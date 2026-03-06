---
title: "Year of the Linux Desktop #6: Managing Linux Configs Like a Pro"
description: Learn how to securely manage your Linux configs with chezmoi and a git repo, so you'll never need to reconfigure or copy files over manually ever again!
date: 2026-04-14T12:00:00+0100
categories: [DevOps]
tags: [linux, configs, dotfiles, chezmoi, video]
---

## Summary

Learn how to securely manage your Linux configs with chezmoi and a git repo, so you'll never need to reconfigure or copy files over manually ever again! I'll cover chezmoi config templating, and secrets encryption with age. I'll also show you how to use global template variables, for conditionally generating configs, depending on whether the private key is available to decrypt secrets or not.

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

## Overview

Chezmoi is a CLI utility to manage dotfiles across multiple machines, running on diverse platforms, while providing encryption features to help you secure sensitive information. Of course I would avoid storing private credentials publicly regardless of the security level, but this is, at the very least, quite helpful for privacy. For example, here I use it to store the MAC address for one of my machines.

Chezmoi also integrates quite well with several password and secret managers, like 1Password, Bitwarden, Proton Pass, the system's keyring, the standard UNIX password manager, `pass`, HashiCorp Vault, or AWS Secrets Manager. These usually require that you install the expected packages to support each manager. For example, you need `bw` for Bitwarden, or a setup AWS profile for AWS Secrets Manager. You know, the usual.

I opted out of using any of these options, as I prefer a more minimal approach for my setup. I've simply kept my age private key securely stored on my personal password manager, so I can restore my configs on other systems easily.

## Age Encryption

If you're setting up chezmoi for the first time, you should generate an age private key:

```bash
chezmoi age-keygen -o ~/.config/chezmoi/key.txt
```

Chezmoi provides out-of-the-box support for asymmetric encryption via the previous command (i.e., you generate a private key and use it to encrypt/decrypt). However, if you have age installed on your system, you'll get access to additional features that are also supported by chezmoi, although they require the age binaries to be installed.

[Age](https://github.com/FiloSottile/age) is a post-quantum alternative to PGP, but please make sure that you generate your private key using `age-keygen` directly, with the `-pq` option, if you need post-quantum encryption, as it won't be used by default.

Here, I just used the age features provided directly by chezmoi, which are more than enough for my use case, since I'm not even storing any credentials really. If this changes, I can just generate a post-quantum private, and build a small script to decrypt and reencrypt existing secrets with the new key, in order to further secure my secrets.

## Configuration

The configuration file for chezmoi should be added to `~/.config/chezmoi/chezmoi.toml` (other formats, like YAML or JSON are also supported).

I've setup two main settings, a custom source directory, where all my configs will live, and the age encryption method, which requires the specification of the path to an existing age private key, alongside the inline public key.

The easiest way to manage your config file is to create a `.chezmoi.toml.tmpl` on the root of your dotfiles repo. Any `tmpl` file on your configs will be parsed by [text/template](https://pkg.go.dev/text/template), which is the native Go template language.

Mine is designed to work in systems with and without secrets, and it looks like this:

```toml
{{- $age_private_key := promptStringOnce . "private_key_path"
    "Where is your age private key"
    (joinPath .chezmoi.homeDir ".config/chezmoi/key.txt") -}}

sourceDir = {{ .chezmoi.sourceDir | quote }}
encryption = "age"

{{ if stat $age_private_key -}}
{{- $age_public_key :=  regexFind "age1[0-9a-z]+" (include $age_private_key) -}}
[age]
identity = {{ $age_private_key | quote }}
recipient = {{ $age_public_key | quote }}
{{- end }}

[data]
hasAgePrivateKey = {{ if stat $age_private_key }}true{{ else }}false{{ end }}
```

When you `init` chezmoi for the first time, the path to your age private key will be prompted and stored in the `$age_private_key` template variable. You can also default to `~/.config/chezmoi/key.txt` by pressing enter.

The public key is extracted from the private key comment, that is generated by default through `age-keygen`, and stored in the `$age_public_key` template variable.

## Setup

My chezmoi dotfiles are designed to work with and without secrets, conditionally on whether the age private key is available on the current system. For you, an external user, always follow the [[#Without Secrets]] instructions. You can also clone my repo and replace my secrets with your own, in which case you'll be able to follow the [[#With Secrets]] instructions.

### With Secrets

This requires that the age private key is available, by default at `~/.config/chezmoi/key.txt`. Configs will include decrypted secrets.

```bash
chezmoi init --source ~/Code/dotfiles --apply -ssh DataLabTechTV/dotfiles
```

### Without Secrets

For systems where the age private key is not available, you won't be able to decrypt any `*.age` secrets that I have committed. I'm also assuming that the SSH private key for this repo is not available on the target system, so I removed the `--ssh` option. While I don't include it here, you can customize your source dir with `--source` as well, here.

```bash
chezmoi init --apply DataLabTechTV/dotfiles
```

> [!NOTE]
> Notice that `~/.config/chezmoi/chezmoi.toml` won't include the typical configs for for age encryption to work. If the age private key becomes available, you'll need to run `chezmoi init` again to regenerate the chezmoi config.

## Cheat Sheet

### Common Commands

#### Track a Config File

Track a new file (or use `-r` to recursively track all files in a directory):

```bash
chezmoi add ~/.config/app/app.conf
```

#### Edit a Config File

Edit a config (use the system path):

```bash
chezmoi edit ~/.config/fish/config.fish
```

#### View Changes

Check what changed:

```bash
chezmoi diff
```

#### Apply Changes

Apply changes (files will be copied over to the system path):

```bash
chezmoi apply
```

#### Encrypting Secrets

Encrypt a secret and save it in the repo (not applied, but used in templates):

```bash
chezmoi encrypt /tmp/secret -o ~/Code/dotfiles/.chezmoitemplates/secrets/secret.age
```

#### Decrypting Secrets

Decrypt a secret to the stdout:

```bash
chezmoi decrypt ~/Code/dotfiles/.chezmoitemplates/secrets/secret.age
```

### Templates

Only files ending with `.tmpl` will be rendered as templates (e.g., see `config.fish.tmpl`).

#### Decrypting Secrets

In order to include the content of an encrypted file, you can use something like this:

```jinja
{{ include ".chezmoitemplates/secrets/secret.age" | decrypt | trim }}
```

This includes a file from the root of the dotfiles repo and, in this case, decrypts it, as long as you have the age private key setup in the path described in the chezmoi config. We usually add `trim` as well, since age encrypted files tend to have a newline at the end, regardless of the original file (I might be wrong).

#### Escaping `{{ ... }}`

If you need to escape `{{ ... }}`, the cleaner way is to use the following strategy, with template variables:

```jinja
{{ $podman_fmt := "{{.Host.RemoteSocket.Path}}" -}}
set -x DOCKER_HOST unix://(podman info --format '{{ $podman_fmt }}')
```

#### Global Template Variables

Any variable defined on the chezmoi config file, under `[data]`, can be accessed globally on any config template. For example, we use it check if an age private key was configured, when we need to use decrypted values on our configs.

```jinja
{{ if .hasAgePrivateKey }}
{{- $homelab_mac := include ".chezmoitemplates/secrets/homelab.mac.age" | decrypt | trim -}}
abbr wake-delorean sudo ether-wake {{ $homelab_mac }}
{{- end }}
```
