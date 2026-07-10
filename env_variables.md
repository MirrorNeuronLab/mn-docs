# Runtime Configuration Reference

This is the canonical internal reference for shared MirrorNeuron configuration. It covers the CLI, FastAPI gateway, runtime connection, Web UI, local models, and blueprint-catalog resolution. Blueprint-specific configuration belongs in the owning manifest and configuration files.

## Sources of truth

- CLI parsing/defaults: `mn-cli/mn_cli/config.py`.
- API parsing/defaults: `mn-api/mn_api/config_schema.py` and `mn-api/mn_api/config.py`.
- Blueprint catalog resolution: `mn-python-sdk/mn_sdk/blueprint_source.py`.
- Deployment/runtime publication: `mn-cli/mn_cli/runtime/server.py`, `mn-deploy/install.sh`, and `mn-deploy/docker-compose.yml`.

Update this page and `mn-doc-site/content/docs/env_variables.mdx` whenever a parser, default, validation rule, or secret classification changes.

## Inspect before changing state

```bash
mn runtime status
mn runtime health
```

Save sanitized output before changing listener, connection, catalog, model, or credential configuration. Do not commit `~/.mn/docker-compose.env`, endpoint files, or secrets.

## Runtime state and client connection

| Variable | Default | Behavior |
| --- | --- | --- |
| `MN_ENV` | `dev` | CLI/API environment. Use `prod` only with intentional authentication and secret configuration. |
| `MN_HOME` | `~/.mn` | State root for endpoints, logs, models, and default run records. |
| `MN_GRPC_TARGET` | `localhost:55051` in CLI | Core gRPC target. |
| `MN_GRPC_TIMEOUT_SECONDS` | `10` | Per-RPC timeout. |
| `MN_GRPC_AUTH_TOKEN` | unset | Sensitive gRPC bearer token. |
| `MN_GRPC_ADMIN_TOKEN` | unset | Sensitive administrative token. |
| `MN_REDIS_URL` | deployment-specific | Runtime state-store URL. |
| `MN_REDIS_NAMESPACE` | `mirror_neuron` | Redis namespace; use a separate value for isolated tests. |
| `MN_COOKIE` | deployment-specific | Sensitive cluster credential. Change before non-local cluster use. |

The deployed gRPC endpoint is normally published on port `55051`; the Core container can use a distinct internal port. Confirm actual endpoints with `mn runtime status` after custom deployment.

## FastAPI gateway and Web UI

| Variable | Default | Behavior |
| --- | --- | --- |
| `MN_API_HOST` | `localhost` | FastAPI bind host. |
| `MN_API_PORT` | `54001` | FastAPI bind port. |
| `MN_API_BASE_URL` | unset | External API base URL; must be absolute HTTP(S) when set. |
| `MN_API_TOKEN` | unset | Sensitive bearer token for protected API deployments. |
| `MN_API_REQUEST_SIZE_LIMIT_BYTES` | `5242880` | Maximum request body size. |
| `MN_API_CORS_ALLOW_ORIGINS` | unset | Comma-separated CORS allowlist. |
| `MN_WEB_UI_HOST` | `localhost` | Web UI bind host. |
| `MN_WEB_UI_PORT` | `55173` | Web UI bind port. |
| `MN_WEB_UI_API_BASE_URL` | unset | Web UI upstream API URL. |
| `MN_WEB_UI_PROXY_TIMEOUT_SECONDS` | `30` | Web UI upstream timeout in seconds. |

Warning: CORS does not authenticate requests. A non-localhost bind requires firewall, reverse-proxy, authentication, and security-documentation review.

## Blueprint catalog resolution

| Variable | Default | Behavior |
| --- | --- | --- |
| `MN_BLUEPRINT_SOURCE` | `github` | Must be `github` or `local`. |
| `MN_BLUEPRINT_REPO` | SDK default repository for Git source | Must be a Git URL when source is `github`. |
| `MN_BLUEPRINT_LOCAL` | unset | Required for local source; must be an existing directory containing `index.json`. |
| `MN_BLUEPRINT_REPO_CACHE` | `~/.cache/mirror-neuron/blueprint-repos` | Catalog checkout cache root. |

```bash
export MN_BLUEPRINT_SOURCE="local"
export MN_BLUEPRINT_LOCAL="/absolute/path/to/blueprint-catalog"
mn blueprint list
```

## Models, launch controls, and logs

| Variable | Default | Behavior |
| --- | --- | --- |
| `MN_LLM_PROVIDER` | blueprint-specific | Model provider. |
| `MN_LLM_MODEL` | blueprint-specific | Model name passed to the worker/provider. |
| `MN_LLM_RUNTIME_MODEL` | blueprint-specific | Runtime-managed model reference. |
| `MN_LLM_API_BASE` | provider-specific | OpenAI-compatible API base when used. |
| `MN_LLM_API_KEY` | unset | Sensitive provider key. |
| `MN_PRE_LAUNCH_TIMEOUT_SECONDS` | `30` | Pre-launch timeout in seconds. |
| `MN_POST_LAUNCH_TIMEOUT_SECONDS` | `10` | Post-launch timeout in seconds. |
| `MN_LOG_LEVEL` | `INFO` | Process log level. |
| `MN_LOGS_ROOT` | `~/.mn/logs` | Default log root. |
| `MN_CLI_OUTPUT` | `rich` | CLI rendering mode; `plain` disables Rich formatting. |

Validate models and blueprint requirements with `mn model doctor <model-id>` and `mn blueprint validate <folder>`. Do not use `--force` as a routine fix for a failed hardware check.

## Contributor verification

After changing shared configuration, run `mn runtime health` and `mn runtime status`. Also run `mn blueprint list` for catalog changes, `mn model doctor <model-id>` for model changes, and API health checks for API configuration changes.

Configuration changes require parser/schema tests, secret-redaction review where applicable, this reference, the docs-site reference, and a documentation-site type check.

## Related pages

- [CLI Reference](cli.md)
- [API Reference](api.md)
- [Model Runtime](model-runtime.md)
- [Cluster Guide](cluster.md)
- [Security Model](security.md)
