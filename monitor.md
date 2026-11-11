# Monitor and Control a Run

Operational execution inspection belongs under `mn run`. Keep the run ID
returned by `mn blueprint run` or `mn job start`; the job ID identifies the
durable definition, while the run ID identifies one execution.

## Runtime and run state

Start with aggregate runtime health:

```bash
mn runtime status
```

Use deep diagnostics only when the aggregate status needs investigation:

```bash
mn runtime doctor
```

The Web UI dashboard reads the connected runtime's system summary. If it shows
a connection error, attach the CLI/API surface using
[Installation](installation.md#install-the-surface-without-docker) and retry
the dashboard request. Entry and peer labels refer to the runtime connection.

List and inspect executions:

```bash
mn run list
mn run list --job <job-id>
mn run show <run-id>
mn run watch <run-id>
```

Ctrl+C intentionally detaches from `watch`; it does not cancel the run.

## Logs, events, and results

```bash
mn run logs <run-id> --channel logs
mn run logs <run-id> --channel events
mn run logs <run-id> --channel all --follow
mn run resources <run-id>
mn run result <run-id>
```

`run result` downloads to the CLI installation's
`$MN_HOME/outputs/<run-id>` unless `--output` is supplied. Preserve logs,
events, artifacts, timestamps, and sanitized
configuration when reporting a failure.

Blueprint report generation stays under `blueprint`:

```bash
mn blueprint export <run-id> --format markdown --output report.md
```

## Control

```bash
mn run pause <run-id>
mn run resume <run-id>
mn run cancel <run-id>
```

Cancellation stops runtime work but cannot reverse an external action already
performed by a worker. Review side-effecting adapters and idempotency before
launch.

> Deleting a Run permanently removes its stored data. If it is active, deletion
> first cancels it. Preserve needed evidence before confirming. Use
> `mn run cancel` to stop work while retaining its history.

```bash
mn run delete <run-id> --dry-run
mn run delete <run-id> --yes
```

## Human collaboration

```bash
mn run human list <run-id> --pending
mn run human respond <run-id> <request-id> --decision approve
mn run human ack <run-id> <notice-id>
```

See [Troubleshooting](troubleshooting.md) for Redis, OpenShell, model, API, and
cluster-specific diagnostics.
