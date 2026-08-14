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

`run result` writes under `$MN_HOME/outputs/<run-id>` unless `--output` is
supplied. Preserve logs, events, artifacts, timestamps, and sanitized
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
mn run delete <terminal-run-id> --yes
```

Cancellation stops runtime work but cannot reverse an external action already
performed by a worker. Review side-effecting adapters and idempotency before
launch.

## Human collaboration

```bash
mn run human list <run-id> --pending
mn run human respond <run-id> <request-id> --decision approve
mn run human ack <run-id> <notice-id>
```

See [Troubleshooting](troubleshooting.md) for Redis, OpenShell, model, API, and
cluster-specific diagnostics.
