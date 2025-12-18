#!/bin/bash

################################################################################
# VoidPWN - Advanced WiFi Tools Installer
# Description: Installs specialized tools for PMKID, MDK4, and WPS attacks
# Author: void0x11
################################################################################

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[*]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }

# Check root
if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root (use sudo)"
    exit 1
fi

log_info "Updating package lists..."
apt update -y

log_info "Installing advanced WiFi pentesting suite..."

# 1. Modern Handshake/PMKID Tools
log_info "Installing hcxtools & hcxdumptool (PMKID)..."
apt install -y hcxtools hcxdumptool

# 2. Denial of Service & Confusion
log_info "Installing mdk4 (Beacon/Auth flooding)..."
apt install -y mdk4

# 3. WPS Exploitation
log_info "Installing pixiewps & reaver..."
apt install -y pixiewps reaver

# 4. Passive Sniffing
log_info "Installing tshark..."
DEBIAN_FRONTEND=noninteractive apt install -y tshark

log_success "Advanced tools installation complete!"
log_info "Installed: hcxtools, hcxdumptool, mdk4, pixiewps, reaver, tshark"
