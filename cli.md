# CLI Reference

The `mn` command is the primary user-facing CLI. It uses `mn-python-sdk` to talk
to the MirrorNeuron core gRPC runtime and uses local deployment metadata for
runtime start, health, and sidecar control.

Check your installed version:

```bash
mn --version
```

Expected output includes:

```text
MirrorNeuron CLI
version
```

## Command Summary

```bash
mn blueprint install [blueprint_id]
mn blueprint list
mn blueprint validate <bundle_path>
mn blueprint run <blueprint_id> [--follow-seconds <seconds>]
mn blueprint run --folder <bundle_path> [--follow-seconds <seconds>]
mn blueprint update
mn blueprint cleanup [--blueprint-id <blueprint_id>] [--dry-run]
mn blueprint uninstall [blueprint_id]
mn blueprint monitor [--follow]
mn blueprint tail <run_id>
mn blueprint logs <run_id>
mn blueprint stream <run_id>
mn blueprint resources <run_id>
mn blueprint human <run_id> [--pending]
mn blueprint human respond <run_id> <request_id> --decision approve
mn blueprint human ack <run_id> <notice_id>
mn blueprint compare <run_id_a> <run_id_b>
mn blueprint export <run_id> --format json|markdown|html
mn job submit <manifest.json>
mn job status <job_id>
mn job list
mn job monitor <job_id>
mn job result <job_id>
mn job cancel [job_id]
mn job pause <job_id>
mn job resume <job_id>
mn job backup <job_id_or_run_id_or_blueprint_id> --output <folder>
mn job restore <blueprint_id> --input <backup.zip>
mn job dead-letters <job_id>
mn job clear
mn node list
mn node reconcile <node_name> [--reason <text>] [--dry-run]
mn node drain <node_name> [--reason <text>] [--deadline 30m] [--dry-run] [--wait]
mn node undrain <node_name> [--reason <text>] [--mark-eligible]
mn node maintenance <node_name> --enable|--disable [--reason <text>]
mn node join <worker-host> --token <worker-token>
mn node expose
mn node add <host> --token <token>
mn node leave <node_name>
mn node refresh-token
mn resource list
mn resource ports
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
mn model proxy --config <config.json> [--port 4000] [--host 127.0.0.1] [--no-start] [--replace]
mn deployment deploy <bundle_path> --key <deployment_key>
mn deployment list|status|promote|rollback|pause|resume|fail
mn schedule create <bundle_path> --cron "0 2 * * *"
mn schedule delay <bundle_path> --in 30m
mn schedule list|status|pause|resume|delete|run-now
mn trigger create <bundle_path> --event <event_type>
mn trigger list|delete
mn event emit <event_type>
mn event list
mn runtime start
mn runtime stop
mn runtime status
mn runtime health
mn runtime restart-sidecars --api|--web-ui
mn runtime update
mn runtime metrics
```

Cluster helper scripts in `MirrorNeuron/scripts/` provide lower-level node
start, join, Redis HA, and failover smoke-test flows. See [Cluster Guide](cluster.md)
and [Redis High Availability](redis-ha.md).

## Blueprint Commands

### `mn blueprint install`

Install the default blueprint library, or install one catalog blueprint and its
required runtime models:

```bash
mn blueprint install
mn blueprint install <blueprint_id>
```

Expected output includes the storage path and a next step such as:

```text
mn blueprint list
```

### `mn blueprint list`

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

### `mn blueprint validate`

Validates a local job bundle or blueprint folder.

```bash
mn blueprint validate otterdesk-blueprints/medical_deid_record_intake_assistant
```

Expected output includes:

```text
valid
```

Use this before running any bundle from another person or repository.

### `mn blueprint run`

Runs a catalog blueprint by ID, or a local bundle/source folder when `--folder`
is provided.

```bash
mn blueprint run <blueprint_id>
mn blueprint run --folder otterdesk-blueprints/medical_deid_record_intake_assistant
```

Expected output includes:

```text
Job submitted
```

Limit how long the CLI follows post-submit events:

```bash
mn blueprint run <blueprint_id> --follow-seconds 10
```

Run in detached mode:

```bash
mn blueprint run --folder otterdesk-blueprints/video_watch_assistant --detached
```

Start or register a blueprint Web UI when supported:

```bash
mn blueprint run --folder otterdesk-blueprints/video_watch_assistant --web-ui
```

Environment controls:

| Variable | Default | Description |
| --- | --- | --- |
| `MN_RUN_DETACH_LOG_SECONDS` | `30` | Default follow duration after submit. |
| `MN_RUN_LOG_LEVEL` | `INFO` | Per-run log level. |
| `MN_RUN_LOG_MAX_BYTES` | `2097152` | Run log rotation size. |
| `MN_RUN_EVENT_LOG_MAX_BYTES` | `10485760` | Event log rotation size. |

Blueprint run artifacts are written under `MN_RUNS_ROOT` or `$MN_HOME/runs`.
Transient job logs may also be written under `/tmp/mn_<job_id>/`.

### `mn blueprint update`, `cleanup`, And `uninstall`

Update cached blueprint storage:

```bash
mn blueprint update
```

Clean no-longer-referenced blueprint-owned runtime resources:

```bash
mn blueprint cleanup --dry-run
mn blueprint cleanup --blueprint-id <blueprint_id>
```

Remove cached blueprint storage or one blueprint:

```bash
mn blueprint uninstall --dry-run
mn blueprint uninstall <blueprint_id> --keep-resources
```

Cleanup can remove cached Python virtualenvs, `$MN_HOME/runs/<run_id>` records,
generated bundles, local bundle-cache entries, web UI processes, and Docker
resources labelled for removed blueprints. Use `--dry-run` first.

### Blueprint Observability

Show recent blueprint runs:

```bash
mn blueprint monitor
mn blueprint monitor --follow
```

Read run events and logs:

```bash
mn blueprint tail <run_id>
mn blueprint logs <run_id>
mn blueprint stream <run_id>
```

Inspect resource and token usage:

```bash
mn blueprint resources <run_id>
mn blueprint resources <run_id> --live
```

Handle human review events:

```bash
mn blueprint human <run_id>
mn blueprint human <run_id> --pending
mn blueprint human respond <run_id> <request_id> --decision approve --notes "Looks good"
mn blueprint human ack <run_id> <notice_id>
```

Compare and export runs:

```bash
mn blueprint compare <run_id_a> <run_id_b>
mn blueprint export <run_id> --format markdown
mn blueprint export <run_id> --format html
```

## Job Commands

### `mn job submit`

Submits a raw manifest JSON file.

```bash
mn job submit /path/to/manifest.json
```

Expected output includes:

```text
Job submitted
```

Use `mn blueprint run --folder <bundle_path>` for normal bundle execution
because it also packages payloads and prepares run metadata.

### `mn job status`

Gets one job record.

```bash
mn job status <job_id>
```

Expected output includes a `status` field such as `running`, `completed`,
`failed`, or `cancelled`.

### `mn job list`

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

### `mn job monitor`

Streams events for one job.

```bash
mn job monitor <job_id>
```

Use this when a job is running and you want live event output.

### `mn job result`

Fetches final and progressive result artifacts for a job.

```bash
mn job result <job_id>
```

Expected output depends on the bundle. Look for saved result paths or JSON
result output.

### `mn job cancel`, `pause`, And `resume`

```bash
mn job cancel <job_id>
mn job pause <job_id>
mn job resume <job_id>
```

If no `job_id` is provided to cancel, the CLI may show an interactive cancel
flow.

### `mn job backup` And `mn job restore`

Back up a paused job:

```bash
mn job backup <job_id_or_run_id_or_blueprint_id> --output ./backups
```

Restore it as a fresh paused clone:

```bash
mn job restore <blueprint_id> --input ./backups/<backup>.zip
```

Backups use the `mn.backup.v1` zip schema and include raw runtime job state,
agent snapshots, event history, `bundle/manifest.json`, `bundle/payloads/**`,
checksums, and local `run_store/**` files when available. The archive may
contain secrets. Nothing is redacted.

### `mn job dead-letters` And `mn job clear`

```bash
mn job dead-letters <job_id>
mn job clear
```

Use dead letters when messages could not be routed or processed.

Warning: `mn job clear` affects persisted Redis job records. Use a test
namespace when experimenting.

## Runtime And Node Commands

Start, stop, inspect, repair, and update local services:

```bash
mn runtime start
mn runtime health
mn runtime status
mn runtime restart-sidecars --api
mn runtime restart-sidecars --web-ui
mn runtime update
mn runtime stop
```

Show runtime metrics:

```bash
mn runtime metrics
```

Inspect nodes:

```bash
mn node list
```

Expected output includes node and job summaries. In a real cluster, `nodes`
contains node names, connected peers, and executor pool stats.

Run reconciler and lifecycle operations:

```bash
mn node reconcile mirror_neuron@<node-host> --reason "manual check" --dry-run
mn node maintenance mirror_neuron@<node-host> --enable --reason "driver update"
mn node drain mirror_neuron@<node-host> --reason "reboot" --deadline 30m --wait
mn node undrain mirror_neuron@<node-host> --mark-eligible --reason "ready"
```

### Cluster Node Flows

Use `mn runtime start` on the main box. It starts the regular local runtime and
prints a stable token persisted at `$MN_HOME/network.token`.

For the common worker flow, start the worker box first:

```bash
mn runtime start --worker-node
```

Copy the worker token, then connect it from the main box:

```bash
mn node join <worker-host> --token <worker-token> --network overlay --docker-network mirror-neuron-runtime
```

For multi-host Docker clusters, create an attachable overlay network first:

```bash
docker network create --driver overlay --attachable mirror-neuron-runtime
```

For the inverse flow, expose a core-only node on the second box:

```bash
mn node expose --host <worker-host> --network overlay --docker-network mirror-neuron-runtime
```

Then add that node from the main box:

```bash
mn node add <worker-host> --token <token> --network overlay --docker-network mirror-neuron-runtime
```

`mn node expose` starts only Core with host gRPC and Docker-internal Redis/Erlang
cluster traffic. It does not start the REST API, Web UI, OpenShell, context
engine, or SDK-facing helper processes.

When the second box must read files submitted on the main box, start it directly
as a joined runtime so Syncthing replication is configured before Docker creates
the Core container:

```bash
mn runtime start --join-host <main-host> --token <main-token> --host <worker-host>
```

`MN_SYNCTHING_ENABLED=auto` starts a Docker sidecar for shared-storage
replication. `MN_SYNCTHING_REQUIRED=1` fails startup/join if the sidecar or peer
configuration cannot be completed.

Remove a node from the cluster:

```bash
mn node leave mirror_neuron@<node-host>
```

Rotate the local join token:

```bash
mn node refresh-token
```

## Resources, Services, And Models

Inspect aggregate and per-node resources:

```bash
mn resource list
mn resource ports
mn resource set --cpu 75 --memory 75 --gpu 100 --disk 75
```

See [Resources and Devices](resources-and-devices.md).

Inspect the service registry and run required service checks:

```bash
mn service list
mn service list --all
mn service resolve ollama --tag llm
mn service check /path/to/bundle --output json
```

See [Services and Health Checks](services-and-health-checks.md).

Manage local Docker Model Runner models:

```bash
mn model list
mn model show gemma4:e2b --compatibility
mn model install gemma4:e2b
mn model update gemma4:e2b
mn model proxy --config mn-docs/examples/openai-compatible-model-proxy.json
mn model doctor gemma4:e2b
mn model remove gemma4:e2b
```

The default model is `gemma4:e2b`, which resolves to Docker's `ai/gemma4:E2B`
model. Installs block incompatible hardware unless `--force` is passed.

Use `mn model proxy` to register external OpenAI-compatible models through a LiteLLM proxy. Proxy models appear as installed in `mn model list --installed` with `backend` set to `proxy`, and blueprint validation skips local hardware checks for them.

See [Model Runtime](model-runtime.md).

## Deployments, Schedules, Triggers, And Events

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

## Connectivity Environment

| Variable | Default | Description |
| --- | --- | --- |
| `MN_GRPC_TARGET` | `localhost:55051` | Core gRPC endpoint for the local deployed runtime. |
| `MN_GRPC_TIMEOUT_SECONDS` | `10` | Per-RPC timeout. |
| `MN_GRPC_AUTH_TOKEN` | unset | Optional bearer token metadata. |
| `MN_NETWORK_JOIN_TOKEN` | `$MN_HOME/network.token` for `mn runtime start` and `mn node expose` | Stable token used to derive cluster cookies and network-mode Redis secrets. |
| `MN_CLI_OUTPUT` | `rich` | Set to `plain` for less formatting. |

## Troubleshooting

### `StatusCode.UNAVAILABLE`

The CLI cannot reach the core gRPC server.

```bash
mn runtime start
mn runtime health
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
