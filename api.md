# MirrorNeuron REST API

This page describes the canonical HTTP API used by the Web UI, OtterDesk, and
HTTP automation. The CLI and Python SDK also use internal gRPC interfaces; the
gRPC `v2` package name and domain schema labels such as `mn.workflow/v2` are
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

`/api/v2`, historical aliases, `/runtime-runs`, and WebSocket routes are not
supported and return `404`.

## Common conventions

- JSON fields use `snake_case`; request bodies reject unknown fields.
- Collection responses are `{ "items": [], "next_page_token": null }`.
- `page_size` defaults to `50` and is capped at `200`. Pass the opaque
  `page_token` unchanged to continue. Tokens expire after 24 hours and are
  bound to the route, principal, filters, and stable sort.
- Synchronous creation returns `201 Created` with `Location`. Accepted Runs and
  Operations return `202 Accepted` with `Location`. Updates return `200`; a
  completed deletion returns `204 No Content`.
- Send `Idempotency-Key` on non-idempotent POST requests, especially Run
  creation, blueprint addition or removal, schedule dispatch, and
  administrative operations. Replay records last 24 hours; reusing a key for
  another request returns `409 Conflict`.
- Persistent jobs, schedules, deployments, model registrations, and model
  installations return strong `ETag` headers. Their `PATCH` and `DELETE`
  requests require `If-Match`; missing and stale conditions return `428` and
  `412`, respectively.
- Errors use `application/problem+json` with `type`, `title`, `status`,
  `detail`, `instance`, `code`, `request_id`, and bounded field `errors` when
  applicable. Work that fails after a `202 Accepted` response records its
  terminal failure on the Operation instead of returning a second HTTP error.

## Resource overview

| Area | Canonical resources |
| --- | --- |
| Health and system | `/health`, `/runtime/status`, `/runtime/health`, `/runtime/diagnostics`, `/runtime/resources`, `/system/summary`, `/metrics` |
| Jobs | `/jobs`, `/jobs/{job_id}`, `/jobs/{job_id}/bundle`, `/jobs/{job_id}/data-resets`, `/jobs/{job_id}/mcp` |
| Runs | `/jobs/{job_id}/runs`, `/blueprints/{blueprint_id}/runs`, `/runs`, `/runs/{run_id}` |
| Run detail | `/runs/{run_id}/monitor`, `/workflow-progress`, `/logs`, `/events`, `/resources`, `/human-requests`, `/ui`, `/artifacts`, `/outputs`, `/snapshots`, `/agent-graph`, `/export`, `/observability` |
| Bundles and blueprints | `/bundles`, `/blueprints`, `/blueprints/{blueprint_id}`, `/additions`, `/removals`, `/validations`, `/runs` |
| Schedules and events | `/jobs/{job_id}/schedules`, `/schedules`, `/schedules/{schedule_id}`, `/dispatches`, `/trigger-events` |
| Infrastructure | `/nodes`, `/deployments`, `/models`, `/model-remotes`, `/model-proxies`, `/services`, `/service-checks` |
| Operations | `/operations`, `/operations/{operation_id}` |

Durable configured work is a Job. One execution of that definition is a Run.
Run URLs always use the public `run_id`; `runtime_run_id` is diagnostic metadata
and is never part of a client URL.

## Stable supervisory MCP

A blueprint that explicitly declares `mcp_collaboration.enabled` with the
standard `mn-job-collaboration`, `streamable-http`, and `/mcp` descriptor gives
each of its stable Jobs this Streamable HTTP endpoint:

```text
POST /api/v1/jobs/{job_id}/mcp
```

It uses the same bearer-authentication policy as protected REST routes. The URL
binds the MCP session to one Job; no tool accepts a `job_id`, so a caller cannot
switch Jobs through tool arguments. Tool discovery returns exactly these
read-only tools:

| Tool | Result |
| --- | --- |
| `get_job_profile()` | Blueprint identity, mission, capabilities, safe configuration, schedule, and lifecycle state. |
| `get_latest_run()` | Bounded latest-run status, result projection, structured evidence, warnings, and timestamps. |
| `get_job_context(evidence_limit=50)` | Combined profile, schedule, latest-run summary, warnings, and truncation metadata. |

Results use `mn.mcp.stable_job_context.v1`. The lifecycle projection is one of
`never_run`, `running`, `idle`, `paused`, `scheduled_waiting`, or `archived`.
The endpoint remains readable without an active target Run, including before
the first Run and after completion or failure. If a recent Run's workflow or
result data is temporarily unavailable, the result keeps the stable profile and
adds a warning instead of failing the complete tool call.

Each response is bounded to 256 KiB and 50 evidence records. Projections omit
secrets, credentials, environment values, raw logs, host paths, arbitrary
files, and unrestricted artifact bodies. The tools cannot start, pause,
configure, schedule, approve, or otherwise mutate the Job. Archived Jobs remain
readable; deleted, unknown, and non-enabled Jobs return the same sanitized
not-found class of error.

Do not confuse this API-owned supervisory MCP with the runtime
`mn-job-collaboration` service. The latter exists only during an active Run and
supports peer-to-peer collaboration among executing workers. Its service
discovery, active-run lifetime, and human-approval behavior are unchanged.

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

The response is a pending Run with `202 Accepted`. Pause, resume, or cancel it
through one desired-state update:

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

| Field | Default | Effect |
| --- | --- | --- |
| `keep_resources` | `false` | Preserve blueprint-owned runtime resources instead of cleaning them up. |
| `keep_models` | `false` | Explicitly retain model images after releasing this blueprint's ownership. |
| `remove_models` | `false` | Remove model images that become orphaned; cannot be combined with `keep_models`. |
| `dry_run` | `false` | Plan the archive, resource cleanup, and model changes without applying them. |

Removal is also asynchronous. Poll its Operation or follow the Operation SSE
stream, then verify that the blueprint projection reports `added: false` and
`addition.status: "not_added"`. Re-adding can recreate runtime prerequisites,
but it cannot recover resources or data deleted by removal.

The former `GET /blueprints/<blueprint-id>/installation`,
`PUT /blueprints/<blueprint-id>/installation`, and
`DELETE /blueprints/<blueprint-id>/installation` routes are removed and return
`404`; clients must migrate to additions and removals.

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
