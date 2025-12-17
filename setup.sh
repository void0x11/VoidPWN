#!/bin/bash

################################################################################
# VoidPWN - Main Setup Script
# Description: Automated installation and configuration for VoidPWN device
# Author: void0x11
# Usage: sudo ./setup.sh
################################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Banner
print_banner() {
    echo -e "${BLUE}"
    cat << "EOF"
    ╦  ╦┌─┐┬┌┬┐╔═╗╦ ╦╔╗╔
    ╚╗╔╝│ │││ ││╠═╝║║║║║║
     ╚╝ └─┘┴└─┘┴╩  ╚╩╝╝╚╝
    Portable Pentesting Device
EOF
    echo -e "${NC}"
}

# Logging functions
log_info() {
    echo -e "${BLUE}[*]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Update system
update_system() {
    log_info "Updating system packages..."
    apt update -y
    apt upgrade -y
    log_success "System updated"
}

# Install essential tools
install_essential_tools() {
    log_info "Installing essential tools..."
    
    apt install -y \
        git \
        vim \
        tmux \
        htop \
        curl \
        wget \
        net-tools \
        wireless-tools \
        rfkill \
        python3-pip \
        python3-dev \
        build-essential
    
    log_success "Essential tools installed"
    
    log_success "Essential tools installed"
    
    # Install Python packages for dashboard
    log_info "Installing Python packages for dashboard..."
    # Use apt instead of pip to avoid "externally managed environment" error
    apt install -y python3-flask python3-psutil
    log_success "Python packages installed"
}

# Install WiFi pentesting tools
install_wifi_tools() {
    log_info "Installing WiFi pentesting tools..."
    
    apt install -y \
        aircrack-ng \
        wifite \
        bettercap \
        mdk4 \
        hcxdumptool \
        hcxtools \
        reaver \
        pixiewps \
        hostapd \
        dnsmasq
    
    log_success "WiFi tools installed"
}

# Install network tools
install_network_tools() {
    log_info "Installing network reconnaissance tools..."
    
    apt install -y \
        nmap \
        masscan \
        netcat-traditional \
        tcpdump \
        wireshark \
        tshark \
        ettercap-text-only \
        arp-scan \
        nbtscan
    
    log_success "Network tools installed"
}

# Install password cracking tools
install_password_tools() {
    log_info "Installing password cracking tools..."
    
    apt install -y \
        hashcat \
        john \
        hydra \
        medusa \
        crunch
    
    log_success "Password tools installed"
}

# Install exploitation tools
install_exploit_tools() {
    log_info "Installing exploitation frameworks..."
    
    apt install -y \
        metasploit-framework \
        sqlmap \
        responder \
        impacket-scripts \
        enum4linux \
        smbclient
    
    log_success "Exploitation tools installed"
}

# Install web tools
install_web_tools() {
    log_info "Installing web application testing tools..."
    
    apt install -y \
        gobuster \
        dirb \
        nikto \
        wpscan \
        whatweb
    
    log_success "Web tools installed"
}

# Configure WiFi adapter
configure_wifi_adapter() {
    log_info "Configuring WiFi adapter..."
    
    # Kill interfering processes
    airmon-ng check kill > /dev/null 2>&1 || true
    
    # Check for wireless adapters
    if iwconfig 2>/dev/null | grep -q "wlan"; then
        log_success "WiFi adapter detected"
        
        # Create helper script for monitor mode
        cat > /usr/local/bin/monitor-mode << 'SCRIPT'
#!/bin/bash
IFACE=${1:-wlan1}
sudo airmon-ng start $IFACE
SCRIPT
        chmod +x /usr/local/bin/monitor-mode
        
        log_success "Monitor mode helper created: monitor-mode <interface>"
    else
        log_warning "No WiFi adapter detected - plug in your ALFA adapter"
    fi
}

# Install PiSugar software
install_pisugar() {
    log_info "Installing PiSugar battery management..."
    
    if curl -s http://cdn.pisugar.com/release/pisugar-power-manager.sh | bash; then
        log_success "PiSugar installed - Web UI at http://<IP>:8421"
    else
        log_warning "PiSugar installation failed - skip if not using battery"
    fi
}

# Configure auto-login
configure_autologin() {
    log_info "Configuring auto-login..."
    
    # Create autologin service
    mkdir -p /etc/systemd/system/getty@tty1.service.d/
    cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf << EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin kali --noclear %I \$TERM
EOF
    
    systemctl enable getty@tty1.service
    log_success "Auto-login configured"
}

# Optimize power settings
optimize_power() {
    log_info "Optimizing power settings..."
    
    # Disable Bluetooth if not needed
    if grep -q "dtoverlay=disable-bt" /boot/config.txt; then
        log_info "Bluetooth already disabled"
    else
        echo "dtoverlay=disable-bt" >> /boot/config.txt
        log_success "Bluetooth disabled for power saving"
    fi
    
    # Disable HDMI on boot (can be re-enabled manually)
    cat > /usr/local/bin/hdmi-off << 'SCRIPT'
#!/bin/bash
/usr/bin/tvservice -o
SCRIPT
    chmod +x /usr/local/bin/hdmi-off
    
    log_success "Power optimization complete"
}

# Create VoidPWN menu launcher
create_launcher() {
    log_info "Creating VoidPWN launcher..."
    
    cat > /usr/local/bin/voidpwn << 'SCRIPT'
#!/bin/bash
cd ~/VoidPWN
./voidpwn.sh
SCRIPT
    chmod +x /usr/local/bin/voidpwn
    
    log_success "Launcher created - run 'voidpwn' from anywhere"
}

# Final setup
final_setup() {
    log_info "Performing final setup..."
    
    # Update locate database
    updatedb
    
    # Clean up
    apt autoremove -y
    apt clean
    
    log_success "Setup complete!"
}

# Main installation
main() {
    print_banner
    check_root
    
    log_info "Starting VoidPWN setup..."
    echo ""
    
    update_system
    install_essential_tools
    install_wifi_tools
    install_network_tools
    install_password_tools
    install_exploit_tools
    install_web_tools
    configure_wifi_adapter
    install_pisugar
    configure_autologin
    optimize_power
    create_launcher
    final_setup
    
    echo ""
    log_success "═══════════════════════════════════════"
    log_success "  VoidPWN Setup Complete!"
    log_success "═══════════════════════════════════════"
    echo ""
    log_info "Next steps:"
    echo "  1. Reboot the system: sudo reboot"
    echo "  2. Plug in your ALFA WiFi adapter"
    echo "  3. Run: voidpwn (to launch the menu)"
    echo "  4. Install LCD last: sudo ./install_lcd.sh"
    echo ""
    log_warning "Reboot recommended to apply all changes"
}

main "$@"
