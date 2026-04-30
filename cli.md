# CLI Reference

The `mn` command is the primary user-facing CLI. It uses `mn-python-sdk` to talk to the MirrorNeuron core gRPC runtime.

Check your installed version:

```bash
mn --help
```

Expected output includes:

```text
MirrorNeuron CLI
```

## Command Summary

```bash
mn validate <bundle_path>
mn run <bundle_path> [--follow-seconds <seconds>]
mn monitor <job_id>
mn result <job_id>
mn submit <manifest.json>
mn status <job_id>
mn list
mn clear
mn cancel [job_id]
mn pause <job_id>
mn resume <job_id>
mn nodes
mn metrics
mn dead-letters <job_id>
mn start
mn stop
mn join <ip>
mn leave <node_name>
mn blueprint list
mn blueprint run <name>
```

Cluster helper scripts in `MirrorNeuron/scripts/` provide lower-level node start, join, Redis HA, and failover smoke-test flows. See [Cluster Guide](cluster.md) and [Redis High Availability](redis-ha.md).

## `mn validate`

Validates a local job bundle.

```bash
mn validate mn-blueprints/general_test_message_flow
```

Expected output:

```text
Job bundle at 'mn-blueprints/general_test_message_flow' is valid.
Graph ID: general_test_message_flow_v1
Nodes count: 3
```

Use this before running any bundle from another person or repository.

## `mn run`

Submits and follows a local bundle.

```bash
mn run mn-blueprints/general_test_message_flow
```

Expected output:

```text
Job submitted successfully
```

Limit how long the CLI follows post-submit events:

```bash
mn run mn-blueprints/general_test_message_flow --follow-seconds 10
```

Environment controls:

| Variable | Default | Description |
| --- | --- | --- |
| `MN_RUN_DETACH_LOG_SECONDS` | `30` | Default follow duration after submit. |
| `MN_RUN_LOG_LEVEL` | `INFO` | Per-run log level. |
| `MN_RUN_LOG_MAX_BYTES` | `2097152` | Run log rotation size. |
| `MN_RUN_EVENT_LOG_MAX_BYTES` | `10485760` | Event log rotation size. |

Run artifacts are written to `/tmp/mn_<job_id>/`.

## `mn submit`

Submits a raw manifest JSON file.

```bash
mn submit /path/to/manifest.json
```

Expected output:

```text
Job submitted successfully. Job ID: <job_id>
```

Use `mn run <bundle_path>` for normal bundle execution because it also packages payloads.

## `mn status`

Gets one job record.

```bash
mn status <job_id>
```

Expected output includes:

```json
{
  "status": "running"
}
```

Terminal states are:

- `completed`
- `failed`
- `cancelled`

## `mn list`

Lists jobs.

```bash
mn list
```

Expected output includes either:

```text
Job ID
```

or:

```text
No jobs found
```

## `mn monitor`

Streams events for one job.

```bash
mn monitor <job_id>
```

Use this when a job is running and you want live event output.

## `mn result`

Fetches final and progressive result artifacts for a job.

```bash
mn result <job_id>
```

Expected output depends on the bundle. Look for saved result paths or JSON result output.

## `mn cancel`

Cancels a running job.

```bash
mn cancel <job_id>
```

Expected output:

```text
Job cancelled. Status: cancelled
```

If no `job_id` is provided, the CLI may show an interactive cancel flow.

## `mn pause` And `mn resume`

Pause a running job:

```bash
mn pause <job_id>
```

Expected output:

```text
Job paused
```

Resume it:

```bash
mn resume <job_id>
```

Expected output:

```text
Job resumed
```

## `mn nodes`

Shows system summary and runtime nodes.

```bash
mn nodes
```

Expected output includes:

```json
{
  "nodes": [],
  "jobs": []
}
```

In a real cluster, `nodes` contains node names, connected peers, and executor pool stats.

## `mn metrics`

Shows runtime metrics derived from the core system summary.

```bash
mn metrics
```

Use it for a quick view of active jobs, nodes, and pressure signals.

## `mn dead-letters`

Lists dead-letter events for a job.

```bash
mn dead-letters <job_id>
```

Use this when messages could not be routed or processed.

## `mn clear`

Removes non-running job records.

```bash
mn clear
```

Warning: cleanup affects persisted Redis job records. Use a test namespace when experimenting.

## `mn start` And `mn stop`

Starts and stops local MirrorNeuron services.

```bash
mn start
mn stop
```

Expected output:

```text
MirrorNeuron services started
MirrorNeuron services stopped
```

## `mn join` And `mn leave`

Join a cluster by IP:

```bash
mn join 192.168.4.173
```

Leave by node name:

```bash
mn leave mirror_neuron@192.168.4.173
```

For controlled two-box startup, prefer the scripts in [Cluster Guide](cluster.md).

## `mn blueprint list`

Lists installed or discoverable blueprints.

```bash
mn blueprint list
```

Expected output includes:

```text
ID
Name
Job Name
```

## `mn blueprint run`

Runs a blueprint by name.

```bash
mn blueprint run general_python_defined_basic
```

Expected output:

```text
Job submitted successfully
```

Blueprint names and availability depend on your local blueprint index.

## Connectivity Environment

| Variable | Default | Description |
| --- | --- | --- |
| `MIRROR_NEURON_GRPC_TARGET` | `localhost:50051` | Core gRPC endpoint. |
| `MIRROR_NEURON_GRPC_TIMEOUT_SECONDS` | `10` | Per-RPC timeout. |
| `MIRROR_NEURON_GRPC_AUTH_TOKEN` | unset | Optional bearer token metadata. |
| `MIRROR_NEURON_CLI_OUTPUT` | `rich` | Set to `plain` for less formatting. |

## Troubleshooting

### `StatusCode.UNAVAILABLE`

The CLI cannot reach the core gRPC server.

```bash
mn start
mn nodes
```

### Rich output breaks scripts

Use plain output:

```bash
MIRROR_NEURON_CLI_OUTPUT=plain mn list
```

## Related Pages

- [Quickstart](quickstart.md)
- [API Reference](api.md)
- [Environment Variables](env_variables.md)
- [Troubleshooting](troubleshooting.md)
