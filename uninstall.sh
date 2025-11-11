#!/bin/bash

# Uninstall script for RAK5146 gateway
# This removes what install.sh installed

set -e

if [ $UID != 0 ]; then
    echo "ERROR: Operation not permitted. Forgot sudo?"
    exit 1
fi

function echo_yellow()
{
    echo -e "\033[1;33m$1\033[0m"
}

function echo_green()
{
    echo -e "\033[1;32m$1\033[0m"
}

function echo_red()
{
    echo -e "\033[1;31m$1\033[0m"
}

function show_model_menu()
{
    echo "========================================"
    echo "RAK Gateway Uninstall Script"
    echo "========================================"
    echo ""
    echo_red "NOTE: This script only supports RAK5146 models"
    echo ""
    echo_yellow "Please select your gateway model:"
    echo_yellow " *\t --  RAK2245 (Not supported)"
    echo_yellow " *\t --  RAK7243/RAK7244 no LTE (Not supported)"
    echo_yellow " *\t --  RAK7243/RAK7244 with LTE (Not supported)"
    echo_yellow " *\t --  RAK2247(USB) (Not supported)"
    echo_yellow " *\t --  RAK2247(SPI) (Not supported)"
    echo_yellow " *\t --  RAK2246 (Not supported)"
    echo_yellow " *\t --  RAK7248(SPI) no LTE (Not supported)"
    echo_yellow " *\t --  RAK7248(SPI) with LTE (Not supported)"
    echo_yellow " *\t --  RAK2287(USB) (Not supported)"
    echo_green  " *\t 10. RAK5146(USB)"
    echo_green  " *\t 11. RAK5146(SPI)"
    echo_green  " *\t 12. RAK5146(SPI) with LTE"
    echo ""
    echo_yellow "Please enter 10-12 to select the model (or 'q' to quit): "
}

function select_model()
{
    while true; do
        show_model_menu
        read -r RAK_MODEL
        
        if [ "$RAK_MODEL" = "q" ] || [ "$RAK_MODEL" = "Q" ]; then
            echo "Uninstall cancelled."
            exit 0
        fi
        
        if [ -z "$RAK_MODEL" ]; then
            continue
        fi
        
        # Check if it's a number
        if ! [[ "$RAK_MODEL" =~ ^[0-9]+$ ]]; then
            echo_red "Invalid input. Please enter 10-12 or 'q' to quit."
            echo ""
            continue
        fi
        
        # Only accept RAK5146 models (10, 11, 12)
        if [ "$RAK_MODEL" -ge 10 ] && [ "$RAK_MODEL" -le 12 ]; then
            case "$RAK_MODEL" in
                10) INSTALL_LTE=0; SPI_MODE=0; echo_green "Selected: RAK5146(USB)";;
                11) INSTALL_LTE=0; SPI_MODE=1; echo_green "Selected: RAK5146(SPI)";;
                12) INSTALL_LTE=1; SPI_MODE=1; echo_green "Selected: RAK5146(SPI) with LTE";;
            esac
            return 0
        else
            echo_red "Invalid selection. This script only supports RAK5146 models (10-12)."
            echo ""
        fi
    done
}

# Show model selection
select_model

echo ""
echo "This will remove:"
echo "  - Gateway services and systemd units"
echo "  - Configuration files in /usr/local/rak"
echo "  - Packet forwarder in /opt/ttn-gateway"
echo "  - Gateway binaries in /usr/bin"
echo "  - AP and LTE services"
if [ "$INSTALL_LTE" -eq 1 ]; then
    echo "  - LTE/PPP configuration (as this is an LTE model)"
fi
echo ""
read -p "Continue? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Uninstall cancelled."
    exit 0
fi

echo ""
echo "Stopping and disabling services..."

# Stop and disable gateway services
systemctl stop ttn-gateway 2>/dev/null || true
systemctl disable ttn-gateway 2>/dev/null || true

# Stop and disable AP service
systemctl stop create_ap 2>/dev/null || true
systemctl disable create_ap 2>/dev/null || true

# Stop and disable LTE service
systemctl stop rak-pppd 2>/dev/null || true
systemctl disable rak-pppd 2>/dev/null || true

echo "Removing systemd service files..."
rm -f /lib/systemd/system/ttn-gateway.service
rm -f /lib/systemd/system/create_ap.service
rm -f /lib/systemd/system/rak-pppd.service

systemctl daemon-reload

echo "Removing gateway files and directories..."

# Remove packet forwarder
rm -rf /opt/ttn-gateway

# Remove RAK configuration and scripts
rm -rf /usr/local/rak

# Remove gateway binaries
rm -f /usr/bin/gateway-config
rm -f /usr/bin/gateway-version
rm -f /usr/bin/rak_test
rm -f /usr/bin/test_rak

echo "Cleaning up rc.local..."
# Remove rak_script line from rc.local if it exists
if [ -f /etc/rc.local ]; then
    sed -i '/rak_script/d' /etc/rc.local
fi

echo "Restoring original boot configuration..."
# Note: We don't restore /boot/config.txt automatically as it may have other changes
# Users should manually verify /boot/config.txt if they need to restore it

echo ""
echo "========================================"
echo "Uninstall complete!"
echo "========================================"
echo ""
echo "Note: The following were NOT removed:"
echo "  - Installed packages (git, ppp, dialog, jq, minicom, monit, i2c-tools, gpiod)"
echo "  - /boot/config.txt (contains UART/SPI settings - review manually if needed)"
echo "  - Network configuration in /etc/wpa_supplicant or /etc/dhcpcd.conf"
echo "  - Hostname changes"
echo ""
echo "To complete cleanup, you may want to:"
echo "  1. Review /boot/config.txt for any RAK-specific changes"
echo "  2. Reboot the system"
echo ""

