#!/bin/bash

################################################################################
# VoidPWN - Touch Screen Kiosk Mode Setup
# Description: Configures the Raspberry Pi to boot directly into the Web Dashboard
#              in fullscreen Kiosk mode, ideal for 3.5" touch screens.
# Author: void0x11
# Usage: sudo ./setup_kiosk.sh
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
    log_error "This script must be run as root (use sudo)"
    exit 1
fi

log_info "Setting up VoidPWN Kiosk Mode for Touch Screen..."

# 1. Install necessary packages
log_info "Installing dependencies (X11, Chromium, Window Manager)..."
apt update
apt install -y \
    xserver-xorg \
    x11-xserver-utils \
    xinit \
    matchbox-window-manager \
    chromium \
    x11-utils \
    unclutter \
    python3-flask \
    python3-psutil

log_success "Dependencies installed"

# 2. Configure Systemd Service for Dashboard (Backend)
log_info "Configuring Dashboard Service..."
USER_HOME=$(getent passwd $SUDO_USER | cut -d: -f6)
VOIDPWN_DIR="$USER_HOME/VoidPWN"

# Create Service File
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

# Enable and Start Service
systemctl daemon-reload
systemctl enable voidpwn.service
systemctl restart voidpwn.service
log_success "Dashboard service installed and started (voidpwn.service)"

# 3. Configure X init script to launch Kiosk (Frontend only)
log_info "Configuring X11 startup script..."

cat > /home/$SUDO_USER/.xinitrc << EOF
#!/bin/bash

# Disable screen saver and power management
xset -dpms
xset s off
xset s noblank

# Hide cursor if not moving
unclutter -idle 0.1 -root &

# Start window manager (removes title bars for fullscreen feel)
matchbox-window-manager -use_titlebar no &

# Wait a moment for network/server
sleep 5

# Start Chromium in Kiosk Mode
# Pointing to localhost:5000 where the systemd service is running
chromium --noerrdialogs --disable-infobars --kiosk http://localhost:5000 &

# Keep session alive
exec sh /etc/X11/Xsession
EOF

chown $SUDO_USER:$SUDO_USER /home/$SUDO_USER/.xinitrc
chmod +x /home/$SUDO_USER/.xinitrc

log_success "X11 configured"

# 3. Configure Autostart
log_info "Configuring autostart..."

BASHRC="/home/$SUDO_USER/.bashrc"

# Check if startx is already in .bashrc
if grep -q "startx" "$BASHRC"; then
    log_warning "Autostart already configured in .bashrc"
else
    echo "" >> "$BASHRC"
    echo "# Auto-start Kiosk Mode on tty1" >> "$BASHRC"
    echo 'if [[ -z $DISPLAY ]] && [[ $(tty) = /dev/tty1 ]]; then' >> "$BASHRC"
    echo '    startx -- -nocursor' >> "$BASHRC"
    echo 'fi' >> "$BASHRC"
    log_success "Added startx to .bashrc"
fi

# 4. Ensure Auto-Login is enabled (handled by main setup, but good to double check)
log_info "Verifying auto-login..."
if [ -f "/etc/systemd/system/getty@tty1.service.d/autologin.conf" ]; then
    log_info "Auto-login appears configured."
else
    log_warning "Auto-login might not be set. Running setup.sh configuration..."
    # Create autologin service
    mkdir -p /etc/systemd/system/getty@tty1.service.d/
    cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf << EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $SUDO_USER --noclear %I \$TERM
EOF
    systemctl enable getty@tty1.service
    log_success "Auto-login configured"
fi

echo ""
log_success "════════════════════════════════════════════"
log_success "  Kiosk Mode Setup Complete!"
log_success "════════════════════════════════════════════"
echo ""
log_info "The next time you reboot:"
echo "  1. System will auto-login"
echo "  2. X11 will start automatically"
echo "  3. Dashboard will load in full-screen on the LCD"
echo ""
log_warning "To exit Kiosk mode: Connect a keyboard and press Ctrl+Alt+Fx to switch TTY, or SSH in."
log_info "Reboot now to test: sudo reboot"
