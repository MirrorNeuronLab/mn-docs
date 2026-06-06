# Job Bundle Format

In MirrorNeuron, a **Job Bundle** is the standard deployment package for a multi-agent workflow. It defines the structure of the agent graph, the initial state, and any necessary executable payloads or static data required to run the job in an isolated execution sandbox.

## Bundle Structure

A valid job bundle is a directory with the following structure:

```text
my_job_bundle/
├── manifest.json
└── payloads/
    ├── worker_script.py
    └── data.json
```

- **`manifest.json`**: The declarative workflow definition. It maps out nodes (agents), edges (message routing), and execution policies.
- **`payloads/`**: A required directory containing all external static assets, shell scripts, Python code, and data files referenced by the executor nodes. The runtime resolves any relative `source` paths in the manifest against this directory before uploading them to the OpenShell sandbox.

---

## The `manifest.json` Schema

The `manifest.json` is a JSON document that defines the execution graph.

### Top-level Fields

| Field | Type | Description |
|-------|------|-------------|
| `manifest_version` | String | **Required.** The version of the manifest format (e.g., `"1.0"`). |
| `graph_id` | String | **Required.** A unique workflow id. |
| `job_name` | String | Optional. A human-readable name for the job. Defaults to `graph_id` if missing. |
| `type` | String | Optional. Set to `"service"` for workflows intended to run until manually stopped. Omit for default batch workflows. `system` and `sysbatch` are selected through scheduler policy. |
| `requiredContextEngine` | Boolean | Optional. Set to `true` when the workflow requires the Context Engine. The runtime checks `CONTEXT_ENGINE_ADDR` or port `50052` and rejects the run before scheduling agents if the service is unavailable. Defaults to `false`. |
| `services` | Array | Optional. Services registered by the job. See [Services and Health Checks](services-and-health-checks.md). |
| `required_services` | Array | Optional. Services that must be healthy before job start. |
| `deployment` | Object | Optional. Stable deployment key and metadata. See [Deployments](deployments.md). |
| `schedule` | Object | Optional. Periodic or delayed schedule declaration. See [Schedules and Events](schedules-and-events.md). |
| `triggers` | Array | Optional. Event-trigger schedule declarations. |
| `parameterized` | Object | Optional. Dispatch payload and metadata declaration for scheduled or event-triggered runs. |
| `metadata` | Object | Optional. Custom metadata tags for the job. |
| `entrypoints` | Array | **Required.** A list of `node_id` strings where initial inputs will be injected to start the graph. |
| `initial_inputs` | Object | Optional. A map where the keys are `node_id`s (from `entrypoints`) and values are arrays of message payloads to seed the job. |
| `nodes` | Array | **Required.** The list of agent nodes that make up the workflow. |
| `edges` | Array | **Required.** The list of message-routing edges between nodes. |
| `policies` | Object | Optional. Job-level policies like `recovery_mode`. |

### Nodes (Agents)

Each item in the `nodes` array defines an agent that will be supervised by the BEAM runtime.

| Field | Type | Description |
|-------|------|-------------|
| `node_id` | String | **Required.** Unique identifier for this node within the graph. |
| `agent_type` | String | **Required.** The core runtime primitive. Typically `"router"`, `"executor"`, `"aggregator"`, or `"sensor"`. |
| `type` | String | Optional. The behavioral template (e.g., `"map"`, `"reduce"`, `"stream"`, `"batch"`). Defaults to `"generic"`. |
| `role` | String | Optional. A human-readable tag describing the agent's domain role (e.g., `"researcher"`, `"root_coordinator"`). |
| `config` | Object | Optional. Configuration specific to the `agent_type` and `type` (e.g., `emit_type`, `pool`, `uploads`). |
| `resources` | Object | Optional. CPU, memory, disk, GPU, device, port, volume, and runtime-driver requirements. |
| `services` | Array | Optional. Services registered by this specific agent. |
| `requires_services` | Array | Optional. Node-scoped service requirements used during placement. |
| `policies` | Object | Optional. Per-agent restart and reschedule overrides. |

### Job Types

MirrorNeuron supports four Nomad-inspired job types:

| Type | How to declare | Behavior |
| --- | --- | --- |
| `service` | top-level `"type": "service"` or scheduler policy | Long-running and restarted/rescheduled by policy until stopped. |
| `batch` | default top-level type | Runs to completion and retries within policy limits. |
| `system` | `policies.scheduler.job_type: "system"` | Runs one copy on every eligible node. |
| `sysbatch` | `policies.scheduler.job_type: "sysbatch"` | Runs one one-off copy on every eligible node. |

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

### Restart And Reschedule Policies

Job-level policies live under `policies.restart` and `policies.reschedule`. Per-agent overrides live under `nodes[].policies.restart` and `nodes[].policies.reschedule`.

```json
{
  "policies": {
    "recovery_mode": "cluster_recover",
    "restart": {
      "attempts": 3,
      "interval_ms": 600000,
      "delay_ms": 1000,
      "delay_function": "exponential",
      "max_delay_ms": 30000,
      "mode": "fail"
    },
    "reschedule": {
      "unlimited": true,
      "delay_ms": 5000,
      "delay_function": "exponential",
      "max_delay_ms": 300000
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

Edges dictate how messages flow between agents after a step completes.

| Field | Type | Description |
|-------|------|-------------|
| `from_node` | String | **Required.** The `node_id` of the sending agent. |
| `to_node` | String | **Required.** The `node_id` of the receiving agent. |
| `message_type` | String | **Required.** The event or message type that triggers this edge (e.g., `"research_request"`). |

---

## The `payloads/` Directory

Because MirrorNeuron strictly separates the control plane (BEAM orchestration) from the execution plane (OpenShell sandboxes), any code executed by an `"executor"` agent must be supplied through the `payloads/` directory.

When you configure an executor node to run a script, you declare it in the `config.uploads` map. The `source` paths are evaluated relative to the `payloads/` directory:

```json
{
  "node_id": "python_worker",
  "agent_type": "executor",
  "config": {
    "uploads": [
      {
        "source": "process_data.py",
        "target": "/sandbox/process_data.py"
      }
    ],
    "command": ["python3", "/sandbox/process_data.py"]
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
    "command": ["python3", "scripts/analyze_door_camera_frame.py"],
    "python_environment": {
      "requirements": "person_detector/requirements.txt",
      "packages": ["opencv-python-headless>=4.10,<5"]
    }
  }
}
```

`requirements` must be a relative path inside `payloads/`. Inline `packages` are normal pip requirement strings. If both are provided, both are installed into the same cached environment. If neither is provided, no environment is created.

The core Docker image only includes generic Python virtualenv support. Blueprint-specific packages such as OpenCV, optimization solvers, browser tooling, and model libraries should be declared by the blueprint, not installed into core. Root-level blueprint `requirements.txt` files are not automatically installed; put runtime dependency files under `payloads/` and reference them explicitly from the executor node.

---

## Example Bundle

Here is a simple example of a complete `manifest.json` for a Map-Reduce style workflow.

```json
{
  "manifest_version": "1.0",
  "graph_id": "document_summarizer",
  "requiredContextEngine": false,
  "entrypoints": ["dispatcher"],
  "initial_inputs": {
    "dispatcher": [
      {"file": "doc1.txt"},
      {"file": "doc2.txt"}
    ]
  },
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
        "command": ["python3", "/app/summarize.py"]
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
  ],
  "policies": {
    "recovery_mode": "local_restart"
  }
}
```

## Loading and Running

You can validate and run a job bundle using the MirrorNeuron CLI:

```bash
# Validate the bundle structure and manifest constraints
mn blueprint validate path/to/my_job_bundle

# Execute the bundle in the cluster
mn blueprint run --folder path/to/my_job_bundle
```

Expected validation output:

```text
Job bundle at 'path/to/my_job_bundle' is valid.
```

Before running a third-party bundle, review `manifest.json`, `payloads/`, `runner`, `command`, `pass_env`, and any OpenShell `policy` file. See [Security Model](security.md).

Via the API (HTTP POST to `/api/v1/jobs`), the exact same `manifest.json` shape is accepted, with the payloads assumed to either already exist locally or omitted in pure-router workflows.
