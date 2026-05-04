# Python SDK Reference

The MirrorNeuron Python SDK provides:

- a gRPC client for the core runtime
- workflow and agent decorators for pure Python bundle authoring
- a compiler that turns restricted Python workflow definitions into normal MirrorNeuron bundles

## Install For Local Development

From the monorepo root:

```bash
python3 -m pip install -e mn-python-sdk
```

Expected output:

```text
Successfully installed mn-python-sdk
```

The `mn-system-tests/requirements.txt` file installs the SDK and CLI together for test runs.

## Client Usage

```python
from mn_sdk import Client

client = Client(target="localhost:50051")

manifest_json = '{"manifest_version": "1.0", "graph_id": "simple", "nodes": [], "edges": []}'
job_id = client.submit_job(manifest_json, payloads={})

print(job_id)
print(client.get_job(job_id))
```

Important environment variables:

| Variable | Default | Description |
| --- | --- | --- |
| `MN_GRPC_TARGET` | `localhost:50051` | Runtime gRPC endpoint. |
| `MN_GRPC_TIMEOUT_SECONDS` | `10` | Per-RPC timeout. |
| `MN_GRPC_AUTH_TOKEN` | unset | Optional bearer token metadata. |
| `MN_SDK_LOG_PATH` | `~/.mn/logs/sdk.log` | SDK log path. |

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
    daemon=False,
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

Generate a checked-in example:

```bash
python3 mn-blueprints/general_python_defined_basic/generate_bundle.py \
  --quick-test \
  --output-dir /tmp/mn-python-basic
```

Expected output:

```text
bundle generated
```

Validate:

```bash
mn validate /tmp/mn-python-basic
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

If you need durable long-running behavior, use MirrorNeuron workflow features such as daemon mode, stream agents, recovery policies, retries, backpressure, and persisted agent snapshots.

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
| `raw_config` | Escape hatch for manifest fields not yet modeled by the SDK. |

Keep `pass_env` narrow. See [Security Model](security.md).

## Workflow Options

`@workflow.defn(...)` supports:

| Field | Purpose |
| --- | --- |
| `name` | `graph_id` / workflow name. |
| `daemon` | Keeps the job alive until cancelled. |
| `stream_mode` | Enables stream-oriented behavior when supported by nodes. |
| `recovery_mode` | Recovery policy such as `local_restart`. |
| `backpressure` | Job-level pressure policy. |
| `includes` | Files or directories copied into the generated payload. |
| `excludes` | Package paths to omit. |

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
python3 -m pytest tests
```

Expected output:

```text
12 passed
```

Generate both Python-defined blueprints:

```bash
python3 mn-system-tests/test_all.py --blueprints
```

Expected output:

```text
general_python_defined_basic quick bundle
general_python_defined_advanced_deamon quick bundle
All selected test suites passed.
```

## Related Pages

- [Blueprints and Skills](blueprints-and-skills.md)
- [Job Bundle Format](bundle.md)
- [Security Model](security.md)
- [Testing](testing.md)
