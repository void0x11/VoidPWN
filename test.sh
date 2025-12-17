#!/bin/bash

################################################################################
# VoidPWN - System Test Script
# Description: Comprehensive testing of all VoidPWN components
# Author: void0x11
# Usage: sudo ./test.sh
################################################################################

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Test results
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_WARNING=0
ISSUES=()

# Output file
REPORT_FILE="$HOME/VoidPWN/test_report_$(date +%Y%m%d_%H%M%S).txt"

log_info() { echo -e "${BLUE}[TEST]${NC} $1"; }
log_pass() { 
    echo -e "${GREEN}[PASS]${NC} $1"
    ((TESTS_PASSED++))
}
log_fail() { 
    echo -e "${RED}[FAIL]${NC} $1"
    ((TESTS_FAILED++))
    ISSUES+=("FAIL: $1")
}
log_warn() { 
    echo -e "${YELLOW}[WARN]${NC} $1"
    ((TESTS_WARNING++))
    ISSUES+=("WARN: $1")
}

# Banner
print_banner() {
    clear
    echo -e "${CYAN}"
    cat << "EOF"
    ╔═══════════════════════════════════╗
    ║     VOIDPWN SYSTEM TEST           ║
    ╚═══════════════════════════════════╝
EOF
    echo -e "${NC}"
    echo ""
}

# Start report
start_report() {
    cat > "$REPORT_FILE" << EOF
VoidPWN System Test Report
Generated: $(date)
Hostname: $(hostname)
IP Address: $(hostname -I | awk '{print $1}')
Kernel: $(uname -r)

================================================================================
TEST RESULTS
================================================================================

EOF
}

# Check if running as root
check_root() {
    log_info "Checking root privileges..."
    if [[ $EUID -ne 0 ]]; then
        log_fail "Not running as root (use sudo)"
        return 1
    else
        log_pass "Running as root"
        return 0
    fi
}

################################################################################
# Test 1: File Structure
################################################################################
test_file_structure() {
    echo ""
    log_info "=== Testing File Structure ==="
    
    local files=(
        "setup.sh"
        "wifi_tools.sh"
        "recon.sh"
        "voidpwn.sh"
        "install_lcd.sh"
        "install_tools.sh"
        "dashboard.sh"
        "scenarios.sh"
        "README.md"
        "QUICKSTART.md"
        "DEPLOYMENT.md"
        "LICENSE"
        ".gitignore"
    )
    
    for file in "${files[@]}"; do
        if [[ -f "$HOME/VoidPWN/$file" ]]; then
            log_pass "File exists: $file"
        else
            log_fail "Missing file: $file"
        fi
    done
    
    # Check directories
    local dirs=(
        "dashboard"
        "captures"
        "recon"
        "scenarios"
    )
    
    for dir in "${dirs[@]}"; do
        if [[ -d "$HOME/VoidPWN/$dir" ]]; then
            log_pass "Directory exists: $dir"
        else
            log_warn "Missing directory: $dir (will be created on first use)"
        fi
    done
}

################################################################################
# Test 2: Script Permissions
################################################################################
test_script_permissions() {
    echo ""
    log_info "=== Testing Script Permissions ==="
    
    local scripts=(
        "setup.sh"
        "wifi_tools.sh"
        "recon.sh"
        "voidpwn.sh"
        "install_lcd.sh"
        "install_tools.sh"
        "dashboard.sh"
        "scenarios.sh"
    )
    
    for script in "${scripts[@]}"; do
        if [[ -x "$HOME/VoidPWN/$script" ]]; then
            log_pass "Executable: $script"
        else
            log_fail "Not executable: $script (run: chmod +x $script)"
        fi
    done
}

################################################################################
# Test 3: Script Syntax
################################################################################
test_script_syntax() {
    echo ""
    log_info "=== Testing Script Syntax ==="
    
    local scripts=(
        "setup.sh"
        "wifi_tools.sh"
        "recon.sh"
        "voidpwn.sh"
        "install_lcd.sh"
        "install_tools.sh"
        "dashboard.sh"
        "scenarios.sh"
    )
    
    for script in "${scripts[@]}"; do
        if bash -n "$HOME/VoidPWN/$script" 2>/dev/null; then
            log_pass "Syntax OK: $script"
        else
            log_fail "Syntax error in: $script"
        fi
    done
}

################################################################################
# Test 4: Required Tools
################################################################################
test_required_tools() {
    echo ""
    log_info "=== Testing Required Tools ==="
    
    # WiFi tools
    local wifi_tools=(
        "aircrack-ng"
        "airodump-ng"
        "aireplay-ng"
        "airmon-ng"
        "wifite"
        "bettercap"
        "mdk4"
    )
    
    for tool in "${wifi_tools[@]}"; do
        if command -v "$tool" &> /dev/null; then
            log_pass "WiFi tool installed: $tool"
        else
            log_fail "Missing WiFi tool: $tool"
        fi
    done
    
    # Network tools
    local net_tools=(
        "nmap"
        "masscan"
        "wireshark"
        "tshark"
        "ettercap"
        "arp-scan"
    )
    
    for tool in "${net_tools[@]}"; do
        if command -v "$tool" &> /dev/null; then
            log_pass "Network tool installed: $tool"
        else
            log_fail "Missing network tool: $tool"
        fi
    done
    
    # Password tools
    local pass_tools=(
        "hashcat"
        "john"
        "hydra"
        "medusa"
        "crunch"
    )
    
    for tool in "${pass_tools[@]}"; do
        if command -v "$tool" &> /dev/null; then
            log_pass "Password tool installed: $tool"
        else
            log_fail "Missing password tool: $tool"
        fi
    done
    
    # Exploitation tools
    local exploit_tools=(
        "msfconsole"
        "sqlmap"
        "responder"
    )
    
    for tool in "${exploit_tools[@]}"; do
        if command -v "$tool" &> /dev/null; then
            log_pass "Exploit tool installed: $tool"
        else
            log_fail "Missing exploit tool: $tool"
        fi
    done
    
    # Web tools
    local web_tools=(
        "gobuster"
        "dirb"
        "nikto"
        "wpscan"
        "whatweb"
    )
    
    for tool in "${web_tools[@]}"; do
        if command -v "$tool" &> /dev/null; then
            log_pass "Web tool installed: $tool"
        else
            log_fail "Missing web tool: $tool"
        fi
    done
}

################################################################################
# Test 5: Python Dependencies
################################################################################
test_python_dependencies() {
    echo ""
    log_info "=== Testing Python Dependencies ==="
    
    local python_modules=(
        "flask"
        "psutil"
    )
    
    for module in "${python_modules[@]}"; do
        if python3 -c "import $module" 2>/dev/null; then
            log_pass "Python module installed: $module"
        else
            log_fail "Missing Python module: $module (run: pip3 install $module)"
        fi
    done
}

################################################################################
# Test 6: WiFi Adapter
################################################################################
test_wifi_adapter() {
    echo ""
    log_info "=== Testing WiFi Adapter ==="
    
    # Check for wireless interfaces
    if iwconfig 2>&1 | grep -q "wlan"; then
        log_pass "Wireless interface detected"
        
        # Check for external adapter (wlan1)
        if iwconfig 2>&1 | grep -q "wlan1"; then
            log_pass "External WiFi adapter detected (wlan1)"
        else
            log_warn "External WiFi adapter not detected (wlan1)"
        fi
        
        # Check for monitor mode capability
        if iw list 2>/dev/null | grep -q "monitor"; then
            log_pass "Monitor mode supported"
        else
            log_warn "Monitor mode may not be supported"
        fi
    else
        log_fail "No wireless interfaces detected"
    fi
}

################################################################################
# Test 7: Network Connectivity
################################################################################
test_network() {
    echo ""
    log_info "=== Testing Network Connectivity ==="
    
    # Check network interfaces
    if ip link show | grep -q "state UP"; then
        log_pass "Network interface is up"
    else
        log_warn "No active network interface"
    fi
    
    # Check internet connectivity
    if ping -c 1 8.8.8.8 &> /dev/null; then
        log_pass "Internet connectivity OK"
    else
        log_warn "No internet connectivity"
    fi
    
    # Check DNS resolution
    if ping -c 1 google.com &> /dev/null; then
        log_pass "DNS resolution OK"
    else
        log_warn "DNS resolution failed"
    fi
}

################################################################################
# Test 8: System Resources
################################################################################
test_system_resources() {
    echo ""
    log_info "=== Testing System Resources ==="
    
    # Check disk space
    local disk_usage=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
    if [[ $disk_usage -lt 90 ]]; then
        log_pass "Disk space OK ($disk_usage% used)"
    else
        log_warn "Disk space low ($disk_usage% used)"
    fi
    
    # Check memory
    local mem_available=$(free -m | awk 'NR==2 {print $7}')
    if [[ $mem_available -gt 500 ]]; then
        log_pass "Memory available: ${mem_available}MB"
    else
        log_warn "Low memory: ${mem_available}MB available"
    fi
    
    # Check CPU temperature (if available)
    if command -v vcgencmd &> /dev/null; then
        local temp=$(vcgencmd measure_temp | cut -d= -f2)
        log_pass "CPU temperature: $temp"
    fi
}

################################################################################
# Test 9: Dashboard
################################################################################
test_dashboard() {
    echo ""
    log_info "=== Testing Dashboard ==="
    
    # Check dashboard files
    if [[ -f "$HOME/VoidPWN/dashboard/index.html" ]]; then
        log_pass "Dashboard HTML exists"
    else
        log_fail "Missing dashboard/index.html"
    fi
    
    if [[ -f "$HOME/VoidPWN/dashboard/server.py" ]]; then
        log_pass "Dashboard server exists"
    else
        log_fail "Missing dashboard/server.py"
    fi
    
    # Check if Flask is installed
    if python3 -c "import flask" 2>/dev/null; then
        log_pass "Flask installed for dashboard"
    else
        log_fail "Flask not installed (dashboard won't work)"
    fi
    
    # Test dashboard syntax
    if python3 -m py_compile "$HOME/VoidPWN/dashboard/server.py" 2>/dev/null; then
        log_pass "Dashboard server syntax OK"
    else
        log_fail "Dashboard server has syntax errors"
    fi
}

################################################################################
# Test 10: Scenarios
################################################################################
test_scenarios() {
    echo ""
    log_info "=== Testing Scenarios ==="
    
    # Check scenarios script
    if [[ -f "$HOME/VoidPWN/scenarios.sh" ]]; then
        log_pass "Scenarios script exists"
    else
        log_fail "Missing scenarios.sh"
        return
    fi
    
    # Check syntax
    if bash -n "$HOME/VoidPWN/scenarios.sh" 2>/dev/null; then
        log_pass "Scenarios script syntax OK"
    else
        log_fail "Scenarios script has syntax errors"
    fi
    
    # Check if executable
    if [[ -x "$HOME/VoidPWN/scenarios.sh" ]]; then
        log_pass "Scenarios script is executable"
    else
        log_fail "Scenarios script not executable"
    fi
}

################################################################################
# Test 11: Wordlists
################################################################################
test_wordlists() {
    echo ""
    log_info "=== Testing Wordlists ==="
    
    # Check for rockyou.txt
    if [[ -f "/usr/share/wordlists/rockyou.txt" ]]; then
        log_pass "rockyou.txt available"
    elif [[ -f "/usr/share/wordlists/rockyou.txt.gz" ]]; then
        log_warn "rockyou.txt is compressed (run: sudo gunzip /usr/share/wordlists/rockyou.txt.gz)"
    else
        log_fail "rockyou.txt not found"
    fi
    
    # Check for dirb wordlists
    if [[ -d "/usr/share/wordlists/dirb" ]]; then
        log_pass "Dirb wordlists available"
    else
        log_warn "Dirb wordlists not found"
    fi
}

################################################################################
# Test 12: Permissions
################################################################################
test_permissions() {
    echo ""
    log_info "=== Testing Permissions ==="
    
    # Check VoidPWN directory ownership
    local owner=$(stat -c '%U' "$HOME/VoidPWN" 2>/dev/null)
    if [[ "$owner" == "kali" ]] || [[ "$owner" == "$USER" ]]; then
        log_pass "VoidPWN directory ownership OK"
    else
        log_warn "VoidPWN directory owner: $owner (expected: kali or $USER)"
    fi
    
    # Check if user can write to output directories
    if [[ -w "$HOME/VoidPWN" ]]; then
        log_pass "Write permission to VoidPWN directory"
    else
        log_fail "No write permission to VoidPWN directory"
    fi
}

################################################################################
# Generate Report
################################################################################
generate_report() {
    echo ""
    echo "================================================================================"
    echo -e "${CYAN}TEST SUMMARY${NC}"
    echo "================================================================================"
    echo -e "${GREEN}Passed:${NC}  $TESTS_PASSED"
    echo -e "${RED}Failed:${NC}  $TESTS_FAILED"
    echo -e "${YELLOW}Warnings:${NC} $TESTS_WARNING"
    echo ""
    
    # Write to report file
    cat >> "$REPORT_FILE" << EOF

SUMMARY
=======
Tests Passed:  $TESTS_PASSED
Tests Failed:  $TESTS_FAILED
Warnings:      $TESTS_WARNING

EOF
    
    if [[ ${#ISSUES[@]} -gt 0 ]]; then
        echo -e "${YELLOW}ISSUES FOUND:${NC}"
        echo "================================================================================"
        printf '%s\n' "${ISSUES[@]}"
        echo ""
        
        cat >> "$REPORT_FILE" << EOF
ISSUES FOUND
============
EOF
        printf '%s\n' "${ISSUES[@]}" >> "$REPORT_FILE"
        cat >> "$REPORT_FILE" << EOF

EOF
    fi
    
    # Overall status
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}✓ ALL TESTS PASSED${NC}"
        echo ""
        echo "VoidPWN is ready to use!"
        cat >> "$REPORT_FILE" << EOF
OVERALL STATUS
==============
✓ ALL TESTS PASSED
VoidPWN is ready to use!
EOF
    else
        echo -e "${RED}✗ SOME TESTS FAILED${NC}"
        echo ""
        echo "Please fix the issues above before using VoidPWN."
        echo "Run: sudo ./setup.sh to install missing components"
        cat >> "$REPORT_FILE" << EOF
OVERALL STATUS
==============
✗ SOME TESTS FAILED
Please fix the issues above before using VoidPWN.
Run: sudo ./setup.sh to install missing components
EOF
    fi
    
    echo ""
    echo "Full report saved to: $REPORT_FILE"
}

################################################################################
# Main
################################################################################
main() {
    print_banner
    start_report
    
    check_root
    test_file_structure
    test_script_permissions
    test_script_syntax
    test_required_tools
    test_python_dependencies
    test_wifi_adapter
    test_network
    test_system_resources
    test_dashboard
    test_scenarios
    test_wordlists
    test_permissions
    
    generate_report
}

main "$@"
