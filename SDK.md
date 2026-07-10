# Python SDK Reference

The MirrorNeuron Python SDK provides:

- a gRPC client for the core runtime
- workflow and agent decorators for pure Python bundle authoring
- a compiler that turns restricted Python workflow definitions into normal MirrorNeuron bundles

## Install For Local Development

From the workspace root:

```bash
.venv/bin/python -m pip install -e mn-python-sdk
```

Expected output:

```text
Successfully installed mirrorneuron-python-sdk
```

The `mn-system-tests/requirements.txt` file installs the SDK and CLI together for test runs.

## Client Usage

```python
from mn_sdk import Client

client = Client(target="localhost:55051")

manifest_json = '{"manifest_version": "1.0", "graph_id": "simple", "nodes": [], "edges": []}'
job_id = client.submit_job(manifest_json, payloads={})

print(job_id)
print(client.get_job(job_id))
```

Important environment variables:

| Variable | Default | Description |
| --- | --- | --- |
| `MN_GRPC_TARGET` | `localhost:55051` | Runtime gRPC endpoint for the local deployed runtime. |
| `MN_GRPC_TIMEOUT_SECONDS` | `10` | Per-RPC timeout. |
| `MN_GRPC_AUTH_TOKEN` | unset | Optional bearer token metadata. |
| `MN_SDK_LOG_PATH` | `$MN_HOME/logs/sdk.log` | SDK log path. |

## Python-Defined Workflows

Use decorators to author workflows in Python:

```python
from mn_sdk import agent, workflow

TOPIC = workflow.input("topic", default="electric vehicle charging adoption")


class ResearchAgents:
    @agent.defn(
        name="ingress",
        type="map",
        runner="host_local",
        retries={"max_attempts": 2, "backoff_ms": 250},
        backpressure={"max_queue_depth": 20},
    )
    def ingress(self, topic: str):
        return {
            "message_type": "research_request",
            "topic": topic,
            "text": "Collect a short research summary.",
        }

    @agent.defn(name="reviewer", type="reduce")
    def reviewer(self, result):
        return {"status": "saved", "summary": result.get("summary")}


@workflow.defn(
    name="marketing_research_flow_v1",
    recovery_mode="local_restart",
)
class MarketingResearchFlow:
    def __init__(self):
        self.agents = ResearchAgents()

    @workflow.run
    def run(self):
        request = self.agents.ingress(TOPIC)
        return self.agents.reviewer(request)
```

Generate a Python-defined blueprint from a local source-mode blueprint folder:

```bash
cd path/to/python-source-blueprint
.venv/bin/python -m pip install -e ../../mn-skills/blueprint_support_skill
python -m mn_blueprint_support.python_workflow_bundle_cli \
  --blueprint-dir . \
  --quick-test \
  --output-dir /tmp/mn-python-research
```

Expected output:

```text
bundle generated
```

Validate:

```bash
mn blueprint validate /tmp/mn-python-research
```

Expected output:

```text
Job bundle at '/tmp/mn-python-basic' is valid.
```

## Compiler Model

The Python SDK compiler is a bundle compiler.

It does:

- parse the decorated workflow class
- map agent method calls to graph nodes
- map call order and return flow to graph edges
- resolve literals, safe module constants, and `workflow.input(...)`
- package declared includes and payload files
- emit a normal `manifest.json` plus `payloads/`

It does not:

- execute arbitrary workflow expressions during compilation
- use `eval()` for non-literal arguments
- run Python workflow code as a durable orchestrator at job runtime
- provide Temporal-style event-history replay
- provide deterministic clock, random, or command APIs

If you need durable long-running behavior, set the workflow type to `service` and use MirrorNeuron workflow features such as stream agents, recovery policies, retries, backpressure, and persisted agent snapshots.

## Agent Options

`@agent.defn(...)` supports these commonly used fields:

| Field | Purpose |
| --- | --- |
| `name` | Node id in the generated bundle. |
| `type` | Behavioral template such as `map`, `reduce`, `stream`, or `batch`. |
| `runner` | Runner choice such as `host_local` or OpenShell-backed execution. |
| `retries` | Retry policy. |
| `pool` | Executor pool name. |
| `backpressure` | Node-level queue and pressure policy. |
| `env` | Explicit worker environment values. |
| `pass_env` | Environment variables copied from the host into the worker. |
| `uploads` | Payload files to stage for execution. |
| `policy` | Runner policy file, usually OpenShell network policy. |
| `timeout_seconds` | Worker command timeout. |
| `resources` | CPU, memory, disk, GPU/device, port, volume, and runtime-driver requirements. |
| `services` | Agent-scoped service declarations. |
| `requires_services` | Node-scoped service requirements used by the scheduler. |
| `raw_config` | Escape hatch for manifest fields not represented by the SDK. |

Keep `pass_env` narrow. See [Security Model](security.md).

## Workflow Options

`@workflow.defn(...)` supports:

| Field | Purpose |
| --- | --- |
| `name` | `graph_id` / workflow name. |
| `type` | Set to `"service"` for long-running jobs; omit for default batch jobs. |
| `stream_mode` | Enables stream-oriented behavior when supported by nodes. |
| `recovery_mode` | Recovery policy such as `local_restart`. |
| `deployment` | Deployment key and metadata pass-through. |
| `schedule` | Periodic or delayed schedule declaration pass-through. |
| `triggers` | Event trigger declarations pass-through. |
| `services` | Job-scoped services provided by the workflow. |
| `required_services` | Required service preflight declarations. |
| `policies` | Restart, reschedule, scheduler, and update policy maps. |
| `backpressure` | Job-level pressure policy. |
| `includes` | Files or directories copied into the generated payload. |
| `excludes` | Package paths to omit. |

The SDK passes these orchestration maps through unchanged so the runtime remains the source of truth for validation and behavior.

## Operational Client Methods

The gRPC client exposes operator surfaces for the Nomad-inspired runtime features:

```python
from mn_sdk import Client

client = Client()

client.reconcile_node("mirror_neuron@<node-host>", reason="manual check", dry_run=True)
client.drain_node("mirror_neuron@<node-host>", reason="reboot", deadline_ms=1_800_000)
client.set_node_maintenance("mirror_neuron@<node-host>", True, reason="maintenance")

client.list_services()
client.resolve_service("ollama", tags=["llm"])
client.check_services([{"name": "ollama", "checks": [{"type": "tcp", "address": "127.0.0.1", "port": 11434}]}])

client.list_deployments()
client.promote_deployment("agent-api")
client.rollback_deployment("agent-api", version="1")

client.list_schedules()
client.dispatch_schedule("schedule-id", payload={"manual": True})
client.emit_trigger_event("file_uploaded", payload={"path": "/datasets/eval.jsonl"})
```

See [Nomad-Inspired Runtime Features](nomad-inspired-runtime.md), [Services and Health Checks](services-and-health-checks.md), [Resources and Devices](resources-and-devices.md), [Deployments](deployments.md), and [Schedules and Events](schedules-and-events.md).

## Packaging Rules

The compiler packages declared includes and local source files into the generated bundle payload. Prefer explicit includes for:

- Python packages
- templates
- data files
- policy files
- helper modules in nested directories

If a worker import depends on local files that are not included, the bundle may validate but fail at runtime. Add explicit includes and rerun quick tests.

## Test Commands

```bash
cd mn-python-sdk
.venv/bin/python -m pytest tests
```

Expected output:

```text
12 passed
```

For checked-in source-mode examples, use the same
`mn_blueprint_support.python_workflow_bundle_cli` command from the owning
blueprint folder and write generated bundles outside the source tree.

## Related Pages

- [Blueprints and Skills](blueprints-and-skills.md)
- [Job Bundle Format](bundle.md)
- [Security Model](security.md)
- [Testing](testing.md)
