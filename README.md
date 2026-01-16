# Arch Linux Suspend-Then-Hibernate on Lid Close

On Arch Linux with Gnome (especially at 6.18.5-zen1-1-zen version), closing the laptop lid often triggers a simple suspend, even when suspend-then-hibernate is properly configured in systemd.

In practice, this means the system never enter hibernation when the lid is closed and leading to unexpected battery drain or weird sleep behavior.

This repository documents a working solution to trigger suspend-then-hibernate when lid is closed using systemd, logind overrides and ACPID.

This setup was tested on:
- Arch Linux
- GNOME 49.2
- systemd 259-2-arch
- Kernel 6.18.5 (zen)
- GRUB 2:2.14rc1

## Table of Contents
- [Overview](#arch-linux-suspend-then-hibernate-on-lid-close)
- [Motivation](#motivation)
- [Why This Fails](#why-this-fails)
- [Solution](#solution)
- [Issues](#issues)


## Motivation
Coming from MacOS, I was used to closing the laptop lid and leaving the device for days with almost no battery drain.

When attempting to achieve similar behavior on Arch Linux with GNOME, I found that lid close only triggered a regular suspend, even with Suspend-Then-Hibernate configured in logind.conf and I tried to work-around with it to significantly reduces long-term power usage while the laptop is closed.

## Why This Fails 
With minimal setup, you will only get suspend on lid close. Even if you are doing something like this on your logind.conf and sleep.conf
```Bash
$ sudo cat /etc/systemd/logind.conf

[Login]
HandleLidSwitch=suspend
HandleLidSwitchExternalPower=suspend
```

```Bash
$ sudo cat /etc/systemd/sleep.conf

[Sleep]
AllowSuspend=yes
AllowHibernation=yes
AllowSuspendThenHibernate=yes
SuspendState=mem
HibernateDelaySec=10
```

You wont know until you check it. So, close your lid and open it again, then run this command for observation.
```Bash
$ sudo journalctl -f -u systemd-logind
```

You will see something similar to these logs
```Bash
Jan xx xx:xx:37 user systemd-logind[483]: Lid closed.
Jan xx xx:xx:37 user systemd-logind[483]: Suspending...
Jan xx xx:xx:35 user systemd-logind[483]: Lid opened.
Jan xx xx:xx:35 user systemd-logind[483]: Operation 'suspend' finished.
```

Which means it only suspends. Even if you change the logind.conf to be something like this, then try to close and open the lid it will still fail and let to unexpected behavior.

```Bash
$ sudo cat /etc/systemd/logind.conf

[Login]
HandleLidSwitch=suspend-then-hibernate
HandleLidSwitchExternalPower=suspend-then-hibernate
```
The logs would probably be like this:
```Bash
$ sudo journalctl -f -u systemd-logind

Jan xx xx:xx:02 user systemd-logind[483]: Lid closed.
Jan xx xx:xx:02 user systemd-logind[483]: Suspending, then hibernating...
Jan xx xx:xx:13 user systemd-logind[483]: Operation 'suspend-then-hibernate' finished.
Jan xx xx:xx:42 user systemd-logind[483]: Suspending, then hibernating...
Jan xx xx:xx:51 user systemd-logind[483]: Lid opened.
Jan xx xx:xx:51 user systemd-logind[483]: Operation 'suspend-then-hibernate' finished.
```
Systemd-logind treats lid close differently from an explicit suspend-then-hibernate request, and the hibernate timer never completes while the lid event lifecycle is active.
The proof is if you run this command, and waited for 10s (as HibernateDelaySec=10), it will go to hibernate and you will need to use your power button to activate it.
```Bash
$ sudo systemctl suspend-then-hibernate
```
```Bash
$ sudo journalctl -f -u systemd-logind

Jan xx xx:xx:09 user systemd-logind[483]: The system will suspend and later hibernate now!
Jan xx xx:xx:44 user systemd-logind[483]: Operation 'suspend-then-hibernate' finished.
```

## Solution
First of all, I would assume you have correctly configured your hibernation setting. Such as, GRUB Config, Resume on HOOKS, Disk Swap and when you use
```Bash
$ sudo systemctl hibernate
```
You would need to use your power button to activate your device and it restores all of your applications like when you hibernated it.
If systemctl hibernate does not fully power off and restore state, do not proceed.

What we want to achieve is
```
lid close
  ↓
suspend (fast, low power)
  ↓ after delay
hibernate (zero power)
```

### 1. Configure Logind
To start with, you will need to Configure Logind to make it ignore Lid Switch's Event.
First, you will need to make the override config. (Configuration files is provided on the repository)
```Bash
$ sudo mkdir -p /etc/systemd/logind.conf.d
$ sudo nano /etc/systemd/logind.conf.d/logind_override.conf
```
Then put these on your logind_override.conf
```
[Login]
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
HandleLidSwitchDocked=ignore
```
Save it then restart your system, to ensure you configured it correctly. Run this command
```Bash
$ sudo systemd-analyze cat-config /etc/systemd/logind.conf
```
Scroll down and if you see your override config, then you good. Try to close and open your laptop's lid, It shouldn't do anything now.

### 2. Configure Sleep
Same as before, you would need to make a override config for sleep.conf. (Configuration files is provided on the repository)
```Bash
$ sudo mkdir -p /etc/systemd/sleep.conf.d
$ sudo nano /etc/systemd/sleep.conf.d/sleep_override.conf
```
Then put these on your sleep_override.conf
```
[Sleep]
AllowSuspend=yes
AllowHibernation=yes
AllowSuspendThenHibernate=yes
HibernateDelaySec=1h
```
Note: you can change how long it should be Suspended before going Hibernate by changing HibernateDelaySec's value. I suggest you not touch other parameters unless you know what you're doing.

After that, you would need to execute this command to apply the changes
```Bash
$ sudo systemctl daemon-reexec
```
Then, you could execute this command
```Bash
$ sudo systemd-analyze cat-config /etc/systemd/sleep.conf
```
To check and make sure you configured your override config correctly.
And, you should test suspend-then-hibernate before you go further. You can change the HibernateDelaySec to 10 (means 10 seconds), execute the command below and wait for around 12-15s before doing anything.
```Bash
$ sudo systemctl suspend-then-hibernate
```
If it goes to Hibernate, you can go further.

### 3. Configure Lid Event with ACPID
First, you would need to install the ACPID if you haven't done it
```Bash
$ sudo pacman -S acpid
$ sudo systemctl enable --now acpid
```
Before creating the configuration, make sure ACPID listened to the event correctly. Run this command
```Bash
$ sudo acpi_listen
```
Then, Close and Open your laptop's lid. If you see this text on your terminal, it means ACPID works as intended.
```
button/lid LID close
button/lid LID open
```
Next is to make the ACPID Event Rule. Run this command (Configuration files is provided on the repository)
```Bash
$ sudo nano /etc/acpi/events/lid
```
Then paste the text below into your /etc/acpi/events/lid
```
event=button/lid.*
action=/usr/bin/systemctl suspend-then-hibernate
```
Apply the changes by restarting ACPID.
```Bash
$ sudo systemctl restart acpid
```
Then you can try to Close and Open your laptop lid again, it should work perfectly now.

## Issues
If you have issues with this setup, you could open a new issues on this repository.
