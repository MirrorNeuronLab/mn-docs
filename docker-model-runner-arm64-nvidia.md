# Prepare Docker Model Runner on NVIDIA DGX Spark

This how-to prepares Docker Model Runner (DMR) and Docker GPU access before
installing or starting MirrorNeuron on an NVIDIA DGX Spark. It also applies to
an ARM64 Ubuntu 24.04 host with a supported NVIDIA GPU, but it does not cover
driver installation, rootless Docker, non-Ubuntu distributions, or vLLM.

## Reader and outcome

- **Reader:** operator preparing an NVIDIA DGX Spark or comparable ARM64 Ubuntu host.
- **Outcome:** `docker model` is installed, Docker containers can access the NVIDIA GPU, and the local DMR API responds on the loopback interface.
- **Page type:** installation how-to.
- **Maturity:** platform prerequisite; DMR behavior remains owned by Docker and NVIDIA.
- **Sources of truth:** Docker Engine and Model Runner documentation, NVIDIA DGX Spark and Container Toolkit documentation, and `mn-deploy/install.sh`.

## Before you begin

Run every command on the DGX Spark host. You need:

- ARM64 Ubuntu 24.04 (Noble);
- a working NVIDIA driver;
- an account with `sudo` access; and
- outbound access to Docker's APT repository and the NVIDIA container registry.

DGX Spark normally includes Docker Engine and NVIDIA Container Toolkit. Do not
replace those packages merely to install DMR. First inspect the host and only
run the missing preparation steps.

Adding an account to the `docker` group grants root-equivalent access through
the Docker daemon. Continue to use `sudo docker` if that trust boundary is not
acceptable on the host.

## 1. Inspect the host

Confirm the architecture and operating system:

```bash
dpkg --print-architecture
lsb_release -a
```

The architecture must be `arm64`. Confirm that the NVIDIA driver and Docker
daemon are available:

```bash
nvidia-smi
docker --version
sudo systemctl status docker --no-pager
```

If Docker is not installed on a stock DGX Spark, stop and repair the DGX
software installation using NVIDIA's system documentation. For a generic
ARM64 Ubuntu host, follow Docker's Ubuntu installation guide before continuing.

## 2. Add Docker's APT repository when needed

DMR for Docker Engine is distributed as `docker-model-plugin`. Check whether
APT can already resolve it:

```bash
apt-cache policy docker-model-plugin
```

If the output contains a candidate version, continue to step 3. If it reports
`Candidate: (none)`, add Docker's official repository:

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
```

```bash
sudo tee /etc/apt/sources.list.d/docker.sources >/dev/null <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF
sudo apt-get update
apt-cache policy docker-model-plugin
```

Do not continue until `apt-cache policy` shows a candidate from
`https://download.docker.com/linux/ubuntu`.

## 3. Install Docker Model Runner

Install the plugin without replacing the existing Docker Engine packages:

```bash
sudo apt-get install -y docker-model-plugin
docker model version
```

`docker model version` must return version information. MirrorNeuron's Ubuntu
installer can install this package when APT already knows about it, but it does
not add Docker's repository for you.

## 4. Verify the NVIDIA container runtime

DGX Spark ships with NVIDIA Container Toolkit configured for Docker. Verify the
host before changing its daemon configuration:

```bash
nvidia-ctk --version
docker info --format '{{json .Runtimes}}'
```

If `nvidia-ctk` is present and Docker lists an `nvidia` runtime, continue to
step 5. If `nvidia-ctk` is present but Docker does not list `nvidia`, register
the runtime and restart Docker:

```bash
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
docker info --format '{{json .Runtimes}}'
```

The configuration command updates `/etc/docker/daemon.json`. Back up and review
that file first when the Docker daemon has operator-managed settings.

If `nvidia-ctk` is missing on a stock DGX Spark, repair the NVIDIA software
installation instead of mixing arbitrary toolkit packages into the appliance.
On a generic ARM64 Ubuntu host, install and configure NVIDIA Container Toolkit
using NVIDIA's installation guide.

## 5. Verify GPU access from Docker

Run NVIDIA's DGX Spark validation image:

```bash
docker run --rm \
  --gpus=all \
  nvcr.io/nvidia/cuda:13.0.1-devel-ubuntu24.04 \
  nvidia-smi
```

The command succeeds when the container prints the host GPU and driver
information and exits with status 0. If the image tag becomes unavailable,
select a DGX Spark-compatible CUDA image from NVIDIA's current guide rather
than substituting an x86-only image.

## 6. Start and verify Docker Model Runner

Run the small Docker test model, then check the local API:

```bash
docker model run ai/smollm2 "Reply with one word: ready"
docker model list
curl --fail http://127.0.0.1:12434/engines/v1/models
```

On Docker Engine, DMR enables TCP access on port `12434` by default. Keep this
endpoint bound to the local host or a trusted network boundary; do not expose
an unauthenticated model endpoint to an untrusted network.

After this preflight succeeds, install MirrorNeuron by following
[Install MirrorNeuron Locally](installation.md). On Linux NVIDIA hosts, the
MirrorNeuron installer may replace only the `docker-model-runner` controller
container with its required CUDA-enabled llama.cpp build. It retains the named
`docker-model-runner-models` volume and does not remove downloaded model
artifacts. Verify the resulting runtime with:

```bash
docker model status
mn model list
mn model doctor gemma4:e2b
```

## Troubleshooting

### `Package 'docker-model-plugin' has no installation candidate`

Inspect the package source:

```bash
apt-cache policy docker-model-plugin
cat /etc/apt/sources.list.d/docker.sources
```

The repository must use the host's Ubuntu codename and `arm64` architecture.
Repeat `sudo apt-get update` after correcting the source.

### `unknown or invalid runtime name: nvidia`

Use read-only checks first:

```bash
nvidia-ctk --version
docker info --format '{{json .Runtimes}}'
cat /etc/docker/daemon.json
command -v nvidia-container-runtime
```

If the toolkit and runtime binary exist but Docker has no `nvidia` entry, run
the configuration and restart commands from step 4.

### The Docker GPU test fails

Check the host before changing Docker:

```bash
nvidia-smi
ls -la /dev/nvidia*
nvidia-ctk --version
docker info --format '{{json .Runtimes}}'
```

If `nvidia-smi` fails on the host, repair the NVIDIA driver or DGX software
stack first. If only the container test fails, collect the Docker daemon logs
and the output of the commands above before restarting Docker or changing its
configuration.

## Rollback

To remove only the DMR package installed by this guide:

```bash
sudo apt-get remove docker-model-plugin
```

This does not remove Docker Engine. Do not delete Docker volumes or
`/var/lib/docker`; those actions can destroy unrelated containers, images, and
MirrorNeuron model artifacts.

If you added Docker's repository only for this package and no other installed
package depends on it, remove `/etc/apt/sources.list.d/docker.sources` and
`/etc/apt/keyrings/docker.asc` through the host's normal configuration-management
process, then run `sudo apt-get update`.

## Official references

- [Install Docker Engine on Ubuntu](https://docs.docker.com/engine/install/ubuntu/)
- [Get started with Docker Model Runner](https://docs.docker.com/ai/model-runner/get-started/)
- [Docker Model Runner inference engines](https://docs.docker.com/ai/model-runner/inference-engines/)
- [NVIDIA Container Runtime for Docker on DGX Spark](https://docs.nvidia.com/dgx/dgx-spark/nvidia-container-runtime-for-docker.html)
- [Install NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html)

Last reviewed against the linked Docker and NVIDIA documentation: September
2026.
