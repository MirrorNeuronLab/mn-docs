# MirrorNeuron Docs

MirrorNeuron is an Elixir/BEAM runtime for durable, observable, multi-agent workflows that run on one machine, on edge boxes, or across a small cluster.

## What It Does

- Runs message-driven workflow graphs from reusable bundles and blueprints.
- Keeps job state, agent snapshots, events, leases, and recovery metadata in Redis.
- Executes Python, shell, and other worker payloads through bounded local or OpenShell runners.
- Supports daemon workflows, streaming, backpressure, retry, cluster failover, and Redis Sentinel HA.

## Quick Start

```bash
curl -fsSL https://mirrorneuron.io/install.sh | bash
mn blueprint run general_message_routing_trace
```

Expected output:

```text
Blueprint 'general_message_routing_trace' validated. Running...
Job submitted successfully
```

To run jobs, start Redis and the MirrorNeuron runtime first:

```bash
docker run -d --name mirror-neuron-redis -p 6379:6379 redis:7
mn start
mn blueprint run general_message_routing_trace
```

Expected result:

```text
Job submitted successfully
```

## Requirements

- macOS, Linux, or WSL2.
- Elixir/Erlang for the core runtime.
- Python 3.9+ for the CLI, SDK, API, system tests, and Python-defined blueprints.
- Redis for durable runtime state.
- Docker for the easiest local Redis and Redis Sentinel tests.
- OpenShell for sandboxed worker execution.

## First Useful Task

Run the tiny message-flow blueprint first:

```bash
mn blueprint run general_message_routing_trace
mn blueprint monitor
mn list
```

Then try a pure Python-defined workflow:

```bash
python3 mn-blueprints/general_python_defined_basic/generate_bundle.py \
  --quick-test \
  --output-dir /tmp/mn-python-basic

mn validate /tmp/mn-python-basic
mn run /tmp/mn-python-basic
```

## Architecture

MirrorNeuron separates the control plane from the execution plane.

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

Read [Runtime Architecture](runtime-architecture.md) and [Cluster Architecture](cluster_architecture.md) for the full model.

## Security Basics

MirrorNeuron can run local code, create sandboxes, call external services, connect to model providers, and pass selected environment variables to worker payloads.

Before running third-party bundles or exposing a cluster:

- Keep runtime API and gRPC ports bound to trusted networks.
- Review bundle `manifest.json`, `payloads/`, `pass_env`, and runner policies.
- Use OpenShell policies for untrusted network access.
- Do not pass broad secrets into workers.
- Prefer Redis Sentinel HA over single Redis for multi-box deployments.
- Treat incoming live messages, emails, Slack events, and model outputs as untrusted input.

Read [Security Model](security.md) before operating shared or public-facing workflows.

## Where To Go Next

- [Getting Started](quickstart.md)
- [Installation](installation.md)
- [CLI Reference](cli.md)
- [Blueprints and Skills](blueprints-and-skills.md)
- [Security Model](security.md)
- [Troubleshooting](troubleshooting.md)
- [Contributing](contributing.md)

## License

See [LICENSE](LICENSE).
