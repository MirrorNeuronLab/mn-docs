# Redis High Availability

MirrorNeuron can run Redis in two modes:

- `single`: one Redis endpoint from `MN_REDIS_URL`
- `sentinel`: Redis primary-replica replication with Sentinel failover

Use Sentinel to give one Core's Redis store failover candidates. Each
federated Core needs a distinct writable store identity and its own primary
or Sentinel group. Federation rejects peers sharing the same store. See
[Federation Architecture](cluster_architecture.md#2-coordination-and-control-plane).

This is an operator how-to for the Core Sentinel integration and the supplied
local helper. It does not replace the Redis and Sentinel security, backup, or
networking procedures required for a production deployment.

## Why Sentinel

MirrorNeuron stores job state, agent snapshots, event history, leader leases, and job leases in Redis. These records need a single authoritative write path. Redis OSS supports this with primary-replica replication plus Sentinel promotion.

MirrorNeuron does not use Redis sharding or multi-master merging for runtime state. That avoids split-brain writes and keeps lease fencing meaningful.

## Runtime Configuration

Set these in the Core process environment on the runtime that owns this
store. Replace the sentinel addresses with endpoints reachable from Core:

```bash
export MN_REDIS_HA_MODE="sentinel"
export MN_REDIS_SENTINELS="<sentinel-1-host>:26379,<sentinel-2-host>:26379"
export MN_REDIS_SENTINEL_MASTER="mirror-neuron"
export MN_REDIS_SENTINEL_PORT="26379"
export MN_REDIS_DB="0"
```

`MN_REDIS_URL` supplies the endpoint in `single` mode and the connection
scheme in Sentinel mode. In Sentinel mode, Core resolves the elected primary
through Sentinel before opening the Redix connection.

For externally managed Redis and Sentinel, configure their client credentials
in the owning Core environment as needed:

```bash
export MN_REDIS_USERNAME="default"
export MN_REDIS_PASSWORD="<redis-password>"
export MN_REDIS_SENTINEL_USERNAME="default"
export MN_REDIS_SENTINEL_PASSWORD="<sentinel-password>"
```

The `redis_ha.sh join` helper has a stricter rule: it requires a non-empty
`MN_REDIS_PASSWORD` and uses it for Redis authentication and replication. If
`MN_REDIS_SENTINEL_PASSWORD` is unset, the helper uses that same password for
the local Sentinel client listener.

Warning: the helper starts Redis and Sentinel bound for cluster peers. Restrict
ports `6379` and `26379` to the trusted cluster network, keep the passwords out
of shell history and source control, and set the credentials before joining.
The helper intentionally refuses to start unauthenticated listeners.

Optional durable write acknowledgement:

```bash
export MN_REDIS_WAIT_REPLICAS="1"
export MN_REDIS_WAIT_TIMEOUT_MS="100"
```

This runs Redis `WAIT` after durable job, event, snapshot, bundle archive, and node-state writes. It is reliability-first and can add latency. Hot lease renewals do not use `WAIT` by default.

Optional reconnect tuning:

```bash
export MN_REDIS_RECONNECT_ATTEMPTS="10"
export MN_REDIS_RECONNECT_BACKOFF_MS="250"
export MN_REDIS_RECONNECT_MAX_BACKOFF_MS="2000"
```

The runtime retries reconnectable Redis failures, including closed connections and `READONLY` errors that can appear during promotion.

If Sentinel advertises a primary hostname that a runtime cannot resolve or
route to directly, set `MN_REDIS_SENTINEL_HOST_MAP` to a comma-separated list
of `<advertised-host>=<reachable-host>` mappings. Prefer fixing Redis's
advertised address; the host map is for a deliberate network translation.

## Join a Redis HA Cluster

The helper script configures local Redis and local Sentinel:

```bash
cd MirrorNeuron

export MN_REDIS_PASSWORD="<strong-shared-redis-password>"

bash scripts/redis_ha.sh join \
  --self-host <this-host> \
  --redis-port 6379 \
  --sentinel-port 26379 \
  --sentinels <sentinel-1-host>:26379,<sentinel-2-host>:26379 \
  --master-name mirror-neuron \
  --quorum 1
```

Run the same command on the hosts participating in this Redis group, changing
`--self-host` for each host. Keep each data directory and set of ports
dedicated to that group. Configure the owning Core with the Sentinel endpoints
and credentials from [Runtime Configuration](#runtime-configuration).

In production, run at least three Sentinel voters and use quorum appropriate for the deployment. A two-box quorum of `1` is useful for development smoke tests, but it can split-brain during network partitions.

## Leave a Redis HA Cluster

Warning: `--purge-local` runs `FLUSHDB` on the detached local Redis. Do not use
it until the node is no longer a failover candidate and any required data has
been backed up or preserved elsewhere.

Graceful leave:

```bash
bash scripts/redis_ha.sh leave \
  --self-host <this-host> \
  --sentinels <sentinel-1-host>:26379,<sentinel-2-host>:26379 \
  --master-name mirror-neuron
```

If the local Redis is primary, the script first asks Sentinel to fail over to another Redis and waits for the primary to change. Then it detaches local Redis with `REPLICAOF NO ONE` and removes the Sentinel monitor.

Data is preserved by default. Use `--purge-local` only when you intentionally want `FLUSHDB` after detaching.

## Start a runtime with its own Redis HA store

Once the group's primary is available, apply the settings above to the
owning Core through its deployment configuration. Preserve the previous
configuration and data for rollback. Check the current master from a trusted
host with the configured Sentinel client credential:

```bash
redis-cli -h "<sentinel-host>" -p 26379 SENTINEL get-master-addr-by-name mirror-neuron
```

The reply should identify a primary reachable from Core. Restart the owning
runtime through its normal lifecycle and check its Redis and coordination
health. To federate with another Core, follow [Cluster](cluster.md) and
verify that the peer has a distinct coordination store.

## Verification

Local Docker Sentinel smoke:

```bash
cd MirrorNeuron
bash scripts/test_redis_sentinel_ha.sh
```

Two-box smoke using a remote host:

```bash
cd MirrorNeuron

bash scripts/test_redis_sentinel_two_box_ha.sh \
  --remote-host <remote-host> \
  --local-ip <local-host> \
  --remote-ip <remote-host>
```

The two-box smoke:

1. starts Redis and Sentinel in Docker on both boxes
2. checks whether the remote box can reach the local Redis test port
3. starts the reachable side as the initial primary and the other side as a replica
4. writes MirrorNeuron state through Sentinel mode
5. kills the initial primary Redis
6. waits for Sentinel promotion
7. verifies MirrorNeuron can write and read through the promoted replica

If the remote box cannot route to the local test port, the script prints:

```text
Remote cannot reach local Redis at <local-ip>:<port>; using remote as initial primary.
```

That fallback is intentional for lab networks with one-way reachability. The test still verifies that MirrorNeuron survives losing the initial Redis primary.

Warning: the fallback is a smoke-test convenience, not a production Sentinel topology. Production should use independently reachable Redis and Sentinel nodes with at least three Sentinel voters.

Expected success markers:

```text
two_box_initial_write_ok=...
two_box_post_failover_write_read_ok
```

Useful overrides:

```bash
bash scripts/test_redis_sentinel_two_box_ha.sh \
  --remote-host <remote-host> \
  --local-ip <local-host> \
  --remote-ip <remote-host> \
  --remote-network auto \
  --initial-primary auto
```

Options:

| Option              | Default | Description                                                                                                          |
| ------------------- | ------- | -------------------------------------------------------------------------------------------------------------------- |
| `--remote-network`  | `auto`  | `auto`, `host`, or `bridge`. On Linux Docker, `auto` chooses host networking for the remote side.                    |
| `--initial-primary` | `auto`  | `auto`, `local`, or `remote`. `auto` falls back to remote-primary when the remote cannot reach the local Redis port. |

From `mn-system-tests` with its [test environment](testing.md#common-commands),
the runner can execute the same smoke against a disposable remote workspace:

```bash
.venv/bin/mn_test --suite redis-ha.two-box --two-node \
  --remote-ssh-command "ssh <user>@<remote-host>" \
  --remote-mn-set-folder "<remote-workspace>"
```

Use the SSH login and workspace path for the test peer. Run with `--dry-run`
first to check connectivity and prerequisites. Confirm the suite passed and
check the run report for cleanup errors.

## Operational Notes

- Keep each group's Sentinel endpoints reachable from its owning Core.
- Redis nodes should announce box-reachable IPs, not container bridge IPs.
- Use at least three Sentinel voters for production.
- `MN_REDIS_WAIT_REPLICAS=1` waits for a replica acknowledgement on selected
  durable writes. A wait timeout can follow a committed primary write. Check
  the durable result before retrying.
- Keep `MN_REDIS_NAMESPACE` unique for tests.
- Monitor Redis replication lag, Sentinel leadership, and MirrorNeuron Redis reconnect warnings.
