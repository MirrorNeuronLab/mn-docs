# MirrorNeuron Runtime Architecture

For runtime maintainers: this explanation maps compilation, admission,
owner-local execution, and federation in the current checkout. It assumes
familiarity with [Core Concepts](core-concepts.md); command syntax and source
authoring belong in their canonical references. Sources are Core's `lib/`,
`proto/job.proto`, SDK preparation code, and the tests listed below. These are
checkout-verified contracts; release maturity and installed compatibility depend
on the owning artifacts. [Changes](changes.md) records validation and limits.

## Runtime code map

Paths in this table are relative to `MirrorNeuron/lib/mirror_neuron/` unless
otherwise stated. Bare filenames in a cell share the preceding file's directory.

| Boundary                   | Owning code                                                                        | Contract                                                                                                                     |
| -------------------------- | ---------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| Startup                    | `application.ex`                                                                   | Supervises registries, job/agent supervisors, admission, recovery, cancellation, responses, and native-resource maintenance. |
| Definition and start       | `runtime/stable_job.ex`, `stable_job_update.ex`, `run_start_request.ex`            | Durable Job identity, revision/start gates, service single-run rules, and keyed start reconciliation.                        |
| Physical capacity          | `runtime/node_admission.ex`, `node_admission_state.ex`, `resource_allocation.ex`   | Atomic owner-local reservations, durable queue, generation fencing, and verified reclamation.                                |
| Physical placement         | `scheduler.ex`, `resource_spec.ex`                                                 | Resolves admitted workers, devices, ports, and volume requirements on the owner.                                             |
| Execution lifecycle        | `runtime/job_runner.ex`, `job_coordinator.ex`, `agent_worker.ex`                   | Per-run supervision, worker delivery, status, and durable transition ownership.                                              |
| Logical workflow           | `runtime/workflow_ledger.ex`, `workflow_admission.ex`, `workflow_message.ex`       | Dependency admission, attempt context, step boundaries, retries, and completion fencing.                                     |
| Adaptive work              | `runtime/dynamic_workflow.ex`, `child_workflow.ex`                                 | Bounded graph patches and child rounds within the existing run.                                                              |
| Progress and action limits | `runtime/workflow_activity.ex`, `workflow_budget.ex`                               | Live progress supervision and durable named action allowances.                                                               |
| Messages                   | `runtime/delivery.ex`, `backpressure.ex`, `live_input.ex`                          | Leases, ACK/retry/deduplication, queue pressure, and declared live controls.                                                 |
| External execution         | `runner/`, `execution/lease_manager.ex`, `sandbox/`                                | Host/Docker/OpenShell invocation, local executor slots, staging, and owned cleanup.                                          |
| Durability and recovery    | `persistence/`, `runtime/local_recovery.ex`, `recovery_safety.ex`, `run_retry.ex`  | Fenced Redis state, safe clean attempts, and explicit checkpoint retry.                                                      |
| Finalization               | `runtime/finalization.ex`, `job_cleanup.ex`, `cancellation_reconciler.ex`          | Terminal publication, durable cancellation intent, and retryable cleanup.                                                    |
| Peer control               | `cluster/federation_client.ex`, `federation_registry.ex`, `federation_channels.ex` | Authenticated owner forwarding and cached projections. Horde supervision remains local to a Core.                            |
| Remote interfaces          | `MirrorNeuron/proto/job.proto`, `MirrorNeuron/lib/mirror_neuron_grpc/handlers/`    | Authoritative `mirrorneuron.job.v1.JobService`; CLI and REST adapt it through the SDK.                                       |

```text
source package -> SDK validate/compile/prepare -> durable Job on one owner
  -> keyed start + owner reservation -> queued OR admitted Run
  -> staged-input readiness -> coordinator + workflow ledger
  -> delivery admission -> worker -> declared runner -> accepted step boundary
  -> terminal publication -> verified resource cleanup -> capacity reusable
```

## Design goals

MirrorNeuron is not trying to replicate Airflow as a general-purpose data scheduler. It is a multi-agent runtime with a narrower job:

- keep orchestration and collaboration in BEAM
- execute workers through declared host, Docker, or OpenShell runners
- keep every job and all of its workers on one owner Core
- federate independent Cores for owner selection and remote control
- keep inter-agent communication event-driven and observable
- avoid turning the BEAM control plane into a pile of heavyweight OS processes

That last point drives most of the recent changes.

## What we borrowed from Airflow

The project intentionally borrows a few control-plane ideas from Airflow while avoiding Airflow's product shape.

- Small built-in primitive set instead of domain-specific agents
- Clear separation between author-time workflow definition and runtime execution
- Pools and slot accounting for heavyweight execution capacity
- Strong message and artifact boundaries between scheduler concerns and task payload concerns

Airflow's big lesson for this runtime is not "copy operators." It is "treat heavyweight execution capacity as scarce and schedule it explicitly."

## Workflow DAG execution model

MirrorNeuron now separates the user-facing problem workflow from the lower-level agent runtime. In the generated `mn.workflow/v1` runtime descriptor, `workflow` is the problem DAG: it names the source, sink, step dependencies, branch requirements, join behavior, and accepted outcomes. `agents.nodes` and `agents.edges` are the runtime agent communication topology used by the BEAM runtime; they are not the problem workflow. Blueprint authors instead supply the referenced `workflow.json` and `execution.json` roles in the [canonical source package](blueprint-standard.md). Generated `nodes`, `edges`, bindings, and entrypoints belong to the compilation/submission boundary.

The DAG executor is a durable scheduler with per-step lifecycle state, explicit
trigger rules, branch and guard skips, runtime-expanded mapped items for
scatter–gather work, and an opt-in bounded dynamic mode. It is not a full GOAP
or PDDL planner. See [Workflow DAG Flow Patterns](dag-flow-patterns.md) for
authoring examples.

```text
workflow.edges + workflow.steps + admitted dynamic templates
  -> graph compiler
  -> static or bounded-dynamic DAG scheduler
  -> step lifecycle state machine
  -> runtime.bindings
  -> agents, workers, validators, reducers
  -> workflow events
  -> CLI and Web UI progress snapshots
```

Execution works in layers:

- The graph compiler validates source/sink, reachability, acyclicity, edge ids, join modes, retry bounds, timeout values, and parallel output path conflicts.
- The scheduler keeps a map of step outcomes such as `done`, `partial`, `skipped`, `failed`, and `blocked`.
- A step becomes ready only when its parent edges and trigger rule are satisfied. Ready steps in the same graph layer can run concurrently.
- Each step follows a small lifecycle: `pending -> ready -> running -> done`, with terminal alternatives such as `partial`, `skipped`, `failed`, or `blocked`.
- `runtime.bindings` maps each workflow step to one or more internal workers. A tax step, for example, may run a preparer and a validator while still appearing as one problem-workflow node.
- The executor emits generic workflow events such as `workflow_graph_compiled`, `workflow_step_started`, `workflow_edge_satisfied`, `workflow_join_waiting`, and `workflow_finished`. The shared SDK turns these into the progress snapshots used by CLI and Web UI.

`workflow.mode: static_dag` retains the original immutable-topology behavior.
`workflow.mode: dynamic_dag` permits named controller steps to patch only
declared adaptive regions. Core validates and applies those patches; the
controller remains responsible for deciding whether runtime evidence warrants
a change.

### Bounded dynamic DAGs

Dynamic workflows do not create arbitrary code or resources. Before a run
starts, the source compiler renders every allowed template into an idle worker
binding and normal resource admission includes those workers. At runtime a
controller may instantiate only those templates.

Two region strategies are supported:

- `replace_path` removes declared mutable edges and inserts finite batch work
  before a fixed exit. New roots wait for the controller attempt to complete.
- `checkpoint_fanout` is for reentrant service controllers. An accepted patch
  durably checkpoints the current invocation, rearms the controller, and
  releases the patch roots immediately. Completed finite subgraphs are retired
  into bounded history. Finite fanout completion does not stop the service;
  explicit service stop or cancellation remains authoritative.

Each `workflow_graph_patch` has a `patch_id`, optimistic `base_revision`, region
id, and at most the configured number of `add_step`, `remove_step`, `add_edge`,
and `remove_edge` operations. Application is atomic. Exact duplicate replays
are successful no-ops; conflicting patch-id reuse and stale revisions are
rejected. A rejection fails the requesting attempt through its normal retry
policy, and later output from that rejected attempt is fenced.

Core also rejects patches that exceed limits, use an unadmitted template,
cross a region boundary, mutate fixed/running/terminal work, create a cycle, or
make required region work unreachable. Defaults are 64 batch patches or 10,000
service patches, 128 active dynamic steps, 64 operations per patch, and 32 KiB
of input per instance. Hard caps are 100,000 patches, 1,000 active dynamic
steps, and 256 operations per patch.

The durable ledger schema is v3 for new runs. It stores graph revision,
patch-deduplication records, region ownership, active instances, and bounded
service history. Static v2 state remains readable. Clean-attempt recovery starts
again at revision 0; restoration of persisted v3 coordinator state retains
already-applied revisions. Public topology events contain safe step/edge
deltas, never per-instance `with` parameters.

GOAP/PDDL-style planning remains outside the runtime contract. Dynamic
conditions and planning decisions are ordinary controller logic; Core provides
only bounded topology validation, durable ordering, scheduling, and recovery.

## Durable definitions, runs, and child workflows

A public Job stores reusable configuration; a public Run identifies one execution.
Core's internal execution identifiers must not be substituted for public REST run
IDs. Run pause/resume/cancel acts on an execution, while archive and data reset
belong to the durable definition.

Batch Jobs can retain many Runs. A `type: service` Job has at most one attached
Run; pause/resume preserves it and an ordinary second start returns
`service_run_exists`. Explicit replacement uses a fresh run ID and permanently
clears the old run's state/artifacts while retaining Job data and schedules.
Retry/recovery preserves run identity and advances an independent attempt.
`MN_JOB_ID`, `MN_RUN_ID`, and `MN_ATTEMPT_ID` carry these separate identities.

Keyed starts persist request identity and the selected run ID before dispatch.
An identical replay returns the durable receipt without a process PID. If a
run committed before receipt persistence, reconciliation requires that run's
manifest to carry the same request identity. Changed payloads or an unrelated
explicit run ID remain conflicts.

Bounded child workflows run through the workflow ledger inside the parent's
execution. They admit declared templates, enforce round and step limits, and
hold the parent boundary until child completion. They are distinct from schedule
dispatch, which creates separate work. Child completion output travels through
step-source delivery so downstream steps receive the mapped boundary output.

DockerWorker and OpenShell buffer command output and do not stream workflow
beacons. Their node-level beacon timeout is ignored; the task deadline remains authoritative.
An explicit workflow `control.beacon_timeout_ms` still applies when a separate
producer supplies beacons. HostLocal node beacon settings are unchanged. See
`tests/unit/child_workflow_test.exs` and `tests/unit/workflow_ledger_test.exs`.

## Admission and execution readiness

The owner reserves capacity before persisting a new execution. Missing resource
profiles reserve the PC exclusively; `policies.resource_allocation.mode: shared`
permits compatible peak budgets to coexist. Manual `start_now` rejects a busy
owner; explicit `enqueue_if_busy` and scheduled occurrences can enter its durable
queue. A read-only availability snapshot is never a reservation. See
[Resources and Devices](resources-and-devices.md) for the canonical accounting,
backfill, device, and release rules.

After admission, SDK-staged submissions with an input-readiness inventory stay
`pending` until the owner verifies the replicated files. The coordinator emits
`submission_storage_waiting`, then `submission_storage_ready` before seeding
entrypoints. Missing/still-replicating input is a wait; malformed metadata is a
validation error. Timeout emits `submission_storage_timeout` and fails before
source dispatch. Legacy submissions without an inventory start immediately.
Cancellation prevents later readiness timers from dispatching.

Run reservations, executor pool slots, and inference request leases have
different lifetimes. Admission retains capacity during pause/recovery; local
executor slots bound expensive invocations; native request leases protect
in-flight inference. All must be released through their owning cleanup paths.

## Step admission and supervision

Core admits a delivery through the owning ledger before a workflow handler
runs. A dependency wait defers delivery without executing user code. Generated
sources and declared collector/stream entry agents can admit multiple upstream
deliveries into their owning attempt; ordinary workers retain a message-specific
fence. Redundant triggers from declared parents do not execute another handler.

Routing inside a logical step retains its attempt context. Crossing a step
boundary clears that context for the destination's admission. Worker
`MN_WORKFLOW_IDEMPOTENCY_KEY` identifies the target-agent delivery and survives
replay; `MN_WORKFLOW_STEP_IDEMPOTENCY_KEY` retains the ledger's step key. A
parent sink notification cannot release a child-workflow target before the
ledger commits the final parent output. Only the owning step boundary completes
logical work.

`workflow.execution.supervision: "activity"` opts into live SDK progress rather
than an implicit batch elapsed deadline. Core requires HostLocal executors with
enabled, required agent beacons. Increasing progress counters prove work is
advancing; process/runtime heartbeats and duplicate counters prove only liveness.
Five minutes without progress fails the step with
`workflow.step.progress_timeout`. Bounded external waits keep a stable identity
and allowance of at most one day; repeated reports cannot extend that same wait.
Pause excludes paused time, persisted progress survives ledger restoration, and
an explicit step/runner `timeout_seconds` remains a hard limit. Other workflows
retain their deadline semantics.

Static services whose phases each bind exactly one `mn.block_events/v1`
executor use successive event callbacks rather than one-shot finite DAG
admission. Omitted dynamic settings and `dynamic: {enabled: false}` both select
the static classification. Mixed services, dynamic DAGs, batch jobs, and child
workflows retain ledger controls. Delivery ACK/retry, event-state fencing, and
explicit callback limits still apply; pause/resume retains the physical output
identity. The public `mn.service.workflow.v1` phase projection describes
startup/service/shutdown; observed serving does not complete ledger steps.

## Workflow action allowances

`policies.workflow_budgets` declares one to 32 named `{limit: integer}`
allowances, each from zero to 100,000. SDK compilation resolves authored
configuration references. The authenticated `SetResource` operation
`workflow_budget` uses schema `mn.workflow_budget/v1` and the closed actions
`start`, `complete`, and `summary`.

The coordinator registers ownership under the stable Job and actual physical
workflow run, serializes grants, and persists changes through its fenced
snapshot barrier before acknowledgement. Identical requests replay the original
reservation; changed requests, limits, runs, or completions reject. Unknown
starts stay charged and completion does not refund units. Checkpoint retry
restores the allowance state. Each allowance journal is bounded to 100,000
records / 4,000,000 encoded bytes, with 16 KiB metadata objects.

These units bound workflow actions. They do not change CPU/GPU percentages,
reserve a PC, provide monetary billing, or make an external effect exactly-once.
Delivery identities and native effect journals still govern dispatch safety.

## Control plane vs execution plane

MirrorNeuron now has a sharper two-layer model.

### Control plane

The control plane lives in BEAM:

- job orchestration
- message routing
- supervision
- persistence
- placement scheduling and allocation metadata
- retries and backoff
- event history
- aggregation
- authenticated federation, owner routing, and summary projection
- service registry health state
- deployment and schedule dispatch state

These are all cheap, stateful, highly concurrent tasks that BEAM is excellent at.

### Execution plane

The execution plane uses the declared runner. HostLocal runs trusted code with host permissions; DockerWorker and DockerCompose use prepared native Docker resources; OpenShell handles policy-controlled sandbox execution. OpenShell responsibilities include:

- sandbox creation
- external process startup
- filesystem staging
- shell or Python command execution
- stdout and stderr capture
- sandbox isolation

This work is comparatively expensive. It should be bounded and scheduled, not launched without limit.

## Native preparation boundary

Core is responsible for running every agent of its owner-local jobs. It is not
responsible for preparing host-native resources or scheduling one job's agents
on a federated peer.

Native preparation includes:

- model catalog and alias resolution
- model hardware compatibility checks
- Docker Model Runner install, update, and remove operations
- model proxy and remote endpoint records
- Docker Compose file edits for helper services
- Docker image build or pull decisions for prepared workers
- host filesystem setup and ownership ledgers

Those operations belong to `mn-python-sdk`, `mn-cli`, and `mn-api`, because they run outside the Core container and can safely interact with the native operating system, Docker daemon, and host filesystem.

Core consumes concrete facts prepared by those layers:

- service instances and tags
- `requires_services`
- placement requirements
- endpoint environment values
- prepared-resource metadata

If a required resource is missing, Core reports the failure. It should not silently install models, edit Docker Compose files, choose model backends, or perform host-level setup.

For model preparation, the gRPC flow is:

```text
Local node:
  SDK/API/CLI -> local Core gRPC PrepareRuntimeModel
  -> MN_NATIVE_SDK_GRPC_TARGET -> Compose proxy mn-native-sdk-grpc
  -> host-side SDK gRPC service -> Docker Model Runner

Federated owner selection:
  SDK/API/CLI -> selected owner Core
  -> owner's node-local SDK gRPC service -> Docker Model Runner
```

Core's local relay keeps the Core boundary small. A request received by another
peer is forwarded to the selected owner, whose SDK service performs the native
operation. The service returns concrete facts for owner-local scheduling and
worker environment injection.

Model inference follows a separate mandatory gateway boundary: agents call the
owner's LiteLLM gateway. For admitted runs, managed models, embeddings, and
fallback remain on the reserved PC; hosted provider routes remain possible.
The gateway can represent peer routes, but a route does not grant another PC's
capacity. Agents never call a local or remote DMR directly. See
[Model Runtime](model-runtime.md#run-admission-and-model-residency).

## Logical workers vs physical execution leases

This is the most important runtime distinction.

### Logical worker

A logical worker is a BEAM process representing workflow state:

- it can receive messages
- it can wait cheaply
- it can be retried
- it can emit events
- it may request external execution

### Physical execution lease

A physical execution lease is permission to consume sandbox capacity on the current node:

- one or more executor slots from a pool
- typically one OpenShell sandbox run
- expensive compared to a BEAM process

The runtime should be able to hold thousands of logical workers without starting thousands of sandboxes at once.

That is why executor nodes now go through `MirrorNeuron.Execution.LeaseManager`.

## Why the lease manager exists

Before this change, each executor agent launched OpenShell directly from its own process. That worked for small demos, but it broke down under large fan-out:

- gateway resets under launch pressure
- duplicate cleanup races
- OS subprocess pressure
- too many expensive execution attempts starting at once

The lease manager addresses that by making executor capacity explicit.

- Every executor requests a lease before running OpenShell.
- The lease manager grants or queues the request per node.
- Executors emit events when they request, acquire, and release leases.
- Capacity is configured with `MN_EXECUTOR_MAX_CONCURRENCY` or per-pool overrides.

This keeps BEAM lightweight while still allowing large logical graphs.

## Executor pools and slots

MirrorNeuron now supports local executor pools.

- default pool capacity comes from `MN_EXECUTOR_MAX_CONCURRENCY`
- named pools can be configured with `MN_EXECUTOR_POOL_CAPACITIES`

Examples:

```bash
export MN_EXECUTOR_MAX_CONCURRENCY=4
export MN_EXECUTOR_POOL_CAPACITIES="default=4,gpu=1,io=8"
```

Executor node config can request a pool and slot count:

```json
{
  "agent_type": "executor",
  "config": {
    "pool": "default",
    "pool_slots": 1
  }
}
```

Pools are enforced per owner Core. Federation scales by selecting different
owners for independent jobs, each with its own bounded execution capacity; it
does not combine several peers' pools for one job.

## Message model

The message system is intentionally split into control-plane and payload-plane sections.

- `envelope`: runtime-owned routing and trace metadata
- `headers`: extensible routing and schema metadata
- `body`: application-owned payload
- `artifacts`: references to large externalized data
- `stream`: optional stream framing metadata

This keeps the runtime generic.

The runtime should understand enough to route and observe messages, but it should not need to parse every application payload to work correctly.

That also enables multi-language workers: Python and shell code consume the payload contract inside the sandbox, while BEAM only needs the stable envelope.

Declared live-input commands require only their entrypoint's available queue,
so prompt/supervision controls can arrive while downstream model queues are
busy. Core verifies the immutable input ID, entrypoint, message type/class, and
payload schema first. Ordinary external messages still check downstream pressure.
This exception does not bypass authentication, delivery limits, or lifecycle
checks.

## Nomad-Inspired Orchestration Layer

MirrorNeuron has an owner-local orchestration layer above the message graph:

- desired-vs-actual reconciliation for local agents and jobs
- local restart policy with sliding windows and backoff
- owner eligibility, maintenance, and drain
- owner-local Redis-backed service registry and health checks
- CUDA, Metal, port, volume, and runtime-driver aware placement
- rolling, canary, promote, rollback, and version history for long-running deployments
- periodic, delayed, and event-triggered job dispatch

Federation adds authenticated owner request forwarding and cached summary
projections. It does not reschedule individual agents or take over an offline
owner's active job.

The detailed map is in [Nomad-Inspired Runtime Features](nomad-inspired-runtime.md).

## Why artifacts matter

Passing large blobs directly between agents is a bad fit for an owner-local
runtime and for optional federation transport.

Instead, messages should stay small and carry:

- ids
- routing metadata
- schema references
- artifact references

This is the same core operational lesson many schedulers learn: small control messages scale much better than inline large payloads.

Federated BlobRef sharing uses a simple peer HTTP content-addressed store. Blob URLs
are not individually bearer-token authenticated; operators should expose the
artifact port only on trusted loopback, Docker, VPN, or LAN interfaces and use
firewall rules or bind/publish host settings to keep it inside the intended
cluster boundary.

OpenShell workers may select `artifact_handoff.version: mn.artifact_handoff/v1`
for immutable result transfer. This conflicts with `sync_shared_storage: true`;
there is no silent fallback between modes. Core validates producer identity,
lease epoch, confined paths, file type, size/hash, and quotas before committing
a receipt. Transfer retry reuses the recorded command outcome instead of another
dispatch. Unknown dispatch completion stays `unknown_blocked`. Cleanup follows
commit and can be retried independently without invalidating committed success.
Configured-folder exports require explicit `artifact_handoff.export_outputs: true`.

Accepted event publications and enabled isolated exports maintain the portable
`.mn-published-files.json` inventory (`mn.published_outputs/v1`): public path,
kind, byte size, and SHA-256, excluding private handoff state. Individual copies
are atomic; the verified receipt/inventory is the completion barrier, not a
filesystem transaction across all filenames. SDK-staged shared submissions
also publish `outputs/runs/<run-id>/.mn_completion.json` with terminal status
and a durable-file inventory. Submitters wait for replicated evidence before
copying outputs; Core does not write a submitter-only path on a remote owner.
Syncthing replication does not make Redis state shared or guarantee immediate
visibility on another machine.

Sources: `runner/open_shell_artifact_handoff.ex`, `artifacts/shared_storage.ex`,
`priv/openshell_handoff/`, and `tests/handoff/test_store.py`.

## Built-in primitives

MirrorNeuron keeps only a small runtime primitive set in core:

- `router`
- `executor`
- `aggregator`
- `sensor`

Why so small:

- runtime primitives stay reusable
- domain-specific agents belong in user code or examples
- the project stays focused on collaboration mechanics instead of shipping business personas

## Why executor code still supports Python and shell

The project is not BEAM-only in the sense of "all useful code must be Elixir." That would make the runtime less practical.

Instead:

- BEAM owns coordination
- the declared runner owns external execution and its isolation boundary
- worker payloads can be shell, Python, or other supported runtimes

That means a logical worker does not "become Python." It requests external execution when needed.

## Operational guidance

A healthy deployment usually looks like this:

- many logical workers
- modest executor concurrency per owner Core
- independent jobs assigned to more Cores when more capacity is needed

Example:

- four jobs with 250 logical workers each
- four owner Cores
- eight executor slots per Core
- up to eight concurrent sandboxes per job owner

That is still a large multi-agent workload, but it does not overload a single OpenShell gateway.

## Current limitations

The current implementation improves the runtime boundary a lot, but a few things are still intentionally simple:

- executor pools are local to each owner Core, not globally brokered
- active jobs do not migrate to another Core when their owner is unavailable
- sensor and deferred waiting primitives can still grow richer
- artifacts are modeled in messages, but the runtime does not provide a full external artifact-store abstraction
- resource reservations and native request fencing do not provide OS-level isolation

Those are good next steps, but the current runtime is already much closer to the intended design:

- BEAM as the lightweight orchestrator
- declared runners as bounded worker execution
- message-driven collaboration across supervised logical workers

## Validation sources

The focused Core suites for resource allocation, admission state, start
receipts, activity supervision, workflow budgets, resource specs, and event-only
services are listed in [Changes](changes.md#validation). Related boundaries are
covered by `workflow_ledger_test.exs`, `workflow_admission_test.exs`,
`workflow_message_test.exs`, `live_input_test.exs`, and
`submission_readiness_test.exs`. Source/test inspection does not establish live
Docker/OpenShell behavior, hardware capacity, or installed-version parity.
