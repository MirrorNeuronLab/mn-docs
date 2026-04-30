# MirrorNeuron Clustering Architecture

MirrorNeuron supports horizontal scaling by seamlessly clustering multiple Elixir/Docker nodes. Under the hood, this relies on Distributed Erlang for real-time messaging, and Redis for shared durable state.

## 1. Network Requirements

For two nodes (e.g. `192.168.4.25` as the Leader and `192.168.4.173` as a Follower) to communicate successfully:
- **Erlang Port Mapper Daemon (EPMD):** Port `4369` must be open and reachable.
- **Erlang Distribution Ports:** A predefined range of ports (e.g. `9000-9010`) must be explicitly published by the Docker container and reachable across the network.
- **Redis:** Development clusters can use one shared Redis on port `6379`. Multi-box reliability should use Redis Sentinel HA so each box has a replicated Redis and MirrorNeuron reconnects to the Sentinel-elected primary.

## 2. Docker Configuration

When deploying a cluster across different host operating systems (like macOS and Linux), the networking bridge behaves differently.
- **macOS:** `--network host` does not expose the Erlang ports to the external network due to the underlying Linux VM. Instead, the `mn` CLI automatically detects macOS (`Darwin`) and manually publishes `-p 4369:4369` and `-p 9000-9010:9000-9010`.
- **Linux:** Native Docker uses `--network host` which binds the Erlang distribution safely to the physical host interfaces.

In both cases, we inject `MIRROR_NEURON_NODE_NAME=mirror_neuron@<IP>` so the Erlang node is explicitly addressable rather than falling back to `nonode@nohost`.

## 3. Remote Payload Execution (`HostLocal` Runner)

When a Job is submitted via the REST API to the Leader node, its artifacts (like Python scripts inside `payloads/`) are extracted to a temporary directory in the Leader's `/tmp/bundle_xxx` path.

As tasks are scheduled to execute remotely, the `MirrorNeuron.Runner.HostLocal` module dynamically detects if the execution is happening locally or remotely:
- **Local:** It simply uses `File.cp_r` to natively copy the files to the sandbox.
- **Remote:** It establishes a synchronous `rpc:call` back to the `coordinator_node` (the Leader) to recursively read the directory tree over the Erlang distribution network and writes the payloads to the remote container's Sandbox filesystem. 
  
This ensures that workflows can seamlessly map/reduce completely agnostic to the underlying hardware execution plane.

## 4. Starting a Cluster

### On Node 1 (The Leader / Initial Node)
```bash
mn start
```
*Starts Redis, the API, and sets itself up as the coordinating node. Ensure your firewall permits access to 4369, Redis/Sentinel ports, and the configured Erlang distribution ports.*

### On Node 2 (The Follower)
```bash
mn join <LEADER_IP>
# e.g., mn join 192.168.4.25
```
*Will launch an attached worker node that links back to Redis or Sentinel and the Elixir swarm.*

### Verifying Connection
```bash
mn nodes
```
*You should see multiple items under `nodes`, and their respective hardware capacities pooled together in the `executor_pools`.*

## 5. Avoiding Local Resource Exhaustion
When running on heavy distributed load tests (e.g. `general_prime_sweep_scale`), attempting to invoke 1,000 OS `python3` subprocesses concurrently across a local 2-node development setup may exhaust CPU and networking file descriptors, causing nodes to miss Erlang heartbeats (`timed out waiting for recovered agent ...`).

To securely test scaling logic without overloading small development VMs, lower the worker count in the generated blueprint:
```bash
cd mn-blueprints/general_prime_sweep_scale
python3 generate_bundle.py --workers 100
```
This enables the framework to accurately demonstrate Map/Reduce scaling topologies, Remote RPC artifact synchronization (`MirrorNeuron.Runner.HostLocal`), and cross-node swarm orchestration entirely under manageable resource constraints.
