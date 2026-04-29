# MirrorNeuron Testing Guide

This workspace is intentionally multi-component. Tests should stay with the component they verify, while root orchestration stays in `mn-system-tests/test_all.py` for developer convenience.

## Test Layout

Preferred layout for new tests:

- `tests/unit/`: pure logic, config parsing, command formatting, manifest validation, component-local behavior.
- `tests/integration/`: one component talking to another through a stable interface, such as CLI to gRPC or API to gRPC.
- `tests/regression/`: focused repros for previously fixed bugs.
- `tests/e2e/`: runtime workflows, live API/CLI flows, Docker or service-backed checks.

Current component mapping:

- `MirrorNeuron/tests/unit`: Elixir unit tests.
- `MirrorNeuron/tests/api`: core gRPC/API boundary tests.
- `MirrorNeuron/tests/e2e`: runtime and stream/live execution e2e tests.
- `MirrorNeuron/tests/regression`: script-style regression repros.
- `mn-api/tests`, `mn-cli/tests`, `mn-python-sdk/tests`, `mn-ts-sdk/tests`, `mn-web-ui/src/test`: component unit tests today. Split these into `unit/`, `integration/`, `regression/`, and `e2e/` as each package grows.
- `mn-system-tests/integration` and `mn-system-tests/e2e`: live cross-component tests. These are opt-in because they need running services.
- `mn-blueprints/*/tests` and `mn-skills/*/tests`: blueprint and skill package tests.

## Common Commands

Fast local signal:

```bash
python3 mn-system-tests/test_all.py --fast
```

Component unit tests, including Node and core when dependencies are present:

```bash
python3 mn-system-tests/test_all.py --unit
```

Blueprint quick checks without external APIs:

```bash
python3 mn-system-tests/test_all.py --blueprints
```

Core runtime e2e, including stream/live backpressure:

```bash
python3 mn-system-tests/test_all.py --runtime-e2e
```

Security checks in reporting mode:

```bash
python3 mn-system-tests/test_all.py --security --skip-core --skip-node --skip-blueprints
```

Strict security mode fails on dependency-audit or secret-scan findings:

```bash
python3 mn-system-tests/test_all.py --security --strict-security --skip-core --skip-node --skip-blueprints
```

Live integration/e2e against running services:

```bash
python3 mn-system-tests/test_all.py --integration --live
python3 mn-system-tests/test_all.py --e2e --live
```

Full default non-live suite:

```bash
python3 mn-system-tests/test_all.py
```

## Manual Live E2E

Use isolated ports and namespaces so tests do not collide with a developer instance:

```bash
cd MirrorNeuron
MIRROR_NEURON_GRPC_PORT=55200 \
MIRROR_NEURON_REDIS_NAMESPACE=mirror_neuron_manual_e2e \
mix run --no-halt
```

In another terminal:

```bash
cd mn-api
MIRROR_NEURON_API_PORT=4001 \
MIRROR_NEURON_GRPC_TARGET=localhost:55200 \
mn-api
```

Then run:

```bash
MIRROR_NEURON_GRPC_TARGET=localhost:55200 \
MIRROR_NEURON_API_BASE_URL=http://localhost:4001/api/v1 \
RUN_MN_SYSTEM_TESTS=1 \
python3 -m pytest mn-system-tests/integration mn-system-tests/e2e
```

## Environment Rules

All runtime/config overrides must use `MIRROR_NEURON_`.

Useful test isolation vars:

- `MIRROR_NEURON_GRPC_PORT`: use a non-default port for test core instances.
- `MIRROR_NEURON_GRPC_TARGET`: point CLI/API/SDK tests at the test core.
- `MIRROR_NEURON_API_BASE_URL`: point system e2e tests at a non-default API port.
- `MIRROR_NEURON_REDIS_NAMESPACE`: isolate Redis keys per test run.
- `MIRROR_NEURON_ENV=test`: use test-mode validation where appropriate.
- `MIRROR_NEURON_API_TOKEN`: test API bearer auth.

Live tests are opt-in. If `RUN_MN_SYSTEM_TESTS=1` is not set, `mn-system-tests` marks integration/e2e tests skipped.

## What To Add Next

- Move flat Python tests into `tests/unit/` first, then add `tests/integration/` for API/CLI behavior that exercises the SDK boundary.
- Convert useful `MirrorNeuron/tests/regression/*.script` repros into ExUnit tests where possible.
- Add Web UI visual/layout regression tests when Playwright is introduced.
- Add a real secret scanner such as `gitleaks` or `detect-secrets` once the team chooses a tool.
