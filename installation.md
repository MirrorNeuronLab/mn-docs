# Install MirrorNeuron Locally

This is the canonical installation procedure for maintainers, contributors, and operators. It documents the deployment installer, local workspace mode, validation signals, state locations, and safe removal behavior.

## Reader and outcome

- **Reader:** operator or contributor preparing a local runtime.
- **Outcome:** the `mn` CLI is available, the local runtime is healthy, and the operator knows where state and listeners live.
- **Page type:** installation how-to.
- **Source of truth:** `mn-deploy/install.sh`, `mn-deploy/server.sh`, `mn-cli/mn_cli/libs/sys_cmds.py`, and the API/CLI configuration schemas.

## Before you begin

- Supported local environments are macOS, Linux, and Windows with WSL2.
- Docker must be installed and running.
- `git` is required for checkout-based installation.
- Python 3.11+ and Elixir/Erlang are required for editable workspace development, not for every released-package installation.
- Docker Model Runner is required only for blueprints that use local models. Docker Desktop provides it on macOS and Windows; Linux operators must install the plugin when they need that capability.

## Install released components

Use the deployment repository for a reviewable installation path:

```bash
cd mn-deploy
./install.sh --help
./install.sh
```

The installer uses default selections without prompts unless `--interactive` is passed. Use `--version <release-tag>` when you need a matching released set of Core, CLI, SDK, API, Web UI, and support files.

The hosted installer is available when a local checkout is not practical:

```bash
curl -fsSL https://mirrorneuron.io/install.sh | bash
```

Warning: this command downloads and executes a script immediately. Prefer `mn-deploy/install.sh` when you need to inspect the script, select a mode, or retain an auditable local copy.

## Install an editable workspace runtime

Run local mode from the deployment component when you are developing against the current workspace:

```bash
cd mn-deploy
./install.sh --mode local
```

For an explicit Git-based installation, use:

```bash
cd mn-deploy
./install.sh --mode github
```

Git mode uses component repositories rather than editable paths from this checkout. Do not use it when your goal is to test uncommitted workspace changes.

## Verify the runtime

Run these commands after any installation or upgrade:

```bash
mn --help
mn runtime start
mn runtime health
mn runtime status
mn node list
```

Verification criteria:

- `mn --help` displays the command groups.
- `mn runtime health` reports the Core, REST API, and Web UI health checks without a failed required component.
- `mn runtime status` reports the resolved endpoints, runtime state, nodes, jobs, and shared storage.
- `mn node list` returns the local runtime-node view or the configured cluster view.

If a command fails, collect its output and continue with [Troubleshooting](troubleshooting.md) rather than deleting local state.

## Local state, ports, and configuration

| Item | Default | Owner |
| --- | --- | --- |
| Runtime state root | `~/.mn` | CLI, API, SDK, runtime services. |
| REST API | `http://localhost:54001/api/v1` | `mn-api`; override with `MN_API_PORT`. |
| Core gRPC endpoint | `localhost:55051` | MirrorNeuron Core; override with `MN_GRPC_PORT` and client target settings. |
| Docker Model Runner/LiteLLM gateway | port `4000` when enabled | Model runtime. |
| Web UI | port `55173` by default | Web UI runtime. |
| Blueprint run records | `~/.mn/runs/<run_id>/` | Blueprint run-store contract. |

See [Environment Variables](env_variables.md) for the full configuration reference. Do not publish `~/.mn/docker-compose.env`, tokens, or generated endpoint files because they can contain deployment-specific configuration.

## Prepare a local model only when a blueprint requires it

Blueprint validation identifies declared model requirements. Install and diagnose a local model only after a preflight reports it or after you have reviewed the blueprint configuration:

```bash
mn model list
mn model install gemma4:e2b
mn model doctor gemma4:e2b
```

`mn model install` can fail on an incompatible machine. Do not use `--force` as a routine fix; first choose a model and blueprint profile that match the available hardware.

## Stop, uninstall, and retain evidence

Stop runtime services:

```bash
mn runtime stop
```

For a hosted installation, use the matching uninstall script:

```bash
curl -fsSL https://mirrorneuron.io/uninstall.sh | bash
```

Before removing `~/.mn`, preserve any required run records, logs, configuration, and model metadata. Removing it can discard local state needed to diagnose jobs or reproduce a deployment.

## Contributor verification

When changing installer, runtime-start, endpoint, or configuration behavior, verify at least:

```bash
cd mn-deploy
./install.sh --help
```

Then run the relevant CLI/API tests and the documentation-site type check. Update `mn-doc-site/content/docs/installation.mdx` with the concise user-facing impact.

## Related pages

- [Quickstart](quickstart.md)
- [Environment Variables](env_variables.md)
- [Model Runtime](model-runtime.md)
- [Services and Health Checks](services-and-health-checks.md)
- [Troubleshooting](troubleshooting.md)
