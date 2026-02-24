---
title: "LabStore - Part 6 - Building an Object Store in Go: S3-Compatible TUI"
description: Learn the basics of TUI building with lipgloss and bubbletea, from the charm stack.
date: 2026-02-24T13:00:00+0100
categories: [Software Engineering]
tags: [s3, go, object-store, aws, cli, tui, client, video]
---

## Summary

Learn the basics of TUI building with [lipgloss](https://github.com/charmbracelet/lipgloss) and [bubbletea](https://github.com/charmbracelet/bubbletea), from the [charm stack](https://charm.land/libs/). We'll cover the `tea.Model` interface and its `Init()`, `Update()`, and `View()` methods. We'll look into the event loop, and the best way to setup messages and handle downstream/upstream updates. We'll show you how to use Go channels in a way that lets you track progress without affecting the performance of the underlying task. And we'll cover component design with `lipgloss`, using the [bubbletea-overlay](github.com/rmhubbert/bubbletea-overlay) library, by `rmhubbert`, for composition, a feature that is currently under development in the beta, coming in `v2.0.0` as layers.

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
