# Resources And Devices

MirrorNeuron supports a stronger resource model for scheduling AI workers across mixed machines. This model is inspired by Nomad's `resources`, `device`, `network`, and `volume` ideas, but v1 is scheduling, allocation metadata, and runtime environment hints only.

It does not enforce cgroups, mount host paths, or isolate device access at the OS level.

## Design Concept

Each agent can request:

- scalar capacity: CPU, memory, disk, generic GPU count
- rich devices: CUDA, Metal, ROCm, vendor, memory, capabilities, device IDs
- explicit ports
- host volumes
- runtime drivers such as `host_local` or `openshell`

The scheduler compares those requests against node inventory and active placements. A successful placement records concrete allocation metadata on the job.

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

| Field | Meaning |
| --- | --- |
| `kind` or `type` | Usually `gpu`; either may be used. |
| `count` | Number of matching devices. Defaults to 1. |
| `vendor` | Vendor filter such as `nvidia`, `apple`, or `amd`. |
| `driver` | Driver/runtime capability such as `cuda`, `metal`, or `rocm`. |
| `min_memory_mb` | Minimum memory on one device. |
| `capabilities` | Required capability labels. |
| `ids` | Optional exact device IDs. |

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

Ports are explicit in v1. The scheduler rejects placements that would reserve the same port on the same node.

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

| Env var | Meaning |
| --- | --- |
| `MN_ALLOCATION_JSON` | Full JSON allocation. |
| `MN_ALLOCATED_DEVICE_IDS` | Comma-separated selected device IDs. |
| `CUDA_VISIBLE_DEVICES` | Selected CUDA device indices. |
| `MN_GPU_DRIVER` | Selected GPU drivers. |
| `MN_PORT_<LABEL>` | Reserved explicit port by label. |
| `MN_VOLUME_<NAME>` | Allocated host volume source. |
| `MN_VOLUME_<NAME>_TARGET` | Requested target path. |

Worker code should use these hints when selecting devices, ports, and model/cache paths.

## Inspect Resources

```bash
mn resource list
```

The response includes per-node scalar totals, combined cluster totals, device inventory, GPU memory totals, runtime drivers, and host path information when available.

Set coarse local resource limits:

```bash
mn resource set --cpu 75 --memory 75 --gpu 100 --disk 75
```

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

| Area | Files |
| --- | --- |
| Resource shape and env hints | `MirrorNeuron/lib/mirror_neuron/resource_spec.ex` |
| Scheduler matching and allocation | `MirrorNeuron/lib/mirror_neuron/scheduler.ex` |
| Node inventory | `MirrorNeuron/lib/mirror_neuron/resource.ex` |
| Admission and limits | `MirrorNeuron/lib/mirror_neuron/resource_admission.ex` |
| Runtime agent context | `MirrorNeuron/lib/mirror_neuron/runtime/job_coordinator.ex` |
| Manifest validation | `MirrorNeuron/lib/mirror_neuron/manifest.ex` |
| CLI commands | `mn-cli/mn_cli/libs/resource_cmds.py` |
| SDK validation helpers | `mn-python-sdk/mn_sdk/blueprint_validation.py` |

## V1 Limits

- no dynamic port allocation
- no automatic volume mounting
- no hard device isolation
- no global executor lease balancer yet
- active placement metadata is used to avoid double-booking devices and ports, but host OS enforcement remains the runner's responsibility

