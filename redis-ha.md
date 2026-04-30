# Redis High Availability

MirrorNeuron can run Redis in two modes:

- `single`: one Redis endpoint from `MIRROR_NEURON_REDIS_URL`
- `sentinel`: Redis primary-replica replication with Sentinel failover

Use Sentinel mode for clusters where one Redis process or one box going down should not stop durable state access. MirrorNeuron still writes correctness-critical state only to the Sentinel-elected primary. Replicas are copies and failover candidates, not independent writable stores.

## Why Sentinel

MirrorNeuron stores job state, agent snapshots, event history, leader leases, and job leases in Redis. These records need a single authoritative write path. Redis OSS supports this with primary-replica replication plus Sentinel promotion.

MirrorNeuron does not use Redis sharding or multi-master merging for runtime state. That avoids split-brain writes and keeps lease fencing meaningful.

## Runtime Configuration

Set these on every runtime and control node:

```bash
export MIRROR_NEURON_REDIS_HA_MODE="sentinel"
export MIRROR_NEURON_REDIS_SENTINELS="192.168.4.29:26379,192.168.4.35:26379"
export MIRROR_NEURON_REDIS_SENTINEL_MASTER="mirror-neuron"
export MIRROR_NEURON_REDIS_DB="0"
```

`MIRROR_NEURON_REDIS_URL` remains useful as the single-Redis fallback and to provide the Redis URL scheme. In Sentinel mode, MirrorNeuron resolves the current primary from Sentinel before opening the Redix connection.

Optional authentication:

```bash
export MIRROR_NEURON_REDIS_USERNAME="default"
export MIRROR_NEURON_REDIS_PASSWORD="..."
export MIRROR_NEURON_REDIS_SENTINEL_USERNAME="default"
export MIRROR_NEURON_REDIS_SENTINEL_PASSWORD="..."
```

Optional durable write acknowledgement:

```bash
export MIRROR_NEURON_REDIS_WAIT_REPLICAS="1"
export MIRROR_NEURON_REDIS_WAIT_TIMEOUT_MS="100"
```

This runs Redis `WAIT` after durable job, event, snapshot, bundle archive, and node-state writes. It is reliability-first and can add latency. Hot lease renewals do not use `WAIT` by default.

Optional reconnect tuning:

```bash
export MIRROR_NEURON_REDIS_RECONNECT_ATTEMPTS="10"
export MIRROR_NEURON_REDIS_RECONNECT_BACKOFF_MS="250"
export MIRROR_NEURON_REDIS_RECONNECT_MAX_BACKOFF_MS="2000"
```

The runtime retries reconnectable Redis failures, including closed connections and `READONLY` errors that can appear during promotion.

## Join A Redis HA Cluster

The helper script configures local Redis and local Sentinel:

```bash
cd MirrorNeuron

bash scripts/redis_ha.sh join \
  --self-host 192.168.4.29 \
  --redis-port 6379 \
  --sentinel-port 26379 \
  --sentinels 192.168.4.29:26379,192.168.4.35:26379 \
  --master-name mirror-neuron \
  --quorum 1
```

Run the same command on each box, changing `--self-host`.

In production, run at least three Sentinel voters and use quorum appropriate for the deployment. A two-box quorum of `1` is useful for development smoke tests, but it can split-brain during network partitions.

## Leave A Redis HA Cluster

Graceful leave:

```bash
bash scripts/redis_ha.sh leave \
  --self-host 192.168.4.29 \
  --sentinels 192.168.4.29:26379,192.168.4.35:26379 \
  --master-name mirror-neuron
```

If the local Redis is primary, the script first asks Sentinel to fail over to another Redis and waits for the primary to change. Then it detaches local Redis with `REPLICAOF NO ONE` and removes the Sentinel monitor.

Data is preserved by default. Use `--purge-local` only when you intentionally want `FLUSHDB` after detaching.

## Start A Two-Box Runtime Cluster With Redis HA

Box 1:

```bash
cd MirrorNeuron

bash scripts/start_cluster_node.sh \
  --box1-ip 192.168.4.29 \
  --box2-ip 192.168.4.35 \
  --box 1 \
  --redis-ha-mode sentinel \
  --redis-sentinels 192.168.4.29:26379,192.168.4.35:26379 \
  --sentinel-master mirror-neuron \
  --redis-wait-replicas 1
```

Box 2:

```bash
cd MirrorNeuron

bash scripts/start_cluster_node.sh \
  --box1-ip 192.168.4.29 \
  --box2-ip 192.168.4.35 \
  --box 2 \
  --redis-ha-mode sentinel \
  --redis-sentinels 192.168.4.29:26379,192.168.4.35:26379 \
  --sentinel-master mirror-neuron \
  --redis-wait-replicas 1
```

The start script calls `scripts/redis_ha.sh join` automatically in Sentinel mode. Pass `--skip-redis-ha` if Redis and Sentinel are managed externally.

For CLI/control calls:

```bash
bash scripts/cluster_cli.sh \
  --box1-ip 192.168.4.29 \
  --box2-ip 192.168.4.35 \
  --self-ip 192.168.4.29 \
  --redis-ha-mode sentinel \
  --redis-sentinels 192.168.4.29:26379,192.168.4.35:26379 \
  --sentinel-master mirror-neuron \
  -- inspect nodes
```

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
  --remote-host 192.168.4.173 \
  --local-ip 192.168.4.25 \
  --remote-ip 192.168.4.173
```

The two-box smoke:

1. starts Redis and Sentinel in Docker on both boxes
2. starts local Redis as primary and remote Redis as replica
3. writes MirrorNeuron state through Sentinel mode
4. kills the local primary Redis
5. waits for Sentinel promotion
6. verifies MirrorNeuron can write and read through the remote-promoted primary

Expected success markers:

```text
two_box_initial_write_ok=...
two_box_post_failover_write_read_ok
```

## Operational Notes

- Keep Sentinel endpoints reachable from all MirrorNeuron nodes.
- Redis nodes should announce box-reachable IPs, not container bridge IPs.
- Use at least three Sentinel voters for production.
- Use `MIRROR_NEURON_REDIS_WAIT_REPLICAS=1` when losing the primary immediately after a write would be unacceptable.
- Keep `MIRROR_NEURON_REDIS_NAMESPACE` unique for tests.
- Monitor Redis replication lag, Sentinel leadership, and MirrorNeuron Redis reconnect warnings.
