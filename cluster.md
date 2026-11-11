# Federation Guide

This guide describes how MirrorNeuron connects independent runtime Cores,
selects one owner for each job, and preserves owner-local operation during a
network partition.

## Architecture

Each runtime node runs Core, `mn_runtime`, its own writable Redis, and the
execution services it needs. A separate CLI/API surface can attach to an entry
runtime. Core peers federate over authenticated gRPC and keep independent
coordination stores. See the [architecture diagram](runtime-architecture.md#application-surface-and-runtime-nodes).

A job has exactly one `owner_node`. The owner stores its authoritative state
and runs all agents, leases, schedules, and execution controls for that job.
Explicit ownership takes priority; otherwise resource and model selection
chooses one eligible owner before job creation. Federated peers keep only
summary projections of remote jobs.

## Network requirements

Permit these endpoints only between trusted LAN or VPN peers:

| Port            | Purpose                                                    |
| --------------- | ---------------------------------------------------------- |
| `55051`         | Core gRPC federation control and forwarded owner requests. |
| `4000`          | Private LiteLLM gateway-to-gateway model routing.          |
| Syncthing ports | Optional blob transport when `cluster.storage` is enabled. |

Redis, Redis Sentinel, EPMD, and BEAM distribution ports do not need to be
reachable between hosts. Each Redis stays local to its Core. LiteLLM port
`4000` is published for authenticated peer gateways, so restrict it with the
host firewall rather than exposing it to an untrusted network.

Each Core advertises a federation-reachable gRPC host and port. Pass `--host`
to the lifecycle command to choose the advertised address explicitly. From the
runtime installation home, replace `<node-address>` with its LAN or VPN address:

```bash
bin/mn-runtime start --host <node-address>
```

## Start and join two nodes

Install and start both runtimes using the combined or runtime-only procedure
in [Installation](installation.md#installation-modes). Each runtime can own
jobs. The connected surface can be on either machine or a third machine.

Only join runtimes in the same trust domain. Get each runtime's advertised gRPC
host and the private control credential in its `runtime.token` file. Keep both
credentials out of shared terminal output. From a shell using the surface
installation, set `ENTRY_HOST` and `PEER_HOST` to the respective hosts and
`ENTRY_TOKEN` and `PEER_TOKEN` to their runtime control tokens. Add the entry
runtime first, then the peer. A fresh combined install already has its local
entry connection, so start with the peer command there.

```bash
mn node add "$ENTRY_HOST" --token "$ENTRY_TOKEN"
mn node add "$PEER_HOST" --token "$PEER_TOKEN"
```

Use `--grpc-port` for an endpoint with a port other than `55051`. On the first
addition, the surface validates and saves its connection. For peer additions,
the entry runtime verifies distinct writable store identities, registers both
peers, and waits until each sees the other as online and job-capable. Repeating
the same peer join is idempotent. Identity conflicts fail without replacing
the existing peer.

## Verify federation

From the attached surface:

```bash
mn node list
mn node show <peer-node>
mn resource show
```

Expected signs include:

- both Cores report different coordination-store identities;
- the peer has `connection_mode=federated`, is online, and is job-owner
  eligible;
- the peer is absent from BEAM `connected_nodes`; and
- each node reports its own local scheduler eligibility and resources.

For local service health, run `bin/mn-runtime status` from the installation
home of each runtime. `POST /api/v1/nodes` uses the same attachment and peer
registration behavior as the CLI. Peer additions return `201` with `Location`
after reciprocal readiness.

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
- a surface with a direct connection to the owner can still reach it;
- peers can return previously cached summary projections, marked stale; and
- ordinary cross-peer mutations, streams, logs, artifacts, and uncached reads
  return `503 MN_NODE_UNAVAILABLE` and are not queued.

Known remote Job archive and confirmed deletion can persist owner-directed
tombstones with `archive_pending` / `delete_pending`. They are lifecycle intents,
not proof that remote cleanup has finished. Reconnection replays those requests;
Run controls have no offline queue. See [Reliability](reliability.md#partition-and-restart-behavior).

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

These are gateway routing capabilities. An admitted Run's managed models,
embeddings, and fallback stay on its reserved owner PC. Another advertised
model does not extend its reservation. Hosted API providers can still receive
requests through the gateway. See
[Model Runtime](model-runtime.md#run-admission-and-model-residency).

## Shared blobs are optional

Syncthing can replicate submissions, executable bundles, intermediate
artifacts, and outputs between local shared-storage roots. This is blob
transport only; it does not share Redis, job state, leases, or scheduling.

Set `MN_SYNCTHING_REQUIRED=1` when failure to establish the optional storage
sidecar should stop startup. Derived HostLocal environments and checkpoints
remain node-local under `$MN_HOME/cache` and `$MN_HOME/checkpoints`.

Keep Syncthing API keys, runtime tokens, and peer credentials out of tickets,
test reports, and shared command output.

## Node operations

Maintenance and drain controls change whether a Core can be selected as the
owner of new jobs. Its current jobs retain their owner.

```bash
mn node maintenance <node> --enable --reason "host maintenance"
mn node drain <node> --reason "host maintenance" --wait
mn node undrain <node> --reason "host ready" --mark-eligible
```

Use an independent owner-local job on another eligible Core when capacity is
needed during maintenance.

Drain a runtime and let its work finish before removing it with `mn node remove`.
Removal checks drain and admission state, removes cluster membership, and leaves
the runtime services and files in place. Removing the entry node also clears
the surface's saved connection.

## Moving an idle Job

`RelocateJob` transfers an idle durable definition and its data; it does not move
an active Run. Prerequisites are terminal Runs, completed resource cleanup,
paused schedules, portable storage, and a reachable compatible destination.
Review the Job's data and keep a backup before changing ownership.

From any directory with the CLI installed and access to the configured Core:

```bash
mn job relocate <job-id> --node <destination-node>
mn job show <job-id>
```

Core freezes source starts/configuration and its responder, verifies a streamed
inactive destination, commits source ownership, then permits destination
activation. Old-owner Job controls redirect to the new owner; historical Run
ownership is resolved separately. History, artifacts, and paused schedules are
transferred as evidence without replaying old executions. Source data remains
a recovery copy and source resources retire only after destination activation.

Retry the same transfer after an interruption. Before ownership commit, abort
can restore source availability:

```bash
mn job relocate <job-id> --node <destination-node> --abort
```

After commit, retry completes activation and cleanup; abort cannot restore the
old ownership. Inspect the resulting Job owner and transfer state before
starting new work. Unrelated destination Job IDs are never overwritten.

Sources: Core `runtime/job_relocation.ex`, `job_relocation_reconciler.ex`,
`backup/relocation_restore.ex`, CLI `job_definition_cmds.py`, and the relocation
tests. Offline unit checks do not establish live two-PC transfer behavior.

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
ordinary mutations and Run controls are not queued elsewhere.

The pending archive/delete exception is described under
[Partition behavior](#partition-behavior); it does not queue ordinary Run controls.

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
