# MirrorNeuron API

This document describes the read and control APIs used by the CLI, Web UI,
OtterDesk, and automation tools.

## HTTP REST API

`mn-api` is a FastAPI gateway over the Python SDK and MirrorNeuron gRPC runtime.
It keeps browser and desktop clients out of the raw gRPC layer while preserving
the runtime's job, run, model, service, schedule, resource, and cluster
semantics.

Default local base URL:

```text
http://localhost:54001/api/v1
```

Set `MN_API_PORT` to change the port. Use `MN_ENV=prod` with `MN_API_TOKEN` for
protected deployments.

## Endpoint Overview

| Method | Endpoint | Purpose |
| --- | --- | --- |
| `GET` | `/health` | API liveness and dependency status. |
| `GET` | `/runtime/status` | Local runtime status summary. |
| `GET` | `/system/summary` | Cluster nodes, active jobs, and system overview. |
| `GET` | `/metrics` | Runtime metrics summary. |
| `POST` | `/jobs` | Submit a manifest JSON payload or uploaded bundle path. |
| `GET` | `/jobs` | List jobs with `limit` and `include_terminal`. |
| `GET` | `/jobs/{job_id}` | Get compact, summary, or full job detail. |
| `POST` | `/jobs/{job_id}/cancel` | Cancel a job. |
| `POST` | `/jobs/{job_id}/pause` | Pause a job. |
| `POST` | `/jobs/{job_id}/resume` | Resume a paused job. |
| `GET` | `/jobs/{job_id}/events` | Stream or list raw runtime events. |
| `GET` | `/jobs/{job_id}/workflow-progress` | Normalized progress, trace, and failure state. |
| `GET` | `/jobs/{job_id}/dead-letters` | Dead-letter events for routing or processing failures. |
| `POST` | `/jobs/cleanup` | Clear terminal job records. |
| `POST` | `/bundles/upload` | Upload a bundle zip for later validation or launch. |
| `GET` | `/blueprints` | List catalog blueprints and categories. |
| `GET` | `/blueprints/{blueprint_id}` | Get one catalog blueprint. |
| `POST` | `/blueprints/{blueprint_id}/install` | Install required runtime models for a blueprint. |
| `POST` | `/blueprints/{blueprint_id}/validate` | Validate catalog blueprint inputs and requirements. |
| `POST` | `/blueprints/{blueprint_id}/runs` | Launch a catalog blueprint run. |
| `POST` | `/blueprints/launch/validate` | Validate a launch source such as an uploaded bundle. |
| `POST` | `/blueprints/launch/runs` | Launch an uploaded or local bundle source. |
| `GET` | `/blueprints/launch/progress/{progress_id}` | Read model-install, validation, and submit progress. |
| `GET` | `/runs/{run_id}/result` | Read run result metadata. |
| `GET` | `/runs/{run_id}/final-artifact` | Read the final run artifact. |
| `GET` | `/runs/{run_id}/artifacts` | List run-store artifacts with metadata and URLs. |
| `GET` | `/runs/{run_id}/outputs` | List user-facing outputs. |
| `GET` | `/runs/{run_id}/events` | Read run-store events. |
| `GET` | `/runs/{run_id}/logs` | Read structured run logs. |
| `GET` | `/runs/{run_id}/timeline` | Read normalized timeline records. |
| `GET` | `/runs/{run_id}/observability-summary` | Read compact observability totals. |
| `GET` | `/runs/{run_id}/stream` | Read merged run events, logs, human events, resources, and timeline channels. |
| `GET` | `/runs/{run_id}/resources` | Read resource and token usage summary. |
| `GET` | `/runs/{run_id}/human` | List human review requests and notices. |
| `POST` | `/runs/{run_id}/human/{request_id}/response` | Record a human review response. |
| `POST` | `/runs/{run_id}/human/{notice_id}/ack` | Acknowledge a human notice. |
| `GET` | `/runs/{run_id}/ui` | Read blueprint UI metadata. |
| `GET` | `/runs/{run_id}/ui/video` | Serve run video UI data when present. |
| `GET` | `/models` | List installed Docker Model Runner models visible to this node. |
| `POST` | `/models/{model_id}/benchmark` | Run a small local model benchmark. |
| `GET` | `/services` | List service-registry entries. |
| `GET` | `/services/{name}/resolve` | Resolve a passing service instance by name, tag, or node. |
| `GET` | `/resource` | Read resource totals and limits. |
| `POST`/`PUT` | `/resource` | Set coarse resource limits. |
| `POST` | `/schedules` | Create periodic, delayed, or event schedules. |
| `GET` | `/schedules` | List schedules. |
| `GET` | `/schedules/{schedule_id}` | Get one schedule. |
| `PATCH` | `/schedules/{schedule_id}` | Update schedule attributes. |
| `POST` | `/schedules/{schedule_id}/pause` | Pause a schedule. |
| `POST` | `/schedules/{schedule_id}/resume` | Resume a schedule. |
| `DELETE` | `/schedules/{schedule_id}` | Delete a schedule. |
| `POST` | `/schedules/{schedule_id}/dispatch` | Dispatch a schedule immediately. |
| `POST` | `/events` | Emit a runtime trigger event. |
| `GET` | `/events` | List recent trigger events. |
| `POST` | `/system/cluster/nodes:add` | Add or join a cluster node. |
| `POST` | `/system/cluster/nodes:join` | Join a cluster node through the REST gateway. |
| `POST` | `/system/cluster/nodes:remove` | Remove a cluster node. |
| `POST` | `/system/cluster/nodes:leave` | Leave a cluster from the local node. |

## Request Examples

### Health

```bash
curl -s http://localhost:54001/api/v1/health
```

Expected response includes:

```json
{
  "status": "ok"
}
```

### List Jobs

```bash
curl -s "http://localhost:54001/api/v1/jobs?limit=5&include_terminal=true"
```

Expected response includes a job list or an empty list, depending on runtime
state.

### Submit A Manifest

`POST /jobs` accepts a request envelope. Use `manifest_json` for a raw manifest
or `bundle_path` for an uploaded bundle path returned by `/bundles/upload`.

```bash
curl -s -X POST http://localhost:54001/api/v1/jobs \
  -H "Content-Type: application/json" \
  -d '{
    "manifest_json": "{\"apiVersion\":\"mn.workflow/v1\",\"kind\":\"Workflow\",\"workflow\":{\"workflow_id\":\"demo\",\"nodes\":[]}}"
  }'
```

Expected response:

```json
{
  "id": "<job_id>",
  "status": "pending"
}
```

For normal user-facing blueprint execution, prefer:

```bash
mn blueprint run --folder otterdesk-blueprints/tax_form_ocr_capture_assistant
```

### Launch A Catalog Blueprint

```bash
curl -s -X POST http://localhost:54001/api/v1/blueprints/portfolio_risk_review_assistant/runs \
  -H "Content-Type: application/json" \
  -d '{"force": false}'
```

Expected response includes `job_id`, `run_id`, validation state, and model
install state.

### Read Run Observability

```bash
curl -s http://localhost:54001/api/v1/runs/<run_id>/observability-summary
curl -s http://localhost:54001/api/v1/runs/<run_id>/timeline
curl -s http://localhost:54001/api/v1/runs/<run_id>/artifacts
```

These endpoints are the preferred Web UI and OtterDesk read surfaces for run
status, logs, timeline, resources, outputs, and downloadable artifacts.

## gRPC And SDK Operator Surfaces

The CLI and Python SDK primarily use gRPC for runtime control. The gRPC server
exposes JSON-safe methods for orchestration features:

| Area | Surface |
| --- | --- |
| Jobs | submit, inspect, list, cancel, pause, resume, backup, restore, dead letters |
| Reconciliation | `ReconcileNode` |
| Drain and maintenance | `DrainNode`, `CancelNodeDrain`, `SetNodeMaintenance`, `GetNodeDrainStatus` |
| Services | `ListServices`, `ResolveService`, `CheckServices` |
| Resources | resource get/set methods |
| Deployments | deploy, update, list, status, promote, rollback, pause, resume, fail methods |
| Schedules and events | create, update, list, status, pause, resume, delete, dispatch, emit, and list event methods |

Implementation entry points:

- `MirrorNeuron/lib/mirror_neuron.ex`
- `MirrorNeuron/lib/mirror_neuron_grpc/server.ex`
- `mn-python-sdk/mn_sdk/client.py`
- `mn-cli/mn_cli/main.py`
- `mn-api/mn_api/routes/`

## Public Elixir API

These functions are exposed from [MirrorNeuron](../MirrorNeuron/lib/mirror_neuron.ex)
for core/runtime code and low-level operational tools.

### Job Execution

#### `MirrorNeuron.validate_manifest(input)`

Validates a job bundle folder.

Return:

- `{:ok, bundle}`
- `{:error, reason}`

#### `MirrorNeuron.run_manifest(input, opts \\ [])`

Submits a job bundle for execution.

Important options:

- `await: boolean`
- `timeout: integer | :infinity`
- `json: boolean`
- `job_bundle: bundle` internal/advanced path

Return:

- `{:ok, job_id}` when `await: false`
- `{:ok, job_id, job}` when `await: true`
- `{:error, reason}`

#### `MirrorNeuron.wait_for_job(job_id, timeout \\ :infinity)`

Waits for terminal status: `completed`, `failed`, or `cancelled`.

### Inspection

Use the monitor read model for operational tooling:

- `MirrorNeuron.list_jobs/1`
- `MirrorNeuron.job_details/2`
- `MirrorNeuron.cluster_overview/1`
- `MirrorNeuron.events/1`
- `MirrorNeuron.inspect_nodes/0`

These calls read Redis-backed job records, agent snapshots, cluster state, and
events without requiring direct Redis access.

### Control

- `MirrorNeuron.pause(job_id)`
- `MirrorNeuron.resume(job_id)`
- `MirrorNeuron.cancel(job_id)`
- `MirrorNeuron.send_message(job_id, agent_id, message)`

These are the mutation APIs used by CLI and SDK control paths.

## Failure And Observability Model

Job details, workflow progress, failure events, and compact summaries expose a
shared `failure` object using `mn.error.v1`. Legacy `reason` and
`status_reason` remain display strings derived from `failure.desc` when
available.

Run observability uses:

- `mn.timeline.v1`
- `mn.observability_summary.v1`
- `errors.jsonl`
- `events.jsonl`
- `logs.jsonl`
- `timeline.jsonl`
- `resource_samples.jsonl`

Clients should link to large artifacts instead of embedding log blobs in job
detail views.

## Terminal CLI

The user-facing CLI is `mn`.

Common commands:

```bash
mn runtime health
mn node list
mn job status <job_id>
mn job monitor <job_id>
mn blueprint monitor
mn blueprint export <run_id> --format markdown
```

The CLI uses the Python SDK over gRPC for most control paths. See
[CLI Reference](cli.md).

## Stability Guidance

For future tools, prefer consuming:

1. FastAPI run and job endpoints for browser/desktop clients.
2. Python SDK methods for Python automation.
3. `MirrorNeuron.list_jobs/1`, `MirrorNeuron.job_details/2`, and `MirrorNeuron.cluster_overview/1` for BEAM-side tooling.

Avoid coupling directly to raw Redis keys unless you are building low-level
operational tooling.
