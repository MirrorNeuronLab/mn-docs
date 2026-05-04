# Environment Variables

This page documents the environment variables used by Mirror Neuron, the CLI, the Python SDK/API, shared skills, and the checked-in blueprints.

Boolean values generally accept `1`, `true`, `yes`, or `on` for true and `0`, `false`, `no`, or `off` for false when parsed by the shared config helpers. Some legacy toggles only check a smaller set; those differences are called out below.

## Run command logging

These variables are read by the shared CLI runner used by both `mn run <bundle>` and `mn blueprint run <name>`. They are evaluated on the client side and do not need to be listed in a blueprint manifest `pass_env`.

Run artifacts are written to `/tmp/mn_<job_id>/`:

| Variable | Default | Usage |
| --- | --- | --- |
| `MN_RUN_DETACH_LOG_SECONDS` | `30` | Seconds to keep polling job events after the submit stream detaches. Can be overridden per command with `--follow-seconds`. |
| `MN_RUN_EVENT_LOG_MAX_BYTES` | `10485760` | Maximum size of `/tmp/mn_<job_id>/events.log` before rotating. |
| `MN_RUN_EVENT_LOG_BACKUP_COUNT` | `5` | Number of rotated `events.log.N` files to keep. |
| `MN_RUN_LOG_LEVEL` | `INFO` | Log level for `/tmp/mn_<job_id>/run.log`. |
| `MN_RUN_LOG_MAX_BYTES` | `2097152` | Maximum size of `/tmp/mn_<job_id>/run.log` before rotating. |
| `MN_RUN_LOG_BACKUP_COUNT` | `5` | Number of rotated `run.log.N` files to keep. |
| `MN_RUN_LOG_POLL_INTERVAL_SECONDS` | `0.5` | Poll interval used while collecting post-detach events. |

Example:

```bash
MN_RUN_DETACH_LOG_SECONDS=10 \
MN_RUN_LOG_LEVEL=DEBUG \
MN_RUN_EVENT_LOG_MAX_BYTES=5242880 \
mn blueprint run general_stream_backpressure_control_loop
```

## CLI and SDK connectivity

These variables control how CLI, SDK, and API clients connect to the core gRPC runtime.

| Variable | Default | Used by | Usage |
| --- | --- | --- | --- |
| `MN_GRPC_TARGET` | `localhost:50051` | CLI, Python SDK, API | gRPC target for the core runtime. |
| `MN_CORE_GRPC_TARGET` | `localhost:50051` | API | Fallback gRPC target used by the API when `MN_GRPC_TARGET` is unset. |
| `MN_GRPC_TIMEOUT_SECONDS` | `10` | CLI, Python SDK, API | Per-RPC timeout. `0`, `none`, or an empty value disables the timeout. |
| `MN_GRPC_AUTH_TOKEN` | empty | CLI, Python SDK | Optional bearer token metadata for protected gRPC gateways. |
| `MN_CLI_OUTPUT` | `rich` | CLI | Set to `plain` to avoid Rich output formatting. |

## CLI, API, SDK, and skill logs

These variables control process-level log files. They are separate from per-run logs under `/tmp/mn_<job_id>/`.

| Variable | Default | Used by | Usage |
| --- | --- | --- | --- |
| `MN_LOG_LEVEL` | `INFO` | CLI, API, SDK, shared skills, some blueprints | Process logger level. |
| `MN_LOG_MAX_BYTES` | `1048576` | CLI, API, SDK, shared skills, some blueprints | Maximum log file size before rotation. |
| `MN_LOG_BACKUP_COUNT` | `5` | CLI, API, SDK, shared skills, some blueprints | Number of rotated process log files to keep. |
| `MN_CLI_LOG_PATH` | `~/.mn/logs/cli.log` | CLI | CLI process log path. |
| `MN_API_LOG_PATH` | `~/.mn/logs/api.log` | API | API process log path. |
| `MN_SDK_LOG_PATH` | `~/.mn/logs/sdk.log` | Python SDK | SDK process log path. |
| `MN_SKILL_LOG_PATH` | `~/.mn/logs/skills.log` | Shared skills | Shared skill log path. |
| `MN_BLUEPRINT_LOG_PATH` | `/tmp/mn-business-email.log` | Business email blueprint | Business email blueprint log path. |
| `MN_BLUEPRINT_LOG_LEVEL` | unset | Blueprint manifest mappings | Generic blueprint log-level input mapped by many checked-in manifests. |

## Web UI

These variables are read by `mn-web-ui`.

| Variable | Default | Usage |
| --- | --- | --- |
| `MN_WEB_API_BASE_URL` | `/api/v1` | REST API base URL for the web UI. |
| `MN_WEB_API_TOKEN` | empty | Optional bearer token for protected API instances. |

## Core runtime

These variables are read by the Elixir core runtime.

| Variable | Default | Usage |
| --- | --- | --- |
| `MN_ENV` | `dev` | Runtime environment. Must be `dev`, `test`, or `prod`. Production requires a non-default `MN_COOKIE`. |
| `MN_REDIS_URL` | `redis://127.0.0.1:6379/0` | Redis URL used by the runtime. Must use `redis://` or `rediss://`. |
| `MN_REDIS_NAMESPACE` | `mirror_neuron` | Redis key namespace. Use a unique value for isolated test runs. |
| `MN_REDIS_HA_MODE` | `single` | Redis mode. Use `single` for `MN_REDIS_URL` or `sentinel` for Redis Sentinel HA. |
| `MN_REDIS_SENTINELS` | empty | Comma-separated Sentinel endpoints such as `192.168.4.29:26379,192.168.4.35:26379`. Required when `MN_REDIS_HA_MODE=sentinel`. |
| `MN_REDIS_SENTINEL_MASTER` | `mirror-neuron` | Sentinel master name to resolve. |
| `MN_REDIS_SENTINEL_HOST_MAP` | empty | Optional comma-separated hostname rewrite map, such as `host.docker.internal=127.0.0.1`, for NAT or Docker test environments. |
| `MN_REDIS_DB` | `0` | Redis database number used in Sentinel mode. |
| `MN_REDIS_USERNAME` | unset | Optional Redis ACL username. |
| `MN_REDIS_PASSWORD` | unset | Optional Redis password. |
| `MN_REDIS_SENTINEL_USERNAME` | unset | Optional Sentinel ACL username. |
| `MN_REDIS_SENTINEL_PASSWORD` | unset | Optional Sentinel password. |
| `MN_REDIS_WAIT_REPLICAS` | `0` | Optional Redis `WAIT` acknowledgement count after durable writes. Use `1` or higher for reliability-first HA writes. |
| `MN_REDIS_WAIT_TIMEOUT_MS` | `100` | Timeout for Redis `WAIT` durable-write acknowledgement. |
| `MN_REDIS_RECONNECT_ATTEMPTS` | `10` | Reconnect/retry attempts for reconnectable Redis failures. |
| `MN_REDIS_RECONNECT_BACKOFF_MS` | `250` | Initial reconnect backoff in milliseconds. |
| `MN_REDIS_RECONNECT_MAX_BACKOFF_MS` | `2000` | Maximum reconnect backoff in milliseconds. |
| `MN_COOKIE` | `mirrorneuron` | Erlang distribution cookie. Must be changed in `prod`. |
| `MN_OPENSHELL_BIN` | `openshell` | OpenShell executable name or path. |
| `MN_TEMP_DIR` | `/tmp/mirror_neuron` | Runtime temporary directory. |
| `MN_API_ENABLED` | `true` | Enables the runtime's built-in API listener. False values are `0`, `false`, `FALSE`, `False`, or empty. |
| `MN_API_PORT` | `4000` in core, `4001` in Python API | HTTP API port. The core runtime and Python API have different defaults. |
| `MN_GRPC_PORT` | `50051` | Core gRPC server port. |
| `MN_NODE_ROLE` | `runtime` | Runtime node role. `control` starts only shared/control services; other values start runtime workers. |
| `MN_NODE_NAME` | set by launch scripts | Erlang node name, typically `mirror_neuron@<ip>` or `mn1@<ip>`. |
| `MN_CLUSTER_NODES` | empty | Comma-separated Erlang node names for clustering. |
| `MN_DIST_PORT` | `4370` in cluster scripts | Erlang distribution port used by cluster helper scripts. |
| `MN_REDIS_SENTINEL_PORT` | `26379` in cluster scripts | Local Sentinel port used by Redis HA helper scripts. |
| `MN_REDIS_SENTINEL_QUORUM` | `1` in cluster scripts | Sentinel quorum used by Redis HA helper scripts. Use at least three Sentinel voters for production. |
| `MN_REDIS_HA_AUTOCONFIG` | `1` in `start_cluster_node.sh` | When Sentinel mode is enabled, controls whether the cluster start script runs `scripts/redis_ha.sh join`. |
| `MN_BUNDLES_DIR` | unset | Directory scanned for registered bundles on runtime startup. |
| `MN_BUNDLE_RELOAD_MODE` | manifest value | Overrides bundle reload mode for scanned bundles. |
| `MN_BUNDLE_RELOAD_INTERVAL_SECONDS` | manifest value | Overrides bundle reload interval for scanned bundles. |

## Runtime limits and admission control

| Variable | Default | Usage |
| --- | --- | --- |
| `MN_EXECUTOR_MAX_CONCURRENCY` | `4` in runtime, `50` in some container launch helpers, `2` in cluster scripts | Default executor lease capacity for the `default` pool. |
| `MN_EXECUTOR_POOL_CAPACITIES` | unset | Comma-separated pool capacities, such as `default=4,gpu=1`. |
| `MN_DEFAULT_MAX_AGENT_QUEUE_DEPTH` | `100` | Default max mailbox depth before an agent is saturated. |
| `MN_DEFAULT_AGENT_QUEUE_HIGH_WATERMARK` | `75` | Default queue depth at which pressure is reported. Must be `<= MN_DEFAULT_MAX_AGENT_QUEUE_DEPTH`. |
| `MN_DEFAULT_AGENT_QUEUE_LOW_WATERMARK` | `25` | Default queue depth at which pressure clears. Must be `<= MN_DEFAULT_AGENT_QUEUE_HIGH_WATERMARK`. |
| `MN_RESOURCE_ADMISSION_ENABLED` | `true` | Enables resource admission checks. False values include `0`, `false`, `FALSE`, `False`, and empty. |
| `MN_MAX_CPU_LOAD_RATIO` | `1.5` | CPU load threshold for resource admission. Must be greater than `0`. |
| `MN_MAX_MEMORY_USED_RATIO` | `0.95` | Memory used ratio threshold. Must be greater than `0` and `<= 1`. |
| `MN_MAX_GPU_UTILIZATION_RATIO` | `0.98` | GPU utilization threshold. Must be greater than `0` and `<= 1`. |
| `MN_MAX_GPU_MEMORY_USED_RATIO` | `0.98` | GPU memory threshold. Must be greater than `0` and `<= 1`. |
| `MN_MAX_COMMAND_LENGTH` | `32768` | Maximum wrapped command length for OpenShell and HostLocal runners. |
| `MN_MAX_ARTIFACT_BYTES` | `1048576` | Maximum captured artifact bytes before truncation. |
| `MN_MAX_EVENT_BYTES` | unset | Optional positive integer validated at startup for event-size limits. |
| `MN_MAX_FAN_OUT` | unset | Optional positive integer validated at startup for fan-out limits. |

## Python API

These variables are read by `mn-api`.

| Variable | Default | Usage |
| --- | --- | --- |
| `MN_API_HOST` | `0.0.0.0` | Python API bind host. |
| `MN_API_PORT` | `4001` | Python API bind port. |
| `MN_API_TOKEN` | empty | Enables bearer-token auth when set. Required when `MN_ENV=prod`. |
| `MN_API_REQUEST_SIZE_LIMIT_BYTES` | `5242880` | Maximum request body size. Must be greater than `0`. |
| `MN_API_CORS_ALLOW_ORIGINS` | empty | Comma-separated CORS allowlist. |
| `MN_API_BASE_URL` | `http://localhost:4001/api/v1` | Used by system e2e tests as the API base URL. |

## Context Engine

These variables are used by runtime preflight checks and context-aware blueprints.

| Variable | Default | Usage |
| --- | --- | --- |
| `CONTEXT_ENGINE_ADDR` | tries `localhost:50052`, `127.0.0.1:50052`, `host.docker.internal:50052` | Context Engine endpoint. Manifest preflight uses this when `requiredContextEngine=true`; context-aware blueprint workers also use it directly. |
| `CONTEXT_ENGINE_READY_TIMEOUT_MS` | `500` | Preflight TCP readiness timeout in milliseconds. Takes precedence over seconds. |
| `CONTEXT_ENGINE_READY_TIMEOUT_SECONDS` | `0.5` in blueprint workers, `0.5` equivalent in preflight | Readiness timeout in seconds. Used when millisecond timeout is unset. |
| `CONTEXT_REDIS_URL` | unset | Optional Redis URL read by finance compliance context helpers when the source does not provide one. |

## Context view logging

These variables are currently used by `general_context_memory`.

| Variable | Default | Usage |
| --- | --- | --- |
| `MN_CONTEXT_VIEW_LOG` | disabled | Enables context-view logging when set to `1`, `true`, `yes`, or `on`. |
| `MN_CONTEXT_VIEW_LOG_DEST` | `both` | Destination for context-view logs. Supported values are `stdout`, `file`, `both`, and `cloud`. |
| `MN_CONTEXT_VIEW_LOG_FILE` | `/tmp/mn-context-agent/context_views.jsonl` | JSONL file path for context-view logs. |
| `MN_CONTEXT_VIEW_LOG_LEVEL` | `INFO` | Logger level for context-view logs. |
| `MN_CONTEXT_VIEW_LOG_MAX_BYTES` | `10485760` | Maximum context-view log size before rotation. |
| `MN_CONTEXT_VIEW_LOG_BACKUP_COUNT` | `5` | Number of rotated context-view logs to keep. |

## Blueprint and model provider variables

Blueprint manifests decide which process environment variables are passed to workers. A variable listed here still needs to be included in a blueprint's `pass_env` or explicit env mapping before a sandboxed worker can see it.

LLM-enabled blueprints use LiteLLM-style settings only. Provider-specific aliases such as OpenAI, Gemini, generic `LLM_*`, Ollama fallback, or profile-prefixed LLM variables are intentionally not part of the blueprint environment contract.

| Variable | Default | Usage |
| --- | --- | --- |
| `MN_BLUEPRINT_QUICK_TEST` | disabled | Enables quick/test mode in blueprint helpers when set to `1`, `true`, `yes`, or `on`. |
| `MN_CONFIG_PATH` | `~/.mn/config.json` | Shared blueprint-support user config path. |
| `MN_RUN_ID` | generated | Optional stable run ID for blueprint runs and specialized worker contracts. |
| `MN_RUNS_ROOT` | `~/.mn/runs` | Overrides the local run-store root. |
| `MN_NO_RUN_STORE` | disabled | Disables run-store writes when set to a truthy value. |
| `MN_DISABLE_RUN_STORE` | disabled | Alias used by worker contracts to disable run-store writes. |
| `MN_BLUEPRINT_CONFIG_PATH` | unset | Worker-contract config file override. |
| `MN_BLUEPRINT_CONFIG_JSON` | unset | Worker-contract inline config JSON override. |
| `LITELLM_MODEL` | `ollama/gemma4:latest` where local defaults are provided; otherwise blueprint-specific | LiteLLM model for LLM-enabled blueprint workers. Use provider prefixes such as `ollama/`, `openai/`, or `gemini/`. |
| `LITELLM_API_BASE` | `http://localhost:11434` for local Ollama blueprints; otherwise provider default | LiteLLM provider API base URL. For local Ollama Gemma, keep this as `http://localhost:11434`. |
| `LITELLM_API_KEY` | unset | Optional LiteLLM provider API key. Not required for local Ollama. |
| `LITELLM_TIMEOUT_SECONDS` | `60` | Optional timeout used by shared LLM skill workers. |
| `LITELLM_MAX_TOKENS` | `800` | Optional max output token limit used by shared LLM skill workers. |
| `LITELLM_NUM_RETRIES` | `2` | Optional provider retry count. Passed to LiteLLM when available. |
| `LITELLM_RETRY_BACKOFF_SECONDS` | `1.0` | Optional exponential retry backoff base for direct HTTP fallbacks. |

## Email and web integration variables

| Variable | Default | Usage |
| --- | --- | --- |
| `RESEND_API_KEY` | unset | Resend API key for email sending skills. |
| `RESEND_FROM_EMAIL` | unset | Sender email for Resend delivery. |
| `RESEND_API_BASE_URL` | `https://api.resend.com` | Resend API base URL. |
| `AGENTMAIL_API_KEY` | unset | AgentMail API key for email receive/delivery skills. |
| `AGENTMAIL_INBOX` | unset | AgentMail inbox ID. |
| `AGENTMAIL_API_BASE_URL` | `https://api.agentmail.to` | AgentMail API base URL. |
| `SCRAPINGBEE_API_KEY` | unset | ScrapingBee API key used by the web fetch skill when configured. |
| `MN_SLACK_BOT_TOKEN` | unset | Slack bot token used by email delivery skills. Falls back to `SLACK_BOT_TOKEN` in those skills. |
| `MN_SLACK_DEFAULT_CHANNEL` | unset | Default Slack channel for email delivery skills. Falls back to `SLACK_DEFAULT_CHANNEL`. |
| `MN_SLACK_API_BASE_URL` | Slack API default | Slack API base URL override for email delivery skills. |
| `SLACK_BOT_TOKEN` | unset | Slack bot token fallback used by Slack-related skills and the finance Slack monitor blueprint. |
| `SLACK_DEFAULT_CHANNEL` | `#claw` in finance Slack monitor | Slack channel fallback used by Slack-related skills and the finance Slack monitor blueprint. |

## Business email blueprint variables

These are specific to `business_email_campaign_deamon`.

| Variable | Default | Usage |
| --- | --- | --- |
| `SYNAPTIC_DB_CONNECTION` | unset | External database connection string. |
| `SYNAPTIC_DB_PATH` | blueprint default or required by worker | SQLite database path override. |
| `SYNAPTIC_QUICK_TEST_MODE` | disabled | Enables reduced quick-test behavior. |
| `SYNAPTIC_EMAIL_DRY_RUN` | disabled | Prevents real email delivery when enabled. |
| `SYNAPTIC_EMAIL_DELIVERY_MODE` | blueprint-specific | Controls email delivery mode. |
| `SYNAPTIC_TEST_EMAIL_TO` | unset | Test recipient override. |
| `SYNAPTIC_EMIT_CYCLE_TRIGGER` | `true` | Set to `false` to suppress cycle trigger emission. |

## Runtime-injected worker variables

The runtime injects these into worker processes. They are normally not set manually.

| Variable | Usage |
| --- | --- |
| `MN_INPUT_FILE` | Path to the worker input payload JSON. |
| `MN_MESSAGE_FILE` | Path to an injected message JSON file for message/body runner cases. |
| `MN_BODY_FILE` | Path to an injected body file for message/body runner cases. |
| `MN_BODY_CONTENT_TYPE` | Content type for `MN_BODY_FILE`. |
| `MN_BODY_CONTENT_ENCODING` | Content encoding for `MN_BODY_FILE`. |
| `MN_CONTEXT_FILE` | Path to the worker context JSON file. |
| `MN_AGENT_TYPE` | Agent type for the current worker. |
| `MN_AGENT_TEMPLATE` | Agent template type for the current worker. |
| `MN_JOB_ID` | Current runtime job ID. |
| `MN_AGENT_ID` | Current runtime agent ID. |
| `MN_WORKDIR` | Worker working directory used by runtime tests and some sandbox flows. |
| `MN_EXIT_CODE` | Internal wrapper variable used to report process exit status. |

## Test-only variables

These variables are used by tests or helper scripts, not by normal production runs.

| Variable | Default | Usage |
| --- | --- | --- |
| `MN_SECURITY_STRICT` | `0` | System tests fail hard on security findings when set to `1`. |
| `RUN_AGENTMAIL_E2E` | disabled | Enables real AgentMail e2e tests when set to `1`. |
| `RUN_AGENTMAIL_INTEGRATION` | disabled | Enables business email AgentMail integration tests when set to `1`. |
| `AGENTMAIL_E2E_TIMEOUT_SECONDS` | `60` | Timeout for AgentMail e2e tests. |
| `RESEND_TEST_TO` | unset | Recipient used by live Resend email tests and business email test config. |
| `RUN_RESEND_E2E` | disabled | Enables real Resend e2e tests when set to `1`. |
| `MN_HOME` | unset | Installation path referenced by docs/examples when running blueprints from a separate checkout. |
| `MN_LOG_PATH` | script-specific | Log file path used by cluster e2e helper scripts. |
| `MN_REMOTE_ROOT` | script-specific | Remote project root used by cluster e2e scripts. |
| `MN_STREAM_WAIT_TIMEOUT_SECONDS` | `120` | Wait timeout used by streaming cluster e2e scripts. |
| `MN_LLM_WAIT_TIMEOUT_SECONDS` | `300` | Wait timeout for LLM codegen cluster e2e scripts. |
| `MN_SIM_WAIT_TIMEOUT_SECONDS` | `420` | Wait timeout for ecosystem simulation cluster e2e scripts. |
| `MN_GEMINI_MODEL` | `gemini-2.5-flash-lite` | Gemini model used by LLM codegen cluster e2e scripts. |
| `MN_REDIS_PORT` | `6379` | Redis port used by cluster helper scripts. |
| `MN_REDIS_TEST_IMAGE` | `redis:7` | Redis Docker image used by Sentinel HA smoke tests. |
| `MN_REDIS_HA_LOCAL_IP` | unset | Local IP override for `test_redis_sentinel_two_box_ha.sh`. |
| `MN_REDIS_HA_REMOTE_IP` | unset | Remote IP override for `test_redis_sentinel_two_box_ha.sh`. |
| `MN_REDIS_HA_TEST_REDIS_PORT` | `46379` | Host Redis port used by the two-box Sentinel smoke test. |
| `MN_REDIS_HA_TEST_SENTINEL_PORT` | `46380` | Host Sentinel port used by the two-box Sentinel smoke test. |
| `MN_REDIS_HA_TEST_SSH_OPTS` | `-o BatchMode=yes -o ConnectTimeout=10` | SSH options used by the two-box Sentinel smoke test. |
| `MN_REDIS_HA_TEST_REMOTE_NETWORK` | `auto` | Remote Docker network mode for the two-box Sentinel smoke test. Supported values: `auto`, `host`, `bridge`. |
| `MN_REDIS_HA_TEST_INITIAL_PRIMARY` | `auto` | Initial Redis primary for the two-box Sentinel smoke test. Supported values: `auto`, `local`, `remote`. |
| `MN_CLI_DIST_PORT` | `4371` | Erlang distribution port used by `cluster_cli.sh`. |
| `MN_TEST_TOOL_BIN` | unset | Test helper binary override used by selected tests. |
