# Choose a Blueprint

For developers and maintainers selecting a workflow from the configured catalog or a local package. This how-to covers discovery, review, preflight, and launch; it does not certify catalog contents or output quality. Sources are SDK `blueprint_source.py` and CLI blueprint resolution/launch tests. Catalog availability is version-dependent.

## Discover the active catalog

From any directory with the CLI installed:

```bash
mn blueprint list
mn blueprint show <blueprint-id>
```

Replace `<blueprint-id>` with an ID returned by the list command. Review the package README, inputs, execution runner, model/service requirements, dependency versions, network access, and output actions. Use provided sample inputs first.

The catalog is configured by `MN_BLUEPRINT_SOURCE`, `MN_BLUEPRINT_REPO`, and `MN_BLUEPRINT_LOCAL`; see [Environment Variables](env_variables.md). A separately checked-out catalog is not assumed to exist beneath this runtime workspace.

## Preflight a local package

From the directory containing your reviewed blueprint folder:

```bash
mn blueprint validate ./my-blueprint
mn blueprint doctor ./my-blueprint
```

Replace `./my-blueprint` with the actual path. Both commands must complete without blocking errors before normal launch. Validate checks the package and requirements; doctor diagnoses runtime prerequisites. Neither proves output correctness or authorization for external actions.

## Launch and inspect

> Launching executes the package's code and can prepare dependencies and resources. Review files, credentials, and external actions first.

```bash
mn blueprint run ./my-blueprint --detached
```

For a catalog-managed package, use its ID instead of a path:

```bash
mn blueprint run <blueprint-id> --detached
```

Record the returned public run ID, then follow [Quickstart](quickstart.md) to inspect results and cancel unfinished work. Preserve evidence before deleting run data.

## Maintain catalog documentation

Derive the published inventory from the catalog's `index.json`. Update each package's README, role documents, sample inputs, and tests together. Document runner, model, device, network, and human-review requirements. Validate the package with its owning tests and synchronize user-visible changes with the external manual.
