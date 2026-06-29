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
mn model proxy --config mn-docs/examples/openai-compatible-model-proxy.json
mn model remote add ai/qwen3-coder --base-url http://192.168.4.173:12434/v1 --name spark
mn model remote list
mn model remote remove spark
```

Use `--json` on `list`, `show`, and `doctor` for machine-readable output.

Installs and blueprint validation block incompatible hardware by default. Use `--force` only when you accept slow CPU execution or a partial accelerator path.

## LiteLLM Proxy Models

Use a LiteLLM proxy when a model should appear in `mn model list` and blueprint validation without a local Docker Model Runner install. Proxy models are stored in `$MN_HOME/models/proxies.json`, show as installed, and display `backend` as `proxy`.

Create and start a proxy:

```bash
export OPENAI_API_KEY=...
mn model proxy --config mn-docs/examples/openai-compatible-model-proxy.json
mn model list --installed
```

The command generates a LiteLLM config under `$MN_HOME/models/proxies/`, starts `ghcr.io/berriai/litellm:main-latest`, and registers each configured model. Use `--no-start` to only generate config and register the models, or `--replace` to replace an existing proxy container with the same generated name.

Example config:

```json
{
  "provider": {
    "openai-compatible": {
      "options": {
        "baseURL": "https://api.openai.com/v1",
        "apiKeyEnv": "OPENAI_API_KEY"
      },
      "models": {
        "openai/gpt-5.4-mini": {
          "name": "OpenAI GPT 5.4 Mini",
          "model": "openai/gpt-5.4-mini",
          "rate_limit_rpm": 30,
          "timeout_seconds": 120
        }
      }
    }
  }
}
```

After registration, blueprint configs can refer to the proxy model by id:

```json
{
  "llm": {
    "enabled": true,
    "configs": {
      "primary": {
        "provider": "docker_model_runner",
        "runtime_model": "openai/gpt-5.4-mini"
      }
    }
  }
}
```

Validation treats proxy models as ready service-backed models. Hardware compatibility checks are skipped because the model is served by the configured upstream provider, not installed locally.

## Cross-Box Model Endpoints

Blueprints should name the model they need. They do not need to know whether that model is served locally or by another cluster node.

When a Docker Model Runner model is already advertised by a runtime node, launch preparation treats it as ready and passes a neutral `MN_MODEL_ENDPOINTS_JSON` mapping to workers. This mapping is separate from `MN_LLM_API_BASE`, `MN_LLM_MODEL`, `LITELLM_*`, and `OPENAI_*`, so blueprints with multiple LLM configs can resolve each model independently.

Operators can declare unmanaged remote endpoints:

```bash
mn model remote add ai/qwen3-coder \
  --base-url http://192.168.4.173:12434/v1 \
  --name spark
```

Remote declarations are stored in `$MN_HOME/model-remotes.json` or `~/.mn/model-remotes.json`. The runtime advertises those declarations as `docker-model-runner` services on node advertisement, and the CLI can use them immediately during blueprint preparation.

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
- `$MN_HOME/models/catalog.json`

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
