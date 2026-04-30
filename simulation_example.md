# Run The Ecosystem Simulation

The ecosystem simulation is a BEAM-native blueprint that stresses MirrorNeuron with stateful regions, animal populations, cross-region messages, and a final leaderboard.

Path:

```text
mn-blueprints/science_ecosystem_simulation
```

## What It Simulates

Animals have compact DNA traits:

- `metabolism`
- `forage`
- `breed`
- `aggression`
- `move`
- `longevity`

Regions have local resource profiles. Animals compete for food, age, die, reproduce, mutate, and migrate between neighboring regions. The final output reports high-performing DNA profiles.

## Why This Example Is BEAM-Native

This blueprint keeps simulation state in BEAM agent state instead of launching one sandbox per animal.

```text
ingress router
      |
      v
world agent
      |
      v
region agents <--> region agents
      |
      v
collector
      |
      v
summarizer
```

This design keeps:

- clear state ownership
- cheap message passing
- bounded runtime processes
- lower Redis and sandbox overhead than per-entity workers

## Generate A Quick Bundle

```bash
python3 mn-blueprints/science_ecosystem_simulation/generate_bundle.py \
  --quick-test \
  --output-dir /tmp/mn-ecosystem
```

Expected output:

```text
bundle generated
```

## Validate And Run

```bash
mn validate /tmp/mn-ecosystem
mn run /tmp/mn-ecosystem
```

Expected output:

```text
Job submitted successfully
```

Inspect the job:

```bash
mn list
mn status <job_id>
mn monitor <job_id>
```

## Watch ASCII State

The blueprint includes an ASCII watcher:

```bash
mix run mn-blueprints/science_ecosystem_simulation/watch_ascii.exs -- <job_id> --once --no-clear
```

Run this from the monorepo root with the core dependencies available.

## When To Use This Example

Use it after simpler examples when you want to test:

- many messages
- stateful agents
- aggregation
- cluster scheduling
- runtime recovery under a larger workload

For first-time setup, use [Quickstart](quickstart.md) instead.

## Related Pages

- [Examples](examples.md)
- [Runtime Architecture](runtime-architecture.md)
- [Cluster Guide](cluster.md)
- [Reliability Guide](reliability.md)
