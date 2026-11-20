---
title: "Beyond Proxmox: Installing uCore HCI with Butane | Project Homelab #3"
description: Learn how to replace Proxmox with uCore HCI, using butane to configure it.
date: 2026-11-20T18:00:00+0000
categories: [DevOps]
tags: [homelab, ucore, cockpit, libvirt, coreos, fedora, proxmox, butane, ignition, video]
---

## Summary

In this video, we install uCore HCI in a VM, using the recommended method based on coreos-installer and butane. This approach first installs CoreOS and then rebases into uCore HCI based on the ignition file produced from on our butane configuration. Using nested virtualization, we demonstrate how to manage VMs through Cockpit and libvirt on uCore HCI, which can essentially replace Proxmox.

This series picks up where Data Lab Infra left off, but it has a broader scope, including for example the deployment of an Agentic AI stack, or a Forgejo local instance with a working CI runner, used to build a custom bootc image for Bazzite. Everything is done with resource to IaC, as a combination of Just for orchestration, OpenTofu for VM provisioning, and Ansible for system configuration and Quadlet deployment. We also cover sandboxing and quadlets lightly, we explore an alternative to Proxmox for managing virtual machines, and we delve a little deeper into AI infrastructure.

<div style="position: relative; padding-bottom: 56.25%; height: 0; overflow: hidden; max-width: 100%;">
    <iframe
        src="https://www.youtube.com/embed/RvQLGQfRoRs"
        frameborder="0"
        allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
        referrerpolicy="strict-origin-when-cross-origin"
        allowfullscreen
        style="position: absolute; top: 0; left: 0; width: 100%; height: 100%;">
    ></iframe>
</div>

