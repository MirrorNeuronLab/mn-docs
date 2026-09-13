# September 2026 runtime documentation alignment

- **Reader:** maintainers reviewing the internal references and external manual.
- **Outcome:** identify changed contracts, owning evidence, and validation limits.
- **Page type:** migration and validation record.
- **Scope:** current workspace contracts and the external `mn-doc-site` manual; no runtime code, catalog release, or deployment changes.
- **Maturity:** checkout-verified behavior, not a new release or compatibility promise.

## Changes readers need to make

| Previous guidance | Current usage | Owning evidence |
| --- | --- | --- |
| Treat a job as one execution; cancel it with `mn job cancel` | Keep durable job and public run IDs separately; control execution through `mn run` | CLI job-definition/run commands; API v1 contract tests |
| Launch a local folder without an explicit path prefix | Use `./folder`, `../folder`, or an absolute path for launch/doctor; other values select catalog IDs | CLI blueprint resolution and command help |
| Assume an OtterDesk checkout and a particular model for the quickstart | Select a reviewed local package or configured catalog entry and diagnose its own prerequisites | CLI catalog, validate, doctor, and launch commands |
| Author a monolithic `WorkflowSource` manifest | Reference workflow, execution, contracts, configuration, dependencies, and extensions from the source manifest | SDK `blueprints` schemas, package loader/compiler tests |
| Treat source format migration as an SDK 2.0 release requirement | Check actual distribution metadata independently of the schema version | Current CLI and SDK `pyproject.toml` |
| Require old independently versioned SDK components | Declare component distributions and supported explicit version constraints | SDK component, package-dependency, and version-constraint tests |
| Route worker inference directly to DMR | Use the owner's managed LiteLLM gateway; direct DMR probes are diagnostic only | SDK model preparation and gateway routing; model CLI implementation |
| Expect one run to spread across peers or share Redis | All workers stay on the job's owner Core; independent Cores federate | Core stable-job/federation code and cluster architecture contract |
| Describe all execution as OpenShell | Review the declared HostLocal, Docker, or OpenShell boundary | Core runner implementations and native preparation code |
| Treat quiet Docker output as missed node beacons | Task deadlines govern DockerWorker liveness; explicit workflow beacon policy remains authoritative | Core workflow ledger and child-workflow unit tests |
| Repeat a model call after uncertain dispatch | Handle `AmbiguousInvocation`; partition required context on `NeedsPartition` | SDK context-session and LiteLLM-context tests |

Detailed internal ownership remains in [CLI](cli.md), [API](api.md),
[Blueprint Standard](blueprint-standard.md), [SDK](SDK.md),
[Runtime Architecture](runtime-architecture.md), [Model Runtime](model-runtime.md),
and [Context Memory](context-memory.md).

## External manual

The public site now starts with installation, launch, monitoring, authoring,
Python/HTTP integration, and troubleshooting. It uses task-oriented navigation
and a developer landing page. Existing page routes remain available; internal
architecture and contributor pages are outside the primary sidebar journey.
The source-format guide replaces the retired monolithic authoring contract.
Model and API examples no longer require a private runtime workspace path.

## Validation performed

Focused Python suites passed against the workspace source:

| Repository | Test files | Result |
| --- | --- | --- |
| `mn-cli` | `test_job_definition_cmds.py`, `test_run_public.py`, `test_main.py` | 53 passed |
| `mn-api` | `test_v1_contract.py` | 26 passed |
| `mn-python-sdk` | `test_version_constraints.py`, `test_dependency_versions.py`, `test_package_dependencies.py` | 131 passed |
| `mn-python-sdk` | `test_blueprint_package.py`, `test_components.py` | 92 passed |
| `mn-python-sdk` | `test_context_session.py`, `test_litellm_context.py` | 27 passed |

Run these files with `python -m pytest` from the owning repository in an
environment with its dependencies and pytest installed. The focused API command
used `-o addopts=''` to omit the unrelated full-suite coverage gate.

The site passed `npm run types:check` and `npm run build`. A local Markdown/MDX
link and anchor audit covered touched internal pages and all public pages.
Both repositories passed `git diff --check`. No Mermaid diagrams were changed.

Core's focused `mix test tests/unit/child_workflow_test.exs
tests/unit/workflow_ledger_test.exs` could not start because Hex/dependencies
were absent. Those claims were checked against implementation and checked-in
tests, but not freshly exercised in Core. No live blueprint, provider billing,
model download, multi-node federation, or deployment was exercised. The
quickstart requires the reader's selected package and its prerequisites; it is
not a claim that an arbitrary package was run successfully during this audit.
