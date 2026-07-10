# MirrorNeuron Documentation Standard

This page governs documentation in `mn-docs` and its concise counterpart in `mn-doc-site/content/docs`. `mn-docs` is the detailed internal and contributor source of truth; the documentation site is the task-oriented public layer. Update both when a user-visible fact changes.

## Documentation mission

A page is successful only when a named reader can understand a boundary, complete a task, look up a contract, diagnose a failure, or make a small correct contribution without guessing.

Priority reader outcomes:

1. An evaluator can decide whether MirrorNeuron fits a workload and risk model.
2. A first-time developer can install the runtime and complete a safe, verified workflow preflight.
3. An operator can identify the next diagnostic action from an observable failure.
4. A contributor can locate the owning component, run validation, and prepare a focused pull request.

## Required documentation brief

Before a substantial new page or rewrite, record:

| Field | Required detail |
| --- | --- |
| Reader | Evaluator, developer, blueprint author, operator, integrator, contributor, or maintainer. |
| Outcome | One observable reader result. |
| Page type | Tutorial, how-to, reference, explanation, troubleshooting, migration, or decision record. |
| Scope and exclusions | Exact behavior covered and nearby topics intentionally excluded. |
| Maturity | Experimental, preview, stable, deprecated, or removed; cite a release/compatibility source. |
| Sources of truth | Code, tests, schemas, CLI/API definitions, release artifacts, or reproducible runtime evidence. |
| Validation | Documentation checks and the smallest relevant product command/test. |

Do not claim maturity, support, compatibility, performance, privacy, or reliability without an implementation or release source that defines the boundary.

## Page types

| Type | Reader question | Required structure |
| --- | --- | --- |
| Tutorial | “Can you guide me through a complete first experience?” | Prerequisites, ordered steps, verification, explanation, cleanup, next steps. |
| How-to | “How do I complete this task?” | Assumptions, numbered procedure, verification, rollback, symptom-led help. |
| Reference | “What exactly is this command, field, or API?” | Scope, syntax/fields, defaults, constraints, side effects, errors, small examples. |
| Explanation | “Why does this work this way?” | Problem, mental model, boundaries, guarantees, non-guarantees, failures, tradeoffs. |
| Troubleshooting | “Why did this fail?” | Exact symptom, likely causes, read-only diagnostics, resolution, verification, escalation evidence. |
| Migration | “How do I move from an old contract?” | Impact, backup/preflight, steps, verification, rollback, changed behavior. |

Do not combine a deep architecture essay, a command reference, and a tutorial on one page. Keep one canonical explanation, then link to it from task pages.

## Canonical-content policy

| Information | Canonical detailed page |
| --- | --- |
| Project fit and non-guarantees | `why-mirrorneuron.md` |
| Shared vocabulary | `core-concepts.md` |
| CLI syntax and flags | `cli.md`, generated from/checked against `mn --help` |
| REST API shapes | `api.md`, checked against `mn-api` routes and OpenAPI schema |
| Configuration keys | `env_variables.md`, checked against configuration schemas |
| Manifest and bundle fields | `blueprint-standard.md` and `bundle.md` |
| Architecture and tradeoffs | `runtime-architecture.md`, `cluster_architecture.md`, `reliability.md` |
| Security boundaries | `security.md` |
| Operational recovery | `troubleshooting.md`, `redis-ha.md`, cluster/deployment guides |

Do not copy a large table or procedure into another page. Keep a short context-specific summary and link to the canonical page.

## Technical accuracy rules

- Use the strongest available source: public contract/schema, automated test, implementation code, then reproducible runtime behavior.
- Never invent commands, flags, defaults, paths, expected output, APIs, compatibility, or guarantees.
- State the working directory and required environment/services for runnable commands.
- Use checked-in examples only when their requirements and safety boundaries are documented.
- Do not use `...` in a command presented as runnable. Use a defined angle-bracket placeholder instead.
- Show a stable success marker only when it was verified. Otherwise state the exit status or observable condition that proves success.
- Distinguish a completed job from a correct domain result; describe required artifact review and human control.

## Security and reliability requirements

Document these boundaries wherever they affect the reader's decision:

- runner type and privilege boundary;
- files, secrets, environment variables, ports, and external services available to workers;
- data that can leave the local environment;
- Redis/run-store persistence and data-retention behavior;
- retries, timeouts, idempotency expectations, and manual intervention;
- cluster trust, listener exposure, and cleanup/data-loss risk.

Use a prominent warning before deleting state, exposing a listener, passing secrets into worker code, executing an unreviewed bundle, disabling validation/authentication, or joining a cluster trust domain.

## Required validation

For every documentation pull request:

1. Run a local-link audit and Markdown/MDX syntax check.
2. Build or type-check `mn-doc-site` when it changes.
3. Run the smallest relevant CLI/API/component test for each documented behavior.
4. Inspect rendered diagrams when a Mermaid diagram changes.
5. Record commands run, sources verified, and untested limitations in the pull request.

Do not merge when a runnable command is untested but presented as a verified path, a destructive operation lacks a warning/recovery path, or a claim conflicts with code/tests/schemas.

## Contribution checklist

- [ ] Reader, outcome, page type, scope, and prerequisites are explicit.
- [ ] Important claims were verified against an authoritative source.
- [ ] Commands use current syntax and define placeholders.
- [ ] State-changing procedures include verification and cleanup or rollback.
- [ ] Security, privacy, listener exposure, secrets, and non-guarantees are visible where relevant.
- [ ] Internal links work in the documentation site and repository context.
- [ ] `mn-docs` and `mn-doc-site` are both updated when the fact is user-facing.
