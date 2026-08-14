# MirrorNeuron REST API

This page describes the canonical HTTP API used by the Web UI, OtterDesk, and
HTTP automation. The CLI and Python SDK also use internal gRPC interfaces; the
gRPC `v2` package name and domain schema labels such as `mn.workflow/v2` are
independent of the REST version.

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
  creation, schedule dispatch, and administrative operations. Replay records
  last 24 hours; reusing a key for another request returns `409 Conflict`.
- Persistent jobs, schedules, deployments, model registrations, and blueprint
  installations return strong `ETag` headers. Their `PATCH` and `DELETE`
  requests require `If-Match`; missing and stale conditions return `428` and
  `412`, respectively.
- Errors use `application/problem+json` with `type`, `title`, `status`,
  `detail`, `instance`, `code`, `request_id`, and bounded field `errors` when
  applicable.

## Resource overview

| Area | Canonical resources |
| --- | --- |
| Health and system | `/health`, `/runtime/status`, `/runtime/health`, `/runtime/diagnostics`, `/runtime/resources`, `/system/summary`, `/metrics` |
| Jobs | `/jobs`, `/jobs/{job_id}`, `/jobs/{job_id}/bundle`, `/jobs/{job_id}/data-resets` |
| Runs | `/jobs/{job_id}/runs`, `/blueprints/{blueprint_id}/runs`, `/runs`, `/runs/{run_id}` |
| Run detail | `/runs/{run_id}/monitor`, `/workflow-progress`, `/logs`, `/events`, `/resources`, `/human-requests`, `/ui`, `/artifacts`, `/outputs`, `/snapshots`, `/agent-graph`, `/export`, `/observability` |
| Bundles and blueprints | `/bundles`, `/blueprints`, `/blueprints/{blueprint_id}`, `/installation`, `/validations`, `/runs` |
| Schedules and events | `/jobs/{job_id}/schedules`, `/schedules`, `/schedules/{schedule_id}`, `/dispatches`, `/trigger-events` |
| Infrastructure | `/nodes`, `/deployments`, `/models`, `/model-remotes`, `/model-proxies`, `/services`, `/service-checks` |
| Operations | `/operations`, `/operations/{operation_id}` |

Durable configured work is a Job. One execution of that definition is a Run.
Run URLs always use the public `run_id`; `runtime_run_id` is diagnostic metadata
and is never part of a client URL.

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

### Install a blueprint conditionally

Read the current installation and retain its `ETag`, then use `If-Match` when
replacing or deleting it. Initial creation may omit `If-Match`.

```bash
curl -i -X PUT http://localhost:54001/api/v1/blueprints/<blueprint-id>/installation \
  -H "Content-Type: application/json" \
  -H "Idempotency-Key: <uuid>" \
  -d '{}'
```

Installation and removal return an Operation. Poll the `Location` resource or
stream its events.

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

Common operator commands include:

```bash
mn runtime health
mn node list
mn job list
mn run list
```

See [CLI Reference](cli.md) for the complete command surface.
