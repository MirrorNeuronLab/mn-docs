# AGENTS.md

Instructions for coding agents working in this repository. These instructions
apply only to `mn-docs`.

## Start Here

Read `SPEC.md`, `README.md`, `index.md`, and `documentation-style.md` before
editing. Then read the full target page and its canonical related pages. Check
`git status` and preserve unrelated work.

This repository documents the MirrorNeuron ecosystem; it does not define new
runtime behavior. Verify claims against the owning repository's code, schemas,
tests, `--help`, OpenAPI, or release artifacts before writing them.

## Content Ownership

- `index.md`: canonical navigation and reader journeys.
- `core-concepts.md`: shared vocabulary.
- `cli.md`: CLI syntax and behavior.
- `api.md`: REST and streaming surface.
- `env_variables.md`: configuration reference.
- `blueprint-standard.md`, `bundle.md`: manifest and bundle contracts.
- `runtime-architecture.md`, `cluster_architecture.md`, `reliability.md`:
  architecture and operational guarantees/non-guarantees.
- `security.md`: trust, isolation, secrets, and exposure boundaries.
- `troubleshooting.md`, `redis-ha.md`: recovery and diagnosis.
- `documentation-style.md`: mandatory authoring and validation standard.

Keep one canonical detailed explanation. Other pages should summarize and link,
not duplicate large tables or procedures.

## Authoring Rules

- Give each substantial page a reader, outcome, page type, scope, maturity,
  sources of truth, and validation plan.
- Never invent commands, flags, defaults, ports, schemas, performance figures,
  supported platforms, or guarantees.
- State the working directory, prerequisites, side effects, verification, and
  cleanup/rollback for runnable procedures.
- Use concrete placeholders such as `<job-id>`; do not use `...` inside commands
  presented as runnable.
- Distinguish a completed workflow from a correct domain result.
- Put warnings before deletion, listener exposure, secret handling, unreviewed
  bundle execution, validation bypass, or cluster trust changes.
- Update the concise documentation-site counterpart in the same change when a
  user-visible fact changes; if that repository is out of scope, report the
  required follow-up instead of pretending synchronization occurred.
- Do not modify checked-in product examples merely to make prose convenient.

## Verification

- Audit local Markdown links and anchors in every touched page.
- Run `bash -n` on touched scripts.
- Run the smallest owning product test or command that proves each behavioral
  claim.
- Inspect rendered Mermaid diagrams after edits.
- Finish with `git diff --check` and report claims that could not be exercised.

## Issue-Fixing Policy

- Correct the source claim and all in-repo canonical references; do not paper
  over contradictory product behavior.
- Avoid undocumented compatibility prose or speculative future behavior.
- Mark known limitations plainly and link to their owning contract.
