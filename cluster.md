# Federation Guide

This guide describes how MirrorNeuron connects independent runtime Cores,
selects one owner for each job, and preserves owner-local operation during a
network partition.

## Architecture

Every machine runs a complete Core with its own writable Redis, API, runtime
services, and LiteLLM gateway. Federation uses authenticated gRPC peer calls;
it does not use a shared Redis, shared BEAM membership, Horde supervision, or a
shared Erlang cookie.

A job has exactly one `owner_node`. The owner stores its authoritative state
and runs all agents, leases, schedules, and execution controls for that job.
Explicit ownership takes priority; otherwise resource and model selection
chooses one eligible owner before job creation. Federated peers keep only
summary projections of remote jobs.

## Network requirements

Permit these endpoints only between trusted LAN or VPN peers:

| Port | Purpose |
| --- | --- |
| `55051` | Core gRPC federation control and forwarded owner requests. |
| `4000` | Private LiteLLM gateway-to-gateway model routing. |
| Syncthing ports | Optional blob transport when `cluster.storage` is enabled. |

Redis, Redis Sentinel, EPMD, and BEAM distribution ports do not need to be
reachable between hosts. Each Redis stays local to its Core. LiteLLM port
`4000` is published for authenticated peer gateways, so restrict it with the
host firewall rather than exposing it to an untrusted network.

Each Core advertises a federation-reachable gRPC host and port. Use `--host`
when automatic address selection would choose the wrong interface:

```bash
mn runtime start --host <this-node-lan-or-vpn-address>
```

## Start and join two nodes

There is no leader/worker start distinction. Start the same full runtime on
both machines:

```bash
mn runtime start
```

Successful startup prints:

- the advertised host and gRPC endpoint;
- the node identity;
- the active federation join token; and
- the exact `mn node add` command for another peer.

On one already-running node, execute the add command printed by the other:

```bash
mn node add <peer-host> --token <join-token>
```

The add operation authenticates the token, verifies distinct writable store
identities, registers both peers, clears stale legacy links, and waits for
reciprocal federation readiness. It returns success only after both sides are
online and job-capable. Repeating the same identity/endpoint join is
idempotent; identity conflicts fail without replacing the existing peer.

The join token is a credential. Keep startup output private and rotate it if
exposed:

```bash
mn node refresh-token
```

The former `mn runtime start --worker` option is removed. Every runtime can own
jobs and resume its local work independently.

## Verify federation

From either machine:

```bash
mn node list
mn node show <peer-node>
mn runtime status
mn resource show
```

Expected signs include:

- both Cores report different coordination-store identities;
- the peer has `connection_mode=federated`, is online, and is job-owner
  eligible;
- the peer is absent from BEAM `connected_nodes`; and
- each node reports its own local scheduler eligibility and resources.

`POST /api/v1/nodes` uses the same SDK orchestration as the CLI. It returns
`201` with `Location` only after reciprocal readiness. Authentication,
readiness, or rollback failures return a sanitized error instead of premature
success.

## Job ownership and routing

Create a job for a chosen Core with the appropriate CLI or API `owner_node`
field/`--node` option. If ownership is omitted, the resource/model selector
chooses one eligible Core before creation. The chosen owner schedules every
agent locally; federation never splits one job's agents across peers.

Requests received by another peer are forwarded to the owner with
authenticated loop-prevention metadata. The owner validates ownership before
applying the operation. The receiving peer caches only returned job/run
summaries with:

- `owner_available`;
- `projection_level=summary`;
- `projection_stale`; and
- `last_synced_at`.

## Partition behavior

If federation connectivity is lost:

- existing jobs continue on their owner Core;
- direct API/CLI access to that owner remains functional;
- peers can return previously cached summary projections, marked stale; and
- cross-peer mutations, streams, logs, artifacts, and uncached reads return
  `503 MN_NODE_UNAVAILABLE` and are not queued.

After reconnection, reciprocal status and summary projections refresh. A Core
that was federation-unlocked remains job-capable after restarting while
disconnected because that state is persisted locally.

## Model routing

All agents call their job owner's LiteLLM gateway, even for local models:

```text
local model:  agent -> owner LiteLLM -> owner DMR
remote model: agent -> owner LiteLLM -> peer LiteLLM -> peer DMR
```

An agent must never use a direct Docker Model Runner `:12434` endpoint. Local
installations win for duplicate model IDs. A remote or alternate model is used
only through an explicitly declared LiteLLM fallback.

## Shared blobs are optional

Syncthing can replicate submissions, executable bundles, intermediate
artifacts, and outputs between local shared-storage roots. This is blob
transport only; it does not share Redis, job state, leases, or scheduling.

Set `MN_SYNCTHING_REQUIRED=1` when failure to establish the optional storage
sidecar should stop startup. Derived HostLocal environments and checkpoints
remain node-local under `$MN_HOME/cache` and `$MN_HOME/checkpoints`.

The Syncthing API key is sensitive. Do not paste it or the federation join
token into tickets, test reports, or shared command output.

## Node operations

Maintenance and drain controls change whether a Core can be selected as the
owner of new jobs. They do not migrate individual agents from an existing job
to another peer; the job remains single-home.

```bash
mn node maintenance <node> --enable --reason "host maintenance"
mn node drain <node> --reason "host maintenance" --wait
mn node undrain <node> --reason "host ready" --mark-eligible
```

Use an independent owner-local job on another eligible Core when capacity is
needed during maintenance.

## Troubleshooting

### Join returns `MN_NODE_UNAVAILABLE`

Confirm the peer's advertised gRPC address is reachable and that both Cores
are healthy. The join does not return success after only one-sided
registration; fix connectivity and repeat the same idempotent command.

### Store identity conflict

Both Cores are using the same Redis identity. Stop the joining node, configure
a distinct writable Redis, and retry. Legacy shared-store deployments must
drain jobs and rejoin; there is no implicit data migration.

### Remote job summaries are stale

The owner is unreachable. Read the summary as cached evidence only. Connect
directly to the owner for local controls or restore federation connectivity;
mutations are intentionally not queued elsewhere.

### Remote model route fails

Verify port `4000` between trusted peers and inspect both LiteLLM gateway
health checks. Do not bypass the gateways with a direct DMR URL.

## Related docs

- [Federation Architecture](cluster_architecture.md)
- [Reliability Guide](reliability.md)
- [Resources and Devices](resources-and-devices.md)
- [CLI Reference](cli.md)
- [Model Runtime](model-runtime.md)
- [Troubleshooting](troubleshooting.md)
