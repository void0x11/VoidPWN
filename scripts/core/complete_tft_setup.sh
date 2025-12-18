#!/bin/bash

################################################################################
# VoidPWN - Complete TFT Setup Script
# Description: Applies all fixes for TFT rotation, touch, and HDMI restore
# Author: void0x11
# Usage: sudo ./complete_tft_setup.sh
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

# Check root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root (use sudo)"
    exit 1
fi

USER_NAME="${SUDO_USER:-kali}"
USER_HOME="/home/$USER_NAME"

echo ""
log_info "VoidPWN Complete TFT Setup"
echo ""
log_info "This script will configure:"
echo "  • Auto-login (no password prompt)"
echo "  • Chromium kiosk mode (fullscreen dashboard)"
echo "  • TFT portrait rotation (vertical display)"
echo "  • Touch input calibration"
echo "  • HDMI restore functionality"
echo ""

# Step 1: Auto-Login Configuration
log_info "Step 1/5: Configuring auto-login..."

LIGHTDM_CONF="/etc/lightdm/lightdm.conf"
if [ -f "$LIGHTDM_CONF" ]; then
    cp "$LIGHTDM_CONF" "$LIGHTDM_CONF.bak"
    sed -i '/^autologin-user=/d' "$LIGHTDM_CONF"
    sed -i '/^autologin-user-timeout=/d' "$LIGHTDM_CONF"
    
    if grep -q "^\[Seat:\*\]" "$LIGHTDM_CONF"; then
        sed -i "/^\[Seat:\*\]/a autologin-user=$USER_NAME\nautologin-user-timeout=0" "$LIGHTDM_CONF"
    else
        echo -e "\n[Seat:*]\nautologin-user=$USER_NAME\nautologin-user-timeout=0" >> "$LIGHTDM_CONF"
    fi
    log_success "Auto-login configured"
else
    mkdir -p /etc/lightdm/lightdm.conf.d/
    cat > /etc/lightdm/lightdm.conf.d/50-autologin.conf <<EOF
[Seat:*]
autologin-user=$USER_NAME
autologin-user-timeout=0
EOF
    log_success "Auto-login configured (alternative method)"
fi

# Step 2: Chromium Kiosk Mode
log_info "Step 2/5: Configuring Chromium kiosk mode..."

mkdir -p "$USER_HOME/.config/autostart"

cat > "$USER_HOME/.config/autostart/voidpwn-dashboard.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=VoidPWN Dashboard
Exec=/bin/bash -c "sleep 8 && chromium --noerrdialogs --disable-infobars --password-store=basic --kiosk http://localhost:5000"
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
EOF

cat > "$USER_HOME/.config/autostart/disable-screensaver.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Disable Screensaver
Exec=/bin/bash -c "xset -dpms && xset s off && xset s noblank"
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
EOF

chown -R "$USER_NAME:$USER_NAME" "$USER_HOME/.config/autostart"
log_success "Chromium kiosk mode configured"

# Step 3: TFT Portrait Rotation
log_info "Step 3/5: Configuring TFT portrait rotation..."

cat > "$USER_HOME/.config/autostart/rotate-display.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Rotate Display
Exec=/bin/bash -c "sleep 2 && xrandr -o right"
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
EOF

chown "$USER_NAME:$USER_NAME" "$USER_HOME/.config/autostart/rotate-display.desktop"
log_success "Display rotation configured"

# Step 4: Touch Calibration
log_info "Step 4/5: Configuring touch input calibration..."

# Touch calibration for portrait mode with USB on right
# Current issue: Up→Left, Down→Right, Right→Up, Left→Down (90° CCW misalignment)
# Fix: Apply 90° CW correction matrix: 0 1 0 -1 0 1 0 0 1
cat > "$USER_HOME/.config/autostart/calibrate-touch.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Calibrate Touch
Exec=/bin/bash -c "sleep 3 && TOUCH_ID=$(xinput list | grep -i 'touch\\|ADS7846' | grep -o 'id=[0-9]*' | grep -o '[0-9]*' | head -1) && [ -n \"$TOUCH_ID\" ] && xinput set-prop $TOUCH_ID 'Coordinate Transformation Matrix' 0 1 0 -1 0 1 0 0 1"
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
EOF

chown "$USER_NAME:$USER_NAME" "$USER_HOME/.config/autostart/calibrate-touch.desktop"
log_success "Touch calibration configured"

# Step 5: Verify Services
log_info "Step 5/5: Verifying services..."

systemctl set-default graphical.target
systemctl enable lightdm

if systemctl is-enabled voidpwn.service &>/dev/null; then
    log_success "voidpwn.service is enabled"
else
    systemctl enable voidpwn.service
fi

if systemctl is-active voidpwn.service &>/dev/null; then
    log_success "voidpwn.service is running"
else
    systemctl start voidpwn.service
fi

# Summary
echo ""
log_success "Complete TFT setup finished!"
echo ""
echo -e "${YELLOW}Configuration Summary:${NC}"
echo "  ✓ Auto-login: $USER_NAME"
echo "  ✓ Dashboard: http://localhost:5000"
echo "  ✓ Display: Portrait mode (vertical)"
echo "  ✓ Touch: Calibrated for portrait"
echo "  ✓ HDMI Restore: Available in SYSTEM tab"
echo ""
echo -e "${BLUE}Next Steps:${NC}"
echo "  1. Reboot: sudo reboot"
echo "  2. TFT should display dashboard in portrait mode"
echo "  3. Touch input should work correctly"
echo "  4. To restore HDMI: Use SYSTEM tab → SWITCH TO HDMI"
echo ""
log_warning "Reboot required for all changes to take effect"
