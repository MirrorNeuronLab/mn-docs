# MirrorNeuron Component Guide

This is the canonical repository map for contributors and maintainers. Use it to identify the component that owns a behavior, select the smallest validation command, and decide which detailed documentation page must change with the code.

This contributor reference describes the current source layout, not a new public interface. Module ownership is grounded in the owning repositories; commands assume their development dependencies are installed. See [Testing](testing.md) for environment setup, service isolation, and result interpretation.

## Documentation ownership

`mn-docs` owns detailed cross-component documentation. Folder READMEs should remain focused on the component's purpose, a safe first command, and component-local validation. Blueprint folders are the exception: they must be self-contained because they are often reviewed and run outside the central documentation.

## Workspace map

| Component               | Owns                                                                                                    | Primary documentation                                                                | Minimum validation                                          |
| ----------------------- | ------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------ | ----------------------------------------------------------- |
| `MirrorNeuron`          | Elixir/OTP runtime, scheduling, persistence, cluster coordination, gRPC services, and execution leases. | [Runtime Architecture](runtime-architecture.md), [Reliability Guide](reliability.md) | `cd MirrorNeuron && mix test`                               |
| `mn-deploy`             | Installer, local service scripts, Docker Compose templates, and release support.                        | [Installation](installation.md)                                                      | `cd mn-deploy && ./install.sh --help`                       |
| `mn-cli`                | `mn` command surface, local runtime orchestration, model/blueprint/job/node operations.                 | [CLI Reference](cli.md)                                                              | `cd mn-cli && python3 -m pytest -q`                         |
| `mn-api`                | FastAPI REST gateway, API auth/configuration, OpenAPI surface, and runtime proxy behavior.              | [API Reference](api.md)                                                              | `cd mn-api && python3 -m pytest -q`                         |
| `mn-python-sdk`         | gRPC client, configuration resolution, bundle helpers, and blueprint catalog source resolution.         | [Python SDK](SDK.md), [Environment Variables](env_variables.md)                      | `cd mn-python-sdk && python3 -m pytest -q`                  |
| `mn-web-ui`             | Browser UI for jobs, runtime state, and blueprint runs.                                                 | [Monitor Guide](monitor.md)                                                          | `cd mn-web-ui && npm run lint && npm test -- --run`         |
| `mn-agents`             | Shared agent templates and contracts used by blueprints.                                                | [Blueprints and Skills](blueprints-and-skills.md)                                    | Component test suite                                        |
| `mn-skills`             | Reusable Python skill packages.                                                                         | [Blueprints and Skills](blueprints-and-skills.md)                                    | Package-specific tests                                      |
| `mn-system-tests`       | Cross-component smoke, integration, end-to-end, security, and benchmark checks.                         | [Testing](testing.md)                                                                | `cd mn-system-tests && .venv/bin/mn_test --suite contracts` |
| `Membrane`              | Context Intelligent System: memory, query planning, retrieval, evidence assembly and context admission. | [Context Intelligent System](context-memory.md)                                      | Component test suite                                        |
| `otterdesk-blueprints`  | Self-contained user-facing workflow blueprints.                                                         | [Examples](examples.md), [Blueprint Standard](blueprint-standard.md)                 | Blueprint validation and repository tests                   |
| `otterdesk-desktop-app` | Desktop application for launching and monitoring blueprints.                                            | [Deployments](deployments.md)                                                        | `cd otterdesk-desktop-app && npm run doctor`                |

## Internal module boundaries

Use the public component facades from integrations. Within a component, import a helper from the module that owns its responsibility. The compatibility facades retain existing imports while these internal modules separate data transformations from orchestration:

| Component | Internal owner                                                                                                                                                                                                             | Responsibility retained by the caller                                                                                                                                                                                                          |
| --------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| API       | `mn_api/launch_progress_store.py` owns progress JSONL storage and event/phase projections.                                                                                                                                 | `blueprint_launch.py` orchestrates preparation and launch; `launch_progress.py` coordinates progress consumers. Both depend on the store, so storage does not import launch orchestration.                                                     |
| CLI       | `mn_cli/runtime/launch_config.py` owns environment, endpoint, and command transformations; `runtime/watchdog.py` owns watchdog code.                                                                                       | `runtime/server.py` retains service lifecycle and configuration resolution. `libs/run_cmds` uses explicit imports and preserves its exported facade.                                                                                           |
| SDK       | `validation_hardware.py` owns hardware requirement matching; `validation_issues.py` owns issue/report formatting; `model_placement.py` owns placement selection; `submission_payloads.py` owns source and payload staging. | `blueprint_validation.py`, `model_runtime.py`, and `submission_preparation.py` retain their public entry points, orchestration, provider calls, and preparation order. Hardware detection enters the validator as a callable and remains lazy. |
| Web UI    | `src/api/schemas.ts` owns Zod schemas and inferred types; `src/utils/jobDetailsView.ts` owns pure status/summary presentation helpers.                                                                                     | `src/api/index.ts` retains HTTP, ETag caching, idempotency, and streaming; `JobDetails.tsx` retains effects, polling, state, and rendering. Existing schema/type exports remain available from the API entry point.                            |
| Core      | `Persistence.JobSummary` builds the persisted summary projection; `Runtime.JobTopology` derives topology and downstream indexes.                                                                                           | `RedisStore` retains Redis operations, keys, fencing, and persistence order; `JobCoordinator` retains the GenServer state machine and lifecycle transitions.                                                                                   |

Configuration schemas and defaults remain with their existing owners. These modules do not introduce configuration files or dependencies. Literal values that define one projection or traversal stay beside that algorithm; operational settings continue through the existing configuration loaders. For validation evidence and deferred work, see the [November internal refactoring report](refactoring-report-2026-11.md).

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
