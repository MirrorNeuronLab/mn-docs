# Develop MirrorNeuron Core

Use this page when you are changing the Elixir/BEAM runtime in `MirrorNeuron/`. It complements the workspace-level ownership map in [Component Guide](component-guide.md); it does not replace component-local tests or the runtime architecture reference.

## Reader and scope

- **Reader:** contributor modifying MirrorNeuron Core behavior.
- **Outcome:** make a focused Core change, run the owning test suite, and update the required cross-component documentation.
- **In scope:** Core orchestration, persistence, scheduling, runners, gRPC, and cluster behavior.
- **Out of scope:** CLI/API presentation changes owned by `mn-cli` or `mn-api`, and blueprint-specific payload behavior.

## Before you begin

- Work from `MirrorNeuron/`.
- Install the Elixir/Erlang versions required by the Core project.
- Start Redis when the focused test requires durable runtime state.
- Read the owning module and its nearest tests before changing an external contract.

## Development loop

```bash
cd MirrorNeuron
mix deps.get
mix format
mix test
```

When a focused test depends on a local Redis instance, start one only if the component test setup does not provision it:

```bash
docker run -d --name mirror-neuron-redis -p 6379:6379 redis:7
```

Warning: do not remove a Redis container used by another developer runtime. Use a dedicated namespace or disposable test environment for Core tests that mutate durable state.

## Architectural boundaries

MirrorNeuron Core owns orchestration, state, scheduling, supervision, and runtime coordination. Workers execute through the runner selected by the workflow:

- HostLocal worker code runs on the host and is appropriate only for trusted payloads.
- OpenShell worker code runs through the sandbox integration and remains subject to its policy and service boundaries.
- SDK/API/CLI layers own blueprint catalog resolution and model preparation before Core receives concrete runtime requirements.

Read [Runtime Architecture](runtime-architecture.md), [Reliability Guide](reliability.md), and [Security Model](security.md) before changing a lifecycle, recovery, runner, or trust boundary.

## Locate the owning code

| Change | Start with |
| --- | --- |
| Runtime configuration and startup validation | `MirrorNeuron/lib/mirror_neuron/config/` |
| Scheduling, leases, and recovery | `MirrorNeuron/lib/mirror_neuron/scheduler.ex`, `execution/`, and cluster modules |
| Job lifecycle and durable state | `MirrorNeuron/lib/mirror_neuron/runtime/` and persistence modules |
| Agent behavior and built-ins | `MirrorNeuron/lib/mirror_neuron/agent*` and `builtins/` |
| HostLocal, Docker, or OpenShell execution | `MirrorNeuron/lib/mirror_neuron/runner/` and `sandbox/` |
| gRPC contract handling | `MirrorNeuron/lib/mirror_neuron_grpc/` |

Do not add domain-specific business logic to Core when it belongs in a blueprint payload, skill, or agent template.

## Required documentation updates

| Core change | Documentation to update |
| --- | --- |
| Lifecycle, scheduler, lease, retry, recovery, or persistence behavior | `runtime-architecture.md`, `reliability.md`, and troubleshooting if the failure is observable. |
| New/changed environment variable | `env_variables.md`, configuration tests, and the docs-site configuration reference. |
| gRPC/API-visible behavior | `api.md`, SDK/CLI references, and relevant route/client tests. |
| Runner, file, secret, network, or sandbox behavior | `security.md`, runner guidance, and the affected blueprint documentation. |
| User-visible behavior | the detailed page in `mn-docs` and the concise matching page in `mn-doc-site/content/docs`. |

## Related pages

- [Component Guide](component-guide.md)
- [Runtime Architecture](runtime-architecture.md)
- [Reliability Guide](reliability.md)
- [Testing](testing.md)
- [Documentation Standard](documentation-style.md)
