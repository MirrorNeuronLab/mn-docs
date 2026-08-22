# Nomad-Inspired Runtime Features

MirrorNeuron has a small-lab orchestration layer inspired by Nomad. It is not a
Kubernetes clone or a full Nomad replacement. The goal is narrower: choose one
eligible owner Core for each job, run all of that job's agents there, recover
locally, and expose enough operator control for AI lab maintenance.

## Feature Status

| Feature | Status | Start here |
| --- | --- | --- |
| Owner-local reconciliation and restart | Implemented | [Reliability Guide](reliability.md) and [Federation Guide](cluster.md) |
| Full job type behavior | Implemented | [Reliability Guide](reliability.md) |
| Restart policy and legacy reschedule-schema compatibility | Implemented | [Reliability Guide](reliability.md) |
| Node drain and maintenance | Implemented | [Cluster Guide](cluster.md) |
| Service registry and health checks | Implemented | [Services and Health Checks](services-and-health-checks.md) |
| Stronger resources and devices | Implemented | [Resources and Devices](resources-and-devices.md) |
| Deployment and update strategy | Implemented | [Deployments](deployments.md) |
| Periodic, delayed, and event-triggered jobs | Implemented | [Schedules and Events](schedules-and-events.md) |

## Design Concept

The runtime uses a desired-vs-actual model:

- the manifest describes desired agents, services, resources, policies, and schedules
- the owner's Redis stores durable job state, snapshots, leases, schedules, services, and deployments
- federation selects one eligible owner before creation
- the owner's scheduler chooses concrete local allocations
- job coordinators keep agents running and apply lifecycle policy
- local sweeps reconcile owned jobs, due drains, and schedules
- remote peers forward controls and cache summaries; they do not move agents or take over jobs

That gives MirrorNeuron a Nomad-like owner-local control loop without requiring
a heavy shared control plane.

## How To Use The Features Together

Use a bounded local restart policy for work that can be replayed safely:

```json
{
  "type": "service",
  "policies": {
    "recovery_mode": "local_restart",
    "restart": {
      "attempts": 3,
      "interval_ms": 600000,
      "delay_ms": 1000,
      "delay_function": "exponential",
      "max_delay_ms": 30000,
      "mode": "fail"
    }
  }
}
```

Use `system` for owner-local long-running system work. It does not expand one
federated job across peer Cores:

```json
{
  "policies": {
    "scheduler": {
      "job_type": "system"
    }
  }
}
```

Use resource and service requirements together when a worker needs a healthy local service:

```json
{
  "nodes": [
    {
      "node_id": "embedding_worker",
      "agent_type": "executor",
      "resources": {
        "devices": [
          {
            "kind": "gpu",
            "driver": "cuda",
            "min_memory_mb": 16000,
            "count": 1
          }
        ]
      },
      "requires_services": [
        {
          "name": "vllm",
          "tags": ["embedding"],
          "required": true
        }
      ]
    }
  ]
}
```

Drain a node before rebooting it:

```bash
mn node drain mirror_neuron@<node-host> --reason "driver update" --deadline 30m --dry-run
mn node drain mirror_neuron@<node-host> --reason "driver update" --deadline 30m --wait
mn node undrain mirror_neuron@<node-host> --mark-eligible --reason "ready"
```

Deploy a long-running service under a stable key:

```bash
mn deployment deploy /path/to/bundle --key agent-api --strategy rolling --max-parallel 1
mn deployment show agent-api
```

Schedule a batch job:

```bash
mn schedule add /path/to/bundle --cron "0 2 * * *" --timezone America/New_York
```

Create an event trigger:

```bash
mn schedule add /path/to/bundle --event file_uploaded --filter '{"path":{"prefix":"/datasets/"}}'
mn event emit file_uploaded --payload-json '{"path":"/datasets/eval.jsonl"}'
```

## Important Code

| Area | Important files |
| --- | --- |
| Manifest fields and validation | `MirrorNeuron/lib/mirror_neuron/manifest.ex` |
| Placement scheduler | `MirrorNeuron/lib/mirror_neuron/scheduler.ex` |
| Resource spec and allocation env | `MirrorNeuron/lib/mirror_neuron/resource_spec.ex` |
| Node inventory and resource API | `MirrorNeuron/lib/mirror_neuron/resource.ex` |
| Job coordinator lifecycle | `MirrorNeuron/lib/mirror_neuron/runtime/job_coordinator.ex` |
| Restart and legacy policy normalization | `MirrorNeuron/lib/mirror_neuron/runtime/lifecycle_policy.ex` |
| Owner-local reconciliation | `MirrorNeuron/lib/mirror_neuron/cluster/reconciler.ex` |
| Federation monitoring | `MirrorNeuron/lib/mirror_neuron/cluster/federation_monitor.ex` |
| Drain and maintenance | `MirrorNeuron/lib/mirror_neuron/cluster/node_drainer.ex` |
| Service declarations | `MirrorNeuron/lib/mirror_neuron/service_spec.ex` |
| Service checks and registry | `MirrorNeuron/lib/mirror_neuron/service_check.ex`, `MirrorNeuron/lib/mirror_neuron/service_registry.ex`, `MirrorNeuron/lib/mirror_neuron/service_monitor.ex`, `MirrorNeuron/lib/mirror_neuron/service_preflight.ex` |
| Deployments | `MirrorNeuron/lib/mirror_neuron/runtime/deployment_policy.ex`, `MirrorNeuron/lib/mirror_neuron/runtime/deployment_controller.ex` |
| Schedules and triggers | `MirrorNeuron/lib/mirror_neuron/runtime/schedule_policy.ex`, `MirrorNeuron/lib/mirror_neuron/runtime/schedule_dispatcher.ex` |
| Durable Redis state | `MirrorNeuron/lib/mirror_neuron/persistence/redis_store.ex` |
| gRPC server surfaces | `MirrorNeuron/lib/mirror_neuron_grpc/server.ex` |
| CLI commands | `mn-cli/mn_cli/main.py`, `mn-cli/mn_cli/libs/*.py` |
| Python SDK | `mn-python-sdk/mn_sdk/client.py`, `mn-python-sdk/mn_sdk/bundle.py`, `mn-python-sdk/mn_sdk/decorators.py` |
| Blueprint validation | `mn-python-sdk/mn_sdk/blueprint_validation.py` |

## What Is Still Intentionally V1

- resources and devices drive scheduling and runtime environment hints, not OS isolation
- volumes are validated and advertised, but not mounted automatically by core
- ports are explicit only, with no dynamic port allocator yet
- service health affects discovery and placement, but does not automatically restart jobs yet
- deployment rollout behavior is focused on `service` and `system` jobs
- scheduled child jobs are ordinary jobs, so the normal reliability model still applies
