# Security Model

MirrorNeuron is powerful because it can run workflows close to real data, local tools, worker code, model providers, and external services. That also means every operator should understand what the runtime can access and where trust boundaries sit.

## What MirrorNeuron Can Access

Depending on configuration and bundle contents, MirrorNeuron can access:

- Redis state used for jobs, events, agent snapshots, leases, bundle archives, and node state.
- Local files included in a job bundle under `payloads/`.
- Local commands executed by the `HostLocal` runner.
- OpenShell sandboxes, uploaded files, stdout, stderr, and sandbox artifacts.
- Environment variables explicitly listed in a node or blueprint `pass_env`.
- Model provider APIs and third-party services used by skills or worker payloads.
- Cluster peers reachable through BEAM distribution and configured network ports.
- Live inputs from daemon workflows, Slack/email integrations, sensors, or API clients.

## Trust Boundaries

```text
User / operator
      |
      v
CLI, API, SDK, Web UI
      |
      v
MirrorNeuron BEAM runtime
      |
      +--> Redis durable state
      +--> Cluster peer nodes
      +--> HostLocal commands
      +--> OpenShell sandboxes
      +--> Bundle payload files
      +--> External APIs and model providers
```

Important boundaries:

- **Operator to runtime:** only trusted operators should submit bundles to shared runtimes.
- **Runtime to worker payload:** bundle code is application code, not trusted runtime code.
- **Worker payload to local machine:** `HostLocal` runs directly on the host, so use it only for trusted payloads.
- **Worker payload to sandbox:** OpenShell provides a stronger boundary, but policies and uploads still matter.
- **Worker payload to external services:** outgoing calls can leak data or spend money.
- **Cluster node to cluster node:** all nodes sharing the Erlang cookie can participate in the distributed runtime.
- **Redis to runtime:** Redis is the lease and state authority; protect it like a control-plane database.

## Safe Defaults

Use these defaults for local development:

```bash
export MIRROR_NEURON_REDIS_URL="redis://127.0.0.1:6379/0"
export MIRROR_NEURON_API_PORT="4000"
export MIRROR_NEURON_GRPC_PORT="50051"
export MIRROR_NEURON_EXECUTOR_MAX_CONCURRENCY="4"
```

Recommended habits:

- Keep API and gRPC listeners on localhost for single-machine development.
- Use a unique `MIRROR_NEURON_REDIS_NAMESPACE` for tests.
- Use OpenShell for code you do not fully trust.
- Keep `pass_env` narrow and explicit.
- Store provider keys in environment variables, not in manifests or payload files.
- Review every third-party bundle before running it.
- Use Redis Sentinel mode for multi-box reliability.

## Dangerous Configurations

### Running HostLocal for Untrusted Payloads

Risk:

```json
{
  "runner": "host_local",
  "command": "python3 worker.py"
}
```

Safer alternative:

- Use OpenShell for untrusted or shared-environment execution.
- Keep HostLocal for trusted, local-only, deterministic helper code.

### Passing Broad Secrets

Risk:

```json
{
  "pass_env": ["AWS_ACCESS_KEY_ID", "AWS_SECRET_ACCESS_KEY", "GEMINI_API_KEY"]
}
```

Safer alternative:

- Pass only the one key a worker needs.
- Use dry-run mode for email, Slack, and external delivery tests.
- Rotate keys if a bundle or log may have exposed them.

### Exposing Runtime Ports To Untrusted Networks

Risk:

```bash
export MIRROR_NEURON_API_HOST="0.0.0.0"
```

Safer alternative:

- Bind to localhost unless a trusted network and auth boundary are in place.
- Require API tokens for non-local API access.
- Put the API behind a trusted reverse proxy if exposing it beyond a development machine.

### Two-Box Sentinel Quorum In Production

Risk:

```bash
export MIRROR_NEURON_REDIS_SENTINEL_QUORUM="1"
```

Safer alternative:

- Use at least three Sentinel voters for production.
- Treat two-box quorum `1` as a development smoke-test setup only.

## Bundle Review Checklist

Before running a bundle from another person or repository:

- Read `manifest.json`.
- Inspect `payloads/` for scripts, package files, templates, and data.
- Check `runner`, `command`, `uploads`, `env`, and `pass_env`.
- Check OpenShell `policy` files.
- Check whether the workflow is a daemon.
- Check whether workers call external APIs or model providers.
- Check retry policies and backpressure settings.
- Run `mn validate <bundle>` before `mn run <bundle>`.

## Skill Review Checklist

Before installing or publishing a skill:

- Read the full README or skill instructions.
- Check commands the skill asks workers or operators to run.
- Check network calls and API destinations.
- Check file access patterns.
- Avoid hidden install scripts.
- Run tests in a sandbox or disposable environment.

## Reporting Vulnerabilities

If you find a vulnerability, do not open a public issue with exploit details. Use the project's GitHub security reporting channel or contact the maintainers privately.

Include:

- affected component
- reproduction steps
- expected and actual behavior
- impact
- suggested fix, if known

## Related Pages

- [Installation](installation.md)
- [Blueprints and Skills](blueprints-and-skills.md)
- [Redis High Availability](redis-ha.md)
- [Troubleshooting](troubleshooting.md)
