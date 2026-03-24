---
title: "Year of the Linux Desktop #7: Building a Custom Bazzite Image"
description:
date: 2026-04-21T12:00:00+0100
categories: [DevOps]
tags: [linux, bazzite, desktop, immutable, bootc, image, oci, video]
---

## Summary



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

## Background Knowledge

We are starting from [Bazzite](https://bazzite.gg/), which is a `bootc` image based on [Fedora Atomic](https://fedoraproject.org/atomic-desktops/) and maintained by [Universal Blue](https://universal-blue.org/). Universal Blue also provides two other images, [Aurora](https://getaurora.dev/en/), a general desktop image based on KDE, and [Bluefin](https://projectbluefin.io/), a workstation image based on GNOME. I picked Bazzite because I'm installing on a desktop that I use for work but also gaming, and setting up game support is a lot harder than setting up everything else.

### Filesystem

When preparing your custom `bootc` image, there are a few things worth knowing regarding the filesystem. The following table covers those details, or at least what I understood so far:

| Path         | Observation                                                                                                                                                     |
| ------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `/usr`       | Immutable. Shows up in the system exactly as you see it during build time, i.e., as defined in the `Containerfile`.                                             |
| `/usr/local` | Mutable and a symlink to `/var/usrlocal`. Should not be touched during build time, using either path.                                                           |
| `/opt`       | Mutable and symlinked to `/var/opt` by default. Optionally immutable, if `/opt` is removed during build time. Different images can decide how to handle `/opt`. |
| `/etc`       | Mutable, real directory. Files in this directory are a mix between the files in the image's `/etc` directory and user changes, which take precedence.           |

There are other helpful details that we, as users, don't usually think about. For example, I was initially using an immutable `/opt` to drop system-wide `uv` tools (`/opt/uv/<tool>`), until I realized I should instead be using something like `/usr/share/uv/tools/<tool>`. This is the type of mindset you must build for yourself when working on OS components.

### Template Repo

While [bazzite-nvidia-open](https://github.com/ublue-os/bazzite/pkgs/container/bazzite-nvidia-open) is a regular container image, the best way to setup your custom image is not by directly deriving from it. Instead, you should use [Universal Blue's image template](https://github.com/ublue-os/image-template) and create your own repo from it. This will provide a preconfigured `Containerfile`, as well as the necessary GitHub Actions to build and push your image to GHCR.

About image naming, the general suggestion, as confirmed by the devs, is to use your own custom name, avoiding direct mentions to the original image. For example, using the Bazzite name might be confusing in terms of ownership. On other hand, using a custom name won't break relation to Bazzite regardless—this is still clear from the `Containerfile` or even the repo's template.

We decided to use DLT OS as the name of our custom image based on Bazzite, but more on it below.

#### What to Edit

Once you setup your repo based on [ublue-os/image-template](https://github.com/ublue-os/image-template), you should start by editing `build_files/build.sh`.  This is the entry point for your custom system commands.

While not included in the template, it is also common to create a `system_files` directory, where you can drop files to be copied over to the root filesystem of your final image, usually to `/usr` (non-local) or `/etc`. It is also frequent to create a `repo_files` directory, where we can store stuff like the logo for the custom image, to appear on ArtifactHub (optionally).

#### Cosign

Our image should also be signed using `cosign`. This is done automatically by the provided `build.yml` GHA, but we are required to first generate a key pair, as described in the image template repo's instructions:

```bash
COSIGN_PASSWORD="" cosign generate-key-pair
```

This will produce a `cosign.key` private key, that I recommend you move to `~/.cosign` and backup appropriately, and a `cosign.pub` public key, that should be committed to the repo. You must also setup your private key as a repo secret under Settings → Security → Secrets and variables → Actions → Repository secrets. Name it as `SIGNING_SECRET` and paste the contents of `cosign.key` into it. This is all that you need to do to sign your image automatically during build.

#### ArtifactHub

If you'd like your image to be listed on [ArtifactHub](https://artifacthub.io/packages/container/dltos/dltos) when ready, simply create an account and repo on ArtifactHub, and copy over the repo ID to `artifacthub-repo.yml`, filling in the owners as well. Keep in mind that the e-mail you use will be public, and it should be the same used to sign up to ArtifactHub.

### Build and Update

Now, as your image grows, you'll want to handle both build performance, through caching mechanisms, as well as ensure that the users of your image will get incremental upgrades when they run `sudo bootc upgrade`, as opposed to downloading a huge image layer every time.

This is where the concept of rechunking enters. As I understand it, this simply repackages the image by reorganizing the layers in a way that user upgrade become more atomic and smaller. Let's say that we add a `dnf install` for a specific package at the end of our `Containerfile` or build script. When the final image is built, it will produce completely different layers, due to metadata or other elements changing. As such, if our custom image adds 4 GiB of packages on top of Bazzite, the final user will keep downloading 4 GiB with each upgrade, despite the actual upgrade only changing a fraction of that.

Rechunking should clear that up, and this is even available as a commented out step on the `.github/workflows/build.yml` GHA that is provided with the image template. However, from what I understand, this approach is deprecated—also, I tested it and it doesn't work. As of now, this is an unsolved problem with DLT OS. As recommended on Universal Blue's Discord, I will be been looking into [compose build-chunked-oci](https://coreos.github.io/rpm-ostree/build-chunked-oci/) to address this issue in the future.

Apart from correctly layering the image, another relevant issue to address is ensuring efficient build performance. If we add a single package to the system, we don't want to wait 15 min for the built to finish. Again, at Universal Blue's Discord server, they pointed me towards DNF cache, leading me to [this](https://github.com/ublue-os/bazzite/commit/f39e268089417dde5bcbcb93dc8c9935886a43d3) specific approach, which I will explore in the near future as well.

As a side note, also don't worry about editing the `README.md` file, since it doesn't trigger a build on push—as long as it's the only changed file, of course.

## Custom Image

First, we edited  the env vars on `.github/workflows/build.yml`, adding a custom description, the proper keywords, and a link to the logo image, stored under `repo_files`:

```yml
env:
  IMAGE_DESC: "..."
  IMAGE_KEYWORDS: "bootc,ublue,universal-blue,..."
  IMAGE_LOGO_URL: "https://..."
```

The build GHA is scheduled to run everyday at 10:05 am. This is how you get updates from your base image baked into your custom image, i.e., as `bazzite-nvidia-open:stable` gets updated, our custom image will also get those updates.

We started by adding custom packages to `build_files/build.sh`, but, as the scope grew, we split this into multiple scripts, with a `RUN` statement for each individual script under `Containerfile`, as this will help with layer caching in the future. We also added a system-wide niri config under `system_files/etc/niri/config.kdl`, as well as a few helper scripts under `system_files/usr/bin`. This is how these folders look like:

```
build_files/
├── ai.sh
├── base.sh
├── cargo-env.sh
├── containers.sh
├── data.sh
├── dev.sh
├── go-env.sh
├── graphics.sh
├── languages.sh
├── network.sh
├── shell.sh
├── uv-env.sh
└── validations.sh
system_files/
├── etc
│   └── niri
│       └── config.kdl
└── usr
    └── bin
        ├── docker
        ├── docker-compose
        └── tray-launch
```

Let's unpack the build files. Our entry-point script is `base.sh`, which installs only system-specific packages, like niri, noctalia, and related graphical utilities.

Also notice that we have three scripts to setup environment variables: `go-env.sh`, `cargo-env.sh`, and `uv-env.sh`. These are used to setup requirements for system-wide installs using `go install`, `cargo install`, or `uv tool install`. We source the corresponding environment scripts whenever we need to install a system-wide binary or script based on Go, Rust, or Python, respectively.

The remaining scripts are software categories. We call them in the following order inside `Containerfile`: base, languages, shell, network, graphics, dev, containers, AI, and data. The final one is `validations.sh`, which simply runs config file validations—we currently just use it to validate niri's config file.

System files are copied from `system_files` to the images root `/` just before `validations.sh` is called. The reasoning behind this is that changes to the niri config won't require a full image rebuild, but instead just a validation run.

Once we push into the GitHub repo, the build action will trigger and the image will be available as `latest`, as well as via tags `latest.YYYYmmdd` and `YYYYmmdd`, so that you can easily go back to older versions.

That's it, we've built a custom Bazzite image!

## DLT OS

You can find DLT OS on [GitHub](https://github.com/DataLabTechTV/dltos/), with its image listed on [GHCR](https://github.com/DataLabTechTV/dltos/pkgs/container/dltos), and also on [ArtifactHub](https://artifacthub.io/packages/container/dltos/dltos). Below we'll go through the changes we've packaged into DLT OS.

### Features

- Preconfigured niri out-of-the-box, with the noctalia shell.
- Go, Rust, Python, and Node tooling, providing `go`, `cargo`, `uv`,  and`npm`.
- System-wide tools, installed via `dnf5`, `go install`, `cargo install`, or `uv tool install`, making it easy to naturally extend if you want to derive your custom image.

The following sections summarize the packages that DLT OS provides out-of-the-box.

#### Base

For the base system, we add `niri` and `noctalia-shell`, alongside a few utilities. We also remove `xwaylandvideobridge`, which opens a blank window by default on niri, but seems to be deprecated anyway. This let's us run the `xwayland-satellite` integration without issues.

| Package                    | Version  | Via    | Observation                                                                 |
| -------------------------- | -------- | ------ | --------------------------------------------------------------------------- |
| `xdg-desktop-portal-gnome` | >=49.0   | `dnf5` | Required for the *Screen Capture (PipeWire)* feature on OBS.                |
| `qt6ct`                    | >=0.11   | `dnf5` | Let's you pick the Qt theme without using KDE utilities.                    |
| `wev`                      | >=1.1.0  | `dnf5` | Keyboard and mouse event debugging utility.                                 |
| `wlsunset`                 | >=0.4.0  | `dnf5` | Used for Noctalia's Night Light feature.                                    |
| `cava`                     | >=0.10.2 | `dnf5` | Used for Noctalia's audio visualizers.                                      |
| `playerctl`                | >=2.4.1  | `dnf5` | Controls your media player (e.g., Spotify) via preconfigured niri keybinds. |

#### Languages

| Package         | Version  | Via    | Observation                                                                                                                                            |
| --------------- | -------- | ------ | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `golang`        | >=1.25.8 | `dnf5` | Used to install system-wide tools under `/usr/bin`.                                                                                                    |
| `cargo`         | >=1.93.1 | `dnf5` | Used to install system-wide tools under `/usr/bin`.                                                                                                    |
| `uv`            | >=0.10.9 | `dnf5` | Used to install system-wide tools under `/usr/share/uv/tools`, symlinked to `/usr/bin`. Defaults to `python` >=3.14.3, which is the system default.    |
| `node-npm`      | >=10.9.4 | `dnf5` | Depends on `node` >=22.22.0, which is installed as a dependency. Let me know if you need `pnpm` or other node tooling that we currently don't include. |
| `just-lsp`      | >=0.4.0  | `dnf5` | Language server for your `justfile`.                                                                                                                   |
| `gopls`         | >=0.21.1 | `dnf5` | Language server for Go code.                                                                                                                           |
| `golangci-lint` | >=2.11.3 | `dnf5` | Can be integrated with `pre-commit` for Go code linting.                                                                                               |
| `shfmt`         | >=3.13.0 | `dnf5` | Can be used with your editor to format shell scripts.                                                                                                  |

#### Shell

| Package          | Version  | Via     | Observation                                                                                                                                                                                                         |
| ---------------- | -------- | ------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `kitty`          | >=0.43.1 | `dnf5`  | GPU-accelerated terminal emulator. Highly customizable.                                                                                                                                                             |
| `fish`           | >=4.2.0  | `dnf5`  | Included in Bazzite by default.                                                                                                                                                                                     |
| `starfish`       | >=1.24.2 | `dnf5`  | Cross-shell prompt, with good defaults. Requires `atim/starship` COPR.                                                                                                                                              |
| `chezmoi`        | >=2.70   | `dnf5`  | Used to manage dotfiles. Take a look at the [DataLabTechTV/dotfiles](https://github.com/DataLabTechTV/dotfiles) repo for an example and instructions on how to use.                                                 |
| `direnv`         | >=2.35   | `dnf5`  | Utility to automatically load and unload `.envrc` or `.env` files per directory.                                                                                                                                    |
| `zoxide`         | >=0.9.8  | `dnf5`  | Useful `cd` replacement, with fuzzy matching and filtering.                                                                                                                                                         |
| `bat` (`batcat`) | >=0.25.0 | `dnf5`  | Replacement for `cat` with syntax highlighting and pager by default. You can also use it to improve readability for help messages (e.g., `cat --help \| bat -l help`) or man pages (e.g., `man cat \| bat -l man`). |
| `rg` (`ripgrep`) | >=14.1.1 | `dnf5`  | Recursive `grep` alternative. Generally more efficiency than `grep -r`.                                                                                                                                             |
| `fd` (`fd-find)` | >=10.4.2 | `dnf5`  | User-friendly find command. Good for quick file searching, but you might still prefer `find`, depending on the task.                                                                                                |
| `eza`            | >=0.23.4 | `cargo` | Beautified version of `ls`, with features like icons or tree listing.                                                                                                                                               |
| `ncdu`           | >=2.9.2  | `dnf5`  | Utility for recursively measuring storage, identifying largest directories. Useful for large file system cleanup.                                                                                                   |
| `prettyping`     | >=1.1.0  | `dnf5`  | Utility `ping` script useful for visually monitoring packet loss.                                                                                                                                                   |

#### Network

| Package  | Version  | Via    | Observation                                                                                 |
| -------- | -------- | ------ | ------------------------------------------------------------------------------------------- |
| `rclone` | >=1.73.0 | `dnf5` | This is like the `rsync` for cloud storage. It can connect to wherever, from S3 to Dropbox. |
| `iperf3` | >=3.19.1 | `dnf5` | Useful to measure network bandwidth and performance.                                        |
| `mkcert` | >=1.4.4  | `dnf5` | Easily run your local CA to issue certificates.                                             |
| `nc`     | >=7.92   | `dnf5` | Swiss army knife for network communication.                                                 |
| `nmap`   | >=7.92   | `dnf5` | Port mapping software.                                                                      |
| `mc`     | dev      | `go`   | MinIO command line client.                                                                  |
| `s5cmd`  | dev      | `go`   | Another S3 client.                                                                          |
| `warp`   | dev      | `go`   | Benchmark software for S3 object stores, by MinIO.                                          |
| `httpie` | >=3.2.4  | `uv`   | Command line REST API request tool. We include support for SigV4.                           |

#### Graphics

| Package             | Version    | Via    | Observation                                                                         |
| ------------------- | ---------- | ------ | ----------------------------------------------------------------------------------- |
| `ImageMagick-heic`  | >=7.1.1.47 | `dnf5` | ImageMagick support for HEIC format.                                                |
| `libheif-freeworld` | >=1.20.2   | `dnf5` | Only available on the  `rpmfusion-free` repo. Adds support for Apple's HEIC format. |
| `rembg[gpu,cli]`    | >=2.0.73   | `uv`   | AI tool to remove the background from photos.                                       |

#### Dev

| Package               | Version   | Via    | Observation                                                                                             |
| --------------------- | --------- | ------ | ------------------------------------------------------------------------------------------------------- |
| `pre-commit`          | >=4.5.1   | `dnf5` | Useful to run linters and formatters before `git commit`.                                               |
| `cloc`                | >=2.08    | `dnf5` | Counts lines of code, so you can get some stats for your codebase.                                      |
| `delta` (`git-delta`) | >=0.18.2  | `dnf5` | A better diff for the CLI, with side-by-side support.                                                   |
| `nvim` (`neovim`)     | >=0.11.6  | `dnf5` | Replaces `vim-minimal`. Set as the default alternative for `vim` (i.e., `vim` command will run `nvim`). |
| `lazygit`             | >=0.60.0  | `dnf5` | Requires the `dejan/lazygit` COPR.                                                                      |
| `hugo`                | >=0.111.3 | `go`   | This is pinned to an older version that works with the [blowfish](https://blowfish.page/) theme.        |

#### Containers

| Package                                   | Version  | Via    | Observation                                                                                                                                                                                                                     |
| ----------------------------------------- | -------- | ------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `docker` (`docker-cli`)                   | >=29.3.0 | `dnf5` | Uses the user's Podman by default, via the corresponding socket, via the provided script.                                                                                                                                       |
| `docker-compose`(`docker-compose-switch`) | >=5.1.0  | `dnf5` | The `docker-compose` package is deprecated. This isn't a command to switch compose versions, but a new package they are switching to. Uses the user's Podman by default, via the corresponding socket, via the provided script. |
| `lazydocker`                              | >=0.25.0 | `go`   | TUI for docker.                                                                                                                                                                                                                 |
| `cosign`                                  | >=3.0.5  | `go`   | Used to sign container images, like this one.                                                                                                                                                                                   |

#### AI

| Package  | Version  | Via              | Observation                     |
| -------- | -------- | ---------------- | ------------------------------- |
| `ollama` | >=0.18.2 | Official Archive | To run your LLM models locally. |

#### Data

| Package          | Version  | Via              | Observation                                                                                  |
| ---------------- | -------- | ---------------- | -------------------------------------------------------------------------------------------- |
| `sqlite3`        |          | `dnf5`           | Embedded SQL database, with support for WAL.                                                 |
| `duckdb`         |          | Official Archive | Embedded SQL database, that works as a data lakehouse, supporting ETL and analytics locally. |
| `mlr` (`miller`) |          | `dnf5`           | CSV query tool.                                                                              |
| `yq`             | >=4.47.1 | `dnf5`           | YAML query tool similar to what `jq` is for JSON.                                            |
| `gnuplot`        |          | `dnf5`           | Command line plotting tool, with multiple charting options, that produce images.             |
| `termgraph`      |          | `uv`             | Command line plotting tool, that produces charts directly in the terminal.                   |
| `visidata`       |          | `uv`             | TUI for data exploration.                                                                    |

#### Validations

We also include a validations script, where, at this point, we only validate the `/etc/niri/config.kdl` file.
