# Monitor and Control a Job

Use this guide after a workflow has been submitted and you have its job ID. It explains how to observe runtime state, inspect run artifacts, cancel work safely, and collect evidence for troubleshooting.

## Before you begin

- Know the `<job_id>` returned by `mn blueprint run` or another job-submission path.
- Keep the corresponding `<run_id>` if the launch created one; the run ID identifies blueprint run-store records.
- Use `mn runtime health` first if every job command fails to reach the runtime.

## Inspect a job

List recent jobs when you do not know the ID:

```bash
mn job list
```

Read the current job state:

```bash
mn job status <job_id>
```

Stream job events while the workflow runs:

```bash
mn job monitor <job_id>
```

Replace `<job_id>` with the submitted job identifier. A terminal job state is `completed`, `failed`, or `cancelled`. A terminal state proves that runtime execution reached an end state; inspect artifacts and warnings before treating a domain result as correct.

## Inspect blueprint artifacts

When you have a run ID, inspect its run-store records separately from job state:

```bash
mn blueprint logs <run_id>
mn blueprint tail <run_id>
mn blueprint export <run_id> --format markdown
```

By default, blueprint run records are stored under `~/.mn/runs/<run_id>/`. Preserve `events.jsonl`, logs, result artifacts, and timestamps when reporting a failure.

## Cancel work

Cancel a running job when it should not continue:

```bash
mn job cancel <job_id>
```

Verify the terminal state with:

```bash
mn job status <job_id>
```

Warning: cancellation stops runtime work but cannot automatically reverse an external action that a worker has already performed. Review the blueprint's output skills, adapters, and idempotency behavior before launching side-effecting workflows.

## Diagnose a stuck or failed job

Collect read-only evidence first:

```bash
mn runtime health
mn runtime status
mn node list
mn job status <job_id>
mn job dead-letters <job_id>
```

Use [Troubleshooting](troubleshooting.md) for Redis, OpenShell, model, API, and cluster-specific diagnosis. Include the job ID, run ID, timestamp, exact error text, and sanitized relevant configuration when escalating an issue.

## Related pages

- [CLI Reference](cli.md)
- [API Reference](api.md)
- [Reliability Guide](reliability.md)
- [Troubleshooting](troubleshooting.md)
