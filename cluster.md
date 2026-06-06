# Cluster Guide

This guide describes how MirrorNeuron forms a small multi-computer runtime and how the cluster places, moves, and protects work.

MirrorNeuron's cluster model is intentionally lightweight. It is closer to a small Nomad-style lab scheduler than to a large container control plane: the runtime places agents on eligible machines, keeps durable job state in Redis, and uses conservative recovery when a node disappears.

## Architecture

MirrorNeuron uses a peer-to-peer cluster model. Every runtime node runs the same core binary and can host job coordinators, agents, and executor work.

The cluster is built from:

- BEAM distribution for node-to-node messaging.
- `libcluster` for peer discovery.
- `Horde` for distributed supervision of job coordinators and agents.
- Redis for durable jobs, events, snapshots, node state, recovery evals, leader election, and job leases.

Single Redis is fine for development. Redis Sentinel HA is recommended once two or more physical machines are sharing real work.

## Required Network Ports

For Docker-network clusters, participating boxes need a shared attachable Docker
network and a reachable host gRPC port:

| Port | Purpose |
| --- | --- |
| `55051` | Deployed host port for the MirrorNeuron core gRPC service. The core container listens on `50051` internally. |
| `26379` | Redis Sentinel when using Redis HA. |

Redis, EPMD, and BEAM distribution stay inside the Docker bridge/overlay network.
Legacy IP-based clusters can still pin BEAM distribution to a fixed port:

```bash
export ERL_AFLAGS="-kernel inet_dist_listen_min 4370 inet_dist_listen_max 4370"
export MN_DIST_PORT="4370"
```

This makes firewall and failure debugging much simpler than random dynamic distribution ports.

## Required Environment

All runtime boxes must agree on the cluster cookie and Redis location.

```bash
export MN_COOKIE="replace-with-a-shared-secret"
export MN_REDIS_URL="redis://192.168.4.29:6379/0"
```

For Redis Sentinel HA:

```bash
export MN_REDIS_HA_MODE="sentinel"
export MN_REDIS_SENTINELS="192.168.4.29:26379,192.168.4.35:26379"
export MN_REDIS_SENTINEL_MASTER="mirror-neuron"
export MN_REDIS_DB="0"
```

See [Redis High Availability](redis-ha.md) for Sentinel setup and failover tests.

## Start A Two-Box Cluster

MirrorNeuron supports two operator flows.

### Option A: Main Box Connects A Worker

On the main box:

```bash
mn runtime start
```

On the worker box:

```bash
mn runtime start --worker-node
```

Copy the worker token printed by `mn runtime start --worker-node`.

Back on the main box, connect the worker:

```bash
mn node join <worker-host> --token <worker-token> --network overlay --docker-network mirror-neuron-runtime
```

Docker multi-host clusters require an existing attachable overlay network:

```bash
docker network create --driver overlay --attachable mirror-neuron-runtime
```

The CLI validates that the network exists, uses the `overlay` driver, and is attachable. The gRPC handshake uses `<worker-host>`, but Erlang distribution and Redis are advertised through stable Docker DNS aliases such as `mirror_neuron@mn-a1b2c3d4` and `mn-a1b2c3d4-redis`.

When `mn node join` first connects a worker, it promotes the main box from local-only mode into cluster mode. By default, the main box advertises the first detected non-loopback LAN IPv4 address. On most computers this is the only LAN address. If the main box has multiple LAN addresses, override the advertised address explicitly:

```bash
mn node join <worker-host> --local-host <main-host> --token <worker-token>
```

### Option B: Main Box Adds Second Box

On the second box:

```bash
mn node expose --host 192.168.4.20 --network overlay --docker-network mirror-neuron-runtime
```

Copy the token printed by `mn node expose`.

On the main box:

```bash
mn node add 192.168.4.20 --token <token> --network overlay --docker-network mirror-neuron-runtime
```

`mn node expose` starts a core-only runtime that exposes host gRPC and keeps Redis/Erlang cluster traffic on the Docker network. It does not start the REST API, Web UI, OpenShell, context engine, or SDK helper processes.

## Verify The Cluster

From the main box:

```bash
mn node list
mn resource list
```

Expected stable signs:

- both physical boxes appear in `mn node list`
- `mn resource list` shows aggregate CPU, memory, disk, and GPU capacity
- node status is `healthy` or `joining`
- `scheduling_eligible` is not `false`

For lower-level dev testing, the checked-in helper can still start a fixed two-node cluster:

```bash
cd MirrorNeuron
bash scripts/start_cluster_node.sh --box1-ip 192.168.4.29 --box2-ip 192.168.4.35 --box 1
```

Run the same helper on the second box with `--box 2`.

## Scheduling Model

The scheduler places workload agents on runtime nodes. It considers:

- node status and scheduling eligibility
- available CPU, memory, disk, and GPU count
- rich device inventory such as CUDA, Metal, GPU vendor, GPU memory, capabilities, and device IDs
- explicit port conflicts
- advertised host paths and runtime drivers
- active job placements already consuming capacity
- execution profiles advertised by each node
- node capabilities and manifest constraints
- node-scoped required services with passing health
- the selected scheduler strategy

Supported strategies:

| Strategy | Behavior |
| --- | --- |
| `binpack` | Prefer fuller nodes so remaining capacity stays consolidated. |
| `spread` | Prefer less-used nodes so work is distributed. |

The default strategy is `binpack`.

### Placement Resources

Per-agent resources can be declared on manifest nodes or under `config.resources`.

Supported placement keys include:

| Resource | Accepted forms |
| --- | --- |
| CPU | `cpu_cores`, `cores`, `cpu`, `cpu_millis`, `cpu_mcores` |
| Memory | `memory_mb`, `memory`, `memory_gb` |
| Disk | `disk_mb`, `disk`, `disk_gb` |
| GPU count | `gpu_count`, `gpus`, `gpu`, or GPU-like entries in `devices` |
| Devices | `devices` with `kind`, `type`, `count`, `vendor`, `driver`, `min_memory_mb`, `capabilities`, and `ids` |
| Ports | `ports` with `label`, `port`, and `protocol` |
| Volumes | `volumes` with `name`, `source`, `target`, `mode`, and `type: host` |
| Runtime driver | `runtime_driver` such as `host_local` or `openshell` |

Execution profiles can also imply GPU demand. If a node asks for a profile whose runtime profile has `gpu: true`, the scheduler requires at least one GPU.

Placement records include concrete allocations for selected devices, reserved ports, volumes, and runtime driver. Core injects safe environment hints such as `MN_ALLOCATION_JSON`, `MN_ALLOCATED_DEVICE_IDS`, `CUDA_VISIBLE_DEVICES`, `MN_PORT_<LABEL>`, and `MN_VOLUME_<NAME>`.

See [Resources and Devices](resources-and-devices.md) for the full resource model.

### Constraints And Capabilities

Constraints can be declared globally in `policies.constraints` or per node in `constraints` / `config.constraints`.

A string constraint means "the target node must advertise this capability." Object constraints can use fields such as `attribute`, `operator`, and `value`.

Common examples:

```json
{
  "policies": {
    "scheduler_strategy": "binpack",
    "constraints": ["cuda"]
  },
  "nodes": [
    {
      "node_id": "worker",
      "type": "executor",
      "resources": {"cpu_cores": 2, "memory_mb": 4096, "gpu_count": 1}
    }
  ]
}
```

## Job Types

MirrorNeuron supports four Nomad-inspired job types.

| Type | Cluster behavior | Typical use |
| --- | --- | --- |
| `service` | Long-running job. Unexpected exit is treated as restartable. | APIs, workers, model servers, queues. |
| `batch` | Runs to completion. Failure retries are policy-limited. | Evals, embedding jobs, dataset processing. |
| `system` | Runs one copy of the whole agent group on every eligible node and keeps it running. | Node monitors, local runtime workers, log collectors. |
| `sysbatch` | Runs one copy of the whole agent group on every eligible node until each target completes. | Diagnostics, cache warmups, cleanup commands. |

`system` and `sysbatch` placements use generated runtime agent ids like `agent@node-name` while preserving the source agent id in the scheduler plan. This lets one logical agent definition expand across every eligible node.

## Node States

Node state is persisted in Redis and used by the scheduler.

| State | Meaning |
| --- | --- |
| `healthy` | Node is active and schedulable unless `scheduling_eligible` is `false`. |
| `joining` | Node is active enough to receive placements. |
| `maintenance` | Node is connected but not eligible for new placements. Existing work is not moved automatically. |
| `draining` | Node is not eligible for new placements and safe work is being moved or allowed to finish. |
| `disconnected` | Node failed reconnect attempts but is still inside the disconnect grace window. |
| `offline` | Node is unavailable after reconnect and grace handling. |
| `quarantined` | Node is treated as inactive. |

The scheduler only places new work on `healthy` or `joining` nodes with `scheduling_eligible != false`.

Node heartbeats do not overwrite an active `maintenance` or `draining` state. This prevents a reconnect from accidentally making a cordoned node schedulable.

## Automatic Reconciliation

When a node disappears, MirrorNeuron does not immediately restart everything.

The recovery path is:

1. `NodeMonitor` observes `nodedown`.
2. The runtime attempts reconnect with exponential backoff.
3. If reconnect is exhausted, the node is marked `disconnected` and executor capacity for that node is released.
4. During the disconnect grace window, recovery evals may wait for the node to return.
5. If the node remains unavailable, the node is marked `offline`.
6. The reconciler inspects active jobs with scheduler placements on that node.

The reconciler uses hybrid recovery:

- If the job coordinator is alive, only affected agents are moved.
- If the job coordinator or job lease is gone, the durable job bundle is loaded and the whole job is restarted with a fresh plan.
- If the job is not effectively `cluster_recover`, it is paused for review instead of moved automatically.
- If snapshots are missing, corrupt, unsafe, or the durable bundle cannot be loaded, the job is paused for review.

Operators can trigger the same path manually:

```bash
mn node reconcile mirror_neuron@192.168.4.20 --reason "manual recovery check" --dry-run
```

Expected output is JSON with counters such as `checked`, `recovered`, `paused`, `blocked`, `skipped`, and `failed`.

## Maintenance Mode

Maintenance mode stops new placements without moving current work.

Enable it before rebooting or changing a box when you want existing jobs to continue in place:

```bash
mn node maintenance mirror_neuron@192.168.4.20 --enable --reason "reboot after current work"
```

Disable it when the node is ready:

```bash
mn node maintenance mirror_neuron@192.168.4.20 --disable --reason "maintenance complete"
```

Maintenance sets `scheduling_eligible` to `false` when enabled and back to `true` when disabled.

## Drain Mode

Drain mode is maintenance plus graceful movement.

Use a dry run first:

```bash
mn node drain mirror_neuron@192.168.4.20 --reason "GPU driver update" --deadline 30m --dry-run
```

Then run the drain:

```bash
mn node drain mirror_neuron@192.168.4.20 --reason "GPU driver update" --deadline 30m --wait
```

Drain behavior:

- the node is marked `draining`
- `scheduling_eligible` becomes `false`
- safe `service` jobs with effective `cluster_recover` migrate through the reconciler
- if the job coordinator lease is on the draining node, the whole job is recovered elsewhere
- `batch` jobs are allowed to finish before the deadline
- after the deadline, batch work migrates only if recovery is safe and cluster-recoverable
- `system` and `sysbatch` jobs are ignored by default
- unsafe leftovers are paused for review rather than force-killed
- blocked placement keeps the node in `draining` so the leader can retry later

Drain migrations are operator-requested maintenance moves. They do not consume failure reschedule policy attempts.

Cancel a drain:

```bash
mn node undrain mirror_neuron@192.168.4.20 --reason "cancel update"
```

A completed drain leaves the node in maintenance/ineligible state. Make it schedulable again explicitly:

```bash
mn node undrain mirror_neuron@192.168.4.20 --reason "ready for work" --mark-eligible
```

## Submit A Cluster Job

Small parallel worker test:

```bash
mn blueprint run parallel_worker_benchmark
```

Expected output:

```text
Job submitted successfully
```

Inspect the job:

```bash
mn job list --running-only
mn job status <job-id>
```

`mn job status` returns the scheduler plan, recovery fields, restart/reschedule policies, and per-agent policy state when present.

## Common Failure Patterns

### `:nodistribution`

Usually means:

- `epmd` is not running
- port `4369` is blocked
- the fixed BEAM distribution port, usually `4370`, is blocked

### Invalid Challenge Reply

Usually means `MN_COOKIE` differs between machines.

Set the same non-default cookie on every physical box:

```bash
export MN_COOKIE="replace-with-a-shared-secret"
```

### HTTP Port `eaddrinuse`

Usually means two local runtimes are trying to bind the same HTTP API port.

Use a different HTTP API port for one of them:

```bash
export MN_API_PORT=4001
```

Keep `MN_API_PORT` separate from `MN_DIST_PORT`.

### Node Name Already In Use

Usually means:

- a runtime node is already running on that machine
- a previous CLI or helper process still exists with the same BEAM node name

Stop the stale process before starting another runtime with the same node name.

### No Schedulable Nodes

Usually means every known node is offline, draining, in maintenance, ineligible, missing a required profile, missing a capability, or short on requested resources.

Check:

```bash
mn node list
mn resource list
```

Then inspect the job scheduler plan:

```bash
mn job status <job-id>
```

### Redis And Split Brain

Redis is the arbiter for leader and job leases. In single Redis mode, the partition that can communicate with Redis maintains leadership and job ownership.

In Sentinel mode, the Sentinel-elected primary is the only write target.

For production Redis HA, use at least three Sentinel voters. A two-box Sentinel quorum of `1` is useful for development smoke tests, but it can split-brain during network partitions.

## Related Docs

- [Nomad-Inspired Runtime Features](nomad-inspired-runtime.md)
- [Reliability Guide](reliability.md)
- [Resources and Devices](resources-and-devices.md)
- [Services and Health Checks](services-and-health-checks.md)
- [Redis High Availability](redis-ha.md)
- [CLI Reference](cli.md)
- [Runtime Architecture](runtime-architecture.md)
- [Troubleshooting](troubleshooting.md)
