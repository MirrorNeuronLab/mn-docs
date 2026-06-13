# MirrorNeuron Docs

Documentation for MirrorNeuron and OtterDesk: local installation, runtime
operations, API and CLI usage, blueprint development, model/runtime services,
security, and troubleshooting.

## Project Scope

MirrorNeuron is an Elixir/BEAM runtime with Python tooling for durable,
message-driven AI workflows. OtterDesk is the desktop/operator layer that
launches and monitors worker blueprints on top of that runtime.

The documentation covers:

- Runtime architecture, clustering, resources, services, schedules, and deployments.
- Local installation, first-run setup, and runtime health checks.
- CLI, FastAPI gateway, Python SDK, Web UI, OtterDesk, blueprints, and skills.
- Docker Model Runner local model management.
- Security considerations for host-local, Docker, and OpenShell worker payloads.
- Troubleshooting and contribution guidance.

## Prerequisites

- macOS, Linux, or WSL2.
- Python 3.11.x for the CLI, SDK, API, system tests, HostLocal workers, and Python-defined blueprints.
- Docker for local Redis, the generated runtime, DockerWorker payloads, and Docker Model Runner.
- Redis for runtime state.
- OpenShell when running sandboxed workers.

Elixir/Erlang are required for core runtime development. Released-package
installs use OTP tarballs instead of building the core from source.

Use `python3.11 -m venv .venv` when creating local environments, then prefer
`.venv/bin/python` for installs and tests. Bare `python3` is reserved for
explicit Docker/OpenShell sandbox contracts such as `/usr/bin/python3` inside a
container image or sandbox policy.

## Quick Start

Install MirrorNeuron from released packages:

```bash
curl -fsSL https://mirrorneuron.io/install.sh | bash
```

Start the runtime and run a catalog blueprint:

```bash
mn runtime start
mn blueprint list
mn blueprint run portfolio_risk_review_assistant
mn blueprint monitor
```

Run a checked-in OtterDesk blueprint directly from this workspace:

```bash
mn blueprint run --folder otterdesk-blueprints/tax_form_ocr_capture_assistant
```

Check jobs and nodes:

```bash
mn job list
mn node list
```

## Architecture Summary

```text
OtterDesk / CLI / FastAPI / Web UI
      |
      v
BEAM runtime: jobs, agents, routing, leases, recovery, events
      |
      v
Execution runners: HostLocal, DockerWorker, OpenShell, Python, shell
      |
      v
Redis durable state, run-store artifacts, optional Redis Sentinel HA
```

Read:

- [Runtime Architecture](runtime-architecture.md)
- [Cluster Architecture](cluster_architecture.md)
- [Nomad-Inspired Runtime Features](nomad-inspired-runtime.md)
- [Security Model](security.md)

## Documentation Index

| Topic | Document |
| --- | --- |
| Repository/component guide | [component-guide.md](component-guide.md) |
| Weekly growth tracker | [change_log.md](change_log.md) |
| Skill catalog | [skill-catalog.md](skill-catalog.md) |
| Getting started | [quickstart.md](quickstart.md) |
| Installation | [installation.md](installation.md) |
| CLI reference | [cli.md](cli.md) |
| Blueprints and skills | [blueprints-and-skills.md](blueprints-and-skills.md) |
| Blueprint standard | [blueprint-standard.md](blueprint-standard.md) |
| Docker and OpenShell for blueprints | [docker_and_openshell_for_blueprints.md](docker_and_openshell_for_blueprints.md) |
| Nomad-inspired runtime features | [nomad-inspired-runtime.md](nomad-inspired-runtime.md) |
| Services and health checks | [services-and-health-checks.md](services-and-health-checks.md) |
| Model runtime | [model-runtime.md](model-runtime.md) |
| Resources and devices | [resources-and-devices.md](resources-and-devices.md) |
| Deployments | [deployments.md](deployments.md) |
| Schedules and events | [schedules-and-events.md](schedules-and-events.md) |
| Runtime architecture | [runtime-architecture.md](runtime-architecture.md) |
| Cluster architecture | [cluster_architecture.md](cluster_architecture.md) |
| Reliability and recovery | [reliability.md](reliability.md) |
| Security | [security.md](security.md) |
| Troubleshooting | [troubleshooting.md](troubleshooting.md) |
| Contributing | [contributing.md](contributing.md) |

## Security Notes

MirrorNeuron can run local code, create sandboxes, call external services,
connect to model providers, and pass selected environment variables to worker
payloads.

Before running third-party bundles or exposing a cluster:

- Keep runtime API and gRPC ports bound to trusted networks.
- Review bundle `manifest.json`, `payloads/`, `pass_env`, runner policies, and service declarations.
- Use OpenShell policies for untrusted network access.
- Do not pass broad secrets into workers.
- Prefer Redis Sentinel HA over single Redis for multi-box deployments.
- Treat incoming live messages, emails, Slack events, browser data, and model outputs as untrusted input.

## Contributing

Keep docs concise and command examples copyable. When documenting behavior, link
to the relevant component README or source file when practical.

## License

See [LICENSE](LICENSE).
