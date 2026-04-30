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

Validate the bundle:

```bash
mn validate my_bundle
```

Expected output:

```text
Job bundle at 'my_bundle' is valid.
```

Run it:

```bash
mn run my_bundle
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

Generate a checked-in example bundle:

```bash
python3 mn-blueprints/general_python_defined_basic/generate_bundle.py \
  --quick-test \
  --output-dir /tmp/mn-python-basic
```

Expected output:

```text
bundle generated
```

Validate it:

```bash
mn validate /tmp/mn-python-basic
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

If a workflow needs long-running durable behavior, express it with MirrorNeuron daemon, stream, retry, and recovery manifest options.

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
- Check whether the workflow is a daemon.
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
