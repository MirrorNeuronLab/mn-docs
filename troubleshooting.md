# Troubleshooting

This guide collects the most common operational failures seen during local and two-box testing.

## Redis issues

### Redis is not running

Symptoms:

- runtime tests fail immediately
- `mn run ...` hangs or errors

Check:

```bash
docker ps
docker exec mirror-neuron-redis redis-cli ping
```

Expected output:

```text
PONG
```

Fix:

```bash
docker rm -f mirror-neuron-redis 2>/dev/null || true
docker run -d --name mirror-neuron-redis -p 6379:6379 redis:7
```

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
nc -vz -w 3 192.168.4.25 46379
```

If this fails, let the smoke test auto-select the remote side as the initial primary:

```bash
python3 mn-system-tests/test_all.py --redis-ha \
  --redis-ha-remote-host 192.168.4.173 \
  --redis-ha-local-ip 192.168.4.25 \
  --redis-ha-remote-ip 192.168.4.173
```

Expected output includes:

```text
Remote cannot reach local Redis at 192.168.4.25:46379; using remote as initial primary.
two_box_post_failover_write_read_ok
```

For direct script control:

```bash
cd MirrorNeuron
bash scripts/test_redis_sentinel_two_box_ha.sh \
  --remote-host 192.168.4.173 \
  --local-ip 192.168.4.25 \
  --remote-ip 192.168.4.173 \
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

- `[error] ** Connection attempt from node :"node2@192.168.4.173" rejected. Invalid challenge reply. **`
- Nodes fail to form a cluster even when IP and ports are fully reachable

Fix:

- This is an **Erlang Cookie mismatch**. Both nodes must share the exact same secret cookie.
- If you are running nodes on different physical machines, they will auto-generate different cookies by default.
- Set the cookie explicitly on both boxes before starting: `export MN_COOKIE="my_shared_secret"`

### HTTP port `eaddrinuse` (4000 already in use)

Symptoms:

- `[error] Running MirrorNeuron.API.Router with Bandit 1.10.4 at http failed, port 4000 already in use`
- `** (EXIT) shutdown: failed to start child: :listener`

Fix:

- By default, the MirrorNeuron HTTP API binds to port `4000`. 
- If you run multiple nodes on the same machine, or if you accidentally configure the Erlang `--bind` to port 4000, they will clash.
- Override the HTTP API port for one of the nodes: `export MN_API_PORT=4001`
- Make sure your Erlang `--bind` distribution port (e.g. `4370`) is completely different from your `MN_API_PORT`.

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
bash scripts/cluster_cli.sh --box1-ip 192.168.4.29 --box2-ip 192.168.4.35 --self-ip 192.168.4.29 -- inspect nodes
mn nodes
```

## Monitor issues

### monitor shows too many old jobs

This usually means Redis still contains older job metadata.

Options:

- ignore completed jobs with `--running-only`
- delete old jobs manually if needed

### monitor JSON has build noise

Use the CLI command:

- `mn monitor <job_id>`

If you need all jobs first, run `mn list`.

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
python3 --version
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
mn nodes
mn status <job_id>
mn monitor <job_id>
mn dead-letters <job_id>
openshell status
openshell sandbox list
epmd -names
```
