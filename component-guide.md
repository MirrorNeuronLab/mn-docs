# MirrorNeuron Component Guide

This is the canonical repository map for contributors and maintainers. Use it to identify the component that owns a behavior, select the smallest validation command, and decide which detailed documentation page must change with the code.

## Documentation ownership

`mn-docs` owns detailed cross-component documentation. Folder READMEs should remain focused on the component's purpose, a safe first command, and component-local validation. Blueprint folders are the exception: they must be self-contained because they are often reviewed and run outside the central documentation.

## Workspace map

| Component | Owns | Primary documentation | Minimum validation |
| --- | --- | --- | --- |
| `MirrorNeuron` | Elixir/OTP runtime, scheduling, persistence, cluster coordination, gRPC services, and execution leases. | [Runtime Architecture](runtime-architecture.md), [Reliability Guide](reliability.md) | `cd MirrorNeuron && mix test` |
| `mn-deploy` | Installer, local service scripts, Docker Compose templates, and release support. | [Installation](installation.md) | `cd mn-deploy && ./install.sh --help` |
| `mn-cli` | `mn` command surface, local runtime orchestration, model/blueprint/job/node operations. | [CLI Reference](cli.md) | `cd mn-cli && python3 -m pytest -q` |
| `mn-api` | FastAPI REST gateway, API auth/configuration, OpenAPI surface, and runtime proxy behavior. | [API Reference](api.md) | `cd mn-api && python3 -m pytest -q` |
| `mn-python-sdk` | gRPC client, configuration resolution, bundle helpers, and blueprint catalog source resolution. | [Python SDK](SDK.md), [Environment Variables](env_variables.md) | `cd mn-python-sdk && python3 -m pytest -q` |
| `mn-web-ui` | Browser UI for jobs, runtime state, and blueprint runs. | [Monitor Guide](monitor.md) | `cd mn-web-ui && npm run lint && npm test -- --run` |
| `mn-agents` | Shared agent templates and contracts used by blueprints. | [Blueprints and Skills](blueprints-and-skills.md) | Component test suite |
| `mn-skills` | Reusable Python skill packages. | [Blueprints and Skills](blueprints-and-skills.md) | Package-specific tests |
| `mn-system-tests` | Cross-component smoke, integration, end-to-end, security, and benchmark checks. | [Testing](testing.md) | `cd mn-system-tests && python3 test_all.py --fast` |
| `Membrane` | Context engine, context-memory SDK, and context-compression tooling. | [Context Memory](context-memory.md) | Component test suite |
| `otterdesk-blueprints` | Self-contained user-facing workflow blueprints. | [Examples](examples.md), [Blueprint Standard](blueprint-standard.md) | Blueprint validation and repository tests |
| `otterdesk-desktop-app` | Desktop application for launching and monitoring blueprints. | [Deployments](deployments.md) | `cd otterdesk-desktop-app && npm run doctor` |

## Change-to-documentation map

| If you change… | Update at minimum |
| --- | --- |
| A CLI command, option, output contract, or command group | `cli.md`, relevant tutorial/how-to, tests. |
| An API route, request/response field, auth behavior, or default port | `api.md`, `env_variables.md`, route tests, and OpenAPI validation. |
| A runtime lifecycle, scheduler, lease, retry, recovery, or persistence behavior | `runtime-architecture.md`, `reliability.md`, troubleshooting, Core tests. |
| A public configuration key | `env_variables.md`, configuration schema/docs, and component tests. |
| A blueprint input/output, runner, service, model, device, or human-control boundary | Blueprint README/SPEC/manifest, `examples.md`, `blueprint-standard.md`, and validation tests. |
| A listener, secret path, external connector, sandbox policy, or cluster trust behavior | `security.md`, relevant operational page, configuration reference, and tests. |
| Installer or service startup behavior | `installation.md`, `troubleshooting.md`, `mn-doc-site` installation page, and installer tests. |

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
mn runtime health
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
