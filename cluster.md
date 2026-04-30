# Cluster Guide

This guide covers MirrorNeuron's peer-to-peer cluster architecture.

## Cluster Architecture

MirrorNeuron uses a **peer-to-peer, highly available cluster model**. It does not use a master-slave pattern. All runtime nodes run the exact same binary and are operationally symmetric. 

The cluster state is built on:
- **BEAM node distribution**: For transparent messaging
- **`libcluster`**: For discovering and joining peer nodes
- **`Horde`**: For distributed supervision of agents and jobs
- **Redis**: For durable state, leader election, and job leasing. Single Redis is supported for development; Redis Sentinel HA is recommended for multi-box reliability.

### Dynamic Leader Election

Critical cluster coordination, such as sweeping orphaned jobs, is handled by a dynamically elected leader.
1. The leader acquires a `cluster:leader` lease in Redis.
2. It refreshes this lease periodically.
3. If the leader node crashes or becomes unresponsive, the lease expires and another node immediately takes over leadership.

With Redis Sentinel HA, this keeps cluster coordination available when either a runtime box or the current Redis primary goes down.

### Job Lease & Ownership

When a job is submitted, it is assigned a **Job Coordinator** process managed by `Horde`.
- The coordinator process acquires a lease in Redis indicating ownership of the job (`job:<job_id>`).
- If the node running the Job Coordinator dies, Horde detects the failure and schedules the coordinator on another peer.
- The new coordinator recognizes that the job already exists, waits for the previous lease to expire (if necessary), and then dynamically resumes the job by fetching its state from Redis.

## Required environment

All runtime boxes must agree on:

- `MIRROR_NEURON_COOKIE`
- `MIRROR_NEURON_CLUSTER_NODES`
- Redis location, or Redis Sentinel endpoints when Redis HA is enabled

Typical values:

```bash
export MIRROR_NEURON_COOKIE="mirrorneuron"
export MIRROR_NEURON_CLUSTER_NODES="mn1@192.168.4.29,mn2@192.168.4.35"
export MIRROR_NEURON_REDIS_URL="redis://192.168.4.29:6379/0"
```

Redis Sentinel HA values:

```bash
export MIRROR_NEURON_REDIS_HA_MODE="sentinel"
export MIRROR_NEURON_REDIS_SENTINELS="192.168.4.29:26379,192.168.4.35:26379"
export MIRROR_NEURON_REDIS_SENTINEL_MASTER="mirror-neuron"
export MIRROR_NEURON_REDIS_DB="0"
```

See [Redis High Availability](redis-ha.md) for setup, leave, and failover testing details.

## Recommended dev-mode networking

Use fixed distribution ports in dev mode:

```bash
export ERL_AFLAGS="-kernel inet_dist_listen_min 4370 inet_dist_listen_max 4370"
export MIRROR_NEURON_DIST_PORT="4370"
```

This makes failures much easier to reason about than random dynamic ports.

## Start a two-box cluster

Box 1:

```bash
cd MirrorNeuron
bash scripts/start_cluster_node.sh --box1-ip 192.168.4.29 --box2-ip 192.168.4.35 --box 1
```

Box 2:

```bash
cd MirrorNeuron
bash scripts/start_cluster_node.sh --box1-ip 192.168.4.29 --box2-ip 192.168.4.35 --box 2 --redis-host 192.168.4.29
```

With Redis Sentinel HA:

```bash
bash scripts/start_cluster_node.sh \
  --box1-ip 192.168.4.29 \
  --box2-ip 192.168.4.35 \
  --box 1 \
  --redis-ha-mode sentinel \
  --redis-sentinels 192.168.4.29:26379,192.168.4.35:26379 \
  --redis-wait-replicas 1
```

Run the same command on box 2 with `--box 2`.

## Inspect the cluster

From box 1:

```bash
bash scripts/cluster_cli.sh --box1-ip 192.168.4.29 --box2-ip 192.168.4.35 --self-ip 192.168.4.29 -- inspect nodes
```

You want to see:

- `mn1@192.168.4.29`
- `mn2@192.168.4.35`

Expected output also includes executor pool stats for each runtime node.

## Submit a cluster job

Small prime test:

```bash
python3 mn-blueprints/general_prime_sweep_scale/generate_bundle.py \
  --quick-test \
  --output-dir /tmp/mn-prime

mn validate /tmp/mn-prime
mn run /tmp/mn-prime
```

Expected output:

```text
Job submitted successfully
```

## Common cluster failure patterns

### `:nodistribution`

Usually means:
- `epmd` is not running
- port `4369` is blocked
- the BEAM node port is blocked

### Invalid challenge reply (Cookie mismatch)

Usually means:
- The `MIRROR_NEURON_COOKIE` differs between machines. 
- Ensure `export MIRROR_NEURON_COOKIE="your_shared_secret"` is identical on all physical boxes.

### Port `4000` already in use (`eaddrinuse`)

Usually means:
- Two nodes on the same box are trying to start the web API on `4000`.
- The Erlang `--bind` distribution port is clashing with the Web API.
- Use `export MIRROR_NEURON_API_PORT=4001` to change the web port.

### node name already in use

Usually means:
- a runtime node is already running on that machine
- a previous CLI node still exists with the same name

### Redis and split-brain

Redis acts as the arbiter for leader and job leases. In single Redis mode, the partition that can communicate with Redis maintains leadership and job ownership. In Sentinel mode, the Sentinel-elected primary is the only write target.

For production Redis HA, use at least three Sentinel voters. A two-box Sentinel quorum of `1` is useful for development smoke tests, but it can split-brain during network partitions.

## Related docs

- [Reliability Guide](reliability.md)
- [Redis High Availability](redis-ha.md)
- [Troubleshooting](troubleshooting.md)
- [Monitor Guide](monitor.md)
