# Make Blueprints Work With Docker And OpenShell

Blueprints often fail for boring environmental reasons: a path exists on macOS but
not inside Docker, a port looks busy because Docker pre-published it, or a service
health check points at the wrong side of a network boundary. This guide explains
the boundaries and the patterns that avoid those failures.

Use it when a blueprint reads local files, opens ports, runs a web UI, calls a
host service, or runs inside OpenShell.

## The Mental Model

A blueprint launch can touch several different filesystems and networks:

| Place | What Runs There | What It Can See |
| --- | --- | --- |
| Native OS | OtterDesk, `mn-api`, `mn`, validation before launch | Native files such as `/Users/alice/docs`, native localhost ports |
| Core Docker container | MirrorNeuron core, core-side validation, HostLocal workers in local installs | Submitted bundle under `/tmp/bundle_*`, payloads under `payloads/`, container localhost |
| HostLocal workspace | A copied payload directory for one agent | Only files copied from the submitted payload `upload_path` |
| OpenShell sandbox | Sandboxed worker command | Only uploaded sandbox files and explicitly allowed network/filesystem resources |

The mistake to avoid: never assume a path or port that worked in native
validation will work in the runtime worker.

## File Inputs

Static files that ship with a blueprint belong under `payloads/`. Runtime worker
commands should read them through paths relative to the node workdir.

User-selected native folders or files need staging. Do not pass a native path such
as `/Users/alice/Downloads/tax2025` directly to a Docker or OpenShell worker.
Instead:

1. Validate the native path before launch.
2. Copy the selected files into the submitted payload.
3. Rewrite the runtime config to point at the copied payload path.
4. Make core-side validation accept the staged path.

For folder inputs, use the blueprint support `local_inputs.folders` contract in
`config/default.json`:

```json
{
  "tax_documents": {
    "folder_path": ""
  },
  "local_inputs": {
    "folders": [
      {
        "config_path": "tax_documents.folder_path",
        "payload_path": "tax_workflow/mn_local_inputs/tax_documents",
        "runtime_path": "mn_local_inputs/tax_documents",
        "allowed_extensions": [".pdf", ".txt", ".json"],
        "linked_config_paths": ["inputs.payload.document_folder"]
      }
    ]
  }
}
```

`payload_path` is where launch preparation writes files in the submitted payload.
It must be inside the payload tree that the node uploads. If the node uses
`upload_path: "tax_workflow"` and its workdir is `/sandbox/job/tax_workflow`,
then `payload_path` should start with `tax_workflow/`.

`runtime_path` is what the worker reads after upload. With
`workdir: "/sandbox/job/tax_workflow"`, the worker reads
`mn_local_inputs/tax_documents`.

Avoid hidden staging directories such as `.mn_local_inputs`. Some packaging,
copy, archive, or inspection tools skip dot-prefixed paths. Prefer
`mn_local_inputs`.

## HostLocal Upload Paths

HostLocal copies files from the submitted payload into an agent workspace:

```json
{
  "runner_module": "MirrorNeuron.Runner.HostLocal",
  "upload_path": "worker",
  "upload_as": "worker",
  "workdir": "/sandbox/job/worker",
  "command": ["python3", "scripts/run_blueprint.py"]
}
```

If a worker needs staged user files, the staged `payload_path` must be inside
`worker/`:

```json
{
  "payload_path": "worker/mn_local_inputs/documents",
  "runtime_path": "mn_local_inputs/documents"
}
```

If several nodes need the same staged input and each uploads a different
directory, either put the staged files under each node's upload path or change the
manifest to use a shared upload root. Do not rely on another node's workspace.

## Validators

Input validation can run twice:

- API or CLI preflight, where native paths may exist.
- Core preflight, where only the submitted bundle and payloads exist.

Command validators should read `MN_BLUEPRINT_CONFIG_JSON`. If launch preparation
rewrites a native input to a staged runtime path, validators must understand both
forms.

Example validator resolver:

```python
from pathlib import Path


def resolve_folder(config: dict, folder: str) -> Path:
    native = Path(folder).expanduser()
    if native.exists():
        return native

    for spec in (config.get("local_inputs") or {}).get("folders") or []:
        if spec.get("runtime_path") != folder:
            continue
        payload_path = spec.get("payload_path")
        if not payload_path:
            continue
        staged = Path("payloads") / payload_path
        if staged.exists():
            return staged
    return native
```

Also watch blank initial inputs. Runtime messages can contain defaults such as
`document_folder: ""`. Worker code should not let a blank runtime value override a
valid staged config path.

## Ports And Web UIs

Docker-published ports look busy from the native host because Docker already owns
the host listener. That is expected. For runtime-managed blueprint web UIs, use
the runtime service path instead of launching an unmanaged side process.

Recommended desktop defaults:

```bash
MN_BLUEPRINT_WEB_UI_PORT_START=61000
MN_BLUEPRINT_WEB_UI_PORT_END=61049
MN_BLUEPRINT_WEB_UI_PORT_ALLOCATION_MODE=prepublished
```

In `prepublished` mode, the blueprint web UI helper selects from the configured
range without rejecting a port just because Docker is listening on it. The API
still reserves ports already used by active `blueprint-web-ui` services so two
co-workers do not receive the same dashboard port.

For Gradio dashboards, keep `config.web_ui` as the public blueprint contract:

```json
{
  "web_ui": {
    "enabled": true,
    "output": {
      "adapter": "gradio",
      "title": "Video Dashboard"
    }
  }
}
```

Launch preparation injects the HostLocal dashboard node, port resource, service
registration, and health check.

## Localhost Means Different Things

`localhost` always means "this process's own network namespace."

| From | `localhost` Means | Use For Host Services |
| --- | --- | --- |
| Native OS | The macOS/Linux/WSL host | `localhost` |
| Core Docker container | The core container | `host.docker.internal` on Docker Desktop, or a reachable host IP |
| OpenShell sandbox | The sandbox | Usually a service DNS name, gateway address, or explicit host mapping |

Examples:

- A dashboard URL shown to a browser on the native OS can be
  `http://localhost:61000`.
- A worker inside Docker calling an Ollama server on the host often needs
  `http://host.docker.internal:11434` or the LAN IP.
- A service health check should use the address that is reachable from the
  process running the check, not necessarily the public browser URL.

## OpenShell Rules

OpenShell should be treated as a stricter runtime than HostLocal.

Put everything the sandbox must read under `payloads/`:

```text
my_blueprint/
  manifest.json
  payloads/
    worker/
      scripts/run.py
      policy.json
      requirements.txt
```

Reference payload-local files in the manifest:

```json
{
  "runner_module": "MirrorNeuron.Sandbox.OpenShell",
  "upload_path": "worker",
  "sandbox_upload_path": "/sandbox/job",
  "workdir": "/sandbox/job/worker",
  "command": ["python3", "scripts/run.py"]
}
```

Do not pass native paths for policies, SSH keys, prompt files, model caches, or
input data unless the OpenShell integration explicitly supports and validates that
local path. Prefer copying those files into the payload.

OpenShell network access is also explicit. If a worker needs a model provider,
web API, local service, or dashboard callback, document the required hostname and
test it from inside the sandbox.

## Service Discovery And Health Checks

If a blueprint starts a long-lived process, register it as a runtime service.
Do not rely only on log messages or a local `*.json` side file.

For blueprint-owned services:

- Give the service a stable name.
- Add tags such as `blueprint`, `<blueprint_id>`, and a capability tag.
- Put the public URL and run identity in `meta`.
- Add a health check that becomes passing only after the service is reachable.
- Let the service lifecycle follow the job or agent lifecycle.

Verify service discovery:

```bash
mn service resolve blueprint-web-ui --tag video_watch_assistant
```

Expected output:

```text
blueprint-web-ui
```

For API clients, use:

```bash
curl http://127.0.0.1:54001/api/v1/services/blueprint-web-ui/resolve
```

## Debug Checklist

When a blueprint works in validation but fails at runtime:

- Check whether the worker received the same config as validation.
- Check whether any blank `initial_inputs` value overwrote a nonblank config
  value.
- Check whether the needed file is inside the submitted payload path.
- Check whether the file is inside the node's `upload_path`.
- Check whether the path is visible from the node workdir.
- Avoid dot-prefixed staging directories.
- Remember core validation runs inside Docker for local Compose installs.

When a port fails:

- Check whether Docker is intentionally publishing the range.
- Use `prepublished` allocation for Compose-published blueprint web UI ports.
- Reserve ports based on active runtime services, not only host bind probes.
- Separate bind host, health-check address, and public browser URL.

Useful commands:

```bash
mn validate /path/to/bundle
mn run /path/to/bundle
mn service list --all
mn service resolve blueprint-web-ui --tag <blueprint_id>
```

For a local development runtime, inspect the submitted bundle from the job
details. The `manifest_ref.cache_path` points at the bundle cache inside the core
container:

```bash
docker exec mirror-neuron-core find /tmp/mirror_neuron/bundle_cache -maxdepth 4 -type f
```

## Design Checklist

Before declaring a blueprint ready:

- Native files are either packaged under `payloads/` or declared through
  `local_inputs`.
- Runtime config paths are relative to the worker workdir.
- Validators work both before staging and after staging.
- Worker code reads `MN_BLUEPRINT_CONFIG_JSON`.
- Blank runtime inputs do not erase staged config paths.
- Long-lived web UIs are runtime-registered services.
- Compose-published ports use `prepublished` allocation.
- OpenShell inputs, policies, and dependencies are payload-local.
- Host service URLs are tested from the runtime namespace that will call them.

## Related Pages

- [Blueprints and Skills](blueprints-and-skills.md)
- [Job Bundle Format](bundle.md)
- [Services and Health Checks](services-and-health-checks.md)
- [Resources and Devices](resources-and-devices.md)
- [Security Model](security.md)
- [Troubleshooting](troubleshooting.md)
