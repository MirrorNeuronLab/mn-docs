# Monitor A Job

Use `mn monitor` when you already have a job id and want to stream its events.

## Start Monitoring

```bash
mn monitor <job_id>
```

Expected output includes job events as they arrive.

If you do not know the job id:

```bash
mn list
```

Expected output includes:

```text
Job ID
```

## Fetch Results

```bash
mn result <job_id>
```

This fetches final and progressive results for a job when the bundle emits them.

## Inspect Status

```bash
mn status <job_id>
```

Expected output includes:

```json
{
  "status": "running"
}
```

Terminal statuses are:

- `completed`
- `failed`
- `cancelled`

## Cancel A Job

```bash
mn cancel <job_id>
```

Expected output:

```text
Job cancelled. Status: cancelled
```

## System Overview

For a broader view of nodes and jobs:

```bash
mn nodes
mn metrics
```

Expected `mn nodes` output includes:

```json
{
  "nodes": [],
  "jobs": []
}
```

In a cluster, `nodes` contains connected runtime nodes and executor pool stats.

## Operational Notes

- Closing your terminal does not necessarily cancel a submitted job.
- Use `mn cancel <job_id>` to stop daemon workflows.
- Use `mn dead-letters <job_id>` when messages fail to route or process.
- Run `mn clear` only when you are ready to remove terminal job records.

## Related Pages

- [CLI Reference](cli.md)
- [API Reference](api.md)
- [Troubleshooting](troubleshooting.md)
