# Contributing To MirrorNeuron

Thanks for helping improve MirrorNeuron. The best first contribution is usually a small bug fix, test, blueprint improvement, or documentation cleanup.

## Ways To Contribute

- Fix runtime, CLI, SDK, API, or Web UI bugs.
- Add or improve tests.
- Improve documentation and examples.
- Build or harden blueprints.
- Improve sandbox, Redis HA, cluster, or resource-admission behavior.
- Report security issues responsibly.

## Development Setup

From the monorepo root:

```bash
python3 -m venv .venv
. .venv/bin/activate
python3 -m pip install -r mn-system-tests/requirements.txt
```

Expected result:

```text
Successfully installed ...
```

Install Elixir dependencies:

```bash
cd MirrorNeuron
mix deps.get
mix compile
```

Expected result:

```text
Generated mirror_neuron app
```

Start local Redis:

```bash
docker rm -f mirror-neuron-redis 2>/dev/null || true
docker run -d --name mirror-neuron-redis -p 6379:6379 redis:7
docker exec mirror-neuron-redis redis-cli ping
```

Expected output:

```text
PONG
```

## Test Commands

Fast Python and blueprint checks:

```bash
python3 mn-system-tests/test_all.py --fast
```

Unit and component tests:

```bash
python3 mn-system-tests/test_all.py --unit
```

Blueprint quick generation:

```bash
python3 mn-system-tests/test_all.py --blueprints
```

Core runtime e2e:

```bash
python3 mn-system-tests/test_all.py --runtime-e2e
```

Redis Sentinel HA smoke tests:

```bash
python3 mn-system-tests/test_all.py --redis-ha
```

Two-box Redis Sentinel HA smoke test:

```bash
python3 mn-system-tests/test_all.py --redis-ha \
  --redis-ha-remote-host 192.168.4.173 \
  --redis-ha-local-ip 192.168.4.25 \
  --redis-ha-remote-ip 192.168.4.173
```

Expected success marker:

```text
All selected test suites passed.
```

## Before Opening A Pull Request

- Run the smallest test suite that covers your change.
- Run the broader suite when touching shared runtime, persistence, CLI, SDK, or API behavior.
- Update docs when behavior, commands, config, or security posture changes.
- Add migration notes when existing manifests, env vars, or persisted data are affected.
- Include screenshots or terminal output for UI, monitor, and CLI changes.

## PR Checklist

- [ ] I tested this locally.
- [ ] I added or updated tests.
- [ ] I updated relevant docs.
- [ ] I considered security implications.
- [ ] I described user-facing behavior changes.
- [ ] I noted any migration or compatibility concerns.

## Code Style

- Keep runtime primitives small and generic.
- Prefer existing helpers and patterns over new abstractions.
- Keep Redis keys, manifest fields, and API responses stable unless a migration is planned.
- Use explicit capacity, timeout, and backpressure settings for work that can block.
- Avoid domain-specific business logic in the core runtime.

## Documentation Style

- Use action-oriented page titles.
- Put commands in fenced `bash` blocks.
- Show expected output after important commands.
- Call out security, data loss, and irreversible operations clearly.
- Prefer realistic examples using checked-in blueprints.
- End pages with the next useful link.

## Documentation Checklist

- [ ] New feature has user-facing docs.
- [ ] Changed behavior is reflected in docs.
- [ ] Commands were tested or marked as representative.
- [ ] Security implications are documented.
- [ ] Migration notes are included if needed.
- [ ] Troubleshooting was updated for repeated support questions.

## Recommended First PRs

- Add a focused regression test for a fixed bug.
- Improve expected output in a getting-started page.
- Add a quick-test mode to a blueprint generator.
- Add a troubleshooting entry from a real failure.
- Tighten a manifest validation error message.

## Related Pages

- [Testing](testing.md)
- [Runtime Architecture](runtime-architecture.md)
- [Security Model](security.md)
- [Documentation Style](documentation-style.md)
