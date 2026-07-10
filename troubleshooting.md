# Troubleshoot MirrorNeuron

This page is the canonical symptom-led guide for local and two-node runtime failures. Start with read-only diagnostics. Do not delete Redis state, bundle files, or run records as a first response.

## Collect evidence before changing state

Run these commands first and retain the output with secrets removed:

```bash
mn --version
mn runtime health
mn runtime status
mn node list
```

For a workflow failure, also record the job ID, run ID, timestamp, and exact error text. Use `mn job status <job_id>` and `mn job monitor <job_id>` to determine whether the failure is in the runtime, a declared blueprint requirement, or worker code.

## Redis issues

### Redis is not running

Symptoms:

- runtime tests fail immediately
- `mn blueprint run ...` hangs or errors

Diagnose:

```bash
docker ps
```

If `mirror-neuron-redis` is listed, check it directly:

```bash
docker exec mirror-neuron-redis redis-cli ping
```

`PONG` confirms that the container is responding. If the container is absent or stopped, start the managed runtime first:

```bash
mn runtime start
mn runtime health
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

If this fails, let the smoke test auto-select the remote side as the initial primary:

```bash
.venv/bin/python mn-system-tests/test_all.py --redis-ha \
  --redis-ha-remote-host <remote-host> \
  --redis-ha-local-ip <local-host> \
  --redis-ha-remote-ip <remote-host>
```

Expected output includes:

```text
Remote cannot reach local Redis at <local-host>:46379; using remote as initial primary.
two_box_post_failover_write_read_ok
```

For direct script control:

```bash
cd MirrorNeuron
bash scripts/test_redis_sentinel_two_box_ha.sh \
  --remote-host <remote-host> \
  --local-ip <local-host> \
  --remote-ip <remote-host> \
  --remote-network auto \
  --initial-primary auto
```

### Redis failover returns `READONLY` or connection errors

During Sentinel promotion, Redis clients can briefly see:

```text
READONLY You can't write against a read only replica
```

or:

```text
%Redix.ConnectionError{}
```

MirrorNeuron retries reconnectable Redis errors with bounded backoff. If errors persist, check Sentinel:

```bash
redis-cli -p 26379 SENTINEL get-master-addr-by-name mirror-neuron
```

Expected output is the current primary host and port.

## OpenShell issues

### gateway is not reachable

Symptoms:

- transport errors
- connection reset by peer
- jobs fail before worker code starts

Check:

```bash
openshell status
openshell sandbox list
```

Expected output includes:

```text
Status: Connected
```

Reset:

```bash
openshell gateway destroy --name openshell
openshell gateway start
openshell status
```

### stale sandboxes slow everything down

Symptoms:

- long provisioning delays
- tiny jobs feel slow
- repeated benchmark runs degrade over time

Clean prime-test sandboxes:

```bash
NO_COLOR=1 openshell sandbox list | awk 'NR>1 && index($1, "prime-worker-")==1 {print $1}' | xargs -I{} openshell sandbox delete {}
```

## Cluster issues

### `:nodistribution`

Check:

```bash
epmd -names
nc -vz 127.0.0.1 4369
```

Fix:

- make sure `epmd` is running
- use fixed Erlang distribution ports
- verify local firewall rules

### Invalid challenge reply

Symptoms:

- `[error] ** Connection attempt from node :"node2@<remote-host>" rejected. Invalid challenge reply. **`
- Nodes fail to form a cluster even when IP and ports are fully reachable

Fix:

- This is an **Erlang Cookie mismatch**. Both nodes must share the exact same secret cookie.
- If you are running nodes on different physical machines, they will auto-generate different cookies by default.
- Set the cookie explicitly on both boxes before starting: `export MN_COOKIE="my_shared_secret"`

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

### cluster forms but work does not land on both boxes

Possible causes:

- job is too small
- remote bundle sync failed
- stale CLI/control nodes are confusing routing
- one box has less executor capacity

Check:

```bash
bash scripts/cluster_cli.sh --box1-ip <box1-host> --box2-ip <box2-host> --self-ip <box1-host> -- inspect nodes
mn node list
```

## Monitor issues

### monitor shows too many old jobs

This usually means Redis still contains older job metadata.

Options:

- ignore completed jobs with `--running-only`
- delete old jobs manually if needed

### monitor JSON has build noise

Use the CLI command:

- `mn job monitor <job_id>`

If you need all jobs first, run `mn job list`.

## LLM example issues

### Gemini API key missing

Symptoms:

- local LLM e2e fails quickly
- cluster LLM harness fails at the first codegen stage

Fix:

```bash
export GEMINI_API_KEY="..."
```

### Python version mismatch across boxes

Symptoms:

- code works on box 1 but fails on box 2
- typing-related syntax errors on older Python versions

Check:

```bash
python3.11 --version
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
mn job status <job_id>
mn job monitor <job_id>
mn job dead-letters <job_id>
openshell status
openshell sandbox list
epmd -names
```
