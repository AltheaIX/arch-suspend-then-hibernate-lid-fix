# Arch Linux Suspend-Then-Hibernate on Lid Close

On Arch Linux with Gnome (especially at 6.18.5-zen1-1-zen version), closing the laptop lid often triggers a simple suspend, even when suspend-then-hibernate is properly configured in systemd.

In practice, this means the system never enter hibernation when the lid is closed and leading to unexpected battery drain or weird sleep behavior.

This repository documents a working solution to trigger suspend-then-hibernate when lid is closed using systemd, logind overrides and ACPID.

This setup was tested on:
- Arch Linux
- GNOME 49.x
- systemd 259-2-arch
- Kernel 6.18.5 (zen)

## Motivation
Coming from MacOS, I was used to closing the laptop lid and leaving the device for days with almost no battery drain.

When attempting to achieve similar behavior on Arch Linux with GNOME, I found that lid close only triggered a regular suspend, even with Suspend-Then-Hibernate configured in logind.conf and I tried to work-around with it to significantly reduces long-term power usage while the laptop is closed.

