# Workflow DAG Flow Patterns

MirrorNeuron workflows can express dependency graphs rather than only a linear
`A → B → C` pipeline. The durable runtime ledger persists each step outcome
and starts, blocks, skips, or triggers work from that state.

A blueprint still needs runtime message routes to carry data between workers;
graph edges decide *when* a step is eligible to run.

## Core shape

Declare runtime-controlled steps in `flow.steps` and dependency edges in
`flow.graph.edges`:

~~~
{
  "flow": {
    "steps": [
      {"id": "extract", "run": "extract"},
      {"id": "transform", "run": "transform"},
      {"id": "load", "run": "load"}
    ],
    "graph": {
      "edges": [
        {"from": "extract", "to": "transform", "accepts": ["done"]},
        {"from": "transform", "to": "load", "accepts": ["done"]}
      ]
    }
  }
}
~~~

The default trigger is `all_success`: every upstream edge must have an
accepted successful outcome. `completed`, `partial`, `skipped`, and
`failed` are durable terminal states.

Use `control.failure_policy: "continue_partial"` (or `skip`) on a step
whose failure should be handled by a later step. The default
`fail_workflow` ends the job after retries are exhausted, before a failure
handler can run. A handled failure remains observable as
`terminal_outcome: "failed"`.

## Trigger rules

Set `trigger_rule` on a step. It can be a string or a map for quorum:

| Rule | Starts when | Typical pattern |
| --- | --- | --- |
| `all_success` | Every upstream succeeds; the default. | Linear pipeline, fan-in |
| `all_done` | Every upstream is terminal. | Cleanup / teardown |
| `one_success` | The first upstream succeeds. | Alternate providers |
| `one_done` | The first upstream becomes terminal. | React to first completion |
| `one_failed` | The first upstream has a handled failure. | Alert, recover, fallback |
| `none_failed_min_one_success` | All upstreams are terminal, none failed, and one succeeded. | Branch join |
| `{ "rule": "quorum_success", "quorum": 2 }` | The requested number succeed. | N-of-M approval |

Aliases `all_required`, `any_success`, `any_done`, `any_failed`,
`partial_success`, and `quorum` are accepted. The runtime validates trigger
names, quorum values, step references, and graph acyclicity at manifest load
time.

## Common patterns

### Linear, fork, and join

Use normal graph edges. A fork has one source and several downstream edges; a
join has several upstream edges and uses the default `all_success` rule.

~~~
extract → [profile, validate, enrich] → publish
~~~

Independent branches can run concurrently, subject to executor-pool capacity.

### Scatter–gather

A worker can expand a declared target step into independently tracked mapped
instances. Emit `workflow_step_scatter` before completing the scattering step:

~~~
{
  "events": [
    {
      "type": "workflow_step_scatter",
      "payload": {
        "targets": ["worker_a", "worker_b"],
        "items": [
          {"customer_id": "c-1"},
          {"customer_id": "c-2"},
          {"customer_id": "c-3"}
        ]
      }
    }
  ],
  "complete_step": true
}
~~~

The runtime expands these to ids such as `worker_a[0]` and `worker_b[1]`,
then replaces dependencies through the declared target steps. Items are
assigned round-robin over `targets`; declare several target worker nodes to
get physical parallelism. Mapped items are persisted immediately but dispatched
only after the scattering step itself completes. A downstream collector with
`all_success` waits for every mapped item. `max_items` caps an individual
scatter event; the default is 1000.

### Conditional branch and short circuit

A router or executor selects downstream step ids by emitting:

~~~
{
  "events": [
    {"type": "workflow_step_branch", "payload": {"branches": ["manual_review"]}}
  ],
  "complete_step": true
}
~~~

Direct unselected paths are marked `skipped`; propagation continues through
paths whose parents are all skipped. Merge selected and skipped paths with
`none_failed_min_one_success`.

For a guard that should stop all downstream work, emit:

~~~
{
  "events": [
    {
      "type": "workflow_step_skipped",
      "payload": {"reason": "no new files", "skip_downstream": true}
    }
  ]
}
~~~

This marks every descendant skipped and terminates any already-active descendant
attempt.

### Any-success, completion, failure, cleanup, and fallback

These patterns differ only in the receiving step's trigger:

~~~
{
  "steps": [
    {"id": "provider_a", "run": "provider_a",
     "control": {"failure_policy": "continue_partial"}},
    {"id": "provider_b", "run": "provider_b",
     "control": {"failure_policy": "continue_partial"}},
    {"id": "first_result", "run": "first_result", "trigger_rule": "one_success"},
    {"id": "alert", "run": "alert", "trigger_rule": "one_failed"},
    {"id": "cleanup", "run": "cleanup", "trigger_rule": "all_done"}
  ]
}
~~~

Use `one_done` to react to either outcome of the first completed parent. For
a fallback chain, connect `primary → fallback → emergency`, set `fallback`
and `emergency` to `one_failed`, and give failed providers
`continue_partial`. Later fallback steps are automatically skipped when their
failure-only trigger becomes impossible.

### Quorum and setup/work/teardown

~~~
{
  "steps": [
    {"id": "replica_a", "run": "replica_a"},
    {"id": "replica_b", "run": "replica_b"},
    {"id": "replica_c", "run": "replica_c"},
    {"id": "approve", "run": "approve",
     "trigger_rule": {"rule": "quorum_success", "quorum": 2}},
    {"id": "destroy", "run": "destroy", "trigger_rule": "all_done"}
  ]
}
~~~

`approve` can start after any two successful replicas. For temporary
resources, declare `create → work → destroy`, give `destroy` `all_done`,
and give `work` `continue_partial` if teardown must run after a work
failure.

## Sensors and event-driven runs

A sensor is a normal workflow step that waits for a file, API job, queue
message, or database condition and then emits its normal output message. Its
downstream graph edge starts the continuation step after the sensor completes.
External callers can also deliver a message directly to a sensor node.

To launch a whole DAG from an external event, declare a top-level runtime
trigger:

~~~
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
~~~

The schedule dispatcher creates an ordinary child job when the event matches;
the DAG starts from its normal entrypoint. See
[Schedules And Events](schedules-and-events.md) for trigger creation and event
emission commands.

## Operational notes

- Graph control is durable in `workflow_state`; inspect it when a step is
  blocked, skipped, retried, or triggered synthetically.
- Success-triggered steps normally receive their upstream data message. A
  failure- or completion-triggered step receives a compact `workflow_trigger`
  command with parent outcomes and outputs.
- Make side-effecting mapped workers idempotent. Delivery is at least once and
  retries can repeat a mapped item attempt.
- Keep a terminal sink separate from workflow steps. It completes the job only
  after the ledger reports every required step terminal.
