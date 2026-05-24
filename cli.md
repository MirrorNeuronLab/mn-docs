# CLI Reference

The `mn` command is the primary user-facing CLI. It uses `mn-python-sdk` to talk to the MirrorNeuron core gRPC runtime.

Check your installed version:

```bash
mn --version
```

Expected output includes:

```text
mn <version>
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
mn reconcile-node <node_name> [--reason <text>] [--dry-run]
mn drain-node <node_name> [--reason <text>] [--deadline 30m] [--dry-run] [--wait]
mn undrain-node <node_name> [--reason <text>] [--mark-eligible]
mn maintenance-node <node_name> --enable|--disable [--reason <text>]
mn resource list
mn resource set [--cpu 75] [--gpu 100] [--memory 75] [--disk 75]
mn service list
mn service resolve <name>
mn service check <bundle_path>
mn deploy <bundle_path> --key <deployment_key>
mn deployment list|status|promote|rollback|pause|resume|fail
mn schedule create <bundle_path> --cron "0 2 * * *"
mn schedule delay <bundle_path> --in 30m
mn schedule list|status|pause|resume|delete|run-now
mn trigger create <bundle_path> --event <event_type>
mn trigger list|delete
mn event emit <event_type>
mn event list
mn metrics
mn dead-letters <job_id>
mn start
mn stop
mn join <main-host> --token <token>
mn expose-node
mn add-node <host> --token <token>
mn leave <node_name>
mn blueprint list
mn blueprint run <name>
```

Cluster helper scripts in `MirrorNeuron/scripts/` provide lower-level node start, join, Redis HA, and failover smoke-test flows. See [Cluster Guide](cluster.md) and [Redis High Availability](redis-ha.md).

## `mn validate`

Validates a local job bundle.

```bash
mn blueprint run general_message_routing_trace
```

Expected output:

```text
Blueprint 'general_message_routing_trace' validated. Running...
Job submitted successfully
```

Use this before running any bundle from another person or repository.

## `mn run`

Submits and follows a local bundle.

```bash
mn blueprint run general_message_routing_trace
```

Expected output:

```text
Job submitted successfully
```

Limit how long the CLI follows post-submit events:

```bash
mn blueprint run general_message_routing_trace
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

## `mn reconcile-node`

Runs the same reconciler used after node-loss recovery and leader orphan sweeps.

```bash
mn reconcile-node mirror_neuron@192.168.4.20 --reason "manual check" --dry-run
```

Use `--dry-run` first to see checked, recovered, paused, blocked, skipped, and failed counts.

## `mn drain-node`, `mn undrain-node`, And `mn maintenance-node`

Maintenance mode stops new placements without moving current work:

```bash
mn maintenance-node mirror_neuron@192.168.4.20 --enable --reason "driver update"
mn maintenance-node mirror_neuron@192.168.4.20 --disable --reason "ready"
```

Drain mode stops new placements, moves safe service work, lets batch work finish before the deadline, and leaves the node in maintenance until undrained:

```bash
mn drain-node mirror_neuron@192.168.4.20 --reason "reboot" --deadline 30m --dry-run
mn drain-node mirror_neuron@192.168.4.20 --reason "reboot" --deadline 30m --wait
mn undrain-node mirror_neuron@192.168.4.20 --mark-eligible --reason "ready"
```

## `mn resource`

Inspect aggregate and per-node CPU, memory, disk, GPU, device, port, host-path, and runtime-driver information:

```bash
mn resource list
```

Set coarse resource limit percentages:

```bash
mn resource set --cpu 75 --memory 75 --gpu 100 --disk 75
```

See [Resources and Devices](resources-and-devices.md).

## `mn service`

Inspect the service registry and run required service checks:

```bash
mn service list
mn service list --all
mn service resolve ollama --tag llm
mn service check /path/to/bundle --output json
```

See [Services and Health Checks](services-and-health-checks.md).

## `mn deploy` And `mn deployment`

Deploy a bundle under a stable deployment key:

```bash
mn deploy /path/to/bundle --key agent-api --strategy rolling --max-parallel 1
```

Manage deployment status, canaries, and rollback:

```bash
mn deployment list
mn deployment status agent-api
mn deployment promote agent-api
mn deployment rollback agent-api --version 1 --reason "restore stable"
mn deployment pause agent-api --reason "hold"
mn deployment resume agent-api --reason "continue"
mn deployment fail agent-api --reason "candidate failed"
```

See [Deployments](deployments.md).

## `mn schedule`, `mn trigger`, And `mn event`

Create periodic and delayed schedules:

```bash
mn schedule create /path/to/bundle --cron "0 2 * * *" --timezone America/New_York
mn schedule delay /path/to/bundle --in 30m
```

Manage schedules:

```bash
mn schedule list
mn schedule status <schedule-id>
mn schedule pause <schedule-id> --reason "hold"
mn schedule resume <schedule-id> --reason "ready"
mn schedule run-now <schedule-id>
mn schedule delete <schedule-id> --reason "retired"
```

Create and emit generic event triggers:

```bash
mn trigger create /path/to/bundle --event file_uploaded --filter-json '{"path":{"prefix":"/datasets/"}}'
mn event emit file_uploaded --payload-json '{"path":"/datasets/eval.jsonl"}'
mn event list
```

See [Schedules and Events](schedules-and-events.md).

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

## Cluster Node Flows

MirrorNeuron supports two cluster flows.

Use `mn start` on the main box. It starts the regular runtime, exposes the core
gRPC and cluster ports, and prints a stable token persisted at `~/.mn/network.token`.
A second box can join that main runtime with:

```bash
mn join 192.168.4.10 --token <token>
```

For the inverse flow, expose a core-only node on the second box:

```bash
mn expose-node --host 192.168.4.20
```

Then add that node from the main box:

```bash
mn add-node 192.168.4.20 --token <token>
```

`mn expose-node` starts only Core with gRPC, cluster ports, and secured Redis when
no external `MN_REDIS_URL` is configured. It does not start the REST API, Web UI,
OpenShell, context engine, or SDK-facing helper processes.

After joining or adding, use `mn nodes` and `mn resource list` to see aggregate
CPU, GPU, memory, and disk across the cluster.

## `mn leave`

Remove a node from the cluster:

```bash
mn leave mirror_neuron@192.168.4.20
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

## `mn blueprint cleanup`

Removes blueprint-owned runtime resources that are no longer referenced by the local blueprint index.

```bash
mn blueprint cleanup
mn blueprint cleanup --blueprint-id business_facility_safety_video_guardian
mn blueprint cleanup --dry-run
mn blueprint cleanup --runs-root ~/.mn/runs --generated-bundles-dir ~/.mn/generated_blueprint_bundles --bundle-cache-dir /tmp/mirror_neuron/bundle_cache
```

The cleanup command removes cached blueprint Python virtualenvs, `~/.mn/runs/<run_id>` records, `~/.mn/generated_blueprint_bundles/<run_id>` bundles, local bundle-cache entries, stale incomplete setup directories, and Docker resources labelled with the deleted blueprint ID. Blueprint-owned Docker containers/images should use `mirrorneuron.blueprint_id=<blueprint_id>` or `com.mirrorneuron.blueprint_id=<blueprint_id>`. `mn blueprint update` runs this cleanup automatically for blueprints removed by a catalog update. Use `mn blueprint uninstall` to remove cached blueprint storage and its owned resources together.

Cleanup is explicit lifecycle housekeeping, not a background scheduler. Use `--dry-run` to inspect what would be reclaimed. Use `--no-files` or `--no-docker` when you only want part of the sweep.

## Connectivity Environment

| Variable | Default | Description |
| --- | --- | --- |
| `MN_GRPC_TARGET` | `localhost:50051` | Core gRPC endpoint. |
| `MN_GRPC_TIMEOUT_SECONDS` | `10` | Per-RPC timeout. |
| `MN_GRPC_AUTH_TOKEN` | unset | Optional bearer token metadata. |
| `MN_NETWORK_JOIN_TOKEN` | `~/.mn/network.token` for `mn start` and `mn expose-node` | Stable token used to derive cluster cookies and network-mode Redis secrets. |
| `MN_CLI_OUTPUT` | `rich` | Set to `plain` for less formatting. |

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
MN_CLI_OUTPUT=plain mn list
```

## Related Pages

- [Quickstart](quickstart.md)
- [API Reference](api.md)
- [Nomad-Inspired Runtime Features](nomad-inspired-runtime.md)
- [Environment Variables](env_variables.md)
- [Troubleshooting](troubleshooting.md)
