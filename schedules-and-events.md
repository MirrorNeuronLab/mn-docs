# Schedules And Events

For operators and integrators, this reference explains owner-local scheduled
Runs, service lifecycle schedules, and queued-start controls in the current
checkout. It assumes a prepared durable Job and authenticated runtime access.
Core's `runtime/schedule_policy.ex`, `schedule_dispatcher.ex`,
`schedule_occurrence.ex`, `node_admission.ex`, `proto/job.proto`, and the CLI/API
adapters own this behavior. This is checkout verification, not a new release
promise. See [Changes](changes.md#validation) for tests and live-test limits.

## Design Concept

A schedule targets a durable `job_id` on its existing owner Core. A batch
occurrence creates a Run of that definition, rather than another configured
Job. A service occurrence manages the Job's single attached Run. All execution
uses the same admission, delivery, and recovery boundaries as a manual start.

Redis stores the schedule identity, kind, enabled/status state, timezone,
next time, definition/bundle reference, source metadata, counters, and bounded
dispatch history. Due processing and schedule leases are owner-local;
federated peers forward requests rather than competing to dispatch the work.

| Kind | Purpose |
| --- | --- |
| `periodic` | Five-field, minute-level cron occurrences in the declared timezone. |
| `delayed` | One occurrence at `run_at` or after `delay_ms`. |
| `event` | Core event matching with declarative payload filters. |
| `resource_wait` | Wait for admissible capacity; also the projection kind for a durable queued Run. |

The public CLI exposes `schedule list`, `show`, `set-time`, and `cancel`.
The retired `schedule add/run/pause/resume/remove` verbs and `event` root are
unavailable. Create schedules through the current blueprint launch options or
the Job schedule API described in [API](api.md#schedules).

## Periodic Jobs

This is the JSON body for `POST /api/v1/jobs/<job-id>/schedules`. It creates
persistent future work; it is not a complete blueprint:

```json
{
  "schedule": {
    "kind": "periodic",
    "crons": ["0 2 * * *"],
    "timezone": "America/New_York",
    "prohibit_overlap": true,
    "missed_policy": "skip",
    "catchup_limit": 10
  }
}
```

Cron shortcuts include `@hourly`, `@daily`, `@weekly`, `@monthly`, `@yearly`,
and `@annually`. Core defaults the timezone to UTC; supply it explicitly when
local civil time matters.

## Delayed Jobs

A delayed schedule accepts either a future ISO 8601 `run_at` with timezone
or a positive `delay_ms`. For a reviewed local blueprint, run from a directory
where `./my-blueprint` exists, with its prerequisites prepared and runtime
credentials configured:

```bash
mn blueprint run ./my-blueprint --schedule 30m
```

This prepares a durable Job and records a delayed start. Retain the returned
Job and schedule IDs, then inspect the schedule through `mn schedule show`.
Cancel it before dispatch if the work is no longer wanted. After dispatch,
control the resulting Run instead; cancelling a schedule cannot undo effects
already performed by a worker.

`--schedule` also accepts schedule JSON or an ISO timestamp. `--auto-schedule`
creates a resource-wait schedule and cannot be combined with `--schedule`.
For an immediate attempt that may queue the same Run when busy, use `--queue`;
see [CLI](cli.md#jobs-and-runs) for that distinct start policy.

## Event-Triggered Jobs

Core's dispatcher supports event types and declarative filters. Values can
match exact values, a list of allowed values, or string `prefix` / `contains`
conditions. For example, this is a Core trigger fragment:

```json
{
  "triggers": [
    {
      "name": "dataset-uploaded",
      "enabled": true,
      "event_type": "file_uploaded",
      "filters": {"path": {"prefix": "/datasets/"}}
    }
  ]
}
```

Matching does not execute code in the filter. Core support does not imply a
public emitter: the current CLI has no `event` group and REST v1 does not expose
`/trigger-events` or manual schedule `/dispatches`. Integrations must use an
actually supported producer; do not copy the retired emitter commands.

## Schedule Operations

From any directory with the CLI installed and credentials for the configured
Core, inspect an owner's schedules. `<owner-node>` is its exact Core identity;
`<schedule-id>` is returned by creation or listing:

```bash
mn schedule list --node <owner-node>
mn schedule show <schedule-id> --node <owner-node>
```

For an accepted queued Run, the schedule ID is `queue_<run-id>`. To defer its
unstarted execution, choose `<future-time>` as a future ISO 8601 timestamp
including timezone:

```bash
mn schedule set-time queue_<run-id> --at <future-time> --node <owner-node>
mn schedule show queue_<run-id> --node <owner-node>
```

Deferral retains the same Run identity and holds no capacity until eligibility.
It becomes eligible in the same owner queue when due. To cancel only unstarted
work:

```bash
mn schedule cancel queue_<run-id> --node <owner-node>
```

The equivalent Run control is `mn run cancel <run-id> --queued-only`. Core
revision/start gates reject a stale cancellation once execution has been
admitted. There is no undo for a cancelled queued start; a later intentional
start is a new request. Read the resulting state after every mutation.

Ordinary schedule changes use optimistic revisions. REST exposes ETags and
requires `If-Match`; the CLI fetches the current revision before changing or
deleting a schedule. See [API](api.md#schedules) for exact request bodies.

## Missed Runs And Overlap

`prohibit_overlap` defaults to `true`. An active prior batch dispatch blocks
another occurrence unless overlap is explicitly allowed. Capacity contention
uses owner admission's durable queue and does not bypass this policy.

| Missed policy | Behavior |
| --- | --- |
| `skip` | Skip occurrences outside the missed grace. |
| `catchup_one` | Dispatch one missed occurrence. |
| `catchup_all` | Dispatch missed occurrences up to `catchup_limit`. |

Before batch dispatch, a durable occurrence receipt binds the schedule and
occurrence to one execution ID. Only its creator may submit. A replay returns
the original receipt or verifies that exact Run's dispatch metadata, even after
dispatcher lease expiry or Run retention. Event identity, rather than retry
time, identifies an event occurrence.

An interrupted reservation without a verifiable Run reports
`schedule_occurrence_unconfirmed` for operator review. It cannot silently
submit another execution. Receipt replay preserves the original submission
time and execution window. Receipts live until their owning schedule is deleted.

## Service lifecycle schedules

Service schedules operate on the single attached Run:

| Existing state | Occurrence action |
| --- | --- |
| No Run | Start one. |
| Paused | Resume the same Run. |
| Pending/running | Record an already-running no-op. |
| Terminal | Clear terminal run history and attach a fresh Run. |
| Cancelling or ambiguous active history | Block for cleanup/review. |

Review run evidence before enabling a service schedule: replacement permanently
removes old run-scoped history and artifacts. Job configuration, schedules, and
persistent data remain. A service window end pauses the Run; overlapping
windows pause it only when the last window closes. Pausing retains its resource
claim, so it does not return capacity to the PC queue.

## Important Code

| Area | Files |
| --- | --- |
| Policy, cron, and event matching | `MirrorNeuron/lib/mirror_neuron/runtime/schedule_policy.ex` |
| Owner dispatch and service windows | `MirrorNeuron/lib/mirror_neuron/runtime/schedule_dispatcher.ex` |
| Durable batch occurrence identity | `MirrorNeuron/lib/mirror_neuron/runtime/schedule_occurrence.ex` |
| Queued-start projection and fencing | `MirrorNeuron/lib/mirror_neuron/runtime/node_admission.ex` |
| Public gRPC contract | `MirrorNeuron/proto/job.proto`, `lib/mirror_neuron_grpc/handlers/job.ex` |
| Public CLI | `mn-cli/mn_cli/libs/schedule_cmds.py`, `run_cmds/common.py` |
| Public REST | `mn-api/mn_api/routes/v1/jobs.py`, `api_models.py` |

## V1 Limits

- Schedules reuse ordinary Run execution; they are not another workflow engine.
- Event filters are declarative and require an available producer.
- The current public interfaces do not expose general deployment or event-emitter commands.
- Source/unit checks do not prove clock, Redis failover, or multi-PC behavior on an installed deployment.
