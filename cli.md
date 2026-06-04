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
mn blueprint validate <bundle_path>
mn blueprint run <blueprint_id> [--follow-seconds <seconds>]
mn blueprint run --folder <bundle_path> [--follow-seconds <seconds>]
mn job monitor <job_id>
mn job result <job_id>
mn job submit <manifest.json>
mn job status <job_id>
mn job list
mn job clear
mn job cancel [job_id]
mn job pause <job_id>
mn job resume <job_id>
mn job backup <job_id_or_run_id_or_blueprint_id> --output <folder>
mn job restore <blueprint_id> --input <backup.zip>
mn node list
mn node reconcile <node_name> [--reason <text>] [--dry-run]
mn node drain <node_name> [--reason <text>] [--deadline 30m] [--dry-run] [--wait]
mn node undrain <node_name> [--reason <text>] [--mark-eligible]
mn node maintenance <node_name> --enable|--disable [--reason <text>]
mn resource list
mn resource set [--cpu 75] [--gpu 100] [--memory 75] [--disk 75]
mn service list
mn service resolve <name>
mn service check <bundle_path>
mn model list [--installed] [--json]
mn model show [MODEL] [--compatibility] [--json]
mn model install [MODEL] [--backend auto|llama.cpp|vllm] [--context-size N] [--force]
mn model update [MODEL|--all] [--force]
mn model remove <MODEL> [--force]
mn model doctor [MODEL] [--json]
mn deployment deploy <bundle_path> --key <deployment_key>
mn deployment list|status|promote|rollback|pause|resume|fail
mn schedule create <bundle_path> --cron "0 2 * * *"
mn schedule delay <bundle_path> --in 30m
mn schedule list|status|pause|resume|delete|run-now
mn trigger create <bundle_path> --event <event_type>
mn trigger list|delete
mn event emit <event_type>
mn event list
mn runtime metrics
mn job dead-letters <job_id>
mn runtime start
mn runtime stop
mn node join <main-host> --token <token>
mn node expose
mn node add <host> --token <token>
mn node leave <node_name>
mn blueprint list
mn blueprint run <blueprint_id>
```

Cluster helper scripts in `MirrorNeuron/scripts/` provide lower-level node start, join, Redis HA, and failover smoke-test flows. See [Cluster Guide](cluster.md) and [Redis High Availability](redis-ha.md).

## `mn blueprint validate`

Validates a local job bundle.

```bash
mn blueprint validate ./bundle
```

Expected output:

```text
Job bundle at './bundle' is valid.
```

Use this before running any bundle from another person or repository.

## `mn blueprint run`

Runs a catalog blueprint by ID, or a local bundle/source folder when `--folder`
is provided.

```bash
mn blueprint run message_routing_trace
mn blueprint run --folder ./bundle
```

Expected output:

```text
Job submitted successfully
```

Limit how long the CLI follows post-submit events:

```bash
mn blueprint run message_routing_trace --follow-seconds 10
```

Environment controls:

| Variable | Default | Description |
| --- | --- | --- |
| `MN_RUN_DETACH_LOG_SECONDS` | `30` | Default follow duration after submit. |
| `MN_RUN_LOG_LEVEL` | `INFO` | Per-run log level. |
| `MN_RUN_LOG_MAX_BYTES` | `2097152` | Run log rotation size. |
| `MN_RUN_EVENT_LOG_MAX_BYTES` | `10485760` | Event log rotation size. |

Run artifacts are written to `/tmp/mn_<job_id>/`.

## `mn job submit`

Submits a raw manifest JSON file.

```bash
mn job submit /path/to/manifest.json
```

Expected output:

```text
Job submitted successfully. Job ID: <job_id>
```

Use `mn blueprint run --folder <bundle_path>` for normal bundle execution because it also packages payloads.

## `mn job status`

Gets one job record.

```bash
mn job status <job_id>
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

## `mn job list`

Lists jobs.

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

## `mn job monitor`

Streams events for one job.

```bash
mn job monitor <job_id>
```

Use this when a job is running and you want live event output.

## `mn job result`

Fetches final and progressive result artifacts for a job.

```bash
mn job result <job_id>
```

Expected output depends on the bundle. Look for saved result paths or JSON result output.

## `mn job cancel`

Cancels a running job.

```bash
mn job cancel <job_id>
```

Expected output:

```text
Job cancelled. Status: cancelled
```

If no `job_id` is provided, the CLI may show an interactive cancel flow.

## `mn job pause` And `mn job resume`

Pause a running job:

```bash
mn job pause <job_id>
```

Expected output:

```text
Job paused
```

Resume it:

```bash
mn job resume <job_id>
```

Expected output:

```text
Job resumed
```

## `mn job backup` And `mn job restore`

Back up a paused job:

```bash
mn job backup <job_id_or_run_id_or_blueprint_id> --output ./backups
```

Restore it as a fresh paused clone:

```bash
mn job restore <blueprint_id> --input ./backups/<backup>.zip
```

Backup resolution accepts an exact job ID, an exact blueprint run ID from
`MN_RUNS_ROOT` or `~/.mn/runs`, or a blueprint ID when exactly one paused run is
active for that blueprint. Ambiguous blueprint IDs fail and print candidate job
and run IDs.

Backups use the `mn.backup.v1` zip schema and include raw runtime job state,
agent snapshots, event history, `bundle/manifest.json`, `bundle/payloads/**`,
checksums, and local `run_store/**` files when available. The archive is a
complete runtime clone and may contain secrets from manifests, config,
environment values, runtime state, or payloads. Nothing is redacted.

Restore always creates a new job ID and run ID for the target blueprint. The
original job/run IDs are kept in restore provenance, stale leases and node
ownership are discarded, and the restored job is left paused for inspection
before `mn job resume <new_job_id>`.

## `mn node list`

Shows system summary and runtime nodes.

```bash
mn node list
```

Expected output includes:

```json
{
  "nodes": [],
  "jobs": []
}
```

In a real cluster, `nodes` contains node names, connected peers, and executor pool stats.

## `mn node reconcile`

Runs the same reconciler used after node-loss recovery and leader orphan sweeps.

```bash
mn node reconcile mirror_neuron@192.168.4.20 --reason "manual check" --dry-run
```

Use `--dry-run` first to see checked, recovered, paused, blocked, skipped, and failed counts.

## `mn node drain`, `mn node undrain`, And `mn node maintenance`

Maintenance mode stops new placements without moving current work:

```bash
mn node maintenance mirror_neuron@192.168.4.20 --enable --reason "driver update"
mn node maintenance mirror_neuron@192.168.4.20 --disable --reason "ready"
```

Drain mode stops new placements, moves safe service work, lets batch work finish before the deadline, and leaves the node in maintenance until undrained:

```bash
mn node drain mirror_neuron@192.168.4.20 --reason "reboot" --deadline 30m --dry-run
mn node drain mirror_neuron@192.168.4.20 --reason "reboot" --deadline 30m --wait
mn node undrain mirror_neuron@192.168.4.20 --mark-eligible --reason "ready"
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

## `mn model`

Manage local Docker Model Runner models:

```bash
mn model list
mn model show gemma4:e2b --compatibility
mn model install gemma4:e2b
mn model update gemma4:e2b
mn model doctor gemma4:e2b
mn model remove gemma4:e2b
```

The default model is `gemma4:e2b`, which resolves to Docker's `ai/gemma4:E2B` model. Installs block incompatible hardware unless `--force` is passed.

See [Model Runtime](model-runtime.md).

## `mn deployment deploy` And `mn deployment`

Deploy a bundle under a stable deployment key:

```bash
mn deployment deploy /path/to/bundle --key agent-api --strategy rolling --max-parallel 1
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

## `mn runtime metrics`

Shows runtime metrics derived from the core system summary.

```bash
mn runtime metrics
```

Use it for a quick view of active jobs, nodes, and pressure signals.

## `mn job dead-letters`

Lists dead-letter events for a job.

```bash
mn job dead-letters <job_id>
```

Use this when messages could not be routed or processed.

## `mn job clear`

Removes non-running job records.

```bash
mn job clear
```

Warning: cleanup affects persisted Redis job records. Use a test namespace when experimenting.

## `mn runtime start` And `mn runtime stop`

Starts and stops local MirrorNeuron services.

```bash
mn runtime start
mn runtime stop
```

Expected output:

```text
MirrorNeuron services started
MirrorNeuron services stopped
```

## Cluster Node Flows

MirrorNeuron supports two cluster flows.

Use `mn runtime start` on the main box. It starts the regular runtime, exposes the core
gRPC and cluster ports, and prints a stable token persisted at `~/.mn/network.token`.
A second box can join that main runtime with:

```bash
mn node join 192.168.4.10 --token <token>
```

For the inverse flow, expose a core-only node on the second box:

```bash
mn node expose --host 192.168.4.20
```

Then add that node from the main box:

```bash
mn node add 192.168.4.20 --token <token>
```

`mn node expose` starts only Core with gRPC, cluster ports, and secured Redis when
no external `MN_REDIS_URL` is configured. It does not start the REST API, Web UI,
OpenShell, context engine, or SDK-facing helper processes.

After joining or adding, use `mn node list` and `mn resource list` to see aggregate
CPU, GPU, memory, and disk across the cluster.

## `mn node leave`

Remove a node from the cluster:

```bash
mn node leave mirror_neuron@192.168.4.20
```
Leave by node name:

```bash
mn node leave mirror_neuron@192.168.4.173
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

## `mn blueprint run <blueprint_id>`

Runs a blueprint by name.

```bash
mn blueprint run message_routing_trace
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
| `MN_GRPC_TARGET` | `localhost:55051` | Core gRPC endpoint for the local deployed runtime. |
| `MN_GRPC_TIMEOUT_SECONDS` | `10` | Per-RPC timeout. |
| `MN_GRPC_AUTH_TOKEN` | unset | Optional bearer token metadata. |
| `MN_NETWORK_JOIN_TOKEN` | `~/.mn/network.token` for `mn runtime start` and `mn node expose` | Stable token used to derive cluster cookies and network-mode Redis secrets. |
| `MN_CLI_OUTPUT` | `rich` | Set to `plain` for less formatting. |

## Troubleshooting

### `StatusCode.UNAVAILABLE`

The CLI cannot reach the core gRPC server.

```bash
mn runtime start
mn node list
```

### Rich output breaks scripts

Use plain output:

```bash
MN_CLI_OUTPUT=plain mn job list
```

## Related Pages

- [Quickstart](quickstart.md)
- [API Reference](api.md)
- [Nomad-Inspired Runtime Features](nomad-inspired-runtime.md)
- [Environment Variables](env_variables.md)
- [Troubleshooting](troubleshooting.md)
