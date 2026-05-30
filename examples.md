# Choose A Blueprint Example

This guide helps you choose a checked-in blueprint for a first run, smoke test,
or runtime demonstration.

Run commands from the workspace root unless a step says otherwise.

## List Available Blueprints

```bash
mn blueprint list
```

Expected output includes:

```text
ID
Name
Job Name
```

Blueprint availability depends on your local blueprint index and checkout. The
catalog source of truth is [`mn-blueprints/index.json`](../mn-blueprints/index.json).

## Recommended Order

| Order | Blueprint | Use it when |
| --- | --- | --- |
| 1 | `message_routing_trace` | You want the smallest local routing workflow. |
| 2 | `python_sdk_research_pipeline` | You want to review a Python-defined batch workflow. |
| 3 | `python_sdk_research_service` | You want a long-running Python service pattern. |
| 4 | `openshell_sandbox_worker_pipeline` | You want sandboxed worker execution and artifact handoff. |
| 5 | `parallel_worker_benchmark` | You want fan-out/fan-in scheduler pressure. |
| 6 | `stream_backpressure_simulation` | You want bounded stream and backpressure behavior. |
| 7 | `ecosystem_simulation` | You want a larger stateful simulation. |
| 8 | `liquidity_risk_monitor` | You want a finance workflow with optional external integrations. |

## 1. Message Routing Trace

Path:

```text
mn-blueprints/message_routing_trace
```

Use it when:

- you want the smallest local workflow;
- you want to validate routing and manifest shape;
- you do not want external APIs.

Run:

```bash
mn blueprint run message_routing_trace
```

Expected output:

```text
Job submitted successfully
```

## 2. Python SDK Research Pipeline

Path:

```text
mn-blueprints/python_sdk_research_pipeline
```

Use it when:

- you want to author workflows in Python;
- you want the SDK compiler to generate a normal bundle;
- you want a deterministic research pipeline example.

Generate a quick deterministic bundle with the shared support generator:

```bash
cd mn-blueprints/python_sdk_research_pipeline
python3 -m pip install -e ../../mn-skills/blueprint_support_skill
python -m mn_blueprint_support.python_workflow_bundle_cli \
  --blueprint-dir . \
  --quick-test \
  --output-dir /tmp/mirror-neuron-bundles
```

## 3. Python SDK Research Service

Path:

```text
mn-blueprints/python_sdk_research_service
```

Use it when:

- you want a service-style Python workflow;
- you want repeated stateful turns;
- you want a long-running workflow that can be cancelled.

Run:

```bash
mn blueprint run python_sdk_research_service
```

Cancel when done:

```bash
mn job cancel <job_id>
```

## 4. OpenShell Sandbox Worker Pipeline

Path:

```text
mn-blueprints/openshell_sandbox_worker_pipeline
```

Use it when:

- you want sandboxed shell or Python execution;
- you want to test OpenShell setup;
- you want to inspect payload staging.

Run:

```bash
mn blueprint run openshell_sandbox_worker_pipeline
```

If the run fails before worker code starts, check OpenShell:

```bash
openshell status
```

## 5. Parallel Worker Benchmark

Path:

```text
mn-blueprints/parallel_worker_benchmark
```

Use it when:

- you want fan-out/fan-in executor behavior;
- you want to exercise pools and backpressure;
- you want a local or cluster scale smoke test.

Run from the catalog:

```bash
mn blueprint run parallel_worker_benchmark
```

Run from the local folder:

```bash
cd mn-blueprints/parallel_worker_benchmark
mn blueprint run --folder .
```

## 6. Stream Backpressure Simulation

Path:

```text
mn-blueprints/stream_backpressure_simulation
```

Use it when:

- you want a stream workflow;
- you want bounded queue behavior;
- you want retry-later and pressure signals.

Run:

```bash
mn blueprint run stream_backpressure_simulation
```

## 7. Ecosystem Simulation

Path:

```text
mn-blueprints/ecosystem_simulation
```

Use it when:

- you want a larger stateful simulation;
- you want to test many messages and actors;
- you want a richer cluster workload.

Run:

```bash
mn blueprint run ecosystem_simulation
```

## 8. Liquidity Risk Monitor

Path:

```text
mn-blueprints/liquidity_risk_monitor
```

Use it when:

- you want a market-signal workflow;
- you want optional LLM or Slack integration;
- you want dry-run delivery before live adapters.

Run in local/mock configuration first:

```bash
mn blueprint run liquidity_risk_monitor
```

## Security Notes

- Review `manifest.json` before running any blueprint.
- Check `pass_env` before passing secrets.
- Use mock, quick-test, and dry-run modes before external delivery.
- Cancel service jobs when you are done.

## Related Pages

- [Quickstart](quickstart.md)
- [Blueprints and Skills](blueprints-and-skills.md)
- [Job Bundle Format](bundle.md)
- [Security Model](security.md)
