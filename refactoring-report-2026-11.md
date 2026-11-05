# November 2026 Internal Refactoring Report

The approved refactor separates progress storage, CLI dependencies and launch helpers, SDK validation and staging, UI schemas and presentation helpers, and Core projections from their orchestration code. Existing entry points remain available. Structural compatibility checks found no API, CLI, public Python declaration, protobuf, or blueprint-schema differences.

This is a contributor decision and validation record for the November 4, 2026 working-tree changes. It covers internal organization and compatibility evidence, not a release certification. Component suites pass as detailed below; existing cross-component fixture failures, three optional UI/API browser failures, one Core restart timeout, and Core compiler warnings remain reproducible on the original revisions. Live GPU, remote federation, and installed-runtime deployment were not exercised.

## Audit and approved plan

The workspace contains eleven independent repositories. The audit prioritized cohesive extractions with testable boundaries. The complete plan was approved before implementation; no feature or external contract redesign was included.

| Priority | Owning files and audit finding                                                                                                                                                    | Implemented improvement and benefit                                                                                                                                                                         | Complexity and regression risk                                                                | Compatibility boundary                                                                                       |
| -------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------ |
| 1        | API, CLI, SDK, UI, and Core tests did not independently characterize every extraction boundary.                                                                                   | Recorded structural baselines and added characterization tests for progress storage, CLI exports and launch configuration, hardware validation, staging, UI status projection, and Core summaries/topology. | Low implementation complexity; essential coverage for later steps.                            | Capture existing behavior before moving it; retain original expectations.                                    |
| 2        | API `blueprint_launch.py` mixed launch orchestration with progress persistence and projections; `launch_progress.py` imported back into launch code.                              | Extracted `launch_progress_store.py` and made both consumers depend on it.                                                                                                                                  | Low–medium: JSONL ordering, terminal events, and legacy imports matter.                       | Preserve record format, path resolution, validation errors, status precedence, and old imports.              |
| 3        | CLI `libs/run_cmds` depended on wildcard imports and a transitive namespace.                                                                                                      | Replaced wildcard imports in 15 consumer modules and the facade with explicit dependencies; removed the corresponding broad Ruff exemptions.                                                                | Medium: existing patch hooks and exported objects must survive.                               | Preserve all 476 facade export names, command callbacks, and existing patch points used by callers/tests.    |
| 4        | CLI `runtime/server.py` mixed service lifecycle with endpoint, environment, command, and watchdog-script construction.                                                            | Extracted `runtime/launch_config.py`; moved watchdog script generation into the existing `runtime/watchdog.py`.                                                                                             | Medium: platform quoting, IPv6, Redis URLs, and bind/advertise behavior.                      | Keep startup order, process ownership, defaults, and old helper imports.                                     |
| 5        | SDK validation, model placement, and submission preparation mixed transformations with provider/orchestration calls; model placement imported back into validation orchestration. | Extracted hardware validation, model placement, and payload staging. Consolidated validation report formatting into `validation_issues.py`. Injected the hardware detector into the internal validator.     | Medium: lazy probes, fallback behavior, source exclusions, and mutation/order.                | Preserve public signatures, lazy detection, caller-supplied validators, report shape, and preparation order. |
| 6        | UI API schemas shared a file with transport state; `JobDetails.tsx` contained reusable status and summary transformations.                                                        | Extracted `api/schemas.ts` and reused `utils/jobDetailsView.ts` for pure view helpers.                                                                                                                      | Low–medium: Zod defaults/coercion and status precedence.                                      | Keep API exports, request paths, ETag/idempotency/stream behavior, polling, effects, and rendering.          |
| 7        | Core Redis persistence and the job coordinator also owned large projection/traversal helpers.                                                                                     | Added `Persistence.JobSummary` and `Runtime.JobTopology`; retained small delegates in the original owners.                                                                                                  | Medium: persisted fields, mixed-key precedence, traversal ordering, and system-job expansion. | Keep Redis keys, serialization, fencing, transactions, leases, and GenServer transitions.                    |
| 8        | Contributor docs pointed to deprecated runner flags and obsolete test/report paths.                                                                                               | Updated ownership guidance and the testing, contributing, and benchmark pages against the current runner.                                                                                                   | Low: command selection and working directories require verification.                          | Documentation reflects existing behavior; no runner or public product change.                                |

## Architecture after the change

The [component guide](component-guide.md#internal-module-boundaries) is the ongoing ownership reference. The main dependency directions are:

- API launch/progress orchestration → progress storage and projection helpers.
- CLI command facade → explicit command modules; runtime lifecycle → launch configuration and watchdog helpers.
- SDK orchestration → hardware matching, placement, report formatting, and file staging. Hardware detection remains at the provider boundary and is evaluated only when required.
- UI transport and views → schemas and pure display helpers. Schema-only consumers no longer need to import transport state.
- Core persistence/coordinator → pure summary and topology functions. Those helpers perform no Redis operations or state-machine transitions.

Old Python entry points re-export moved functions or delegate through the original signature. The default hardware validator has a narrow wrapper so the historical detector patch point remains effective. Moved functions can report a different implementation `__module__`; their old import paths and declared interfaces remain available. No dependencies, configuration keys, blueprint formats, protobuf sources, or persisted formats were added or changed.

The large orchestration files remain intentionally recognizable. Representative line counts, including imports and compatibility delegates:

| File                              | Before | After |
| --------------------------------- | -----: | ----: |
| API `blueprint_launch.py`         |  1,808 | 1,627 |
| CLI `runtime/server.py`           |  7,900 | 7,579 |
| SDK `blueprint_validation.py`     |  2,510 | 1,964 |
| SDK `submission_preparation.py`   |  2,396 | 2,207 |
| UI `api/index.ts`                 |    927 |   458 |
| UI `pages/JobDetails.tsx`         |    765 |   667 |
| Core `persistence/redis_store.ex` |  5,029 | 4,860 |
| Core `runtime/job_coordinator.ex` |  4,127 | 3,995 |

These are cohesion improvements, not performance measurements. Extracted functions retain their original algorithms. Configuration definitions stay with their existing loaders. Algorithm-specific constants and the watchdog program remain code-owned rather than becoming a new configuration format.

## Compatibility evidence

Baselines were captured before implementation and compared with the final source tree under the same Python environment.

| Boundary                     | Result                                                                                                                                                                                           |
| ---------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| FastAPI OpenAPI              | Identical schema: 93 paths and 110 HTTP operations, including request/response schemas and defaults.                                                                                             |
| HTTP route registration      | Identical route structure and methods.                                                                                                                                                           |
| CLI command tree             | Identical 76 leaf commands, group ordering, arguments/options, defaults, environment bindings, parameter types, help, and visibility flags.                                                      |
| Public Python declarations   | All 3,142 captured declarations retain their names, arguments, annotations, decorators, and class bases. Seventeen moved declarations resolve through their original module imports.             |
| Compatibility facades        | Identical exported-name sets for `mn_sdk`, `mn_sdk.blueprint`, `mn_cli.libs.run_cmds`, `mn_cli.server_cmds`, and the API blueprint/job route facades; no callable exports removed.               |
| Wire and blueprint contracts | All 26 captured protobuf/JSON-schema files have unchanged SHA-256 hashes.                                                                                                                        |
| Mechanical Python moves      | 82 moved function ASTs are identical; CLI command-module function/class bodies are unchanged. The detector injection is validated separately by behavior tests.                                  |
| UI definitions               | 78 extracted schema/type declarations and 11 shared view functions compare identically after normalizing syntax formatting and export modifiers.                                                 |
| Distribution packaging       | API, CLI, and SDK wheels build without isolation/network dependency installation. All new modules are packaged, and eleven affected module/facade imports succeed from extracted wheel contents. |

Characterization coverage checks progress JSONL version/order, malformed records, terminal precedence and phase summaries; facade object identity and export sets; endpoint/URL/environment formatting; lazy hardware probes and provider fallbacks; source traversal/exclusions and payload ordering; status/error display; and Core persisted keys, mixed atom/string fields, lease/scheduler summaries, topology expansion, and cycle traversal.

Structural equivalence does not prove every live integration. The runtime and browser evidence below supplements it; the explicitly untested environments remain outside this validation claim.

## Validation results

Python tests used the prepared Python 3.12.14 workspace environment. Redis-backed Core tests used a disposable Redis 8 container bound to loopback, an isolated namespace, and temporary storage. The container was stopped and removed after validation. Tests that require localhost sockets were rerun with that capability after sandbox permission failures; no production behavior was changed for those failures.

| Check                                            | Result                                                                                                                                                                                                                  |
| ------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| API full suite                                   | 664 passed. Final coverage, including branches: 88.08%, above the unchanged 85% gate. Three localhost tests passed on the capability-enabled rerun.                                                                     |
| CLI full suite                                   | 1,103 passed, 1 skipped.                                                                                                                                                                                                |
| SDK full suite                                   | 4,303 passed, 16 skipped, combining the full run with successful reruns of three localhost-dependent tests.                                                                                                             |
| API/CLI/SDK Ruff                                 | All three repositories pass.                                                                                                                                                                                            |
| UI Vitest                                        | 182 passed across 31 files.                                                                                                                                                                                             |
| UI ESLint, TypeScript, production build          | Pass. The existing large-chunk build warning remains.                                                                                                                                                                   |
| UI normal Playwright suite                       | 3 passed.                                                                                                                                                                                                               |
| UI optional real-API Playwright suite            | 3 passed, 3 failed; identical failures on untouched UI/API/SDK revisions.                                                                                                                                               |
| Core unit and API suites                         | 908 passed, 22 skipped. Initial harness overrides of shared-storage/cache paths interfered with six fixtures; correcting only the temporary harness yielded the passing full run.                                       |
| Core persistence/recovery end-to-end tests       | 76 passed.                                                                                                                                                                                                              |
| Core runtime/workflow/blueprint end-to-end tests | 64 passed, 1 failed; the same isolated failure reproduces on the original Core revision.                                                                                                                                |
| Core formatting and shell syntax                 | `mix format --check-formatted` passes; all 15 Core shell scripts pass `bash -n`. One existing schema declaration received formatting only.                                                                              |
| Core strict compilation                          | Fails on the same 12 warnings, in the same owning functions, before and after refactoring. No warnings arise from the new projection modules.                                                                           |
| Cross-component contracts                        | 273 passed, 19 failed before and after; failure IDs are identical.                                                                                                                                                      |
| Documentation commands                           | Current runner help/catalog inspected; all eight documented representative suite selections pass prerequisite dry-run with Docker access. Fixture benchmark report generation succeeds with the documented module path. |
| Documentation and diff checks                    | Five Markdown pages parse; 40 local links/anchors resolve; all eleven repository diffs pass `git diff --check`.                                                                                                         |

Counts describe individual suites and should not be summed with focused extraction checks, which overlap them. No golden fixture, lock file, test expectation, generated binding, or package metadata was changed to conceal a failure.

### Existing failures and validation limits

- **Blueprint contracts:** twelve migrated-blueprint parity failures concern installed distribution/lock version mismatches; four concern reviewed compiled content for `gtm_executor`, `gtm_planner`, `ros_amr_controller`, and `vc_assistant`. The remaining failures concern authored/payload source review, the Membrane checkpoint source inventory, and the `general_assistant` computer-use dependency range. The installed SDK/common metadata is behind the owning source checkout. Immutable fixtures and neighboring blueprint repositories were left unchanged.
- **UI/API integration:** the optional suite cannot find the expected new-execution heading, live-execution heading, and proxied UI heading. All three reproduce on the untouched baseline. The normal browser suite passes.
- **Core restart:** `tests/e2e/runtime_test.exs:3686`, “restarts a missing agent and replays its inflight message,” times out at the eight-second job wait in both versions, including isolated reruns. Its underlying lifecycle issue remains outside this extraction.
- **Core compile gate:** Elixir 1.20.4 reports an unused `Logger` require, an unreachable clause in `StableJob.create_loaded/3`, and ten redundant RedisStore fallback clauses on both revisions. Removing those clauses needs a separate compatibility review across supported toolchains and error paths.
- **CLI environment sensitivity:** `test_run_list_reads_shared_run_store` fails with exit code 13 when network access is enabled on both revisions, while the complete sandboxed suite passes. This is not evidence of a newly introduced CLI behavior change.
- **Unexercised environments:** remote/two-box federation, real GPU/model execution, destructive/host-secret suites, a full installed-runtime upgrade, and live OpenShell policy enforcement were not run. No claim of complete production compatibility follows from local tests alone.

## Deferred work

The self-contained `mn-deploy` installer remains large. Splitting it requires validating its standalone distribution and bootstrap paths, so it was not included in the mechanical module extractions. CLI and SDK airgap resolution also retain separate implementations because their version/error contracts differ; consolidating them without explicit characterization would risk changing behavior.

Further reductions in Core lifecycle code and SDK preparation should proceed behind the same boundaries with focused state-transition tests. The existing baseline failures need their own owning-component fixes rather than refreshed fixtures or relaxed assertions. The separate `mn-doc-site` repository was outside this workspace; contributor test examples there should be checked for the deprecated runner commands and old report paths corrected here.

## Source and evidence record

The source baselines were API `f55bbb6`, CLI `f4b7538`, SDK `44c1ce4`, UI `403a3e2`, Core `7139392`, and docs `353416a`. The other reviewed repositories remain unchanged: Membrane `3de1994`, agents `4ca0548`, deployment `c823394`, skills `a9e2d12`, and system tests `a1e10ad`.

Local detailed evidence is retained in `/private/tmp/mn-refactor-audit-r4qqbelj/`: `contracts/` and `contracts-after/` contain structural snapshots and comparisons; `reports/` contains before/after test logs, compiler comparison, coverage XML, and package validation; wheel artifacts and baseline source copies are separate from the product working trees. These temporary diagnostics are not release artifacts and may be removed after review.

The maintained developer entry points are [Component Guide](component-guide.md), [Testing](testing.md), [Contributing](contributing.md), and [System Benchmarks](system-benchmarks.md). Product interfaces continue to be defined by their existing API, CLI, SDK, configuration, and blueprint sources.
