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

From the workspace root:

```bash
python3.12 -m venv .venv
. .venv/bin/activate
.venv/bin/python -m pip install -e mn-system-tests
```

This creates a workspace virtual environment and installs `mn_test`. Use `MN_ENV=dev` for runner-managed editable refreshes of the selected local Python components, or install the component dependencies explicitly. Native dependencies remain component-owned; inspect selection with `mn_test --dry-run` before running a broad suite.

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

If the change requires a local Redis instance, first check whether one is already running:

```bash
docker ps --filter name=mirror-neuron-redis
```

Start a disposable Redis container only when it is absent:

```bash
docker run -d --name mirror-neuron-redis -p 6379:6379 redis:7
docker exec mirror-neuron-redis redis-cli ping
```

Expected output:

```text
PONG
```

Warning: do not remove a Redis container to make this command work. It can contain another developer's runtime state. Use a separate container name, port, or Redis namespace for isolated testing.

## Test Commands

With the workspace environment above active, start from the workspace root. Inspect the catalog and run the smallest injected contract suite:

```bash
.venv/bin/mn_test --mn-set-folder . --list
.venv/bin/mn_test --mn-set-folder . --suite contracts
```

For a focused component change, select its unit suites:

```bash
.venv/bin/mn_test --mn-set-folder . --component mn-api --level unit
```

Replace `mn-api` with the owning component from `--list`. The canonical [Testing Guide](testing.md#common-commands) covers blueprint validation, Core and browser end-to-end checks, Redis HA, reports, capability gates, and cleanup. The runner records each invocation under `mn-system-tests/results/runs/<run-id>/`; review failures, skips, blockers, and cleanup diagnostics before treating it as successful validation.

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

## Automatic pre-push checks

From this repository root, install [uv](https://docs.astral.sh/uv/getting-started/installation/), then run:

```bash
bash scripts/install-hooks.sh
```

This installs the pinned pre-commit runner and isolated checker dependencies,
and activates `.git/hooks/pre-push` for this checkout. Repeat after a fresh clone.
Git does not activate hooks automatically from tracked files. Existing Git hooks
are preserved by pre-commit's migration mode. No global Git settings are changed.

Each push checks files changed by the outgoing commits, including new branches.
Deletions need no checks. Checks inspect the working tree; commit or stash pending
edits first so the checked content matches what you push. A failure blocks the
push and prints the problem; checks do not auto-format source files.
Generated protobuf bindings and immutable `install_support/` snapshots are excluded.

Run the same checks manually against every tracked file:

```bash
uvx --from pre-commit==4.5.1 pre-commit run --hook-stage pre-push --all-files
```

Tools are pinned in `.pre-commit-config.yaml`. Python uses Ruff lint (including
syntax errors) and format checks. Shell uses Bash syntax, ShellCheck, and shfmt
(two-space indentation). JSON, YAML, and TOML are parsed; Prettier checks document,
web, and data formatting. Existing per-package Ruff configuration remains active.
First use requires network access to populate tool caches. Existing style debt
may fail checks; fix and commit the reported files before pushing.

To remove this checkout’s hook, run `uvx --from pre-commit==4.5.1 pre-commit uninstall --hook-type pre-push`.
