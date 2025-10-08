---
title: "Data Lab Infra - Part 4: Core Services"
description: Learn how to automate data stack deployment using docker compose and GitLab, setting up CI/CD variables with Terraform, and using GPU passthrough to a Docker VM running on Proxmox.
date: 2025-10-14T12:00:00+0100
categories: ["DevOps"]
tags: ["homelab", "core-services", "data-stack", "gitlab", "docker", "ci-cd", "terraform", "postgres", "kafka", "mlflow", "ollama", "open-webui", "video"]
---

## Summary

On part 4 of this series, you'll learn how to automate data stack deployment using docker compose and GitLab, setting up CI/CD variables with Terraform, and using GPU passthrough to a Docker VM running on Proxmox.

We'll deploy Portainer, PostgreSQL, MLflow, Kafka, and Ollama with Open WebUI. We'll also implement a CI/CD pipeline that lets us create a PostgreSQL database and associated credentials, create a Kafka topic and initialize consumers for topics/groups, and pull an Ollama model.

Before starting to implement our `.gitlab-ci.yml`, we noticed that the CPU for the GitLab VM was overloaded, and the GitLab instance was unstable and even froze over long periods of time. We describe how we addressed these issues, having to significantly increase the resource allocation for the GitLab VM.

<div style="position: relative; padding-bottom: 56.25%; height: 0; overflow: hidden; max-width: 100%;">
	<iframe
		src="https://www.youtube.com/embed/TBD"
		frameborder="0"
		allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
		referrerpolicy="strict-origin-when-cross-origin"
		allowfullscreen
		style="position: absolute; top: 0; left: 0; width: 100%; height: 100%;">
	></iframe>
</div>

## Shared Service Planning

Our core services are focused on three main categories: Data Storage & Management, Data Processing, and ML & AI.

In the future, we would like to also consider software in the following categories: Data Visualization & BI, Monitoring & Logging, Search & Indexing, and Backup & Archiving.

### Data Storage & Management

| Category            | Service                                   | Description                                                                                              |
| ------------------- | ----------------------------------------- | -------------------------------------------------------------------------------------------------------- |
| Object Storage      | [MinIO](https://www.min.io/)              | S3-compatible object store. Already a part of the [[Layer 1 - Foundation\|foundation]] layer.            |
| Relational Database | [PostgreSQL](https://www.postgresql.org/) | General-purpose relational database to share among all services.                                         |
| Data Lakehouse      | [DuckLake](https://ducklake.select/)      | Data Lakehouse solution (runs on top of MinIO and PostgreSQL, without any additional services required). |

### Data Processing

| Category          | Service                            | Description                                                                                                                                                                                                        |
| ----------------- | ---------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Batch Processing  | [DuckDB](https://duckdb.org/)      | DuckLake is accessed via DuckDB, which we also use for batch processing (runs on local machines, not the data lab infra).                                                                                          |
| Stream Processing | [Kafka](https://kafka.apache.org/) | Even streaming platform, combined with the [faust](https://faust.readthedocs.io/en/latest/) Python library for stream processing (planned but untested; takes the place of the likes of Flink or Spark Streaming). |
| ETL Pipelines     | [Just](https://just.systems/)      | Makefile style task runner. Since our pipelines are based on calling `dlctl` commands, `just` is a good minimal tool to help organize our pipelines.                                                               |

### ML & AI

| Category     | Service                                                              | Description                                                                                                                       |
| ------------ | -------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| ML Platforms | [MLflow](https://mlflow.org/)                                        | Supports the ML lifecycle, from experimentation to deployment.                                                                    |
| LLMs         | [Ollama](https://ollama.com/) + [Open WebUI](https://openwebui.com/) | Provides a local chatbot via Open WebUI and it can also be used by applications to produce LLM pipelines (e.g., using LangChain). |

### Future Services

Other services that we might consider in the future include [JupyterHub](https://jupyter.org/hub) (ML & AI), [Prometheus](https://prometheus.io/) and [Grafana](https://grafana.com/oss/grafana/) (Monitoring & Logging), [Elasticsearch](https://www.elastic.co/elasticsearch/) (Search & Indexing), and even [Superset](https://superset.apache.org/) (Data Visualization & BI). Later, we'll also explore backup solutions, and, if it makes sense, we'll consider switching from [just](https://just.systems/) to a more specialized orchestration tool, like [Airflow](https://airflow.apache.org/). However, it is more likely that we downsize the data stack rather than expand it, as we are looking for a minimal but robust data stack to run on-prem.

Our current setup is already feeling overcomplex, but we will improve on this as we go. For example, if we run [Ollama](https://ollama.com/) on the `docker-shared` VM, we'll need to enable GPU passthrough for it, but what happens when we want to run project-specific apps that also require the GPU, when those are meant to run on `docker-apps`? Keep in mind that consumer GPUs do not support virtualization. We might be better off with a single Docker VM for everything.  And this would even make it easier to use simpler UIs, like [Dockge](https://dockge.kuma.pet/), as a lightweight alternative to [Portainer](https://github.com/portainer/portainer).

## GPU-Passthrough for QEMU VMs

On [Layer 1 - Foundation](../data-lab-infra-foundation/) we had setup GPU support with NVIDIA drivers for the host machine, i.e., Proxmox itself, which only works for LXCs. Since our Docker host is running on a VM, we'll need to rollback and disable any drivers on the host machine, so that we can install them on the VM instead. Let's go through the required steps.

### Uninstall NVIDIA Drivers from Host

First, let's uninstall the NVIDIA drivers from the host machine:

```bash
nvidia-uninstall
```

Delete or comment out any NVIDIA related modules from `/etc/modules`:

```bash
# nvidia
# nvidia-modeset
# nvidia_uvm
```

And `reboot`.

### Enable IOMMU and Passthrough

First, we need to edit `/etc/default/grub` to set:

```bash
GRUB_CMDLINE_LINUX_DEFAULT="quiet amd_iommu=on iommu=pt"
```

Setting `iommu=pt` is what enables passthrough (`pt`). If your CPU is intel, use `intel_iommu=on` instead.  You can use `lscpu` to check which CPU you have.

Then, add the following modules to `/etc/modules`:

```bash
vfio
vfio_iommu_type1
vfio_pci
vfio_virqfd
```

Now, let's configure VFIO, but first let's get the device IDs for the NVIDIA device:

```bash
lspci -nn | grep NVIDIA
```

In my case, this is the output I get, with four IDs:

```
01:00.0 VGA compatible controller [0300]: NVIDIA Corporation TU106M [GeForce RTX 2060 Mobile] [10de:1f15] (rev a1)
01:00.1 Audio device [0403]: NVIDIA Corporation TU106 High Definition Audio Controller [10de:10f9] (rev a1)
01:00.2 USB controller [0c03]: NVIDIA Corporation TU106 USB 3.1 Host Controller [10de:1ada] (rev a1)
01:00.3 Serial bus controller [0c80]: NVIDIA Corporation TU106 USB Type-C UCSI Controller [10de:1adb] (rev a1)
```

However, we'll only need the IDs for VGA and Audio, which, in our case, are `10de:1f15` and `10de:10f9`, respectively. Now, we can edit `/etc/modprobe.d/vfio.conf`:

```
options vfio-pci ids=10de:1f15,10de:10f9 disable_vga=1
```

Make sure to replace the two IDs with the ones for your own system!

Finally, we should update grub and initramfs, and then reboot:

```bash
update-grub
update-initramfs -u -k all
reboot
```

### Check if Passthrough Is Active

You can check that VFIO is the active driver for your GPU, by running the following command with for your PCI device (e.g., `01:00.0`):

```bash
lspci -k -nn -s "01:00.0"
```

Among other things, it should print:

```
Kernel driver in use: vfio-pci
```

If another driver is active, you might have to edit `/etc/modprobe.d/blacklist.conf` and blacklist all NVIDIA drivers:

```
blacklist nouveau
blacklist nvidia
blacklist nvidiafb
blacklist nvidia_drm
blacklist nvidia_modeset
blacklist nvidia_uvm
```

If you had to update the blacklist, `reboot`, and re-run the `lspci` command to check again.

### Updating VM with GPU Access

Let's go back to our Terraform platform project and add two PCI mappings for the GPU VGA and Audio devices:

```terraform
resource "proxmox_virtual_environment_hardware_mapping_pci" "gpu_vga" {
  name = "gpu_vga"
  map = [
    {
      node         = var.pm_node
      path         = "0000:01:00.0"
      id           = "10de:1f15"
      subsystem_id = "17aa:3a47"
      iommu_group  = 10
    }
  ]
}

resource "proxmox_virtual_environment_hardware_mapping_pci" "gpu_audio" {
  name = "gpu_audio"
  map = [
    {
      node         = var.pm_node,
      path         = "0000:01:00.1",
      id           = "10de:10f9",
      subsystem_id = "10de:10f9"
      iommu_group  = 10
    }
  ]
}
```

To find out the IOMMU group and the subsystem ID, run:

```bash
lspci -nnv -s "01:00.0"
lspci -nnv -s "01:00.1"
```

You'll see something like:

```
01:00.1 Audio device [0403]: NVIDIA Corporation TU106 High Definition Audio Controller [10de:10f9] (rev a1)
        Subsystem: NVIDIA Corporation TU106 High Definition Audio Controller [10de:10f9]
        Flags: fast devsel, IRQ 255, IOMMU group 10
        Memory at d1000000 (32-bit, non-prefetchable) [disabled] [size=16K]
        Capabilities: [60] Power Management version 3
        Capabilities: [68] MSI: Enable- Count=1/1 Maskable- 64bit+
        Capabilities: [78] Express Endpoint, IntMsgNum 0
        Capabilities: [100] Advanced Error Reporting
        Kernel driver in use: vfio-pci
        Kernel modules: snd_hda_intel
```

Under `Subsystem` you'll find the ID in brackets, and under `Flags` you'll find `IOMMU group <n>`.

We then modified our existing `proxmox_virtual_environment_vm.docker` resource to make sure that any GPU-enabled Docker VM will use `q35` for the machine, adding a mapping for the GPU devices (notice that only one VM can access the GPU, so only `docker-shared` will have GPU support):

```terraform
machine = try(local.docker[count.index].gpu, false) ? "q35" : "pc"

dynamic "hostpci" {
  for_each = try(local.docker[count.index].gpu, false) ? [
    proxmox_virtual_environment_hardware_mapping_pci.gpu_vga.name,
    proxmox_virtual_environment_hardware_mapping_pci.gpu_audio.name
  ] : []

  content {
    device  = "hostpci${hostpci.key}"
    mapping = hostpci.value
    pcie    = true
  }
}
```

After we `terraform apply` and once the VM boots, you should login and run:

```bash
lspci | grep NVIDIA
```

If you find two entries, for the VGA and Audio devices, similar to this, then you've got access to the GPU:

```
01:00.0 VGA compatible controller: NVIDIA Corporation TU106M [GeForce RTX 2060 Mobile] (rev a1)
02:00.0 Audio device: NVIDIA Corporation TU106 High Definition Audio Controller (rev a1)
```

### Installing NVIDIA Drivers on the VM

We use cloud-init to install the NVIDIA drivers and add GPU support to Docker. At the stage when we install the drivers, it's likely that on old kernel will be running, so we need to take measures to ensure that the driver will be installed for the kernel loaded in the next boot (i.e., the latest installed). After setting the NVIDIA driver version on `local.nvidia_driver_version`, the installation is done as follows:

```bash
## This retrieves the kernel name (e.g., 6.8.0-85-generic).
ls /boot/vmlinuz-* | sort | tail -n1 | cut -d- -f2- \
    > /run/nvidia-kernel-name

## Install dependencies for building the NVIDIA driver.
apt update && apt install -y build-essential \
	dkms linux-headers-$(cat /run/nvidia-kernel-name)

## Download the installation script.
wget https://us.download.nvidia.com/XFree86/Linux-x86_64/${local.nvidia_driver_version}/NVIDIA-Linux-x86_64-${local.nvidia_driver_version}.run

## Run the installation script for kernel that will be loaded on the
## next boot, and DKMS will ensure the driver will be rebuilt when a
## new kernel is installed.
sh NVIDIA-Linux-x86_64-${local.nvidia_driver_version}.run \
	--silent --dkms --kernel-name=$(cat /run/nvidia-kernel-name)

## Load the nvidia driver kernel modules.
cat <<EOF >>/etc/modules-load.d/modules.conf
nvidia
nvidia-modeset
nvidia_uvm
EOF

## Update initamfs to install the modules.
update-initramfs -u

## List all GPU devices, make GPU devices accessible by all users, and
## load required NVIDIA modules dynamically, when not loaded.
cat <<EOF >>/etc/udev/rules.d/70-nvidia.rules
KERNEL=="nvidia", RUN+="/bin/bash -c '/usr/bin/nvidia-smi -L && /bin/chmod 666 /dev/nvidia*'"
KERNEL=="nvidia_modeset", RUN+="/bin/bash -c '/usr/bin/nvidia-modprobe -c0 -m && /bin/chmod 666 /dev/nvidia-modeset*'"
KERNEL=="nvidia_uvm", RUN+="/bin/bash -c '/usr/bin/nvidia-modprobe -c0 -u && /bin/chmod 666 /dev/nvidia-uvm*'"
EOF
```

We turned the cloud-init config from Docker VMs into a Terraform template, adding the previous commands as `extracmds` when required (i.e., `gpu = true`). Once the Docker VM is provisioned with GPU access, you should be able to run `nvidia-smi` with any user and get information about your available GPUs and running processes.

That's it, we can run Ollama! 🎉

## Installing Services

Besides Portainer, which we'll use to monitor our Docker hosts and run small deployment tests, these are the services that we actually need to deploy:

- [Portainer](https://www.portainer.io/)
- [PostgreSQL](https://www.postgresql.org/)
- [MLflow](https://mlflow.org/)
- [Kafka](https://kafka.apache.org/)
- [Ollama](https://ollama.com/)
- [Open WebUI](https://openwebui.com/)

With the exception of Portainer and Open WebUI, these services are already configured in `datalab` within the `docker-compose.yml` that we provide for running locally. Therefore, we really just need to adapt the existing configuration, install Portainer and Open WebUI, and make sure our VM, and then Docker, both have access to the GPU, which is the bulk of the work here.

In our case, we'll get 6 GiB VRAM to load models, which, in practice, is extra memory that we get to use. The NVIDIA driver can then manage shared memory, as an overflow to RAM, that will take from the VM's assigned memory—I would disable this completely if I could, but in consumer hardware it doesn't seem possible.

We'll also migrate our existing `docker-compose.yml` into the new `infra/services/compose.yml`  file, keeping MinIO available through a `dev` profile. You'll have to run:

```bash
docker compose --profile dev up -d
```

This way, we'll keep things tidy.

## Setting Up CI/CD

Before being able to setup a `.gitlab-ci.yml` to automate docker compose stack deployment, we hit a snag with GitLab that we had to solve. The following section describes the problem and how we solved it, while the last section covers the actual CI/CD implementations.

### Handling GitLab Instability

While I was reworking the Docker VMs, to configure GPU passthrough and install the NVIDIA drivers, I had to destroy the `docker-gitlab` VM and even reboot Proxmox to uninstall the NVIDIA drivers from the host, as I'm not using the GPU on LXCs. Out of nowhere, my GitLab instance started experiencing an extremely high CPU load.

I ended up increasing the number of cores from 1 to 2, leaving only 1 core dedicated to the host. As planned, increasing the number of cores didn't require the VM to be destroyed, but it did stop it to make change, and then booted it up again. GitLab once again resumed its operation, hitting 100% of 2 cores for a while. Moments  later, it looked like it had become stable, but once I visited my repo I got a UI message saying `An error occurred while fetching commit data` and it froze, experiencing a high CPU load yet again.

At that point, after a few VM reboots to regain control, I noticed that `kswapd0` was working intensively and that the VM was listing only 2 GiB RAM internally when running `free -h`, which was the minimum set for ballooning. While it could theoretically be assigned 6 GiB RAM, and other VMs were using only a small fraction of their RAM, memory didn't seem to expand to 6 GiB, so I ended up increasing the `floating` setting to 4096, with an extra 2048 that I took from `docker-apps`. Since there is no swap anywhere, `kswapd0` was trying to get memory memory from other VMs with ballooning enabled, and it kept trying, while hogging resources.

Despite all efforts, the GitLab instance remained unstable, so, as a final attempt, I decided to move into resource overcommitment territory, increasing allocation to 4 cores and 8 GiB of RAM—without ballooning, i.e., the 8 GiB were 100% dedicated to the VM. This finally worked, so I decided to move forward with GitLab, for now at least, despite it feeling quite bloated, which I dislike—UNIX philosophy and all.

Besides the bloat—which might be justified—I also started questioning whether I could even run GitLab, given my resource constraints, without compromising my main services. Gitea has been reported to run with as little as 1 core and 512 MiB RAM, and I did run it in the past on a NAS with a 4-core arm64 and 1 GiB RAM, so I know it runs on environments with limited resources, albeit slower. In the future, I might do a trial run for Gitea, and consider migrating if it runs with less resources, while still fitting my needs. Something for another blog post and video though!

Either way, lesson learned: don't go below 4 cores and 8 GiB of RAM for GitLab!

#### Updated Resource Allocation Table

The updated resource allocation table, with resource overcommitment, is the following:

| ID      | VM/CT           |  Cores |    Disk | Dedicated Mem. | Floating Mem. | Free on Max. |
| ------- | --------------- | -----: | ------: | -------------: | ------------: | -----------: |
| 101     | `minio`         |      2 |     200 |           2048 |          2048 |         4096 |
| 201     | `gitlab`        |      4 |     100 |           8192 |          8192 |         4096 |
| 202     | `docker-gitlab` |      1 |     100 |           6144 |          2048 |            0 |
| 203     | `docker-shared` |      8 |     200 |          20480 |         12288 |        -4096 |
| 204     | `docker-apps`   |      2 |     100 |          10240 |          4096 |        -2048 |
| **ALL** | **TOTALS**      | **17** | **700** |      **47104** |     **22528** |       **-14336** |

We have now oversubscribed 1 core—17 cores out of 16 available cores are allocated to VMs. This not only means that there is no dedicated core for the host, but also that, in the unlikely scenario that all VMs try to use 100% CPU power, there won't be enough resources available, which will make them compete for CPU time—this is tracked in KVM as steal time—which is ok, as long as we don't abuse it too much.

We have also overcommitted 14,336 MiB of memory, over the maximum host memory of 32 GiB. Since we no swap on the host, we'll monitor memory usage and OOM kills so that we tune the overall memory allocation based on real-world statistics, or we decide to simply buy more RAM. In practice, we should never have negative values on the "Free on Max." column, except for its total—negative values mean that the VM will never be able to fully allocate its "Dedicated Mem.", even when all other VMs are at minimum usage (i.e., only "Floating Mem.", the minimum, is allocated).

### Automating Data Stack with CI/CD

#### Creating a GitLab Project

First, you need to login to a non-root user on GitLab, and create a new project. I suggest that you call it `datalab`, but that's optional. Once created, go into Settings → Access tokens and add a new `terraform` token, with `Maintainer` role, and `api` permissions. This will be used to initialize all GitLab variables with your local `.env` configs, so you don't have to manually input the variables twice (i.e., for generic local use and for CI/CD).

Under `infra/services/gitlab/terraform.tfvars`, make sure to set:

```terraform
gitlab_token = "glpat-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX.XX.XXXXXXXXX"
```

Then, after having configured your `.env`, run `terraform apply` under `infra/services/gitlab` as usual. This will create the corresponding GitLab variables under your project, masking and hiding all variables with a name containing `PASSWORD`, `ACCESS_KEY`, or `SECRET`.

#### Setting Up Git for Deployment

After cloning the `datalab` repo from GitHub, you should setup your GitLab remotes as follows:

```bash
cd datalab/
git remote add infra git@gitlab:datalabtechtv/datalab.git
git config remote.infra.push "+HEAD:infra"
```

This will enable push-only to a GitLab project of your choice, always to the `infra` branch, always force pushing. This way, we can deploy from our `main` or `dev` branch, by running:

```bash
git push infra
```

#### Organizing CI/CD Pipeline

Once the variables are available to CI/CD, we can create our [.gitlab-ci.yml](https://github.com/DataLabTechTV/datalab/blob/ba48b987d198c5788527e054b31a7d7528a7c91b/.gitlab-ci.yml) file. Unfortunately, since GitLab doesn't support multiple workflows, all of our workflows will live under the same pipeline (i.e., Docker Compose deployments, PostgreSQL database and credential creation, Kafka topics and groups, Ollama models).

We'll define four stages, one per workflow, with task dependencies being set through `needs` rather than `stages`:

```yaml
stages:
  - deploy
  - postgres
  - kafka
  - ollama
```

We'll then split the workflows into four includable files under [.ci/](https://github.com/DataLabTechTV/datalab/tree/ba48b987d198c5788527e054b31a7d7528a7c91b/.ci):

```yaml
include:
  - .ci/deploy.yml
  - local: .ci/postgres.yml
    inputs:
      db_user: $[[ inputs.postgres_db_user ]]
      db_name: $[[ inputs.postgres_db_name ]]
  - local: .ci/kafka.yml
    inputs:
      topic: $[[ inputs.kafka_topic ]]
      group: $[[ inputs.kafka_group ]]
  - local: .ci/ollama.yml
    inputs:
      pull: $[[ inputs.ollama_pull ]]
```

Each of these files will have their own `spec.inputs`, as will our main pipeline under `.gitlab-ci.yml`, as the header:

```yaml
spec:
  inputs:
    postgres_db_user:
      description: "PostgreSQL username to create and grant privileges to"
      type: string
      default: ""
    postgres_db_name:
      description: "PostgreSQL database to create"
      type: string
      default: ""
    kafka_topic:
      description: "Kafka topic to create"
      type: string
      default: ""
    kafka_group:
      description: "Kafka group to create"
      type: string
      default: ""
    ollama_pull:
      description: "Ollama model name to pull"
      type: string
      default: ""

---
```

#### Docker Deployments

Under [.ci/deploy.yml](https://github.com/DataLabTechTV/datalab/blob/1bab0dcd246a5d63221910310dd382b081c4add2/.ci/deploy.yml), we will trigger the deployment job whenever files under `infra/services/docker/` are changed—this only activates on `push`.

```yaml
services_deploy:
  stage: deploy
  image: docker:28.4.0-cli
  variables:
    DOCKER_HOST: tcp://docker-shared:2375
  script:
    - docker compose -p datalab -f infra/services/docker/compose.yml up -d
    - docker ps
  rules:
    - if: $CI_PIPELINE_SOURCE == "push"
      changes:
        - infra/services/docker/**
```

As you can see, we use the `docker` image instead of the default `ubuntu` runner, setting `DOCKER_HOST` to the `docker-shared` context, directly using its hostname and port. The `rules` are set so that this job only activate on `push` and if there are changes to the corresponding files. This assumes that the CI/CD variables are already available within the GitLab project.

#### Compose Project Details

Our Docker Compose Project has 7 services and an additional 3 init services, that run only once (we set them to `restart: no`).

In order to ensure `datalab` remains backward compatible in the sense that we can still run the whole stack on a local Docker instance, we include `minio` as a service, under an optional `dev` project. MinIO is not a part of the data stack running on layer 3, since we already run it on layer 1, however we keep this as a convenience for quickly spinning up the `datalab` stack locally.

Apart from `minio`, we also provide `postgres`, with an admin user `root`, `ollama`, `open-webui`, `mlflow` running on a SQLite backend and a MinIO bucket for artifact storage, `kafka` as a single node without replication, running one broker and controller, and `portainer` to help monitor our Docker instances.

The provided `*-init` services produce a container that runs only once for initializations: `minio-init` creates default buckets, `ollama-init` pulls default models, and `kafka-init` creates topics and initializes consumers for topics/groups.

In general, each service has its own network and volume, with init services sharing the same network as their corresponding parent services. All init services depend on their parent services being on a healthy status, so that we can run commands on them. For example, for `ollama-init` we set:

```yaml
depends_on:
  ollama:
	condition: service_healthy
```

Implementing health checks on the parent services was mostly constrained by the available tools within the specific base image used for each service (e.g., `curl` wasn't necessarily available). Here are is a summary of the health check commands that we used:

| Service    | Health Check                                                                         |
| ---------- | ------------------------------------------------------------------------------------ |
| `minio`    | `curl -f http://localhost:9000/minio/health/live`                                    |
| `postgres` | `pg_isready`                                                                         |
| `ollama`   | `ollama ls`                                                                          |
| `mlflow`   | `python -c "import urllib.request; urllib.request.urlopen('http://localhost:5000')"` |
| `kafka`    | `/opt/kafka/bin/kafka-topics.sh --bootstrap-server kafka:29092 --list`               |

The configuration for each service is heavily dependent on environment variables defined within a `.env` file on the root of the project, as we don't deploy any secrets management service, like HashiCorp Vault.

The `open-webui` service also runs on the `ollama` network, and the `ollama` service requires GPU support, which was defined as follows:

```yaml
deploy:
  resources:
	reservations:
	  devices:
		- driver: nvidia
		  count: all
		  capabilities: [gpu]
```

Finally, `portainer` porta 9000 was remapped to 9080, so it wouldn't collide with `minio`. We opted to change the port for Portainer rather than MinIO, since this is a secondary service used only for monitoring, and it doesn't require any configs on `datalab`.

#### PostgreSQL Databases

Under [.ci/postgres.yml](https://github.com/DataLabTechTV/datalab/blob/1bab0dcd246a5d63221910310dd382b081c4add2/.ci/postgres.yml), we provide a workflow to provision a PostgreSQL database and credentials, which will be used by our applications from Layer 4 (see upcoming blog post and video).

We specify a `spec.inputs` header with `db_user` and `db_name` inputs:

```yaml
spec:
  inputs:
    db_user:
      description: "PostgreSQL username to create and grant privileges to"
      type: string
    db_name:
      description: "PostgreSQL database to create"
      type: string

---
```

And two jobs, `psql_create_user` and `psql_create_db`:

```yaml
psql_create_user:
  stage: postgres
  image: docker:28.4.0-cli
  variables:
    DOCKER_HOST: tcp://docker-shared:2375
  before_script:
    - apk add --no-cache openssl
  script:
    - # OMITTED
  rules:
    - if: '"$[[ inputs.db_user ]]" != ""'
    - when: never

psql_create_db:
  stage: postgres
  image: docker:28.4.0-cli
  variables:
    DOCKER_HOST: tcp://docker-shared:2375
  script:
    - # OMITTED
  needs:
    - psql_create_user
  rules:
    - if: '"$[[ inputs.db_name ]]" != ""'
    - when: never

```

Notice that `psql_create_db` needs `psql_create_user`, so it will always run after it.

Also notice that each job will only activate when the corresponding input is non-empty, which only happens when we manually launch the CI/CD pipeline, filling those values, via Build → Pipelines → New pipeline, as shown in the following screenshot:

![GitLab Run New Pipeline](./gitlab-run_new_pipeline.png)

#### Kafka Topics and Groups

Under [.ci/kafka.yml](https://github.com/DataLabTechTV/datalab/blob/1bab0dcd246a5d63221910310dd382b081c4add2/.ci/kafka.yml), we provide a workflow to create a Kafka topics and initialize consumers for topics/groups. Similarly, this will be used by our applications from Layer 4.

We specify a `spec.inputs` header with `topic` and `group` inputs:

```yaml
spec:
  inputs:
    topic:
      description: "Kafka topic to create"
      type: string
    group:
      description: "Kafka group to create"
      type: string
```

And two jobs, `kafka_create_topic` and `kafka_init_consumer`:

```yaml
kafka_create_topic:
  stage: kafka
  image: docker:28.4.0-cli
  variables:
    DOCKER_HOST: tcp://docker-shared:2375
  script:
    - # OMITTED
  rules:
    - if: '"$[[ inputs.topic ]]" != ""'
    - when: never

kafka_init_consumer:
  stage: kafka
  image: docker:28.4.0-cli
  variables:
    DOCKER_HOST: tcp://docker-shared:2375
  script:
    - # OMITTED
  needs:
    - kafka_create_topic
  rules:
    - if: '"$[[ inputs.topic ]]" != "" && "$[[ inputs.group ]]" != ""'
    - when: never
```

Again, notice a dependency of `kafka_create_topic` by `kafka_init_consumer`, and notice that these jobs require their corresponding inputs to be non-empty to run (`if: ...`), otherwise they will never run (`when: never`).

#### Ollama Models

Under [.ci/ollama.yml](https://github.com/DataLabTechTV/datalab/blob/1bab0dcd246a5d63221910310dd382b081c4add2/.ci/ollama.yml), we provide a very basic workflow to pull models. There is no workflow to otherwise manage models.

Here is the complete content for the Ollama CI workflow:

```yaml
spec:
  inputs:
    pull:
      description: "Pull Ollama model"
      type: string

---

ollama_pull:
  stage: ollama
  image: docker:28.4.0-cli
  variables:
    DOCKER_HOST: tcp://docker-shared:2375
  script:
    - 'echo "Installing Ollama model: $[[ inputs.pull ]]"'
    - docker exec datalab-ollama-1 ollama pull $[[ inputs.pull ]]
  rules:
    - if: '"$[[ inputs.pull ]]" != ""'
    - when: never
```

The logic is similar to the one described for the PostgreSQL and Kafka CI workflows.

## Final Remarks

There is a lot to criticize based on our design choices, as well as tech stack selection. Next time, we'll show you how to deploy an application using this stack, but also do a retrospective on what could be improved. Overall, the same logic will apply, but there's a few things we would definitely change, mainly regarding the decision to use GitLab versus Gitea. There are also a few added complexities that we would like to simplify, while at the same time revising our decision to purely rely on GitLab for secrets management rather than a more dedicated solution like HashiCorp Vault.

Subscribe to [@DataLabTechTV](https://youtube.com/@DataLabTechTV?sub_confirmation=1) on YouTube, or keep following this blog so you don't miss it! There's [RSS](https://datalabtechtv.com/posts/index.xml), if you're old-school like me, or social media ([Bluesky](https://bsky.app/profile/datalabtechtv.com), [Reddit](https://www.reddit.com/r/DataLabTechTV/), [Discord](https://discord.gg/V5c5htsF)), if you prefer it that way.
