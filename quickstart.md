# Validate And Run Your First Workflow

This tutorial gets you from a fresh checkout to one validated workflow and one
submitted job using a checked-in OtterDesk blueprint.

## What You Will Do

By the end, you will have:

- validated a local blueprint bundle
- started the MirrorNeuron runtime
- submitted one workflow
- inspected job and run state

## Before You Start

You need:

- macOS, Linux, or WSL2
- Python 3.11+
- Docker
- the `mn` CLI on your `PATH`

Elixir/Erlang are needed only when developing the BEAM runtime directly. If the
CLI or local services are not ready yet, follow [Installation](installation.md).

## Step 1: Validate A Checked-In Blueprint

From the workspace root:

```bash
mn blueprint validate otterdesk-blueprints/tax_form_ocr_capture_assistant
```

Expected output includes:

```text
valid
```

This checks the manifest, service declarations, model requirements, and input
contract without submitting a runtime job.

## Step 2: Start The Runtime

```bash
mn runtime start
```

Expected output includes:

```text
MirrorNeuron services started
```

If your local command prints a different success line, verify with:

```bash
mn runtime health
mn node list
```

Expected output includes a healthy runtime and either an empty local node list
or one or more reachable runtime nodes.

## Step 3: Run The Workflow

```bash
mn blueprint run --folder otterdesk-blueprints/tax_form_ocr_capture_assistant
```

Expected output includes:

```text
Job submitted
```

The CLI may print live events, a job id, and a blueprint run id. Keep both ids
for inspection commands.

## Step 4: Inspect Jobs

```bash
mn job list
```

Expected output includes either:

```text
Job ID
```

or:

```text
No jobs found
```

Check a single job:

```bash
mn job status <job_id>
```

Expected output includes a `status` field such as `running`, `completed`,
`failed`, or `cancelled`.

## Step 5: Inspect Blueprint Runs

Show recent blueprint runs:

```bash
mn blueprint monitor
```

Inspect logs and events for one run:

```bash
mn blueprint tail <run_id>
mn blueprint logs <run_id>
mn blueprint export <run_id> --format markdown
```

Most run artifacts are written under:

```text
$MN_HOME/runs/<run_id>/
```

## Step 6: Try The Catalog Flow

List catalog blueprints:

```bash
mn blueprint list
```

Run a catalog blueprint by id:

```bash
mn blueprint run portfolio_risk_review_assistant
```

Use `--update` when you want to refresh the cached blueprint repository first:

```bash
mn blueprint run portfolio_risk_review_assistant --update
```

## Security Basics

Before running bigger or third-party workflows:

- Review `manifest.json` and `payloads/`.
- Check whether a node uses HostLocal, DockerWorker, or OpenShell.
- Check `pass_env` before secrets are exposed to workers.
- Use mock, sample, or dry-run settings before external email, Slack, browser, or delivery adapters.
- Treat live messages, browser data, and model outputs as untrusted input.

Read [Security Model](security.md) before exposing a runtime to other users or
machines.

## Troubleshooting

### `mn: command not found`

Install the CLI or activate the project virtual environment. Then verify:

```bash
which mn
mn --help
```

### Runtime connection refused

The runtime is not reachable.

```bash
mn runtime start
mn runtime health
mn node list
```

### Model requirement failures

Install or inspect the required Docker Model Runner model:

```bash
mn model list
mn model doctor gemma4:e2b
```

## Next Steps

- [CLI Reference](cli.md)
- [Blueprints and Skills](blueprints-and-skills.md)
- [Examples](examples.md)
- [Troubleshooting](troubleshooting.md)
