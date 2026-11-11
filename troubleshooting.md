# Troubleshoot MirrorNeuron

This page is the canonical symptom-led guide for local and two-node runtime failures. Start with read-only diagnostics. Do not delete Redis state, bundle files, or run records as a first response.

## Collect evidence before changing state

From the configured surface, run these read-only checks and retain sanitized
output:

```bash
mn --version
mn runtime status
mn node list
```

For foundation diagnostics, run `mn runtime doctor` on a combined installation
or `bin/mn-runtime doctor` from the runtime-only installation home. Client mode
reports the saved connection through `mn runtime status`. The optional API
surface can check the attached node through authenticated `GET /api/v1/runtime/health`.

For a workflow failure, record the Job ID, Run ID, timestamp, and exact error.
Use `mn job show <job-id>` and `mn run show <run-id>` to inspect the saved
definition and execution.

### The client cannot connect

For `MN_CLIENT_NOT_CONNECTED`, verify the surface's `MN_HOME`, the runtime's
gRPC listener and the runtime control credential. Run the attachment command
in [Installation](installation.md#install-the-surface-without-docker). Use the
same procedure to replace an old profile that points to an API URL. A failed
attachment preserves the existing profile.

## Redis issues

### Redis is not running

Symptoms:

- runtime tests fail immediately
- starts fail with a Redis connection or readiness error

Diagnose:

```bash
docker ps
```

With the default Compose container name, check it directly from the owner:

```bash
docker exec mirror-neuron-redis redis-cli ping
```

`PONG` confirms that Redis is responding. If a managed container is stopped,
start the owning runtime through its installed lifecycle. For a combined
installation:

```bash
mn runtime start
mn runtime status
```

Warning: removing a Redis container can discard runtime job state, event history, leases, and recovery metadata. Back up or preserve that data before any destructive cleanup. Use a manually started Redis container only when you intentionally manage Redis outside the MirrorNeuron deployment.

### Redis Sentinel two-box smoke says replica did not become online

Symptoms:

```text
remote replica did not become online
```

or remote Redis logs show:

```text
Error condition on socket for SYNC: No route to host
```

Cause:

- the remote box cannot route to the local Redis test port
- remote Docker bridge networking cannot reach the local LAN IP
- firewall rules block the test Redis port

Check from the remote box:

```bash
nc -vz -w 3 <local-host> 46379
```

If this fails, use automatic primary selection on the disposable test
topology described in [Redis HA](redis-ha.md#verification). From the workspace
root, substitute the SSH target and the two test IP addresses:

```bash
cd MirrorNeuron
bash scripts/test_redis_sentinel_two_box_ha.sh \
  --remote-host "<user>@<remote-host>" \
  --local-ip "<local-ip>" \
  --remote-ip "<remote-ip>" \
  --remote-network auto \
  --initial-primary auto
```

The successful smoke prints `two_box_post_failover_write_read_ok`.

### Redis failover returns `READONLY` or connection errors

During Sentinel promotion, Redis clients can briefly see:

```text
READONLY You can't write against a read only replica
```

or:

```text
%Redix.ConnectionError{}
```

MirrorNeuron retries reconnectable Redis errors with bounded backoff. If
errors persist, check the owning Core's Sentinel group using its configured
credentials:

```bash
redis-cli -h "<sentinel-host>" -p 26379 SENTINEL get-master-addr-by-name mirror-neuron
```

Expected output is the current primary host and port.

## OpenShell issues

### gateway is not reachable

Symptoms:

- transport errors
- connection reset by peer
- jobs fail before worker code starts

On the runtime that owns the failing Run, check foundation health, then use
its configured OpenShell client:

```bash
openshell status
openshell sandbox list
```

Check for a reachable gateway and record the failing Run's events. If the
gateway is down, inspect the installed runtime's OpenShell service and its
logs before restarting services. A gateway restart can interrupt other jobs.

### stale sandboxes slow everything down

Symptoms:

- long provisioning delays
- tiny jobs feel slow
- repeated benchmark runs degrade over time

Preview runtime-owned cleanup on the runtime host before removing anything:

```bash
mn runtime cleanup --dry-run
```

Use `bin/mn-runtime cleanup --dry-run --json` for a runtime-only installation.
The receipt lists confirmed candidates. Apply cleanup only after verifying the
resources are no longer needed. See [CLI](cli.md#runtime-nodes-and-resources).

## Cluster issues

### `MN_NODE_UNAVAILABLE` or a peer never becomes eligible

Verify each Core's advertised gRPC endpoint from the other runtime and check
both coordination stores. Retry the same join after restoring reachability.
Use the exact runtime name from `mn node list` when inspecting a peer.
Federation uses authenticated gRPC and distinct Redis stores. EPMD and Erlang
cookie diagnostics apply only to BEAM distribution. See
[Federation troubleshooting](cluster.md#troubleshooting).

### HTTP port already in use

Symptoms:

- `Address already in use`
- API or Web UI health checks report that a configured port is unavailable

Fix:

- By default, the local FastAPI gateway uses `MN_API_PORT`, commonly `54001`.
- The Web UI commonly uses `55173`.
- If you run multiple local runtimes, give each API or Web UI sidecar a distinct port.
- Keep Erlang distribution ports separate from API and Web UI ports.

### runtime node name already in use

Symptoms:

- `the name mn1@... seems to be in use`
- `eaddrinuse`

Fix:

- stop the old runtime first
- avoid starting the same box twice

### Federation is connected but one run uses only one node

This is expected: all workers of one job execute on its owner Core. Federation
selects owners for independent jobs; it does not distribute one job's agents or
migrate an active run when its owner goes offline.

```bash
mn node list
mn job show <job-id>
mn run show <run-id>
```

Inspect ownership and node eligibility before submitting another independent job.
See [Cluster](cluster.md) for registration and trust boundaries.

## Monitor issues

### Monitor shows old Runs

The Run list includes retained executions. Use `mn run list --job <job-id>`
or `--blueprint <blueprint-id>` and set `--limit` to narrow the view. See
[Monitor](monitor.md#control) before deleting retained history.

### monitor JSON has build noise

Use `mn run show <run-id> --json` for one result envelope, or
`mn run watch <run-id> --json` for newline-delimited stream records.
Keep stdout separate from stderr when capturing machine-readable output.

## LLM example issues

### Gemini API key missing

Symptoms:

- local LLM e2e fails quickly
- cluster LLM harness fails at the first codegen stage

Fix:

```bash
export GEMINI_API_KEY="<provider-api-key>"
```

### Python version mismatch across boxes

Symptoms:

- code works on box 1 but fails on box 2
- typing-related syntax errors on older Python versions

Check:

```bash
python3.12 --version
```

Try to keep both boxes on a compatible Python version.

## When a run feels slower than expected

Common reasons:

- OpenShell provisioning cost
- cold image pulls
- stale gateway state
- large numbers of very tiny executor tasks
- low executor concurrency

If the workflow itself is tiny but runtime is slow, look first at:

- sandbox lifecycle overhead
- gateway health
- whether jobs are being oversharded

## Good diagnostic commands

```bash
mn node list
mn job show <job-id>
mn run show <run-id>
mn run logs <run-id> --channel events
```
