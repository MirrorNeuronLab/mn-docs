# Context Memory And Compression

MirrorNeuron uses the Membrane projects for shared working memory, context
selection, context compression, and benchmark evaluation.

## Components

| Folder | Purpose | Main validation |
| --- | --- | --- |
| [`Membrane/mn-context-engine`](../Membrane/mn-context-engine) | Rust gRPC context engine. | `cargo test` |
| [`Membrane/mn-context-engine-python-sdk`](../Membrane/mn-context-engine-python-sdk/README.md) | Python SDK shell and utilities for the Rust engine. | `.venv/bin/python -m pytest -q` |
| [`Membrane/mn-context-auto-optimizer`](../Membrane/mn-context-auto-optimizer/README.md) | Deterministic graph/NLP context compression and optional model tooling. | `.venv/bin/python -m pytest -q` |
| [`Membrane/mn-context-auto-optimizer-benchmark`](../Membrane/mn-context-auto-optimizer-benchmark/README.md) | Benchmark and telemetry package for context compression models. | `.venv/bin/python -m pytest -q` |

## Python SDK

Install the Membrane Python SDK from source:

```bash
cd Membrane/mn-context-engine-python-sdk
.venv/bin/python -m pip install -e ".[dev]"
.venv/bin/python -m pytest -q
```

Optional extras are package-specific:

```bash
.venv/bin/python -m pip install -e ".[compression]"
.venv/bin/python -m pip install -e ".[qdrant]"
```

Use `qdrant` and `qdrant-gpu` in separate environments because their FastEmbed
dependencies are mutually exclusive.

## Optimizer Runtime

Install the deterministic optimizer:

```bash
cd Membrane/mn-context-auto-optimizer
.venv/bin/python -m pip install -e ".[dev]"
.venv/bin/python -m pytest -q
```

Inspect runtime capabilities:

```bash
mn-context-packer runtime-info
```

Compress a context packet from standard input:

```bash
cat packet.json | mn-context-packer compress \
  --compression-mode graph_nlp \
  --target-tokens 800 \
  --focus-id goal_1 \
  --agent-role executor
```

Supported compression modes:

| Mode | Use |
| --- | --- |
| `graph_nlp` | Deterministic graph and NLP compression with no model dependency. |
| `llm_only` | Model-only compression; requires `--model-dir` or `MN_CONTEXT_MODEL_DIR`. |
| `hybrid` | Graph-first deterministic compression with optional evidence-only rewrite. |

## Benchmarks

Install the benchmark package:

```bash
cd Membrane/mn-context-auto-optimizer-benchmark
.venv/bin/python -m pip install -e ".[dev]"
```

Run the default graph benchmark:

```bash
mn-context-benchmark --config configs/default.yaml
```

Build a blueprint-derived benchmark suite from the local catalog:

```bash
mn-context-build-blueprint-suite \
  --blueprint-root ../../otterdesk-blueprints \
  --packet-output artifacts/data/blueprint_packet_results.json \
  --working-memory-output artifacts/data/blueprint_working_memory_cases.json \
  --coverage-output artifacts/data/blueprint_suite_coverage.json \
  --cases-per-manifest 12
```

## Notes

- The deterministic runtime path should preserve goals, constraints, source
  references, failures, recovery state, and next actions.
- Optional model or GPU dependencies should be installed only for the benchmark
  or compression path that needs them.
- Keep private or role-restricted memory out of shared context packets unless
  the caller explicitly has access.

## Related Pages

- [Runtime Architecture](runtime-architecture.md)
- [Component Guide](component-guide.md#membrane)
- [Security Model](security.md)
