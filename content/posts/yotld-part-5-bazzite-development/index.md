---
title: "Year of the Linux Desktop #5: Development in Immutable Bazzite"
description: Learn how to install your IDE with a Flatpak, and use distrobox for your dev tooling and environment.
date: 2026-04-07T12:00:00+0100
categories: [DevOps]
tags: [linux, bazzite, development, immutable, flatpak, distrobox, video]
---

## Summary

What changes with immutable distros for developers? What is the best way to setup your dev stack in Bazzite? In this blog post, we'll cover Flatpaks for the IDE, and distrobox for your dev tooling and environment. You'll learn how to configure VS Code in Flatpak, so that it works with the host's Podman to attach to a distrobox container.

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

## Flatpak and Distrobox

I would say these are the options to setup a dev env in Bazzite:

- Rebase to Bazzite DX and go from there.
- Install everything via Homebrew.
- Install anything else via `rpm-ostree install`.
- Use Flatpaks for your GUIs (IDE, etc.).
- Use Distrobox as a mutable layer to manage tooling.

Personally, I didn't want the lock-in of [Bazzite DX](https://dev.bazzite.gg/). While I'm still using Visual Studio Code, I plan to move to Zed soon, and I also dropped Docker for Podman, which already comes preinstalled in regular Bazzite. Anyway, Bazzite DX was out for me.

Installing from Homebrew is a great option, and I do install many tools from there, that I want to have available to me in the host CLI (i.e., Bazzite directly, not Distrobox). Now, layering on top of the Bazzite image, with `rpm-ostree install`, while viable, it's something I would prefer to avoid. I wanted immutable, so I'll drink of the immutable cup.

I ended up going the Flatpak and Distrobox route. Since you can attached to a running container from VSCode anyway, it's a viable option. I'm also moving away from anything Microsoft, so I wouldn't want to adopt dev containers, even though there is no proper alternative to them in neutral territory.

#### What Worked

I installed Visual Studio Code from Flathub, and the installed `podman-host`, configuring `Dev > Containers: Docker Path` to point to `~/.local/bin/podman-host`:

```bash
curl -s https://raw.githubusercontent.com/89luca89/distrobox/main/extras/podman-host \
    -o ~/.local/bin/podman-host && chmod +x ~/.local/bin/podman-host
```

Then I setup everything I required using distrobox:

```ini
[devbox]
image=fedora-toolbox:latest
entry=false
nvidia=true

## --- shell basics ---
pre_init_hooks=export SHELL=/usr/bin/fish
pre_init_hooks=dnf copr enable -y atim/starship
additional_packages=fish starship chezmoi direnv fastfetch
additional_packages=zoxide bat ripgrep fd-find
init_hooks=cargo install --root /usr/local eza

## --- general tools ---
additional_packages=ncdu btop prettyping jq yq

## --- image tools ---
pre_init_hooks=dnf install -y https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
additional_packages=ImageMagick ImageMagick-heic libheif-freeworld libde265
init_hooks=uv tool install rembg[gpu,cli]

## --- network tools ---
additional_packages=rclone iperf3 nc
init_hooks=go install github.com/minio/mc@latest
init_hooks=go install github.com/peak/s5cmd/v2@master
init_hooks=go install github.com/minio/warp@latest
init_hooks=uv tool install --with=httpie-aws-authv4 httpie

## --- data tools ---
init_hooks=uv tool install termgraph==0.7.4

## --- ai tools ---
additional_packages=zstd
init_hooks=curl -fsSL https://ollama.com/download/ollama-linux-amd64.tar.zst | tar x -C /usr

## --- development basics ---
additional_packages=git just pre-commit cloc neovim
init_hooks=alternatives --install /usr/bin/vim vim /usr/bin/nvim 100
pre_init_hooks=dnf copr enable -y dejan/lazygit
additional_packages=lazygit

## --- container tools ---
additional_packages=docker-cli docker-compose
volume=/run/user/1000/podman/podman.sock:/var/run/docker.sock
init_hooks=go install github.com/jesseduffield/lazydocker@latest

## --- languages: go, rust, python, node ---
additional_packages=golang rust cargo uv nodejs
init_hooks=go install golang.org/x/tools/gopls@latest

## --- web dev: hugo ---
init_hooks=go install github.com/gohugoio/hugo@v0.147.1

## --- linting: go ---
additional_packages=golangci-lint

## --- databases: sqlite, duckdb ---
additional_packages=sqlite3
init_hooks=curl https://install.duckdb.org | sh
```

And from VSCode run the command `Dev Containers: Attach to Running Container...` and select `devbox` from the active containers.

#### What Didn't Work

I have also tried other approaches that failed, like installing VSCode directly inside distrobox and exporting it as an app to the host:

```bash
distrobox-export --app code
```

This had several issues, like problems logging in to GitHub to sync the settings. I also tried to use the Flatpak for Go:

```bash
flatpak install org.freedesktop.Sdk.Extension.golang
```

Setting up in Flatseal to run with VSCode:

```bash
FLATPAK_ENABLE_SDK_EXT=golang
```

This worked for VSCode, but not for Zed, which I also tried. Regardless, it is a lousy approach to require a Flatpak to exist for each SDK you need to setup. This is what containers are for.
