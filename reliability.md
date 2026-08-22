# Reliability Guide

MirrorNeuron is a durable, retryable, message-driven runtime for local and
federated AI systems. It is not a consensus workflow engine. Reliability is
anchored to one job owner: restart work locally, preserve authoritative state
in that owner's Redis, and never move or duplicate a job merely because a peer
cannot reach its owner.

## Reliability goals

MirrorNeuron aims for:

- durable owner-local job, run, event, workflow, lease, and schedule state;
- at-least-once recovery for replayable agent work;
- automatic local restart for transient agent failures;
- continued owner-local execution during a federation partition;
- stale, explicitly marked remote summary projections while an owner is
  unavailable; and
- clear failures when a request cannot reach its authoritative owner.

MirrorNeuron does not provide exactly-once external effects, consensus history
replay, multi-primary Redis conflict resolution, cross-peer agent placement,
or automatic migration of an unavailable owner's jobs.

## Owner-local durable state

Every Core has a distinct writable Redis. The job's `owner_node` stores its
authoritative records, including:

- job definitions, runs, events, and executable bundle references;
- workflow step ledgers and delivery identities;
- agent monitoring, heartbeat, lease, and retry metadata;
- schedules and local scheduler state; and
- restart policy state and terminal reasons.

Federated peers do not write that state. They cache only remote job/run
summaries with `projection_level=summary`, `owner_available`,
`projection_stale`, and `last_synced_at`. A projection is diagnostic evidence,
not a replacement authority.

## Workflow step ledger

Blueprints declaring `workflow.steps` use a durable per-job ledger. Step states
include `pending`, `ready`, `queued`, `running`, `retry_wait`, `blocked`,
`completed`, `partial`, `skipped`, and `failed`.

Each running attempt records its step and attempt identity, assigned agent,
deadline, heartbeat deadline, retry policy, idempotency key, outputs, and
terminal reason. Reconciliation is idempotent:

1. Mark dependency-satisfied steps ready.
2. Queue eligible work unless the run is pausing, paused, cancelling, or
   terminal.
3. Track the current attempt and its liveness.
4. Retry only within the configured local policy.
5. Accept outputs only from the current attempt and idempotency key.
6. Advance downstream work from accepted terminal results.

Messages use at-least-once delivery and dedupe identities. After an owner-Core
restart, the local coordinator reconstructs eligible work from its Redis and
redelivers it when safe. Arbitrary process-local memory is not checkpointed.

## Completion, pause, and cancel

`complete_step` completes the current workflow attempt. `complete_run`
completes the run only from a declared terminal sink after required steps are
terminal. Legacy `complete_job` names are invalid.

Pause stops new attempts and asks active attempts to stop. Resume continues
from the durable ledger. Cancel terminates active local attempts and records a
terminal reason. A peer forwards these controls to the owner; it never applies
them to its cached projection.

If the owner is unreachable, cross-peer controls return
`503 MN_NODE_UNAVAILABLE`. They are not queued for later delivery. Direct
access to the owner remains functional during the same partition.

## Local coordinator and leases

The job coordinator and its Redis lease live on the owner Core. The owner may
restart its coordinator from local durable state after a process or Core
restart. Federated Cores do not supervise one another through Horde, compete
for a shared leader lease, or take over jobs whose owner is offline.

Local schedules, orphan checks, and recovery sweeps operate only on jobs owned
by that Core. This avoids split-brain execution when federation connectivity is
ambiguous.

## Restart policy

Restart policy can be declared at job and agent scope. Common fields are:

| Field | Meaning |
| --- | --- |
| `attempts` | Restarts allowed inside the sliding interval. |
| `interval_ms` | Sliding window used to count attempts. |
| `delay_ms` | Base delay before another attempt. |
| `delay_function` | `constant`, `exponential`, or `fibonacci`. |
| `max_delay_ms` | Maximum calculated delay. |
| `mode` | `fail` or `delay` after attempts are exhausted. |

Restart attempts are counted when recovery begins. A new process is created
from the manifest; eligible durable deliveries may be replayed, but arbitrary
agent-local memory is not restored.

Legacy reschedule fields may still be accepted in stored manifests for schema
compatibility. Federation does not use them to place an agent or job on a
different Core. Choose another owner for a new job when another machine should
run the workload.

## Partition and restart behavior

When a peer link fails:

- each owner continues existing local jobs and schedules;
- other peers mark cached projections stale;
- cross-peer mutations and detailed reads fail immediately;
- no alternate Core claims the unavailable owner's leases; and
- reconnection refreshes reciprocal status and projections.

A federation-unlocked Core persists that state. It can restart while
disconnected and resume its own jobs without rejoining a shared store or BEAM
cluster.

When the owner's Redis is unavailable, durable writes, leases, schedules, and
recovery are affected on that Core. Standalone Redis is an acceptable local
deployment when owner-local availability matches the operator's needs. Redis
Sentinel may protect one Core's store, but its replicas are that Core's HA
boundary; Sentinel is not a federation state-sharing mechanism.

## Model availability

All agent model traffic enters the owner's LiteLLM gateway. Local calls route
to the owner's DMR; declared remote calls route owner gateway to peer gateway
and then to the peer DMR. Loss of the peer model route follows normal model
failure/retry behavior and does not move the owning job. Agents never bypass
LiteLLM with a direct DMR endpoint.

## Replay safety

At-least-once recovery can replay work or outputs. Mark replayable effectful
steps with `safe_to_retry`, `idempotent`, or a stable idempotency key. Use
manual approval/review markers for irreversible external writes.

Common safe patterns include bounded shards, deterministic inputs, durable
delivery IDs, and collector deduplication. Exactly-once behavior for arbitrary
external side effects is the blueprint's responsibility.

## Maintenance and drain

Maintenance and drain make a Core ineligible to own new jobs. Existing jobs
remain single-home. Drain may wait for owner-local batch work or stop it under
the documented policy, but it does not migrate individual agents to a
federated peer.

For planned downtime, stop accepting new ownership, allow or cancel local work,
and create new jobs on another eligible Core when appropriate.

## Verified scenarios

Normal CI protects the architecture with `cluster.federation.local`, including:

- distinct writable stores and no BEAM peer membership;
- reciprocal CLI and API readiness;
- explicit and automatic single-owner selection;
- every agent placed on its job owner;
- stale projections and rejected remote controls during a partition;
- owner-local continuation and disconnected restart autonomy;
- projection refresh after reconnection; and
- mandatory owner-LiteLLM-first model routing.

The gated two-box suites repeat these boundaries on the Mini/Spark network
after exact Git commit parity.

## Current limitations

- Exactly-once delivery and deterministic workflow-history replay are not
  implemented.
- Standalone Redis remains a local single point of failure.
- Cached projections do not contain logs, streams, artifacts, or full job
  state.
- Federation does not migrate an offline owner's active jobs.
- Resource metadata guides owner selection but is not hard OS isolation.

## Related docs

- [Federation Guide](cluster.md)
- [Federation Architecture](cluster_architecture.md)
- [Resources and Devices](resources-and-devices.md)
- [Model Runtime](model-runtime.md)
- [Testing](testing.md)
- [Troubleshooting](troubleshooting.md)
