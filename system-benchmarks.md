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
