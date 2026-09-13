# Run Your First Local Workflow

For developers with the CLI installed and a reviewed local blueprint package. This tutorial covers preflight, launch, inspection, and cancellation; it does not install a particular catalog or promise a domain-correct result.

## Reader and outcome

- **Reader:** first-time developer or local operator.
- **Outcome:** launch one blueprint and inspect its public run ID, logs, and results.
- **Page type:** tutorial.
- **Maturity:** current checkout contract; availability in an installed release must be checked with `mn --version` and command help.
- **Sources of truth:** `mn-cli/mn_cli/main.py`, `libs/run_cmds/`, `libs/run_public.py`, and `libs/job_definition_cmds.py`.
- **Validation:** command help and focused CLI contract tests; executing a chosen blueprint additionally requires its inputs and runtime services.

## Before you begin

Complete [Installation](installation.md). Obtain a blueprint folder from a catalog or its author, and read its README, referenced execution/configuration documents, dependencies, and payloads. Use its documented sample inputs. Commands below run from the directory containing that folder; replace `./my-blueprint` with its actual relative or absolute path.

> Review worker code, mounted files, passed environment variables, model endpoints, and external actions before launch. Validation does not establish that a package is safe to execute.

## Step 1: Start and inspect the runtime

```bash
mn runtime start
mn runtime status
```

Resolve failed required components before submitting work. Use `mn runtime doctor` for deeper diagnostics. Startup prints a federation join credential; keep it private.

## Step 2: Validate and diagnose the blueprint

```bash
mn blueprint validate ./my-blueprint
mn blueprint doctor ./my-blueprint
```

Validation checks the local package and declared requirements. Doctor diagnoses launch prerequisites. Resolve reported models, services, inputs, or hardware requirements before continuing; see [Model Runtime](model-runtime.md) and [Troubleshooting](troubleshooting.md). There is no universal model requirement for all blueprints.

Local launch and doctor targets must begin with `./`, `../`, or `/`; other targets are interpreted as catalog IDs. Use [Examples](examples.md) to select a catalog entry.

## Step 3: Launch

```bash
mn blueprint run ./my-blueprint --detached
```

Record the returned `<job-id>` and `<run-id>`. The job is a durable definition; the run is this execution. Starting a run may prepare dependencies and runtime resources and execute the blueprint's external actions. `--detached` skips the live workflow UI; it does not cancel the execution.

## Step 4: Inspect the result

```bash
mn job show <job-id>
mn run show <run-id>
mn run watch <run-id>
mn run logs <run-id> --channel logs
mn run logs <run-id> --channel events
mn run result <run-id>
```

Ctrl+C detaches from the watcher. Inspect the terminal run state, warnings, artifacts, and any required human review before using the result. Completion means execution finished, not that its domain conclusions are correct.

`run result` downloads outputs into `$MN_HOME/outputs/<run-id>` by default. Blueprint run records live under `$MN_HOME/runs/<run-id>`, with `MN_HOME` defaulting to `~/.mn`. For pending human requests and report export, see [Monitor](monitor.md).

## Clean up

If the run is unfinished and should stop:

```bash
mn run cancel <run-id>
```

Cancellation cannot undo external actions already performed. Preserve diagnostic records and outputs. Stop local services when other runs no longer need them:

```bash
mn runtime stop
```

## Next steps

- [Examples](examples.md): select another blueprint.
- [CLI Reference](cli.md): create reusable jobs, start runs, and inspect output.
- [Blueprint Standard](blueprint-standard.md): author a package.
- [Security Model](security.md): review execution and data boundaries.
