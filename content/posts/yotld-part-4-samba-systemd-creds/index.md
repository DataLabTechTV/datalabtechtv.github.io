---
title: "Year of the Linux Desktop #4: Secure Samba Mounts with systemd-creds"
description: Learn how to use systemd-creds to encrypt your credentials using TPM2, and how to mount network resources with systemd-mount and systemd-automount.
date: 2026-03-31T12:00:00+0100
categories: [DevOps]
tags: [linux, bazzite, systemd, credentials, security, mountpoint, video]
---

## Summary

Accessing network shares via Dolphin doesn't always work, since there is no fixed mount point for those shares. If you need to point your configs to a fixed path on a network share, then you'll need to setup the proper mount points under `/mnt`. Using `/etc/fstab` can add increase your boot time, and it also requires access to plain text credential files. A better way is to use `systemd-creds` instead and encrypt those credentials. In this blog post, I'll teach you all about mount units, encrypted credentials with systemd, what it protects and what it doesn't.

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

## Problem

While KDE will let you add samba locations directly to Places on Dolphin, these will mount on different paths every time under `/run/user/<uid>/doc/<id>`. This means that, if your applications depend on these files, the path will constantly change. Also, if you have an automounted assets share, with images that you need to go through, you won't be able to slide through them using Gwenview, which is the default image viewer for KDE.

## Classic Solution

If you have samba shares that you intend to use frequently, it's much better to mount them explicitly under `/mnt/<share>`. So, in order to make samba resources consistently available, we'll need to mount them on boot automatically. This can be accomplished via `/etc/fstab`, however you'd need to store your credentials in plain text, so that the root user can read them when mounting.

## Modern Solution

Another, slightly safer way to do this is to use `systemd-creds` to store your encrypted credentials. This way they'll temporarily be loaded into memory during mount and immediately unloaded. Of course anyone with root access will be able to access the credentials, so this is just a minor additional measure, because nobody wants to store plain text passwords in 2026!

You can either use a locally stored master key (automatically created by `systemd-creds` when required, or use TPM2 so that extracting the disk from the original computer will protect from decryption.

### Encrypting Credentials

So let's create our encrypted samba credentials, by reading from stdin (particularly relevant if you can't `shred` the file afterwards, e.g., in btrfs):

```bash
sudo systemd-creds encrypt \
	--with-key=tpm2 \
	--name=nas.cred \
	- /etc/credstore.encrypted/nas.cred
```

Notice that we use `-` to read from the stdin. We should input the following:

```ini
username=YOUR_USERNAME_HERE
password=YOUR_PASSWORD_HERE
```

### Mount and Automount Units

Then, the best way to mount the samba resource is to create a `.mount` system unit and, optionally, a `.automount` companion, so that the resource gets automatically mounted when accessed. Assuming an immutable distro, Bazzite, here's an example for `/etc/systemd/system/var-mnt-nas.mount`:

```ini
[Unit]
Description=Mount NAS share
After=network-online.target
Wants=network-online.target

[Mount]
What=//markov.lan/share
Where=/var/mnt/share
Type=cifs
LoadCredentialEncrypted=nas.cred:/etc/credstore.encrypted/nas.cred
Options=credentials=%d/nas.cred,iocharset=utf8,vers=3.1.1,uid=1000,gid=1000,x-gvfs-name=share,_netdev

[Install]
WantedBy=multi-user.target
```

And then the companion `/etc/systemd/system/var-mnt-nas.automount`:

```ini
[Automount]
Where=/var/mnt/nas
Unit=var-mnt-nas.mount

[Install]
WantedBy=multi-user.target
```

Then, enable the automount units using:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now var-mnt-nas.automount
```

## Mockup Samba Server

Here's a tip. If you need to test this quickly, you can setup your own server with Docker or Podman.

First, create a temporary directory to hold your share's data:

```bash
mkdir -p /tmp/samba/data
cd /tmp/samba
```

Then, start a Samba container—no need to expose the ports, as we'll use the container IP directly for testing only:

```bash
sudo podman run --rm \
	--name samba \
	-p 139:139 \
	-p 445:445 \
	-v ./data:/mount \
	dperson/samba \
	-u "demo;demo" \
	-s "share;/mount;yes;no;no;demo"
```

Notice that we use `demo` for the username and password, that our share is called `share` and points to `/mount` inside the container (mounted locally under `./data`), and that we give permissions for `demo` to access `share`. We also use `--rm`, so this container will be removed when it's stopped.

You can check if the connection works by fetching the IP for the container with:

```bash
sudo podman inspect -f '{{ .NetworkSettings.IPAddress }}' samba
```

And then connecting to the Samba share using:

```bash
smbclient '//<ip>/share' -U 'demo'
```
