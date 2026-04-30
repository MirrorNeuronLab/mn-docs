# Install MirrorNeuron Locally

This guide installs the dependencies needed to validate bundles, run local workflows, and execute the test suite.

## Requirements

- macOS, Linux, or WSL2
- `git`
- Python 3.9+
- Elixir and Erlang
- Docker
- Redis, usually through Docker for local development
- OpenShell for sandboxed worker execution

Optional:

- model provider keys for LLM blueprints
- two machines with SSH access for cluster and Redis HA smoke tests

## Option 1: Install With The Deployment Script

Use the deployment script when you want a system-wide `mn` command.

```bash
curl -fsSL https://mirrorneuron.io/install.sh | bash
```

Expected result:

```text
mn installed
```

Verify:

```bash
mn --help
```

Expected output includes:

```text
MirrorNeuron CLI
```

## Option 2: Set Up From The Monorepo

From the monorepo root:

```bash
python3 -m venv .venv
. .venv/bin/activate
python3 -m pip install -r mn-system-tests/requirements.txt
```

Expected result:

```text
Successfully installed
```

The system-test requirements install the local Python SDK and CLI in editable mode.

## Step 1: Install Elixir And Erlang

On macOS with Homebrew:

```bash
brew install elixir
elixir --version
mix --version
```

Expected output includes:

```text
Elixir
Mix
```

On Linux, use your package manager or `asdf` and verify with the same commands.

## Step 2: Fetch Core Dependencies

```bash
cd MirrorNeuron
mix deps.get
mix compile
```

Expected output:

```text
Generated mirror_neuron app
```

If dependencies are already compiled, Mix may print less output. A zero exit code is the success signal.

## Step 3: Start Redis

The simplest local Redis path is Docker:

```bash
docker rm -f mirror-neuron-redis 2>/dev/null || true
docker run -d --name mirror-neuron-redis -p 6379:6379 redis:7
docker exec mirror-neuron-redis redis-cli ping
```

Expected output:

```text
PONG
```

## Step 4: Install OpenShell

```bash
curl -LsSf https://raw.githubusercontent.com/NVIDIA/OpenShell/main/install.sh | sh
~/.local/bin/openshell --version
```

Expected output includes:

```text
openshell
```

If `openshell` is not on your `PATH`:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

Or point MirrorNeuron directly to the binary:

```bash
export MIRROR_NEURON_OPENSHELL_BIN="$HOME/.local/bin/openshell"
```

## Step 5: Start The OpenShell Gateway

```bash
openshell gateway start
openshell status
```

Expected output includes:

```text
Status: Connected
```

If OpenShell is not needed for your first pure-router workflow, you can skip this until you run executor blueprints.

## Step 6: Configure Local Environment

Recommended local defaults:

```bash
export MIRROR_NEURON_REDIS_URL="redis://127.0.0.1:6379/0"
export MIRROR_NEURON_EXECUTOR_MAX_CONCURRENCY="4"
export MIRROR_NEURON_COOKIE="mirrorneuron"
```

Optional for LLM-enabled blueprints:

```bash
export LITELLM_MODEL="gemini/gemini-2.5-flash-lite"
export LITELLM_API_KEY="..."
```

Use a unique Redis namespace when running tests beside a developer runtime:

```bash
export MIRROR_NEURON_REDIS_NAMESPACE="mirror_neuron_dev_$(date +%s)"
```

## Step 7: Smoke Test

From the monorepo root:

```bash
mn validate mn-blueprints/general_test_message_flow
```

Expected output:

```text
Job bundle at 'mn-blueprints/general_test_message_flow' is valid.
```

Start services:

```bash
mn start
mn run mn-blueprints/general_test_message_flow
```

Expected output:

```text
Job submitted successfully
```

## Uninstall Local Services

Stop MirrorNeuron:

```bash
mn stop
```

Stop local Redis:

```bash
docker rm -f mirror-neuron-redis
```

If installed through the deployment script, remove the install directory and executable:

```bash
rm -rf ~/.local/share/MirrorNeuron
rm -f ~/.local/bin/mn
```

Warning: only remove these paths if they belong to the MirrorNeuron install you want to delete.

## Security Notes

- Keep local Redis bound to trusted interfaces.
- Change `MIRROR_NEURON_COOKIE` before using a real cluster.
- Do not expose API or gRPC ports publicly without an authentication boundary.
- Review third-party bundles before running them.

## Cluster Prerequisites

For two-box or larger clusters, continue with:

- [Cluster Guide](cluster.md)
- [Redis High Availability](redis-ha.md)

## Common Install Issues

If setup does not work as expected:

- [Troubleshooting](troubleshooting.md)
- [Testing](testing.md)
