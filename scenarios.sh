#!/bin/bash

################################################################################
# VoidPWN - Automated Attack Scenarios
# Description: Pre-configured attack scenarios for one-click execution
# Author: void0x11
# Usage: ./scenarios.sh
################################################################################

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="$HOME/VoidPWN/scenarios"
CAPTURES_DIR="$HOME/VoidPWN/captures"
RECON_DIR="$HOME/VoidPWN/recon"

# Create output directory
mkdir -p "$OUTPUT_DIR"

log_info() { echo -e "${BLUE}[*]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }

# Banner
print_banner() {
    clear
    echo -e "${CYAN}"
    cat << "EOF"
    ╔═══════════════════════════════════╗
    ║   AUTOMATED ATTACK SCENARIOS      ║
    ╚═══════════════════════════════════╝
EOF
    echo -e "${NC}"
    echo ""
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

################################################################################
# SCENARIO 1: WiFi Audit - Full Network Assessment
################################################################################
scenario_wifi_audit() {
    print_banner
    log_info "SCENARIO 1: WiFi Network Audit"
    echo ""
    log_info "This scenario will:"
    echo "  1. Scan for all WiFi networks"
    echo "  2. Capture handshakes from nearby networks"
    echo "  3. Attempt WPS attacks"
    echo "  4. Generate report"
    echo ""
    
    read -p "Duration in minutes (default: 10): " duration
    duration=${duration:-10}
    
    local output="$OUTPUT_DIR/wifi_audit_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$output"
    
    log_info "Starting WiFi audit for $duration minutes..."
    
    # Enable monitor mode
    log_info "Enabling monitor mode..."
    "$SCRIPT_DIR/wifi_tools.sh" --monitor-on
    
    # Scan networks
    log_info "Scanning networks..."
    timeout ${duration}m airodump-ng -w "$output/scan" --output-format csv wlan1mon &
    SCAN_PID=$!
    
    # Wait for scan
    sleep $((duration * 60))
    
    # Kill scan
    kill $SCAN_PID 2>/dev/null
    
    # Disable monitor mode
    "$SCRIPT_DIR/wifi_tools.sh" --monitor-off
    
    # Generate report
    log_info "Generating report..."
    cat > "$output/report.txt" << EOF
WiFi Network Audit Report
Generated: $(date)
Duration: $duration minutes

Networks Found:
$(grep -c "^[0-9]" "$output/scan-01.csv" 2>/dev/null || echo "0")

Scan Files:
$(ls -lh "$output/")

Recommendations:
- Review captured networks in scan-01.csv
- Identify networks with weak encryption (WEP)
- Check for WPS-enabled routers
- Test handshake captures with password lists
EOF
    
    log_success "WiFi audit complete!"
    log_info "Results saved to: $output"
    echo ""
    cat "$output/report.txt"
    echo ""
    read -p "Press Enter to continue..."
}

################################################################################
# SCENARIO 2: Network Sweep - Complete Network Discovery
################################################################################
scenario_network_sweep() {
    print_banner
    log_info "SCENARIO 2: Network Sweep"
    echo ""
    log_info "This scenario will:"
    echo "  1. Discover all hosts on network"
    echo "  2. Scan all ports on discovered hosts"
    echo "  3. Identify services and versions"
    echo "  4. Check for common vulnerabilities"
    echo ""
    
    # Auto-detect network
    local network=$(ip route | grep default | awk '{print $3}' | sed 's/\.[0-9]*$/\.0\/24/')
    
    log_info "Detected network: $network"
    read -p "Use this network? (y/n): " confirm
    
    if [[ "$confirm" != "y" ]]; then
        read -p "Enter network (e.g., 192.168.1.0/24): " network
    fi
    
    local output="$OUTPUT_DIR/network_sweep_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$output"
    
    log_info "Starting network sweep..."
    
    # Host discovery
    log_info "[1/4] Discovering hosts..."
    nmap -sn "$network" -oA "$output/01_discovery"
    
    # Extract live hosts
    local hosts=$(grep "Up" "$output/01_discovery.gnmap" | awk '{print $2}')
    local host_count=$(echo "$hosts" | wc -l)
    
    log_success "Found $host_count hosts"
    
    # Port scan
    log_info "[2/4] Scanning ports on $host_count hosts..."
    nmap -sV -sC -p- $hosts -oA "$output/02_port_scan"
    
    # Vulnerability scan
    log_info "[3/4] Checking for vulnerabilities..."
    nmap --script vuln $hosts -oA "$output/03_vuln_scan"
    
    # OS detection
    log_info "[4/4] Detecting operating systems..."
    nmap -O $hosts -oA "$output/04_os_detection"
    
    # Generate report
    log_info "Generating report..."
    cat > "$output/report.txt" << EOF
Network Sweep Report
Generated: $(date)
Network: $network

Summary:
- Hosts discovered: $host_count
- Total open ports: $(grep "open" "$output/02_port_scan.nmap" | wc -l)
- Vulnerabilities found: $(grep "VULNERABLE" "$output/03_vuln_scan.nmap" | wc -l)

Live Hosts:
$hosts

Detailed results in:
- 01_discovery.nmap
- 02_port_scan.nmap
- 03_vuln_scan.nmap
- 04_os_detection.nmap
EOF
    
    log_success "Network sweep complete!"
    log_info "Results saved to: $output"
    echo ""
    cat "$output/report.txt"
    echo ""
    read -p "Press Enter to continue..."
}

################################################################################
# SCENARIO 3: Web Application Hunt - Find and Enumerate Web Services
################################################################################
scenario_web_hunt() {
    print_banner
    log_info "SCENARIO 3: Web Application Hunt"
    echo ""
    log_info "This scenario will:"
    echo "  1. Find all web servers on network"
    echo "  2. Enumerate directories and files"
    echo "  3. Identify web technologies"
    echo "  4. Check for common vulnerabilities"
    echo ""
    
    # Auto-detect network
    local network=$(ip route | grep default | awk '{print $3}' | sed 's/\.[0-9]*$/\.0\/24/')
    
    log_info "Detected network: $network"
    read -p "Use this network? (y/n): " confirm
    
    if [[ "$confirm" != "y" ]]; then
        read -p "Enter network (e.g., 192.168.1.0/24): " network
    fi
    
    local output="$OUTPUT_DIR/web_hunt_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$output"
    
    log_info "Starting web application hunt..."
    
    # Find web servers
    log_info "[1/4] Finding web servers..."
    nmap -p 80,443,8080,8443 --open "$network" -oA "$output/01_web_servers"
    
    # Extract web server IPs
    local web_hosts=$(grep "open" "$output/01_web_servers.gnmap" | awk '{print $2}' | sort -u)
    local web_count=$(echo "$web_hosts" | wc -l)
    
    if [[ -z "$web_hosts" ]]; then
        log_warning "No web servers found"
        read -p "Press Enter to continue..."
        return
    fi
    
    log_success "Found $web_count web servers"
    
    # Enumerate each web server
    log_info "[2/4] Enumerating web servers..."
    for host in $web_hosts; do
        log_info "Scanning $host..."
        
        # Directory enumeration
        gobuster dir -u "http://$host" \
            -w /usr/share/wordlists/dirb/common.txt \
            -o "$output/gobuster_$host.txt" \
            -q 2>/dev/null || true
        
        # Technology detection
        whatweb "http://$host" > "$output/whatweb_$host.txt" 2>/dev/null || true
    done
    
    # Nikto scan
    log_info "[3/4] Running Nikto scans..."
    for host in $web_hosts; do
        nikto -h "http://$host" -output "$output/nikto_$host.txt" 2>/dev/null || true
    done
    
    # SQL injection check
    log_info "[4/4] Checking for SQL injection..."
    for host in $web_hosts; do
        sqlmap -u "http://$host" --batch --crawl=2 \
            --output-dir="$output/sqlmap_$host" 2>/dev/null || true
    done
    
    # Generate report
    log_info "Generating report..."
    cat > "$output/report.txt" << EOF
Web Application Hunt Report
Generated: $(date)
Network: $network

Summary:
- Web servers found: $web_count
- Directories discovered: $(cat "$output"/gobuster_*.txt 2>/dev/null | wc -l)

Web Servers:
$web_hosts

Results:
- Directory enumeration: gobuster_*.txt
- Technology detection: whatweb_*.txt
- Vulnerability scan: nikto_*.txt
- SQL injection tests: sqlmap_*/
EOF
    
    log_success "Web application hunt complete!"
    log_info "Results saved to: $output"
    echo ""
    cat "$output/report.txt"
    echo ""
    read -p "Press Enter to continue..."
}

################################################################################
# SCENARIO 4: Stealth Recon - Low-Profile Network Reconnaissance
################################################################################
scenario_stealth_recon() {
    print_banner
    log_info "SCENARIO 4: Stealth Reconnaissance"
    echo ""
    log_info "This scenario will:"
    echo "  1. Perform slow, stealthy scans"
    echo "  2. Use fragmentation and decoys"
    echo "  3. Avoid IDS/IPS detection"
    echo "  4. Gather intelligence quietly"
    echo ""
    
    read -p "Enter target IP or network: " target
    
    if [[ -z "$target" ]]; then
        log_error "Target required"
        read -p "Press Enter to continue..."
        return
    fi
    
    local output="$OUTPUT_DIR/stealth_recon_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$output"
    
    log_info "Starting stealth reconnaissance on $target..."
    log_warning "This will be slow to avoid detection..."
    
    # Stealth SYN scan
    log_info "[1/4] Stealth SYN scan..."
    nmap -sS -T2 -f --data-length 25 -D RND:10 "$target" -oA "$output/01_syn_scan"
    
    # Service detection (slow)
    log_info "[2/4] Service detection..."
    nmap -sV -T1 --version-intensity 0 "$target" -oA "$output/02_services"
    
    # OS fingerprinting
    log_info "[3/4] OS fingerprinting..."
    nmap -O -T1 "$target" -oA "$output/03_os_detect"
    
    # Script scan (safe scripts only)
    log_info "[4/4] Safe script scan..."
    nmap --script safe -T1 "$target" -oA "$output/04_scripts"
    
    # Generate report
    log_info "Generating report..."
    cat > "$output/report.txt" << EOF
Stealth Reconnaissance Report
Generated: $(date)
Target: $target

Scan Configuration:
- Timing: T1-T2 (Slow/Sneaky)
- Fragmentation: Enabled
- Decoys: 10 random IPs
- Data padding: 25 bytes

Results:
- Open ports: $(grep "open" "$output/01_syn_scan.nmap" | wc -l)
- Services identified: $(grep "open" "$output/02_services.nmap" | wc -l)
- OS detected: $(grep "OS:" "$output/03_os_detect.nmap" | head -1)

Detailed results in:
- 01_syn_scan.nmap
- 02_services.nmap
- 03_os_detect.nmap
- 04_scripts.nmap
EOF
    
    log_success "Stealth reconnaissance complete!"
    log_info "Results saved to: $output"
    echo ""
    cat "$output/report.txt"
    echo ""
    read -p "Press Enter to continue..."
}

################################################################################
# SCENARIO 5: Quick Assessment - Fast Security Check
################################################################################
scenario_quick_assessment() {
    print_banner
    log_info "SCENARIO 5: Quick Security Assessment"
    echo ""
    log_info "This scenario will:"
    echo "  1. Rapid host discovery"
    echo "  2. Top 1000 ports scan"
    echo "  3. Quick vulnerability check"
    echo "  4. Generate summary report"
    echo ""
    
    # Auto-detect network
    local network=$(ip route | grep default | awk '{print $3}' | sed 's/\.[0-9]*$/\.0\/24/')
    
    log_info "Detected network: $network"
    read -p "Use this network? (y/n): " confirm
    
    if [[ "$confirm" != "y" ]]; then
        read -p "Enter network (e.g., 192.168.1.0/24): " network
    fi
    
    local output="$OUTPUT_DIR/quick_assessment_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$output"
    
    log_info "Starting quick assessment..."
    
    # Fast host discovery
    log_info "[1/3] Discovering hosts..."
    nmap -sn -T4 "$network" -oA "$output/01_hosts"
    
    local hosts=$(grep "Up" "$output/01_hosts.gnmap" | awk '{print $2}')
    local host_count=$(echo "$hosts" | wc -l)
    
    log_success "Found $host_count hosts"
    
    # Top ports scan
    log_info "[2/3] Scanning top 1000 ports..."
    nmap -sV -T4 --top-ports 1000 $hosts -oA "$output/02_ports"
    
    # Quick vuln check
    log_info "[3/3] Quick vulnerability check..."
    nmap --script vuln -T4 $hosts -oA "$output/03_vulns"
    
    # Generate report
    log_info "Generating report..."
    
    local open_ports=$(grep "open" "$output/02_ports.nmap" | wc -l)
    local vulns=$(grep "VULNERABLE" "$output/03_vulns.nmap" | wc -l)
    
    cat > "$output/report.txt" << EOF
Quick Security Assessment Report
Generated: $(date)
Network: $network

SUMMARY
=======
Hosts discovered: $host_count
Open ports: $open_ports
Vulnerabilities: $vulns

RISK ASSESSMENT
===============
$(if [ $vulns -gt 10 ]; then echo "HIGH RISK - Multiple vulnerabilities detected"; 
   elif [ $vulns -gt 5 ]; then echo "MEDIUM RISK - Several vulnerabilities found";
   elif [ $vulns -gt 0 ]; then echo "LOW RISK - Few vulnerabilities detected";
   else echo "MINIMAL RISK - No obvious vulnerabilities"; fi)

LIVE HOSTS
==========
$hosts

RECOMMENDATIONS
===============
1. Review all open ports in 02_ports.nmap
2. Investigate vulnerabilities in 03_vulns.nmap
3. Close unnecessary services
4. Update vulnerable software
5. Implement network segmentation

Detailed results in:
- 01_hosts.nmap
- 02_ports.nmap
- 03_vulns.nmap
EOF
    
    log_success "Quick assessment complete!"
    log_info "Results saved to: $output"
    echo ""
    cat "$output/report.txt"
    echo ""
    read -p "Press Enter to continue..."
}

################################################################################
# Main Menu
################################################################################
show_menu() {
    print_banner
    
    echo -e "${YELLOW}Select Attack Scenario:${NC}"
    echo ""
    echo -e "  ${CYAN}[1]${NC} WiFi Audit"
    echo -e "      Complete WiFi network assessment"
    echo ""
    echo -e "  ${CYAN}[2]${NC} Network Sweep"
    echo -e "      Full network discovery and scanning"
    echo ""
    echo -e "  ${CYAN}[3]${NC} Web Application Hunt"
    echo -e "      Find and enumerate web services"
    echo ""
    echo -e "  ${CYAN}[4]${NC} Stealth Reconnaissance"
    echo -e "      Low-profile intelligence gathering"
    echo ""
    echo -e "  ${CYAN}[5]${NC} Quick Assessment"
    echo -e "      Fast security check (5-10 min)"
    echo ""
    echo -e "  ${CYAN}[6]${NC} View Results"
    echo -e "      Browse previous scenario results"
    echo ""
    echo -e "  ${CYAN}[0]${NC} Exit"
    echo ""
}

# View results
view_results() {
    print_banner
    log_info "Previous Scenario Results:"
    echo ""
    
    if [ ! -d "$OUTPUT_DIR" ] || [ -z "$(ls -A $OUTPUT_DIR 2>/dev/null)" ]; then
        log_warning "No results found"
        echo ""
        read -p "Press Enter to continue..."
        return
    fi
    
    ls -lht "$OUTPUT_DIR" | grep "^d" | head -10
    echo ""
    read -p "Enter directory name to view (or press Enter to skip): " dir
    
    if [[ -n "$dir" ]] && [[ -d "$OUTPUT_DIR/$dir" ]]; then
        echo ""
        log_info "Contents of $dir:"
        echo ""
        ls -lh "$OUTPUT_DIR/$dir"
        echo ""
        
        if [[ -f "$OUTPUT_DIR/$dir/report.txt" ]]; then
            echo ""
            log_info "Report:"
            echo ""
            cat "$OUTPUT_DIR/$dir/report.txt"
        fi
    fi
    
    echo ""
    read -p "Press Enter to continue..."
}

# Main loop
main() {
    check_root
    
    while true; do
        show_menu
        read -p "$(echo -e ${GREEN}Select option [0-6]: ${NC})" choice
        
        case $choice in
            1) scenario_wifi_audit ;;
            2) scenario_network_sweep ;;
            3) scenario_web_hunt ;;
            4) scenario_stealth_recon ;;
            5) scenario_quick_assessment ;;
            6) view_results ;;
            0) 
                log_info "Exiting..."
                exit 0
                ;;
            *)
                log_error "Invalid option"
                sleep 1
                ;;
        esac
    done
}

main
