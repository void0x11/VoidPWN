#!/bin/bash

################################################################################
# VoidPWN - Network Reconnaissance Script
# Description: Automated network scanning and enumeration
# Author: void0x11
# Usage: ./recon.sh [options]
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
OUTPUT_DIR="$PROJECT_ROOT/output/recon"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Banner
print_banner() {
    echo -e "${CYAN}"
    cat << "EOF"
    ╦═╗┌─┐┌─┐┌─┐┌┐┌
    ╠╦╝├┤ │  │ ││││
    ╩╚═└─┘└─┘└─┘┘└┘
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

# Quick network scan
quick_scan() {
    local target="$1"
    
    if [[ -z "$target" ]]; then
        log_error "Usage: $0 --quick <TARGET>"
        exit 1
    fi
    
    local output="$OUTPUT_DIR/quick_scan_${TIMESTAMP}.txt"
    
    log_info "Quick scan of $target"
    log_info "Output: $output"
    echo ""
    
    nmap -sn "$target" | tee "$output"
    
    log_success "Scan complete"
}

# Full port scan
full_scan() {
    local target="$1"
    
    if [[ -z "$target" ]]; then
        log_error "Usage: $0 --full <TARGET>"
        exit 1
    fi
    
    local output="$OUTPUT_DIR/full_scan_${TIMESTAMP}"
    
    log_info "Full port scan of $target"
    log_info "This may take a while..."
    log_info "Output: $output"
    echo ""
    
    nmap -sV -sC -O -A -p- -oA "$output" "$target"
    
    log_success "Scan complete"
    log_info "Results saved to: ${output}.nmap"
}

# Stealth scan
stealth_scan() {
    local target="$1"
    
    if [[ -z "$target" ]]; then
        log_error "Usage: $0 --stealth <TARGET>"
        exit 1
    fi
    
    local output="$OUTPUT_DIR/stealth_scan_${TIMESTAMP}"
    
    log_info "Stealth SYN scan of $target"
    log_info "Output: $output"
    echo ""
    
    nmap -sS -T2 -f -D RND:10 -oA "$output" "$target"
    
    log_success "Scan complete"
}

# Vulnerability scan
vuln_scan() {
    local target="$1"
    
    if [[ -z "$target" ]]; then
        log_error "Usage: $0 --vuln <TARGET>"
        exit 1
    fi
    
    local output="$OUTPUT_DIR/vuln_scan_${TIMESTAMP}"
    
    log_info "Vulnerability scan of $target"
    log_info "Output: $output"
    echo ""
    
    nmap --script vuln -oA "$output" "$target"
    
    log_success "Scan complete"
}

# Web enumeration
web_enum() {
    local target="$1"
    local wordlist="${2:-/usr/share/wordlists/dirb/common.txt}"
    
    if [[ -z "$target" ]]; then
        log_error "Usage: $0 --web <TARGET> [WORDLIST]"
        exit 1
    fi
    
    local output="$OUTPUT_DIR/web_enum_${TIMESTAMP}.txt"
    
    log_info "Web directory enumeration: $target"
    log_info "Wordlist: $wordlist"
    log_info "Output: $output"
    echo ""
    
    gobuster dir -u "$target" -w "$wordlist" -o "$output" -x php,html,txt,js
    
    log_success "Enumeration complete"
}

# SMB enumeration
smb_enum() {
    local target="$1"
    
    if [[ -z "$target" ]]; then
        log_error "Usage: $0 --smb <TARGET>"
        exit 1
    fi
    
    local output="$OUTPUT_DIR/smb_enum_${TIMESTAMP}.txt"
    
    log_info "SMB enumeration of $target"
    log_info "Output: $output"
    echo ""
    
    {
        echo "=== NMAP SMB Scripts ==="
        nmap -p445 --script smb-enum-shares,smb-enum-users,smb-os-discovery "$target"
        
        echo ""
        echo "=== Enum4linux ==="
        enum4linux -a "$target"
        
        echo ""
        echo "=== SMBClient Shares ==="
        smbclient -L "$target" -N
    } | tee "$output"
    
    log_success "SMB enumeration complete"
}

# ARP scan
arp_scan_network() {
    local interface="${1:-eth0}"
    
    log_info "ARP scan on interface $interface"
    echo ""
    
    arp-scan --interface="$interface" --localnet
    
    log_success "ARP scan complete"
}

# DNS enumeration
dns_enum() {
    local domain="$1"
    
    if [[ -z "$domain" ]]; then
        log_error "Usage: $0 --dns <DOMAIN>"
        exit 1
    fi
    
    local output="$OUTPUT_DIR/dns_enum_${TIMESTAMP}.txt"
    
    log_info "DNS enumeration of $domain"
    log_info "Output: $output"
    echo ""
    
    {
        echo "=== DNS Lookup ==="
        nslookup "$domain"
        
        echo ""
        echo "=== DNS Records ==="
        dig "$domain" ANY
        
        echo ""
        echo "=== Reverse DNS ==="
        host "$domain"
        
        echo ""
        echo "=== Zone Transfer Attempt ==="
        dig axfr "@$domain" "$domain"
    } | tee "$output"
    
    log_success "DNS enumeration complete"
}

# Network discovery
network_discovery() {
    log_info "Discovering local network..."
    echo ""
    
    # Get default gateway
    local gateway=$(ip route | grep default | awk '{print $3}')
    local network=$(ip -o -f inet addr show | awk '/scope global/ {print $4}' | head -1)
    
    log_info "Gateway: $gateway"
    log_info "Network: $network"
    echo ""
    
    log_info "Active hosts:"
    nmap -sn "$network" | grep "Nmap scan report" | awk '{print $5}'
    
    log_success "Discovery complete"
}

# Comprehensive scan
comprehensive_scan() {
    local target="$1"
    
    if [[ -z "$target" ]]; then
        log_error "Usage: $0 --comprehensive <TARGET>"
        exit 1
    fi
    
    local scan_dir="$OUTPUT_DIR/comprehensive_${TIMESTAMP}"
    mkdir -p "$scan_dir"
    
    log_info "Comprehensive scan of $target"
    log_info "Output directory: $scan_dir"
    echo ""
    
    # Host discovery
    log_info "[1/5] Host discovery..."
    nmap -sn "$target" -oA "$scan_dir/01_host_discovery"
    
    # Port scan
    log_info "[2/5] Port scanning..."
    nmap -sV -sC -oA "$scan_dir/02_port_scan" "$target"
    
    # Vulnerability scan
    log_info "[3/5] Vulnerability scanning..."
    nmap --script vuln -oA "$scan_dir/03_vuln_scan" "$target"
    
    # OS detection
    log_info "[4/5] OS detection..."
    nmap -O -oA "$scan_dir/04_os_detection" "$target"
    
    # Service enumeration
    log_info "[5/5] Service enumeration..."
    nmap -sV --script=banner,http-title,smb-os-discovery -oA "$scan_dir/05_service_enum" "$target"
    
    log_success "Comprehensive scan complete"
    log_info "Results in: $scan_dir"
}

# Show help
show_help() {
    cat << EOF
${CYAN}VoidPWN Network Reconnaissance${NC}

${YELLOW}Usage:${NC}
  sudo $0 [OPTION] <TARGET>

${YELLOW}Options:${NC}
  --quick <TARGET>          Quick host discovery scan
  --full <TARGET>           Full port scan with service detection
  --stealth <TARGET>        Stealth SYN scan
  --vuln <TARGET>           Vulnerability scan
  --web <URL> [WORDLIST]    Web directory enumeration
  --smb <TARGET>            SMB enumeration
  --dns <DOMAIN>            DNS enumeration
  --arp [INTERFACE]         ARP scan on local network
  --discover                Discover local network
  --comprehensive <TARGET>  Full comprehensive scan
  --help                    Show this help

${YELLOW}Examples:${NC}
  sudo $0 --quick 192.168.1.0/24
  sudo $0 --full 192.168.1.100
  sudo $0 --web http://example.com
  sudo $0 --smb 192.168.1.50
  sudo $0 --comprehensive 192.168.1.100

${YELLOW}Output Directory:${NC}
  $OUTPUT_DIR

${RED}Legal Warning:${NC}
  Only scan networks and systems you own or have permission to test.
  Unauthorized scanning is illegal.

EOF
}

# Main
main() {
    print_banner
    check_root
    
    case "$1" in
        --quick)
            quick_scan "$2"
            ;;
        --full)
            full_scan "$2"
            ;;
        --stealth)
            stealth_scan "$2"
            ;;
        --vuln)
            vuln_scan "$2"
            ;;
        --web)
            web_enum "$2" "$3"
            ;;
        --smb)
            smb_enum "$2"
            ;;
        --dns)
            dns_enum "$2"
            ;;
        --arp)
            arp_scan_network "$2"
            ;;
        --discover)
            network_discovery
            ;;
        --comprehensive)
            comprehensive_scan "$2"
            ;;
        --help|*)
            show_help
            ;;
    esac
}

main "$@"
