# MirrorNeuron Clustering Architecture

MirrorNeuron supports horizontal scaling by seamlessly clustering multiple Elixir/Docker nodes. Under the hood, this relies on Distributed Erlang for real-time messaging, and Redis for shared durable state.

## 1. Network Requirements

For two nodes, for example `192.168.4.25` and `192.168.4.173`, to communicate successfully:

- **Erlang Port Mapper Daemon (EPMD):** Port `4369` must be open and reachable.
- **Erlang Distribution Port:** MirrorNeuron helpers pin BEAM distribution to port `4370` with `MN_DIST_PORT` and `ERL_AFLAGS`.
- **gRPC:** The deployed host gRPC port, usually `55051`, must be reachable for CLI, SDK, and node operator calls. The core container listens on `50051` internally.
- **Redis:** Development clusters can use one shared Redis on port `6379`. Multi-box reliability should use Redis Sentinel HA so each box has a replicated Redis and MirrorNeuron reconnects to the Sentinel-elected primary.
- **Redis Sentinel:** Sentinel uses port `26379` when HA mode is enabled.

## 2. Docker Configuration

When deploying a cluster across different host operating systems (like macOS and Linux), Docker networking behaves differently.
- **Local Docker Compose:** MirrorNeuron uses a named bridge network and a persisted `MN_NODE_ALIAS` so the single-node BEAM identity is stable across laptop IP changes.
- **Multi-host Docker:** Use an existing attachable Docker overlay network. The CLI validates the overlay and uses Docker DNS aliases for Erlang distribution and Redis.
- **Legacy IP mode:** Set `MN_DOCKER_NETWORK_MODE=disabled` to use host/IP-backed Erlang names.

In Docker network mode, we inject `MN_NODE_NAME=mirror_neuron@<MN_NODE_ALIAS>` so the Erlang node is explicitly addressable without depending on the current LAN IP. In legacy mode, `MN_NODE_NAME=mirror_neuron@<IP>` remains available.

## 3. Remote Payload Execution (`HostLocal` Runner)

When a Job is submitted via the REST API to the Leader node, its artifacts (like Python scripts inside `payloads/`) are extracted to a temporary directory in the Leader's `/tmp/bundle_xxx` path.

As tasks are scheduled to execute remotely, the `MirrorNeuron.Runner.HostLocal` module dynamically detects if the execution is happening locally or remotely:
- **Local:** It simply uses `File.cp_r` to natively copy the files to the sandbox.
- **Remote:** It establishes a synchronous `rpc:call` back to the `coordinator_node` (the Leader) to recursively read the directory tree over the Erlang distribution network and writes the payloads to the remote container's Sandbox filesystem. 
  
This ensures that workflows can seamlessly map/reduce completely agnostic to the underlying hardware execution plane.

## 4. Nomad-Inspired Control Loop

The clustered runtime now has a Nomad-inspired control loop:

- the scheduler places agents on eligible nodes using resources, devices, ports, volumes, runtime drivers, constraints, and service requirements
- node state in Redis decides whether a node is healthy, joining, draining, in maintenance, disconnected, offline, or quarantined
- the reconciler handles node loss, orphaned jobs, and policy-driven reschedules
- the job coordinator restarts agents locally first, then asks the reconciler to move safe work when restart policy is exhausted
- node drain marks a node ineligible, moves safe service work, lets batch work finish, and leaves the node in maintenance until undrained
- the leader sweeps recovery evals, due drains, orphaned jobs, and due schedules

See [Nomad-Inspired Runtime Features](nomad-inspired-runtime.md), [Reliability Guide](reliability.md), and [Cluster Guide](cluster.md).

## 5. Starting a Cluster

### On Node 1 (The Leader / Initial Node)
```bash
mn runtime start
```
*Starts Redis, the API, and sets itself up as the coordinating node. Ensure your firewall permits access to 4369, Redis/Sentinel ports, and the configured Erlang distribution ports.*

### On Node 2 (The Worker)
```bash
mn runtime start --worker-node
```

### Back On Node 1
```bash
mn node join <WORKER_IP> --token <worker-token>
# e.g., mn node join 192.168.4.25 --token <worker-token>
```
*Promotes the main runtime to cluster mode if needed, then connects the worker. If Node 1 has multiple LAN addresses, pass `--local-host <NODE_1_IP>` to choose the advertised address.*

### Verifying Connection
```bash
mn node list
```
*You should see multiple items under `nodes`, and their respective hardware capacities pooled together in the `executor_pools`.*

## 6. Avoiding Local Resource Exhaustion
When running heavy distributed load tests such as `parallel_worker_benchmark`, very high worker counts across a small two-node development setup may exhaust CPU and networking file descriptors, causing nodes to miss Erlang heartbeats (`timed out waiting for recovered agent ...`).

To test scaling logic without overloading small development VMs, lower the worker count in the blueprint configuration before running the benchmark.

This enables the framework to accurately demonstrate Map/Reduce scaling topologies, Remote RPC artifact synchronization (`MirrorNeuron.Runner.HostLocal`), and cross-node swarm orchestration entirely under manageable resource constraints.
