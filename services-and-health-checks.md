# Services And Health Checks

MirrorNeuron has a native Redis-backed service registry and generic health check layer. It is inspired by Nomad's `service` and `check` blocks: jobs declare services, checks decide whether service instances are discoverable, and registration follows job or agent lifecycle.

Service discovery remains generic: blueprints and skills declare service endpoints and health checks for Ollama, vLLM, vector databases, and provider-specific services. Local Docker Model Runner LLMs are managed separately with `mn model`; see [Model Runtime](model-runtime.md).

## Design Concept

Service support has three parts:

- `services` and `nodes[].services` declare what a job or agent provides
- `required_services` and `nodes[].requires_services` declare what must exist before the job starts or before a node can be selected
- health checks mark service instances `passing`, `warning`, or `critical`

Only passing services are returned by discovery by default. Critical services stay in the registry for inspection but are not normal routing targets.

## Manifest Fields

Top-level fields:

```json
{
  "services": [],
  "required_services": []
}
```

Node-level fields:

```json
{
  "nodes": [
    {
      "node_id": "agent_api",
      "services": [],
      "requires_services": []
    }
  ]
}
```

Use top-level `required_services` for external or cluster-wide requirements that must pass before the job starts. Use node-level `requires_services` when placement should target a node that already has a healthy matching local service.

## Service Declaration

```json
{
  "name": "ollama",
  "id": "ollama-local",
  "address": "${config.ollama.host}",
  "port": "${config.ollama.port}",
  "tags": ["llm", "local"],
  "meta": {
    "model_family": "qwen"
  },
  "provider": "mirror_neuron",
  "origin": "external",
  "checks": [
    {
      "name": "http-health",
      "type": "http",
      "url": "${config.ollama.api_base}/api/tags",
      "method": "GET",
      "expected_status": 200,
      "timeout_ms": 2000,
      "interval_ms": 10000,
      "required": true,
      "failures_before_critical": 1
    }
  ]
}
```

Supported service fields:

| Field | Meaning |
| --- | --- |
| `name` | Required service name. |
| `id` | Optional stable instance id. Defaults from job, agent, and service name. |
| `address` | Host or IP. Supports templates. |
| `port` | Explicit port. Supports templates. |
| `tags` | Discovery filters. |
| `meta` | JSON metadata stored with the service. |
| `provider` | `mirror_neuron` in v1. |
| `origin` | `internal` for runtime registered services, `external` for dependencies outside the job. |
| `checks` | HTTP, TCP, script, or gRPC check declarations. |

Templates supported in string fields include:

- `${config.llm.api_base}`
- `${env.MN_LLM_API_BASE}`
- `${node}`
- `${job_id}`
- `${agent_id}`
- `${service.address}`
- `${service.port}`

Blueprint config comes from `config/default.json`, `config/overwrite.json`, and runtime overrides when available.

## Check Types

HTTP:

```json
{
  "type": "http",
  "path": "/health",
  "address": "127.0.0.1",
  "port": 11434,
  "method": "GET",
  "expected_status": 200,
  "contains": "ok"
}
```

TCP:

```json
{
  "type": "tcp",
  "address": "127.0.0.1",
  "port": 6379
}
```

Script:

```json
{
  "type": "script",
  "command": ["python3", "payloads/check_model_cache.py"],
  "timeout_ms": 5000
}
```

Script commands run without shell expansion unless the blueprint explicitly invokes a shell as the command. Validation rejects unsafe single-string command shapes with shell metacharacters.

gRPC:

```json
{
  "type": "grpc",
  "address": "127.0.0.1",
  "port": 50051,
  "service": "grpc.health.v1.Health"
}
```

## Validation And Preflight

`mn blueprint validate <bundle>` validates service declarations after manifest/schema checks and before input validation. `mn blueprint run --folder <bundle>` runs the same local preflight, and core repeats service preflight before direct runtime starts.

Failed required services stop the job before agents launch. A forced run can skip service preflight, and job metadata records the skipped check.

Run service checks directly:

```bash
mn service check /path/to/bundle
mn service check /path/to/bundle --output json
```

## Discovery Commands

List passing services:

```bash
mn service list
```

Include warning and critical services:

```bash
mn service list --all
```

Resolve one service:

```bash
mn service resolve ollama --tag llm
```

Filter by node:

```bash
mn service resolve vllm --node mirror_neuron@192.168.4.20
```

## Blueprint Web UI Services

Blueprints keep using their existing `config.web_ui` contract. For live/service blueprints with `web_ui.output.adapter: "gradio"`, launch preparation injects a runtime-managed `web_ui_dashboard` HostLocal agent and registers its dashboard as a service:

```json
{
  "name": "blueprint-web-ui",
  "tags": ["web_ui", "blueprint", "<blueprint_id>", "gradio"],
  "meta": {
    "run_id": "<run_id>",
    "blueprint_id": "<blueprint_id>",
    "url": "http://localhost:58000",
    "adapter": "gradio"
  }
}
```

The generated service reserves an explicit HTTP port from `MN_BLUEPRINT_WEB_UI_PORT_START`/`MN_BLUEPRINT_WEB_UI_PORT_END` and includes an HTTP readiness check. Discovery returns it as passing only after the Gradio dashboard is reachable. Runtime dashboards read live events through the mn-api run events endpoint when the run store is outside the Core container, and fall back to `events.jsonl` when no API event source is configured. The dashboard still writes `ui.json` and `web_ui.json` under the run store for older OtterDesk and CLI consumers, but the service registry is the authoritative live-service source.

## Runtime Behavior

- job-level services register when the job starts
- agent-level services register when the agent starts
- the service monitor refreshes checks periodically
- failed checks mark instances critical after `failures_before_critical`
- discovery hides non-passing instances by default
- agent-scoped services deregister when an agent stops, is rescheduled, or the job is cancelled
- deployment metadata is attached to service instances so canary or candidate versions can be hidden until promotion

## Important Code

| Area | Files |
| --- | --- |
| Manifest service shape | `MirrorNeuron/lib/mirror_neuron/service_spec.ex` |
| One-shot checks | `MirrorNeuron/lib/mirror_neuron/service_check.ex` |
| Preflight | `MirrorNeuron/lib/mirror_neuron/service_preflight.ex` |
| Registry | `MirrorNeuron/lib/mirror_neuron/service_registry.ex` |
| Periodic monitor | `MirrorNeuron/lib/mirror_neuron/service_monitor.ex` |
| Job registration and deregistration | `MirrorNeuron/lib/mirror_neuron/runtime/job_coordinator.ex` |
| Redis storage | `MirrorNeuron/lib/mirror_neuron/persistence/redis_store.ex` |
| Scheduler node-scoped requirements | `MirrorNeuron/lib/mirror_neuron/scheduler.ex` |
| CLI commands | `mn-cli/mn_cli/libs/service_cmds.py` |
| Blueprint validation | `mn-python-sdk/mn_sdk/blueprint_validation.py` |
| SDK client | `mn-python-sdk/mn_sdk/client.py` |
