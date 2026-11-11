# MirrorNeuron Component Guide

This is the canonical repository map for contributors and maintainers. Use it to identify the component that owns a behavior, select the smallest validation command, and decide which detailed documentation page must change with the code.

This contributor reference describes the current source layout. The validation
commands assume each component's development dependencies are installed. See the
[application surface and runtime diagram](runtime-architecture.md#application-surface-and-runtime-nodes)
for the request path and [Testing](testing.md) for environment setup and service
isolation.

## Documentation ownership

`mn-docs` owns detailed cross-component documentation. Folder READMEs should remain focused on the component's purpose, a safe first command, and component-local validation. Blueprint folders are the exception: they must be self-contained because they are often reviewed and run outside the central documentation.

## Workspace map

| Component                        | Owns                                                                                                                                                                    | Primary documentation                                                                | Minimum validation                                                 |
| -------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------ | ------------------------------------------------------------------ |
| `MirrorNeuron`                   | Elixir/OTP Core, runtime gRPC gateway, cluster membership, admission, scheduling, execution supervision, and Redis persistence.                                         | [Runtime Architecture](runtime-architecture.md), [Reliability Guide](reliability.md) | `cd MirrorNeuron && mix test`                                      |
| `mn-deploy`                      | Installation roles, package selection, credentials, service scripts, Compose templates, and release support.                                                            | [Installation](installation.md)                                                      | `cd mn-deploy && ./install.sh --help`                              |
| `mn-cli`                         | `mn` commands, options, and terminal output. Sends runtime requests through the SDK client.                                                                             | [CLI Reference](cli.md)                                                              | `cd mn-cli && python3 -m pytest -q`                                |
| `mn-api`                         | FastAPI REST and MCP surface, API authentication, OpenAPI, and adaptation of runtime responses, streams, downloads, and job UI connections.                             | [API Reference](api.md)                                                              | `cd mn-api && python3 -m pytest -q`                                |
| `mn-python-sdk`                  | Shared wire contracts, runtime client and connection profile, validation, bundle helpers, and worker libraries.                                                         | [Python SDK](SDK.md), [Environment Variables](env_variables.md)                      | `cd mn-python-sdk && python3 -m pytest -q`                         |
| `mn-python-sdk/packages/runtime` | Independent `mirrorneuron-runtime` package (`mn_runtime`). Hosts the private native service and owns catalog operations, preparation, lifecycle, monitors, and cleanup. | [Native preparation boundary](runtime-architecture.md#native-preparation-boundary)   | `cd mn-python-sdk/packages/runtime && python3 -m pytest -q`        |
| `mn-web-ui`                      | Browser interface for jobs and runs through `mn-api`.                                                                                                                   | [Monitor Guide](monitor.md)                                                          | `cd mn-web-ui && npm run lint && npm test -- --run`                |
| `mn-agents`                      | Shared agent templates and contracts used by blueprints.                                                                                                                | [Blueprints and Skills](blueprints-and-skills.md)                                    | Component test suite                                               |
| `mn-skills`                      | Reusable Python skill packages.                                                                                                                                         | [Blueprints and Skills](blueprints-and-skills.md)                                    | Package-specific tests                                             |
| `mn-system-tests`                | Cross-component smoke, integration, end-to-end, security, and benchmark checks.                                                                                         | [Testing](testing.md)                                                                | `cd mn-system-tests && .venv/bin/mn_test --suite contracts`        |
| `Membrane`                       | Context Intelligent System: memory, query planning, retrieval, evidence assembly and context admission.                                                                 | [Context Intelligent System](context-memory.md)                                      | Component test suite                                               |
| `Synapse`                        | Synapsy CLI and libraries for authoring and verifying blueprint packages.                                                                                               | [Blueprint Standard](blueprint-standard.md)                                          | `cd Synapse && python3 -m pytest -q`                               |
| `mn-blueprints`                  | Default external blueprint catalog consumed by the runtime.                                                                                                             | [Blueprints and Skills](blueprints-and-skills.md)                                    | Blueprint validation and repository tests                          |
| `mn-docs`                        | Canonical contributor and operator documentation.                                                                                                                       | [Documentation Index](index.md)                                                      | [Documentation checks](documentation-style.md#required-validation) |
| `otterdesk-blueprints`           | Self-contained user-facing workflow blueprints.                                                                                                                         | [Examples](examples.md), [Blueprint Standard](blueprint-standard.md)                 | Blueprint validation and repository tests                          |
| `otterdesk-desktop-app`          | Desktop application for launching and monitoring blueprints.                                                                                                            | [Deployments](deployments.md)                                                        | `cd otterdesk-desktop-app && npm run doctor`                       |

## Internal module boundaries

Use the public component interfaces from integrations. When tracing a runtime
request in the source, start with these modules.

| Component | Internal owner                                                                                                                                                                                                             | Responsibility retained by the caller                                                                                                                                                                                                          |
| --------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| API       | `mn_api/runtime_adapter.py` maps REST requests to SDK runtime calls and adapts replies and streams.                                                                                                                        | REST routes define the public request, response, and authentication contracts.                                                                                                                                                                 |
| CLI       | `mn_cli/client_commands.py` dispatches commands to SDK runtime adapters.                                                                                                                                                   | `commands.py` defines the command options. Local lifecycle commands delegate to the installed runtime lifecycle module.                                                                                                                        |
| Runtime   | `mn_runtime/lifecycle.py` manages host services. `mn_runtime/native_service.py` hosts the private runtime service.                                                                                                         | `services/blueprint_launch.py`, `services/operations.py`, and `services/launch_progress_store.py` handle launch preparation, durable operations, and progress on the runtime.                                                                  |
| SDK       | `validation_hardware.py` owns hardware requirement matching; `validation_issues.py` owns issue/report formatting; `model_placement.py` owns placement selection; `submission_payloads.py` owns source and payload staging. | `blueprint_validation.py`, `model_runtime.py`, and `submission_preparation.py` retain their public entry points, orchestration, provider calls, and preparation order. Hardware detection enters the validator as a callable and remains lazy. |
| Web UI    | `src/api/schemas.ts` owns Zod schemas and inferred types; `src/utils/jobDetailsView.ts` owns pure status/summary presentation helpers.                                                                                     | `src/api/index.ts` retains HTTP, ETag caching, idempotency, and streaming; `JobDetails.tsx` retains effects, polling, state, and rendering. Existing schema/type exports remain available from the API entry point.                            |
| Core      | `MirrorNeuron.Grpc.RuntimeControlServer` authenticates runtime requests and routes them to native services. `Persistence.JobSummary` and `Runtime.JobTopology` build job projections and indexes.                          | `RedisStore` handles persistence and fencing. `JobCoordinator` owns execution state transitions.                                                                                                                                               |

The SDK client is a shared library dependency of CLI and API. The runtime package
uses the SDK on the execution host and is installed independently of those
surface packages. For the earlier module changes, see the
[November internal refactoring report](refactoring-report-2026-11.md).

## Change-to-documentation map

| If you change…                                                                         | Update at minimum                                                                              |
| -------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------- |
| A CLI command, option, output contract, or command group                               | `cli.md`, relevant tutorial/how-to, tests.                                                     |
| An API route, request/response field, auth behavior, or default port                   | `api.md`, `env_variables.md`, route tests, and OpenAPI validation.                             |
| A runtime lifecycle, scheduler, lease, retry, recovery, or persistence behavior        | `runtime-architecture.md`, `reliability.md`, troubleshooting, Core tests.                      |
| A public configuration key                                                             | `env_variables.md`, configuration schema/docs, and component tests.                            |
| A blueprint input/output, runner, service, model, device, or human-control boundary    | Blueprint README/SPEC/manifest, `examples.md`, `blueprint-standard.md`, and validation tests.  |
| A listener, secret path, external connector, sandbox policy, or cluster trust behavior | `security.md`, relevant operational page, configuration reference, and tests.                  |
| Installer or service startup behavior                                                  | `installation.md`, `troubleshooting.md`, `mn-doc-site` installation page, and installer tests. |

## Safe contributor loop

1. Start in the component that owns the behavior, not in a documentation file.
2. Read the component README, local `AGENTS.md`, focused tests, and the canonical page listed above.
3. Make the smallest behavior change that addresses the intended contract.
4. Run the component's focused validation before broader checks.
5. Update `mn-docs` first for detailed facts, then `mn-doc-site/content/docs` for the concise reader-facing path when the behavior is public.
6. Run the documentation-site type check and record evidence in the pull request.

## Local runtime development

Use the deployment component to install an editable workspace runtime:

```bash
cd mn-deploy
./install.sh --mode local
```

Then inspect the services before testing a blueprint:

```bash
mn runtime status
mn node list
```

Use [Quickstart](quickstart.md) for the model-backed first workflow path. Do not substitute a deleted blueprint ID or assume a checked-in blueprint has no model, service, or device requirements.

## Related pages

- [Documentation Standard](documentation-style.md)
- [Testing](testing.md)
- [Contributing](contributing.md)
- [Runtime Architecture](runtime-architecture.md)
- [Security Model](security.md)
