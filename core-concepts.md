# Core Concepts

This page is the canonical vocabulary for contributors, integrators, and operators. Use these terms consistently in manifests, CLI/API descriptions, tests, logs, and documentation.

## Execution model

```text
blueprint folder → validation → job submission → scheduling → worker execution
       ↓                ↓             ↓              ↓              ↓
 manifest + payloads   requirements   job state      events          artifacts
```

The control plane accepts jobs, records state, coordinates scheduling, and exposes inspection/control operations. The execution plane runs agents through the execution environment selected by the workflow. Redis holds runtime state; blueprint-oriented runs write a local run store for artifacts and records.

## Canonical terms

| Term | Definition | Primary evidence |
| --- | --- | --- |
| **workflow** | A declared graph or program of work executed by the runtime. | Manifest schema and runtime scheduling code. |
| **blueprint** | A reusable packaged workflow, normally containing a manifest, configuration, payloads, README, and supporting assets. | `otterdesk-blueprints/<blueprint_id>/`. |
| **bundle** | The validated package submitted to the runtime. | `bundle.md`, SDK bundle helpers, CLI validation. |
| **job** | A durable configured definition, identified by a public job ID. It can have multiple runs. | `mn job` commands and `/jobs` API routes. |
| **run** | One execution of a durable job, identified by a public run ID. | `mn run` commands and `/runs` API routes. |
| **agent** | An executable workflow participant with a declared role and runtime contract. | Manifest nodes and runtime agent modules. |
| **runtime node** | A machine or runtime member eligible to execute work. | `mn node` commands and cluster runtime code. |
| **event** | A recorded runtime occurrence such as progress, failure, retry, or completion. | Job events and run-store JSONL streams. |
| **artifact** | A file or output associated with a run. | Run-store contract and artifact API routes. |
| **control plane** | The runtime responsibilities for state, scheduling, inspection, and control. | Runtime architecture and Core modules. |
| **execution plane** | Worker processes and runners that execute workflow work. | Runner configuration, OpenShell integration, and worker modules. |

## Runner and trust boundaries

- **HostLocal** executes worker code on the host. It is appropriate only for trusted payloads.
- **DockerWorker** executes prepared worker commands in Docker containers. Review image contents, mounts, environment, and network access.
- **OpenShell** executes worker code in an OpenShell sandbox. It reduces the host boundary but does not remove the need to review policy, uploads, environment variables, and network access.
- **Cluster execution** places eligible work on another runtime node. Nodes participate in one trust domain and must protect shared credentials and internal listeners.

The runner is part of a blueprint's contract. Documentation and tests must not describe a blueprint as sandboxed when it uses HostLocal, or as local-only when it can call configured external services.

## Job lifecycle and evidence

The normal user-facing sequence is:

1. `mn blueprint validate ./my-blueprint` checks the local blueprint and its declared requirements.
2. `mn blueprint run ./my-blueprint` prepares the definition and starts a run; retain both public IDs.
3. `mn job show <job-id>` inspects the definition; `mn run show <run-id>` and `mn run watch <run-id>` inspect execution.
4. `mn run logs <run-id> --channel logs` and `mn run logs <run-id> --channel events` inspect output.
5. `mn run cancel <run-id>` cancels the execution when it should not continue.

Do not treat a completed job as a blanket correctness guarantee. Inspect the output artifacts, failure/warning events, input provenance, and any required human-control record before using the result.

## Documentation implications

- Use **job ID** for durable definition inspection, configuration, and starting another run.
- Use **run ID** for execution inspection, pause/resume/cancel, logs, and artifacts. Internal `runtime_run_id` values are diagnostic metadata, not public REST URL identifiers.
- Name the runner whenever execution safety matters.
- Name the model, service, device, input, or network prerequisite when it affects whether a blueprint can launch.
- Keep exact CLI syntax in `cli.md`, exact API shapes in `api.md`, and exact environment defaults in `env_variables.md`.

## Related pages

- [Why MirrorNeuron](why-mirrorneuron.md)
- [Blueprint Standard](blueprint-standard.md)
- [Runtime Architecture](runtime-architecture.md)
- [Reliability Guide](reliability.md)
- [Security Model](security.md)
