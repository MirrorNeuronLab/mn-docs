# Canonical blueprint format

For blueprint authors and SDK, CLI, API, and UI maintainers. This reference describes the source format implemented by `mn-python-sdk/mn_sdk/blueprints` and its packaged JSON Schemas. It covers development folders, installed folders, catalog packages, generated blueprints, and ZIP distributions. Core's generated execution manifest is documented separately in [Job Bundle Format](bundle.md).

The format identifier is `https://mirrorneuron.dev/schemas/blueprint/v1/manifest.schema.json`. The blueprint's `version` is its semantic release version. There is no authored `apiVersion`, `kind`, `manifest_version`, profile, or raw runtime-manifest override in the core document.

## Package layout

```text
legal_assistant/
  manifest.json
  workflow.json
  execution.json
  contracts.json
  dependencies.json
  config/default.json
  config/overwrite.json
  extensions/llm.json
  extensions/product.json
  payloads/
  LICENSE.md
  TERM.md
```

`dependencies.json`, extensions, legal documents, and the local overwrite file are optional. A package with no code assets does not need `payloads/`. Required roles are referenced explicitly; their filenames can differ from these examples.

```json
{
  "$schema": "https://mirrorneuron.dev/schemas/blueprint/v1/manifest.schema.json",
  "id": "legal_assistant",
  "name": "Legal Assistant",
  "version": "1.0.0",
  "description": "Review legal documents and prepare a review packet.",
  "license": "LICENSE.md",
  "terms": "TERM.md",
  "workflow": "workflow.json",
  "execution": "execution.json",
  "contracts": "contracts.json",
  "config": "config/default.json",
  "dependencies": "dependencies.json",
  "extensions": {
    "mn.llm": {"file": "extensions/llm.json", "required": true},
    "mn.product": {"file": "extensions/product.json", "required": false}
  }
}
```

All references are ordinary package-relative POSIX paths. Documents have fixed responsibilities, not arbitrary include or override semantics.

| Document | Responsibility |
| --- | --- |
| `manifest.json` | Identity, release version, description, legal references, and role references |
| `workflow.json` | Logical steps, dependencies, dynamic workflows, and workflow policies |
| `execution.json` | Execution mode, agents, workers, runners, resources, placement, services, schedules, and execution policies |
| `contracts.json` | Inputs, validation, adapters, live inputs, outputs, artifacts, events, status, and privacy |
| `dependencies.json` | Skill and agent package names, versions, and sources |
| `config/default.json` | Operator-tunable defaults |
| `extensions/*.json` | Platform features and domain descriptors |

The SDK ships Draft 2020-12 schemas for each role and known extension. Canonical schema identifiers resolve against the SDK's local registry without fetching schemas from the network. Unknown core fields, duplicate JSON properties, invalid release versions, missing documents, and unsupported schema identifiers are errors.

## Execution modes

`execution.mode` is required:

- `compiled`: logical workflows, reusable worker declarations, and Python `StepSpec` definitions are compiled into a physical agent graph.
- `explicit`: a native or custom physical graph is declared directly through execution agents and runtime bindings.

Both modes have the same package structure and use the same loader and submission preparation. `execution.type` specifies batch or service execution. Shared step settings belong in `workflow.defaults.step`; shared workers belong in `execution.defaults.worker` and worker groups. Defaults are applied deterministically by the SDK's format-v1 compiler.

A logical workflow uses either `needs` on its steps or an explicit `edges` list. An edge can carry its event or condition declaration. Combining the two forms is rejected. Step IDs must be unique, referenced steps must exist, and logical dependencies must be acyclic. Bounded loops and dynamic templates remain explicit workflow capabilities.

`StepSpec` modules define contracts and collaboration. Agent handlers own work, and blueprint payloads own domain policy. The SDK imports StepSpec modules only during requested compilation, in subprocesses with a ten-second deadline. Missing dependencies fail compilation; they never generate substitute nodes.

## Extensions

Each extension document declares its own canonical `$schema`. Manifest extension registrations name the document and state whether support is required.

| Registration | Feature |
| --- | --- |
| `mn.llm` | Logical models, provider settings, actor assignments, structured output |
| `mn.rag` | Grounding, retrieval, embeddings, and knowledge settings |
| `mn.context` | Context/memory policy and cluster capabilities |
| `mn.response` | Definition-scoped response services, including bounded job agents |
| `mn.storage` | Persistent job data resources |
| `mn.airgap` | Air-gap behavior and offline dependency policy |
| `mn.ui` | Configuration review, dashboards, and launch presentation |
| `mn.product` | Product information and discovery descriptors |
| `mn.testing` | Quick-test descriptors |
| `mn.agentic` | Bounded research and tool-use policy |
| `mn.domain` | Blueprint-owned domain descriptors |

Known runtime features are handled by the SDK. An unknown required extension fails compilation. Unknown optional descriptive extensions remain in the snapshot and exported package without being executed. Adding a runtime feature requires a handler and a schema; adding fields to the core document is not an extension mechanism.

## Loading and configuration

The public SDK stages are:

```text
read_blueprint → BlueprintPackage
resolve_config → ResolvedConfiguration
compile_blueprint → CompiledBlueprint
plan_submission → SubmissionPlan
prepare_submission → PreparedSubmission
submit → commit or reconcile
```

`read_blueprint` validates and snapshots a folder. `open_blueprint` is a context manager that accepts a folder or ZIP; extraction is the only transport-specific stage. A package records each document's source path, file content hashes, executable permissions, and a content fingerprint. Document access returns copies, so callers cannot mutate the snapshot.

```python
from mn_sdk.blueprints import open_blueprint, resolve_config, compile_blueprint

with open_blueprint("./legal_assistant") as package:
    configuration = resolve_config(package, {"execution": {"quick_test": True}})
    compiled = compile_blueprint(package, configuration)
    print(package.manifest["id"], compiled.fingerprint)
```

Configuration resolves in this order:

1. SDK projections of declared feature descriptors.
2. The referenced default configuration document.
3. `config/overwrite.json`, when present in the package snapshot.
4. Invocation overrides.

The resolver provides identity, model, retrieval, resource, adapter, and human-control settings through one resolved configuration. There is no authored `config.manifest_defaults` path projection list. Worker code uses the SDK runtime configuration and resolved descriptor accessors. Launch identity, environment, and secrets are separate launch inputs; adapters must not mutate process-global environment variables to launch a job.

Compilation fingerprints include the package fingerprint, resolved configuration, and compiled graph. Source changes between reading and compilation are rejected. Fingerprints are deterministic across relocation and ZIP transport, and include referenced documents and payload content.

## Catalogs

`index.json` is only an ordered inventory of published package paths:

```json
["legal_assistant", "purchasing_manager", "research_assistant"]
```

`read_catalog` validates those folders and derives descriptive records from their manifests and extensions. It does not import blueprint Python, install dependencies, prepare models, restore databases, or provision services. A folder absent from the index remains a valid unpublished package. Duplicate paths and duplicate blueprint identities are errors.

## Submission and ownership

CLI, REST, and Python launches share SDK configuration, compiler, dependency preparation, payload assembly, and native resource contracts. Workers receive one complete resolved descriptor at `runtime/manifest.json`, including role documents and resolved configuration. This is a generated worker artifact, distinct from the package's small authored manifest.

Preparation uses a unique submission identity and tracks native resource ownership. Confirmed preparation failure rolls back resources acquired by that preparation. Cancellation is included. A submission timeout or malformed acknowledgement is not proof that Core rejected the definition. Reconciliation compares the submission identity against Core's authoritative ownership projection before a retry or cleanup. Uncertain outcomes preserve resources.

Persistent job data belongs to the durable job. Input staging and execution identifiers belong to individual launches. Replacement and cleanup must retain these boundaries. Secret injection and monitoring redaction occur at the submission boundary; source migration does not rewrite deployed jobs or run history.

## Paths, transport, and export

Folders and extracted ZIPs use the same package path validator. Absolute document paths, traversal, symlinks, duplicate destinations, and conflicting document-role destinations are rejected. ZIP extraction preflights its members before writing, with limits of 32 GiB and 100,000 entries. Folder snapshots apply corresponding content limits. Large assets are hashed and exported in chunks.

`export_blueprint(package, destination)` exports the complete portable file snapshot, including referenced documents, declared assets, code, configuration, and legal files. It excludes development caches and checks for changed files. Export outside the source package. Executable bits survive export and reimport. External dependencies remain explicitly declared; vendoring is optional.

## Verification

Run the SDK package, submission lifecycle, compiler, bundle, and payload tests. Run CLI and API catalog/launch tests, blueprint behavior contracts, UI tests/build, and Core/system boundary gates for affected runtime behavior. The migration inventory contains 39 present packages: 31 in `mn-blueprints` and 8 in `otterdesk-blueprints`. `demo_air_gapped` remains unpublished. The four previously deleted OtterDesk coworker packages remain deleted.

Source packages intentionally require the canonical format. Runtime artifacts and historical run records remain their own contracts. The documentation describes this source migration; publishing a coordinated SDK/CLI/API release is a separate release operation.

## Coordinated release

This is a breaking source-format change targeting SDK 2.0. CLI, API, and blueprint
support require `mirrorneuron-python-sdk>=2.0,<3`; distribute them together with
the migrated catalogs. Git tags remain the distribution version authority.
For a local pre-release build before tagging, set
`SETUPTOOLS_SCM_PRETEND_VERSION=2.0.0` while building the workspace packages.
Do not mix these catalogs with an earlier installed SDK.

The documentation-site repository was not present in this workspace; its concise
blueprint format reference must be updated when this coordinated release is published.

Execution defaults for this format are frozen in the SDK's packaged
`execution.schema.json` under `x-mn-compilation-defaults`. The compiler reads
that same versioned definition. Changes to implicit execution behavior require
a new format version; per-blueprint changes use explicit workflow or execution
defaults. No external profile file or mutable remote schema controls a package.
