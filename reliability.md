# Reliability Guide

This guide explains the reliability model implemented in MirrorNeuron.

MirrorNeuron is not a consensus workflow engine. It is a durable, retryable, message-driven runtime for small local and multi-computer AI labs. Its reliability design is practical and conservative: restart locally first, reschedule across nodes only when policy and safety allow it, and pause for review when automatic movement could duplicate unsafe side effects.

## Reliability Goals

MirrorNeuron aims for:

- durable job records, events, snapshots, leases, and recovery metadata
- at-least-once recovery for replayable agent work
- automatic local restart for transient worker failures
- automatic cross-node rescheduling for safe `cluster_recover` jobs
- graceful node maintenance and drain without placing new work on a node
- clear operator status when recovery pauses or blocks

MirrorNeuron does not provide:

- exactly-once delivery
- consensus-based workflow history replay
- multi-primary Redis conflict resolution
- automatic movement of work that is marked unsafe or manual-only

## Durable State

Redis is the shared durable state store. MirrorNeuron persists:

- job records and status
- job event history
- durable job bundle references
- agent snapshots and heartbeats
- job coordinator leases such as `job:<job_id>`
- the cluster leader lease `cluster:leader`
- workflow step ledgers stored on jobs as `workflow_state`
- node state, profile health, capabilities, and drain metadata
- recovery evals used by the reconciler
- restart/reschedule `policy_state`

Agent snapshots are the core recovery unit. They include the assigned node, processed message count, inflight message, pending messages, encoded local state, and last heartbeat timestamp.

This is enough for replay-oriented recovery. It is not a full deterministic event history.

## Workflow Step Ledger

Blueprints that declare `workflow.steps` use a durable workflow-control layer in addition to agent snapshots. The runtime treats `workflow.steps` as the source of truth for the workflow and stores per-step execution state in the job's `workflow_state` field.

Step status values are:

- `pending`
- `ready`
- `queued`
- `running`
- `retry_wait`
- `blocked`
- `completed`
- `partial`
- `skipped`
- `failed`

Every running step attempt is bounded work. The ledger records the `step_id`, `attempt_id`, current attempt number, assigned `agent_id`, dispatch message id, `deadline_at`, `heartbeat_deadline_at`, retry policy, idempotency key, outputs, and terminal reason. Dispatch payloads include the same workflow metadata so workers can report back with enough context for the coordinator to reject stale results.

The job coordinator reconciles the ledger on a short interval, normally around 1 to 2 seconds. Reconciliation is idempotent:

1. Mark dependency-satisfied steps as `ready`.
2. Queue eligible work unless the job is pausing, paused, cancelling, or terminal.
3. Mark dispatched attempts as `running`.
4. Refresh liveness when the step emits a beacon.
5. Fail only the current attempt when its deadline or heartbeat deadline is exceeded.
6. Schedule retry/backoff while attempts remain.
7. Apply the step failure policy after attempts are exhausted.
8. Advance dependent steps only from accepted current-attempt outputs.

Workflow messages are tracked with at-least-once delivery and idempotency. A message can move through states such as `created`, `dispatched`, `acked`, `failed`, and `dead_lettered`. If a coordinator restarts while work is queued or in flight, it reconstructs the ledger from durable state and safely redelivers eligible messages using dedupe keys.

Stale outputs from old attempts are ignored. A worker result must match the current `attempt_id` and idempotency key before it can complete a step or unlock downstream dependencies.

## Completion Naming

Workflow completion is explicit:

- `complete_step` marks the current workflow step attempt complete.
- `complete_run` completes the whole job only from a declared terminal sink after `workflow_state` shows all required steps are terminal.
- `complete_job` and `complete_job?` are invalid legacy names.

Executor stdout may emit structured JSON with `complete_step` or `complete_run`. Runtime actions use `{:complete_step, result}` and `{:complete_run, result}`. Workflow-bound worker nodes must not declare `complete_run`; final collectors must declare `terminal_sink: true` and `complete_run: true`. A non-terminal join that uses `complete_on_message: true` must declare an `output_message_type`.

## Workflow Liveness

Workflow executor steps use `agent_beacon` as the standard liveness signal. The OtterDesk default is:

| Field | Default |
| --- | --- |
| Beacon event | `agent_beacon` |
| Beacon interval | `15s` |
| Beacon timeout | `45s` |
| Missed beacon action | `fail_attempt` |

The host runner emits runtime beacons while a command is alive, and worker scripts can emit richer activity beacons when they know what they are doing. A missed required beacon fails the current attempt with a retryable timeout-style reason. Existing retry and failure policies decide whether the step retries, becomes partial/skipped, or fails the job.

Job details should render from `workflow_state` and workflow events. A healthy long step shows fresh liveness, a retrying step shows `retry_wait` and the next retry time, and a dependency problem shows `blocked` with the dependency reason instead of silently remaining `running`.

## Workflow Pause And Cancel

Pause and cancel are reconciled through the same ledger:

- `pause` sets the job to `pausing`, stops scheduling new attempts, and asks active attempts to stop.
- Once active attempts stop or hit their deadline, the job becomes `paused`.
- `resume` re-enters reconciliation from `workflow_state` and schedules only eligible steps.
- `cancel` terminates active attempts and records a terminal reason.

No step should rely only on in-memory progress. After a coordinator restart, the replacement coordinator reconstructs state from the manifest, job record, workflow ledger, and events, then resumes reconciliation.

## Coordinator And Leader Leases

Each running job has a job coordinator process supervised through `Horde`.

The coordinator owns a Redis job lease. If its node dies, Horde may start a replacement coordinator on another peer, but the Redis lease remains the durable guardrail that prevents two coordinators from assuming ownership at the same time.

Cluster-wide sweeps are handled by a Redis-elected leader:

1. A runtime node acquires `cluster:leader`.
2. The leader periodically refreshes that lease.
3. If the leader dies or loses Redis, the lease expires.
4. Another node acquires the lease and resumes sweeps.

The leader sweeps:

- due recovery evals
- due drain retries and deadlines
- due schedules
- orphaned jobs whose coordinator lease is gone

## Job Types

MirrorNeuron supports four lifecycle modes.

| Type | Reliability behavior |
| --- | --- |
| `service` | Long-running. Unexpected completion or missing agents are treated as restartable unless stopped or paused. |
| `batch` | Runs to completion. Failure retries and reschedules are limited by policy. Normal completion is final. |
| `system` | Long-running copy on every eligible node. A completed target is restarted to keep that node covered. |
| `sysbatch` | One-off copy on every eligible node. Each target completes once, and the job completes after all targets finish. |

`system` and `sysbatch` expand one logical agent group across eligible nodes. Runtime agent ids include the target node, for example `monitor@mirror_neuron@<node-host>`, while the scheduler plan keeps the original source agent id for policy lookup.

## Recovery Modes

The effective recovery mode controls how far MirrorNeuron may go automatically.

| Mode | Behavior |
| --- | --- |
| `cluster_recover` | Local restart first, then safe cross-node reschedule when restart policy is exhausted or a node is lost. |
| `local_restart` | Restart locally according to policy. Do not move the job to another node automatically. |
| `manual_recover` | Do not automatically restart or reschedule after failure. Pause for operator review. |

Jobs without effective `cluster_recover` are never moved across machines automatically.

## Restart And Reschedule Policies

MirrorNeuron uses Nomad-inspired policies at job and per-agent scope.

Job-level policies live under `policies.restart` and `policies.reschedule`. Agent-level overrides live under `nodes[].policies.restart` and `nodes[].policies.reschedule`.

Restart policy fields:

| Field | Meaning |
| --- | --- |
| `attempts` | Number of restarts allowed inside the sliding interval. |
| `interval_ms` | Sliding window for counting attempts. |
| `delay_ms` | Base delay before the next restart. |
| `delay_function` | `constant`, `exponential`, or `fibonacci`. |
| `max_delay_ms` | Cap for calculated delay. |
| `mode` | `fail` or `delay` after attempts are exhausted. |

Reschedule policy fields:

| Field | Meaning |
| --- | --- |
| `attempts` | Number of cross-node reschedules allowed inside the sliding interval. |
| `interval_ms` | Sliding window for counting attempts. |
| `delay_ms` | Base delay before the next reschedule. |
| `delay_function` | `constant`, `exponential`, or `fibonacci`. |
| `max_delay_ms` | Cap for calculated delay. |
| `unlimited` | If `true`, attempts do not exhaust. |

Legacy `policies.max_agent_restart_attempts` is still accepted only when `policies.restart.attempts` is absent.

### Defaults

| Job and recovery mode | Restart default | Reschedule default |
| --- | --- | --- |
| `service` / `system` with `cluster_recover` | 3 attempts in 10 minutes, exponential `1s` to `30s`, `mode: fail` | unlimited, exponential `5s` to `5m` |
| `service` / `system` with `local_restart` | 3 attempts in 10 minutes, exponential `1s` to `30s`, `mode: delay` | disabled |
| `batch` / `sysbatch` with `cluster_recover` | 3 attempts in 24 hours, exponential `1s` to `30s`, `mode: fail` | 1 attempt in 24 hours, constant `5s` |
| any job with `manual_recover` | disabled | disabled |

Example:

```json
{
  "policies": {
    "recovery_mode": "cluster_recover",
    "job_type": "service",
    "restart": {
      "attempts": 2,
      "interval_ms": 60000,
      "delay_ms": 1000,
      "delay_function": "exponential",
      "max_delay_ms": 5000,
      "mode": "fail"
    },
    "reschedule": {
      "attempts": 0,
      "interval_ms": 60000,
      "delay_ms": 2000,
      "delay_function": "exponential",
      "max_delay_ms": 30000,
      "unlimited": true
    }
  }
}
```

## Policy State

The runtime persists normalized policies and per-agent state on the job.

`mn job status <job-id>` includes fields such as:

- `restart_policy`
- `reschedule_policy`
- `policy_state`
- `recovery_status`
- `recovery_requires_review`
- `recovery`

Per-agent `policy_state` records:

- restart and reschedule histories
- active attempt counts
- last failure reason
- next action
- next eligible timestamp
- exhausted policy reason

Restart attempts are counted when recovery starts, not only when it succeeds. This prevents a bad startup loop from retrying forever without consuming attempts.

## Local Restart Flow

When an agent is missing, unhealthy, or exits unexpectedly:

1. The job coordinator checks the agent's restart policy.
2. If an attempt is allowed, it records the attempt and schedules a delayed restart.
3. The affected agent worker is terminated if still present.
4. The durable snapshot is loaded.
5. The agent restarts with restored local state, pending messages, and inflight replay data.
6. On success, pending restart timers are cleared.

If restart attempts are exhausted:

- `mode: delay` waits until the sliding window resets, then tries locally again.
- `mode: fail` makes the agent eligible for reschedule if the job is `cluster_recover`.
- `manual_recover` pauses for review.
- `local_restart` pauses long-running service/system work or fails completion-oriented batch/sysbatch work according to job behavior.

Cross-node reschedule after restart exhaustion is launched through an async recovery task so the coordinator does not deadlock by calling a reconciler that may call back into the coordinator.

## Hybrid Automatic Rescheduling

The reconciler handles node loss, orphan sweeps, and policy-driven reschedules through one conservative path.

For affected agents on a failed node:

1. Check that the job is active.
2. Check that effective recovery is `cluster_recover`.
3. Check durable bundle and snapshot safety.
4. Check the reschedule policy unless the trigger is a maintenance drain.
5. Re-plan affected agents with the failed node excluded and the stale job placements ignored.
6. Move only affected agents if the coordinator is alive.
7. Restart the whole job only when the coordinator or job lease is gone.

Agent-level movement uses `only_agent_ids`, `exclude_nodes`, and `ignore_job_ids` so the scheduler does not count stale placements from the same job while computing the replacement plan.

The coordinator handles `reschedule_agents` by:

- terminating only affected live agents
- reloading their durable snapshots
- applying the merged scheduler plan
- restarting those agents with updated `mirror_neuron_target_node`
- emitting per-agent reschedule events

Unaffected agents stay running.

## Node Loss Flow

When a runtime node goes down:

1. `NodeMonitor` marks the node reconnecting.
2. It retries `Node.connect` with exponential backoff.
3. If reconnect succeeds, executor capacity is restored and blocked recovery evals are woken.
4. If reconnect is exhausted, executor capacity for the node is released.
5. The node is marked `disconnected` for the disconnect grace window.
6. During grace, recovery may wait instead of moving node-scoped work too quickly.
7. When grace expires, the node is marked `offline`.
8. The leader runs orphan and recovery sweeps.

This avoids turning a short network hiccup into unnecessary cross-node movement.

## Recovery Safety Checks

Automatic recovery pauses for review when safety is uncertain.

MirrorNeuron blocks or pauses when:

- required agent snapshots are missing
- checkpoints are corrupt
- the durable job bundle is unavailable
- the job was already paused before runtime loss
- the job uses `manual_recover`
- an active or queued step has unsafe side effects
- an executor has no retry-safety marker

Executor steps are considered safer to replay when their config includes one of:

- `safe_to_retry: true`
- `idempotent: true`
- `idempotency_key`
- `recovery_idempotency_key`

Unsafe markers include:

- `manual_review_on_recovery`
- `requires_approval`
- `unsafe`
- `safe_to_retry: false`
- `idempotent: false`
- side effects marked as external writes

The goal is to move replayable work automatically and stop before duplicating irreversible external effects.

## Recovery Evals

Recovery evals are durable records for reconciliation work.

They let the leader retry recovery when placement is temporarily blocked. A blocked eval stores its reason and `wait_until` timestamp. Placement-blocked evals do not consume reschedule policy attempts until a real placement attempt is made.

The retry backoff for recovery eval infrastructure is separate from job reschedule policy:

- recovery eval backoff answers "when should the control plane retry this blocked eval?"
- reschedule policy answers "is this workload allowed to try another placement?"

## Drain And Maintenance Reliability

Maintenance mode is a cordon. It stops new placements but leaves current work alone.

Drain mode is a graceful migration workflow:

- mark the node `draining`
- set `scheduling_eligible` to `false`
- migrate safe long-running service work
- let batch work finish before the deadline
- ignore `system` and `sysbatch` by default
- pause unsafe leftovers for review at the deadline
- leave the node in maintenance when the drain completes

Drain migrations do not consume failure reschedule attempts because they are operator-requested maintenance moves, not workload failures.

The leader also processes due drains so blocked drains can make progress after capacity changes or deadlines expire.

## Replay And Deduplication

MirrorNeuron uses at-least-once recovery.

That means work or output can be replayed after failure. To make common fan-out/fan-in jobs safer:

- executors persist their last emitted output payload
- recovery can re-emit completed executor output if the downstream collector did not durably observe it
- the built-in aggregator dedupes replayed executor results by `agent_id` when that field is present

This works well for one-result-per-worker patterns such as prime sweep shards. It is not a universal exactly-once system for arbitrary streams.

## Redis HA

Single Redis mode remains the simplest development setup, but it is a single point of failure.

Redis Sentinel mode provides an authoritative primary with replica promotion:

- MirrorNeuron writes to the Sentinel-elected primary.
- If the primary dies, Sentinel promotes a replica.
- MirrorNeuron re-resolves the primary and reconnects.
- `READONLY` and connection errors are retried during promotion.
- Optional `MN_REDIS_WAIT_REPLICAS` asks Redis to wait for replica acknowledgement after durable writes.

See [Redis High Availability](redis-ha.md) for setup and smoke tests.

## Verified Scenarios

The current design has targeted unit, runtime, CLI, SDK, and joined-cluster coverage for:

- scheduler exclusion of offline, draining, maintenance, and ineligible nodes
- partial agent replanning with stale placement ignoring
- service and batch lifecycle behavior
- system and sysbatch expansion across eligible nodes
- restart policy normalization, delay functions, window exhaustion, and legacy fallback
- reschedule policy enforcement and unlimited mode
- node loss reconciliation with live coordinator agent movement
- whole-job recovery when the coordinator lease is gone
- safe pause behavior for missing snapshots, corrupt snapshots, unsafe active steps, and manual recovery
- node drain dry runs, service migration, batch waiting, system job ignore, blocked placement, cancellation, and maintenance toggles
- two-box cluster verification using local plus `spark`
- service registry health filtering and required service preflight
- CUDA/Metal/device-memory placement, port conflicts, and host-volume placement
- rolling/canary deployment bookkeeping and service discovery role filtering
- periodic, delayed, and event-triggered dispatch idempotency

Useful smoke tests:

```bash
cd MirrorNeuron
bash scripts/test_cluster_prime_failover_e2e.sh \
  --box1-ip <box1-host> \
  --box2-ip <box2-host> \
  --start 1000003 \
  --end 1006002
```

Redis Sentinel local smoke test:

```bash
cd MirrorNeuron
bash scripts/test_redis_sentinel_ha.sh
```

Two-box Sentinel smoke test:

```bash
cd MirrorNeuron
bash scripts/test_redis_sentinel_two_box_ha.sh \
  --remote-host <remote-host> \
  --local-ip <local-host> \
  --remote-ip <remote-host>
```

## Failure Model To Expect

When an executor node dies:

- jobs continue if the coordinator and durable state are healthy
- replayable agents can restart locally or move to another node
- some work may be replayed
- throughput drops because capacity is gone
- completion may take longer
- unsafe work pauses for review

When the coordinator node dies:

- the job lease eventually expires
- the leader sweep detects the orphan
- the durable bundle is loaded
- a fresh scheduler plan is computed
- the whole job is restarted only if recovery policy and safety allow it

When Redis is unavailable:

- durable writes, leases, recovery evals, and job status are affected
- Sentinel mode can recover after primary promotion
- single Redis mode cannot tolerate Redis loss

## Practical Guidance

For the most reliable behavior:

- use `cluster_recover` only for work that is safe to replay
- mark unsafe executor steps with manual review or approval fields
- give replayable executors an idempotency marker
- keep work split into bounded shards
- prefer deterministic worker payloads
- use `service` for long-running workers and APIs
- use `batch` for finite evals and data processing
- use `system` for per-node monitors and local workers
- use `sysbatch` for per-node diagnostics and cache warmups
- use maintenance before planned reboot when work can stay in place
- use drain before planned reboot when safe work should move away
- use Redis Sentinel HA for real multi-box reliability

## Current Limitations

MirrorNeuron still has important limits:

- exactly-once delivery is not implemented
- arbitrary stream dedupe is not automatic
- full deterministic workflow-history replay is not implemented
- single Redis mode remains a single point of failure
- two-box Sentinel quorum settings are useful for lab smoke tests but not production-grade partition handling
- resource/device placement records are scheduling hints and allocation metadata, not hard OS isolation
- volumes are validated and advertised, but core does not mount them automatically
- service health affects discovery and placement, but does not automatically restart services yet
- scheduled jobs are ordinary child jobs, not a separate deterministic scheduler engine

## Related Docs

- [Cluster Guide](cluster.md)
- [Nomad-Inspired Runtime Features](nomad-inspired-runtime.md)
- [Services and Health Checks](services-and-health-checks.md)
- [Resources and Devices](resources-and-devices.md)
- [Deployments](deployments.md)
- [Schedules and Events](schedules-and-events.md)
- [Redis High Availability](redis-ha.md)
- [Runtime Architecture](runtime-architecture.md)
- [Job Bundle Format](bundle.md)
- [Testing](testing.md)
- [Troubleshooting](troubleshooting.md)
