# System Benchmarks

MirrorNeuron system benchmarks provide deterministic fixtures and report
generation for runtime evaluation.

This contributor reference covers fixture evaluation and interface measurements in the current source workspace. It does not establish production quality or performance. Use the Python environment from [Testing](testing.md#common-commands); sources of truth are `mn-system-tests/src/mn_system_tests/benchmarks/`, its suite catalog, and `tests/system/benchmarks/`.

## Metrics

| Metric | What it measures |
| --- | --- |
| Workflow Completion Rate | Whether a full multi-step workflow finishes the intended task. |
| Fault Recovery Rate | Whether the workflow resumes after worker, tool, loop, or approval failures. |
| Tool Execution Accuracy | Whether agents choose expected tools, parameters, and side-effect boundaries. |
| Cost per Successful Workflow | Estimated runtime cost for successful workflow execution. |
| Human Intervention Rate | How often a person is needed at review or repair checkpoints. |

## Run Tests

```bash
cd mn-system-tests
.venv/bin/mn_test --suite benchmarks
```

Run the key interface performance benchmark:

```bash
.venv/bin/mn_test --suite performance
```

Continue from `mn-system-tests/` for all commands below. The runner writes `performance.txt` and `performance.json` under the fresh `results/runs/<run-id>/` directory, alongside the aggregate report and suite logs.
The report covers injected API HTTP routes, SDK/gRPC-boundary calls, CLI runtime
status, and the LLM stream parser. It also records hardware, software, Python
package versions, git revisions, and skipped/live probe reasons.

Live endpoint measurements are opt-in:

```bash
RUN_MN_PERF_LIVE=1 \
MN_API_BASE_URL=http://127.0.0.1:54001/api/v1 \
MN_GRPC_TARGET=127.0.0.1:55051 \
MN_LLM_BASE_URL=http://127.0.0.1:12434/engines/v1 \
MN_LLM_MODEL=ai/gemma3 \
MN_WEB_UI_URL=http://127.0.0.1:55173 \
.venv/bin/mn_test --suite performance
```

The parallel-worker benchmark contract is generated in `mn-system-tests`
rather than loaded from a blueprint repository. Offline tests validate the
manifest shape; live tests submit a temporary fanout manifest when explicitly
enabled.

Use the `scale.local` runner suite for the owned local service path. A direct pytest invocation of `tests/integration/live` with `-k parallel_worker` needs caller-managed disposable services and `RUN_MN_SYSTEM_TESTS=1`; see [Manual Live E2E](testing.md#manual-live-e2e) for isolation requirements. `MN_BENCHMARK_WORKER_COUNT` controls the requested worker count.

## Generate A Report

```bash
.venv/bin/python -m mn_system_tests.benchmarks.agent_runtime --output-dir /tmp/mn-agent-runtime-benchmark
```

The report includes completion, recovery, tool/action correctness, cost, human
intervention, and a compact scorecard JSON object for CI trend checks.
The command writes fixture-derived reports to the selected directory; choose a fresh output directory to preserve earlier results. Remove that directory when the artifacts are no longer needed. Runner-owned services are stopped at teardown, and their cleanup diagnostics remain in the aggregate report.

## Publishing Notes

- Replace fixture observations with fresh artifacts from live MirrorNeuron runs
  before sharing external benchmark claims.
- Refresh provider pricing data before publishing cost estimates.
- Document any human-review rubric used for quality grading.
- Add a repository-level license before distributing benchmark fixtures or
  reports outside the project.

## Related Pages

- [Testing](testing.md)
- [Component Guide](component-guide.md#workspace-map)
