#!/bin/bash

################################################################################
# VoidPWN - Interactive Main Menu
# Description: Main interface for VoidPWN pentesting device
# Usage: ./voidpwn.sh
################################################################################

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Banner
print_banner() {
    clear
    echo -e "${CYAN}"
    cat << "EOF"
    ╦  ╦┌─┐┬┌┬┐╔═╗╦ ╦╔╗╔
    ╚╗╔╝│ │││ ││╠═╝║║║║║║
     ╚╝ └─┘┴└─┘┴╩  ╚╩╝╝╚╝
    ═══════════════════════
    Portable Pentesting Device
EOF
    echo -e "${NC}"
    echo ""
}

# System info
show_system_info() {
    local ip
    ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    local uptime
    uptime=$(uptime -p 2>/dev/null | sed 's/up //' || echo "N/A")
    local temp
    if [[ -f /sys/class/thermal/thermal_zone0/temp ]]; then
        temp=$(awk '{printf "%.1f'\''C", $1/1000}' /sys/class/thermal/thermal_zone0/temp)
    else
        temp=$(vcgencmd measure_temp 2>/dev/null | cut -d= -f2 || echo "N/A")
    fi
    
    echo -e "${BLUE}[System Info]${NC}"
    echo -e "  IP Address: ${GREEN}${ip:-N/A}${NC}"
    echo -e "  Uptime: ${GREEN}${uptime}${NC}"
    echo -e "  Temperature: ${GREEN}${temp}${NC}"
    
    # Check WiFi adapter using iw (works with any naming convention)
    local wifi_iface
    wifi_iface=$(iw dev 2>/dev/null | awk '/Interface/{print $2}' | head -n 1)
    if [[ -n "$wifi_iface" ]]; then
        echo -e "  WiFi Adapter: ${GREEN}✓ $wifi_iface${NC}"
    else
        echo -e "  WiFi Adapter: ${RED}✗ Not detected${NC}"
    fi
    
    echo ""
}

# Main menu
show_menu() {
    echo -e "${YELLOW}╔════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║         MAIN MENU                  ║${NC}"
    echo -e "${YELLOW}╚════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${CYAN}[1]${NC} Auto Scenarios"
    echo -e "  ${CYAN}[2]${NC} Python Tools"
    echo -e "  ${CYAN}[3]${NC} WiFi Tools"
    echo -e "  ${CYAN}[4]${NC} Network Reconnaissance"
    echo -e "  ${CYAN}[5]${NC} Password Attacks"
    echo -e "  ${CYAN}[6]${NC} Exploitation Tools"
    echo -e "  ${CYAN}[7]${NC} System Tools"
    echo -e "  ${CYAN}[8]${NC} View Captures"
    echo -e "  ${CYAN}[9]${NC} Web Dashboard"
    echo -e "  ${CYAN}[T]${NC} Run Diagnostics"
    echo -e "  ${CYAN}[0]${NC} Exit"
    echo ""
}

# WiFi menu
wifi_menu() {
    while true; do
        print_banner
        echo -e "${YELLOW}╔════════════════════════════════════╗${NC}"
        echo -e "${YELLOW}║         WiFi Tools                 ║${NC}"
        echo -e "${YELLOW}╚════════════════════════════════════╝${NC}"
        echo ""
        echo -e "  ${CYAN}[1]${NC} Scan Networks"
        echo -e "  ${CYAN}[2]${NC} Capture Handshake"
        echo -e "  ${CYAN}[3]${NC} Automated Attack (Wifite)"
        echo -e "  ${CYAN}[4]${NC} Deauth Attack"
        echo -e "  ${CYAN}[5]${NC} Crack Handshake"
        echo -e "  ${CYAN}[6]${NC} Monitor Mode ON"
        echo -e "  ${CYAN}[7]${NC} Monitor Mode OFF"
        echo -e "  ${CYAN}[0]${NC} Back"
        echo ""
        read -p "$(echo -e ${GREEN}Select option: ${NC})" choice
        
        case $choice in
            1) sudo "$SCRIPT_DIR/scripts/network/wifi_tools.sh" --scan ;;
            2) 
                read -p "BSSID: " bssid
                read -p "Channel: " channel
                sudo "$SCRIPT_DIR/scripts/network/wifi_tools.sh" --handshake "$bssid" "$channel"
                ;;
            3)
                if ! iwconfig 2>/dev/null | grep -qE "^wlan[0-9]"; then
                    log_error "No WiFi adapter detected. Connect an adapter and try again."
                else
                    sudo "$SCRIPT_DIR/scripts/network/wifi_tools.sh" --auto-attack
                fi
                ;;
            4)
                read -p "BSSID: " bssid
                read -p "Count (0=continuous): " count
                sudo "$SCRIPT_DIR/scripts/network/wifi_tools.sh" --deauth "$bssid" "$count"
                ;;
            5)
                read -p "Capture file path: " capfile
                sudo "$SCRIPT_DIR/scripts/network/wifi_tools.sh" --crack "$capfile"
                ;;
            6) sudo "$SCRIPT_DIR/scripts/network/wifi_tools.sh" --monitor-on ;;
            7) sudo "$SCRIPT_DIR/scripts/network/wifi_tools.sh" --monitor-off ;;
            0) break ;;
            *) echo -e "${RED}Invalid option${NC}" ;;
        esac
        
        echo ""
        read -p "Press Enter to continue..."
    done
}

# Recon menu
recon_menu() {
    while true; do
        print_banner
        echo -e "${YELLOW}╔════════════════════════════════════╗${NC}"
        echo -e "${YELLOW}║    Network Reconnaissance          ║${NC}"
        echo -e "${YELLOW}╚════════════════════════════════════╝${NC}"
        echo ""
        echo -e "  ${CYAN}[1]${NC} Quick Scan"
        echo -e "  ${CYAN}[2]${NC} Full Port Scan"
        echo -e "  ${CYAN}[3]${NC} Stealth Scan"
        echo -e "  ${CYAN}[4]${NC} Vulnerability Scan"
        echo -e "  ${CYAN}[5]${NC} Web Enumeration"
        echo -e "  ${CYAN}[6]${NC} SMB Enumeration"
        echo -e "  ${CYAN}[7]${NC} DNS Enumeration"
        echo -e "  ${CYAN}[8]${NC} Network Discovery"
        echo -e "  ${CYAN}[9]${NC} Comprehensive Scan"
        echo -e "  ${CYAN}[0]${NC} Back"
        echo ""
        read -p "$(echo -e ${GREEN}Select option: ${NC})" choice
        
        case $choice in
            1)
                read -p "Target (IP/CIDR): " target
                sudo "$SCRIPT_DIR/scripts/network/recon.sh" --quick "$target"
                ;;
            2)
                read -p "Target IP: " target
                sudo "$SCRIPT_DIR/scripts/network/recon.sh" --full "$target"
                ;;
            3)
                read -p "Target IP: " target
                sudo "$SCRIPT_DIR/scripts/network/recon.sh" --stealth "$target"
                ;;
            4)
                read -p "Target IP: " target
                sudo "$SCRIPT_DIR/scripts/network/recon.sh" --vuln "$target"
                ;;
            5)
                read -p "Target URL: " target
                sudo "$SCRIPT_DIR/scripts/network/recon.sh" --web "$target"
                ;;
            6)
                read -p "Target IP: " target
                sudo "$SCRIPT_DIR/scripts/network/recon.sh" --smb "$target"
                ;;
            7)
                read -p "Domain: " domain
                sudo "$SCRIPT_DIR/scripts/network/recon.sh" --dns "$domain"
                ;;
            8) sudo "$SCRIPT_DIR/scripts/network/recon.sh" --discover ;;
            9)
                read -p "Target IP: " target
                sudo "$SCRIPT_DIR/scripts/network/recon.sh" --comprehensive "$target"
                ;;
            0) break ;;
            *) echo -e "${RED}Invalid option${NC}" ;;
        esac
        
        echo ""
        read -p "Press Enter to continue..."
    done
}

# Password attacks menu
password_menu() {
    while true; do
        print_banner
        echo -e "${YELLOW}╔════════════════════════════════════╗${NC}"
        echo -e "${YELLOW}║       Password Attacks             ║${NC}"
        echo -e "${YELLOW}╚════════════════════════════════════╝${NC}"
        echo ""
        echo -e "  ${CYAN}[1]${NC} Hydra - SSH Brute Force"
        echo -e "  ${CYAN}[2]${NC} Hydra - FTP Brute Force"
        echo -e "  ${CYAN}[3]${NC} Hydra - HTTP Form"
        echo -e "  ${CYAN}[4]${NC} John the Ripper"
        echo -e "  ${CYAN}[5]${NC} Hashcat"
        echo -e "  ${CYAN}[0]${NC} Back"
        echo ""
        read -p "$(echo -e ${GREEN}Select option: ${NC})" choice
        
        case $choice in
            1)
                read -p "Target IP: " target
                read -p "Username: " user
                read -p "Wordlist: " wordlist
                hydra -l "$user" -P "$wordlist" ssh://"$target"
                ;;
            2)
                read -p "Target IP: " target
                read -p "Username: " user
                read -p "Wordlist: " wordlist
                hydra -l "$user" -P "$wordlist" ftp://"$target"
                ;;
            3)
                echo "Example: hydra -l admin -P wordlist.txt target.com http-post-form '/login:user=^USER^&pass=^PASS^:F=incorrect'"
                read -p "Press Enter to continue..."
                ;;
            4)
                read -p "Hash file: " hashfile
                ROCKYOU="/usr/share/wordlists/rockyou.txt"
                if [[ ! -f "$ROCKYOU" ]] && [[ -f "${ROCKYOU}.gz" ]]; then
                    log_warning "rockyou.txt not found. Decompressing..."
                    gunzip -k "${ROCKYOU}.gz"
                fi
                if [[ ! -f "$ROCKYOU" ]]; then
                    log_error "rockyou.txt not found. Run: gunzip /usr/share/wordlists/rockyou.txt.gz"
                else
                    john "$hashfile" --wordlist="$ROCKYOU"
                fi
                ;;
            5)
                echo "Hashcat example: hashcat -m 0 -a 0 hashes.txt wordlist.txt"
                read -p "Press Enter to continue..."
                ;;
            0) break ;;
            *) echo -e "${RED}Invalid option${NC}" ;;
        esac
        
        echo ""
        read -p "Press Enter to continue..."
    done
}

# Exploitation menu
exploit_menu() {
    while true; do
        print_banner
        echo -e "${YELLOW}╔════════════════════════════════════╗${NC}"
        echo -e "${YELLOW}║      Exploitation Tools            ║${NC}"
        echo -e "${YELLOW}╚════════════════════════════════════╝${NC}"
        echo ""
        echo -e "  ${CYAN}[1]${NC} Metasploit Framework"
        echo -e "  ${CYAN}[2]${NC} SQLMap"
        echo -e "  ${CYAN}[3]${NC} Responder"
        echo -e "  ${CYAN}[4]${NC} Bettercap (Interactive)"
        echo -e "  ${CYAN}[5]${NC} MITM Toolkit"
        echo -e "  ${CYAN}[0]${NC} Back"
        echo ""
        read -p "$(echo -e ${GREEN}Select option: ${NC})" choice
        
        case $choice in
            1) msfconsole ;;
            2)
                read -p "Target URL: " url
                sqlmap -u "$url" --batch
                ;;
            3) 
                local eth_iface
                eth_iface=$(ip route 2>/dev/null | awk '/default/{print $5; exit}')
                [[ -z "$eth_iface" ]] && eth_iface=$(ip link show 2>/dev/null | awk -F': ' '/^[0-9]+: e/{print $2; exit}')
                [[ -z "$eth_iface" ]] && eth_iface="eth0"
                sudo responder -I "$eth_iface" ;;
            4) sudo bettercap ;;
            5) mitm_menu ;;
            0) break ;;
            *) echo -e "${RED}Invalid option${NC}" ;;
        esac
        
        echo ""
        read -p "Press Enter to continue..."
    done
}

# MITM & Credential Intercept menu
mitm_menu() {
    local MITM_SCRIPT="$SCRIPT_DIR/scripts/network/mitm_tools.sh"
    if [[ ! -f "$MITM_SCRIPT" ]]; then
        log_error "mitm_tools.sh not found at $MITM_SCRIPT"
        return 1
    fi

    while true; do
        print_banner
        echo -e "${RED}╔════════════════════════════════════╗${NC}"
        echo -e "${RED}║    MITM & Credential Intercept     ║${NC}"
        echo -e "${RED}╚════════════════════════════════════╝${NC}"
        echo ""
        echo -e "  ${CYAN}[1]${NC} Bettercap MITM       ${RED}(ARP poison + sniff)${NC}"
        echo -e "  ${CYAN}[2]${NC} SSL Strip             ${RED}(downgrade HTTPS → HTTP)${NC}"
        echo -e "  ${CYAN}[3]${NC} DNS Spoof             ${RED}(redirect any domain)${NC}"
        echo -e "  ${CYAN}[4]${NC} KARMA Rogue AP        ${RED}(respond to all SSID probes)${NC}"
        echo -e "  ${CYAN}[5]${NC} WPA Enterprise AP     ${RED}(harvest domain creds)${NC}"
        echo -e "  ${CYAN}[6]${NC} Analyze Captures      ${RED}(PCredz: extract creds from .cap)${NC}"
        echo -e "  ${CYAN}[0]${NC} Back"
        echo ""
        read -p "$(echo -e ${GREEN}Select option: ${NC})" choice

        case $choice in
            1)
                read -p "Interface (leave blank = auto): " mitm_iface
                read -p "Target IP (leave blank = full subnet): " mitm_target
                local mitm_args="--bettercap"
                [[ -n "$mitm_iface" ]]  && mitm_args+=" --interface $mitm_iface"
                [[ -n "$mitm_target" ]] && mitm_args+=" --target $mitm_target"
                sudo "$MITM_SCRIPT" $mitm_args
                ;;
            2)
                read -p "Interface (leave blank = auto): " mitm_iface
                read -p "Target IP (leave blank = full subnet): " mitm_target
                local ssl_args="--sslstrip"
                [[ -n "$mitm_iface" ]]  && ssl_args+=" --interface $mitm_iface"
                [[ -n "$mitm_target" ]] && ssl_args+=" --target $mitm_target"
                sudo "$MITM_SCRIPT" $ssl_args
                ;;
            3)
                read -p "Interface (leave blank = auto): " mitm_iface
                read -p "Domain to spoof (e.g. google.com): " dns_domain
                read -p "Redirect to IP: " dns_redir
                if [[ -z "$dns_domain" || -z "$dns_redir" ]]; then
                    log_error "Domain and redirect IP are required"
                else
                    local dns_args="--dnsspoof --domain $dns_domain --redirect $dns_redir"
                    [[ -n "$mitm_iface" ]] && dns_args+=" --interface $mitm_iface"
                    sudo "$MITM_SCRIPT" $dns_args
                fi
                ;;
            4)
                read -p "Interface (leave blank = auto): " mitm_iface
                local karma_args="--karma"
                [[ -n "$mitm_iface" ]] && karma_args+=" --interface $mitm_iface"
                sudo "$MITM_SCRIPT" $karma_args
                ;;
            5)
                read -p "Interface (leave blank = auto): " mitm_iface
                read -p "SSID to broadcast (default: Corporate-WiFi): " ent_ssid
                ent_ssid="${ent_ssid:-Corporate-WiFi}"
                local ent_args="--eaphammer --ssid \"$ent_ssid\""
                [[ -n "$mitm_iface" ]] && ent_args+=" --interface $mitm_iface"
                sudo "$MITM_SCRIPT" $ent_args
                ;;
            6)
                read -p "Capture file path (leave blank = use latest): " cap_path
                local pcredz_args="--pcredz"
                [[ -n "$cap_path" ]] && pcredz_args+=" --file \"$cap_path\""
                sudo "$MITM_SCRIPT" $pcredz_args
                ;;
            0) break ;;
            *) echo -e "${RED}Invalid option${NC}" ;;
        esac

        echo ""
        read -p "Press Enter to continue..."
    done
}

# System tools menu
system_menu() {
    while true; do
        print_banner
        echo -e "${YELLOW}╔════════════════════════════════════╗${NC}"
        echo -e "${YELLOW}║        System Tools                ║${NC}"
        echo -e "${YELLOW}╚════════════════════════════════════╝${NC}"
        echo ""
        echo -e "  ${CYAN}[1]${NC} System Information"
        echo -e "  ${CYAN}[2]${NC} Network Interfaces"
        echo -e "  ${CYAN}[3]${NC} Disk Usage"
        echo -e "  ${CYAN}[4]${NC} Running Processes"
        echo -e "  ${CYAN}[5]${NC} Update System"
        echo -e "  ${CYAN}[6]${NC} Reboot"
        echo -e "  ${CYAN}[7]${NC} Shutdown"
        echo -e "  ${CYAN}[0]${NC} Back"
        echo ""
        read -p "$(echo -e ${GREEN}Select option: ${NC})" choice
        
        case $choice in
            1) neofetch 2>/dev/null || screenfetch 2>/dev/null || uname -a ;;
            2) ip a ;;
            3) df -h ;;
            4) htop 2>/dev/null || top ;;
            5) sudo apt update && sudo apt upgrade -y ;;
            6)
                read -p "Reboot now? (y/n): " confirm
                [[ "$confirm" == "y" ]] && sudo reboot
                ;;
            7)
                read -p "Shutdown now? (y/n): " confirm
                [[ "$confirm" == "y" ]] && sudo shutdown now
                ;;
            0) break ;;
            *) echo -e "${RED}Invalid option${NC}" ;;
        esac
        
        echo ""
        read -p "Press Enter to continue..."
    done
}

# Python Tools menu
python_menu() {
    while true; do
        print_banner
        echo -e "${YELLOW}╔════════════════════════════════════╗${NC}"
        echo -e "${YELLOW}║        PYTHON TOOLS                ║${NC}"
        echo -e "${YELLOW}╚════════════════════════════════════╝${NC}"
        echo ""
        echo -e "  ${CYAN}[1]${NC} Smart Scan"
        echo -e "      Intelligent automated enumeration"
        echo ""
        echo -e "  ${CYAN}[2]${NC} Packet Visualizer"
        echo -e "      Matrix-style traffic display"
        echo ""
        echo -e "  ${CYAN}[3]${NC} WiFi Monitor"
        echo -e "      Track devices nearby"
        echo ""
        echo -e "  ${CYAN}[4]${NC} WiFi Speed Limiter"
        echo -e "      Throttle bandwidth of devices"
        echo ""
        echo -e "  ${CYAN}[0]${NC} Back"
        echo ""
        read -p "$(echo -e ${GREEN}Select option: ${NC})" choice
        
        case $choice in
            1) 
                read -p "Enter target IP: " target
                if [[ ! -f "$SCRIPT_DIR/scripts/python/smart_scan.py" ]]; then
                    log_error "smart_scan.py not found in $SCRIPT_DIR/scripts/python/"
                else
                    sudo python3 "$SCRIPT_DIR/scripts/python/smart_scan.py" "$target"
                fi
                ;;
            2) 
                echo -e "${YELLOW}Press Ctrl+C to stop${NC}"
                if [[ ! -f "$SCRIPT_DIR/scripts/python/packet_visualizer.py" ]]; then
                    log_error "packet_visualizer.py not found in $SCRIPT_DIR/scripts/python/"
                else
                    sudo python3 "$SCRIPT_DIR/scripts/python/packet_visualizer.py"
                fi
                ;;
            3)
                local iface
                iface=$(iw dev 2>/dev/null | awk '/type monitor/{f=NR} f && /Interface/{print $2; f=0}' | head -1)
                if [[ -z "$iface" ]]; then
                    read -p "Monitor interface (e.g., wlan1mon): " iface
                fi
                echo -e "${YELLOW}Press Ctrl+C to stop${NC}"
                if [[ ! -f "$SCRIPT_DIR/scripts/python/wifi_monitor.py" ]]; then
                    log_error "wifi_monitor.py not found in $SCRIPT_DIR/scripts/python/"
                else
                    sudo python3 "$SCRIPT_DIR/scripts/python/wifi_monitor.py" "$iface"
                fi
                ;;
            4)
                 sudo "$SCRIPT_DIR/scripts/network/wifi_throttle.sh"
                 ;;
            0) break ;;
            *) echo -e "${RED}Invalid option${NC}" ;;
        esac
        
        echo ""
        read -p "Press Enter to continue..."
    done
}

# Dashboard menu
dashboard_menu() {
    while true; do
        print_banner
        echo -e "${YELLOW}╔════════════════════════════════════╗${NC}"
        echo -e "${YELLOW}║        Web Dashboard               ║${NC}"
        echo -e "${YELLOW}╚════════════════════════════════════╝${NC}"
        echo ""
        echo -e "  ${CYAN}[1]${NC} Start Dashboard"
        echo -e "  ${CYAN}[2]${NC} Stop Dashboard"
        echo -e "  ${CYAN}[3]${NC} Dashboard Status"
        echo -e "  ${CYAN}[4]${NC} Open in Browser"
        echo -e "  ${CYAN}[0]${NC} Back"
        echo ""
        read -p "$(echo -e ${GREEN}Select option: ${NC})" choice
        
        case $choice in
            1) 
                "$SCRIPT_DIR/scripts/core/dashboard.sh" start
                ;;
            2) 
                "$SCRIPT_DIR/scripts/core/dashboard.sh" stop
                ;;
            3) 
                "$SCRIPT_DIR/scripts/core/dashboard.sh" status
                ;;
            4)
                IP=$(hostname -I | awk '{print $1}')
                echo ""
                echo -e "${CYAN}Dashboard URL:${NC}"
                echo "  http://$IP:5000"
                echo ""
                echo "Open this URL in a browser on any device"
                ;;
            0) break ;;
            *) echo -e "${RED}Invalid option${NC}" ;;
        esac
        
        echo ""
        read -p "Press Enter to continue..."
    done
}

# View captures
view_captures() {
    print_banner
    echo -e "${YELLOW}╔════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║         Saved Captures             ║${NC}"
    echo -e "${YELLOW}╚════════════════════════════════════╝${NC}"
    echo ""
    
    echo -e "${CYAN}WiFi Captures:${NC}"
    ls -lh "$SCRIPT_DIR/output/captures/" 2>/dev/null || echo "  No captures found"
    echo ""
    
    echo -e "${CYAN}Recon Results:${NC}"
    ls -lh "$SCRIPT_DIR/output/recon/" 2>/dev/null || echo "  No results found"
    echo ""
    
    read -p "Press Enter to continue..."
}

# System Diagnostics
run_diagnostics() {
    print_banner
    echo -e "${YELLOW}╔════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║        System Diagnostics          ║${NC}"
    echo -e "${YELLOW}╚════════════════════════════════════╝${NC}"
    echo ""

    # 1. Dependency Check
    echo -e "${CYAN}[*] Checking Dependencies...${NC}"
    local tools=("nmap" "aircrack-ng" "wifite" "python3" "iwconfig" "bettercap")
    local missing=0
    for tool in "${tools[@]}"; do
        if command -v $tool &> /dev/null; then
             echo -e "  [${GREEN}OK${NC}] $tool"
        else
             echo -e "  [${RED}FAIL${NC}] $tool not found"
             missing=1
        fi
    done

    # MITM Toolkit dependencies
    echo ""
    echo -e "${CYAN}[*] Checking MITM Toolkit...${NC}"
    if [[ -d /opt/eaphammer ]]; then
        echo -e "  [${GREEN}OK${NC}] eaphammer found at /opt/eaphammer"
    else
        echo -e "  [${YELLOW}WARN${NC}] eaphammer not found (run build_voidpwn.sh to install)"
    fi
    if [[ -d /opt/pcredz ]]; then
        echo -e "  [${GREEN}OK${NC}] PCredz found at /opt/pcredz"
    else
        echo -e "  [${YELLOW}WARN${NC}] PCredz not found (run build_voidpwn.sh to install)"
    fi

    # 2. Interface Check
    echo ""
    echo -e "${CYAN}[*] Checking Network Interfaces...${NC}"
    if iw dev 2>/dev/null | awk '/type/{print}' | grep -q monitor; then
         echo -e "  [${YELLOW}WARN${NC}] One or more interfaces in Monitor Mode"
    fi

    # Show all detected wireless interfaces
    local wifi_ifaces
    wifi_ifaces=$(iw dev 2>/dev/null | awk '/Interface/{print $2}')
    if [[ -n "$wifi_ifaces" ]]; then
        local count
        count=$(echo "$wifi_ifaces" | wc -l)
        echo -e "  [${GREEN}OK${NC}] $count wireless interface(s) detected: $(echo $wifi_ifaces | tr '\n' ' ')"
    else
        echo -e "  [${RED}FAIL${NC}] No wireless interfaces found!"
    fi

    # 3. Service Status
    echo ""
    echo -e "${CYAN}[*] Checking Services...${NC}"
    if systemctl is-active --quiet voidpwn.service; then
         echo -e "  [${GREEN}OK${NC}] Dashboard Service (voidpwn.service) is RUNNING"
         echo -e "       URL: http://$(hostname -I | awk '{print $1}'):5000"
    else
         echo -e "  [${RED}FAIL${NC}] Dashboard Service is STOPPED"
         echo -e "       Try: sudo systemctl start voidpwn.service"
    fi

    # 4. Connectivity
    echo ""
    echo -e "${CYAN}[*] Checking Internet...${NC}"
    if ping -c 1 8.8.8.8 &> /dev/null; then
         echo -e "  [${GREEN}OK${NC}] Internet Connected"
    else
         echo -e "  [${RED}FAIL${NC}] No Internet Connection"
    fi
    
    echo ""
    echo -e "${MAGENTA}Diagnostics Complete.${NC}"
    echo ""
    read -p "Press Enter to return to menu..."
}

# Main loop
main() {
    while true; do
        print_banner
        show_system_info
        show_menu
        
        read -p "$(echo -e ${GREEN}Select option: ${NC})" choice
        
        case $choice in
            1) sudo "$SCRIPT_DIR/scripts/network/scenarios.sh" ;;
            2) python_menu ;;
            3) wifi_menu ;;
            4) recon_menu ;;
            5) password_menu ;;
            6) exploit_menu ;;
            7) system_menu ;;
            8) view_captures ;;
            9) dashboard_menu ;;
            t|T) run_diagnostics ;;
            0) 
                echo -e "${CYAN}Exiting VoidPWN...${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid option${NC}"
                sleep 1
                ;;
        esac
    done
}

main
