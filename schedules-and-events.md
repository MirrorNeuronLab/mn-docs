# Schedules And Events

MirrorNeuron runtime now owns periodic, delayed, and event-triggered jobs. This moves scheduling authority out of OtterDesk and into the same runtime layer that already understands resources, services, deployments, and restart/reschedule policy.

Scheduled child jobs are ordinary MirrorNeuron jobs. They get normal reconciliation, resource placement, service preflight, deployment metadata, and reliability behavior.

## Design Concept

Schedules are Redis records with:

- `schedule_id`
- `kind`: `periodic`, `delayed`, or `event`
- bundle reference and manifest snapshot
- enabled/status state
- timezone
- `next_run_at`
- last dispatch state
- child job ids
- source metadata
- missed/failure counters

The cluster leader processes due schedules. Per-schedule leases and idempotency keys prevent duplicate dispatch when local and remote nodes are both alive.

Event triggers are declarative. They match event type and payload filters. They do not execute code in the trigger itself.

## Periodic Jobs

Manifest shape:

```json
{
  "schedule": {
    "enabled": true,
    "kind": "periodic",
    "crons": ["0 2 * * *"],
    "timezone": "America/New_York",
    "prohibit_overlap": true,
    "missed_policy": "skip",
    "catchup_limit": 10,
    "window": {
      "duration_ms": 3600000,
      "end_action": "cancel"
    }
  }
}
```

Create a periodic schedule:

```bash
mn schedule create /path/to/bundle \
  --cron "0 2 * * *" \
  --timezone America/New_York \
  --name nightly-eval
```

Allow overlapping child jobs:

```bash
mn schedule create /path/to/bundle --cron "*/15 * * * *" --allow-overlap
```

Create a bounded window:

```bash
mn schedule create /path/to/bundle --cron "0 1 * * *" --window 2h
```

Supported cron shortcuts:

- `@hourly`
- `@daily`
- `@weekly`
- `@monthly`
- `@yearly`
- `@annually`

Five-field cron syntax is also supported.

## Delayed Jobs

Run once at an exact time:

```bash
mn schedule delay /path/to/bundle --at "2026-05-25T02:00:00Z"
```

Run once after a delay:

```bash
mn schedule delay /path/to/bundle --in 30m --name delayed-cleanup
```

Manifest shape:

```json
{
  "schedule": {
    "kind": "delayed",
    "run_at": "2026-05-25T02:00:00Z"
  }
}
```

or:

```json
{
  "schedule": {
    "kind": "delayed",
    "delay_ms": 1800000
  }
}
```

## Event-Triggered Jobs

Create an event trigger:

```bash
mn trigger create /path/to/bundle \
  --event file_uploaded \
  --filter-json '{"path":{"prefix":"/datasets/"}}'
```

Emit an event:

```bash
mn event emit file_uploaded \
  --payload-json '{"path":"/datasets/eval.jsonl","bucket":"local"}'
```

Manifest trigger shape:

```json
{
  "triggers": [
    {
      "name": "dataset-uploaded",
      "enabled": true,
      "event_type": "file_uploaded",
      "filters": {
        "path": {
          "prefix": "/datasets/"
        }
      }
    }
  ]
}
```

Filter values can match exact values, lists, string prefixes, and string contains:

```json
{
  "source": "otterdesk",
  "path": {
    "contains": ".jsonl"
  },
  "kind": ["dataset", "eval"]
}
```

## Schedule Operations

List schedules:

```bash
mn schedule list
mn schedule list --kind periodic
mn schedule list --status active
```

Show status:

```bash
mn schedule status <schedule-id>
```

Pause and resume:

```bash
mn schedule pause <schedule-id> --reason "hold during maintenance"
mn schedule resume <schedule-id> --reason "maintenance complete"
```

Dispatch immediately:

```bash
mn schedule run-now <schedule-id>
mn schedule run-now <schedule-id> --payload-json '{"manual":true}'
```

Delete:

```bash
mn schedule delete <schedule-id> --reason "retired"
```

List trigger events:

```bash
mn event list --limit 50
```

## Missed Runs And Overlap

`prohibit_overlap` defaults to `true`. When a previous child job is still active, the schedule does not launch another overlapping child unless overlap is explicitly allowed.

`missed_policy` controls late periodic runs:

| Policy | Behavior |
| --- | --- |
| `skip` | Skip runs that are past the missed grace. |
| `catchup_one` | Dispatch one missed run. |
| `catchup_all` | Dispatch missed runs up to `catchup_limit`. |

The default timezone is UTC. The CLI sends the local timezone explicitly unless you pass `--timezone`.

## OtterDesk Adoption

OtterDesk is now a schedule client:

- GUI and CLI schedule actions create or update MirrorNeuron runtime schedules
- OtterDesk stores the runtime `schedule_id`
- status displays runtime `next_run_at`, last dispatch, and errors
- upload flows emit runtime events such as `bundle_uploaded` and `file_uploaded`
- local schedule utilities remain for preview and conflict hints, not for launching jobs

## Important Code

| Area | Files |
| --- | --- |
| Policy normalization and cron/event matching | `MirrorNeuron/lib/mirror_neuron/runtime/schedule_policy.ex` |
| Schedule dispatch and due processing | `MirrorNeuron/lib/mirror_neuron/runtime/schedule_dispatcher.ex` |
| Leader sweeps | `MirrorNeuron/lib/mirror_neuron/cluster/leader.ex` |
| Redis schedule/event storage | `MirrorNeuron/lib/mirror_neuron/persistence/redis_store.ex` |
| gRPC methods | `MirrorNeuron/lib/mirror_neuron_grpc/server.ex` |
| CLI commands | `mn-cli/mn_cli/libs/schedule_cmds.py` |
| SDK client and decorators | `mn-python-sdk/mn_sdk/client.py`, `mn-python-sdk/mn_sdk/decorators.py`, `mn-python-sdk/mn_sdk/bundle.py` |
| REST API emitters | `mn-api` upload and schedule endpoints |
| OtterDesk schedule client | `otterdesk-desktop-app` scheduler and GUI schedule code |

## V1 Limits

- schedules dispatch normal child jobs; they are not a separate execution engine
- event triggers use declarative filters only
- cron parsing is five-field minute-level syntax plus common shortcuts
- upload events are a built-in event source, but event types are otherwise generic

