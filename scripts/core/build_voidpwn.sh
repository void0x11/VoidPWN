#!/bin/bash

################################################################################
# VoidPWN - Master Build & Setup Orchestrator
# Description: Unified "One-Touch" installer for the entire VoidPWN platform.
#              Consolidates toolchain, system, kiosk, and display configurations.
# Author: void0x11
# Usage: sudo ./build_voidpwn.sh
################################################################################

# set -e # Removed for build resilience

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[*]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }
log_step() { echo -e "${CYAN}>> $1${NC}"; }

# Check root
if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root (use sudo)"
    exit 1
fi

USER_NAME="${SUDO_USER:-kali}"
USER_HOME=$(getent passwd "$USER_NAME" | cut -d: -f6)
VOIDPWN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

clear
echo -e "${CYAN}"
cat << "EOF"
    ╦  ╦┌─┐┬┌┬┐╔═╗╦ ╦╔╗╔
    ╚╗╔╝│ │││ ││╠═╝║║║║║║
     ╚╝ └─┘┴└─┘┴╩  ╚╩╝╝╚╝
    MASTER BUILD ORCHESTRATOR v3.2
EOF
echo -e "${NC}"

log_info "Starting the complete VoidPWN build process."
log_info "This script unifies all legacy setup files into a single technical deployment."
echo ""

# --- Resilience Wrapper Functions ---
# Critical install: Exit on failure
install_critical() {
    log_info "Installing CRITICAL: $1..."
    apt install -y $2 || { log_error "Failed to install critical dependency: $1"; exit 1; }
}

# Non-critical install: Continue on failure
install_tool_group() {
    log_info "Installing $1..."
    apt install -y $2 || log_warning "Some packages in '$1' failed. Skipping non-critical tools."
}

# Python Resilience: Continue on failure
install_python_tool() {
    log_info "Installing Python tool: $1..."
    pip3 install $1 --break-system-packages || log_warning "Failed to install Python tool: $1. Skipping..."
}

# --- 1. System Foundation (CRITICAL) ---
log_step "PHASE 1: System Baseline & Dependencies"
log_info "Updating package lists..."
apt update -y || log_warning "Apt update encountered issues. Continuing..."

install_critical "Foundation (X11, Python, Utilities)" "\
    xserver-xorg x11-xserver-utils xinit xinput \
    matchbox-window-manager chromium unclutter \
    python3-flask python3-psutil python3-pip \
    git wget curl iw pciutils net-tools"
log_success "Foundation ready."

# --- 2. Security Toolchain (Consolidated) ---
log_step "PHASE 2: Security Arsenal Installation"

install_tool_group() {
    log_info "Installing $1..."
    # Non-critical tools allow failure
    apt install -y $2 || log_warning "Some packages in '$1' failed to install. Skipping non-critical tools."
}

# Wireless & Network
# 'tc' is replaced with 'iproute2' which contains 'tc'
install_tool_group "Wireless Suite" "aircrack-ng wifite bettercap mdk4 hcxdumptool hcxtools reaver pixiewps hostapd dnsmasq"
install_tool_group "Network Recon" "nmap masscan wireshark tshark ettercap-text-only arp-scan dsniff iproute2 gdb ltrace strace"

# Frameworks & Specialized Tools
log_info "Installing Advanced Frameworks (SET, Empire)..."
apt install -y set powershell-empire

# Forensics, RE, & Mobile
install_tool_group "Forensics" "autopsy sleuthkit volatility3 binwalk foremost exiftool"
install_tool_group "Reverse Engineering" "radare2 ghidra"
install_tool_group "Mobile Analysis" "apktool dex2jar jadx"

# Python Advanced
install_python_tool "wifiphisher"

# Fluxion
if [ ! -d "/opt/fluxion" ]; then
    log_info "Cloning Fluxion..."
    git clone https://github.com/FluxionNetwork/fluxion.git /opt/fluxion
fi

log_success "Arsenal fully provisioned."

# --- 3. Platform Configuration ---
log_step "PHASE 3: Service & Autostart Configuration"

# Dashboard Service
log_info "Creating voidpwn.service..."
cat > /etc/systemd/system/voidpwn.service << EOF
[Unit]
Description=VoidPWN Dashboard Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$VOIDPWN_DIR/dashboard
ExecStart=/usr/bin/python3 server.py
Restart=always
Environment=VOIDPWN_DIR=$VOIDPWN_DIR

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable voidpwn.service
log_success "Backend service enabled."

# Auto-login Configuration (tty1 & LightDM fallback)
log_info "Configuring system auto-login for $USER_NAME..."
mkdir -p /etc/systemd/system/getty@tty1.service.d/
cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf << EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $USER_NAME --noclear %I \$TERM
EOF

if [ -d "/etc/lightdm" ]; then
    mkdir -p /etc/lightdm/lightdm.conf.d/
    cat > /etc/lightdm/lightdm.conf.d/50-autologin.conf <<EOF
[Seat:*]
autologin-user=$USER_NAME
autologin-user-timeout=0
EOF
fi

# Kiosk Setup (.xinitrc & .Xresources)
log_info "Configuring OS-level scaling for 3.5\" TFT..."
cat > "$USER_HOME/.Xresources" << EOF
Xft.dpi: 85
EOF

cat > "$USER_HOME/.xinitrc" << EOF
#!/bin/bash
# Load scaling settings
xrdb -merge ~/.Xresources
export GDK_SCALE=1
export GDK_DPI_SCALE=0.85
export QT_AUTO_SCREEN_SCALE_FACTOR=0
export QT_FONT_DPI=85

xset -dpms
xset s off
xset s noblank
unclutter -idle 0.1 -root &
matchbox-window-manager -use_titlebar no &
sleep 5
chromium --noerrdialogs --disable-infobars --kiosk http://localhost:5000 &
exec sh /etc/X11/Xsession
EOF
chown "$USER_NAME:$USER_NAME" "$USER_HOME/.xinitrc" "$USER_HOME/.Xresources"
chmod +x "$USER_HOME/.xinitrc"

# Auto-start X on TTY1
if ! grep -q "startx" "$USER_HOME/.bashrc"; then
    echo -e "\n# Auto-start Kiosk Mode on tty1\nif [[ -z \$DISPLAY ]] && [[ \$(tty) = /dev/tty1 ]]; then\n    startx -- -nocursor\nfi" >> "$USER_HOME/.bashrc"
fi
log_success "Platform configuration and OS scaling applied."

# --- 4. Display & Touch Calibration (Universal) ---
log_step "PHASE 4: Display & Touch Staging"
log_info "Preparing calibration triggers..."

# Create calibration script
cat > "$VOIDPWN_DIR/scripts/core/apply_calibration.sh" << 'EOF'
#!/bin/bash
# Apply 90° CW correction for portrait mode
TOUCH_ID=$(xinput list | grep -i 'touch\|ADS7846' | grep -o 'id=[0-9]*' | grep -o '[0-9]*' | head -1)
if [ -n "$TOUCH_ID" ]; then
    xinput set-prop $TOUCH_ID 'Coordinate Transformation Matrix' 0 1 0 -1 0 1 0 0 1
fi
EOF
chmod +x "$VOIDPWN_DIR/scripts/core/apply_calibration.sh"

# Add to autostart
mkdir -p "$USER_HOME/.config/autostart"
cat > "$USER_HOME/.config/autostart/voidpwn-cal.desktop" << EOF
[Desktop Entry]
Type=Application
Name=VoidPWN Calibration
Exec=$VOIDPWN_DIR/scripts/core/apply_calibration.sh
EOF
chown -R "$USER_NAME:$USER_NAME" "$USER_HOME/.config"

log_success "Display logic staged."

# --- 5. Cleanup & Finalize ---
log_step "PHASE 5: Finalization"
log_info "Correcting permissions..."
chmod +x "$VOIDPWN_DIR/voidpwn.sh"
find "$VOIDPWN_DIR/scripts" -name "*.sh" -exec chmod +x {} \;

echo ""
log_success "════════════════════════════════════════════════════════════"
log_success "         VOIDPWN MASTER BUILD COMPLETE!"
log_success "════════════════════════════════════════════════════════════"
echo ""
log_info "Legacy setup scripts can now be archived."
echo -e "${YELLOW}FINAL V3 ACTION REQUIRED:${NC}"
echo "To activate the 3.5\" LCD and finalize hardware rotation, run:"
echo -e "  ${CYAN}sudo ./scripts/core/install_lcd.sh${NC}"
echo ""
log_warning "After LCD installation, the system will reboot into the HUD."
echo ""
