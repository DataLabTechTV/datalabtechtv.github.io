---
title: "Year of the Linux Desktop #9: Bootc Image Lifecycle Management for Immutable Linux"
description: Learn about the pains of managing a custom bootc image, and how to handle caching, configuration management, and testing changes before rebuilding.
date: 2026-05-26T13:00:00+0100
categories: [DevOps]
tags: [linux, bazzite, immutable, bootc, image, lifecycle, caching, configs, dotfiles, video]
---

## Summary

Learn about the pains of managing a custom bootc image, and how to handle caching, configuration management, and testing changes before rebuilding.

<div style="position: relative; padding-bottom: 56.25%; height: 0; overflow: hidden; max-width: 100%;">
    <iframe
        src="https://www.youtube.com/embed/l7Hep0D0w8Q"
        frameborder="0"
        allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
        referrerpolicy="strict-origin-when-cross-origin"
        allowfullscreen
        style="position: absolute; top: 0; left: 0; width: 100%; height: 100%;">
    ></iframe>
</div>

## Container vs Host

When I first started customizing by bootc image for Bazzite, the approach was to bake everything into the host system, but I soon started having trouble maintaining this. Every time I needed a new tool, I tended to try and rebuild the image using GitHub Actions, and then download and apply the upgrade. This alone took quite a long time and sometimes it even failed, so I had to do it again.

Since it quickly became unmanageable, I decided to move everything into a distrobox, with the exception of OS-level software, like the compositor or the terminal emulator. This seemed like a great idea at the time. Keep the host system minimal and clean, and manage all the tooling directly inside distrobox, which allowed for easily installing anything I needed.

But, after a while, I wasn't quite happy with again. Maintaining distrobox usually led to reassembling the `distrobox.ini` for the `dltos` distrobox, at least from time to time. It took quite a while to rebuild, but it also didn't have the fastest start, even when everything was already installed and I had checks in place to avoid trying to reinstall.

Immutable Linux is fairly recent, and it's brand new to me—at this point, I've got a few weeks of experience with it—so it's hard to get a clear view of what the best workflow would be. Regardless, after having made a few mistakes, I think I finally landed on a sweet spot.

It was clear all along! Bake everything you want to use into the host system, adding it to the custom bootc image, but, when adding new packages or configs, give yourself a trial period before committing into the image. This can be done, for instance, by using a small `distrobox`, either directly or by exporting a command to the host, or by modifying user configs to test them before integrating into the main config. This is how I expect my workflow will be from now on, and this is what I talk about below in more detail.

## GitHub Caching

Regardless of whether you rebuild your custom bootc image frequently or not, the amount of time you have to wait for a new build to be available matters, so caching matters.

We attempted two approaches for caching:

1. Using a container registry (GHCR) adding `--cache-to/--cache-from` to `buildah build`.
2. Saving and restoring `/var/tmp/buildah-cache-*` as a GitHub Cache, while setting `keepcache=1` for DNF to keep downloaded RPMs.

Approach nr. 1 provides layer caching based on the container image, while approach nr. 2 provides DNF caching for when layer caching doesn't hit—useful for example when adding a new package to `10-tooling.sh`, since without it all packages would need to be re-downloaded, but with it only the new package and updates will be fetched.

### Test Cases

I ran a few tests to measure the performance of this setup, while considering the impact of including the rechunking step versus relying purely on layer caching. I did not test with and without `--cache-to/--cache-from` because GHA logs clearly show cache layers being hit and re-used when available.

Displayed times are in `[hh:]mm:ss`, with build time representing how long the GHA took to run in total.

I did not reboot between upgrades, since the layers should be cached either way. Notice that I also don't run `bootc upgrade` directly, but instead use `ujust update` as recommended for Bazzite, which relies on `rpm-ostree upgrade`.

|  ID | Test Case                                                     | Build Time | Upgrade Size |
| --: | ------------------------------------------------------------- | ---------: | -----------: |
|   1 | Standard image build – 0% cached                              |    1:07:33 |      3.5 GiB |
|   2 | Standard image build – 100% cached                            |      23:28 |     14.4 MiB |
|   3 | Remove `ShellCheck` from `10-tooling.sh`                      |      53:30 |      3.9 GiB |
|   4 | Re-add `ShellCheck` to `10-tooling.sh` (i.e., reset baseline) |      24:02 |      3.6 GiB |
|   5 | Disabled rechunker – 0% cached (reset it)                     |      51:46 |        6 GiB |
|   6 | Disabled rechunker – 100% cached                              |       7:30 |            0 |

1️⃣ Test case 1 upgrade size really depended on the current image installed on my system, but content-wise this was virtually the same that I had installed already. The whole image was  about 10.49 GiB, so, even with an uncached build, it only required a download that was 33% of the original image to upgrade.

2️⃣ Test case 2 completely relies on layer cache previously saved to the `datalabtechtv/dltos-cache` image via `--cache-to` during `buildah build`. The upgrade size from test case 1 to 2 is also quite small, as it's just a new ostree commit—metadata essentially.

3️⃣ Test case 3 hits image layer cache up to and including `00-base.sh`, but once it hits the change in `10-tooling.sh` it uses the GitHub Cache for `/var/tmp/buildah-cache-*`. While we confirmed installed packages were hitting the cache, and didn't require a download, we only reduced build time in ~14 min compared to test case 1 (0% cached), and most of the time is likely due to image layer cache anyway. The small decrease in build time is likely due to Rust and Go package compilations, which we do not provide any viable caching mechanism for. This is something to consider in the future, and perhaps also separating each ecosystem into its own build script and `RUN` stage in the `Containerfile`.

4️⃣ Test case 4 provides a sanity chat, confirming that re-adding `ShellCheck` will again hit the existing image layer cache, as expected, since it matches the state produced by test case 2.

5️⃣ Test case 5 took a little less time to run than test case 1 due to the rechunker step being disabled, but resulted in a larger upgrade size of  3.5 GiB for the ostree layer, plus 2.5 GiB for the custom layer—not integrated into `rpm-ostree`, since we dropped the rechunker that essentially ran `rpm-ostree compose build-chunked-oci`. On day-to-day operations, I'd rather add 15m to the build time than to have to download an extra 2.5 GiB every time. Remember that, once your custom bootc image stabilizes (i.e., you're rarely changing it), then the only real updates will come from upstream, from the Bazzite base image we're using.

6️⃣ Finally, test case 6 was again a lot faster to run due to image layer caching, but still produced quite a large upgrade size, so clearly adding the rechunker step is useful to this workflow and we will leave it enabled. I would disable it if build time was more important to me than upgrade time, as it generally results in lower build times, but higher upgrade sizes.

### Improvements

From the tests I conducted, it seems that image layer caching is the main positive driver of improved build time, with the GitHub Cache for Buildah providing a small but noticeable improvement as well.

For the latter, the bottleneck seems to be `cargo install` compilation times, due to build artifacts not being cached or reused—a temporary `target/` directory is used each time, resulting in full recompilation. To mitigate this, I explicitly set `CARGO_TARGET_DIR` to `/var/cache/cargo-target`, which should be persisted with the maintained Buildah cache.

## Config Management

Prior to this, I was using [chezmoi](https://www.chezmoi.io/) to manage my [dotfiles](https://github.com/DataLabTechTV/dotfiles), a tool that I definitely recommend. But then I listened to the latest episode of the Fedora Project Podcast, titled [BootC in the Wild](https://fedoraproject.fireside.fm/54), where Eric interviews James Harmison. James talks about baking everything into bootc and, since I'm always looking for ways to simplify my processes, I had to try it on my setup!

Of course not all configs can be easily generalized—and I don't know if this was the goal for James, or if he simply ran it privately on his home lab and didn't have to worry about secrets. Regardless, most of my configs could certainly be migrated to a system-wide format, leaving only some minor local configs out of it. Those were either specific to a particular machine, or contained secrets that should not be baked into a public image.

Below, I briefly explain how `/etc` works in bootc images, how `systemd-tmpfiles` can be useful for drop-in config templates in mutable user homes, and how I organized and now manage my configs with the help of a couple of custom `just` commands, still partially in the works.

### Understanding `/etc`

Filesystem directories in bootc images are either mutable (e.g., `/var`) or immutable (e.g., `/usr`). Some directories, like `/etc`, while mutable, behave in a special way, combining existing configs and new image defaults between upgrades. According to the [bootc docs](https://bootc.dev/bootc/filesystem.html#etc), this is how `/etc` actually consolidates config files during bootc upgrades:

> - The _new default_ `/etc` is used as a base
> - The diff between current and previous `/etc` is applied to the new `/etc`
> - Locally modified files in `/etc` different from the default `/usr/etc` (of the same deployment) will be retained

The `/usr/etc` directory is generated by the bootc/ostree tooling during image building, representing the image’s default view of `/etc`. It's an internal implementation detail used as input for `/etc` reconciliation during deployment and upgrades. It should not be manually curated or treated as a configuration target.

### Understanding `systemd-tmpfiles`

The name `systemd-tmpfiles` is, at this stage, a bit misleading. While it sounds like it should manage temporary files—and it was originally designed to do so—it now provides generic file management, according to configuration files called `tmpfiles.d`.

Personally, I like to think of `tmp` as "template" instead of "temporary", and I actually think they should rebrand as such. While there is no actual template language for the files, a kind of template language is already used to setup file paths (e.g., `%h` for the user's home directory). No file is actually rendered, but sources still work as templates or example files.

Configs to be used during boot are usually stored in a `tmpfiles.d` directory, while configs to be used for a user are usually stored in a `user-tmpfiles.d` directory. All of our configs are added to `/usr/share/user-tmpfiles.d`. 

You can check `man tmpfiles.d` for all details on this file format, but generically we set the following fields:

- Type – file or directory action (e.g., `C` will copy files without overwriting if a target already exists, when the `systemd-tmpfiles-setup.service` runs).
- Path – target path (might contain specifiers like `%h`, which maps to the users' home directory, e.g., `/root` or `/home/dlt`).
- Mode – file or directory permissions in octal (e.g., `0755`).
- User – owner of the target file or directory.
- Group – group of the target file or directory.
- Age – cleanup age (files older than this age will be deleted by the `systemd-tmpfiles-clean.service`).
- Argument – argument specific to the action type (e.g., for `C` type, the argument is the source file or directory).

Here's an example for `zed.conf`:

```bash
C %h/.config/zed/settings.json - - - - /usr/share/zed/defaults/settings.json
C %h/.config/zed/keymap.json - - - - /usr/share/zed/defaults/keymap.json
```

This will provision default settings and keymap configs for users in this machine. Once copied to the user home, they will not be copied or overwritten again.

I'm essentially using this as `/etc/skel`, but the reason I cannot use `skel` directly is because the system will be installed from a Bazzite ISO and only then will I switch to my custom image. This means that, at that stage, the user has already been created, so `skel` would never trigger. I also cannot copy the files to my home during image building because not only don't I know the username at that stage, but also homes are mutable and live in `/var/home`, so I cannot copy anything to them at that stage. This is why `systemd-tmpfiles` is the right tool for the job here.

### From Dotfiles to Baked-In Configs

Here's what the relevant configs in my dotfiles repo looked like before I migrated the configs to the custom bootc image directly:

```
dotfiles/
├── dot_config
│   ├── bat
│   │   ├── config
│   │   ├── syntaxes
│   │   │   └── KDL1.sublime-syntax
│   │   └── themes
│   │       └── Catppuccin Mocha.tmTheme
│   ├── containers
│   │   └── containers.conf
│   ├── direnv
│   │   └── direnv.toml
│   ├── environment.d
│   │   ├── niri.conf
│   │   └── spectacle-video-fix.conf
│   ├── kitty
│   │   ├── kitty.conf
│   │   └── symlink_current-theme.conf
│   ├── niri
│   │   └── config.kdl
│   ├── nvim
│   │   ├── init.lua
│   │   ├── lua
│   │   │   ├── config
│   │   │   │   ├── autocmds.lua
│   │   │   │   ├── keymaps.lua
│   │   │   │   ├── lazy.lua
│   │   │   │   └── options.lua
│   │   │   └── plugins
│   │   │       ├── bufferline.lua
│   │   │       ├── colorscheme.lua
│   │   │       ├── harpoon.lua
│   │   │       ├── kitty.lua
│   │   │       ├── lint.lua
│   │   │       ├── lsp.lua
│   │   │       ├── neo-tree.lua
│   │   │       ├── oil.lua
│   │   │       ├── syntax.lua
│   │   │       └── treesitter.lua
│   │   └── stylua.toml
│   ├── private_konsolerc
│   ├── private_konsolesshconfig
│   ├── starship.toml
│   ├── xdg-desktop-portal
│   │   └── portals.conf
│   ├── zed
│   │   ├── keymap.json
│   │   └── private_settings.json
│   └── zsh
│       ├── aliases.zsh.tmpl
│       ├── completion.zsh
│       ├── env.zsh
│       ├── functions
│       │   └── ls
│       ├── init.zsh
│       ├── keybinds.zsh
│       ├── options.zsh
│       ├── plugins.txt
│       ├── plugins.zsh
│       └── prompt.zsh
├── dot_local
│   ├── bin
│   │   ├── executable_fix-nvidia-sleep-issues
│   │   └── executable_undo-fix-nvidia-sleep-issues
│   └── share
│       ├── delta
│       │   └── themes.gitconfig
│       └── konsole
│           └── private_Main.profile
├── dot_zprofile
└── dot_zshrc
```

I deleted a few of these, as they no longer applied:

- `~/.config/environment.d/spectacle-video-fix.conf` (fixed upstream).
- `~/.config/kitty/current-theme.conf` (automatically generated by Noctalia).
- `~/.config/konsolesshconfig` (redundant).
- `~/.local/bin/*fix-nvidia-sleep-issues*` (could have been migrated to `/usr/bin` if required).

The remaining configs were either migrated to `/etc`, if they made sense as system defaults, or copied over to the user's home using `systemd-tmpfiles`, if they made more sense as user-managed configs rather than admin-managed configs.

#### System Configs

I ended up with the following structure for `/etc`:

```
etc/
├── bat
│   ├── config
│   ├── syntaxes
│   │   └── KDL1.sublime-syntax
│   └── themes
│       └── Catppuccin Mocha.tmTheme
├── bc
│   └── bcrc
├── containers
│   └── containers.conf
├── direnv
│   └── direnv.toml
├── environment.d
│   ├── bat.conf
│   ├── bc.conf
│   ├── direnv.conf
│   ├── niri.conf
│   └── starship.conf
├── gitconfig
├── niri
│   └── config.kdl
├── starship.toml
├── xdg
│   ├── kitty/kitty.conf
│   └── xdg-desktop-portal
│       └── niri-portals.conf
├── zprofile
├── zsh
│   └── functions
│       ├── ls
│       └── man
├── zshrc
└── zshrc.d
    ├── 10-env.zsh
    ├── 20-completion.zsh
    ├── 30-plugins.zsh
    ├── 40-options.zsh
    ├── 50-aliases.zsh
    ├── 60-keybinds.zsh
    └── 70-prompt.zsh
```

Notice the additional `environment.d` configs (e.g., `bat.conf`, `starship.conf`, etc.). These were required to set a global environment variable pointing to the system-wide config for these tools.

Also notice that I added a `gitconfig` that replaces the delta `themes.gitconfig` file and the manual setup I had done in my `~/.gitconfig` (untracked at the time).

I renamed `portals.conf` to `niri-portals.conf` so that it doesn't affect other compositors. I also considered replacing the file with the same name under `/usr/share/xdg-desktop-portal`, but decided against it to avoid having to rename or overwrite the original one.

Finally, configs for zsh were reorganized to match system-wide standards, with `zshrc.d` working as an extension of `zshrc` and functions moving to `zsh/functions` instead.

#### User Configs

We also opted to leave a few configs completely to the user, particularly for tooling that is heavily customizable. In here, we included  a default profile for Konsole, the Neovim configs, the Zed configs, a commented template for a user Niri config that extends the system config by default, and a config to help set the default keyboard layout used by Gamescope.

In general, the configs to be copied over to the user's home by `systemd-tmpfiles` were spread across `/usr/share/<app>/defaults`, with a corresponding `/usr/share/user-tmpfiles.d/<app>.conf` as exemplified in a previous section. Users configs looked like this:

```
usr/share/
├── gamescope
│   └── defaults
│       └── gamescope.conf
├── konsole
│   ├── defaults
│   │   └── konsolerc
│   └── DLTOS.profile
├── niri
│   └── defaults
│       └── config.kdl
├── nvim
│   └── defaults
│       ├── init.lua
│       ├── lua
│       │   ├── config
│       │   │   ├── autocmds.lua
│       │   │   ├── keymaps.lua
│       │   │   ├── lazy.lua
│       │   │   └── options.lua
│       │   └── plugins
│       │       ├── bufferline.lua
│       │       ├── colorscheme.lua
│       │       ├── harpoon.lua
│       │       ├── kitty.lua
│       │       ├── lint.lua
│       │       ├── lsp.lua
│       │       ├── neo-tree.lua
│       │       ├── oil.lua
│       │       ├── syntax.lua
│       │       └── treesitter.lua
│       └── stylua.toml
├── user-tmpfiles.d
│   ├── gamescope.conf
│   ├── konsole.conf
│   ├── neovim.conf
│   ├── niri.conf
│   └── zed.conf
└── zed
    └── defaults
        ├── keymap.json
        └── settings.json
```

All the files get copied over to the user home by the service defined in `/usr/lib/systemd/user/systemd-tmpfiles-setup.service`, which is enabled as a global user service. You can check its status by running:

```bas
systemctl --user status systemd-tmpfiles-setup.service
```

It should be enabled.

### Diff and Import Configs

Chezmoi provided a way to diff your current and default configs, but now that I've baked configs into my custom bootc image I no longer have any of these. So I decided to build a few just commands to help out with two tasks that I feel will be common:

1. Diff the default and the user configs for `systemd-tmpfiles` managed configs, which are the most common to require updates.
2. Replace the configs in the custom bootc image repo with the current user configs, to facilitate image updating.

I currently provide two general commands for this:

```bash
just diff-all-user-configs
just import-all-user-configs
```

As well as equivalent individual commands for `nvim`, `gamescope`, `konsole`, `niri`, and `zed` in the format:

```bash
just diff-<app>-user-configs
just import-<app>-user-configs
```

Currently, there is no just command to diff or import system configs, like zsh or the system-wide niri config, but I might add them in the future, depending on how frequent the task of updating them is.

The diff commands use delta with a friendly color scheme that integrates well with the default terminal colors, providing colored pagination over all configs.

The import commands just run `cp` for the same files that were diffed—I might switch to `rsync` to avoid copying over unchanged files, but it's largely redundant given the small size of the files.

## Local Overrides

Whenever I need to quickly add packages or test some configs, I avoid rebuilding the whole image, as it will severely slowdown my workflow. Having done this several times in the past, let me tell you straight up that you should resist the urge to rebuild and upgrade for every single new component that you want to add to your bootc image!

### Testing Configs

Each update to the packages or configs it will most likely break, end up installing the wrong tool for the job, or any other unpredictable event that will make you repeat the whole process. You'll easily get stuck doing this and forget about what you were actually trying to achieve, which is harmful due to context switching and added cognitive load. So [refuse/resist](https://youtu.be/6ODNxy3YOPU)!

Since `/etc` is mutable, there are other way to test your configs, even if they're system-wide. And, as long as you reset to the original configs tracked in `/usr/etc`, you'll be able to test that your custom bootc image correctly updates those files. You can change them temporarily *without* turning them into user configs that override the image default configs.

Other than that, changing your user configs should be a natural part of day-to-day operations, as `systemd-tmpfiles` will never overwrite them anyway, unless you completely delete the directory. However, with the diff commands I provide, you shouldn't have to do this.

### Testing Packages

Now, your system is immutable, but unless you need to switch your compositor or another system component, you shouldn't have to install packages directly on the custom bootc image, if you just need to test them, or maybe you're just in a rush to spin up some app that's on Bazaar/Flathub.

For these cases, I recommend that you simply use distrobox, starting from the `dltos.ini` config that we provide. It's extremely minimal, to minimize time to first command, but it should provide a good basic integration with the host system, i.e., it will start in zsh with the host's configs (read-only) and starship, providing basic system tooling (`eza`, `bat`, `zoxide`, etc.) along `neovim` for easier config editing. In order to test your packages, you can rely on `distrobox-export` to expose binaries or desktop applications to the host OS:

```bash
distrobox-export --bin /usr/bin/bat
distrobox-export --app emacs
```

If you need a host command to be available inside distrobox, you can use something like this:

```bash
sudo ln -s /usr/bin/distrobox-host-exec /usr/local/bin/podman
```

Once you are satisfied with the configs or package install process, then you can bake these into your own custom image. This avoids splitting into a side-task of updating the custom bootc image when it's not ideal for your, and it lets you test the software before committing to it in your immutable system.
