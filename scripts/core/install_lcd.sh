#!/bin/bash

################################################################################
# VoidPWN - LCD Display Installation Script
# Description: Install Waveshare 3.5" LCD drivers (run this LAST)
# Usage: sudo ./install_lcd.sh
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

# Warning
echo -e "${YELLOW}"
cat << "EOF"
╔═══════════════════════════════════════════════╗
║           LCD DISPLAY INSTALLATION            ║
║                                               ║
║  WARNING: This will switch output from HDMI   ║
║  to the 3.5" LCD screen and reboot the Pi.    ║
║                                               ║
║  Make sure you have:                          ║
║  - Completed all other setup steps            ║
║  - SSH access configured                      ║
║  - The LCD physically connected               ║
╚═══════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Auto-proceed (no user confirmation needed when called from dashboard)
log_info "Proceeding with LCD installation..."

# Install LCD drivers
log_info "Installing LCD drivers..."

# Remove old installation if exists
rm -rf ~/LCD-show-kali

# Clone the repository
log_info "Downloading LCD drivers..."
git clone https://github.com/lcdwiki/LCD-show-kali.git ~/LCD-show-kali

# Set permissions
chmod -R 755 ~/LCD-show-kali

# Navigate to directory
cd ~/LCD-show-kali

log_success "Drivers downloaded"

# Install the LCD
log_warning "Installing LCD driver - system will reboot..."
sleep 3

./LCD35-show

# Note: The script will reboot the system automatically
# If it doesn't reboot, something went wrong
