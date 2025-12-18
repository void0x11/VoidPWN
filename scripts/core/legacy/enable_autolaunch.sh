#!/bin/bash

################################################################################
# VoidPWN - Enable Auto-Launch on Boot
# Description: Configure VoidPWN to launch automatically on LCD screen
# Author: void0x11
# Usage: sudo ./enable_autolaunch.sh
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

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root (use sudo)"
    exit 1
fi

# Get the VoidPWN directory
VOIDPWN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VOIDPWN_SCRIPT="$VOIDPWN_DIR/voidpwn.sh"

log_info "Configuring auto-launch for VoidPWN..."

# 1. Create a systemd service for auto-launch
log_info "Creating systemd service..."

cat > /etc/systemd/system/voidpwn.service << EOF
[Unit]
Description=VoidPWN Pentesting Device
After=network.target
Wants=display-manager.service

[Service]
Type=simple
User=root
WorkingDirectory=$VOIDPWN_DIR
ExecStart=/bin/bash -c 'sleep 5 && $VOIDPWN_SCRIPT'
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

log_success "Systemd service created at /etc/systemd/system/voidpwn.service"

# 2. Enable the service
log_info "Enabling VoidPWN service..."
systemctl daemon-reload
systemctl enable voidpwn.service
log_success "VoidPWN service enabled"

# 3. Configure auto-login for Kali user
log_info "Configuring auto-login..."

mkdir -p /etc/systemd/system/getty@tty1.service.d
cat > /etc/systemd/system/getty@tty1.service.d/override.conf << EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin kali --noclear %I \$TERM
EOF

log_success "Auto-login configured"

# 4. Add bashrc configuration to auto-launch on login
log_info "Configuring bashrc for auto-launch..."

if ! grep -q "# VoidPWN Auto-Launch" /root/.bashrc; then
    cat >> /root/.bashrc << 'EOF'

# VoidPWN Auto-Launch
if [ -z "$DISPLAY" ] && [ "$XDG_VTNR" = "1" ]; then
    export TERM=linux
    $VOIDPWN_SCRIPT
fi
EOF
    log_success "Bashrc updated for root"
fi

if ! grep -q "# VoidPWN Auto-Launch" /home/kali/.bashrc; then
    cat >> /home/kali/.bashrc << 'EOF'

# VoidPWN Auto-Launch
if [ -z "$DISPLAY" ] && [ "$XDG_VTNR" = "1" ]; then
    export TERM=linux
    $VOIDPWN_SCRIPT
fi
EOF
    log_success "Bashrc updated for kali user"
fi

# 5. Create a startup script
log_info "Creating startup script..."
mkdir -p /etc/init.d
cat > /usr/local/bin/voidpwn-start << EOF
#!/bin/bash
cd $VOIDPWN_DIR
$VOIDPWN_SCRIPT
EOF

chmod +x /usr/local/bin/voidpwn-start
log_success "Startup script created at /usr/local/bin/voidpwn-start"

# Display summary
echo ""
echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   AUTO-LAUNCH CONFIGURATION COMPLETE   ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
echo ""
echo "VoidPWN will now:"
echo "  ✓ Auto-login as 'kali' user on boot"
echo "  ✓ Launch the main menu automatically"
echo "  ✓ Restart if the menu exits"
echo ""
echo -e "${YELLOW}Manual Start Commands:${NC}"
echo "  voidpwn                              # Launch from CLI"
echo "  sudo systemctl start voidpwn         # Start service"
echo "  sudo systemctl stop voidpwn          # Stop service"
echo "  sudo systemctl disable voidpwn       # Disable auto-start"
echo ""
echo -e "${YELLOW}Testing auto-launch (optional):${NC}"
echo "  You can test by rebooting: sudo reboot"
echo ""
log_success "Auto-launch enabled!"
