# Choose A Blueprint Example

This guide helps you pick the right checked-in blueprint for your first run or test.

Run commands from the monorepo root unless a step says otherwise.

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

Blueprint availability depends on your local blueprint index and checkout.

## 1. General Test Message Flow

Path:

```text
mn-blueprints/general_message_routing_trace
```

Use it when:

- you want the smallest local workflow
- you want to validate routing and manifest shape
- you do not want external APIs

Run:

```bash
mn blueprint run general_message_routing_trace
mn blueprint run general_message_routing_trace
```

Expected output:

```text
Job submitted successfully
```

## 2. Pure Python Basic Workflow

Path:

```text
mn-blueprints/general_python_defined_basic
```

Use it when:

- you want to author a workflow in Python
- you want the SDK to generate a normal bundle
- you want HostLocal, retry, and deterministic input examples

Generate:

```bash
python3 mn-blueprints/general_python_defined_basic/generate_bundle.py \
  --quick-test \
  --output-dir /tmp/mn-python-basic
```

Validate and run:

```bash
mn validate /tmp/mn-python-basic
mn run /tmp/mn-python-basic
```

## 3. Pure Python Advanced Daemon

Path:

```text
mn-blueprints/general_python_defined_advanced_deamon
```

Use it when:

- you want daemon workflow options
- you want stream/backpressure examples
- you want a Python-defined workflow that stays alive until cancelled

Generate:

```bash
python3 mn-blueprints/general_python_defined_advanced_deamon/generate_bundle.py \
  --quick-test \
  --output-dir /tmp/mn-python-advanced-daemon
```

Run:

```bash
mn validate /tmp/mn-python-advanced-daemon
mn run /tmp/mn-python-advanced-daemon
```

Cancel when done:

```bash
mn cancel <job_id>
```

Expected output:

```text
Job cancelled. Status: cancelled
```

## 4. OpenShell Worker Basic

Path:

```text
mn-blueprints/general_openshell_sandbox_worker_pipeline
```

Use it when:

- you want sandboxed shell or Python execution
- you want to test OpenShell setup
- you want to inspect payload staging

Run:

```bash
mn blueprint run general_openshell_sandbox_worker_pipeline
mn blueprint run general_openshell_sandbox_worker_pipeline
```

If the run fails before worker code starts, check:

```bash
openshell status
```

Expected output includes:

```text
Status: Connected
```

## 5. Prime Sweep Scale

Path:

```text
mn-blueprints/general_prime_sweep_scale
```

Use it when:

- you want fan-out/fan-in executor behavior
- you want to exercise pools and backpressure
- you want a local or cluster scale smoke test

Generate a quick bundle:

```bash
python3 mn-blueprints/general_prime_sweep_scale/generate_bundle.py \
  --quick-test \
  --output-dir /tmp/mn-prime
```

Run:

```bash
mn validate /tmp/mn-prime
mn run /tmp/mn-prime
```

## 6. Stream Live Backpressure Daemon

Path:

```text
mn-blueprints/general_stream_backpressure_control_loop
```

Use it when:

- you want a daemon workflow
- you want bounded queue and retry-later behavior
- you want live stream pressure signals

Run:

```bash
mn blueprint run general_stream_backpressure_control_loop
mn blueprint run general_stream_backpressure_control_loop
```

Cancel after observing events:

```bash
mn cancel <job_id>
```

## 7. Science Ecosystem Simulation

Path:

```text
mn-blueprints/science_ecosystem_simulation
```

Use it when:

- you want a larger stateful simulation
- you want to test many messages and actors
- you want a richer cluster workload

Quick generation:

```bash
python3 mn-blueprints/science_ecosystem_simulation/generate_bundle.py \
  --quick-test \
  --output-dir /tmp/mn-ecosystem
```

## 8. Financial Market Realtime Advisor Daemon

Path:

```text
mn-blueprints/financial_market_realtime_advisor_deamon
```

Use it when:

- you want a long-lived market simulation
- you want optional LLM and Slack integration
- you want retry and dry-run delivery behavior

Start in quick-test mode before enabling real external delivery:

```bash
python3 mn-blueprints/financial_market_realtime_advisor_deamon/generate_bundle.py \
  --quick-test \
  --output-dir /tmp/mn-market
```

## Recommended Order

1. `general_message_routing_trace`
2. `general_python_defined_basic`
3. `general_openshell_sandbox_worker_pipeline`
4. `general_prime_sweep_scale`
5. `general_python_defined_advanced_deamon`
6. `general_stream_backpressure_control_loop`
7. `science_ecosystem_simulation`
8. `financial_market_realtime_advisor_deamon`

That path moves from pure local routing to Python authoring, sandbox execution, scale, daemon behavior, streaming, simulation, and external integrations.

## Security Notes

- Review `manifest.json` before running any blueprint.
- Check `pass_env` before passing secrets.
- Use quick-test and dry-run modes before external delivery.
- Cancel daemon jobs when you are done.

## Related Pages

- [Quickstart](quickstart.md)
- [Blueprints and Skills](blueprints-and-skills.md)
- [Job Bundle Format](bundle.md)
- [Security Model](security.md)
