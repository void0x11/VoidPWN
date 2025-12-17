# VoidPWN System Test

## Overview

The system test script (`test.sh`) performs comprehensive validation of all VoidPWN components before deployment or after installation to ensure everything is working correctly.

## Usage

```bash
cd ~/VoidPWN
sudo ./test.sh
```

## What It Tests

### 1. File Structure (13 tests)
- Verifies all core scripts exist
- Checks for documentation files
- Validates directory structure
- Confirms dashboard files present

### 2. Script Permissions (8 tests)
- Ensures all scripts are executable
- Validates proper file permissions
- Checks ownership

### 3. Script Syntax (8 tests)
- Validates bash syntax for all scripts
- Detects syntax errors before runtime
- Prevents execution failures

### 4. Required Tools (35+ tests)
Tests installation of:
- **WiFi Tools**: aircrack-ng, wifite, bettercap, mdk4, etc.
- **Network Tools**: nmap, masscan, wireshark, ettercap, etc.
- **Password Tools**: hashcat, john, hydra, medusa, etc.
- **Exploitation Tools**: metasploit, sqlmap, responder
- **Web Tools**: gobuster, nikto, wpscan, whatweb, etc.

### 5. Python Dependencies (2 tests)
- Flask (for dashboard)
- psutil (for system monitoring)

### 6. WiFi Adapter (4 tests)
- Detects wireless interfaces
- Checks for external adapter (wlan1)
- Verifies monitor mode support
- Tests adapter capabilities

### 7. Network Connectivity (3 tests)
- Network interface status
- Internet connectivity
- DNS resolution

### 8. System Resources (3 tests)
- Disk space availability
- Memory availability
- CPU temperature (if available)

### 9. Dashboard (4 tests)
- Dashboard files exist
- Flask installation
- Server syntax validation
- File permissions

### 10. Scenarios (3 tests)
- Scenarios script exists
- Syntax validation
- Executable permissions

### 11. Wordlists (2 tests)
- rockyou.txt availability
- Dirb wordlists presence

### 12. Permissions (2 tests)
- Directory ownership
- Write permissions

## Test Results

### Output Format

```
[PASS] Test description - Test passed
[FAIL] Test description - Test failed (critical)
[WARN] Test description - Warning (non-critical)
```

### Example Output

```
╔═══════════════════════════════════╗
║     VOIDPWN SYSTEM TEST           ║
╚═══════════════════════════════════╝

[TEST] Checking root privileges...
[PASS] Running as root

[TEST] === Testing File Structure ===
[PASS] File exists: setup.sh
[PASS] File exists: wifi_tools.sh
[PASS] File exists: recon.sh
[PASS] File exists: voidpwn.sh
[PASS] File exists: dashboard.sh
[PASS] File exists: scenarios.sh
...

[TEST] === Testing Required Tools ===
[PASS] WiFi tool installed: aircrack-ng
[PASS] WiFi tool installed: wifite
[FAIL] Missing WiFi tool: mdk4
...

================================================================================
TEST SUMMARY
================================================================================
Passed:  67
Failed:  3
Warnings: 2

ISSUES FOUND:
================================================================================
FAIL: Missing WiFi tool: mdk4
FAIL: Missing Python module: flask
WARN: External WiFi adapter not detected (wlan1)

✗ SOME TESTS FAILED

Please fix the issues above before using VoidPWN.
Run: sudo ./setup.sh to install missing components

Full report saved to: ~/VoidPWN/test_report_20250116_170530.txt
```

## Report File

A detailed report is automatically generated:

**Location**: `~/VoidPWN/test_report_YYYYMMDD_HHMMSS.txt`

**Contents**:
- System information
- Complete test results
- List of all issues found
- Recommendations for fixes
- Overall status

### Example Report

```
VoidPWN System Test Report
Generated: Mon Jan 16 17:05:30 MST 2025
Hostname: voidpwn
IP Address: 192.168.1.100
Kernel: 5.10.0-kali7-arm64

================================================================================
TEST RESULTS
================================================================================

SUMMARY
=======
Tests Passed:  67
Tests Failed:  3
Warnings:      2

ISSUES FOUND
============
FAIL: Missing WiFi tool: mdk4
FAIL: Missing Python module: flask
WARN: External WiFi adapter not detected (wlan1)

OVERALL STATUS
==============
✗ SOME TESTS FAILED
Please fix the issues above before using VoidPWN.
Run: sudo ./setup.sh to install missing components
```

## When to Run Tests

### Before First Use
```bash
# After cloning/transferring VoidPWN
cd ~/VoidPWN
chmod +x *.sh
sudo ./test.sh
```

### After Installation
```bash
# After running setup.sh
sudo ./test.sh
```

### Before Deployment
```bash
# Before using VoidPWN in production
sudo ./test.sh
```

### After Updates
```bash
# After git pull or manual updates
sudo ./test.sh
```

### Troubleshooting
```bash
# When experiencing issues
sudo ./test.sh
```

## Fixing Common Issues

### Missing Tools

```bash
# Install missing tools
sudo ./setup.sh

# Or install specific tool
sudo apt install <tool-name>
```

### Missing Python Modules

```bash
# Install Flask and psutil
pip3 install flask psutil
```

### Script Not Executable

```bash
# Make all scripts executable
chmod +x ~/VoidPWN/*.sh
```

### WiFi Adapter Not Detected

```bash
# Check USB connection
lsusb | grep -i alfa

# Try different USB port
# Replug the adapter
```

### Syntax Errors

```bash
# Check specific script
bash -n ~/VoidPWN/script_name.sh

# Re-download if corrupted
git pull
```

## Integration with Setup

The test script can be run automatically after setup:

```bash
# In setup.sh, add at the end:
./test.sh
```

## Automated Testing

### Run on Boot

```bash
# Add to /etc/rc.local
/home/kali/VoidPWN/test.sh > /home/kali/VoidPWN/boot_test.log 2>&1
```

### Scheduled Testing

```bash
# Add to crontab
crontab -e

# Run test daily at 3 AM
0 3 * * * cd ~/VoidPWN && sudo ./test.sh
```

## Exit Codes

The test script returns:
- `0` - All tests passed
- `1` - Some tests failed
- `2` - Critical error (can't run tests)

Use in scripts:

```bash
if sudo ./test.sh; then
    echo "All tests passed, proceeding..."
else
    echo "Tests failed, aborting..."
    exit 1
fi
```

## Verbose Mode

For detailed debugging, run with bash -x:

```bash
sudo bash -x ./test.sh
```

## Quick Test

For a fast check of critical components only:

```bash
# Test only tools (skip file checks)
sudo ./test.sh --quick  # (if implemented)
```

## CI/CD Integration

Use in continuous integration:

```bash
#!/bin/bash
# CI test script

cd VoidPWN
chmod +x *.sh

if sudo ./test.sh; then
    echo "Build passed"
    exit 0
else
    echo "Build failed"
    cat ~/VoidPWN/test_report_*.txt
    exit 1
fi
```

## Troubleshooting the Test Script

### Test Script Won't Run

```bash
# Check permissions
ls -l ~/VoidPWN/test.sh

# Make executable
chmod +x ~/VoidPWN/test.sh

# Check syntax
bash -n ~/VoidPWN/test.sh
```

### Tests Hang

```bash
# Kill hung tests
pkill -f test.sh

# Run with timeout
timeout 300 sudo ./test.sh  # 5 minute timeout
```

### False Positives

Some tests may show warnings that can be ignored:
- "External WiFi adapter not detected" - OK if using built-in WiFi
- "rockyou.txt is compressed" - Can be extracted later
- "Dirb wordlists not found" - Optional for basic use

## Test Coverage

Current test coverage:
- **File Structure**: 100%
- **Scripts**: 100%
- **Core Tools**: 95%
- **Optional Tools**: 80%
- **System Resources**: 100%
- **Network**: 100%

Total: **87 individual tests**

## Future Enhancements

Planned additions:
- Performance benchmarks
- Network speed tests
- Tool version checks
- Compatibility matrix
- Hardware stress tests
- Security audit checks

---

The test script ensures VoidPWN is fully functional before use, preventing runtime errors and identifying missing components early.
