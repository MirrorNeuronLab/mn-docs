# Run Your First Local Workflow

This tutorial is the canonical first workflow path for contributors and local operators. It intentionally uses a checked-in medical de-identification blueprint only with its sample configuration: do not add private or regulated documents while learning the runtime.

## Reader and outcome

- **Reader:** first-time developer or operator with a local MirrorNeuron installation.
- **Outcome:** a model-backed blueprint has been preflighted, submitted, and inspected with its job ID and run ID.
- **Page type:** tutorial.
- **Sources of truth:** `mn-cli` command definitions, the `medical_deid_record_intake_assistant` manifest/configuration, and model validation behavior.

## What you will learn

- how runtime health differs from blueprint preflight;
- how local model requirements block submission until satisfied;
- how job inspection differs from run-store inspection; and
- how to stop a job and preserve diagnostic evidence.

## Before you begin

- Complete [Installation](installation.md).
- Start Docker and make Docker Model Runner available.
- Run commands from the workspace root.
- Keep the blueprint's checked-in sample configuration. Its outputs are review material and are not approval to release data.

## Step 1: Start and inspect the runtime

```bash
mn runtime start
mn runtime health
mn runtime status
```

Verification: `mn runtime health` must not report a failed required component. If it does, resolve that failure before changing blueprint configuration; use [Troubleshooting](troubleshooting.md) to collect diagnostics.

## Step 2: Install the model required by this tutorial

The selected blueprint resolves its default model requirement to `gemma4:e2b` during local validation. Install and diagnose that model:

```bash
mn model install gemma4:e2b
mn model doctor gemma4:e2b
```

Verification: `mn model doctor` must report a usable local model. If hardware compatibility fails, do not force the install. Choose a compatible model profile or a blueprint that fits the available machine.

## Step 3: Preflight the blueprint

```bash
mn blueprint validate otterdesk-blueprints/medical_deid_record_intake_assistant
```

This checks the bundle and declared requirements without creating a job. Treat any missing model, service, input, or schema error as a blocker. The expected success signal is a zero exit status with no validation errors.

## Step 4: Submit the workflow

```bash
mn blueprint run --folder otterdesk-blueprints/medical_deid_record_intake_assistant
```

Record the returned values:

- `<job_id>` identifies the runtime execution.
- `<run_id>` identifies the blueprint run store and local artifacts.

Never put actual IDs, paths, tokens, or customer data into documentation examples or issue reports.

## Step 5: Inspect runtime state and run artifacts

```bash
mn job status <job_id>
mn job monitor <job_id>
mn blueprint logs <run_id>
mn blueprint tail <run_id>
```

A terminal job state is `completed`, `failed`, or `cancelled`. A terminal state proves that the runtime reached an end state; it does not prove that a domain result is correct. Inspect `events.jsonl`, `result.json`, `final_artifact.json`, warnings, and required human-control records before using outputs.

## What happened

The CLI preflighted the folder, the runtime accepted a job, and the scheduler executed its declared agents. Runtime state is available through job commands and API routes. Blueprint-oriented output is written to `~/.mn/runs/<run_id>/` by default and is accessed through blueprint log/tail/export commands.

The blueprint manifest controls runners, model configuration, inputs, service requirements, environment access, and output contracts. The runtime does not infer a safe data classification or a safe external destination for you.

## Clean up

Cancel an unfinished job before stopping local services:

```bash
mn job cancel <job_id>
mn runtime stop
```

Do not delete the run store until you have collected the artifacts and events needed for review or troubleshooting.

## Next steps

- [Examples](examples.md) to choose a blueprint based on task, resources, and data boundary.
- [Core Concepts](core-concepts.md) for the vocabulary used by the runtime and docs.
- [Blueprint Standard](blueprint-standard.md) to author a compatible workflow package.
- [Security Model](security.md) before providing real data, secrets, or network access.
