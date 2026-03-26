#!/bin/bash
set -e

HOOK_PATH="/usr/lib/systemd/system-sleep/90-force-hibernate"
ACPI_LID_PATH="/etc/acpi/events/lid"
HIBERNATE_DELAY=1800 # 30 minutes

echo "--- Applying Force-Hibernate (s2idle fix) Patch ---"

# 1. Configuring sleep.conf.d
echo "[1/3] Updating configuration sleep.conf.d for s2idle"
sudo tee /etc/systemd/sleep.conf.d/sleep_override.conf > /dev/null <<EOF
[Sleep]
AllowSuspend=yes
AllowHibernation=yes
AllowSuspendThenHibernate=yes
HibernateMode=shutdown
SuspendMode=s2idle
SuspendState=mem
HibernateOnACPower=yes
EOF

sudo systemctl daemon-reexec

# 2. Create the system-sleep hook
echo "[2/3] Creating system-sleep hook at $HOOK_PATH..."
sudo tee "$HOOK_PATH" > /dev/null <<EOF
#!/bin/sh

logger "[force-hibernate] hook called: \$1 (\$SYSTEMD_SLEEP_ACTION)"

FLAG="/run/force-hibernate"
HIBERNATE_DELAY=$HIBERNATE_DELAY

case "\$1" in
  pre)
    logger "[force-hibernate] pre-called"
    if [ "\$SYSTEMD_SLEEP_ACTION" = "suspend" ]; then
	touch "\$FLAG"
    	rtcwake -m disable > /dev/null 2>&1
    	rtcwake -m no -s \$HIBERNATE_DELAY
    fi
    ;;
  post)
    logger "[force-hibernate] post-resume detected"

    ALARM_TIME=\$(cat /sys/class/rtc/rtc0/wakealarm)
    CURRENT_TIME=\$(date +%s)

    # To prevent hibernate loop after continues from hibernate state
    [ "\$SYSTEMD_SLEEP_ACTION" != "suspend" ] && exit 0
    
    # Just to be sure it comes from this script
    [ ! -f "\$FLAG" ] && exit 0

    if [ -n "\$ALARM_TIME" ] &&	[ "\$CURRENT_TIME" -lt "\$ALARM_TIME" ]; then
	logger "[force-hibernate] interrupted"
	exit 0
    fi
    
    if [ -f "\$FLAG" ]; then
        logger "[force-hibernate] hibernating"
        systemd-run --on-active=2s /usr/bin/systemctl hibernate --no-block
    else
        logger "[force-hibernate] interrupted"
        rtcwake -m disable > /dev/null 2>&1
    fi
    ;;
esac
EOF

sudo chmod +x "$HOOK_PATH"

echo "[3/3] Updating ACPI lid event..."
sudo tee "$ACPI_LID_PATH" > /dev/null <<EOF
event=button/lid.*
action=/bin/sh -c "systemctl suspend -i"
EOF

sudo systemctl daemon-reexec
sudo systemctl restart acpid

echo "--- Patch Applied Successfully ---"
echo "To monitor activity, use: journalctl -b 0 | grep force-hibernate"
