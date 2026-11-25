---
title: "Monitoring uCore HCI with Grafana PCP | Project Homelab #5"
description: Learn how to build a custom uCore HCI bootc image for your homelab.
date: 2026-11-25T14:15:00+0000
categories: [DevOps]
tags: [homelab, monitoring, grafana, grafana-pcp, performance-co-pilot, ucore, video]
---

## Summary

Today, we pickup where we left off, configuring our custom bootc image based on uCore HCI to provide Grafana with support for PCP (Performance Co-Pilot), and also adding metrics to PCP for monitoring libvirt VMs. We explore dashboard creation on Grafana, demonstrating that the components we installed are enough to display metrics per VM.

This series picks up where Data Lab Infra left off, but it has a broader scope, including for example the deployment of an Agentic AI stack, or a Forgejo local instance with a working CI runner, used to build a custom bootc image for Bazzite. Everything is done with resource to IaC, as a combination of Just for orchestration, OpenTofu for VM provisioning, and Ansible for system configuration and Quadlet deployment. We also cover sandboxing and quadlets lightly, we explore an alternative to Proxmox for managing virtual machines, and we delve a little deeper into AI infrastructure.

<div style="position: relative; padding-bottom: 56.25%; height: 0; overflow: hidden; max-width: 100%;">
    <iframe
        src="https://www.youtube.com/embed/uMRW7ua-fkM"
        frameborder="0"
        allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
        referrerpolicy="strict-origin-when-cross-origin"
        allowfullscreen
        style="position: absolute; top: 0; left: 0; width: 100%; height: 100%;">
    ></iframe>
</div>


