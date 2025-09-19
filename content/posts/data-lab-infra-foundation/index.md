---
title: "Data Lab Infra - Part 2: Bootstrapping with Terraform"
description: Learn how to setup Terraform, with an S3-backed state, to deploy the foundation layer of your on-premise homelab infrastructure running on Proxmox.
date: 2025-09-23T12:00:00+0100
categories: ["DevOps"]
tags: ["homelab", "foundation", "proxmox", "minio", "terraform", "secrets-management", "video"]
---

## Summary

On part 2 of this series, you'll learn the basics of Terraform, provisioning a MinIO server as an LXC (Linux Container) running on Proxmox.

Then, you'll learn how to use this foundation infrastructure, consisting of the MinIO S3-compatible object store, to track the state of a separate Terraform project in a way that will let you update your infrastructure from any location with access to your Proxmox instance.

These skills are loosely transferable to cloud platforms like AWS, GCP or Azure, with the advantage that it costs zero to setup Proxmox at home, if you've got some old hardware lying around.

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

## Proxmox

### Terraform Access

After installing Proxmox, we'll create a `terraform` user. This needs to be a PAM user, since Terraform's [bpg/proxmox](https://registry.terraform.io/providers/bpg/proxmox) provider will need shell access to be able to run a few actions that are not supported by the API, like downloading Debian or Ubuntu images. We'll disable password login for this user, because we'll exclusively rely on SSH keys for shell access.

We create the system user:

```bash
adduser --disabled-password terraform
pveum user add terraform@pam
```

And an associated role with the [permissions required by the provider](https://registry.terraform.io/providers/bpg/proxmox/latest/docs#api-token-authentication):

<pre wrap>
pveum role add Terraform -privs "Realm.AllocateUser, VM.PowerMgmt, VM.GuestAgent.Unrestricted, Sys.Console, Sys.Audit, Sys.AccessNetwork, VM.Config.Cloudinit, VM.Replicate, Pool.Allocate, SDN.Audit, Realm.Allocate, SDN.Use, Mapping.Modify, VM.Config.Memory, VM.GuestAgent.FileSystemMgmt, VM.Allocate, SDN.Allocate, VM.Console, VM.Clone, VM.Backup, Datastore.AllocateTemplate, VM.Snapshot, VM.Config.Network, Sys.Incoming, Sys.Modify, VM.Snapshot.Rollback, VM.Config.Disk, Datastore.Allocate, VM.Config.CPU, VM.Config.CDROM, Group.Allocate, Datastore.Audit, VM.Migrate, VM.GuestAgent.FileWrite, Mapping.Use, Datastore.AllocateSpace, Sys.Syslog, VM.Config.Options, Pool.Audit, User.Modify, VM.Config.HWType, VM.Audit, Sys.PowerMgmt, VM.GuestAgent.Audit, Mapping.Audit, VM.GuestAgent.FileRead, Permissions.Modify"

pveum acl modify / -user terraform@pam -role Terraform
</pre>

We'll need an API key as well, which we can create with:

```bash
pveum user token add terraform@pam datalabtech --privsep 0
```

We disable Privilege Separation to make sure that we use the Terraform role we defined previously, but API keys can have their own, more restrict permissions. Make sure to save the token ID and value to use when configuring Terraform.

Now, on your host machines—those that will be able to run Terraform—create an SSH key to be added to the terraform account:

```bash
ssh-keygen -t ed25519 -C proxmox -f ~/.ssh/proxmox
```

Currently, `ed25519` is the default key type anyway, but making it explicit ensures the command will endure the test of time. We also use `-C` so that information about our user and host is not leaked in the key. Finally, the naming scheme for the key file is simply the name of the target service—if we had multiple accounts for a service (e.g., multiple GitHub accounts), then we'd use something like `github-account1`, `github-account2`, etc., but one thing we should avoid is sharing keys, even between the same user on different machines.

Copy the public key from the host machine:

```bash
cat ~/.ssh/proxmox.pub | pbcopy
```

And then just drop it on Proxmox under `/home/terraform/.ssh/authorized_keys`:

```bash
mkdir ~terraform/.ssh
vi ~terraform/.ssh/authorized_keys
# Paste public key and save
```

From your host machine, you can then test if access was correctly setup (e.g., using `proxmox` as your hypervisor host):

```bash
ssh -i ~/.ssh/proxmox terraform@proxmox
```

### GPU Support

It's possible to passthrough your GPU NVIDIA card to VMs or CTs. This is how we setup the hypervisor machine drivers.

#### Step 1: Blacklist nouveau

We'll want to use the proprietary drivers, so we need to disable the open source `nouveau` drivers.

```shell
vi /etc/modprobe.d/blacklist.conf
```

Add the following line:

```
blacklist nouveau
```

And then run:

```shell
update-initramfs -u
reboot
```

#### Step 2: Install NVIDIA drivers

Under `Updates` ▶ `Repositories`, make sure that the `No-Subscription` and `Ceph` `No-Subscription` repositories are configured and that the corresponding Enterprise versions are disable.

Then run:

```bash
apt update && apt upgrade -y
apt install pve-headers build-essential -y
```

[Download the official NVIDIA drivers](https://www.nvidia.com/en-us/drivers/) for  Linux 64-bit, assuming that's your arch. I usually just search for my card and copy the link to the `.run` script, so I can download directly to Proxmox using `wget`. For example:

```bash
wget https://us.download.nvidia.com/XFree86/Linux-x86_64/<version>/NVIDIA-Linux-x86_64-580.82.09.run
sh NVIDIA-Linux-x86_64-580.82.09.run
```

You can accept 32-bit libraries, if the option is provided (but I didn't). Don't run the `nvidia-xconfig` utility, as Proxmox is headless, and there is no X11 installation. You can also safely ignore any warnings about inferring or not finding X11 libraries.

#### Step 3: Load drivers on boot

In order for drivers to be loaded on boot, you need to edit your `modules.conf`:

```shell
vi /etc/modules-load.d/modules.conf
```

Add:

```
nvidia
nvidia-modeset
nvidia_uvm
```

And run:

```shell
update-initramfs -u
```

Also edit:

```shell
vi /etc/udev/rules.d/70-nvidia.rules
```

And add:

```
KERNEL=="nvidia", RUN+="/bin/bash -c '/usr/bin/nvidia-smi -L && /bin/chmod 666 /dev/nvidia*'"
KERNEL=="nvidia_modeset", RUN+="/bin/bash -c '/usr/bin/nvidia-modprobe -c0 -m && /bin/chmod 666 /dev/nvidia-modeset*'"
KERNEL=="nvidia_uvm", RUN+="/bin/bash -c '/usr/bin/nvidia-modprobe -c0 -u && /bin/chmod 666 /dev/nvidia-uvm*'"
```

Then you can `reboot`, and run `nvidia-smi` to ensure the drivers are operational. That's it. Everything else will be done at the VM or CT level, and we'll discuss it at a later time.

## Terraform

### Installation

The best way to install Terraform is using [tfswitch](https://tfswitch.warrensbox.com/Installation/). Follow the installation instructions and, once that is done, just run `tfswitch` and select your version of Terraform.

If you have other initialized Terraform projects, running `tfswitch` from the root directory will automatically install the version of Terraform required for that project. You'll need to re-run this for Terraform projects that require different versions.

The version is usually setup under `versions.hcl` as follows:

```terraform
terraform {
  required_version = "~> 1.13.2"
}
```

### Accessing Secrets

By default, running `terraform output` will redact sensitive variables (i.e., secrets), but it's possible access the value with the `-raw` argument, only for a specific output. We suggest that you never print the secret plainly to the console, but instead pipe it to a copy command, like `pbcopy` (pasteboard copy) on Mac, or `xclip -selection clipboard` on Linux (I personally alias this to `pbcopy` on Linux as a convention).

```bash
terraform -chdir=infra/foundation \
    output -raw minio_admin_password | pbcopy
```

### S3 State Storage

Since variables can only be accessed after `terraform init`, we cannot use regular variables to configure the backend for state storage. Instead, the documentation suggests that we use a `state.config` file for this.

So, we begin with an empty backend config:

```terraform
terraform {
  backend "s3" {}
}
```

And we produce a `state.config` file that looks like this:

```terraform
bucket = "terraform"
key    = "state/platform/terraform.tfstate"

endpoints = {
  s3 = "http://minio:9000"
}

region     = "eu-west-1"
access_key = "admin"
access_key = "XXXXXXXXXXXXXXXXXXXX"

skip_credentials_validation = true
skip_metadata_api_check     = true
skip_requesting_account_id  = true
use_path_style              = true
```

The previous file is already provided to you under `state.config.example`. You can copy it to `state.config` and replace the access key:

```bash
cp infra/platform/state.config.example infra/platform/state.config
vim infra/platform/state.config
# Replace secret_key with your MinIO admin password and save
```

You can then init your stored state Terraform project:

```bash
terraform -chdir=infra/platform init -backend-config=state.config
```

### Deployment

After having run `terraform init` for each project, you can then deploy the infrastructure as shown below. Remember that the platform layer is built on top of the foundation layer, so this it is a requirement that is deployed first.

```bash
terraform -chdir=infra/foundation apply -auto-approve
terraform -chdir=infra/platform apply -auto-approve
```

Now, if you clone the `datalab` repo to a different location and run the `init` command for the platform project, using the proper `state.config`, you'll be able to access your latest Terraform state. This will let you work from anywhere, as long as you have access to Proxmox—I recommend setting up a VPN to your homelab using WireGuard, if you're outside of your local network.

## Justfile Tasks

For your convenience, we provide several top-level `just` tasks on `datalab` that you can use, if you forget the commands:

- `infra-config-check` – check for terraform and the required configs for all infra projects.
- `infra-init` – run the proper terraform init commands for each project (must be manually run before `infra-deploy`).
- `infra-deploy` – deploy each layer of the architecture in sequence (`foundation` and `platform` are the only ones supported at this time).
- `infra-show-credentials`  – print all credentials, for each layer, in plain text.

Any task in this video series will begin with the prefix `infra-`, so you can keep a look for these in the upcoming videos.
