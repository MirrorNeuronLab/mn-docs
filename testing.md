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
- `mn-api/tests`, `mn-cli/tests`, `mn-python-sdk/tests`, `mn-web-ui/src/test`: component unit tests today. Split these into `unit/`, `integration/`, `regression/`, and `e2e/` as each package grows.
- `mn-system-tests/integration` and `mn-system-tests/e2e`: live cross-component tests. These are opt-in because they need running services.
- `mn-blueprints/*/tests` and `mn-skills/*/tests`: blueprint and skill package tests.

## Common Commands

Fast local signal:

```bash
.venv/bin/python mn-system-tests/test_all.py --fast
```

Component unit tests, including Node and core when dependencies are present:

```bash
.venv/bin/python mn-system-tests/test_all.py --unit
```

Blueprint quick checks without external APIs:

```bash
.venv/bin/python mn-system-tests/test_all.py --blueprints
```

Core runtime e2e, including stream/live backpressure:

```bash
.venv/bin/python mn-system-tests/test_all.py --runtime-e2e
```

Security checks in reporting mode:

```bash
.venv/bin/python mn-system-tests/test_all.py --security --skip-core --skip-node --skip-blueprints
```

Strict security mode fails on dependency-audit or secret-scan findings:

```bash
.venv/bin/python mn-system-tests/test_all.py --security --strict-security --skip-core --skip-node --skip-blueprints
```

Live integration/e2e against running services:

```bash
.venv/bin/python mn-system-tests/test_all.py --integration --live
.venv/bin/python mn-system-tests/test_all.py --e2e --live
```

Full default non-live suite:

```bash
.venv/bin/python mn-system-tests/test_all.py
```

## Manual Live E2E

Use isolated ports and namespaces so tests do not collide with a developer instance:

```bash
cd MirrorNeuron
MN_GRPC_PORT=55200 \
MN_REDIS_NAMESPACE=mirror_neuron_manual_e2e \
mix run --no-halt
```

In another terminal:

```bash
cd mn-api
MN_API_PORT=4001 \
MN_GRPC_TARGET=localhost:55200 \
mn-api
```

Then run:

```bash
MN_GRPC_TARGET=localhost:55200 \
MN_API_BASE_URL=http://localhost:4001/api/v1 \
RUN_MN_SYSTEM_TESTS=1 \
.venv/bin/python -m pytest mn-system-tests/integration mn-system-tests/e2e
```

## Redis HA Tests

MirrorNeuron includes Redis Sentinel smoke tests for the runtime's durable state store.

Local Docker test:

```bash
cd MirrorNeuron
bash scripts/test_redis_sentinel_ha.sh
```

Two-box Docker test:

```bash
cd MirrorNeuron

bash scripts/test_redis_sentinel_two_box_ha.sh \
  --remote-host 192.168.4.173 \
  --local-ip 192.168.4.25 \
  --remote-ip 192.168.4.173
```

Expected success markers:

```text
two_box_initial_write_ok=...
two_box_post_failover_write_read_ok
```

The two-box test starts Redis and Sentinel on both machines, writes MirrorNeuron state, kills the initial Redis primary, waits for Sentinel failover, then writes and reads again through the promoted replica. If the remote box cannot route to the local Redis test port, the script automatically uses the remote Redis as the initial primary and tests failover back to the local replica.

Run the same path through the workspace test runner:

```bash
.venv/bin/python mn-system-tests/test_all.py --redis-ha \
  --redis-ha-remote-host 192.168.4.173 \
  --redis-ha-local-ip 192.168.4.25 \
  --redis-ha-remote-ip 192.168.4.173
```

Expected output:

```text
All selected test suites passed.
```

## Nomad-Inspired Runtime Feature Tests

The Nomad-inspired runtime features should be covered at three levels:

- component unit tests in `MirrorNeuron`, `mn-cli`, and `mn-python-sdk`
- live cross-component tests in `mn-system-tests`
- two-box joined-cluster smoke tests when placement, drain, recovery, or schedule uniqueness is involved

Core areas to keep covered:

| Feature | Test focus |
| --- | --- |
| Reconciliation | Node-loss recovery, live coordinator agent movement, whole-job recovery after lease loss, pause for unsafe work. |
| Job types | `service`, `batch`, `system`, and `sysbatch` lifecycle behavior. |
| Restart/reschedule policy | Sliding windows, delay functions, `mode: fail`, `mode: delay`, disabled and unlimited reschedule. |
| Drain and maintenance | Eligibility, dry run, service migration, batch waiting, system ignore, cancellation, undrain. |
| Services and checks | Manifest validation, service preflight, registry filtering, HTTP/TCP/script/gRPC checks. |
| Resources and devices | CUDA vs Metal, GPU memory, device ID exclusivity, explicit port conflicts, host volume placement. |
| Deployments | Rolling, canary isolation, promotion, rollback, service discovery roles. |
| Schedules and events | Cron parsing, timezone, delayed runs, overlap prevention, missed policies, event filters, idempotent dispatch. |

Two-box cluster checks should use a shared Redis namespace and sync the remote workspace through Git rather than editing files directly on the remote machine.

Typical joined-cluster verification:

```bash
mn runtime start
mn runtime start --worker-node
mn node join <worker-ip> --token <worker-token>
mn node list
mn resource list
```

Then run targeted system tests for:

- one due schedule dispatching exactly once across both boxes
- `system` jobs expanding across both eligible nodes
- service jobs moving from a drained node to the other node
- resource placement avoiding a node without the requested CUDA/Metal/device capability
- required service preflight blocking before agents launch

## Environment Rules

All runtime/config overrides must use `MN_`.

Useful test isolation vars:

- `MN_GRPC_PORT`: use a non-default port for test core instances.
- `MN_GRPC_TARGET`: point CLI/API/SDK tests at the test core.
- `MN_API_BASE_URL`: point system e2e tests at a non-default API port.
- `MN_REDIS_NAMESPACE`: isolate Redis keys per test run.
- `MN_ENV=test`: use test-mode validation where appropriate.
- `MN_API_TOKEN`: test API bearer auth.

Live tests are opt-in. If `RUN_MN_SYSTEM_TESTS=1` is not set, `mn-system-tests` marks integration/e2e tests skipped.

## What To Add Next

- Move flat Python tests into `tests/unit/` first, then add `tests/integration/` for API/CLI behavior that exercises the SDK boundary.
- Convert useful `MirrorNeuron/tests/regression/*.script` repros into ExUnit tests where possible.
- Add Web UI visual/layout regression tests when Playwright is introduced.
- Add a real secret scanner such as `gitleaks` or `detect-secrets` once the team chooses a tool.
