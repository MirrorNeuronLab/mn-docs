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
- Python 3.10+
- Elixir/Erlang
- Docker
- the `mn` CLI on your PATH

If those are not ready yet, follow [Installation](installation.md) first.

## Step 1: Validate A Bundle

From the workspace root:

```bash
mn blueprint validate mn-blueprints/message_routing_trace
```

Expected output:

```text
Job bundle at 'mn-blueprints/message_routing_trace' is valid.
```

This checks the local manifest and input contract without submitting a runtime job.

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
mn runtime start
```

Expected output:

```text
MirrorNeuron services started
```

If your local command prints a different success line, verify with:

```bash
mn node list
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
mn blueprint run message_routing_trace
```

Expected output:

```text
Job submitted successfully
```

The CLI may also print live events and the job id. Keep the job id for inspection commands.

## Step 5: Inspect Jobs

```bash
mn job list
```

Expected output:

```text
Job ID
```

Check a single job:

```bash
mn job status <job_id>
```

Expected output includes:

```json
{
  "status": "completed"
}
```

If the job is still running, wait a moment and run `mn job status <job_id>` again.

## Step 6: Try A Python-Defined Blueprint

Run the checked-in Python SDK research pipeline:

```bash
mn blueprint run python_sdk_research_pipeline
```

Expected output:

```text
Job submitted successfully
```

For Python bundle-generation details, see [Python SDK](SDK.md).

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
mn runtime start
mn node list
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
