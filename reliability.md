# Reliability Guide

For operators and runtime maintainers, this explanation defines durable state,
replay, pause/cancel, and recovery boundaries in the current checkout. It assumes
a configured owner Core and Redis; it does not establish a release SLA. Sources
are Core's persistence, workflow, cancellation, recovery, and admission modules
and their focused tests. [Changes](changes.md#validation) records which paths
were exercised and which require live integration validation.

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

Redis is the coordination authority. Agent monitoring projections contain
bounded liveness/queue/error fields, not arbitrary agent memory or in-flight
payload copies. Local disk checkpoints cannot authorize workflow recovery.
Persistent Job data has a separate lifetime from Runs, submissions, and
artifacts; run retention and cleanup must not delete it.

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
from the durable ledger, retaining remaining step, heartbeat, child-workflow,
and retry budgets. HostLocal and DockerWorker pause/resume waits for interrupted
commands to relinquish their processes. Paused runs retain resource reservations
and managed-model references. A peer forwards these controls to the owner; it
never applies them to its cached projection.

If the owner is unreachable, cross-peer controls return
`503 MN_NODE_UNAVAILABLE`. Run controls are not queued for later delivery.
The limited offline Job archive/delete exception is described under
[Partition and restart behavior](#partition-and-restart-behavior).
Direct access to the owner remains functional during the same partition.

## Cancellation and cleanup

Cancellation first commits durable intent and revokes the old lease epoch.
`cancelling` is fenced and non-recoverable: stale writes, resume, recovery,
schedule dispatch, and drain migration cannot restart that attempt while cleanup
is pending. Cleanup targets owned HostLocal process groups, Docker invocations
and projects, OpenShell sandboxes, services, leases, deliveries, and run data on
the recorded runtime nodes.

Unreachable nodes can leave cleanup pending. An internal cancellation tombstone
retains those nodes and the write fence even if public run records are cleared.
Rejoining nodes acknowledge cleanup without recreating deleted public state.
An accepted cancellation or deletion therefore does not prove that every remote
process or byte has already been removed.

Terminal status also does not prove resource capacity has returned. Admission
releases a claim only after owned execution stops, inference drains, and
run-owned model residency is released. Failed/uncertain cleanup retains the
claim for reconciliation; timeout or owner unavailability cannot free it. See
[Resources and Devices](resources-and-devices.md#admission-and-queueing).

Archive retains Job data. Data reset advances its generation. Confirmed Job
deletion cancels/clears its runs and retires definition-owned resources before
removing persistent data. Run deletion leaves the durable definition's data
intact. Review retained artifacts before a destructive replacement or deletion;
neither completion nor a cleanup acknowledgement establishes domain correctness.

## Local coordinator and leases

The job coordinator and its Redis lease live on the owner Core. The owner may
restart its coordinator from local durable state after a process or Core
restart. Federated Cores do not supervise one another through Horde, compete
for a shared leader lease, or take over jobs whose owner is offline.

Local schedules, orphan checks, and recovery sweeps operate only on jobs owned
by that Core. This avoids split-brain execution when federation connectivity is
ambiguous.

Recovery verifies runtime identity, bundle compatibility, ownership, and
manifest-declared retry safety before seeding a clean attempt. An unsafe
effectful worker pauses for operator review. `paused_for_review` is stable:
periodic reconciliation does not create a new recovery evaluation on every scan.
Automatic clean-attempt recovery and explicit checkpoint retry have different
restoration contracts.

## Manual checkpoint retry

Failed runs can expose a `mn.run_checkpoint/v1` plan through `PlanRunRetry`.
`RetryRun` requires explicit overrides, expected attempt, checkpoint revision,
and an idempotency key; Core revalidates under the lifecycle/start gate and
reacquires owner capacity or explicitly queues the retry.

The checkpoint binds ledger v3, Job/run identity, attempt, immutable
manifest/input digests, Job-data generation, and artifact integrity. Completed
steps and accepted dynamic/child topology can be restored; unfinished work
restarts from retained inputs. Arbitrary process memory is excluded. Dependency
failure skips can reopen after verified classification, while intentional
branch skips remain preserved. Missing artifacts or uncertain external effects
block dispatch.

Acceptance preserves Job/run IDs, advances attempt and lease epoch, and records
attempt history. Only declared retry-adjustable budget/connection fields may
change; topology, bundle, and inputs remain bound. Earlier attempt writes and
completion markers are fenced. Failed-run checkpoint evidence is retained
beyond ordinary terminal retention until explicit deletion or data reset.
Use the [CLI retry interface](cli.md#jobs-and-runs) or
[REST retry routes](api.md#checkpoint-retry) to inspect a plan before requesting it.

## Restart policy

Restart policy can be declared at job and agent scope. Common fields are:

| Field            | Meaning                                         |
| ---------------- | ----------------------------------------------- |
| `attempts`       | Restarts allowed inside the sliding interval.   |
| `interval_ms`    | Sliding window used to count attempts.          |
| `delay_ms`       | Base delay before another attempt.              |
| `delay_function` | `constant`, `exponential`, or `fibonacci`.      |
| `max_delay_ms`   | Maximum calculated delay.                       |
| `mode`           | `fail` or `delay` after attempts are exhausted. |

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
- ordinary cross-peer mutations and detailed reads fail when the owner cannot be reached;
- no alternate Core claims the unavailable owner's leases; and
- reconnection refreshes reciprocal status and projections.

Known remote Job archive and confirmed Job deletion are explicit exceptions.
The receiving Core can durably store an owner-directed tombstone:

| Pending status    | Meaning                                                                                       |
| ----------------- | --------------------------------------------------------------------------------------------- |
| `archive_pending` | The cached Job reflects archive intent; the owner has not applied it yet.                     |
| `delete_pending`  | Normal cached lists hide the definition/runs; owner cleanup and data deletion remain pending. |

Reconnection replays these lifecycle requests. A reachable owner response clears
the tombstone, including a rejected request; it does not become an unlimited
retry policy. Other mutations and Run controls receive no such offline queue.

A federation-unlocked Core persists that state. It can restart while
disconnected and resume its own jobs without rejoining a shared store or BEAM
cluster.

When the owner's Redis is unavailable, durable writes, leases, schedules, and
recovery are affected on that Core. Standalone Redis is an acceptable local
deployment when owner-local availability matches the operator's needs. Redis
Sentinel may protect one Core's store, but its replicas are that Core's HA
boundary; Sentinel is not a federation state-sharing mechanism.

## Model availability

Agent model traffic enters the owner's LiteLLM gateway. Admitted runs keep
managed models, embeddings, and fallback on their reserved PC; hosted provider
routes remain supported. A peer route in the registry cannot grant run capacity
or relocate the Job. Agents never bypass LiteLLM with a direct DMR endpoint.

Managed residency is owned by run and attempt. Pause retains it; terminal
cleanup closes that attempt's references. The last reference unloads inference
weights after requests drain while preserving downloaded artifacts and
installation. Delayed cleanup cannot release a later checkpoint retry's model.
See [Model Runtime](model-runtime.md#run-admission-and-model-residency).

## Replay safety

At-least-once recovery can replay work or outputs. Mark replayable effectful
steps with `safe_to_retry`, `idempotent`, or a stable idempotency key. Use
manual approval/review markers for irreversible external writes.

Common safe patterns include bounded shards, deterministic inputs, durable
delivery IDs, and collector deduplication. Exactly-once behavior for arbitrary
external side effects is the blueprint's responsibility.

Artifact-handoff receipts are a narrow disk-recovery exception: Core can repair
publication of an already executed result without rerunning the command. They
do not restore agent memory or replace Redis coordination. An uncertain isolated
dispatch without trustworthy completion is `unknown_blocked` and requires an
explicit new run. Only verified receipt publication can authorize completion.
See [Runtime Architecture](runtime-architecture.md#why-artifacts-matter).

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
- Resource reservations and native request fencing do not provide hard OS isolation.
- Installed Core, native SDK, gateway, and prepared worker versions must agree;
  updating source does not update a running image or a saved worker container.

## Related docs

- [Federation Guide](cluster.md)
- [Federation Architecture](cluster_architecture.md)
- [Resources and Devices](resources-and-devices.md)
- [Model Runtime](model-runtime.md)
- [Testing](testing.md)
- [Troubleshooting](troubleshooting.md)
