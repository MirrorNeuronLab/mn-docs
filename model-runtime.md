# Model Runtime

MirrorNeuron manages Docker Model Runner artifacts and external
OpenAI-compatible provider routes through one model registry. The model runtime
is used by blueprints that declare `provider: "docker_model_runner"` in
`llm.configs`.

Without an operator override, MirrorNeuron selects its built-in default from
healthy cluster hardware, in this order:

| Tier | Model | Accelerator memory minimum |
| --- | --- | --- |
| `medium` | Nemotron 3.5 Lightning | 48 GB VRAM or integrated/shared GPU memory |
| `small` | Bonsai2 27B PTQ1_0 (~5.95 GB weights) | 24 GB VRAM or integrated/shared GPU memory |
| `nano` | Gemma 4 E2B | 8 GB VRAM or 16 GB unified memory |

`default` selects the first feasible tier: medium → small → nano. CPU RAM alone
does not qualify as accelerator memory. An operator-selected default takes
priority over automatic selection.

Tier thresholds use total hardware capacity. Explicit worker GPU allocations
still require free memory. On Windows, detection uses
[DXGI dedicated VRAM](https://learn.microsoft.com/en-us/windows/win32/api/dxgi/ns-dxgi-dxgi_adapter_desc1)
and [D3D12 UMA architecture](https://learn.microsoft.com/en-us/windows/win32/api/d3d12/ns-d3d12-d3d12_feature_data_architecture):
confirmed integrated AMD/Intel adapters use installed shared host memory;
discrete cards use dedicated VRAM. Driver acceleration must be verified with
`mn model probe` on the target machine.

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
mn model probe gemma4:e2b
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

Use `mn model probe <model-id>` after the model and managed LiteLLM gateway are
ready to replace catalog assumptions with a live behavioral matrix. The default
probe covers embeddings, image input, strict JSON Schema output, SSE streaming,
and thinking. It forces fresh requests even when the catalog already contains
values and persists the effective LiteLLM-facing result in
`$MN_HOME/models/catalog.json`:

```bash
mn model probe gemma4:e2b
mn model probe gemma4:e2b --capabilities json-schema,streaming
mn model probe nemotron-3.5-lightning:latest --json
```

For a DMR artifact selected on the current node, the command also probes the
host Docker Model Runner endpoint and requires exact parity through LiteLLM.
For a remote-owner or provider model, the command respects the routing boundary
and does not attempt direct access. A completed probe may contain `false`
capabilities; these are verified unsupported behaviors, not command failures.
An unknown result, unreachable endpoint, missing route, or direct/proxy mismatch
fails the command.

`--default` is valid for either a DMR reference or a provider JSON file that
defines exactly one model. The registry stores only that model's ID as the
operator-selected priority; it never stores resolved provider secrets. Removing
the selected model restores automatic medium → small → nano selection.

DMR adds and blueprint validation block incompatible hardware by default. Use
`--force` only when you accept slow CPU execution or a partial accelerator
path.

## Bonsai2 on Docker Model Runner

The unreleased `small` catalog entry uses
`hf.co/prism-ml/Ternary-Bonsai-2-27B-gguf:PTQ1_0`, tagged locally as
`bonsai2:ptq1_0`, with a 32,768-token initial context. Its ternary packing requires
Prism llama.cpp. The catalog declares that customization, and the SDK prepares
it automatically during normal installation or first use.

Run from any directory with MirrorNeuron and Docker Desktop/Engine installed.
The installed Python SDK downloads a prepared native runner from public GAR
and verifies its catalog-pinned SHA-256 before extraction. Users need no Go,
Git, compiler or Google Cloud credentials. The first preparation downloads
runner/backend assets; model installation then downloads the weights. Preparation
starts a managed host listener: control uses loopback, and container inference
requires the generated token. Keep runner state and gateway env files private.

```bash
mn model add small --local
mn model probe small
```

Automatic `default` selection uses this same preparation when the selected owner
has at least 24 GB and less than 48 GB accelerator memory. Blueprint launch
keeps its lazy installation behavior: actual model use triggers preparation.
macOS Apple Silicon selects Metal, NVIDIA PCs select CUDA, and AMD/Intel GPUs
select Vulkan. The catalog also contains explicit HIP assets. Linux ARM64 CUDA
uses a prepared GAR backend for Spark's GB10 (SM 12.1), Ubuntu 24.04 and NVIDIA
driver 580+, with CUDA 13 runtime libraries bundled. Windows ARM64 GPU assets
remain unavailable. Metal runs natively on macOS; Docker's Linux VM cannot
provide Apple Metal acceleration.

Release builds compile the native DMR from a full commit SHA with the SDK's fixed
managed HTTP, native transport and Prism version-parser patches. The installed SDK
downloads those prepared binaries, uses pinned backend assets, verifies the backend commit, and sets
`LLAMA_SERVER_PATH` and `DISABLE_SERVER_UPDATE=true`. Per-recipe/platform caches
under `MN_HOME/model-runners` hold the runner, backend, weights, logs and private
state. Repeated preparation reuses the cache; changed customization creates a
separate bundle. A stopped owned controller restarts automatically during
preparation or request admission. Preparation leaves model weights unloaded.

Control calls use the selected runner's host-loopback address. Container
inference uses authenticated `/engines/` access through the owner LiteLLM gateway;
its SDK-generated private Compose env file supplies the token. Public configs
hold environment references. Normal models keep their regular DMR endpoint.
No manual launcher, global endpoint exports or Docker Desktop backend replacement
is required. Workers continue using their node-local LiteLLM route.

The catalog contract is `preparation.kind: "dmr_native"`, version 1. Its `runner`
contains an HTTPS GitHub source repository, immutable revision, SDK policy and
per-platform prepared archives (`name`, public HTTPS `url`, mandatory `sha256`). Its `backend`
contains a repository, release, commit and per-platform asset lists. For example,
the packaged Bonsai2 recipe includes:

```json
{
  "preparation": {
    "kind": "dmr_native",
    "version": 1,
    "runner": {
      "repository": "https://github.com/docker/model-runner",
      "revision": "ab88713fadabe6a6da5d7c7fe8ce3407ecf2d4da",
      "policy": 2,
      "assets": {
        "darwin-arm64": {
          "name": "managed-dmr-darwin-arm64.tar.gz",
          "url": "https://artifactregistry.googleapis.com/download/v1/projects/mirrorneuron-public-packages/locations/us-central1/repositories/mirrorneuron-binaries/files/managed-dmr%3Aab88713fadab-policy2%3Amanaged-dmr-darwin-arm64.tar.gz:download?alt=media",
          "sha256": "10ec21136c63b4f4f8e7cbe1c7795a058d2f8773483256eabbd337b7703d6c34"
        }
      }
    },
    "backend": {
      "repository": "https://github.com/PrismML-Eng/llama.cpp",
      "release": "prism-b10743-adfffbe",
      "commit": "adfffbe",
      "assets": {
        "darwin-arm64-metal": [
          "llama-prism-b10743-adfffbe-bin-macos-arm64.tar.gz"
        ]
      }
    }
  }
}
```

The full packaged recipe includes Windows and Linux assets. An optional
`backend.accelerator` selects `metal`, `cuda`, `hip`, `vulkan` or `cpu`; the
default `auto` uses the owner accelerator. `backend.transport` accepts `auto`,
`tcp` or `unix`. Automatic transport uses loopback TCP with independent backend
ports on Windows and Unix sockets on macOS/Linux. Operators can use
`MN_HOME/models/catalog.json` or `MN_MODEL_CATALOG_PATH` for catalog overrides.
Asset entries can also be `{ "name": "backend.zip", "sha256": "<digest>" }`
objects. A public HTTPS `url` can select a GAR backend; an explicit URL always
requires a pinned SHA-256. Otherwise the archive comes from the pinned GitHub
release. The SDK rejects unsupported fields, arbitrary scripts, unpinned runner
revisions and unsafe archive paths before download effects. Missing prepared
runner assets fail explicitly; normal installation never compiles source.

Python callers can warm the backend independently of the model artifact:

```python
from mn_sdk import prepare_dmr_model, resolve_model_entry

prepared = prepare_dmr_model(resolve_model_entry("small"))
```

The deploy `scripts/build-prism-dmr.py` helper calls this same SDK API. Normal
load/unload and last-job cleanup target the matching runner. Unload releases
weights from accelerator memory and keeps downloaded artifacts and the backend
cache; `mn model remove small --local --yes` removes the model installation and
route while preserving the backend cache. Failed archive checksums stop preparation
before execution; startup failures point to the bundle's launcher log,
and occupied ports fail without adopting another service.

Verification covers offline selection, safe preparation, cache reuse/restart,
load/unload and gateway routing. Live acceptance on 2026-10-12 passed native
inference with all 65/65 model layers on Apple M4 Pro Metal and Spark GB10 CUDA.
The Mac's normal LiteLLM path passed streaming and JSON-schema probes with Go
absent from `PATH`. A fresh Spark SDK wheel downloaded and verified the public
GAR runner/backend, installed and configured Bonsai2, and passed JSON-schema and
streaming inference with both Go and `nvcc` absent from `PATH`. Windows and Linux x64 binaries are cross-compiled; live
inference on those platforms remains an opt-in acceptance check.

## Nemotron 3.5 Lightning Compatibility

The built-in `nemotron-3.5-lightning:latest` alias pulls
`hf.co/bartowski/NVIDIA-Nemotron-3.5-Lightning-30B-A3B-GGUF:Q4_K_M` and then
tags that artifact locally as `nemotron-3.5-lightning:latest`. MirrorNeuron
does not use the defective `ai/nemotron-3.5-lightning:latest` artifact.

On a Linux host with NVIDIA hardware, `mn-deploy/install.sh` ensures Docker
Model Runner uses the CUDA-enabled llama.cpp `b10524` build before it prepares
models. The one-time upgrade downloads the Model Runner source and CUDA image,
replaces the `docker-model-runner` controller container, and retains the named
`docker-model-runner-models` volume. It does not delete model artifacts.

On an NVIDIA DGX Spark or comparable ARM64 Ubuntu host, prepare the Docker APT
source, Model Runner plugin, and NVIDIA container runtime by following
[Prepare Docker Model Runner on NVIDIA DGX Spark](docker-model-runner-arm64-nvidia.md)
before running the MirrorNeuron installer.

After installation or a lazy model preparation, verify the local alias with:

```bash
docker model status
docker model list
docker model run nemotron-3.5-lightning:latest "Explain Docker containers in one sentence."
```

## Provider Models

Use a provider definition when a model is served by an external
OpenAI-compatible endpoint instead of local Docker Model Runner. Added DMR and
provider records are stored together in `$MN_HOME/models/registry.json`.
Provider routes are loaded by MirrorNeuron's managed LiteLLM gateway.

### Adaptive output budgets

The managed LiteLLM gateway prepares a bounded output-token limit before each
generation request reaches a model. Initial requests default to 1024 tokens;
an explicitly marked, harness-managed continuation defaults to 2048. A valid
caller limit is never increased. The forwarded limit is the smallest known
positive cap from the caller, phase, model metadata, hardware safety policy,
remaining job budget, and reliably estimated remaining context.

Configure the node-local policy with:

```bash
MN_LITELLM_ADAPTIVE_OUTPUT_BUDGET_ENABLED=true
MN_LITELLM_ADAPTIVE_OUTPUT_BUDGET_INITIAL_TOKENS=1024
MN_LITELLM_ADAPTIVE_OUTPUT_BUDGET_CONTINUATION_TOKENS=2048
MN_LITELLM_ADAPTIVE_OUTPUT_BUDGET_CONTEXT_RESERVE_TOKENS=256
MN_LITELLM_ADAPTIVE_OUTPUT_BUDGET_HARDWARE_SAFE_MAX_TOKENS=4096
MN_LITELLM_ADAPTIVE_OUTPUT_BUDGET_FAIL_OPEN=true
```

Model definitions may add `max_output_tokens`,
`hardware_safe_max_output_tokens`, and `total_context_window`. Catalog
`context_size` is projected as the total context window. Per-model operator
overrides can be supplied with
`MN_LITELLM_ADAPTIVE_OUTPUT_BUDGET_MODEL_OVERRIDES_JSON`.

Continuation is an explicit request protocol, not an automatic proxy retry:

```json
{
  "metadata": {
    "mn_adaptive_budget_enabled": true,
    "mn_budget_phase": "continuation",
    "mn_budget_attempt": 1,
    "mn_remaining_output_tokens": 5000
  }
}
```

Set `mn_adaptive_budget_enabled` to `false` to preserve the request limit.
Internal controls are stripped before upstream forwarding. Response headers
`x-mn-output-budget-phase`, `x-mn-output-budget-applied`, and
`x-mn-output-budget-reason` expose the decision without recording prompts or
response content.

Register a provider definition:

```bash
export OPENAI_API_KEY="<provider-api-key>"
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

At launch, preparation resolves model IDs and injects the owner's managed
LiteLLM gateway endpoint and credentials. Worker inference uses that gateway;
it must not call Docker Model Runner directly. A remote model route goes from
the owner's gateway to the peer gateway and then to the peer's DMR. Direct DMR
calls in `mn model probe` are diagnostic parity checks, not worker routing.

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

The fragment above is a runtime model descriptor. For authored source packages,
place execution model declarations in the referenced execution document and
follow [Blueprint Standard](blueprint-standard.md). The historical
`examples/custom-hf-model` manifest uses the retired source shape and is not a
current runnable tutorial.

Custom model preparation uses the same timeout policy in CLI and API launches. Set
`MN_RUNTIME_MODEL_PREPARE_TIMEOUT_SECONDS` to a positive number of seconds to override the
default 1200-second timeout. Transient timeout or unavailable gRPC failures are retried once
against the same selected node.

Node logs record the `resolve`, `install`, `gateway`, and `ready` preparation phases with the
model, selected node, attempt, duration, and stable error code. Ownership metadata records
`prepare_status` and `prepare_stage`; an installed model whose gateway registration fails remains
recorded as installed with a gateway failure instead of being reported as ready.

## Hardware Validation

The following table describes the `nano` Gemma4 policy; larger tiers use the
memory minima at the top of this page.

| Hardware profile | `gemma4:e2b` result | Backend | Rule |
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

`mn blueprint validate` and `mn blueprint run` validate declared model
requirements before Core submission. Generation-model installation stays lazy:
first actual use selects an owner and prepares its runner, artifact and gateway
route. Explicit installation remains available with:

```bash
mn model add gemma4:e2b
```

After submission, Core only checks the concrete service requirements provided by the SDK/API/CLI. It does not resolve aliases, choose model backends, inspect model hardware compatibility, or install Docker Model Runner models.
