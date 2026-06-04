# Model Runtime

MirrorNeuron can manage local LLMs through Docker Model Runner. The model runtime is used by blueprints that declare `provider: "docker_model_runner"` in `llm.configs`.

The default local model is `gemma4:e2b`, which resolves to Docker's `ai/gemma4:E2B` model. It uses the Docker Model Runner llama.cpp backend by default.

## Commands

```bash
mn model list
mn model show gemma4:e2b --compatibility
mn model install gemma4:e2b
mn model update gemma4:e2b
mn model remove gemma4:e2b
mn model doctor gemma4:e2b
```

Use `--json` on `list`, `show`, and `doctor` for machine-readable output.

Installs and blueprint validation block incompatible hardware by default. Use `--force` only when you accept slow CPU execution or a partial accelerator path.

## Blueprint Config

```json
{
  "llm": {
    "enabled": true,
    "default_config": "primary",
    "configs": {
      "primary": {
        "provider": "docker_model_runner",
        "mode": "openai_compatible",
        "runtime_model": "gemma4:e2b",
        "model": "gemma4:e2b",
        "api_base": "auto",
        "backend": "llama.cpp",
        "context_size": 4096,
        "timeout_seconds": 60,
        "max_tokens": 800
      }
    }
  }
}
```

At launch, MirrorNeuron resolves the config to:

- `MN_LLM_PROVIDER=docker_model_runner`
- `MN_LLM_MODEL=ai/gemma4:E2B`
- `MN_LLM_RUNTIME_MODEL=ai/gemma4:E2B`
- `MN_LLM_API_BASE=http://localhost:12434/engines/v1` for HostLocal workers
- `MN_LLM_API_BASE=http://model-runner.docker.internal/engines/v1` for container or sandbox workers

## Catalog Overrides

The built-in catalog can be extended or overridden with JSON entries from:

- `MN_MODEL_CATALOG_PATH`
- `~/.mn/models/catalog.json`

The file may contain a list, a `{ "models": [...] }` object, or an object keyed by model id. Local entries win over built-in entries with the same `id`.

## Hardware Validation

| Hardware profile | `gemma4:e2b` default result | Backend | Rule |
| --- | --- | --- | --- |
| Apple Silicon, 16GB+ unified memory | Pass | llama.cpp / Metal | Default supported target. |
| Apple Silicon, 8GB unified memory | Fail | llama.cpp / Metal | Too tight for default policy. |
| NVIDIA CUDA, Linux or WSL2, 8GB+ VRAM | Pass | llama.cpp / CUDA | vLLM is only for vLLM-capable catalog models. |
| NVIDIA CUDA, Linux ARM64, 8GB+ VRAM | Pass | llama.cpp / CUDA | vLLM is not supported. |
| NVIDIA CUDA, 6GB VRAM | Fail | llama.cpp / partial GPU possible | Requires `--force` or a smaller model. |
| AMD ROCm/Vulkan, Docker Engine Linux, 8GB+ VRAM | Pass with warning | llama.cpp | Verify acceleration with `mn model doctor`. |
| CPU-only, 32GB+ RAM | Force only | llama.cpp / CPU | Slow CPU execution requires `--force`. |
| Intel Mac or Windows without supported GPU | Fail | CPU fallback only | Use a smaller model or `--force`. |
| Windows ARM64 with Adreno 6xx+ and 16GB+ unified memory | Pass with warning | llama.cpp / OpenCL | Acceleration support is partial. |
| Raspberry Pi / low-memory ARM CPU | Fail | CPU | Not default-compatible. |

## Validation

`mn blueprint validate` and `mn blueprint run` check runtime-managed models after service checks and before input validation. Missing models fail with a fix like:

```bash
mn model install gemma4:e2b
```
