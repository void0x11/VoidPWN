#!/bin/bash

################################################################################
# VoidPWN - Interactive Main Menu
# Description: Main interface for VoidPWN pentesting device
# Author: void0x11
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
    by void0x11
EOF
    echo -e "${NC}"
    echo ""
}

# System info
show_system_info() {
    local ip=$(hostname -I | awk '{print $1}')
    local uptime=$(uptime -p | sed 's/up //')
    local temp=$(vcgencmd measure_temp 2>/dev/null | cut -d= -f2 || echo "N/A")
    
    echo -e "${BLUE}[System Info]${NC}"
    echo -e "  IP Address: ${GREEN}$ip${NC}"
    echo -e "  Uptime: ${GREEN}$uptime${NC}"
    echo -e "  Temperature: ${GREEN}$temp${NC}"
    
    # Check WiFi adapter
    if iwconfig 2>/dev/null | grep -q "wlan1"; then
        echo -e "  WiFi Adapter: ${GREEN}✓ Connected${NC}"
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
            3) sudo "$SCRIPT_DIR/scripts/network/wifi_tools.sh" --auto-attack ;;
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
                john "$hashfile" --wordlist=/usr/share/wordlists/rockyou.txt
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
        echo -e "  ${CYAN}[4]${NC} Bettercap"
        echo -e "  ${CYAN}[0]${NC} Back"
        echo ""
        read -p "$(echo -e ${GREEN}Select option: ${NC})" choice
        
        case $choice in
            1) msfconsole ;;
            2)
                read -p "Target URL: " url
                sqlmap -u "$url" --batch
                ;;
            3) sudo responder -I eth0 ;;
            4) sudo bettercap ;;
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
            1) neofetch || screenfetch || uname -a ;;
            2) ip a ;;
            3) df -h ;;
            4) htop ;;
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
                sudo python3 "$SCRIPT_DIR/scripts/python/smart_scan.py" "$target"
                ;;
            2) 
                echo -e "${YELLOW}Press Ctrl+C to stop${NC}"
                sudo python3 "$SCRIPT_DIR/scripts/python/packet_visualizer.py"
                ;;
            3)
                ifconfig | grep -q "monitor"
                if [ $? -ne 0 ]; then
                    read -p "Monitor interface (e.g., wlan1mon): " iface
                else
                    iface=$(iw dev | grep Interface | grep mon | awk '{print $2}' | head -1)
                fi
                echo -e "${YELLOW}Press Ctrl+C to stop${NC}"
                sudo python3 "$SCRIPT_DIR/scripts/python/wifi_monitor.py" "$iface"
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
    ls -lh "$HOME/VoidPWN/captures/" 2>/dev/null || echo "  No captures found"
    echo ""
    
    echo -e "${CYAN}Recon Results:${NC}"
    ls -lh "$HOME/VoidPWN/recon/" 2>/dev/null || echo "  No results found"
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
    local tools=("nmap" "aircrack-ng" "wifite" "python3" "iwconfig")
    local missing=0
    for tool in "${tools[@]}"; do
        if command -v $tool &> /dev/null; then
             echo -e "  [${GREEN}OK${NC}] $tool"
        else
             echo -e "  [${RED}FAIL${NC}] $tool not found"
             missing=1
        fi
    done

    # 2. Interface Check
    echo ""
    echo -e "${CYAN}[*] Checking Network Interfaces...${NC}"
    if iwconfig 2>/dev/null | grep -q "monitor"; then
         echo -e "  [${YELLOW}WARN${NC}] One or more interfaces in Monitor Mode"
    fi

    # Check for external adapter (heuristic: often wlan1)
    if iwconfig 2>/dev/null | grep -q "wlan1"; then
         echo -e "  [${GREEN}OK${NC}] External Adapter (wlan1) detected"
    elif iwconfig 2>/dev/null | grep -q "wlan0"; then
         echo -e "  [${YELLOW}INFO${NC}] Only internal WiFi (wlan0) detected"
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
