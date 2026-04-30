# Validate And Run Your First Workflow

This tutorial gets you from a fresh checkout to one validated workflow and one submitted job.

## What You Will Do

By the end, you will have:

- validated a checked-in job bundle
- started Redis
- started the MirrorNeuron runtime
- submitted one workflow
- inspected job state

## Before You Start

You need:

- macOS, Linux, or WSL2
- Python 3.9+
- Elixir/Erlang
- Docker
- the `mn` CLI on your PATH

If those are not ready yet, follow [Installation](installation.md) first.

## Step 1: Validate A Bundle

From the monorepo root:

```bash
mn validate mn-blueprints/general_test_message_flow
```

Expected output:

```text
Job bundle at 'mn-blueprints/general_test_message_flow' is valid.
Job Name: test-message-flow
Graph ID: general_test_message_flow_v1
Nodes count: 3
```

This command does not require Redis or a running runtime. It checks bundle structure, `manifest.json`, nodes, edges, and entrypoints.

## Step 2: Start Redis

```bash
docker rm -f mirror-neuron-redis 2>/dev/null || true
docker run -d --name mirror-neuron-redis -p 6379:6379 redis:7
docker exec mirror-neuron-redis redis-cli ping
```

Expected output:

```text
PONG
```

## Step 3: Start The Runtime

```bash
mn start
```

Expected output:

```text
MirrorNeuron services started
```

If your local command prints a different success line, verify with:

```bash
mn nodes
```

Expected output includes:

```json
{
  "nodes": []
}
```

or a non-empty `nodes` list when the core runtime is reachable.

## Step 4: Run The Workflow

```bash
mn run mn-blueprints/general_test_message_flow
```

Expected output:

```text
Job submitted successfully
```

The CLI may also print live events and the job id. Keep the job id for inspection commands.

## Step 5: Inspect Jobs

```bash
mn list
```

Expected output:

```text
Job ID
```

Check a single job:

```bash
mn status <job_id>
```

Expected output includes:

```json
{
  "status": "completed"
}
```

If the job is still running, wait a moment and run `mn status <job_id>` again.

## Step 6: Try A Python-Defined Blueprint

Generate a bundle from pure Python workflow code:

```bash
python3 mn-blueprints/general_python_defined_basic/generate_bundle.py \
  --quick-test \
  --output-dir /tmp/mn-python-basic
```

Expected output:

```text
bundle generated
```

Validate and run it:

```bash
mn validate /tmp/mn-python-basic
mn run /tmp/mn-python-basic
```

Expected output:

```text
Job submitted successfully
```

## Security Basics

Before running bigger or third-party workflows:

- Review `manifest.json` and `payloads/`.
- Check whether a node uses `host_local` or OpenShell.
- Check `pass_env` before secrets are exposed to workers.
- Use dry-run options for email, Slack, or other external delivery flows.
- Treat live messages and model outputs as untrusted input.

Read [Security Model](security.md) before exposing a runtime to other users or machines.

## Troubleshooting

### `mn: command not found`

Install the CLI or activate the project virtual environment. Then verify:

```bash
which mn
mn --help
```

### gRPC connection refused

The runtime is not reachable.

```bash
mn start
mn nodes
```

### Redis connection errors

Check:

```bash
docker exec mirror-neuron-redis redis-cli ping
```

Expected output:

```text
PONG
```

## Next Steps

- [CLI Reference](cli.md)
- [Blueprints and Skills](blueprints-and-skills.md)
- [Examples](examples.md)
- [Troubleshooting](troubleshooting.md)
