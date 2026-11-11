# MirrorNeuron Federation Architecture

MirrorNeuron scales across machines by federating independent Cores. Each Core
owns a writable Redis, schedules its own jobs, and remains operational when a
peer is unavailable. Nodes exchange authenticated control requests and cached
job/run summaries over gRPC; they do not form a Distributed Erlang cluster or
share Redis job state.

## 1. Node and job ownership

Each runtime node runs Core, the private `mn_runtime` service, and Redis. A job has exactly one `owner_node`, selected
explicitly or by the resource/model selector before creation. The owner stores
the authoritative job state and runs every agent, lease, schedule, and control
loop for that job in its own Core.

Another peer can forward create, read, and control requests to the owner. It
stores only a cached summary projection containing availability, freshness,
and last-sync metadata. If the owner is offline, its local work continues and
direct access to that Core remains functional. Other peers can return cached
summaries, but mutations, streams, logs, artifacts, and uncached reads fail
with `503 MN_NODE_UNAVAILABLE`. Run controls are not queued. Known remote Job
archive and confirmed deletion have a narrow exception: the receiving Core can
persist an owner-directed tombstone and report `archive_pending` or
`delete_pending`. Owner cleanup/data deletion is not complete until the peer
reconnects and acknowledges it. See [Reliability](reliability.md#partition-and-restart-behavior).

## 2. Coordination and control plane

Each node uses a distinct Redis identity. Federation rejects peers that point
at the same coordination store, including legacy shared-store deployments.
Redis and Redis Sentinel ports are local deployment details and are not opened
between federated hosts.

An attached surface asks its entry runtime to add a peer. Peer registration is
reciprocal and authenticated. It succeeds after both nodes report the peer as
federated, online, and job-capable. A peer appears in the authoritative node
list with `connection_mode=federated`. Each Core keeps separate BEAM membership.

The Core gRPC port, normally `55051` on the host, must be reachable between
trusted peers. EPMD port `4369`, BEAM distribution port `4370`, and Redis port
`6379` are not federation requirements.

## 3. Model plane

Every agent calls the LiteLLM gateway belonging to its job owner, including
when the selected model is installed on that same machine:

```text
local model:  agent -> owner LiteLLM -> owner DMR
remote model: agent -> owner LiteLLM -> peer LiteLLM -> peer DMR
```

The second path describes gateway route capability. Runs admitted under
`resource_admission_v2` keep managed model/embedding/fallback work on their
reserved PC; peer inventory and gateway routing cannot grant another PC's
capacity. Hosted provider routes remain supported. See
[Model Runtime](model-runtime.md#run-admission-and-model-residency).

Agents never call Docker Model Runner directly. The private LiteLLM endpoint,
normally port `4000`, must be reachable between trusted peers for declared
remote-model routes. Restrict that port with a host firewall or private LAN/VPN
policy. A duplicate model ID prefers the owner's local installation; a remote
or alternate model is used only through an explicitly declared LiteLLM
fallback.

## 4. Starting and joining nodes

Use either runtime installation role to start a node. An application surface
attaches to the first runtime with its control token. That runtime coordinates
additional peer joins through Core federation. Internal peer credentials
authenticate subsequent federated traffic. See the
[Federation Guide](cluster.md#start-and-join-two-nodes) for connection, startup,
and verification commands.

## 5. Storage and scale

Syncthing may transport job blobs between peers, but shared blob visibility
does not make Redis or job state shared. Storage checks are independent from
federation readiness.

Scaling means running independent owner-local jobs concurrently on eligible
Cores. A single job's agents do not fan out across federated nodes. This keeps
owner-local execution available during partitions and makes ownership and
recovery deterministic.

An idle Job can explicitly transfer ownership through `RelocateJob`: freeze
the source, verify an inactive destination, commit source ownership, then
activate the destination. This does not migrate running workers. The transfer
retains source recovery data and imported schedules stay paused; see
[Moving an idle Job](cluster.md#moving-an-idle-job).

See [Reliability Guide](reliability.md), [Cluster Guide](cluster.md), and
[Model Runtime](model-runtime.md) for operational procedures.
