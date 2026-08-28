# CLI Reference

`mn` is the operator interface for MirrorNeuron blueprints, runs, models, and
runtime services. The CLI uses resource-oriented nouns and a small common verb
set:

- `list` shows a collection.
- `show` returns stored facts about one resource without active probes.
- `status` summarizes live runtime state.
- `doctor` runs deep diagnostics and supplies fixes.
- `validate` checks static input without mutation.
- `add`, `update`, and `remove` manage registered resources.
- `create` and `delete` create or irreversibly delete durable data.

## Command tree

<!-- BEGIN GENERATED MN COMMAND TREE -->
```text
blueprint  list add show update remove run validate doctor cleanup export
job        list create show start archive reset-data delete
run        list show watch logs result resources compare pause resume cancel delete
run human  list respond ack
model      list add show update remove doctor
runtime    start stop status doctor cleanup restart-sidecars ensure-context-engine update
node       list show add remove reconcile drain undrain maintenance refresh-token
operation  show watch
resource   show usage set
service    list show
```
<!-- END GENERATED MN COMMAND TREE -->

Every leaf command accepts `--json`. `--debug` is the single root diagnostic
flag; the former root `--verbose` option is not supported.

## Common output

Default output is concise terminal text. Results go to stdout. Progress,
warnings, and errors go to stderr. `MN_CLI_OUTPUT=plain` removes decoration but
does not change the information returned; `NO_COLOR=1` removes color only.

One-shot `--json` output uses this envelope:

```json
{
  "schema": "mn.cli/v1",
  "ok": true,
  "data": {},
  "warnings": [],
  "meta": {
    "command": "mn node show",
    "timestamp": "2026-08-14T00:00:00Z",
    "duration_ms": 0
  }
}
```

Failures use the same stdout envelope with `ok: false` and an
`error: {code, message, hint, details}` object. `watch` and followed commands
emit newline-delimited `mn.cli.stream/v1` records. Secrets and internal
diagnostics are redacted.

Exit codes are `0` for success, `1` for an operational or critical diagnostic
failure, `2` for usage/validation/not-found/confirmation errors, `13` for
authorization failures, and `130` for interruption. Intentionally detaching
from a watcher is not an error.

Destructive commands use these flags consistently:

- `--yes` answers a confirmation and does nothing else.
- `--force` overrides only the precondition described by that command.
- `--dry-run` previews the action without mutation.

JSON and other non-interactive destructive operations require `--yes` unless
`--dry-run` is used.

## Blueprints

```bash
mn blueprint list
mn blueprint show <blueprint-id>
mn blueprint add <blueprint-id>
mn blueprint update <blueprint-id>
mn blueprint update --all
mn blueprint remove <blueprint-id> --yes
mn blueprint validate ./path/to/blueprint
mn blueprint doctor ./path/to/blueprint
mn blueprint run ./path/to/blueprint
mn blueprint run <catalog-id>
mn blueprint cleanup --dry-run
```

Local `run` and `doctor` targets must be explicit paths such as `./folder`,
`../folder`, or an absolute path. Other values are catalog IDs.

Report generation remains a blueprint operation even though it accepts a run
ID:

```bash
mn blueprint export <run-id> --format json --output report.json
mn blueprint export <run-id> --format markdown --output report.md
mn blueprint export <run-id> --format html --output report.html
```

`--format` controls report content, `--output` controls its destination, and
`--json` controls the CLI result envelope. There is no `mn run export`.

## Jobs and runs

A job is a durable definition. A run is one execution of that definition.

```bash
mn job list
mn job create ./bundle --job-id daily-review
mn job show daily-review
mn job start daily-review
mn job archive daily-review
mn job reset-data daily-review --yes
mn job delete daily-review --yes

mn run list
mn run list --job daily-review
mn run list --follow
mn run show <run-id>
mn run watch <run-id>
mn run logs <run-id> --channel logs
mn run logs <run-id> --channel events --follow
mn run logs <run-id> --channel all --follow
mn run result <run-id>
mn run resources <run-id>
mn run compare <run-a> <run-b>
mn run pause|resume|cancel <run-id>
mn run delete <run-id> --yes
```

`mn run result` resolves the runtime job internally and writes to
`$MN_HOME/outputs/<run-id>` unless `--output` is supplied.

Human collaboration is grouped under the run:

```bash
mn run human list <run-id> --pending
mn run human respond <run-id> <request-id> --decision approve
mn run human ack <run-id> <notice-id>
```

## Models

```bash
mn model list
mn model list --available
mn model add <catalog-id-or-dmr-reference>
mn model add <model> --node <node>
mn model add <model> --local
mn model add --file ./provider-models.json
mn model show <model-id>
mn model update <model-id>
mn model update --all
mn model remove <model-id> --yes
mn model doctor <model-id>
```

Use `--default` while adding exactly one DMR or provider model to make it the
highest-priority logical `default`:

```bash
mn model add hf.co/acme/chat:Q4_K_M --default
mn model add --file mn-docs/examples/muse-glimmer-gomokubench-config.json --default
```

The custom choice stays registered until removed and takes priority over the
hardware-selected Nemotron and Gemma built-ins. Those built-ins remain the
fallback chain. Adding a different model with `--default` changes the priority
without removing the former registration. A provider file used with
`--default` must contain exactly one model.

Provider files use the JSON shape shown in
[`examples/openai-compatible-model-proxy.json`](examples/openai-compatible-model-proxy.json)
and [`examples/muse-glimmer-gomokubench-config.json`](examples/muse-glimmer-gomokubench-config.json).
All entries and referenced environment variables are validated before registry
or gateway changes.

## Runtime, nodes, and resources

```bash
mn runtime start
mn runtime stop
mn runtime status
mn runtime doctor
mn runtime doctor --repair
mn runtime cleanup --dry-run
mn runtime cleanup --yes
mn runtime restart-sidecars
mn runtime ensure-context-engine
mn runtime update
```

`runtime status` includes endpoints, component health, nodes, active jobs, and
shared storage. `runtime doctor` adds coordination, Docker Model Runner,
gateway, storage, and foundation checks. Repair belongs only to `doctor`.

Every runtime is federation-capable and owns its own coordination store and
jobs. Start both nodes with the same command:

```bash
# On each node
mn runtime start

# On either already-running peer, use the command printed by the other node
mn node add <node-host> --token <join-token>
```

Successful startup prints the advertised host, gRPC endpoint, node identity,
active join token, and exact add-node command. The token grants federation
registration access: keep the terminal output private and rotate it with
`mn node refresh-token` when exposed. The removed `--worker` option exits with
code `2` and directs operators to `mn runtime start`.

The printed command uses the default gRPC port (`55051`) implicitly. If the
advertised gRPC endpoint uses another port, it includes `--grpc-port`.

```bash
mn node list
mn node show <node>
mn node remove <node> --yes
mn node reconcile <node>
mn node drain <node> --reason maintenance --wait
mn node undrain <node>
mn node maintenance <node> --enable
mn node refresh-token

mn resource show
mn resource usage
mn resource set --cpu 75 --memory 75
mn service list
mn service show <service-name>
```

Service readiness for a blueprint is diagnosed with `mn blueprint doctor`; a
separate service-check command is not exposed.

## Removed paths

Removed commands are not aliases and never execute. They return exit code `2`
with the exact replacement, including `runtime health`, `job inspect`,
`job runs`, `run status`, `run monitor`, `node join/expose/leave`,
`blueprint install/uninstall/monitor/tail/logs/stream`, `resource ports`,
`service check`, and the old schedule verbs. The `deployment`, `schedule`, and
`event` root command groups are not registered. To create a delayed or
resource-wait schedule from the CLI, use `mn blueprint run <target> --schedule
<delay-or-json>` or `--auto-schedule`.
