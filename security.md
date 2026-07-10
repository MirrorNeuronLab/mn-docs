# Security Model

This is the canonical security and privacy guide for MirrorNeuron operators and contributors. Use it before you run a third-party bundle, add a connector, expose a listener, configure a cluster, or process real data.

## Security scope

MirrorNeuron can execute worker code, access declared files, pass selected environment variables, call models/services, persist job state, and coordinate runtime nodes. The runtime does not infer your data classification, trust policy, or allowed destination; blueprint authors and operators must define and review those boundaries.

## Before you begin

- Identify the runner for each worker: HostLocal or OpenShell.
- Read `manifest.json`, `payloads/`, policy files, service declarations, and `pass_env` entries.
- Identify every listener, external provider, and output destination.
- Keep Redis, API, gRPC, artifact sharing, and cluster traffic on trusted networks.
- Use synthetic or approved non-sensitive inputs for development and preflight.

## Assets and trust boundaries

| Boundary | What crosses it | Operator responsibility |
| --- | --- | --- |
| Operator → runtime | Bundles, commands, configuration, credentials. | Only trusted operators should submit to a shared runtime. |
| Runtime → worker payload | Manifest fields, payload files, selected environment variables, messages. | Treat payloads as application code, not trusted runtime code. |
| HostLocal worker → host | Commands, files, processes, and host credentials reachable by the process. | Use only for trusted payloads and narrow environment access. |
| OpenShell worker → sandbox | Uploads, policy-controlled commands, services, stdout/stderr, artifacts. | Review policy, mounts/uploads, service exposure, and egress. |
| Worker → external service | Prompts, files, metadata, requests, and provider credentials. | Explicitly approve data transfer and scope credentials to the worker. |
| Runtime → Redis | Jobs, events, agent snapshots, leases, bundle state, node state. | Protect Redis as a control-plane data store and use Sentinel appropriately for HA. |
| Node → node | Cluster membership, scheduling, runtime traffic, shared credentials. | Treat a cluster as one trust domain and protect membership credentials. |

## Execution safety

### HostLocal

HostLocal workers run directly on the machine. They can act with the permissions of the runtime process. Do not use HostLocal for unreviewed, third-party, or multi-tenant payloads.

### OpenShell

OpenShell provides a stronger execution boundary. It does not remove the need to review sandbox policy, uploads, mounted data, network access, environment variables, and exposed services. A sandboxed worker can still leak data or spend money through an allowed external integration.

### Cluster execution

Runtime nodes share control-plane state and membership credentials. Do not join an untrusted machine to a cluster, and change `MN_COOKIE` before using a non-local cluster. Keep Redis and runtime listeners off public networks unless a deliberate authentication and network boundary is in place.

## Local defaults and listener checks

The deployed defaults include:

```bash
export MN_REDIS_URL="redis://127.0.0.1:6379/0"
export MN_API_PORT="54001"
export MN_GRPC_PORT="55051"
```

Verify the actual local deployment rather than assuming defaults:

```bash
mn runtime health
mn runtime status
```

The model gateway commonly uses port `4000` when enabled; the Web UI default is port `55173`. See [Environment Variables](env_variables.md) for all listener and bind-host settings.

Warning: setting a listener host such as `MN_API_HOST=0.0.0.0` exposes it beyond localhost. Do so only behind a trusted network boundary with appropriate API authentication and review of CORS, reverse-proxy, and firewall configuration.

## Secrets and data movement

- Include only the minimum required environment variables in `pass_env`.
- Keep credentials out of manifests, payloads, example files, and committed configuration.
- Treat logs, run stores, backups, and bundle archives as potentially sensitive. They can contain inputs, output artifacts, configuration, event history, or derived data.
- Review model-provider and connector endpoints before assuming data remains local.
- Rotate a credential if it may have appeared in a bundle, run record, terminal transcript, or log.

## Bundle review procedure

Before launching a bundle from another person or repository:

1. Read the complete `manifest.json` and all payload files.
2. Identify HostLocal commands, OpenShell policies, uploads, service declarations, and `pass_env` values.
3. Identify model providers, external API destinations, output skills, and network listeners.
4. Validate the bundle:

   ```bash
   mn blueprint validate <bundle_folder>
   ```

5. Start with mock, dry-run, quick-test, or sample configuration when available.
6. Launch only on a trusted runtime and inspect the resulting job/events before enabling real side effects.

## Incident evidence and response

If you suspect an exposure:

1. Stop or cancel the affected job if doing so is safe: `mn job cancel <job_id>`.
2. Preserve the job ID, run ID, timestamps, sanitized configuration, and relevant event/log records.
3. Rotate potentially exposed credentials and remove access where possible.
4. Do not publish exploit details or secrets in an issue. Use the project's private security-reporting channel or contact maintainers privately.

## Contributor documentation requirements

Any change that adds a runner, file access, listener, secret path, connector, model provider, cluster behavior, or persistence behavior must update:

- this security page when the trust boundary changes;
- the relevant blueprint/component README and reference page;
- [Environment Variables](env_variables.md) for a new public configuration key; and
- [Troubleshooting](troubleshooting.md) when a predictable security or connectivity failure has a diagnostic path.

## Related pages

- [Why MirrorNeuron](why-mirrorneuron.md)
- [Core Concepts](core-concepts.md)
- [Blueprint Standard](blueprint-standard.md)
- [Redis High Availability](redis-ha.md)
- [Troubleshooting](troubleshooting.md)
