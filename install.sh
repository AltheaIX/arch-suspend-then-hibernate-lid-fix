#!/bin/bash
set -e

echo "--- Starting Arch Suspend-then-Hibernate Lid Fix Installer ---"

# 1. Logind
echo "[1/3] Configuring systemd-logind..."
sudo mkdir -p /etc/systemd/logind.conf.d
sudo tee /etc/systemd/logind.conf.d/logind_override.conf > /dev/null <<EOF
[Login]
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
HandleLidSwitchDocked=ignore
EOF

# 2. Sleep
echo "[2/3] Configuring systemd-sleep..."
sudo mkdir -p /etc/systemd/sleep.conf.d
sudo tee /etc/systemd/sleep.conf.d/sleep_override.conf > /dev/null <<EOF
[Sleep]
AllowSuspend=yes
AllowHibernation=yes
AllowSuspendThenHibernate=yes
HibernateDelaySec=1h
EOF

sudo systemctl daemon-reexec

# 3. ACPID
echo "[3/3] Setting up acpid..."

if ! pacman -Q acpid &> /dev/null; then
    echo "Installing acpid..."
    sudo pacman -S --noconfirm acpid
fi

sudo mkdir -p /etc/acpi/events
sudo tee /etc/acpi/events/lid > /dev/null <<EOF
event=button/lid.*
action=/usr/bin/systemctl suspend-then-hibernate
EOF

sudo systemctl enable --now acpid

echo "--- Installation Complete ---"
echo "IMPORTANT: Make sure hibernation (swap + resume) is properly configured!"
