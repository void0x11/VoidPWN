#!/bin/bash

################################################################################
# VoidPWN - TFT Screen Rotation & Touch Calibration Fix
# Description: Rotates TFT to portrait mode and calibrates touch input
# Author: void0x11
# Usage: sudo ./fix_tft_rotation.sh
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

log_info "Configuring TFT screen rotation and touch calibration..."

# Step 1: Rotate Display to Portrait (270 degrees = vertical)
log_info "Step 1: Creating display rotation script..."

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

log_success "Display rotation configured (portrait mode)"

# Step 2: Calibrate Touch Input
log_info "Step 2: Configuring touch input calibration..."

# Find the touchscreen device
TOUCH_DEVICE=$(xinput list | grep -i touch | grep -o 'id=[0-9]*' | grep -o '[0-9]*' | head -1)

if [ -z "$TOUCH_DEVICE" ]; then
    log_warning "Touch device not found, trying alternative method..."
    TOUCH_DEVICE=$(xinput list | grep -i "ADS7846" | grep -o 'id=[0-9]*' | grep -o '[0-9]*' | head -1)
fi

if [ -n "$TOUCH_DEVICE" ]; then
    log_info "Found touch device ID: $TOUCH_DEVICE"
    
    # Create touch calibration script
    cat > "$USER_HOME/.config/autostart/calibrate-touch.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Calibrate Touch
Exec=/bin/bash -c "sleep 3 && xinput set-prop $TOUCH_DEVICE 'Coordinate Transformation Matrix' 0 1 0 -1 0 1 0 0 1"
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
EOF
    
    chown "$USER_NAME:$USER_NAME" "$USER_HOME/.config/autostart/calibrate-touch.desktop"
    log_success "Touch calibration configured"
else
    log_warning "Could not detect touch device automatically"
    log_info "You may need to calibrate manually after reboot"
fi

# Step 3: Update Chromium to use portrait mode
log_info "Step 3: Updating Chromium autostart for portrait display..."

cat > "$USER_HOME/.config/autostart/voidpwn-dashboard.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=VoidPWN Dashboard
Exec=/bin/bash -c "sleep 8 && chromium --noerrdialogs --disable-infobars --password-store=basic --kiosk http://localhost:5000"
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
EOF

chown "$USER_NAME:$USER_NAME" "$USER_HOME/.config/autostart/voidpwn-dashboard.desktop"

log_success "Chromium autostart updated (increased delay for rotation)"

# Summary
echo ""
log_success "Configuration complete!"
echo ""
echo -e "${YELLOW}Changes made:${NC}"
echo "  ✓ Display rotation: Landscape → Portrait (right rotation)"
echo "  ✓ Touch calibration: Axes aligned with portrait mode"
echo "  ✓ Chromium delay: Increased to 8s to allow rotation to complete"
echo ""
echo -e "${BLUE}Next Steps:${NC}"
echo "  1. Reboot: sudo reboot"
echo "  2. TFT should display in portrait mode (vertical)"
echo "  3. Touch input should align correctly"
echo ""
log_warning "Reboot required for changes to take effect"
