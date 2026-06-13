# System Benchmarks

MirrorNeuron system benchmarks provide deterministic fixtures and report
generation for runtime evaluation.

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
.venv/bin/python -m pytest benchmarks -q
```

Run the key interface performance benchmark:

```bash
cd mn-system-tests
.venv/bin/python test_all.py --performance
```

This writes `results/performance.txt` and `results/performance.json`.
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
.venv/bin/python test_all.py --performance
```

The parallel-worker benchmark contract is generated in `mn-system-tests`
rather than loaded from a blueprint repository. Offline tests validate the
manifest shape; live tests submit a temporary fanout manifest when explicitly
enabled.

```bash
MN_BENCHMARK_WORKER_COUNT=100 .venv/bin/python -m pytest integration -k parallel_worker
```

## Generate A Report

```bash
cd mn-system-tests
.venv/bin/python -m benchmarks.agent_runtime_benchmark --output-dir /tmp/mn-agent-runtime-benchmark
```

The report includes completion, recovery, tool/action correctness, cost, human
intervention, and a compact scorecard JSON object for CI trend checks.

## Publishing Notes

- Replace fixture observations with fresh artifacts from live MirrorNeuron runs
  before sharing external benchmark claims.
- Refresh provider pricing data before publishing cost estimates.
- Document any human-review rubric used for quality grading.
- Add a repository-level license before distributing benchmark fixtures or
  reports outside the project.

## Related Pages

- [Testing](testing.md)
- [Component Guide](component-guide.md#system-tests)
