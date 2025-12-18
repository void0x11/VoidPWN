#!/bin/bash

################################################################################
# VoidPWN - Additional Tools Installer
# Description: Install extra pentesting tools on demand
# Author: void0x11
# Usage: sudo ./install_tools.sh
################################################################################

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

# Check root
if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root (use sudo)"
    exit 1
fi

# Menu
show_menu() {
    clear
    echo -e "${CYAN}"
    cat << "EOF"
    ╔═══════════════════════════════════╗
    ║   Additional Tools Installer      ║
    ╚═══════════════════════════════════╝
EOF
    echo -e "${NC}"
    echo ""
    echo -e "  ${CYAN}[1]${NC} Wireless Tools (wifiphisher, fluxion)"
    echo -e "  ${CYAN}[2]${NC} Social Engineering (SET)"
    echo -e "  ${CYAN}[3]${NC} Post-Exploitation (Empire, Covenant)"
    echo -e "  ${CYAN}[4]${NC} Forensics Tools"
    echo -e "  ${CYAN}[5]${NC} Reverse Engineering Tools"
    echo -e "  ${CYAN}[6]${NC} Mobile Tools (APK analysis)"
    echo -e "  ${CYAN}[7]${NC} Install All"
    echo -e "  ${CYAN}[0]${NC} Exit"
    echo ""
}

# Wireless tools
install_wireless() {
    log_info "Installing advanced wireless tools..."
    
    # Wifiphisher
    pip3 install wifiphisher
    
    # Fluxion
    git clone https://github.com/FluxionNetwork/fluxion.git /opt/fluxion
    
    log_success "Wireless tools installed"
}

# Social engineering
install_social_eng() {
    log_info "Installing Social Engineering Toolkit..."
    
    apt install -y set
    
    log_success "SET installed"
}

# Post-exploitation
install_post_exploit() {
    log_info "Installing post-exploitation frameworks..."
    
    # PowerShell Empire
    apt install -y powershell-empire
    
    log_success "Post-exploitation tools installed"
}

# Forensics
install_forensics() {
    log_info "Installing forensics tools..."
    
    apt install -y \
        autopsy \
        sleuthkit \
        volatility3 \
        binwalk \
        foremost \
        exiftool
    
    log_success "Forensics tools installed"
}

# Reverse engineering
install_reverse_eng() {
    log_info "Installing reverse engineering tools..."
    
    apt install -y \
        radare2 \
        ghidra \
        gdb \
        ltrace \
        strace \
        objdump
    
    log_success "Reverse engineering tools installed"
}

# Mobile tools
install_mobile() {
    log_info "Installing mobile analysis tools..."
    
    apt install -y \
        apktool \
        dex2jar \
        jadx
    
    # MobSF (optional - resource intensive)
    log_warning "MobSF not installed (resource intensive)"
    log_info "Install manually: https://github.com/MobSF/Mobile-Security-Framework-MobSF"
    
    log_success "Mobile tools installed"
}

# Install all
install_all() {
    install_wireless
    install_social_eng
    install_post_exploit
    install_forensics
    install_reverse_eng
    install_mobile
    
    log_success "All additional tools installed!"
}

# Main
main() {
    while true; do
        show_menu
        read -p "$(echo -e ${GREEN}Select option: ${NC})" choice
        
        case $choice in
            1) install_wireless ;;
            2) install_social_eng ;;
            3) install_post_exploit ;;
            4) install_forensics ;;
            5) install_reverse_eng ;;
            6) install_mobile ;;
            7) install_all ;;
            0) exit 0 ;;
            *) log_error "Invalid option" ;;
        esac
        
        echo ""
        read -p "Press Enter to continue..."
    done
}

main
