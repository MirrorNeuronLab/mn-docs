# MirrorNeuron Documentation

This directory is the detailed documentation source of truth for the MirrorNeuron workspace. It is written for internal maintainers, contributors, integrators, and operators; the documentation site presents a shorter reader-facing layer. When the two differ, verify the implementation and update both in the same change.

MirrorNeuron is a runtime for message-driven workflows with a Python CLI/API layer, an Elixir/BEAM core, Redis-backed runtime state, and blueprint-oriented run records. It can run on one machine or across runtime nodes.

## Documentation contract

Every user-visible behavior has one canonical detailed page in this directory:

| Fact | Canonical page | Implementation source to verify |
| --- | --- | --- |
| Project fit, boundaries, and non-guarantees | [Why MirrorNeuron](why-mirrorneuron.md) | Runtime, runner, and security implementation. |
| Shared vocabulary | [Core Concepts](core-concepts.md) | Manifest/runtime terms and CLI/API contracts. |
| Installation and local services | [Installation](installation.md) | `mn-deploy/install.sh`, `server.sh`, runtime start code. |
| CLI syntax and behavior | [CLI Reference](cli.md) | `mn-cli/mn_cli/main.py` and command modules. |
| REST API shape | [API Reference](api.md) | `mn-api` routes and running FastAPI OpenAPI schema. |
| Environment defaults | [Environment Variables](env_variables.md) | CLI, API, SDK, and Core configuration definitions. |
| Blueprint and manifest contracts | [Blueprint Standard](blueprint-standard.md), [Job Bundle Format](bundle.md) | Schemas, SDK validators, and checked-in blueprints. |
| Reliability and recovery | [Reliability Guide](reliability.md) | Core persistence, lease, scheduler, and recovery tests. |
| Security boundaries | [Security Model](security.md) | Runner, network, Redis, secret, and policy behavior. |
| Repeated operational failures | [Troubleshooting](troubleshooting.md) | Reproducible diagnostics and component tests. |

Do not duplicate large command tables, API shapes, or environment-variable lists on tutorial pages. Link to the canonical reference instead.

## Reader journeys

### Evaluator

1. [Why MirrorNeuron](why-mirrorneuron.md)
2. [Core Concepts](core-concepts.md)
3. [Quickstart](quickstart.md)
4. [Security Model](security.md)
5. [Runtime Architecture](runtime-architecture.md)

### First-time developer

1. [Installation](installation.md)
2. [Quickstart](quickstart.md)
3. [Examples](examples.md)
4. [CLI Reference](cli.md)
5. [Troubleshooting](troubleshooting.md)

### Blueprint author

1. [Core Concepts](core-concepts.md)
2. [Blueprint Standard](blueprint-standard.md)
3. [Blueprints and Skills](blueprints-and-skills.md)
4. [Python SDK](SDK.md)
5. [Testing](testing.md)

### Operator

1. [Installation](installation.md)
2. [Services and Health Checks](services-and-health-checks.md)
3. [Monitor Guide](monitor.md)
4. [Reliability Guide](reliability.md)
5. [Redis High Availability](redis-ha.md)
6. [Troubleshooting](troubleshooting.md)

### Contributor

1. [Component Guide](component-guide.md)
2. [Runtime Architecture](runtime-architecture.md)
3. [Testing](testing.md)
4. [Contributing](contributing.md)
5. [Documentation Style](documentation-style.md)

## Documentation map

| Topic | Page |
| --- | --- |
| Local installation and verification | [installation.md](installation.md) |
| First local workflow | [quickstart.md](quickstart.md) |
| Checked-in blueprint selection | [examples.md](examples.md) |
| CLI, API, SDK, and configuration | [cli.md](cli.md), [api.md](api.md), [SDK.md](SDK.md), [env_variables.md](env_variables.md) |
| Models, OpenShell, services, and resources | [model-runtime.md](model-runtime.md), [docker_and_openshell_for_blueprints.md](docker_and_openshell_for_blueprints.md), [services-and-health-checks.md](services-and-health-checks.md), [resources-and-devices.md](resources-and-devices.md) |
| Cluster, deployment, schedules, and HA | [cluster.md](cluster.md), [deployments.md](deployments.md), [schedules-and-events.md](schedules-and-events.md), [redis-ha.md](redis-ha.md) |
| Architecture, reliability, and security | [runtime-architecture.md](runtime-architecture.md), [cluster_architecture.md](cluster_architecture.md), [reliability.md](reliability.md), [security.md](security.md) |
| Internal quality and contributor process | [testing.md](testing.md), [contributing.md](contributing.md), [documentation-style.md](documentation-style.md) |

## Source-doc update rule

When a pull request changes a command, API route, configuration key, manifest field, runtime guarantee, runner boundary, or failure behavior:

1. update the canonical detailed page in `mn-docs`;
2. update the concise corresponding page in `mn-doc-site/content/docs` when the behavior is user-facing;
3. update a tutorial, troubleshooting page, and migration note when the reader journey changes;
4. run the documentation build and the smallest relevant product validation; and
5. record the implementation source and validation command in the pull request.
