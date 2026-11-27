---
title: "Grafana PCP Dashboard & Moving to libvirt | Project Homelab #6"
description: Let's configure a Grafana PCP dashboard and work on libvirt in OpenTofu.
date: 2026-11-27T18:00:00+0000
categories: [DevOps]
tags: [homelab, monitoring, grafana, grafana-pcp, libvirt, iac, opentofu, video]
---

## Summary

In this video, we show off the Grafana PCP Dashboard started on the last video, describing the configs and command line tools required to get it up and running. We also start a refactoring of our OpenTofu project to accommodate VM provisioning based either on Proxmox or libvirt, with Proxmox being our current approach and libvirt being the newcomer.

This series picks up where Data Lab Infra left off, but it has a broader scope, including for example the deployment of an Agentic AI stack, or a Forgejo local instance with a working CI runner, used to build a custom bootc image for Bazzite. Everything is done with resource to IaC, as a combination of Just for orchestration, OpenTofu for VM provisioning, and Ansible for system configuration and Quadlet deployment. We also cover sandboxing and quadlets lightly, we explore an alternative to Proxmox for managing virtual machines, and we delve a little deeper into AI infrastructure.

<div style="position: relative; padding-bottom: 56.25%; height: 0; overflow: hidden; max-width: 100%;">
    <iframe
        src="https://www.youtube.com/embed/4aKL4CSiVmo"
        frameborder="0"
        allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
        referrerpolicy="strict-origin-when-cross-origin"
        allowfullscreen
        style="position: absolute; top: 0; left: 0; width: 100%; height: 100%;">
    ></iframe>
</div>
