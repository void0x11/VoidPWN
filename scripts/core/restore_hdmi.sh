#!/bin/bash

################################################################################
# VoidPWN - HDMI Switcher
# Description: Restores HDMI output and disables LCD drivers
# Usage: sudo ./restore_hdmi.sh
################################################################################

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[*]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }

# Check root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root (use sudo)"
    exit 1
fi

# Determine user (handle both direct sudo and systemd service calls)
if [ -n "$SUDO_USER" ]; then
    TARGET_USER="$SUDO_USER"
else
    TARGET_USER="kali"
fi

log_info "Restoring HDMI output for user: $TARGET_USER..."
log_warning "This will disable the 3.5\" LCD and reboot the system."

# Method 1: Try LCD-show driver script
LCD_DIR="/home/$TARGET_USER/LCD-show-kali"
if [ -d "$LCD_DIR" ]; then
    cd "$LCD_DIR"
    
    if [ -f "./LCD-hdmi" ]; then
        log_info "Found LCD driver script, executing..."
        chmod +x ./LCD-hdmi
        ./LCD-hdmi
        exit 0
    fi
fi

# Method 2: Try alternative LCD-show location
LCD_DIR_ALT="/home/$TARGET_USER/LCD-show"
if [ -d "$LCD_DIR_ALT" ]; then
    cd "$LCD_DIR_ALT"
    
    if [ -f "./LCD-hdmi" ]; then
        log_info "Found LCD driver script (alternative location), executing..."
        chmod +x ./LCD-hdmi
        ./LCD-hdmi
        exit 0
    fi
fi

# Method 3: Manual restoration of /boot/config.txt
log_warning "Driver script not found, using manual method..."

if [ -f "/boot/config.txt.bak" ]; then
    log_info "Restoring /boot/config.txt from backup..."
    cp /boot/config.txt.bak /boot/config.txt
    log_success "Config restored"
else
    log_warning "No backup found, creating clean config..."
    # Remove LCD-specific overlays
    sed -i '/dtoverlay=.*lcd/d' /boot/config.txt
    sed -i '/dtoverlay=ads7846/d' /boot/config.txt
fi

# Remove rotation settings from autostart
log_info "Removing TFT rotation settings..."
rm -f "/home/$TARGET_USER/.config/autostart/rotate-display.desktop" 2>/dev/null
rm -f "/home/$TARGET_USER/.config/autostart/calibrate-touch.desktop" 2>/dev/null

log_success "HDMI restoration complete"
log_info "Rebooting in 3 seconds..."
sleep 3
reboot

