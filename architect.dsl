workspace "MirrorNeuron" "Architecture of the MirrorNeuron runtime" {

    model {
        user = person "Developer / Operator" "Interacts with MirrorNeuron to submit jobs, monitor execution, and manage the cluster."

        mirror_neuron = softwareSystem "MirrorNeuron" "Owner-local execution and federation for message-driven workflows." {

            cli = container "CLI Tool (mn)" "Provides terminal-first tooling for interacting with MirrorNeuron." "Python / Typer"

            api = container "REST API" "Adapts runtime requests, results, and streams to REST, MCP, and the Job UI relay." "FastAPI"

            core_runtime = container "Core Runtime" "Owns admission, scheduling, execution state, and federation on one runtime node." "Elixir / BEAM" {
                runtime_gateway = component "Runtime Control Gateway" "Authenticates surface and peer requests and routes operations to the owner Core and its native service." "gRPC"
                job_coordinator = component "Job Coordinator" "Manages execution, agent lifecycle, terminal states, and cleanup on the owner." "GenServer"
                agent_worker = component "Agent Worker" "Represents a logical agent and invokes its declared runner." "GenServer"
                message_router = component "Message Router" "Routes messages between agents within the same job." "Elixir"
                event_bus = component "Event Bus" "Publishes and subscribes to job-related events." "Registry"
                lease_manager = component "Lease Manager" "Grants owner-local executor pool slots." "GenServer"
                runners = component "Runner Adapters" "Execute through HostLocal, DockerWorker, Docker Compose, or OpenShell." "Elixir"
            }

            native_runtime = container "Native Runtime" "Prepares blueprints and native resources, manages services, and serves owner-side operations and streams." "Python / mn_runtime"
            redis_store = container "Owner Coordination Store" "Stores this Core's durable Job and Run state, admission records, schedules, and leases." "Redis"
        }

        openshell = softwareSystem "OpenShell" "Provides policy-controlled sandbox execution."
        docker = softwareSystem "Docker" "Runs prepared containers, Compose services, and local model backends."

        # Relationships between people and software systems
        user -> cli "Uses for terminal operations"
        user -> api "Uses via Web UI or scripts"

        # Relationships between containers
        cli -> runtime_gateway "Sends runtime requests with the runtime control credential" "gRPC"
        api -> runtime_gateway "Sends runtime requests with the runtime control credential" "gRPC"
        runtime_gateway -> native_runtime "Delegates owner-local preparation, operations, and streams" "Private gRPC"
        native_runtime -> core_runtime "Submits prepared definitions and execution requests" "gRPC"
        native_runtime -> docker "Prepares worker containers, services, and model resources"
        core_runtime -> redis_store "Persists and fences owner-local state"
        runners -> openshell "Executes commands in configured sandboxes"
        runners -> docker "Invokes and controls prepared worker resources"

        # Relationships between components (Internal to Core Runtime)
        job_coordinator -> agent_worker "Supervises and controls"
        agent_worker -> message_router "Sends and receives messages"
        job_coordinator -> event_bus "Publishes lifecycle events"
        agent_worker -> event_bus "Publishes state changes and errors"
        agent_worker -> lease_manager "Requests execution leases"
        agent_worker -> runners "Invokes the declared execution adapter"
    }

    views {
        systemContext mirror_neuron "SystemContext" {
            include *
            autoLayout
        }

        container mirror_neuron "Containers" {
            include *
            autoLayout
        }

        component core_runtime "CoreRuntimeComponents" {
            include *
            autoLayout
        }
    }
}
