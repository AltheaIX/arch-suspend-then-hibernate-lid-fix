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

## Motivation
Coming from MacOS, I was used to closing the laptop lid and leaving the device for days with almost no battery drain.

When attempting to achieve similar behavior on Arch Linux with GNOME, I found that lid close only triggered a regular suspend, even with Suspend-Then-Hibernate configured in logind.conf and I tried to work-around with it to significantly reduces long-term power usage while the laptop is closed.

## Why This Fails 
With minimal setup, you will only get suspend on lid close. Even if you are doing something like this on your logind.conf and sleep.conf
```
$ sudo cat /etc/systemd/logind.conf

[Login]
HandleLidSwitch=suspend
HandleLidSwitchExternalPower=suspend
```

```
$ sudo cat /etc/systemd/sleep.conf

[Sleep]
AllowSuspend=yes
AllowHibernation=yes
AllowSuspendThenHibernate=yes
SuspendState=mem
HibernateDelaySec=10
```

You wont know until you check it. So, close your lid and open it again, then run this command for observation.
```
$ sudo journalctl -f -u systemd-logind
```

You will see something similar to these logs
```
Jan xx xx:xx:37 user systemd-logind[483]: Lid closed.
Jan xx xx:x:37 user systemd-logind[483]: Suspending...
Jan xx xx:xx:35 user systemd-logind[483]: Lid opened.
Jan xx xx:xx:35 user systemd-logind[483]: Operation 'suspend' finished.
```

Which means it only suspends. Even if you change the logind.conf to be something like this, then try to close and open the lid it will still fail and let to unexpected behavior.

```
$ sudo cat /etc/systemd/logind.conf

[Login]
HandleLidSwitch=suspend-then-hibernate
HandleLidSwitchExternalPower=suspend-then-hibernate
```
The logs would probably be like this:
```
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
```
$ sudo systemctl suspend-then-hibernate
```
```
$ sudo journalctl -f -u systemd-logind
Jan xx xx:xx:09 user systemd-logind[483]: The system will suspend and later hibernate now!
Jan xx xx:xx:44 user systemd-logind[483]: Operation 'suspend-then-hibernate' finished.
```

## Solution (WIP)
