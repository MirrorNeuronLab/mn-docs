# MirrorNeuron Component Guide

This guide keeps the durable project details in `mn-docs` so each folder-level
`README.md` can stay short and task-focused.

Use this page when you need to choose the right repository, install a component,
run local validation, or understand where a detail belongs.

## Documentation Model

Most non-blueprint folder READMEs should answer four questions only:

1. What is this folder?
2. What is the shortest safe command to try it?
3. What should be validated before changing it?
4. Where is the detailed guide?

Long-lived setup, configuration, architecture, security, troubleshooting,
testing, and release notes belong in `mn-docs`.

Blueprint folders in `otterdesk-blueprints` are the exception. Keep those
README files self-contained because users often review, copy, or run a single
blueprint folder without opening the central docs.

## Workspace Map

| Folder | Owns | Start here | Basic validation |
| --- | --- | --- | --- |
| [`MirrorNeuron`](../MirrorNeuron/README.md) | Elixir/OTP runtime, gRPC services, runtime scheduling, Redis state | [`runtime-architecture.md`](runtime-architecture.md) | `mix test` |
| [`mn-deploy`](../mn-deploy/README.md) | Installer, local service control, generated Docker Compose runtime | [`installation.md`](installation.md) | `./install.sh --help` |
| [`mn-cli`](../mn-cli/README.md) | `mn` command-line interface | [`cli.md`](cli.md) | `.venv/bin/python -m pytest -q` |
| [`mn-api`](../mn-api/README.md) | FastAPI REST gateway over the runtime SDK | [`api.md`](api.md) | `.venv/bin/python -m pytest -q` |
| [`mn-python-sdk`](../mn-python-sdk/README.md) | Python gRPC client and workflow bundle helpers | [`SDK.md`](SDK.md) | `.venv/bin/python -m pytest -q` |
| [`mn-web-ui`](../mn-web-ui/README.md) | Browser UI for jobs, graphs, runtime state, and blueprint runs | [`monitor.md`](monitor.md) | `npm run lint && npm test -- --run` |
| [`mn-agents`](../mn-agents/README.md) | Shared agent templates used by blueprints | [`blueprints-and-skills.md`](blueprints-and-skills.md) | `.venv/bin/python tools/validate_agents.py --json` |
| [`mn-skills`](../mn-skills/README.md) | Installable Python skill packages used by blueprint payloads | [`blueprints-and-skills.md`](blueprints-and-skills.md) | Package-specific `.venv/bin/python -m pytest -q` |
| [`mn-system-tests`](../mn-system-tests/README.md) | Cross-repository smoke, integration, e2e, and benchmark tests | [`testing.md`](testing.md) | `.venv/bin/python test_all.py --help` |
| [`Membrane`](../Membrane/README.md) | Rust context engine, Python SDK, context compression tooling | [`runtime-architecture.md`](runtime-architecture.md) | `cargo test` and package pytest suites |
| [`Synapse`](../Synapse/README.md) | Blueprint-composition planner and MCP wrapper | [`architect.md`](architect.md) | `.venv/bin/python -m pytest -q` in each package |
| [`otterdesk-blueprints`](../otterdesk-blueprints/README.md) | OtterDesk-facing blueprint catalog | [`blueprints-and-skills.md`](blueprints-and-skills.md) | `.venv/bin/python -m pytest -q` |
| [`otterdesk-desktop-app`](../otterdesk-desktop-app/README.md) | Electron desktop app that launches and monitors worker blueprints | [`deployments.md`](deployments.md) | `npm run doctor` |

## Quick Local Path

Install or update the local runtime with the deployment repository:

```bash
cd mn-deploy
./install.sh --help
./install.sh
```

Start services after installation:

```bash
mn runtime start
mn node list
```

Run a checked-in blueprint:

```bash
mn blueprint run --folder otterdesk-blueprints/tax_form_ocr_capture_assistant
mn blueprint monitor --follow
```

Most run artifacts are written under:

```text
~/.mn/runs/<run_id>/
```

## Component Details

### MirrorNeuron Core

MirrorNeuron Core is the Elixir/OTP runtime. It schedules workflow agents,
routes messages, records events, persists runtime state through Redis, exposes
gRPC services, and supports local or clustered execution.

Use this folder when changing runtime behavior, scheduling, persistence,
clustering, resource accounting, gRPC services, or sandbox execution.

Common local commands:

```bash
cd MirrorNeuron
mix deps.get
mix format
mix test
```

Redis-backed tests need Redis:

```bash
docker run -d --name mirror-neuron-redis -p 6379:6379 redis:7
mix test
```

Read next:

- [Runtime Architecture](runtime-architecture.md)
- [Cluster Architecture](cluster_architecture.md)
- [Reliability Guide](reliability.md)
- [Security Model](security.md)

### Deployment Scripts

`mn-deploy` installs and controls a local MirrorNeuron system. The unified
installer is `install.sh`; its default mode installs from GitHub repositories.
It can install the core, Python SDK, CLI, API, Web UI, Redis, OpenShell, and the
Membrane context engine depending on the selected options.

Useful commands:

```bash
cd mn-deploy
./install.sh --help
./server.sh status
./server.sh start
./server.sh stop
```

Default runtime state lives in `~/.mn`. Generated service settings, ports,
tokens, and shared run paths are stored in `~/.mn/docker-compose.env`.

Read next:

- [Installation](installation.md)
- [Docker and OpenShell for Blueprints](docker_and_openshell_for_blueprints.md)
- [Security Model](security.md)

### CLI

`mn-cli` provides the `mn` command. It submits blueprints, validates bundles,
lists jobs, inspects runtime state, exports artifacts, and starts local services
installed by `mn-deploy`.

Developer setup:

```bash
cd mn-cli
python3.11 -m venv .venv
. .venv/bin/activate
.venv/bin/python -m pip install -e .
.venv/bin/python -m pytest -q
```

Common commands:

```bash
mn --version
mn node list
mn blueprint run --folder otterdesk-blueprints/tax_form_ocr_capture_assistant
mn job status <job_id>
mn blueprint monitor --follow
```

Read next:

- [CLI Reference](cli.md)
- [Environment Variables](env_variables.md)
- [Monitor Guide](monitor.md)

### API

`mn-api` is a FastAPI service that exposes runtime operations over REST and uses
the Python SDK gRPC client to talk to the core.

Developer setup:

```bash
cd mn-api
python3.11 -m venv .venv
. .venv/bin/activate
.venv/bin/python -m pip install -e ".[test]"
.venv/bin/python -m pytest -q
mn-api
```

The default local server is:

```text
http://localhost:54001
```

Use `MN_ENV=prod` and `MN_API_TOKEN` for protected deployments.

Read next:

- [API Reference](api.md)
- [Environment Variables](env_variables.md)
- [Security Model](security.md)

### Python SDK

`mn-python-sdk` provides the gRPC client, workflow decorators, bundle generation
helpers, input validation helpers, and runtime configuration utilities used by
the CLI and API.

Developer setup:

```bash
cd mn-python-sdk
python3.11 -m venv .venv
. .venv/bin/activate
.venv/bin/python -m pip install -e .
.venv/bin/python -m pytest -q
```

Minimal client example:

```python
from mn_sdk import Client

client = Client(target="localhost:55051")
print(client.list_jobs(limit=5))
```

Read next:

- [Python SDK](SDK.md)
- [Job Bundle Format](bundle.md)
- [Environment Variables](env_variables.md)

### Web UI

`mn-web-ui` is a React/Vite browser interface for runtime dashboards, job
history, graph inspection, events, dead letters, and raw manifest submission.

Developer setup:

```bash
cd mn-web-ui
npm install
npm run dev
```

Build and test:

```bash
npm run lint
npm test -- --run
npm run build
```

The local development server defaults to:

```text
http://localhost:55173
```

Read next:

- [Monitor Guide](monitor.md)
- [API Reference](api.md)

### Blueprint Library

The default catalog is cached under `~/.mn/blueprints` by `mn blueprint install`,
`mn blueprint update`, or the first catalog run. The checked-in local catalog in
this workspace is `otterdesk-blueprints`. Each blueprint folder contains a
manifest, default config, payloads, a quick README, user-facing `SPEC.md`, and
tests or fixtures when available.

Run from the catalog:

```bash
mn blueprint list
mn blueprint run portfolio_risk_review_assistant
mn blueprint monitor --follow
```

Run from a checked-in local folder:

```bash
mn blueprint run --folder otterdesk-blueprints/portfolio_risk_review_assistant
```

Read next:

- [Blueprints and Skills](blueprints-and-skills.md)
- [Examples](examples.md)
- [Job Bundle Format](bundle.md)
- [Services and Health Checks](services-and-health-checks.md)

### Agent Templates

`mn-agents` keeps reusable, versioned agent templates. Blueprints actualize
these templates with `uses`, `with`, and `config` rather than copying node
boilerplate into every manifest.

Validate the catalog:

```bash
cd mn-agents
.venv/bin/python -m pip install -r requirements-test.txt
.venv/bin/python tools/validate_agents.py --json
.venv/bin/python -m pytest -q
```

Simulate one fixture:

```bash
.venv/bin/python tools/simulate_agent.py data_python_executor/fixtures/minimal.instance.json
```

Read next:

- [Blueprints and Skills](blueprints-and-skills.md)
- [`mn-agents/SPEC.md`](../mn-agents/SPEC.md)

### Skill Packages

`mn-skills` contains installable Python helper packages for blueprint payloads.
Skills should stay generic; blueprint-specific prompts, policy, scenarios, and
customer assumptions belong in the owning blueprint.

Install one package from source:

```bash
cd mn-skills
.venv/bin/python -m pip install -e generate_fake_data_skill
```

Run package tests from the package folder when tests exist:

```bash
cd generate_fake_data_skill
.venv/bin/python -m pytest -q
```

Read next:

- [Blueprints and Skills](blueprints-and-skills.md)
- [Skill Catalog](skill-catalog.md)
- [Documentation Style](documentation-style.md)

### System Tests

`mn-system-tests` coordinates checks across the core, SDK, CLI, API, Web UI,
installers, the current `otterdesk-blueprints` catalog, live flows, and
deterministic benchmark fixtures.

Set up dependencies:

```bash
cd mn-system-tests
.venv/bin/python -m pip install -r requirements.txt
```

Inspect the test runner:

```bash
.venv/bin/python test_all.py --help
```

Fast injected contract tests:

```bash
.venv/bin/python test_all.py --contracts
```

Offline development gate:

```bash
.venv/bin/python test_all.py --fast --skip-core --skip-node
```

Key interface performance benchmark:

```bash
.venv/bin/python test_all.py --performance
```

Runner-driven suites write summaries under `mn-system-tests/results/`,
including `system-tests.txt` and `performance.txt`.

Live integration and e2e tests are intentionally gated. Set
`RUN_MN_SYSTEM_TESTS=1` and use the `--live` runner options only when local
services are available.

Read next:

- [Testing](testing.md)
- [`mn-system-tests/REGRESSION_MATRIX.md`](../mn-system-tests/REGRESSION_MATRIX.md)
- [`mn-system-tests/benchmarks/README.md`](../mn-system-tests/benchmarks/README.md)

### Membrane

`Membrane` is the context-memory side of the platform. It includes a Rust gRPC
context engine, a Python SDK shell, deterministic context compression tooling,
and benchmark packages.

Core engine validation:

```bash
cd Membrane/mn-context-engine
cargo test
```

Python SDK validation:

```bash
cd Membrane/mn-context-engine-python-sdk
.venv/bin/python -m pip install -e ".[dev]"
.venv/bin/python -m pytest -q
```

Optimizer validation:

```bash
cd Membrane/mn-context-auto-optimizer
.venv/bin/python -m pip install -e ".[dev]"
.venv/bin/python -m pytest -q
```

Read next:

- [Runtime Architecture](runtime-architecture.md)
- [`Membrane/SPEC.md`](../Membrane/SPEC.md)

### Synapse

`Synapse` is the blueprint-composition layer. It studies a problem brief,
selects reusable `mn-agents` and `mn-skills`, compares against existing
blueprints, and produces an inspectable composition plan.

Try the orchestrator:

```bash
cd Synapse/mn-orchastrator
PYTHONPATH=src .venv/bin/python -m mn_orchastrator.cli compose \
  "Build a support triage workflow that ranks escalation risk and writes a report." \
  --workspace-root ../..
```

Read next:

- [`Synapse/SPEC.md`](../Synapse/SPEC.md)
- [`Synapse/mn-orchastrator/README.md`](../Synapse/mn-orchastrator/README.md)
- [`Synapse/mn-orchastrator-mcp/README.md`](../Synapse/mn-orchastrator-mcp/README.md)

### OtterDesk

`otterdesk-desktop-app` is the Electron desktop app. It launches and monitors
worker blueprints, stores app state, and exposes desktop workflows for local
operators.

Developer setup:

```bash
cd otterdesk-desktop-app
npm install
npm run doctor
npm run dev
```

`otterdesk-blueprints` contains the OtterDesk-facing worker blueprint catalog.
Use its root tests before changing catalog metadata or manifests:

```bash
cd otterdesk-blueprints
.venv/bin/python -m pytest -q
```

Read next:

- [Blueprints and Skills](blueprints-and-skills.md)
- [Deployments](deployments.md)

## Cross-Cutting Configuration

Common environment variables include:

| Variable | Used by | Purpose |
| --- | --- | --- |
| `MN_GRPC_TARGET` | CLI, API, SDK | Runtime gRPC target. |
| `MN_API_PORT` | API, deploy scripts | REST API port, defaulting to `54001` in local deployments. |
| `MN_RUNS_ROOT` | Core, API, CLI, blueprints | Shared run-artifact store. |
| `MN_API_TOKEN` | API, Web UI | Bearer token for protected REST deployments. |
| `MN_WEB_API_BASE_URL` | Web UI | Browser REST API base URL. |

See [Environment Variables](env_variables.md) for the detailed reference.

## Validation Notes

- Prefer the smallest component-level validation before broader system tests.
- Use `mn-system-tests/test_all.py` when a change spans repositories.
- Run live tests only when Redis, the core, API, and any required sandbox or
  provider services are available.
- When a command in a README changes, update this guide or the linked reference
  page in the same change.

## Open TODOs

- TODO: Add a top-level license file to `mn-system-tests` before distributing
  benchmark fixtures or reports outside the project.
- TODO: Add stable screenshots or short recordings for the Web UI and runtime
  monitor after those views settle.
