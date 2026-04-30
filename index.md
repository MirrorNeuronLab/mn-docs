# MirrorNeuron Documentation

MirrorNeuron is a durable runtime and control plane for adaptive, message-driven AI workflows. It runs on a laptop, on edge boxes, or across a small cluster.

The documentation has two goals:

- A new user should install, configure, run, and safely test MirrorNeuron in under 10 minutes.
- A new contributor should understand the architecture well enough to make a small pull request in under one hour.

## Start Here

1. [README](README.md): project overview, quick start, and doc map.
2. [Quickstart](quickstart.md): validate and run your first workflow.
3. [Installation](installation.md): install runtime dependencies and start local services.
4. [Security Model](security.md): understand what powers you are giving the runtime.
5. [Troubleshooting](troubleshooting.md): common setup, Redis, OpenShell, and cluster errors.

## Documentation Map

| Page | Type | Use it when |
| --- | --- | --- |
| [Quickstart](quickstart.md) | Tutorial | You want the shortest path to first success. |
| [Installation](installation.md) | Tutorial | You need to install Redis, OpenShell, Elixir, and Python tooling. |
| [Examples](examples.md) | Tutorial | You want to choose the right checked-in blueprint. |
| [Cluster Guide](cluster.md) | How-to | You need to start or inspect a multi-box runtime. |
| [Redis High Availability](redis-ha.md) | How-to | You need Redis Sentinel failover. |
| [Monitor Guide](monitor.md) | How-to | You need to inspect live jobs and events. |
| [CLI Reference](cli.md) | Reference | You need exact CLI commands and options. |
| [Environment Variables](env_variables.md) | Reference | You need config names, defaults, and effects. |
| [API Reference](api.md) | Reference | You need HTTP or Elixir API shapes. |
| [Job Bundle Format](bundle.md) | Reference | You are writing or validating `manifest.json`. |
| [Python SDK](SDK.md) | Reference | You want to compile Python workflow definitions into bundles. |
| [Runtime Architecture](runtime-architecture.md) | Explanation | You want the control-plane/execution-plane mental model. |
| [Cluster Architecture](cluster_architecture.md) | Explanation | You want leader, node, and relocation behavior. |
| [Reliability Guide](reliability.md) | Explanation | You want recovery, leases, backpressure, and retention behavior. |
| [Security Model](security.md) | Explanation | You need trust boundaries and safe defaults. |
| [Blueprints and Skills](blueprints-and-skills.md) | How-to | You are extending MirrorNeuron safely. |
| [Testing](testing.md) | Reference | You need the test matrix and commands. |
| [Contributing](contributing.md) | Tutorial | You are preparing a pull request. |
| [Documentation Style](documentation-style.md) | Reference | You are editing docs. |

## First Safe Workflow

From the monorepo root:

```bash
mn validate mn-blueprints/general_test_message_flow
```

Expected output:

```text
Job bundle at 'mn-blueprints/general_test_message_flow' is valid.
Graph ID: general_test_message_flow_v1
Nodes count: 3
```

Run it after Redis and the runtime are started:

```bash
mn run mn-blueprints/general_test_message_flow
```

Expected output:

```text
Job submitted successfully
```

## Security Quick Read

MirrorNeuron can run local commands, create sandboxes, call APIs, pass selected secrets into workers, and coordinate jobs across boxes. Before using it in a shared or production environment:

- Review every bundle before running it.
- Keep `pass_env` narrow.
- Prefer OpenShell over HostLocal for less-trusted worker code.
- Keep Redis protected and use Redis Sentinel for multi-box reliability.
- Change `MIRROR_NEURON_COOKIE` for any non-local cluster.
- Bind API/gRPC listeners only to trusted networks.

Read [Security Model](security.md) for the full checklist.

## Contributor Path

1. Read [Runtime Architecture](runtime-architecture.md).
2. Run [Testing](testing.md) commands.
3. Make a small focused change.
4. Update docs when behavior changes.
5. Use the [Contributing](contributing.md) checklist before opening a PR.
