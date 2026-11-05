# Runtime Configuration Reference

This is the canonical internal reference for shared MirrorNeuron configuration. It covers the CLI, FastAPI gateway, runtime connection, Web UI, local models, and blueprint-catalog resolution. Blueprint-specific configuration belongs in the owning manifest and configuration files.

## Sources of truth

- CLI parsing/defaults: `mn-cli/mn_cli/config.py`.
- API parsing/defaults: `mn-api/mn_api/config_schema.py` and `mn-api/mn_api/config.py`.
- Blueprint catalog resolution: `mn-python-sdk/mn_sdk/blueprint_source.py`.
- Deployment/runtime publication: `mn-cli/mn_cli/runtime/server.py`, `mn-deploy/install.sh`, and `mn-deploy/docker-compose.yml`.
- Core defaults and validation: `MirrorNeuron/lib/mirror_neuron/config/schema.ex`,
  `config.ex`, and `execution/lease_manager.ex`.

Update this page and `mn-doc-site/content/docs/env_variables.mdx` whenever a parser, default, validation rule, or secret classification changes.

## Inspect before changing state

```bash
mn runtime status
mn runtime doctor
```

Save sanitized output before changing listener, connection, catalog, model, or credential configuration. Do not commit `~/.mn/docker-compose.env`, endpoint files, or secrets.

## Runtime state and client connection

| Variable                  | Default                  | Behavior                                                                                       |
| ------------------------- | ------------------------ | ---------------------------------------------------------------------------------------------- |
| `MN_ENV`                  | `dev`                    | CLI/API environment. Use `prod` only with intentional authentication and secret configuration. |
| `MN_HOME`                 | `~/.mn`                  | State root for endpoints, logs, models, and default run records.                               |
| `MN_GRPC_TARGET`          | `localhost:55051` in CLI | Core gRPC target.                                                                              |
| `MN_GRPC_TIMEOUT_SECONDS` | `10`                     | Per-RPC timeout.                                                                               |
| `MN_GRPC_AUTH_TOKEN`      | unset                    | Sensitive gRPC bearer token.                                                                   |
| `MN_GRPC_ADMIN_TOKEN`     | unset                    | Sensitive administrative token.                                                                |
| `MN_REDIS_URL`            | deployment-specific      | Runtime state-store URL.                                                                       |
| `MN_REDIS_NAMESPACE`      | `mirror_neuron`          | Redis namespace; use a separate value for isolated tests.                                      |
| `MN_COOKIE`               | deployment-specific      | Sensitive cluster credential. Change before non-local cluster use.                             |

The deployed gRPC endpoint is normally published on port `55051`; the Core container can use a distinct internal port. Confirm actual endpoints with `mn runtime status` after custom deployment.

`MN_COOKIE` applies to BEAM distribution where configured. Independent federated
Cores use authenticated peer credentials and distinct Redis stores; they do not
share an Erlang cookie as their federation authentication mechanism.

## Execution capacity and readiness

These are Core process settings. Configure them in the owning runtime's
environment before startup; exporting them only in a client terminal does not
reconfigure an already-running container. Review/restart through the deployment's
normal maintenance procedure, then inspect `mn runtime status` and the resulting
resource/worker state. Preserve previous values for rollback.

| Variable                                  | Default | Behavior                                                                                             |
| ----------------------------------------- | ------- | ---------------------------------------------------------------------------------------------------- |
| `MN_EXECUTOR_MAX_CONCURRENCY`             | `4`     | Default owner-local executor pool slot capacity; positive integer.                                   |
| `MN_EXECUTOR_POOL_CAPACITIES`             | unset   | Comma-separated positive pool capacities, for example `default=4,gpu=1,io=8`. Overrides named pools. |
| `MN_AUTO_PORT_START`                      | `49152` | First automatic allocation port, inclusive.                                                          |
| `MN_AUTO_PORT_END`                        | `65535` | Last automatic allocation port, inclusive; the range must ascend within `1..65535`.                  |
| `MN_SHARED_STORAGE_READY_TIMEOUT_SECONDS` | `1800`  | Owner-side staged-input readiness deadline before source dispatch.                                   |

Executor slots bound invocations. Run CPU/RAM/GPU reservations are separately
declared in `execution.json.policies.resource_allocation`; workflow action units
use `policies.workflow_budgets`. Neither is configured by these pool settings.
Automatic allocation does not publish a listener or open a firewall, and shared
run profiles require fixed ports. See [Resources and Devices](resources-and-devices.md)
and [Runtime Architecture](runtime-architecture.md#workflow-action-allowances).

## FastAPI gateway and Web UI

| Variable                          | Default                | Behavior                                                                                                                                 |
| --------------------------------- | ---------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| `MN_API_HOST`                     | `localhost`            | FastAPI bind host. The installer defaults it to `0.0.0.0` when the Compose Web UI is enabled so the container can proxy to the host API. |
| `MN_API_PORT`                     | `54001`                | FastAPI bind port.                                                                                                                       |
| `MN_API_BASE_URL`                 | unset                  | External API base URL; must be absolute HTTP(S) when set.                                                                                |
| `MN_API_TOKEN`                    | unset                  | Sensitive bearer token for protected API deployments.                                                                                    |
| `MN_API_REQUEST_SIZE_LIMIT_BYTES` | `5242880`              | Maximum request body size.                                                                                                               |
| `MN_API_CORS_ALLOW_ORIGINS`       | unset                  | Comma-separated CORS allowlist.                                                                                                          |
| `MN_WEB_UI_HOST`                  | `localhost`            | Web UI endpoint host reported by the CLI.                                                                                                |
| `MN_WEB_UI_PORT`                  | `55173`                | Web UI published/container port.                                                                                                         |
| `MN_WEB_UI_BIND_HOST`             | `127.0.0.1`            | Compose host address for publishing the Web UI port.                                                                                     |
| `MN_WEB_UI_SOURCE_MODE`           | installer-selected     | `package` for binary installs; `source` for local/GitHub installs.                                                                       |
| `MN_WEB_UI_SOURCE_MOUNT`          | installer-selected     | Read-only source mount consumed by the Compose Web UI service.                                                                           |
| `MN_WEB_UI_PACKAGE_VERSION`       | selected release       | Published package version installed inside the Compose service in package mode.                                                          |
| `MN_WEB_UI_API_HOST`              | `host.docker.internal` | API host used by the Web UI container proxy.                                                                                             |
| `MN_WEB_UI_API_BASE_URL`          | unset                  | Web UI upstream API URL.                                                                                                                 |
| `MN_WEB_UI_PROXY_TIMEOUT_SECONDS` | `30`                   | Web UI upstream timeout in seconds.                                                                                                      |

Warning: CORS does not authenticate requests. A non-localhost bind requires firewall, reverse-proxy, authentication, and security-documentation review.

## Blueprint catalog resolution

| Variable                  | Default                                  | Behavior                                                                          |
| ------------------------- | ---------------------------------------- | --------------------------------------------------------------------------------- |
| `MN_BLUEPRINT_SOURCE`     | `github`                                 | Must be `github` or `local`.                                                      |
| `MN_BLUEPRINT_REPO`       | SDK default repository for Git source    | Must be a Git URL when source is `github`.                                        |
| `MN_BLUEPRINT_LOCAL`      | unset                                    | Required for local source; must be an existing directory containing `index.json`. |
| `MN_BLUEPRINT_REPO_CACHE` | `~/.cache/mirror-neuron/blueprint-repos` | Catalog checkout cache root.                                                      |

```bash
export MN_BLUEPRINT_SOURCE="local"
export MN_BLUEPRINT_LOCAL="/absolute/path/to/blueprint-catalog"
mn blueprint list
```

## Models, launch controls, and logs

| Variable                         | Default            | Behavior                                              |
| -------------------------------- | ------------------ | ----------------------------------------------------- |
| `MN_LLM_PROVIDER`                | blueprint-specific | Model provider.                                       |
| `MN_LLM_MODEL`                   | blueprint-specific | Model name passed to the worker/provider.             |
| `MN_LLM_RUNTIME_MODEL`           | blueprint-specific | Runtime-managed model reference.                      |
| `MN_LLM_API_BASE`                | provider-specific  | OpenAI-compatible API base when used.                 |
| `MN_LLM_API_KEY`                 | unset              | Sensitive provider key.                               |
| `MN_PRE_LAUNCH_TIMEOUT_SECONDS`  | `30`               | Pre-launch timeout in seconds.                        |
| `MN_POST_LAUNCH_TIMEOUT_SECONDS` | `10`               | Post-launch timeout in seconds.                       |
| `MN_LOG_LEVEL`                   | `INFO`             | Process log level.                                    |
| `MN_LOGS_ROOT`                   | `~/.mn/logs`       | Default log root.                                     |
| `MN_CLI_OUTPUT`                  | `rich`             | CLI rendering mode; `plain` disables Rich formatting. |

Validate models and blueprint requirements with `mn model doctor <model-id>` and `mn blueprint validate <folder>`. Do not use `--force` as a routine fix for a failed hardware check.

## Shared storage and node-local caches

| Variable                               | Default                                | Behavior                                                                                                                                                                   |
| -------------------------------------- | -------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `MN_SHARED_STORAGE_ROOT`               | `$MN_HOME/shared`                      | Synchronized job storage. Multi-node submissions and executable bundle cache entries remain here.                                                                          |
| `MN_BLUEPRINT_PYTHON_ENVS_DIR`         | `$MN_HOME/cache/blueprint-python-envs` | Node-local derived HostLocal virtual-environment cache. An explicit path remains supported, but `mn blueprint doctor` warns when that path is inside synchronized storage. |
| `MN_CHECKPOINT_ROOT`                   | `$MN_HOME/checkpoints`                 | Node-local compatibility checkpoint directory. Redis remains the recovery authority.                                                                                       |
| `MN_SYNCTHING_ENABLED`                 | `auto`                                 | Starts and configures the shared-storage Syncthing sidecar unless explicitly disabled.                                                                                     |
| `MN_SYNCTHING_REQUIRED`                | unset                                  | When truthy, fail startup or join instead of warning when Syncthing cannot be prepared.                                                                                    |
| `MN_SYNCTHING_RESCAN_INTERVAL_SECONDS` | `3600`                                 | Periodic fallback rescan interval. Invalid and non-positive runtime values fall back to `3600`; filesystem watching remains enabled with a 10-second coalescing delay.     |

MirrorNeuron installs rooted Syncthing ignores for `blueprint-python-envs`,
`blueprint-python-sources`, and `checkpoints` separately on every peer while
preserving operator-defined ignore lines. The `.stignore` file is node-local
and is not replicated by Syncthing.

There is no automatic submission retention. Inputs, intermediate artifacts, and
outputs remain synchronized until the existing job or run deletion workflow
removes them. See [Cluster Guide](cluster.md#shared-blobs-are-optional)
for the replication and node-local cache boundary.

## Contributor verification

After changing shared configuration, run `mn runtime status` and `mn runtime doctor`. Also run `mn blueprint list` for catalog changes, `mn model doctor <model-id>` for model changes, and API health checks for API configuration changes.

Configuration changes require parser/schema tests, secret-redaction review where applicable, this reference, the docs-site reference, and a documentation-site type check.

## Related pages

- [CLI Reference](cli.md)
- [API Reference](api.md)
- [Model Runtime](model-runtime.md)
- [Cluster Guide](cluster.md)
- [Security Model](security.md)
