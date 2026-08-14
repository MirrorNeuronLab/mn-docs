# Model Runtime

MirrorNeuron manages Docker Model Runner artifacts and external
OpenAI-compatible provider routes through one model registry. The model runtime
is used by blueprints that declare `provider: "docker_model_runner"` in
`llm.configs`.

Without an operator override, MirrorNeuron selects its built-in default from
the host hardware: `nemotron3` on a suitable NVIDIA system and `gemma4:e2b`
otherwise. A model added with `--default` takes priority over both built-ins.

## Ownership Boundary

Model definition, registry persistence, catalog resolution, provider parsing,
hardware compatibility checks, Docker Model Runner lifecycle operations, and
model-to-service expansion are owned by `mn-python-sdk`, `mn-cli`, and
`mn-api`.

MirrorNeuron Core does not own the model catalog and does not install models directly. Core receives already-expanded runtime facts, checks concrete service availability, schedules jobs, and runs agents. If a required model or service is not ready, Core reports a preflight or scheduling error instead of preparing the resource itself.

Launch preparation should translate blueprint model references into concrete service requirements before submission:

- concrete `requires_services` entries
- service tags for `docker-model-runner` or provider endpoints
- placement requirements for the node that can serve the model
- endpoint environment such as `MN_MODEL_ENDPOINTS_JSON`
- prepared-model metadata owned by the SDK/API/CLI layer

## Commands

```bash
mn model list
mn model list --available
mn model add gemma4:e2b
mn model add --file mn-docs/examples/openai-compatible-model-proxy.json
mn model add hf.co/acme/chat:Q4_K_M --default
mn model add --file mn-docs/examples/muse-glimmer-gomokubench-config.json --default
mn model doctor gemma4:e2b
mn model update gemma4:e2b
mn model remove gemma4:e2b --yes
```

Use `--json` on every command for machine-readable output. `mn model list`
shows added models plus unmanaged local DMR artifacts; `--available` includes
catalog-only choices. Human output uses `ID`, `Kind`, `Source`, `State`, and
`Node`. JSON output explicitly reports `kind`, `state`, `registered`,
`installed`, `routed`, `node`, `cataloged`, and `verification`. States are
`ready`, `degraded`, `unmanaged`, and catalog-only `available`.

`--default` is valid for either a DMR reference or a provider JSON file that
defines exactly one model. The registry stores only that model's ID as the
operator-selected priority; it never stores resolved provider secrets. Removing
the selected model restores automatic `nemotron3`/`gemma4:e2b` selection.

DMR adds and blueprint validation block incompatible hardware by default. Use
`--force` only when you accept slow CPU execution or a partial accelerator
path.

## Provider Models

Use a provider definition when a model is served by an external
OpenAI-compatible endpoint instead of local Docker Model Runner. Added DMR and
provider records are stored together in `$MN_HOME/models/registry.json`.
Provider routes are loaded by MirrorNeuron's managed LiteLLM gateway.

Register a provider definition:

```bash
export OPENAI_API_KEY=...
mn model add --file mn-docs/examples/openai-compatible-model-proxy.json
mn model list
```

The command validates the complete JSON file before changing state, checks each
`apiKeyEnv` reference, rejects duplicate registered IDs, and synchronizes the
managed gateway across runtime nodes. It does not start a standalone proxy
container. Remove an existing ID before adding a changed definition.

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

After registration, blueprint configs can refer to the provider model by ID:

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

Validation treats provider models as service-backed models. Hardware
compatibility checks are skipped because the model is served by the configured
upstream provider, not installed locally. `mn model update <ID>` reloads the
stored source JSON and synchronizes its route. `mn model remove <ID>` removes
only that registration and its routes; it never deletes the source JSON.

## Cross-Box Model Placement

Blueprints should name the model they need. They do not need to know whether that model is served locally or by another cluster node.

For cluster launches, the SDK/API/CLI chooses the target node from the cluster resource summary, then sends `PrepareRuntimeModel` to that node's advertised Core gRPC endpoint. That node's Core only relays the request to its node-local SDK gRPC sidecar. The SDK sidecar on that same host performs Docker Model Runner operations and returns concrete endpoint facts.

This path is intentionally gRPC-only between runtime nodes. Operators should not rely on SSH to install models on another box during normal blueprint launch.

When a Docker Model Runner model is already advertised by a runtime node, launch preparation treats it as ready and passes a neutral `MN_MODEL_ENDPOINTS_JSON` mapping to workers. This mapping is separate from `MN_LLM_API_BASE`, `MN_LLM_MODEL`, `LITELLM_*`, and `OPENAI_*`, so blueprints with multiple LLM configs can resolve each model independently.

`mn model add <MODEL>` selects the best compatible runtime node by default.
Use `--local` to require the submitting machine or `--node <node-name>` to
select a specific cluster node. Cluster-managed model routes remain dynamic:
the runtime monitor adds and removes them as node inventories change.

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

The SDK built-in catalog can be extended or overridden with JSON entries from:

- `MN_MODEL_CATALOG_PATH`
- `$MN_HOME/models/catalog.json`

The file may contain a list, a `{ "models": [...] }` object, or an object keyed by model id. Local SDK entries win over built-in entries with the same `id`. These overrides are resolved before Core receives a submitted job.

## Exceptional Blueprint Hugging Face Models

A blueprint may explicitly opt into an uncataloged Hugging Face Docker Model Runner model by setting `customize_mode: true` on `runtime.models.<name>`. Operators may also add an arbitrary valid DMR or Hugging Face reference with `mn model add <MODEL>`; that registration is marked `unverified` and does not gain catalog-specific hardware guarantees.

```json
{
  "runtime": {
    "models": {
      "primary": {
        "provider": "docker_model_runner",
        "runtime_model": "hf.co/bartowski/Qwen2.5-7B-Instruct-GGUF:Q4_K_M",
        "backend": "llama.cpp",
        "context_size": 4096,
        "required": true,
        "customize_mode": true
      }
    }
  }
}
```

Only explicit `hf.co/<owner>/<repo>[:tag]` and `huggingface.co/<owner>/<repo>[:tag]` references are accepted. The declaration is rejected if the model is already cataloged, uses an external endpoint, disables installation, or selects a backend other than `auto`, `llama.cpp`, or `vllm`.

MirrorNeuron does not perform model-specific hardware compatibility checks for this mode. It selects the healthy, schedulable, custom-model-capable node with the greatest accelerator capacity and attempts installation there. Failure on that selected node stops launch; it does not fall back locally or try another node. The resulting model and ownership records remain marked `unverified`.

See [`examples/custom-hf-model`](examples/custom-hf-model) for a source manifest and matching blueprint config.

Custom model preparation uses the same timeout policy in CLI and API launches. Set
`MN_RUNTIME_MODEL_PREPARE_TIMEOUT_SECONDS` to a positive number of seconds to override the
default 1200-second timeout. Transient timeout or unavailable gRPC failures are retried once
against the same selected node.

Node logs record the `resolve`, `install`, `gateway`, and `ready` preparation phases with the
model, selected node, attempt, duration, and stable error code. Ownership metadata records
`prepare_status` and `prepare_stage`; an installed model whose gateway registration fails remains
recorded as installed with a gateway failure instead of being reported as ready.

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

`mn blueprint validate` and `mn blueprint run` check and prepare runtime-managed models before Core submission whenever the selected flow is allowed to prepare native host resources. Missing models fail with a fix like:

```bash
mn model add gemma4:e2b
```

After submission, Core only checks the concrete service requirements provided by the SDK/API/CLI. It does not resolve aliases, choose model backends, inspect model hardware compatibility, or install Docker Model Runner models.
