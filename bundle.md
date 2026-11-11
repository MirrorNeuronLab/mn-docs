# Generated Job Runtime Format

Blueprint folders and ZIP distributions use the [canonical blueprint package](blueprint-standard.md).
The SDK compiles that package into Core's executable workflow envelope and then
lowers it for submission. This page documents that generated runtime artifact;
its graph and runner fields do not belong in an authored blueprint manifest.

The package's referenced documents and assets travel together. Workers receive
`runtime/manifest.json`, a generated resolved descriptor containing the package
documents and invocation configuration. Core receives the executable graph.

## The `manifest.json` Schema

The generated Core manifest defines the execution graph. The source package's
`manifest.json` references the authored role documents. See
`MirrorNeuron/lib/mirror_neuron/manifest.ex` for Core validation.

### Top-level Fields

| Field                     | Type    | Description                                                                                                                                                                         |
| ------------------------- | ------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `apiVersion`              | String  | **Required.** `"mn.workflow/v1"` for the executable Core manifest.                                                                                                                  |
| `kind`                    | String  | **Required.** `"Workflow"`.                                                                                                                                                         |
| `manifest_version`        | String  | **Required.** The version of the manifest format (e.g., `"1.0"`).                                                                                                                   |
| `graph_id`                | String  | **Required.** A unique workflow id.                                                                                                                                                 |
| `job_name`                | String  | Optional. A human-readable name for the job. Defaults to `graph_id` if missing.                                                                                                     |
| `type`                    | String  | Optional. Set to `"service"` for workflows intended to run until manually stopped. Omit for default batch workflows. `system` and `sysbatch` are selected through scheduler policy. |
| `response_service`        | Object  | Optional. `{"enabled": true}` enables a definition-scoped responder. The optional `agent` declares a bounded MCP agent. Author either through `mn.response`.                        |
| `required_context_engine` | Boolean | Optional. Defaults to `false`. When true, Core requires TCP reachability at `MN_CONTEXT_ADDR` or one of its default addresses on port `50052` before scheduling agents.             |
| `services`                | Array   | Optional. Services registered by the job. See [Services and Health Checks](services-and-health-checks.md).                                                                          |
| `required_services`       | Array   | Optional. Services that must be healthy before job start.                                                                                                                           |
| `deployment`              | Object  | Optional. Stable deployment key and metadata. See [Deployments](deployments.md).                                                                                                    |
| `schedule`                | Object  | Optional. Periodic or delayed schedule declaration. See [Schedules and Events](schedules-and-events.md).                                                                            |
| `triggers`                | Array   | Optional. Event-trigger schedule declarations.                                                                                                                                      |
| `parameterized`           | Object  | Optional. Dispatch payload and metadata declaration for scheduled or event-triggered runs.                                                                                          |
| `metadata`                | Object  | Optional. Custom metadata tags for the job.                                                                                                                                         |
| `entrypoints`             | Array   | **Required.** A list of `node_id` strings where initial inputs will be injected to start the graph.                                                                                 |
| `initial_inputs`          | Object  | Optional. A map where the keys are `node_id`s (from `entrypoints`) and values are arrays of message payloads to seed the job.                                                       |
| `flow`                    | Object  | **Required.** Contains physical `nodes` and message-routing `edges`. For a logical DAG, it also carries `steps` and `graph.edges`.                                                  |
| `policies`                | Object  | Optional. Job-level policies like `recovery_mode`.                                                                                                                                  |

### Nodes (Agents)

Each item in `flow.nodes` defines an agent supervised by the BEAM runtime.

| Field               | Type   | Description                                                                                                     |
| ------------------- | ------ | --------------------------------------------------------------------------------------------------------------- |
| `node_id`           | String | **Required.** Unique identifier for this node within the graph.                                                 |
| `agent_type`        | String | **Required.** The core runtime primitive. Typically `"router"`, `"executor"`, `"aggregator"`, or `"sensor"`.    |
| `type`              | String | Optional. The behavioral template (e.g., `"map"`, `"reduce"`, `"stream"`, `"batch"`). Defaults to `"generic"`.  |
| `role`              | String | Optional. A human-readable tag describing the agent's domain role (e.g., `"researcher"`, `"root_coordinator"`). |
| `config`            | Object | Optional. Configuration specific to the `agent_type` and `type` (e.g., `emit_type`, `pool`, `uploads`).         |
| `resources`         | Object | Optional. CPU, memory, disk, GPU, device, port, volume, and runtime-driver requirements.                        |
| `services`          | Array  | Optional. Services registered by this specific agent.                                                           |
| `requires_services` | Array  | Optional. Node-scoped service requirements used during placement.                                               |
| `policies`          | Object | Optional. Per-agent restart overrides and legacy policy fields.                                                 |

### Job Types

MirrorNeuron supports four Nomad-inspired job types:

| Type       | How to declare                                    | Behavior                                                                              |
| ---------- | ------------------------------------------------- | ------------------------------------------------------------------------------------- |
| `service`  | top-level `"type": "service"` or scheduler policy | Long-running and restarted locally by policy until stopped.                           |
| `batch`    | default top-level type                            | Runs to completion and retries within policy limits.                                  |
| `system`   | `policies.scheduler.job_type: "system"`           | Runs owner-local long-running system work. It does not expand across federated peers. |
| `sysbatch` | `policies.scheduler.job_type: "sysbatch"`         | Runs owner-local one-off system work. It does not expand across federated peers.      |

Example:

```json
{
  "policies": {
    "scheduler": {
      "job_type": "system",
      "strategy": "spread"
    }
  }
}
```

### Restart Policies

Job-level restart policy lives under `policies.restart`; per-agent overrides
live under `flow.nodes[].policies.restart`. Legacy `reschedule` fields remain
accepted for stored-manifest compatibility, but federation does not move a job
or agent to another Core.

```json
{
  "policies": {
    "recovery_mode": "local_restart",
    "restart": {
      "attempts": 3,
      "interval_ms": 600000,
      "delay_ms": 1000,
      "delay_function": "exponential",
      "max_delay_ms": 30000,
      "mode": "fail"
    }
  }
}
```

See [Reliability Guide](reliability.md).

### Resource Requirements

```json
{
  "resources": {
    "cpu_cores": 2,
    "memory_mb": 8192,
    "devices": [
      {
        "kind": "gpu",
        "driver": "cuda",
        "min_memory_mb": 16000,
        "count": 1
      }
    ],
    "ports": [
      {
        "label": "api",
        "port": 8088,
        "protocol": "http"
      }
    ],
    "volumes": [
      {
        "name": "models",
        "source": "/mnt/models",
        "target": "/models",
        "mode": "ro",
        "type": "host"
      }
    ],
    "runtime_driver": "host_local"
  }
}
```

See [Resources and Devices](resources-and-devices.md).

### Service Requirements

```json
{
  "required_services": [
    {
      "name": "ollama",
      "origin": "external",
      "address": "${config.ollama.host}",
      "port": "${config.ollama.port}",
      "checks": [
        {
          "type": "http",
          "url": "${config.ollama.api_base}/api/tags",
          "expected_status": 200
        }
      ]
    }
  ]
}
```

See [Services and Health Checks](services-and-health-checks.md).

### Deployment Policy

```json
{
  "deployment": {
    "key": "agent-api"
  },
  "policies": {
    "update": {
      "strategy": "canary",
      "canary": 1,
      "max_parallel": 1,
      "auto_promote": false,
      "auto_revert": true
    }
  }
}
```

See [Deployments](deployments.md).

### Schedule And Triggers

```json
{
  "schedule": {
    "kind": "periodic",
    "crons": ["0 2 * * *"],
    "timezone": "America/New_York",
    "prohibit_overlap": true,
    "missed_policy": "skip"
  },
  "triggers": [
    {
      "name": "dataset-uploaded",
      "event_type": "file_uploaded",
      "filters": {
        "path": {
          "prefix": "/datasets/"
        }
      }
    }
  ]
}
```

See [Schedules and Events](schedules-and-events.md).

### Edges (Routing)

`flow.edges` routes messages between agents. Logical step dependencies are
stored separately in `flow.graph.edges`.

| Field          | Type   | Description                                                                                   |
| -------------- | ------ | --------------------------------------------------------------------------------------------- |
| `from_node`    | String | **Required.** The `node_id` of the sending agent.                                             |
| `to_node`      | String | **Required.** The `node_id` of the receiving agent.                                           |
| `message_type` | String | **Required.** The event or message type that triggers this edge (e.g., `"research_request"`). |

---

## The `payloads/` Directory

Include portable worker code and assets under `payloads/`. An executor runs
through its declared runner. A prepared image can already contain its command
and dependencies.

This generated OpenShell node stages a script using `config.uploads`. Each
`source` is relative to `payloads/`:

```json
{
  "node_id": "python_worker",
  "agent_type": "executor",
  "config": {
    "runner_module": "MirrorNeuron.Runner.OpenShell",
    "uploads": [
      {
        "source": "process_data.py",
        "target": "/sandbox/process_data.py"
      }
    ],
    "command": ["/usr/bin/python3", "/sandbox/process_data.py"]
  }
}
```

In this example, the runtime will look for `my_job_bundle/payloads/process_data.py` and mount it into the OpenShell sandbox at `/sandbox/process_data.py`.

### Blueprint-Scoped Python Dependencies

`MirrorNeuron.Runner.HostLocal` executor nodes can opt in to an isolated Python virtual environment with `python_environment`. Dependencies are cached by Python version, requirements contents, and inline package list, so repeated runs reuse the same environment while unrelated blueprints remain isolated.

```json
{
  "node_id": "video_worker",
  "agent_type": "executor",
  "config": {
    "runner_module": "MirrorNeuron.Runner.HostLocal",
    "upload_path": "person_detector",
    "upload_as": "person_detector",
    "workdir": "/sandbox/job/person_detector",
    "command": ["python3.12", "scripts/analyze_door_camera_frame.py"],
    "python_environment": {
      "requirements": "person_detector/requirements.txt",
      "packages": ["opencv-python-headless>=4.10,<5"]
    }
  }
}
```

`requirements` must be a relative path inside `payloads/`. Inline `packages` are normal pip requirement strings. If both are provided, both are installed into the same cached environment. If neither is provided, no environment is created.

The default cache is node-local at
`$MN_HOME/cache/blueprint-python-envs`; source packages staged for installation
use the sibling `blueprint-python-sources` directory. Docker Core sees these
paths under `/root/.mn/cache`. `MN_BLUEPRINT_PYTHON_ENVS_DIR` can explicitly
select another cache, including the legacy shared location, but a synchronized
virtual-environment cache causes avoidable Syncthing indexing and is reported
as a warning by blueprint doctor.

The core Docker image only includes generic Python virtualenv support. Blueprint-specific packages such as OpenCV, optimization solvers, browser tooling, and model libraries should be declared by the blueprint, not installed into core. Root-level blueprint `requirements.txt` files are not automatically installed; put runtime dependency files under `payloads/` and reference them explicitly from the executor node.

### Blueprint-Owned Skills And Agents

A bundle may carry installable skill and agent packages alongside ordinary
payload files:

```text
payloads/
  skills/<package>/pyproject.toml
  agents/index.json
  agents/<package>/pyproject.toml
```

Each package is either a source tree in the same layout as `mn-skills` or
`mn-agents`, or a Python wheel. Declare it at the manifest root:

```json
{
  "skill_dependencies": [
    {
      "type": "pip",
      "source": "payload",
      "name": "example-private-skill",
      "version": "1.0.0",
      "path": "skills/example_private_skill",
      "format": "source"
    }
  ],
  "agent_dependencies": [
    {
      "type": "pip",
      "source": "payload",
      "name": "example-private-agent",
      "version": "1.0.0",
      "path": "agents/example_private_agent",
      "format": "source"
    }
  ]
}
```

Paths are relative to `payloads/` and cannot escape the bundle. Names and
versions must match the source `pyproject.toml` or wheel metadata. A payload
package overrides a GAR declaration with the same normalized distribution name
and exact version.

### Blueprint-Owned Models

Large model files belong below `payloads/models`. They are streamed into the
content-addressed blob store instead of being read into memory:

```json
{
  "runtime": {
    "models": {
      "primary": {
        "provider": "docker_model_runner",
        "runtime_model": "example/private-model:latest",
        "backend": "llama.cpp",
        "context_size": 4096,
        "required": true,
        "source": {
          "type": "payload",
          "path": "models/private/model.gguf",
          "format": "gguf",
          "mmproj_path": "models/private/model.mmproj",
          "license_path": "models/private/LICENSE"
        }
      }
    }
  }
}
```

Supported formats are `gguf`, `safetensors`, and `dduf`. MirrorNeuron validates
safe paths, records SHA-256 digests, and packages the files into Docker Model
Runner before launch. Model licenses remain part of the bundle and backup.

---

## Example Bundle

This is a generated Core manifest for a map/reduce workflow. For an authoring
example that produces a source package the CLI can load, see
[Python-defined workflows](SDK.md#python-defined-workflows).

```json
{
  "apiVersion": "mn.workflow/v1",
  "kind": "Workflow",
  "manifest_version": "1.0",
  "graph_id": "document_summarizer",
  "required_context_engine": false,
  "entrypoints": ["dispatcher"],
  "initial_inputs": {
    "dispatcher": [{ "file": "doc1.txt" }, { "file": "doc2.txt" }]
  },
  "flow": {
    "nodes": [
      {
        "node_id": "dispatcher",
        "agent_type": "router",
        "type": "map",
        "role": "root_coordinator",
        "config": {
          "emit_type": "summarize_request"
        }
      },
      {
        "node_id": "summarizer_worker",
        "agent_type": "executor",
        "type": "map",
        "config": {
          "pool": "default",
          "uploads": [
            {
              "source": "summarize.py",
              "target": "/app/summarize.py"
            }
          ],
          "command": ["/usr/bin/python3", "/app/summarize.py"]
        }
      },
      {
        "node_id": "result_collector",
        "agent_type": "aggregator",
        "type": "reduce",
        "config": {
          "complete_on_message": true,
          "terminal_sink": true,
          "complete_run": true
        }
      }
    ],
    "edges": [
      {
        "from_node": "dispatcher",
        "to_node": "summarizer_worker",
        "message_type": "summarize_request"
      },
      {
        "from_node": "summarizer_worker",
        "to_node": "result_collector",
        "message_type": "summarize_request"
      }
    ]
  },
  "policies": {
    "recovery_mode": "local_restart"
  }
}
```

## Loading and Running

Use the CLI with a canonical source folder or catalog ID. The generated manifest
above illustrates the Core boundary. The CLI compiles an authored package when
preparing a Job. From the directory containing a reviewed package, with the
CLI attached to its local runtime:

```bash
mn blueprint validate ./my-blueprint
mn blueprint doctor ./my-blueprint
```

> Launch executes the package's code. Review `manifest.json`, referenced role
> documents, payloads, commands, `pass_env`, and OpenShell policy first.

```bash
mn blueprint run ./my-blueprint --detached
```

Use the returned Run ID to inspect results or cancel unfinished work in
[Monitor](monitor.md).

For HTTP clients, upload the ZIP as multipart data to `POST /api/v1/bundles`,
then pass the returned opaque `bundle_id` to `POST /api/v1/jobs`. The REST API
does not accept manifest, payload, or host filesystem paths directly.
