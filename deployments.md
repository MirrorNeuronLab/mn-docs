# Deployments

MirrorNeuron deployments provide versioned updates for long-running workloads. The design is inspired by Nomad rolling and canary deployments, but uses MirrorNeuron's job coordinator, service registry, and Redis state.

`deployment_key` is the stable identity for an app, blueprint, or co-worker. `job_id` remains the concrete runtime instance.

## Design Concept

A deployment records:

- stable deployment key
- deployment id
- version history
- source job and target job
- target manifest and bundle reference
- rollout status and events
- health summary
- rollback target

For `service` and `system` jobs, deployments can update running agents. For `batch` and `sysbatch`, deployments store versioned rerun history instead of doing in-place rolling updates.

## Manifest Fields

```json
{
  "deployment": {
    "key": "agent-api"
  },
  "policies": {
    "update": {
      "strategy": "rolling",
      "max_parallel": 1,
      "canary": 0,
      "min_healthy_ms": 10000,
      "healthy_deadline_ms": 300000,
      "progress_deadline_ms": 600000,
      "health_check": "checks",
      "auto_promote": false,
      "auto_revert": false
    }
  }
}
```

Supported strategies:

| Strategy | Behavior |
| --- | --- |
| `rolling` | Replace changed agents in batches capped by `max_parallel`. |
| `canary` | Replace a canary batch and pause until promotion unless `auto_promote` is true. |
| `blue-green` | Start a target version alongside the old version, then promote and retire the old primary. |

Health checks:

| Value | Meaning |
| --- | --- |
| `checks` | Agent ready plus passing service checks when declared. |
| `agent_states` | Agent readiness only. |

Defaults:

| Field | Default |
| --- | --- |
| `strategy` | `rolling` |
| `max_parallel` | `1` |
| `canary` | `0` |
| `min_healthy_ms` | `10000` |
| `healthy_deadline_ms` | `300000` |
| `progress_deadline_ms` | `600000` |
| `health_check` | `checks` |
| `auto_promote` | `false` |
| `auto_revert` | `false` |

## CLI Usage

First deploy:

```bash
mn deployment deploy /path/to/bundle --key agent-api --strategy rolling --max-parallel 1
```

List deployments:

```bash
mn deployment list
```

Show one deployment:

```bash
mn deployment status agent-api
```

Manual canary:

```bash
mn deployment deploy /path/to/bundle-v2 --key agent-api --strategy canary --canary 1
mn deployment status agent-api
mn deployment promote agent-api
```

Rollback:

```bash
mn deployment rollback agent-api --version 1 --reason "restore stable worker"
```

Pause or resume deployment bookkeeping:

```bash
mn deployment pause agent-api --reason "investigating health"
mn deployment resume agent-api --reason "continue rollout"
```

Mark a deployment failed:

```bash
mn deployment fail agent-api --reason "candidate failed health checks"
```

## Runtime Behavior

- a new deployment key starts normally and writes version `1`
- same-topology updates replace changed agents through the live job coordinator
- topology-changing updates use blue-green whole-job deployment
- canary services are hidden from normal discovery by default
- promotion makes the target version primary and retires old primary instances
- rollback creates a new deployment from a selected stable version instead of mutating old history
- restart/reschedule policy still applies underneath deployments

Same-topology means stable agent IDs and compatible graph edges. If the coordinator cannot safely update selected agents, deployment falls back to a whole-job strategy.

## Service Discovery Integration

Service instances carry deployment metadata:

- `deployment_key`
- `deployment_id`
- `deployment_version`
- `deployment_role`

Normal service discovery returns primary passing instances. Canary and candidate instances stay hidden unless the caller explicitly asks for non-primary discovery.

## Important Code

| Area | Files |
| --- | --- |
| Policy normalization and validation | `MirrorNeuron/lib/mirror_neuron/runtime/deployment_policy.ex` |
| Controller and version records | `MirrorNeuron/lib/mirror_neuron/runtime/deployment_controller.ex` |
| Agent replacement messages | `MirrorNeuron/lib/mirror_neuron/runtime/job_coordinator.ex` |
| Service role metadata | `MirrorNeuron/lib/mirror_neuron/service_registry.ex` |
| Redis deployment storage | `MirrorNeuron/lib/mirror_neuron/persistence/redis_store.ex` |
| gRPC methods | `MirrorNeuron/lib/mirror_neuron_grpc/server.ex` |
| CLI commands | `mn-cli/mn_cli/libs/deployment_cmds.py` |
| SDK client and bundle pass-through | `mn-python-sdk/mn_sdk/client.py`, `mn-python-sdk/mn_sdk/bundle.py` |

## V1 Limits

- rolling and canary behavior targets `service` and `system` jobs
- `batch` and `sysbatch` keep version history and explicit reruns
- deployment does not replace reliability policy; failed agents still follow restart/reschedule rules
- fully automatic rollback depends on health signals available from agent readiness and service checks

