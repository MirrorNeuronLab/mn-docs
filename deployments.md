# Deployments

For Core maintainers, this is an explanation/reference of the internal
deployment controller and its retained manifest policy. It is not a public
deployment procedure: the current CLI has no `deployment` group, REST v1 has no
`/deployments`, and `mirrorneuron.job.v1.JobService` exposes durable Job/Run
operations instead. Use [CLI](cli.md) and [API](api.md) for supported interfaces.
Sources are `runtime/deployment_policy.ex`, `deployment_controller.ex`, and
`deployment_policy_test.exs`; public-surface absence is checked against command
registration, OpenAPI, and API contract tests. Internal policy support does not
establish a released rollout API.

MirrorNeuron deployments provide versioned updates for long-running workloads. The design is inspired by Nomad rolling and canary deployments, but uses MirrorNeuron's job coordinator, service registry, and Redis state.

`deployment_key` identifies the controller's version history. Keep that internal
identity separate from the public durable Job and execution Run vocabulary.

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

The former deployment verbs are removed. There is no supported CLI replacement
for rolling/canary promotion. A durable definition can be prepared/updated and
its Runs controlled through current Job/Run interfaces; that does not expose
the internal controller's rollout policy as a public command.

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
| Current gRPC boundary | `MirrorNeuron/proto/job.proto` (no deployment operations) |
| Public CLI boundary | `mn-cli/mn_cli/main.py` (no deployment group) |
| Public REST boundary | `mn-api/mn_api/app.py`, route modules, and OpenAPI (no deployment routes) |

## V1 Limits

- rolling and canary behavior targets `service` and `system` jobs
- `batch` and `sysbatch` keep version history and explicit reruns
- deployment does not replace reliability policy; failed agents still follow restart/reschedule rules
- fully automatic rollback depends on health signals available from agent readiness and service checks

