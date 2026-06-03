# Blueprints And Skills

Blueprints and skills are the main extension points for MirrorNeuron.

- A **blueprint** packages a runnable workflow bundle.
- A **skill** packages reusable code or instructions used by a blueprint worker.
- The **Python SDK** can compile pure Python workflow definitions into a bundle.

## Create A Minimal Blueprint

A runnable bundle has this shape:

```text
my_bundle/
  manifest.json
  payloads/
```

For a pure routing workflow, `payloads/` can be empty. For executor workflows, put scripts, Python packages, policies, templates, and data under `payloads/`.

Blueprints that need Python packages at runtime should declare them on the executor node instead of adding them to the core image. For `MirrorNeuron.Runner.HostLocal`, add a dependency file under `payloads/` and reference it with `python_environment`:

```json
{
  "runner_module": "MirrorNeuron.Runner.HostLocal",
  "python_environment": {
    "requirements": "worker/requirements.txt",
    "packages": ["opencv-python-headless>=4.10,<5"]
  }
}
```

The runtime creates a cached virtualenv keyed by Python version and dependency contents, then runs `python` or `python3` commands from that environment. Root-level blueprint `requirements.txt` files remain documentation or developer setup files unless an executor explicitly references a dependency file under `payloads/`.

## Wrap Plain Code With The Shared Executor

Any code execution that is part of a blueprint workflow should be represented by
an agent. Plain Python does not need a custom wrapper; use the shared
`mn-agents.data_python_executor@1.0.0` executor through
`mn_blueprint_support`:

```python
from mn_blueprint_support import python_executor_template_node

node = python_executor_template_node(
    "target_discovery",
    "scripts/stage_a.py",
    output_message_type="targets_ready",
)
```

The helper emits a normal manifest node using the shared generic Python executor.
The script stays under `payloads/worker`, but the runtime sees a real agent with
leases, lifecycle events, retry policy, beacons, and UI liveness. Prefer this
shared executor over per-blueprint wrapper scripts or direct background process
launches.

Validate the bundle:

```bash
mn blueprint validate my_bundle
```

Expected output:

```text
Job bundle at 'my_bundle' is valid.
```

Run it:

```bash
mn blueprint run --folder my_bundle
```

Expected output:

```text
Job submitted successfully
```

## Use The Python SDK For A Bundle

The SDK supports a Temporal-like authoring style, but it is a bundle compiler, not a Temporal replay engine.

Example:

```python
from mn_sdk import agent, workflow

TOPIC = workflow.input("topic", default="charging adoption")


class ResearchAgents:
    @agent.defn(name="ingress", type="map", runner="host_local")
    def ingress(self, topic: str):
        return {"message_type": "research_request", "topic": topic}

    @agent.defn(name="reviewer", type="reduce", retries={"max_attempts": 2})
    def reviewer(self, request):
        return {"status": "ok", "topic": request["topic"]}


@workflow.defn(name="research_flow_v1")
class ResearchFlow:
    def __init__(self):
        self.agents = ResearchAgents()

    @workflow.run
    def run(self):
        request = self.agents.ingress(TOPIC)
        return self.agents.reviewer(request)
```

Generate the checked-in Python SDK research pipeline:

```bash
cd mn-blueprints/python_sdk_research_pipeline
python3 -m pip install -e ../../mn-skills/blueprint_support_skill
python -m mn_blueprint_support.python_workflow_bundle_cli \
  --blueprint-dir . \
  --quick-test \
  --output-dir /tmp/mn-python-research
```

Expected output:

```text
bundle generated
```

Validate it:

```bash
mn blueprint validate /tmp/mn-python-research
```

## What The Python Compiler Does

The compiler:

- reads a restricted workflow expression tree
- resolves safe literals, `workflow.input(...)`, and registered constants
- maps agent calls to manifest nodes and edges
- packages declared files and includes under the generated payload
- emits a normal MirrorNeuron bundle

The compiler does not:

- execute arbitrary `eval()` expressions
- provide event-history replay like Temporal
- make Python workflow code itself durable at runtime
- turn non-deterministic Python side effects into replay-safe workflow commands

If a workflow needs long-running durable behavior, express it with MirrorNeuron service, stream, retry, and recovery manifest options.

## Skill Package Shape

A skill package commonly contains:

```text
my_skill/
  README.md
  pyproject.toml
  my_skill/
    __init__.py
    tool.py
  tests/
    test_tool.py
```

Some skills are copied into blueprint payloads. Others are installed as local Python packages. Keep skill APIs narrow and testable.

## Where To Put Code

Use this split:

- Runtime scheduling, leases, events, and recovery belong in `MirrorNeuron`.
- Workflow-specific code belongs in `mn-blueprints`.
- Reusable worker helpers belong in `mn-skills`.
- Python workflow authoring helpers belong in `mn-python-sdk`.
- CLI and API integration belongs in `mn-cli` and `mn-api`.

## Extension Security Checklist

Before publishing or running a blueprint or skill:

- Read every command in `manifest.json`.
- Read every file under `payloads/`.
- Check whether `runner` is `host_local` or OpenShell.
- Check all `pass_env` entries.
- Check network policies and API base URLs.
- Check whether the workflow is a service.
- Confirm retry behavior will not spam external services.
- Run quick tests with fake data and dry-run delivery flags first.

## Verification Commands

Run SDK tests:

```bash
cd mn-python-sdk
python3 -m pytest tests
```

Expected output:

```text
12 passed
```

Run blueprint quick generation:

```bash
python3 mn-system-tests/test_all.py --blueprints
```

Expected output:

```text
All selected test suites passed.
```

## Related Pages

- [Job Bundle Format](bundle.md)
- [Python SDK](SDK.md)
- [Security Model](security.md)
- [Testing](testing.md)
