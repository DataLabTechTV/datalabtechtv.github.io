---
title: "Replacing Proxmox with a Custom uCore HCI Image | Project Homelab #4"
description: Learn how to build a custom uCore HCI bootc image for your homelab.
date: 2026-11-23T13:30:00+0000
categories: [DevOps]
tags: [homelab, ucore, immutable, bootc, image, video]
---

## Summary

In this video, we prepare a custom bootc image based on uCore HCI, with the goal of replacing Proxmox as our hypervisor host OS. You'll learn how to setup a GitHub repo based on the image-template repo from ublue-os, including configuring image-template.env, artifacthub-repo.yml, and setting up your Containerfile and build.sh script.

This series picks up where Data Lab Infra left off, but it has a broader scope, including for example the deployment of an Agentic AI stack, or a Forgejo local instance with a working CI runner, used to build a custom bootc image for Bazzite. Everything is done with resource to IaC, as a combination of Just for orchestration, OpenTofu for VM provisioning, and Ansible for system configuration and Quadlet deployment. We also cover sandboxing and quadlets lightly, we explore an alternative to Proxmox for managing virtual machines, and we delve a little deeper into AI infrastructure.

<div style="position: relative; padding-bottom: 56.25%; height: 0; overflow: hidden; max-width: 100%;">
    <iframe
        src="https://www.youtube.com/embed/ps6V56TrAXw"
        frameborder="0"
        allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
        referrerpolicy="strict-origin-when-cross-origin"
        allowfullscreen
        style="position: absolute; top: 0; left: 0; width: 100%; height: 100%;">
    ></iframe>
</div>

