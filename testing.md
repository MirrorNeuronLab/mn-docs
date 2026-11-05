# MirrorNeuron Testing Guide

This workspace is intentionally multi-component. Tests stay with the component they verify, while the installed `mn_test` command provides cross-component orchestration.

## Reader and outcome

- **Reader:** contributor selecting validation for a change.
- **Outcome:** run the smallest relevant check, then expand validation when a shared contract changes.
- **Page type:** contributor reference.
- **Scope:** local component checks, injected contracts, and selection of service-backed suites; production and two-box certification require their own environments.
- **Status:** current source-workspace workflow. `test_all.py` remains a deprecated compatibility entry point.
- **Sources of truth:** `mn-system-tests/src/mn_system_tests/{cli,catalog,runner,config,reports}.py`, component test suites, and `mn_test --help`.
- **Validation:** inspect `--help` and `--list`, check selection with `--dry-run`, then run the smallest owning suite. A skipped or blocked capability is not a passing test.

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
- `mn-system-tests/tests/integration/contracts`: injected API/CLI/SDK contract tests that do not need running Core or Redis services; Python package and local blueprint prerequisites still apply.
- `mn-system-tests/tests/integration/live` and `mn-system-tests/tests/e2e`: service-backed cross-component tests, selected through a runner that provisions its own local services.
- `mn-system-tests/tests/integration/installer`: installer contracts.
- `mn-system-tests/tests/system/benchmarks`: deterministic benchmark and interface performance checks.
- `otterdesk-blueprints/tests` and `mn-skills/*/tests`: blueprint catalog and skill package tests.

## Common Commands

Run these commands from `mn-system-tests/`. Use Python 3.12 or newer and an environment containing the runner and selected component dependencies. For a new environment:

```bash
python3.12 -m venv .venv
.venv/bin/python -m pip install -e .
.venv/bin/mn_test --help
.venv/bin/mn_test --list
```

This creates a local virtual environment and installs Python packages. In `MN_ENV=dev`, normal runs refresh the selected local Python projects and their local dependency closure editably. Use `--skip-python-refresh` to retain an already prepared environment. `--list` and `--dry-run` do not refresh packages. Native dependencies such as Docker, Elixir, Node, and browser binaries remain component prerequisites.

Inspect selection before execution:

```bash
.venv/bin/mn_test --suite contracts --dry-run
```

Choose the smallest relevant check; each row is a separate command from the same directory:

| Validation                                      | Command                                                  |
| ----------------------------------------------- | -------------------------------------------------------- |
| Injected API/CLI/SDK contracts                  | `.venv/bin/mn_test --suite contracts`                    |
| Component unit suites                           | `.venv/bin/mn_test --level unit`                         |
| One component's unit suite                      | `.venv/bin/mn_test --component mn-api --level unit`      |
| Local blueprint catalog validation              | `.venv/bin/mn_test --suite blueprints.local`             |
| Installer and deterministic benchmark contracts | `.venv/bin/mn_test --suite installer --suite benchmarks` |
| Interface performance measurements              | `.venv/bin/mn_test --suite performance`                  |
| Components with dirty Git working trees         | `.venv/bin/mn_test --changed`                            |
| Core runtime end-to-end checks                  | `.venv/bin/mn_test --suite MirrorNeuron.e2e`             |
| Browser end-to-end checks                       | `.venv/bin/mn_test --suite mn-web-ui.e2e`                |
| Python dependency consistency (`pip check`)     | `.venv/bin/mn_test --suite security.dependencies`        |

With no selection filters, the runner selects the full catalog. Local services and demo blueprints can run; gated two-box, GPU, host-secret, and destructive suites remain skipped unless explicitly enabled. This is broader than an offline unit run:

```bash
.venv/bin/mn_test
```

For direct pytest execution against an already prepared environment, without runner service provisioning:

```bash
.venv/bin/python -m pytest tests/integration/contracts tests/integration/installer tests/system/benchmarks -m 'not performance' -q
```

Each runner execution creates `results/runs/<run-id>/` with `report.html`, `report.txt`, `results.json`, `junit.xml`, suite logs, and artifacts. `results/runs/latest.json` points to the latest run. `--results-dir <results-root>` replaces the base directory; the runner still adds a fresh run ID. It supplies `MN_SYSTEM_TEST_RESULTS_DIR` to child tests. The performance suite writes `performance.txt` and `performance.json` inside that run directory.

Inspect the report for failed, blocked, timed-out, or skipped suites and cleanup diagnostics. The runner stops its owned local services at teardown; retain the run directory for diagnosis and remove only that run's artifacts when no longer needed. A `pip check` result covers dependency consistency, not a vulnerability or secret audit. See the owning [runner usage guide](../mn-system-tests/USAGE.md) for the complete catalog, gates, and remote options.

## Manual Live E2E

For a local cross-component smoke run, prefer the runner's owned Core/API/Redis services. From `mn-system-tests/`, inspect prerequisites, then execute:

```bash
.venv/bin/mn_test --suite mn-system-tests.integration --suite mn-system-tests.e2e --dry-run
.venv/bin/mn_test --suite mn-system-tests.integration --suite mn-system-tests.e2e
```

These suites require their catalog-listed native tools and Python packages. They can start listeners, build local runtime artifacts, and execute trusted test payloads. Their service logs and cleanup diagnostics stay in the run directory.

When invoking live pytest tests directly, the caller owns service startup and cleanup. Use a disposable Core/API/Redis setup with separate ports, writable storage roots, and a unique Redis namespace. Set `MN_GRPC_TARGET`, `MN_API_BASE_URL`, and `RUN_MN_SYSTEM_TESTS=1` for that setup. Do not point mutating tests at a developer or production runtime.

## Redis HA Tests

MirrorNeuron includes Redis Sentinel smoke tests for the runtime's durable state store.

Local Docker test:

```bash
cd MirrorNeuron
bash scripts/test_redis_sentinel_ha.sh
```

Warning: the two-box test stops a Redis primary to exercise failover. Use only the script's disposable test topology, with the networking and cleanup prerequisites in [Redis HA](redis-ha.md).

Two-box Docker test:

```bash
cd MirrorNeuron

bash scripts/test_redis_sentinel_two_box_ha.sh \
  --remote-host <remote-host> \
  --local-ip <local-host> \
  --remote-ip <remote-host>
```

Expected success markers:

```text
two_box_initial_write_ok=...
two_box_post_failover_write_read_ok
```

The two-box test starts Redis and Sentinel on both machines, writes MirrorNeuron state, kills the initial Redis primary, waits for Sentinel failover, then writes and reads again through the promoted replica. If the remote box cannot route to the local Redis test port, the script automatically uses the remote Redis as the initial primary and tests failover back to the local replica.

Run the local smoke through the workspace runner from `mn-system-tests/`:

```bash
.venv/bin/mn_test --suite redis-ha.local
```

The remote suite is `redis-ha.two-box` and requires `--two-node`. Before enabling it, follow the [Redis HA prerequisites and cleanup procedure](redis-ha.md). Set `--remote-ssh-command` and `--remote-mn-set-folder` together when selecting a non-default remote workspace. Both direct scripts and the runner exercise failover by stopping a test primary; use only the disposable test topology. Success requires the suite to pass and cleanup diagnostics to be clear.

## Nomad-Inspired Runtime Feature Tests

The Nomad-inspired runtime features should be covered at three levels:

- component unit tests in `MirrorNeuron`, `mn-cli`, and `mn-python-sdk`
- live cross-component tests in `mn-system-tests`
- two-box joined-cluster smoke tests when placement, drain, recovery, or schedule uniqueness is involved

Core areas to keep covered:

| Feature                   | Test focus                                                                                                       |
| ------------------------- | ---------------------------------------------------------------------------------------------------------------- |
| Reconciliation            | Node-loss recovery, live coordinator agent movement, whole-job recovery after lease loss, pause for unsafe work. |
| Job types                 | `service`, `batch`, `system`, and `sysbatch` lifecycle behavior.                                                 |
| Restart/reschedule policy | Sliding windows, delay functions, `mode: fail`, `mode: delay`, disabled and unlimited reschedule.                |
| Drain and maintenance     | Eligibility, dry run, service migration, batch waiting, system ignore, cancellation, undrain.                    |
| Services and checks       | Manifest validation, service preflight, registry filtering, HTTP/TCP/script/gRPC checks.                         |
| Resources and devices     | CUDA vs Metal, GPU memory, device ID exclusivity, explicit port conflicts, host volume placement.                |
| Deployments               | Rolling, canary isolation, promotion, rollback, service discovery roles.                                         |
| Schedules and events      | Cron parsing, timezone, delayed runs, overlap prevention, missed policies, event filters, idempotent dispatch.   |

Two-box federation checks must use distinct writable Redis identities. Sync the
remote workspace through a fast-forward Git update and exact commit parity;
never edit tracked files directly on the remote machine.

Typical federation verification:

```bash
# Run once on each node
mn runtime start

# Run the command printed by the joining node on an existing peer
mn node add <peer-ip> --token <join-token> --grpc-port 55051
mn node list
mn resource show
```

Then run targeted system tests for:

- reciprocal readiness and the absence of BEAM membership;
- one owner-local job on each Core, with no cross-node agent placement;
- owner autonomy and stale projections during a network partition;
- explicit and automatic owner selection from resource/model capabilities;
- owner-LiteLLM-first local and remote gateway routing; and
- secret redaction in topology artifacts, reports, and diagnostics.

`cluster.federation.local` is an ungated deterministic CI topology. The gated
two-box `cluster.federation`, `cluster.storage`, `cluster.job-controls`,
`cluster.models`, `cluster.scale`, and `cluster.llm-live` suites cover the real
network boundary after both hosts are on the same commit.

## Environment Rules

All runtime/config overrides must use `MN_`.

Useful test isolation vars:

- `MN_GRPC_PORT`: use a non-default port for test core instances.
- `MN_GRPC_TARGET`: point CLI/API/SDK tests at the test core.
- `MN_API_BASE_URL`: point system e2e tests at a non-default API port.
- `MN_REDIS_NAMESPACE`: isolate Redis keys per test run.
- `MN_ENV=test`: use test-mode validation where appropriate.
- `MN_API_TOKEN`: test API bearer auth.
- `MN_BENCHMARK_WORKER_COUNT`: worker count for the generated live parallel-worker smoke test; defaults small for local runs and can be set to `100` for stress checks.
- `MN_PERF_ITERATIONS`: measured iterations per performance probe; defaults to `30`.
- `MN_PERF_WARMUP`: warmup iterations per performance probe; defaults to `5`.
- `RUN_MN_PERF_LIVE`: set to `1` to add live API, gRPC, LLM, or Web UI interface probes.

Direct pytest marks `live` tests skipped when `RUN_MN_SYSTEM_TESTS=1` is absent. The `mn_test` runner supplies that variable to its owned local service suites. Remote suites require `--two-node`; GPU, host-secret, and destructive capabilities require their corresponding `--enable` options. A dry run with remote gates enabled can perform read-only SSH prerequisite checks.

## Test-selection rule

For a cross-component regression, prefer `mn-system-tests/tests/integration/contracts` with injected clients or openers before adding a live test. Add a live integration or end-to-end check only when the behavior depends on a running service, Docker, Redis, network topology, or an external capability that an injected test cannot represent.
