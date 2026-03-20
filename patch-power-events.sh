#!/bin/bash

# Configuration
HOOK_PATH="/usr/lib/systemd/system-sleep/90-force-hibernate"
ACPI_LID_PATH="/etc/acpi/events/lid"
HIBERNATE_DELAY=1800 # 30 minutes

echo "--- Applying Force-Hibernate Patch ---"

# 1. Create the system-sleep hook
echo "[1/3] Creating system-sleep hook at $HOOK_PATH..."
sudo tee "$HOOK_PATH" > /dev/null <<EOF
#!/bin/sh
# Auto-generated force-hibernate hook

logger "[force-hibernate] hook called: \$1"

# Time in seconds to stay in suspend before hibernating
HIBERNATE_DELAY=$HIBERNATE_DELAY

case "\$1" in
  pre)
    logger "[force-hibernate] pre-called: setting rtcwake for \$HIBERNATE_DELAYs"
    rtcwake -m disable > /dev/null 2>&1
    rtcwake -m no -s \$HIBERNATE_DELAY
    ;;
  post)
    ALARM_TIME=\$(cat /sys/class/rtc/rtc0/wakealarm)
    logger "[force-hibernate] post-resume detected"

    if [ -z "\$ALARM_TIME" ]; then
        logger "[force-hibernate] alarm expired, initiating hibernate"
        /usr/lib/systemd/systemd-sleep hibernate
    else
        logger "[force-hibernate] manual wake detected, clearing alarm"
        rtcwake -m disable > /dev/null 2>&1
    fi
    ;;
esac
EOF

# 2. Set executable permissions
sudo chmod +x "$HOOK_PATH"

# 3. Update ACPID Lid Event
# We change it from 'suspend-then-hibernate' to 'suspend' 
# because our new hook handles the 'then-hibernate' part automatically.
echo "[2/3] Updating ACPI lid event..."
sudo tee "$ACPI_LID_PATH" > /dev/null <<EOF
event=button/lid LID close
action=/usr/bin/systemctl suspend --ignore-inhibitors
EOF

# 4. Refresh Services
echo "[3/3] Restarting services..."
sudo systemctl daemon-reexec
sudo systemctl restart acpid

echo "--- Patch Applied Successfully ---"
echo "To monitor activity, use: journalctl -f | grep force-hibernate"
