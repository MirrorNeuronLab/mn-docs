# MirrorNeuron Federation Architecture

MirrorNeuron scales across machines by federating independent Cores. Each Core
owns a writable Redis, schedules its own jobs, and remains operational when a
peer is unavailable. Nodes exchange authenticated control requests and cached
job/run summaries over gRPC; they do not form a Distributed Erlang cluster or
share Redis job state.

## 1. Node and job ownership

Every Core is a full runtime node. A job has exactly one `owner_node`, selected
explicitly or by the resource/model selector before creation. The owner stores
the authoritative job state and runs every agent, lease, schedule, and control
loop for that job in its own Core.

Another peer can forward create, read, and control requests to the owner. It
stores only a cached summary projection containing availability, freshness,
and last-sync metadata. If the owner is offline, its local work continues and
direct access to that Core remains functional. Other peers can return cached
summaries, but mutations, streams, logs, artifacts, and uncached reads fail
with `503 MN_NODE_UNAVAILABLE`; requests are not queued.

## 2. Coordination and control plane

Each node uses a distinct Redis identity. Federation rejects peers that point
at the same coordination store, including legacy shared-store deployments.
Redis and Redis Sentinel ports are local deployment details and are not opened
between federated hosts.

Peer registration is reciprocal and authenticated. `mn node add` succeeds only
after both nodes report the peer as federated, online, and job-capable. A peer
appears in the authoritative node list with `connection_mode=federated`, but it
must not appear in BEAM `connected_nodes`.

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

Agents never call Docker Model Runner directly. The private LiteLLM endpoint,
normally port `4000`, must be reachable between trusted peers for declared
remote-model routes. Restrict that port with a host firewall or private LAN/VPN
policy. A duplicate model ID prefers the owner's local installation; a remote
or alternate model is used only through an explicitly declared LiteLLM
fallback.

## 4. Starting and joining nodes

There is no leader/worker start distinction. On each machine, start the same
federation-capable runtime:

```bash
mn runtime start
```

The success output shows the advertised host, gRPC endpoint, node identity,
active join token, and an exact command such as:

```bash
mn node add <node-host> --token <join-token> --grpc-port 55051
```

Run that printed command on an already-running peer. The CLI waits for
reciprocal readiness before returning success. The API's
`POST /api/v1/nodes` follows the same SDK orchestration and returns `201` only
after the same readiness check.

Treat the displayed token as a credential: keep terminal output private and
rotate it with `mn node refresh-token` if exposed. The former
`mn runtime start --worker` option has been removed; use `mn runtime start` on
every node.

Verify the relationship from either peer:

```bash
mn node list
mn runtime status
```

The peer should be federated and job-capable, each node should report a
different store identity, and no peer should be present in BEAM
`connected_nodes`.

## 5. Storage and scale

Syncthing may transport job blobs between peers, but shared blob visibility
does not make Redis or job state shared. Storage checks are independent from
federation readiness.

Scaling means running independent owner-local jobs concurrently on eligible
Cores. A single job's agents do not fan out across federated nodes. This keeps
owner-local execution available during partitions and makes ownership and
recovery deterministic.

See [Reliability Guide](reliability.md), [Cluster Guide](cluster.md), and
[Model Runtime](model-runtime.md) for operational procedures.
