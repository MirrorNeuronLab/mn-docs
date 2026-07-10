# Why MirrorNeuron

Use this page to evaluate whether MirrorNeuron fits a workflow before you commit to an integration or contribution. MirrorNeuron is a runtime for message-driven workflows with a Python CLI/API layer, an Elixir/BEAM core, Redis-backed runtime state, and blueprint-oriented local run records.

## Intended workloads

MirrorNeuron is intended for workflows that need one or more of these properties:

- packaged workflow definitions, payload files, configuration, and validation rules;
- explicit job submission, inspection, pause, resume, cancellation, and recovery controls;
- observable runtime state, events, logs, and output artifacts;
- a choice between trusted host-local execution, OpenShell sandbox execution, and placement on eligible runtime nodes; or
- local model execution through Docker Model Runner, with external integrations enabled only by the selected blueprint and its configuration.

It can run on a single machine or on a small cluster of runtime nodes. The `mn` CLI, `mn-api` REST gateway, and Python SDK are the public operational surfaces; MirrorNeuron Core owns scheduling, orchestration, and durable runtime coordination.

## Evaluation checklist

| Question | Evidence to inspect | Why it matters |
| --- | --- | --- |
| Is the workflow safe to run? | `manifest.json`, `payloads/`, runner settings, `pass_env`, policy files. | A blueprint can execute code, read declared files, use selected secrets, and call services. |
| Can the target machine satisfy requirements? | `mn blueprint validate`, `mn model doctor <model-id>`, service checks, resource declarations. | Validation identifies declared model, service, and input requirements before submission. |
| Does the deployment fit the trust boundary? | `security.md`, listener configuration, Redis configuration, runner selection. | HostLocal, OpenShell, and cluster execution have different privilege and network boundaries. |
| Can the workflow tolerate retries? | Retry policies, external adapters, idempotency keys, `reliability.md`. | Recovery can repeat work; side-effecting workers must be idempotent or independently deduplicated. |
| Can operators diagnose failures? | Job events, run store, API health, Redis, model/service diagnostics. | A workflow is operational only when a user can inspect its state and collect evidence. |

## Non-goals and non-guarantees

MirrorNeuron does not provide these properties merely by being installed:

- **Automatic privacy.** Data can leave the host if a blueprint calls a remote model provider, web service, browser, email service, or another configured connector.
- **Automatic sandboxing.** HostLocal runs code directly on the host. OpenShell is a stronger execution boundary, but operators must still review policies, uploads, and service exposure.
- **Exactly-once external effects.** A retry or recovery can cause an external action to be attempted again. Workers that create external effects must use an idempotency strategy.
- **Trust isolation between cluster nodes.** Cluster members share a runtime trust domain. Protect node credentials, Redis, and network listeners accordingly.
- **Domain authority.** Blueprints that prepare finance, legal, medical, safety, investment, or research outputs produce review material; a human must make consequential decisions.

## Internal sources of truth

- CLI surface: `mn-cli/mn_cli/main.py` and command modules under `mn-cli/mn_cli/libs/`.
- REST surface: `mn-api/mn_api/app.py`, route modules under `mn-api/mn_api/routes/`, and the running FastAPI OpenAPI schema.
- Runtime behavior: `MirrorNeuron/lib/` and its tests.
- Blueprint requirements: each blueprint's `manifest.json`, `config/`, `README.md`, `SPEC.md`, and tests in `otterdesk-blueprints/`.
- Runtime configuration: `mn-api/mn_api/config_schema.py`, `mn-cli/mn_cli/config.py`, and the environment-variable reference.

## Related pages

- [Core Concepts](core-concepts.md)
- [Installation](installation.md)
- [Quickstart](quickstart.md)
- [Security Model](security.md)
- [Runtime Architecture](runtime-architecture.md)
