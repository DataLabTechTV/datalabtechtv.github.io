---
title: "Year of the Linux Desktop #1: I Switched to Bazzite!"
description: Wanna know how it really feels to switch to Linux? In this blog post, I share my installation process, first impressions, some issues I encountered, and how to deal with them.
date: 2026-03-10T12:00:00+0100
categories: [Philosophy of Technology]
tags: [linux, bazzite, desktop, immutable, video]
---

## Summary

Wanna know how it really feels to switch to Linux? Is it finally the year of the Linux desktop? What changes with immutable distros? What about apps, tooling, and gaming? I just switched from Windows 11 to Bazzite as my main desktop. In this blog post, I share my installation process, first impressions, some issues I encountered, and how to deal with them.

<div style="position: relative; padding-bottom: 56.25%; height: 0; overflow: hidden; max-width: 100%;">
    <iframe
        src="https://www.youtube.com/embed/vcO3b67lsbQ"
        frameborder="0"
        allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
        referrerpolicy="strict-origin-when-cross-origin"
        allowfullscreen
        style="position: absolute; top: 0; left: 0; width: 100%; height: 100%;">
    ></iframe>
</div>

## Installation Log

1. Downloaded Ventoy for Windows and flashed a USB stick with it.
2. Downloaded the Bazzite non-legacy NVIDA ISO, and copied it to the Ventoy drive.
	1. Also downloaded the Windows 11 English ISO, in case something went wrong and I needed to repair the boot loader.
3. Loaded Ventoy by picking the 2nd UEFI partition from the USB stick, on the BIOS boot menu.
4. Picked `Enroll key from disk` to add support for secure boot. Their key is available directly on the Ventoy drive. I looked for `ENROLL_THIS_KEY_IN_MOKMANAGER.cer`, selected it and rebooted. Instructions are available [on the official website for Ventoy](https://www.ventoy.net/en/doc_secure.html).
5. Loaded Ventoy again, now showing the ISO selection menu, where I picked the Bazzite ISO and booted into it using `grub2` mode (normal mode only works for the legacy ISO, which was not our case).
6. Once booted into Bazzite for installing, an empty popup came up, with "Bazzite Hardware Helper" in the title, and three options: I KNOW WHAT I’M DOING. Install Bazzite Anyway; Power Off; GPU Information.
	1. This was misleading, as GPU Information showed a correctly detected GPU, and no other information was displayed.
	2. I moved to install Bazzite anyway.
7. Once inside the actual installer,  I followed the basics steps, picking a second drive to install in Automatic mode.
	1. It looked like it had frozen during "Deployment starting", but it eventually advanced—I checked `btop` on the terminal and confirmed that `bootc` was at 100% CPU, so it was not idling.
8. Once it was done, I got a message with the information that the secure boot key had been installed—I didn't even need to follow the instructions on the [docs](https://docs.bazzite.gg/General/Installation_Guide/secure_boot/). I checked with `mokutil --list-enrolled` and it listed two keys—the one for Ventoy and the one for Bazzite; one of them seemed to be issued by SUSE Linux, not sure which one.
9. I rebooted straight  into Bazzite, it did some preparations before even booting, and rebooted once again until the system was up and running.

## First Impressions

- Quickly moving the mouse enlarged the cursor, as expected, but it also produced visual artifacts on top of the background—it seemed like the NVIDIA drivers might not be working correctly.
- I ran `ujust upgrade` and noticed NVIDIA software was being updated.
- I rebooted and entered the BIOS drive selection menu to boot back into Windows 11. Everything was working. I set this back as the default boot drive in the BIOS, just until I completed the migration to Bazzite—no shame on that.
- I booted back into Bazzite, but the visual artifacts remained. Strangely, they disappear when I opened the browser—maybe something to do with the fact that it has graphical acceleration?
	- This became extremely evident when waking up after suspending the system. It requires a full plasma restart and manually forcing re-rendering of all apps opened at the time of suspend (e.g., minimize + restore).
	- When this happens, I usually just restart Plasma, with `kquitapp6 plasmashell && sleep 3 && kstart plasmashell`. For other windows, minimizing and restoring usually solves any artifacts.
- Apart from visual artifacts, sometimes Bazzite won't come out of sleep completely, and I end up resetting. Sometimes the display doesn't turn back on, and power cycling solves it, other times the USB peripherals won't, where clicking the mouse will temporarily turn on its LEDs,  but the system won't respond.
- As for gaming, it takes a little using to a few quirks, but at the end of the day I was able to run any game, even if it required some tuning, like changing the Proton version, disabling the Steam overlay, or setting some environment variables.
