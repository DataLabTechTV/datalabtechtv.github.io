---
title: "LabStore - Part 3 - Building an Object Store in Go: Benchmarking"
description: Benchmarking S3-compatible object stores—LabStore, MinIO, Garage, SeaweedFS, RustFS—and setting up a Go profiling to detect bottlenecks.
date: 2025-12-09T12:00:00+0100
categories: [Software Engineering]
tags: [s3, go, object-store, aws, benchmark, video]
---

## Summary

Learn how to deploy multiple S3-compatible object stores, including LabStore, MinIO, Garage, SeaweedFS, and RustFS, using Docker Compose. Once the stack is running, you'll learn how to benchmark throughput using warp by MinIO. You'll also learn how to setup Go profiling, which we use in LabStore to help us identify bottlenecks and drive performance optimization. Everything is orchestrated with Just commands, split into two modules, infra for provisioning the Docker stack, and benchmark for running tests and analyzing throughput.

Follow this series with IllumiKnow Labs, and let's see where this journey takes us. Hopefully you'll learn a lot along the way!

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
