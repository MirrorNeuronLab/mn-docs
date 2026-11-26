# Install MirrorNeuron Locally

## Current contract requirement

The current installer uses independently pinned components and `v2:` release fingerprints. It does not infer historical unified component tags or migrate old runtime state. Historical release snapshots remain immutable.

This guide covers installation of the application surface, the runtime node, or both. Use the [Runtime Architecture](runtime-architecture.md#application-surface-and-runtime-nodes) diagram to see how they connect.

## Reader and outcome

- **Reader:** operator or contributor choosing which MirrorNeuron components to install.
- **Outcome:** verify the selected installation role and connect a surface to a healthy runtime.
- **Page type:** installation how-to.
- **Maturity:** current checkout contract. Use the installer and its matching package pins together.
- **Sources of truth:** `mn-deploy/install.sh`, `mn-deploy/install_dev.sh`, `mn-deploy/uninstall.sh`, `mn_runtime.lifecycle`, and `mn_sdk.runtime_connection`.

## Installation modes

| Binary installer command      | Components                                                                    | Default home    |
| ----------------------------- | ----------------------------------------------------------------------------- | --------------- |
| `./install.sh`                | CLI/API surface and runtime. The surface attaches locally on first start.     | `~/.mn`         |
| `./install.sh --no-runtime`   | Wasm CLI, API and client support with Wasmtime.                               | `~/.mn`         |
| `./install.sh --runtime-only` | Core, native runtime, Redis, and selected execution services through Compose. | `~/.mn-runtime` |

The combined and runtime-only modes start their services by default. Use
`--no-start` to prepare either installation for later startup. Client mode
starts no services. The optional `mn-api` process can run in the foreground.
Runtime-only mode omits the application CLI, API, and Web UI. It can still
serve a blueprint's own UI through the runtime.

Use `MN_HOME` to choose a different home. Reinstall with the same role or use a
separate directory for a different role. The two role flags are mutually
exclusive. The developer installer supports `--no-runtime` for client-only
builds. Its default installs both parts.

## Before you begin

- Supported local environments are macOS, Linux, and Windows with WSL2.
- A combined or runtime-only install needs a running Docker engine and Docker Compose. The client installer skips Docker discovery and runtime setup.
- `git` is required for checkout-based installation.
- Python 3.12+ and Elixir/Erlang are required for editable workspace development, not for every released-package installation.
- Docker Model Runner is required only for blueprints that use local models. Docker Desktop provides it on macOS and Windows; Linux operators must install the plugin when they need that capability. NVIDIA DGX Spark and ARM64 Ubuntu operators should complete [Prepare Docker Model Runner on NVIDIA DGX Spark](docker-model-runner-arm64-nvidia.md) first.
- npm is not required to install or run the Web UI; its Node build runs inside
  the Docker Compose Web UI service.

## Install released components

Use the deployment repository for a reviewable installation path:

```bash
cd mn-deploy
./install.sh --help
./install.sh
```

The installer uses default selections without prompts unless `--interactive` is passed. Use `--version <release-tag>` to select the corresponding installer support snapshot and component pins.

The hosted installer downloads and executes a script immediately. Use the local checkout above if you need to inspect the script first.

```bash
curl -fsSL https://mirrorneuron.io/install.sh | bash
```

## Install the surface without Docker

From the workspace root, install the CLI and API and verify the client role.
The commands below use the default client home. If you set `MN_HOME`, source the
`env` file from that installation instead.

```bash
cd mn-deploy
./install.sh --no-runtime
./install.sh --no-runtime --detect-only
source "$HOME/.mn/env"
mn --help
```

Detection should report `install_role` as `client` and `installed` as `true`.
The client needs a reachable runtime with compatible capabilities to run
blueprints. Use a trusted network or secure tunnel to reach the runtime's gRPC
endpoint. For a runtime on another computer, verify its listener and advertised
address using the [Federation Guide](cluster.md#network-requirements). Get the
host and runtime control token from the runtime operator, and
keep the token private. Set `RUNTIME_NODE_HOST` to that hostname or IP address and
`RUNTIME_NODE_TOKEN` to the credential from the runtime's `runtime.token` file.
For a first connection, run:

```bash
mn node add "$RUNTIME_NODE_HOST" --token "$RUNTIME_NODE_TOKEN"
mn node list
```

`mn node list` should show the connected runtime. If its gRPC port differs from
`55051`, pass that port with `--grpc-port` when connecting. For a runtime already
installed on the same machine, `mn node add local --runtime-home "$HOME/.mn-runtime"`
reads that installation's credential directly.

If the saved client connection uses an API URL, reconnect with the runtime
hostname and control token. A failed reconnection leaves the previous profile
in place.

For local REST access, run `mn-api` in a shell using the client environment.
Authenticate to that process with the client home's `api.token`. CLI and API
share the saved runtime connection. See the [API Reference](api.md) for REST
requests and the [Federation Guide](cluster.md#start-and-join-two-nodes) for
adding peers.

## Install a runtime node

With Docker running, use the runtime-only mode from the workspace root. This
installs the execution stack and starts its services. The lifecycle command is
available in the runtime home.

```bash
cd mn-deploy
./install.sh --runtime-only
"$HOME/.mn-runtime/bin/mn-runtime" status --json
```

Check `install_role` for `runtime` and inspect the required component health.
With a custom `MN_HOME`, use its `bin/mn-runtime` path. If you installed with
`--no-start`, use the same executable with `start` before checking status.
Share the runtime's reachable Core endpoint and private runtime control token
with the surface operator. A successful installation that starts services can
print a ready-to-run `mn node add` command containing that token. Keep the
command and terminal transcript private.

## Install an editable workspace runtime

Install Rust with rustup, then run the developer installer from the deployment
checkout. It builds the sibling sources and prepares the WASI SDK needed to
compile SQLite for `mn-api` on macOS and Linux, including ARM64 Spark hosts.

```bash
cd mn-deploy
./install_dev.sh
```

Use `./install_dev.sh --no-runtime` to build only the clients. To prepare the
toolchain ahead of time, run `./scripts/preapare_dev.sh` from the same directory.

For an explicit Git-based installation, use:

```bash
cd mn-deploy
./install_dev.sh --mode github
```

Git mode uses component repositories rather than editable paths from this checkout. Do not use it when your goal is to test uncommitted workspace changes.

## Verify the runtime

After a combined installation or upgrade, use its shell environment and check
runtime health and the saved connection. If you installed with `--no-start`,
first run `mn runtime start`.

```bash
mn runtime status
mn node list
```

Verification criteria:

- `mn runtime status` reports component health, endpoints, runtime state, and shared storage. Resolve failed required components before launching work.
- `mn node list` shows the cluster reached through the saved connection. On a fresh combined installation, the local Core is the entry runtime.

If a command fails, collect its output and continue with [Troubleshooting](troubleshooting.md) rather than deleting local state.

## Local state, ports, and configuration

| Item                  | Default                                       | Owner                                                                                                                      |
| --------------------- | --------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| Installation root     | See [Installation modes](#installation-modes) | Override with `MN_HOME`.                                                                                                   |
| Surface connection    | `$MN_HOME/client.json`                        | Private profile shared by CLI and API.                                                                                     |
| REST API              | `http://localhost:54001/api/v1`               | `mn-api`; override with `MN_API_PORT`.                                                                                     |
| Core gRPC endpoint    | port `55051`                                  | Runtime control gateway and federation. Set the runtime port with `MN_GRPC_PORT` and use the matching port when attaching. |
| LiteLLM gateway       | port `4000` when enabled                      | Owner-first model gateway; restrict peer access to trusted LAN/VPN networks.                                               |
| Web UI                | port `55173` by default                       | Docker Compose service; local mode builds the mounted `mn-web-ui` source there.                                            |
| Blueprint run records | `$MN_HOME/runs/<run-id>/`                     | Run store on the owning runtime.                                                                                           |

See [Environment Variables](env_variables.md) for configuration and
[Runtime Architecture](runtime-architecture.md#application-surface-and-runtime-nodes)
for Redis and file storage. Keep `client.json`, token files, Compose environment
files, and generated endpoints private.

## Prepare a local model only when a blueprint requires it

Blueprint validation identifies declared model requirements. Install and diagnose a local model only after a preflight reports it or after you have reviewed the blueprint configuration:

```bash
mn model list
mn model add nano
mn model doctor nano
```

`mn model add` can fail when no compatible runtime node is available. Do not use `--force` as a routine fix; first choose a model and blueprint profile that match the available hardware.

## Stop, uninstall, and retain evidence

Stop a foreground client API with Ctrl+C. To stop a combined runtime, run
`mn runtime stop`. On a runtime-only installation, use `bin/mn-runtime stop`
from its installation home.

Back up any local data you need before removal. Uninstalling a client deletes its
saved connection, local credentials, and downloaded results. Removing a runtime
can discard state needed to diagnose or recover jobs.

From `mn-deploy`, run the command for your installation. Set `MN_HOME` to the
installation home if it differs from the role's default.

| Role         | Removal command                 |
| ------------ | ------------------------------- |
| Client       | `./uninstall.sh --no-runtime`   |
| Runtime-only | `./uninstall.sh --runtime-only` |
| Combined     | `./uninstall.sh`                |

For a hosted installation, the hosted uninstall script downloads and executes
code immediately. Review the matching script before running it.

```bash
curl -fsSL https://mirrorneuron.io/uninstall.sh | bash
```

## Contributor verification

When changing installer, runtime-start, endpoint, or configuration behavior, verify at least:

```bash
cd mn-deploy
./install.sh --help
```

Run the installer and package closure tests in
`mn-system-tests/tests/integration/installer` to check the role selections and
client installation with Docker and Redis unavailable. See [Testing](testing.md)
for the test environment.

## Related pages

- [Quickstart](quickstart.md)
- [Environment Variables](env_variables.md)
- [Model Runtime](model-runtime.md)
- [Prepare Docker Model Runner on NVIDIA DGX Spark](docker-model-runner-arm64-nvidia.md)
- [Services and Health Checks](services-and-health-checks.md)
- [Troubleshooting](troubleshooting.md)
