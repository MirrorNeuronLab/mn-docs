# Nomad-Inspired Runtime Features

MirrorNeuron now has a small-lab orchestration layer inspired by Nomad. It is not a Kubernetes clone and it is not a full Nomad replacement. The goal is narrower: run agent workloads across a few machines, make placement decisions from real resources, recover safely when nodes fail, and expose enough operator control for AI lab maintenance.

## Feature Status

| Feature | Status | Start here |
| --- | --- | --- |
| Reconciliation and automatic rescheduling | Implemented | [Reliability Guide](reliability.md) and [Cluster Guide](cluster.md) |
| Full job type behavior | Implemented | [Reliability Guide](reliability.md) |
| Restart and reschedule policies | Implemented | [Reliability Guide](reliability.md) |
| Node drain and maintenance | Implemented | [Cluster Guide](cluster.md) |
| Service registry and health checks | Implemented | [Services and Health Checks](services-and-health-checks.md) |
| Stronger resources and devices | Implemented | [Resources and Devices](resources-and-devices.md) |
| Deployment and update strategy | Implemented | [Deployments](deployments.md) |
| Periodic, delayed, and event-triggered jobs | Implemented | [Schedules and Events](schedules-and-events.md) |

## Design Concept

The runtime uses a desired-vs-actual model:

- the manifest describes desired agents, services, resources, policies, and schedules
- Redis stores durable job state, node state, snapshots, leases, schedules, services, and deployments
- the scheduler chooses eligible target nodes and concrete allocations
- job coordinators keep agents running and apply lifecycle policy
- the leader sweeps recovery evals, orphaned jobs, due drains, and due schedules
- the reconciler moves only the affected agents when it can, and restarts a whole job only when the coordinator lease is gone

That gives MirrorNeuron the Nomad-like heart for small clusters without requiring a heavy control plane.

## How To Use The Features Together

Use `cluster_recover` for work that can be replayed safely:

```json
{
  "type": "service",
  "policies": {
    "recovery_mode": "cluster_recover",
    "restart": {
      "attempts": 3,
      "interval_ms": 600000,
      "delay_ms": 1000,
      "delay_function": "exponential",
      "max_delay_ms": 30000,
      "mode": "fail"
    },
    "reschedule": {
      "unlimited": true,
      "delay_ms": 5000,
      "delay_function": "exponential",
      "max_delay_ms": 300000
    }
  }
}
```

Use `system` for one copy per eligible machine:

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
mn node drain mirror_neuron@192.168.4.20 --reason "driver update" --deadline 30m --dry-run
mn node drain mirror_neuron@192.168.4.20 --reason "driver update" --deadline 30m --wait
mn node undrain mirror_neuron@192.168.4.20 --mark-eligible --reason "ready"
```

Deploy a long-running service under a stable key:

```bash
mn deployment deploy /path/to/bundle --key agent-api --strategy rolling --max-parallel 1
mn deployment status agent-api
```

Schedule a batch job:

```bash
mn schedule create /path/to/bundle --cron "0 2 * * *" --timezone America/New_York
```

Create an event trigger:

```bash
mn trigger create /path/to/bundle --event file_uploaded --filter-json '{"path":{"prefix":"/datasets/"}}'
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
| Restart and reschedule policy | `MirrorNeuron/lib/mirror_neuron/runtime/lifecycle_policy.ex` |
| Reconciliation | `MirrorNeuron/lib/mirror_neuron/cluster/reconciler.ex` |
| Node monitor and leader sweeps | `MirrorNeuron/lib/mirror_neuron/cluster/node_monitor.ex`, `MirrorNeuron/lib/mirror_neuron/cluster/leader.ex` |
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

