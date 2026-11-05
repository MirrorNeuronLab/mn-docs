# Resources And Devices

For blueprint authors and operators, this reference explains how the current
checkout reserves one run's capacity on its Job owner, queues compatible work,
and selects devices, ports, and volumes. It covers admission and allocation;
runner isolation is covered in [Security](security.md). The contracts below are
verified against Core's `runtime/resource_allocation.ex`, `node_admission.ex`,
`node_admission_state.ex`, `resource_spec.ex`, and their unit tests. Release
compatibility requires matching Core and native SDK artifacts.

Admission enforces runtime reservations. It does not create cgroups, mount host
paths, or provide an OS security boundary for arbitrary worker code.

## Design Concept

Each agent can request:

- scalar capacity: CPU, memory, disk, generic GPU count
- rich devices: CUDA, Metal, ROCm, vendor, memory, capabilities, device IDs
- explicit ports
- host volumes
- runtime drivers such as `host_local` or `openshell`

Owner selection uses node inventory; only the selected owner's atomic Redis
reservation authorizes execution. The local scheduler then resolves worker
placements and allocation metadata. A federated availability report or a
successful read-only admission check cannot grant capacity.

## Run resource budgets

The generated executable manifest accepts `policies.resource_allocation`.
In a [source package](blueprint-standard.md), author this under `policies` in
`execution.json`.

| Policy                             | Admission behavior                                                                                                                       |
| ---------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| Omitted, or `mode: exclusive_node` | Reserves the whole owner PC. Existing whole-PC claims retain this protection until cleanup.                                              |
| `mode: shared`                     | Admits compatible runs together within declared peak CPU, RAM, disk, and GPU budgets. Positive `cpu_cores` and `memory_mb` are required. |

This CPU-only policy is a fragment of `execution.json`, not a complete blueprint:

```json
{
  "policies": {
    "resource_allocation": {
      "mode": "shared",
      "cpu_cores": 2,
      "memory_mb": 4096,
      "disk_mb": 1024
    }
  }
}
```

The budget must cover the declared workers and peak concurrent model use,
including weights, contexts/KV caches, and scratch memory. Core rejects an
undersized shared profile. In a device request, `min_memory_mb` selects compatible
hardware; `reservation_memory_mb` reserves the run's peak use. For example, a
shared GPU request can require a 49,152 MiB NVIDIA CUDA device while reserving
16,384 MiB on it:

```json
{
  "vendor": "nvidia",
  "driver": "cuda",
  "count": 1,
  "min_memory_mb": 49152,
  "sharing": "shared",
  "reservation_memory_mb": 16384
}
```

Place that object in the profile's `devices` array. `sharing: exclusive`
reserves the selected GPU while leaving other PC capacity available. Core
selects the smallest compatible GPU first and retains the larger of 512 MiB
and 10% headroom for shared GPUs. Unified-memory GPU reservations also consume
host RAM. Shared weights reduce a reservation only with a matching native
resident-engine attestation; current managed-model sharing requires one
physical GPU. Multi-GPU managed engines require an exclusive profile.

Shared profiles require fixed integer ports. Ports and overlapping writable host
volumes stay exclusive across shared runs. Worker device binding and native model
requests must honor the recorded allocation and reservation generation.

## Admission and queueing

`CheckRunAdmission` is read-only and returns `runnable_now`, `runnable_later`,
`not_runnable`, or `unavailable`, with measured blockers. Stale telemetry cannot
authorize execution. Start and explicit checkpoint retry recheck and reserve
under the owner's start gate before execution persistence.

| Start policy                 | Result when compatible capacity is busy                                                                                             |
| ---------------------------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| `start_now` (manual default) | Rejects admission with `accepted: false`; no failed execution is created just to represent resource contention.                     |
| `enqueue_if_busy`            | Accepts the same run into a durable owner-local queue with `status: queued` and an `admission` receipt; no executor is running yet. |
| Scheduled occurrence         | Uses the durable queue automatically while retaining occurrence identity and overlap policy.                                        |

An accepted queued run starts automatically when eligible. The receipt identifies
the queue, owner, friendly PC label when available, position, and blocker.
Queue order uses bounded backfill: after three bypasses, older work's required
resource vector is protected while work fitting residual capacity can proceed.
The combined queued/deferred limit is 1,000 entries per PC. Queue state, run
identity, staged inputs, configuration/bundle identity, and data generation
survive admission-service restart.

Queue entries appear as `resource_wait` schedules named `queue_<run-id>`.
Deferral releases any unstarted claim until the future time; queued cancellation
cannot cancel an already admitted execution. See [Schedules and Events](schedules-and-events.md)
for the lifecycle and [CLI](cli.md#jobs-and-runs) / [API](api.md#run-admission-and-queued-starts)
for the public interfaces.

Pause, automatic retry, and recovery retain a run's claim. Terminal cleanup must
stop owned commands/containers, drain native inference leases, and release
run-owned model residency before capacity becomes reusable. Failed cleanup keeps
the reservation pending for reconciliation. A timeout, missing process, missing
run record, or offline owner is insufficient proof of release. Installed model
files, reusable images, reports, and durable Job data remain on disk.

Detailed run reads expose `placement.owner_node`, an optional friendly label,
and a sanitized `placement.reservation` whose state is `reserved`, `queued`,
`unreserved`, or `unavailable`. Unknown amounts stay null; paused and terminal
cleanup claims can still be reserved. List projections do not read claims.

## Resource Request Shape

```json
{
  "nodes": [
    {
      "node_id": "gpu_worker",
      "agent_type": "executor",
      "resources": {
        "cpu_cores": 2,
        "memory_mb": 8192,
        "disk_mb": 20480,
        "devices": [
          {
            "kind": "gpu",
            "driver": "cuda",
            "vendor": "nvidia",
            "min_memory_mb": 16000,
            "capabilities": ["fp16"],
            "count": 1
          }
        ],
        "ports": [
          {
            "label": "api",
            "port": 8088,
            "protocol": "http"
          }
        ],
        "volumes": [
          {
            "name": "models",
            "source": "/mnt/models",
            "target": "/models",
            "mode": "ro",
            "type": "host"
          }
        ],
        "runtime_driver": "host_local"
      }
    }
  ]
}
```

Existing manifests remain valid. Legacy `gpu_count` is treated as a generic GPU device request:

```json
{
  "resources": {
    "gpu_count": 1
  }
}
```

## Device Requests

| Field            | Meaning                                                       |
| ---------------- | ------------------------------------------------------------- |
| `kind` or `type` | Usually `gpu`; either may be used.                            |
| `count`          | Number of matching devices. Defaults to 1.                    |
| `vendor`         | Vendor filter such as `nvidia`, `apple`, or `amd`.            |
| `driver`         | Driver/runtime capability such as `cuda`, `metal`, or `rocm`. |
| `min_memory_mb`  | Minimum memory on one device.                                 |
| `capabilities`   | Required capability labels.                                   |
| `ids`            | Optional exact device IDs.                                    |

Examples:

CUDA only:

```json
{
  "resources": {
    "devices": [
      {
        "kind": "gpu",
        "driver": "cuda",
        "count": 1
      }
    ]
  }
}
```

Apple Metal:

```json
{
  "resources": {
    "devices": [
      {
        "kind": "gpu",
        "driver": "metal",
        "vendor": "apple",
        "count": 1
      }
    ]
  }
}
```

Large memory GPU:

```json
{
  "resources": {
    "devices": [
      {
        "kind": "gpu",
        "min_memory_mb": 24000,
        "count": 1
      }
    ]
  }
}
```

## Ports

Ports may be fixed integers or `"auto"`. The scheduler rejects conflicting
reservations on one node. An automatic request resolves to an integer in the
persisted plan and `MN_PORT_<LABEL>`; service templates use the same allocation.
The default range is `49152..65535`, constrained by `MN_AUTO_PORT_START` and
`MN_AUTO_PORT_END`. Shared run profiles currently require fixed ports.

An allocation does not publish a container port or open a firewall. Configure
the runner and listener boundary separately before exposing a service.

```json
{
  "resources": {
    "ports": [
      {
        "label": "metrics",
        "port": 9100,
        "protocol": "http"
      }
    ]
  }
}
```

Supported protocols are `tcp`, `udp`, `http`, and `grpc`.

## Volumes

Volumes are host-path requirements in v1. The scheduler only places a job on a node that advertises or has the requested absolute source path. Core records the allocation and injects environment hints, but it does not mount the path automatically.

```json
{
  "resources": {
    "volumes": [
      {
        "name": "cache",
        "source": "/var/mn-cache",
        "target": "/cache",
        "mode": "rw",
        "type": "host"
      }
    ]
  }
}
```

Supported modes are `ro` and `rw`. Supported type is `host`.

## Runtime Environment Hints

When an agent starts, allocation metadata is passed into its runtime context and safe environment hints:

| Env var                   | Meaning                              |
| ------------------------- | ------------------------------------ |
| `MN_ALLOCATION_JSON`      | Full JSON allocation.                |
| `MN_ALLOCATED_DEVICE_IDS` | Comma-separated selected device IDs. |
| `CUDA_VISIBLE_DEVICES`    | Selected CUDA device indices.        |
| `MN_GPU_DRIVER`           | Selected GPU drivers.                |
| `MN_PORT_<LABEL>`         | Reserved explicit port by label.     |
| `MN_VOLUME_<NAME>`        | Allocated host volume source.        |
| `MN_VOLUME_<NAME>_TARGET` | Requested target path.               |

Worker code should use these hints when selecting devices, ports, and model/cache paths.

## Inspect Resources

From any directory with the CLI installed and runtime credentials configured:

```bash
mn resource show
```

The response includes per-node capacity, device inventory, runtime drivers, and
admission information when available. Combined totals do not mean one run can
pool several PCs. `cpu_load_average_1m`, when present, is measured one-minute
load, not CPU utilization or a reservation; a missing sample is unknown.

To change coarse local capacity percentages, save the current limits first,
then apply and inspect them:

```bash
mn resource set --cpu 75 --memory 75 --gpu 100 --disk 75
mn resource show
```

This changes admission limits. Restore the saved percentages with the same
command to roll back; it does not install OS resource isolation.

## Validation

`mn blueprint validate` rejects:

- malformed `devices`, `ports`, or `volumes`
- negative memory, count, or scalar values
- duplicate port labels
- duplicate volume names
- invalid ports outside `1..65535`
- relative volume source or target paths
- unsupported volume modes or protocols
- non-string `runtime_driver`

## Important Code

| Area                                       | Files                                                                                 |
| ------------------------------------------ | ------------------------------------------------------------------------------------- |
| Resource shape and env hints               | `MirrorNeuron/lib/mirror_neuron/resource_spec.ex`                                     |
| Scheduler matching and allocation          | `MirrorNeuron/lib/mirror_neuron/scheduler.ex`                                         |
| Node inventory                             | `MirrorNeuron/lib/mirror_neuron/resource.ex`                                          |
| Run budgets and device accounting          | `MirrorNeuron/lib/mirror_neuron/runtime/resource_allocation.ex`                       |
| Durable reservation, dispatch, and cleanup | `MirrorNeuron/lib/mirror_neuron/runtime/node_admission.ex`, `node_admission_state.ex` |
| Coarse resource percentages                | `MirrorNeuron/lib/mirror_neuron/resource_admission.ex`                                |
| Runtime agent context                      | `MirrorNeuron/lib/mirror_neuron/runtime/job_coordinator.ex`                           |
| Manifest validation                        | `MirrorNeuron/lib/mirror_neuron/manifest.ex`                                          |
| CLI commands                               | `mn-cli/mn_cli/libs/resource_cmds.py`                                                 |
| SDK validation helpers                     | `mn-python-sdk/mn_sdk/blueprint_validation.py`                                        |

## V1 Limits

- no automatic volume mounting
- no hard device isolation
- no global executor lease balancer yet
- automatic ports are unavailable to shared run profiles
- managed-model sharing requires one physical GPU and a covering reservation
- allocation and request fencing do not constrain unrelated host processes

## Verification

Core's `resource_allocation_test.exs`, `node_admission_state_test.exs`, and
`resource_spec_test.exs` cover shared packing, backfill, conflicts, legacy claims,
and port normalization. SDK `test_node_admission.py` and
`test_run_model_allocation.py` cover native request leases and model bounds.
Real hardware admission, Docker device binding, and release compatibility still
require the matching installed-runtime integration checks. See [Changes](changes.md)
for this audit's exact validation scope.
