#!/bin/bash

################################################################################
# VoidPWN - Touch Calibration Fix (Left/Right Reversal)
# Description: Fixes inverted left/right touch input on TFT
# Author: void0x11
# Usage: sudo ./fix_touch_leftright.sh
################################################################################

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[*]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }

# Check root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root (use sudo)"
    exit 1
fi

USER_NAME="${SUDO_USER:-kali}"
USER_HOME="/home/$USER_NAME"

log_info "Fixing left/right touch reversal..."

# Update touch calibration with corrected matrix
# Original matrix: 0 1 0 -1 0 1 0 0 1 (had left/right reversed)
# New matrix: 0 -1 1 1 0 0 0 0 1 (fixes left/right)

cat > "$USER_HOME/.config/autostart/calibrate-touch.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Calibrate Touch
Exec=/bin/bash -c "sleep 3 && TOUCH_ID=$(xinput list | grep -i 'touch\|ADS7846' | grep -o 'id=[0-9]*' | grep -o '[0-9]*' | head -1) && [ -n \"$TOUCH_ID\" ] && xinput set-prop $TOUCH_ID 'Coordinate Transformation Matrix' 0 -1 1 1 0 0 0 0 1"
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
EOF

chown "$USER_NAME:$USER_NAME" "$USER_HOME/.config/autostart/calibrate-touch.desktop"

log_success "Touch calibration updated"
log_info "Applying calibration now (if X11 is running)..."

# Try to apply immediately if X11 is running
export DISPLAY=:0
TOUCH_ID=$(xinput list 2>/dev/null | grep -i 'touch\|ADS7846' | grep -o 'id=[0-9]*' | grep -o '[0-9]*' | head -1)

if [ -n "$TOUCH_ID" ]; then
    xinput set-prop $TOUCH_ID 'Coordinate Transformation Matrix' 0 -1 1 1 0 0 0 0 1 2>/dev/null
    log_success "Calibration applied immediately"
    echo ""
    echo -e "${GREEN}Touch calibration fixed!${NC}"
    echo "Left/right should now work correctly."
else
    log_info "X11 not running, calibration will apply on next boot"
    echo ""
    echo -e "${YELLOW}Reboot required:${NC} sudo reboot"
fi
