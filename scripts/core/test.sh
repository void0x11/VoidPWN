#!/bin/bash

################################################################################
# VoidPWN - System Test Script
# Description: Comprehensive testing of all VoidPWN components
# Usage: sudo ./scripts/core/test.sh
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

# Directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
REPORT_FILE="$PROJECT_ROOT/test_report_$(date +%Y%m%d_%H%M%S).txt"

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
Project Root: $PROJECT_ROOT

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
        "scripts/core/setup.sh"
        "scripts/core/test.sh"
        "scripts/network/wifi_tools.sh"
        "scripts/network/recon.sh"
        "scripts/network/scenarios.sh"
        "voidpwn.sh"
        "README.md"
        "USER_GUIDE.md"
        "docs/HUD_MANUAL.md"
        "docs/NETWORK_INTEL.md"
        "docs/WIFI_ARSENAL.md"
        "docs/SCENARIO_GUIDE.md"
        "docs/ATTACK_REFERENCE.md"
        "docs/TECHNICAL_REFERENCE.md"
        "LICENSE"
        ".gitignore"
    )
    
    for file in "${files[@]}"; do
        if [[ -f "$PROJECT_ROOT/$file" ]]; then
            log_pass "File exists: $file"
        else
            log_fail "Missing file: $file"
        fi
    done
    
    # Check directories
    local dirs=(
        "dashboard"
        "output/captures"
        "output/recon"
        "output/logs"
        "scripts/core"
        "scripts/network"
        "scripts/python"
        "docs"
    )
    
    for dir in "${dirs[@]}"; do
        if [[ -d "$PROJECT_ROOT/$dir" ]]; then
            log_pass "Directory exists: $dir"
        else
            mkdir -p "$PROJECT_ROOT/$dir" 2>/dev/null
            if [[ -d "$PROJECT_ROOT/$dir" ]]; then
                log_pass "Directory created: $dir"
            else
                log_warn "Missing directory: $dir (failed to create)"
            fi
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
        "scripts/core/setup.sh"
        "scripts/core/test.sh"
        "scripts/network/wifi_tools.sh"
        "scripts/network/recon.sh"
        "scripts/network/scenarios.sh"
        "voidpwn.sh"
    )
    
    for script in "${scripts[@]}"; do
        if [[ -x "$PROJECT_ROOT/$script" ]]; then
            log_pass "Executable: $script"
        else
            chmod +x "$PROJECT_ROOT/$script" 2>/dev/null
            if [[ -x "$PROJECT_ROOT/$script" ]]; then
                log_pass "Fixed permissions: $script"
            else
                log_fail "Not executable: $script"
            fi
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
        "scripts/core/setup.sh"
        "scripts/core/test.sh"
        "scripts/network/wifi_tools.sh"
        "scripts/network/recon.sh"
        "scripts/network/scenarios.sh"
        "voidpwn.sh"
    )
    
    for script in "${scripts[@]}"; do
        if bash -n "$PROJECT_ROOT/$script" 2>/dev/null; then
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
        "dsniff"
        "tc"
    )
    
    for tool in "${net_tools[@]}"; do
        if command -v "$tool" &> /dev/null; then
            log_pass "Network tool installed: $tool"
        else
            log_fail "Missing network tool: $tool"
        fi
    done
    
    # Exploit/Web/Advanced tools
    local other_tools=(
        "msfconsole"
        "sqlmap"
        "responder"
        "gobuster"
        "nikto"
        "wifiphisher"
        "autopsy"
        "binwalk"
        "ghidra"
        "radare2"
        "apktool"
        "jadx"
        "set"
    )
     for tool in "${other_tools[@]}"; do
        if command -v "$tool" &> /dev/null; then
            log_pass "Tool installed: $tool"
        else
            log_warn "Missing tool (Optional): $tool"
        fi
    done
    
    # Check for fluxion
    if [[ -d "/opt/fluxion" ]]; then
        log_pass "Fluxion installed in /opt"
    else
        log_warn "Fluxion not found in /opt"
    fi
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
        "scapy"
    )
    
    for module in "${python_modules[@]}"; do
        if python3 -c "import $module" 2>/dev/null; then
            log_pass "Python module installed: $module"
        else
            log_fail "Missing Python module: $module"
        fi
    done
}

################################################################################
# Test 6: WiFi Adapter
################################################################################
test_wifi_adapter() {
    echo ""
    log_info "=== Testing WiFi Adapter ==="
    
    if iwconfig 2>&1 | grep -q "wlan"; then
        log_pass "Wireless interface detected"
        if iwconfig 2>&1 | grep -q "wlan1"; then
            log_pass "External WiFi adapter detected (wlan1)"
        else
            log_warn "External WiFi adapter not detected (wlan1)"
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
    
    if [[ -f "$PROJECT_ROOT/dashboard/index.html" ]]; then
        log_pass "Dashboard HTML exists"
    else
        log_fail "Missing dashboard/index.html"
    fi
    
    if [[ -f "$PROJECT_ROOT/dashboard/server.py" ]]; then
        log_pass "Dashboard server exists"
    else
        log_fail "Missing dashboard/server.py"
    fi
}

################################################################################
# Test 10: Wordlists
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
# Test 11: Permissions
################################################################################
test_permissions() {
    echo ""
    log_info "=== Testing Permissions ==="
    
    # Check VoidPWN directory ownership
    if [[ -d "$PROJECT_ROOT" ]]; then
        local owner=$(stat -c '%U' "$PROJECT_ROOT" 2>/dev/null)
        if [[ "$owner" == "kali" ]] || [[ "$owner" == "$USER" ]]; then
            log_pass "VoidPWN directory ownership OK"
        else
            log_warn "VoidPWN directory owner: $owner (expected: kali or $USER)"
        fi
        
        # Check if user can write to output directories
        if [[ -w "$PROJECT_ROOT" ]]; then
            log_pass "Write permission to VoidPWN directory"
        else
            log_fail "No write permission to VoidPWN directory"
        fi
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
    fi
    
    # Overall status
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}✓ ALL TESTS PASSED${NC}"
        echo ""
        echo "VoidPWN is ready to use!"
    else
        echo -e "${RED}✗ SOME TESTS FAILED${NC}"
        echo ""
        echo "Please fix the issues above before using VoidPWN."
        echo "Run: sudo ./scripts/core/setup.sh to install missing components"
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
    test_wordlists
    test_permissions
    
    generate_report
}

main "$@"
