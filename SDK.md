# Python SDK Reference

The MirrorNeuron Python SDK provides:

- an authenticated runtime client for connected applications and a direct Core
  gRPC client for integrations that own those credentials
- workflow and agent decorators for pure Python bundle authoring
- a compiler that turns restricted Python workflow definitions into normal MirrorNeuron bundles

For canonical split-document packages, use `mn_sdk.blueprints.open_blueprint`,
`resolve_config`, and `compile_blueprint`; see [Blueprint Standard](blueprint-standard.md).
The decorator/compiler sections below describe the lower-level Python workflow
interface, not the authored package manifest. A compiled descriptor still needs
submission preparation before execution.

## Install For Local Development

From the workspace root, create or activate a Python 3.12+ virtual environment:

```bash
python3.12 -m venv .venv
.venv/bin/python -m pip install -e mn-python-sdk/packages/common -e 'mn-python-sdk[client,dev]'
```

Expected output:

```text
Successfully installed mirrorneuron-python-sdk
```

For cross-component tests, use the [workspace test runner](testing.md#common-commands).

## Optional Components

Blueprint authors select runtime capabilities in `dependencies.json`:

```json
{
  "$schema": "https://mirrorneuron.io/schemas/blueprint/v1/dependencies.schema.json",
  "packages": [
    {
      "type": "pip",
      "source": "gar",
      "name": "mn-python-sdk-mcp",
      "version": ">=1.3,<2.0"
    },
    {
      "type": "pip",
      "source": "gar",
      "name": "mn-python-sdk-rag",
      "version": ">=1.3.58.dev0,<2"
    }
  ]
}
```

The base SDK depends on the common component. Install additional components
with the matching SDK extras or declare them for blueprint workers. The RAG distribution includes
DuckDB and supports injected parsers, stores and embedders. Each component
is a separate distribution built and tested from `mn-python-sdk/packages/`.
Email, browsing, and task-oriented research remain skills.

Submission preparation installs the declared package closure into the Python
worker environment. Editable source mode stages matching projects; Git installs
pin sibling subdirectories to the SDK's exact installed commit. Binary preparation resolves declared version constraints. SDK component distributions
share the SDK release version; the former independent `0.1.x` restriction does
not describe the current contract. Source development validates distribution
identity and uses local source metadata. See [Dependency versions](blueprint-standard.md#dependency-versions).

Prepared workers use the per-blueprint registry:

```python
from mn_sdk.components import ComponentRegistry

registry = ComponentRegistry.from_environment()
call_tool = registry.service("mcp", "call_tool")
```

`ComponentRegistry.from_manifest(manifest)` serves standalone callers. Providers
register through the `mn_sdk.components` Python entry-point group, or through
`registry.register(name, factory)` for explicitly enabled custom services.
Lookup is lazy and never installs packages. An installed but undeclared provider
is unavailable to that registry. The native response-service factory separately
prepares its host dependencies, including RAG/MCP only when its configuration
needs them. Failed installation is retryable and fails before engine creation.

The source and wheel contracts are exercised by the SDK's component tests and
`scripts/verify_component_installs.py`. Package-index and release publication are
separate operator actions; this migration does not publish a release.

## External knowledge RAG storage

The RAG backend is `duckdb` with exact cosine search. Complete parsed external
knowledge lives in immutable Markdown revisions selected by a
`mn.rag_corpus.v1` filesystem manifest. DuckDB stores vectors, references, UTF-8
byte spans, hashes and small metadata, with no document or chunk bodies.
Retrieval verifies the active manifest and Markdown hashes before loading spans.

For jobs, canonical Markdown lives under
`MN_JOB_DATA_DIR/knowledge/canonical/<scope-id>/` and the index is
`MN_JOB_DATA_DIR/databases/rag/knowledge.duckdb`. Standalone corpora live under
`MN_HOME/rag/<namespace>/<blueprint_id>/knowledge/`, beside the separately named
`<blueprint_id>.duckdb`. Membrane runtime memory remains separate.

The SDK injects the existing document-reading and OCR skills; unsupported,
failed and explicitly incomplete extraction is visible. OCR is lazy. Index
deletion preserves canonical knowledge; reindexing reads Markdown without
reparsing originals. `mn.rag_export.v2` bundles carry Markdown and provenance;
restore rebuilds the destination index. Database-only exports are rejected.
Milvus dependencies and migration commands have been removed. Activate matching
packages and worker environments after stopping active jobs and draining responses.
The detailed implementation contract and tests live in the RAG component README.

## Client Usage

After connecting the surface with `mn node add`, use the same private
`$MN_HOME/client.json` profile from Python. Install `mirrorneuron-python-sdk[client]`
and run this example with `MN_HOME` set to that surface's installation home:

```python
from mn_sdk.runtime_resources import RuntimeResources

runtime = RuntimeResources()
print(runtime.items("/jobs"))
print(runtime.items("/runs"))
```

These reads go over Core's native gRPC gateway. Runtime preparation,
operations, and execution continue on the owning runtime.

For direct Core integrations, `Client` uses the configured Core target and
gRPC user credential. Set the target and credential using the variables below.
Replace `<job-id>` with an ID returned by the first call:

```python
import json

from mn_sdk import Client

with Client() as client:
    print(json.loads(client.list_jobs(page_size=5)))
    print(json.loads(client.list_runs("<job-id>", page_size=5)))
```

Important environment variables:

| Variable                  | Default                 | Description                                           |
| ------------------------- | ----------------------- | ----------------------------------------------------- |
| `MN_GRPC_TARGET`          | `localhost:55051`       | Runtime gRPC endpoint for the local deployed runtime. |
| `MN_GRPC_TIMEOUT_SECONDS` | `10`                    | Per-RPC timeout.                                      |
| `MN_GRPC_AUTH_TOKEN`      | unset                   | Optional bearer token metadata.                       |
| `MN_SDK_LOG_PATH`         | `$MN_HOME/logs/sdk.log` | SDK log path.                                         |

## Python-Defined Workflows

Use decorators to author workflows in Python:

```python
from mn_sdk import agent, workflow

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
        request = self.agents.ingress(
            workflow.input("topic", default="electric vehicle charging adoption")
        )
        return self.agents.reviewer(request)
```

Save the example as `research_flow.py` in a dedicated source directory and
append this build entry point:

```python
if __name__ == "__main__":
    import sys

    print(workflow.to_bundle(MarketingResearchFlow, sys.argv[1]))
```

From that directory with the SDK environment active, compile into a fresh
directory outside the source tree and validate with an attached local runtime:

```bash
bundle_root="$(mktemp -d)"
python research_flow.py "$bundle_root/research"
mn blueprint validate "$bundle_root/research"
```

The compiler prints the generated directory. Validation should exit zero.
Remove the generated directory when you finish inspecting it.

## Compiler Model

The Python SDK compiler is a bundle compiler.

It does:

- parse the decorated workflow class
- map agent method calls to graph nodes
- map call order and return flow to graph edges
- resolve literals, safe module constants, and `workflow.input(...)`
- package declared includes and payload files
- emit a canonical source package with the referenced role documents and payloads

It does not:

- execute arbitrary workflow expressions during compilation
- use `eval()` for non-literal arguments
- run Python workflow code as a durable orchestrator at job runtime
- provide Temporal-style event-history replay
- provide deterministic clock, random, or command APIs

If you need durable long-running behavior, set the workflow type to `service` and use MirrorNeuron workflow features such as stream agents, recovery policies, retries, backpressure, and persisted agent snapshots.

## Agent Options

`@agent.defn(...)` supports these commonly used fields:

| Field               | Purpose                                                                       |
| ------------------- | ----------------------------------------------------------------------------- |
| `name`              | Node id in the generated bundle.                                              |
| `type`              | Behavioral template such as `map`, `reduce`, `stream`, or `batch`.            |
| `runner`            | Runner choice such as `host_local` or OpenShell-backed execution.             |
| `retries`           | Retry policy.                                                                 |
| `pool`              | Executor pool name.                                                           |
| `pool_slots`        | Number of slots requested from the pool.                                      |
| `backpressure`      | Node-level queue and pressure policy.                                         |
| `env`               | Explicit worker environment values.                                           |
| `pass_env`          | Environment variables copied from the host into the worker.                   |
| `uploads`           | Payload files to stage for execution.                                         |
| `policy`            | Runner policy file, usually OpenShell network policy.                         |
| `timeout_seconds`   | Worker command timeout.                                                       |
| `resources`         | CPU, memory, disk, GPU/device, port, volume, and runtime-driver requirements. |
| `services`          | Agent-scoped service declarations.                                            |
| `requires_services` | Node-scoped service requirements used by the scheduler.                       |
| `raw_config`        | Escape hatch for manifest fields not represented by the SDK.                  |

Keep `pass_env` narrow. See [Security Model](security.md).

## Workflow Options

`@workflow.defn(...)` supports:

| Field               | Purpose                                                                |
| ------------------- | ---------------------------------------------------------------------- |
| `name`              | `graph_id` / workflow name.                                            |
| `type`              | Set to `"service"` for long-running jobs; omit for default batch jobs. |
| `stream_mode`       | Enables stream-oriented behavior when supported by nodes.              |
| `recovery_mode`     | Recovery policy such as `local_restart`.                               |
| `deployment`        | Deployment key and metadata pass-through.                              |
| `schedule`          | Periodic or delayed schedule declaration pass-through.                 |
| `triggers`          | Event trigger declarations pass-through.                               |
| `services`          | Job-scoped services provided by the workflow.                          |
| `required_services` | Required service preflight declarations.                               |
| `update_policy`     | Internal deployment update policy, when applicable.                    |
| `backpressure`      | Job-level pressure policy.                                             |
| `requirements`      | Job requirements passed through to the manifest.                       |
| `input_validation`  | Input validation declarations.                                         |
| `parameterized`     | Scheduled or triggered input and metadata declarations.                |

Set `includes` and `excludes` when calling `workflow.to_bundle`. The
runtime validates the generated orchestration policies.

## Operational Client Methods

With a configured direct Core credential, inspect schedules and services:

```python
from mn_sdk import Client

with Client() as client:
    print(client.list_schedules())
    print(client.list_services())
```

The direct client also implements node reconciliation, maintenance, and drain.
See [Cluster](cluster.md#node-operations), [Services and Health Checks](services-and-health-checks.md),
and [Schedules and Events](schedules-and-events.md) for the operational boundaries.

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
.venv/bin/python -m pytest mn-python-sdk/tests
```

Run from the workspace root using the development environment above. The
command exits zero when the selected tests pass.

For checked-in source-mode examples, use the same
`mn_sdk.blueprint_support.python_workflow_bundle_cli` command from the owning
blueprint folder and write generated bundles outside the source tree.

## Related Pages

- [Blueprints and Skills](blueprints-and-skills.md)
- [Job Bundle Format](bundle.md)
- [Security Model](security.md)
- [Testing](testing.md)
