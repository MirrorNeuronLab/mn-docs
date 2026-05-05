# MirrorNeuron Docs

Documentation for MirrorNeuron, including installation, architecture, CLI usage, blueprint development, security, and troubleshooting.

## Project Scope

MirrorNeuron is an Elixir/BEAM runtime with Python tooling for running message-driven workflow graphs. The documentation covers:

- Runtime architecture and clustering.
- Local installation and first-run setup.
- CLI, API, SDK, Web UI, blueprints, and skills.
- Security considerations for running worker payloads.
- Troubleshooting and contribution guidance.

## Prerequisites

- macOS, Linux, or WSL2.
- Python 3.9+ for CLI, SDK, API, system tests, and Python-defined blueprints.
- Docker for the default local Redis and core workflow.
- Redis for runtime state.
- OpenShell when running sandboxed workers.

Elixir/Erlang are required for core runtime development. Released-package installs use OTP tarballs instead of building the core from source.

## Quick Start

Install MirrorNeuron from released packages:

```bash
curl -fsSL https://mirrorneuron.io/install.sh | bash
```

Start the runtime and run a sample blueprint:

```bash
mn start
mn blueprint run general_message_routing_trace
mn blueprint monitor
```

Check jobs:

```bash
mn list
mn nodes
```

## Architecture Summary

```text
CLI / API / Web UI
      |
      v
BEAM runtime: jobs, agents, routing, leases, recovery, events
      |
      v
Execution runners: HostLocal, OpenShell, Python, shell, worker payloads
      |
      v
Redis durable state and optional Redis Sentinel HA
```

Read:

- [Runtime Architecture](runtime-architecture.md)
- [Cluster Architecture](cluster_architecture.md)
- [Security Model](security.md)

## Documentation Index

| Topic | Document |
| --- | --- |
| Getting started | [quickstart.md](quickstart.md) |
| Installation | [installation.md](installation.md) |
| CLI reference | [cli.md](cli.md) |
| Blueprints and skills | [blueprints-and-skills.md](blueprints-and-skills.md) |
| Runtime architecture | [runtime-architecture.md](runtime-architecture.md) |
| Cluster architecture | [cluster_architecture.md](cluster_architecture.md) |
| Security | [security.md](security.md) |
| Troubleshooting | [troubleshooting.md](troubleshooting.md) |
| Contributing | [contributing.md](contributing.md) |

## Security Notes

MirrorNeuron can run local code, create sandboxes, call external services, connect to model providers, and pass selected environment variables to worker payloads.

Before running third-party bundles or exposing a cluster:

- Keep runtime API and gRPC ports bound to trusted networks.
- Review bundle `manifest.json`, `payloads/`, `pass_env`, and runner policies.
- Use OpenShell policies for untrusted network access.
- Do not pass broad secrets into workers.
- Prefer Redis Sentinel HA over single Redis for multi-box deployments.
- Treat incoming live messages, emails, Slack events, and model outputs as untrusted input.

## Contributing

Keep docs concise and command examples copyable. When documenting behavior, link to the relevant component README or source file when practical.

## License

See [LICENSE](LICENSE).
