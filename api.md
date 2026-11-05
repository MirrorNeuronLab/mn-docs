# MirrorNeuron REST API

This page describes the canonical HTTP API used by the Web UI, OtterDesk, and
HTTP automation. The CLI and Python SDK also use internal gRPC interfaces; the
gRPC `mirrorneuron.job.v1` package and domain schema labels such as `mn.workflow/v1` are
independent of the REST version.

## Reader and scope

- **Reader:** integrator, application developer, or maintainer using the public
  HTTP boundary.
- **Outcome:** select canonical resources, make conditional or idempotent
  requests, and monitor accepted work without relying on retired routes.
- **Page type:** REST and streaming API reference.
- **Scope:** the canonical `mirrorneuron.rest.v1` HTTP and SSE surface. Internal
  gRPC interfaces, CLI syntax, and domain payload schemas are out of scope.
- **Maturity:** stable canonical v1 surface; removed and unsupported routes are
  identified explicitly.
- **Sources of truth:** `mn-api` route modules, request models, operation
  implementation, OpenAPI schema, and contract tests.
- **Validation:** audit local links and Markdown syntax, then run the focused
  `mn-api` contract tests for changed routes and response behavior.

## Base URL and capability

The default local base URL is:

```text
http://localhost:54001/api/v1
```

`GET /health` is unauthenticated and deliberately small:

```json
{
  "status": "ok",
  "api_contract": "mirrorneuron.rest.v1",
  "auth": "enabled"
}
```

Clients must verify `api_contract`. A server that responds on `/api/v1` without
that value implements a historical, incompatible contract and must not be used.
All other endpoints require `Authorization: Bearer <token>` when
`MN_API_TOKEN` is configured.

`/api/v2`, historical aliases, `/runtime-runs`, `/deployments`,
`/trigger-events`, manual schedule `/dispatches`, and WebSocket routes are not
supported. Use the current Job/Run and schedule resources.

## Common conventions

- JSON fields use `snake_case`; request bodies reject unknown fields.
- Collection responses are `{ "items": [], "next_page_token": null }`.
- `page_size` defaults to `50` and is capped at `200`. Pass the opaque
  `page_token` unchanged to continue. Tokens expire after 24 hours and are
  bound to the route, principal, filters, and stable sort.
- Synchronous creation returns `201 Created` with `Location`. Run creation and
  background Operations return `202 Accepted` with `Location`. Updates return
  `200`. Run deletion returns `204`; schedule deletion returns a `200` receipt.
  Checkpoint retry returns `202` with its accepted selection.
- Send `Idempotency-Key` on non-idempotent POST requests, especially Run
  creation, blueprint addition or removal, schedule creation, and
  administrative operations. Replay records last 24 hours; reusing a key for
  another request returns `409 Conflict`.
- Persistent jobs, schedules, model registrations, and model
  installations return strong `ETag` headers. Their `PATCH` and `DELETE`
  requests require `If-Match`; missing and stale conditions return `428` and
  `412`, respectively.
- Errors use `application/problem+json` with `type`, `title`, `status`,
  `detail`, `instance`, `code`, `request_id`, and bounded field `errors` when
  applicable. Work that fails after a `202 Accepted` response records its
  terminal failure on the Operation instead of returning a second HTTP error.

## Resource overview

| Area                   | Canonical resources                                                                                                                                                                             |
| ---------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Health and system      | `/health`, `/runtime/status`, `/runtime/health`, `/runtime/diagnostics`, `/runtime/resources`, `/system/summary`, `/metrics`                                                                    |
| Jobs                   | `/jobs`, `/jobs/{job_id}`, `/jobs/{job_id}/bundle`, `/jobs/{job_id}/data-resets`, `/jobs/{job_id}/relocations`, `/jobs/{job_id}/mcp`                                                            |
| Runs                   | `/jobs/{job_id}/runs`, `/blueprints/{blueprint_id}/runs`, `/runs`, `/runs/{run_id}`                                                                                                             |
| Admission and retry    | `/jobs/{job_id}/run-admission-checks`, `/runs/{run_id}/retry-plans`, `/runs/{run_id}/retries`                                                                                                   |
| Run detail             | `/runs/{run_id}/monitor`, `/workflow-progress`, `/logs`, `/events`, `/resources`, `/human-requests`, `/ui`, `/artifacts`, `/outputs`, `/snapshots`, `/agent-graph`, `/export`, `/observability` |
| Bundles and blueprints | `/bundles`, `/blueprints`, `/blueprints/{blueprint_id}`, `/additions`, `/removals`, `/validations`, `/runs`                                                                                     |
| Schedules              | `/jobs/{job_id}/schedules`, `/schedules`, `/schedules/{schedule_id}`                                                                                                                            |
| Infrastructure         | `/nodes`, `/models`, `/model-remotes`, `/model-proxies`, `/services`, `/service-checks`                                                                                                         |
| Operations             | `/operations`, `/operations/{operation_id}`                                                                                                                                                     |

Durable configured work is a Job. One execution of that definition is a Run.
Run URLs always use the public `run_id`; `runtime_run_id` is diagnostic metadata
and is never part of a client URL.

## Run admission and queued starts

`POST /jobs/{job_id}/run-admission-checks` reads saved configuration and owner
capacity without preparing containers, changing the Job, or reserving resources.
The body accepts `action` (`start`, `resume`, or `retry`, default `start`),
optional `run_id`, and `config_overrides`. Resume/retry requires `run_id`.
Overrides that would change saved configuration return `409`; save them before
checking. A successful read returns an admission status of `runnable_now`,
`runnable_later`, `not_runnable`, or `unavailable`, with bounded blockers and
owner/observation metadata. A later start must recheck capacity.

Run creation accepts:

| Field                  | Default     | Contract                                                                                                                                    |
| ---------------------- | ----------- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| `admission_policy`     | `start_now` | `start_now` rejects a busy owner before execution persistence; `enqueue_if_busy` explicitly accepts compatible work into its durable queue. |
| `inputs`               | `{}`        | Runtime workflow inputs.                                                                                                                    |
| `config_overrides`     | `{}`        | Catalog Job configuration changes; preparation occurs only when resolved configuration changes.                                             |
| `run_id`               | generated   | Explicit public execution identity when supplied.                                                                                           |
| `replace_existing_run` | `false`     | Destructive service replacement; requires a fresh explicit `run_id`.                                                                        |

For example, the body below opts into automatic dispatch when owner capacity
becomes available:

```json
{ "inputs": {}, "admission_policy": "enqueue_if_busy" }
```

An accepted busy start returns `202` with `status: queued` and an `admission`
receipt identifying the queue, owner, position, and blocker. It has no running
executor yet. Keep its public run ID and monitor it rather than submitting a
second request. Reuse the same `Idempotency-Key` after an uncertain response.
Permanent incompatibility is not accepted as a queue entry.

`GET /runs/{run_id}` and the monitor projection include sanitized `placement`
with `owner_node`, optional `node_label`, and `reservation.state`:
`reserved`, `queued`, `unreserved`, or `unavailable`. Reserved amounts include
mode, CPU cores, RAM/disk MB, GPU count and memory when known. Unknown values
stay null, and a terminal or paused Run may still hold capacity until cleanup.
This detail omits device identities, model names, volume paths, and native
request tokens. List summaries do not read claims.

`PATCH /runs/{run_id}` with
`{"desired_state":"cancelled","queued_only":true}` cancels only an unstarted
queued execution. If admission has already advanced, it returns `409`. Use the
[schedule interface](#schedules) to defer the same queued Run. The reservation
and cleanup rules are defined in [Resources and Devices](resources-and-devices.md).

## Checkpoint retry

`POST /runs/{run_id}/retry-plans` accepts
`{"configuration_overrides":{}}` and inspects the failed Run's retained
checkpoint. It returns eligibility, reasons, preserved/retried steps, and the
attempt/checkpoint selection when available. Stored history without a Core
control record is inspectable but ineligible; owner unavailability remains an
availability error.

`POST /runs/{run_id}/retries` requires `Idempotency-Key` and this body shape:

```json
{
  "expected_attempt": 1,
  "checkpoint_revision": "<64-lowercase-hex-revision-from-plan>",
  "configuration_overrides": {},
  "admission_policy": "start_now"
}
```

The revision is a placeholder to replace with the exact plan value. Overrides
are limited to 32 declared integer/string settings; booleans and compound values
are rejected. A successful submission returns `202`, retains the public Run ID,
and advances its attempt. `enqueue_if_busy` explicitly queues a compatible
retry. Preserve the original key, expected attempt, revision, and overrides
when reconciling a lost response. See [Reliability](reliability.md#manual-checkpoint-retry)
for integrity and replay limits.

## Schedules

All paths below are beneath `/api/v1`. Requests require the configured API
authentication. Schedules target an existing durable Job on its owner.

| Method and path                                     | Request / result                                                                                                     |
| --------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| `POST /jobs/{job_id}/schedules`                     | `{schedule: {...}, source: {}}`; idempotent creation with `Idempotency-Key`, returns `201`.                          |
| `GET /schedules?owner_node=<node>`                  | Lists the selected owner's schedules and queued starts.                                                              |
| `GET /schedules/{schedule_id}?owner_node=<node>`    | Detail and current ETag.                                                                                             |
| `PATCH /schedules/{schedule_id}?owner_node=<node>`  | Requires `If-Match`; `schedule` contains changes, or `desired_state` is `running`/`paused` for an ordinary schedule. |
| `DELETE /schedules/{schedule_id}?owner_node=<node>` | Requires `If-Match`; returns the owner's deletion/cancellation receipt with `200`.                                   |

An admission queue entry is `kind: resource_wait`, named `queue_<run-id>`.
For that projection, PATCH accepts `{"schedule":{"run_at":"<future-ISO-time>"}}`
to defer the same unstarted Run. DELETE cancels only the queued start; it cannot
cancel an admitted execution. Refresh and resolve a revision conflict before
retrying. [Schedules and Events](schedules-and-events.md) owns cron, occurrence
deduplication, service windows, and queue lifecycle details.

## Stable Job MCP and real-time responses

Prepared Jobs expose the SDK-owned `mn.mcp.supervision.v1` profile through this
Job-bound Streamable HTTP endpoint. The prepared declaration includes a staged
manual/hash, tool schemas, and any declared worker service. Older definitions
missing that contract require a definition update before supervision:

```text
POST /api/v1/jobs/{job_id}/mcp
```

It uses the same bearer-authentication policy as protected REST routes. The URL
binds the MCP session to one Job; no tool accepts a `job_id`, so a caller cannot
switch Jobs through tool arguments. Discover the current tools and availability
through `get_capabilities`; the endpoint includes lifecycle effects:

| Tool                                                                                              | Result                                                                                 |
| ------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------- |
| `get_user_manual()`, `get_capabilities()`                                                         | Installed manual/hash, profile, declared schemas, effects, and current readiness.      |
| `get_job_profile()`                                                                               | Blueprint identity, mission, safe configuration, schedule, and lifecycle state.        |
| `get_job_context(evidence_limit=50)`                                                              | Combined profile, schedule, latest-run summary, warnings, and truncation metadata.     |
| `get_run_status(run_id?)`, `get_run_results(run_id?)`                                             | Actual runtime state or bounded published results; omitted Run selects the latest.     |
| `watch_job_activity(after_event_id?, wait_seconds=20)`                                            | One activity/cursor, waiting at most 25 seconds; does not acknowledge a human notice.  |
| `get_operation_status(operation_id)`                                                              | Observed status of an operation belonging to this Job.                                 |
| `start_run(request_id)`                                                                           | Explicitly starts from saved validated configuration.                                  |
| `pause_run(request_id, run_id)`, `resume_run(request_id, run_id)`, `stop_run(request_id, run_id)` | Core-owned lifecycle transitions; stop means cancellation.                             |
| Declared domain tools                                                                             | Exact schemas/effects from the prepared Job and its owner-routed worker service.       |
| `ask_job`, optional `get_job_turn`                                                                | Conversational response tools when the Job enables the corresponding response service. |

Standard results use `mn.mcp.tool_result.v1` with Job/blueprint/run identity,
request ID, status, optional operation ID, data, and sanitized error. Mutating
tools require a non-empty request ID of at most 128 characters. Reusing it with
changed arguments conflicts; accepted work is reconciled through
`get_operation_status`, not assumed complete from acknowledgement. Run IDs are
checked against the bound Job. Domain effects can require declared live read
preflight. Archived Jobs remain readable but cannot perform effects.

Context data uses `mn.mcp.job_context.v1`. The lifecycle projection is one of
`never_run`, `running`, `idle`, `paused`, `scheduled_waiting`, or `archived`.
The endpoint remains readable without an active target Run, including before
the first Run and after completion or failure. If a recent Run's workflow or
result data is temporarily unavailable, the result keeps the stable profile and
adds a warning instead of failing the complete tool call.

Tool envelopes are bounded to 256 KiB; context includes at most 50 evidence records. Read projections omit
secrets, credentials, environment values, raw logs, host paths, arbitrary
files, and unrestricted artifact bodies. These redaction bounds do not make
the endpoint read-only; protect the configured API credential as authority for
advertised lifecycle/domain effects. Deleted, unknown, and non-enabled Jobs
return sanitized errors.

An authored `mn.response` extension enables the generated `response_service`
and its conversational tools. `ask_job` accepts at most 8,000 question
characters, a UUID conversation ID, and a 128-character request ID. Answer data
uses `mn.mcp.job_answer.v1`, bounded to 12,000 answer characters, 20 citations,
and 64 KiB. Response queries do not create Runs; bounded conversation state
belongs to Job data. Read the advertised response contract for synchronous or
operation-based behavior.

Sources: `mn-api/mn_api/job_supervision.py`, `job_mcp.py`, SDK
`packages/common/src/mn_sdk_common/mcp.py`, and
`packages/mcp/src/mn_sdk_mcp/supervision.py` / `supervisor.py`.

## Examples

### List and continue a collection

```bash
curl -s "http://localhost:54001/api/v1/runs?page_size=50"
```

If `next_page_token` is not `null`:

```bash
curl -sG http://localhost:54001/api/v1/runs \
  --data-urlencode "page_size=50" \
  --data-urlencode "page_token=<next-page-token>"
```

### Upload a bundle and create a Job

Public requests never contain host paths or raw payload paths.

```bash
curl -s -X POST http://localhost:54001/api/v1/bundles \
  -F "bundle=@./worker-bundle.zip"
```

Use the returned opaque `bundle_id`:

```bash
curl -i -X POST http://localhost:54001/api/v1/jobs \
  -H "Content-Type: application/json" \
  -H "Idempotency-Key: <uuid>" \
  -d '{"bundle_id":"<bundle-id>"}'
```

Catalog jobs may instead use `{"blueprint_id":"<blueprint-id>"}`.

### Start and control a Run

```bash
curl -i -X POST http://localhost:54001/api/v1/jobs/<job-id>/runs \
  -H "Content-Type: application/json" \
  -H "Idempotency-Key: <uuid>" \
  -d '{"inputs":{}}'
```

The response is an accepted Run with `202 Accepted`; it can be pending or,
with explicit queue admission, queued. Pause, resume, or cancel active work
through one desired-state update:

Catalog-backed Jobs may also send `config_overrides`. When they change saved
configuration, the API rebuilds and prepares the Job definition before starting the Run;
`inputs` remains reserved for runtime workflow input rather than blueprint
configuration.

```bash
curl -s -X PATCH http://localhost:54001/api/v1/runs/<run-id> \
  -H "Content-Type: application/json" \
  -d '{"desired_state":"paused"}'
```

Invalid state transitions return `409 Conflict`.

### Add a blueprint and monitor preparation

Prerequisites: run `mn-api` with its blueprint catalog configured, choose an ID
returned by `GET /blueprints`, and authenticate when `MN_API_TOKEN` is set. The
request validates the blueprint bundle, prepares required runtime models and
services, and records the blueprint locally. It does not require a separate
`mn blueprint add` command.

```bash
curl -i -X POST http://localhost:54001/api/v1/blueprints/<blueprint-id>/additions \
  -H "Content-Type: application/json" \
  -H "Idempotency-Key: <uuid>" \
  -d '{"force":false}'
```

The response is `202 Accepted`. Its `Location` header identifies an Operation,
and the body initially resembles:

```json
{
  "operation_id": "op-local-<opaque-id>",
  "kind": "add_blueprint",
  "status": "pending",
  "progress": {
    "percent": 0,
    "stage": "queued",
    "label": "Queued",
    "detail": "The operation is queued on the local API host."
  }
}
```

Poll the Operation until `status` is `completed` or `failed`:

```bash
curl -s http://localhost:54001/api/v1/operations/<operation-id>
```

`progress.percent` is monotonic and bounded from `0` through `100`; successful
completion sets it to `100`. Addition stages include `queued`, `starting`,
`resolve_blueprint`, `validate_blueprint`, `prepare_runtime`,
`record_addition`, and `completed`; clients should present the supplied `label`
and `detail` and must tolerate new stage names. A completed Operation contains
`result.added`, the public `result.blueprint`, its `result.addition`, and a
sanitized `result.runtime_preparation` summary.

After completion, `GET /blueprints/<blueprint-id>` and collection items expose
addition state without the retired installation vocabulary:

```json
{
  "id": "<blueprint-id>",
  "added": true,
  "addition": {
    "blueprint_id": "<blueprint-id>",
    "status": "added",
    "added_at": "<timestamp>",
    "revision": "<revision>"
  }
}
```

If runtime preparation fails, the Operation has `status: "failed"` and a
sanitized `error` with `code`, `title`, `detail`, `retryable`, optional `hint`,
and bounded prerequisite `errors`. `MN_BLUEPRINT_ADD_FAILED` means a required
runtime prerequisite was not ready; correct the reported prerequisite and send
a new addition request with a new idempotency key.

> **Warning:** `{"force":true}` passes a compatibility override into runtime
> prerequisite preparation. Use it only after reviewing the failed check; it
> can admit a configuration that the normal compatibility path rejects.

### Remove an added blueprint

> **Warning:** removal archives the local addition record and, by default,
> removes blueprint-owned runtime resources, including cleanup-owned files.
> Deleted runtime data is not restored by adding the blueprint again. Run a dry
> run first or set `keep_resources` when those resources must remain.

Preview removal without changing state:

```bash
curl -i -X POST http://localhost:54001/api/v1/blueprints/<blueprint-id>/removals \
  -H "Content-Type: application/json" \
  -H "Idempotency-Key: <uuid>" \
  -d '{"dry_run":true}'
```

Then submit the intended policy with a new idempotency key. This example keeps
runtime resources and model images:

```bash
curl -i -X POST http://localhost:54001/api/v1/blueprints/<blueprint-id>/removals \
  -H "Content-Type: application/json" \
  -H "Idempotency-Key: <uuid>" \
  -d '{"keep_resources":true,"keep_models":true}'
```

The request fields are:

| Field            | Default | Effect                                                                           |
| ---------------- | ------- | -------------------------------------------------------------------------------- |
| `keep_resources` | `false` | Preserve blueprint-owned runtime resources instead of cleaning them up.          |
| `keep_models`    | `false` | Explicitly retain model images after releasing this blueprint's ownership.       |
| `remove_models`  | `false` | Remove model images that become orphaned; cannot be combined with `keep_models`. |
| `dry_run`        | `false` | Plan the archive, resource cleanup, and model changes without applying them.     |

Removal is also asynchronous. Poll its Operation or follow the Operation SSE
stream, then verify that the blueprint projection reports `added: false` and
`addition.status: "not_added"`. Re-adding can recreate runtime prerequisites,
but it cannot recover resources or data deleted by removal.

The former `GET /blueprints/<blueprint-id>/installation`,
`PUT /blueprints/<blueprint-id>/installation`, and
`DELETE /blueprints/<blueprint-id>/installation` routes are removed and return
`404`; clients must migrate to additions and removals.

## Model catalog and default installation

`GET /api/v1/models` includes all catalog models and discovered installations
by default. Its paginated items carry `default: true` for the configured
default/fallback chain. Use `?installed_only=true` for installed models only;
`GET /api/v1/models/<model-id>` retains the individual detail view.

`PUT /api/v1/models/default/installation` with JSON body `{}` eagerly prepares
the first compatible configured default on a local or cluster node. It uses
catalog overrides and fallbacks without changing the default policy. The
existing request options are `backend` (default `auto`), optional `context_size`,
and `force` (default `false`). DMR options are rejected for provider defaults.
Send `Idempotency-Key` for safe replay. The response is `202` with an Operation
Location; poll or follow its SSE stream for completion and sanitized failures.
Explicit model installation uses the same background SDK preparation boundary.

## Server-Sent Events

The only realtime HTTP surfaces are authenticated, resumable SSE:

```text
GET /runs/{run_id}/events/stream
GET /operations/{operation_id}/events/stream
```

Every event uses this envelope:

```json
{
  "id": "42",
  "type": "run.snapshot",
  "occurred_at": "2026-08-13T17:00:00Z",
  "resource": "/api/v1/runs/<run-id>",
  "data": {}
}
```

Event IDs increase monotonically. On reconnect, send the last applied value as
`Last-Event-ID`. The server replays available later events, sends heartbeat
comments while idle, releases stream resources on disconnect, and closes after
a terminal event. Keep ordinary snapshot and history GETs as the recovery
source of truth.

API-owned addition and removal Operations emit `operation.accepted`,
`operation.progress`, and one terminal `operation.completed` or
`operation.failed` event. Each event's `data` is the current Operation snapshot,
including its progress and terminal result or error.

```bash
curl -N http://localhost:54001/api/v1/runs/<run-id>/events/stream \
  -H "Authorization: Bearer <token>" \
  -H "Last-Event-ID: <last-event-id>"
```

## Artifact handling

Artifact and output lists contain download URLs beneath the public Run. They do
not expose host filesystem paths and there is no server-side “reveal” action.
Browser clients download or open the artifact; native clients may reveal the
downloaded local file using their own platform integration.

## CLI and SDK terminology

Use `mn job` for durable definitions and `mn run` for executions. The Python
SDK exposes typed pages, revision-aware conditional updates, and idempotent
create/dispatch methods while keeping HTTP-specific headers and Problem Details
adaptation inside `mn-api`.

Blueprint lifecycle terminology also matches the CLI: the REST API creates
blueprint additions and removals; it does not expose a blueprint installation
resource. Installation remains valid terminology for model resources.

Common operator commands include:

```bash
mn runtime status
mn node list
mn job list
mn run list
```

See [CLI Reference](cli.md) for the complete command surface.
