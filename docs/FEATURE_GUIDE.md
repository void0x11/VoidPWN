# VoidPWN Feature Guide

This document provides comprehensive explanations of every feature available in the VoidPWN dashboard.

---

## Table of Contents

1. [Dashboard Overview](#dashboard-overview)
2. [Network Interfaces](#network-interfaces)
3. [WiFi Attacks](#wifi-attacks)
4. [Network Reconnaissance](#network-reconnaissance)
5. [Automated Scenarios](#automated-scenarios)
6. [Reports System](#reports-system)
7. [System Management](#system-management)
8. [Device Inventory](#device-inventory)
9. [Live HUD](#live-hud)

---

## Dashboard Overview

The VoidPWN dashboard is a web-based interface accessible at `http://<PI_IP>:5000`. It provides centralized control over all penetration testing operations.

### Navigation Tabs
- **INTERFACES**: Network interface management
- **WIFI ATTACKS**: Wireless security assessment tools
- **RECON**: Network reconnaissance and scanning
- **SCENARIOS**: Automated multi-stage workflows
- **REPORTS**: Operation logs and results
- **SYSTEM**: Device configuration and maintenance

### Header Controls
- **STOP ALL**: Global kill switch for active attacks (red button, top-right)
- **System Stats**: Real-time CPU, RAM, and disk usage monitoring

---

## Network Interfaces

**Location**: INTERFACES tab

### Purpose
Manage network interfaces and configure monitor mode for wireless attacks.

### Features

#### Interface Status Display
Shows all available network interfaces with:
- **Interface Name**: e.g., `wlan0`, `wlan1`, `eth0`
- **IP Address**: Current IPv4 address
- **MAC Address**: Hardware address
- **Status**: UP/DOWN state

#### Monitor Mode Control
**What is Monitor Mode?**
Monitor mode allows a wireless adapter to capture all WiFi traffic in range, not just traffic directed to it. This is essential for wireless attacks.

**Buttons:**
- **MONITOR ON**: Activates monitor mode on selected interface
  - Creates `wlan1mon` interface
  - Kills conflicting processes (NetworkManager, wpa_supplicant)
  - Required before any WiFi attacks

- **MONITOR OFF**: Deactivates monitor mode
  - Restores normal managed mode
  - Re-enables NetworkManager

**Technical Details:**
```bash
# What happens when you click "MONITOR ON"
sudo airmon-ng check kill
sudo airmon-ng start wlan1
# Creates: wlan1mon (monitor interface)
```

---

## WiFi Attacks

**Location**: WIFI ATTACKS tab

### Network Scanning

#### REFRESH NETWORKS
**Purpose**: Discover nearby WiFi access points

**What it does:**
1. Puts adapter in monitor mode (if not already)
2. Scans all WiFi channels (1-14 for 2.4GHz, 36-165 for 5GHz)
3. Captures beacon frames from access points
4. Displays results in a table

**Information Collected:**
- **SSID**: Network name
- **BSSID**: MAC address of access point
- **Channel**: Operating frequency channel
- **Signal**: Strength in dBm (e.g., -45 dBm = strong, -80 dBm = weak)
- **Encryption**: Security type (WPA2, WPA3, WEP, Open)
- **Clients**: Number of connected devices

**Technical Command:**
```bash
sudo airodump-ng --band abg --output-format csv wlan1mon
```

**Duration**: ~15 seconds

### Attack Types

#### 1. DEAUTH (Deauthentication Attack)

**Purpose**: Disconnect clients from a WiFi network

**How it works:**
1. Sends spoofed deauthentication frames to clients
2. Frames appear to come from the access point
3. Clients disconnect and attempt to reconnect
4. Useful for forcing handshake captures

**Parameters:**
- **Target**: Selected WiFi network (BSSID)
- **Channel**: Locked to target's channel for reliability
- **Count**: Continuous (0 = infinite loop)

**Technical Details:**
```bash
# Channel locking (ensures reliable delivery)
sudo iwconfig wlan1mon channel <TARGET_CHANNEL>

# Aggressive deauth with driver workaround
sudo aireplay-ng --deauth 0 -a <BSSID> --ignore-negative-one wlan1mon
```

**Use Cases:**
- Force WPA handshake capture
- Test client reconnection behavior
- Denial of service testing (authorized networks only)

**Indicators of Success:**
- Live HUD shows "Sending DeAuth packets"
- Clients visible in airodump-ng output disappear
- Handshake captured (if running simultaneously)

#### 2. HANDSHAKE (WPA/WPA2 Handshake Capture)

**Purpose**: Capture 4-way handshake for offline password cracking

**How it works:**
1. Starts packet capture on target channel
2. Waits for client to connect/reconnect
3. Optionally sends deauth to force reconnection
4. Captures EAPOL frames (handshake)
5. Saves to `.cap` file for cracking

**Technical Process:**
```bash
# 1. Lock to target channel
sudo iwconfig wlan1mon channel <CHANNEL>

# 2. Start capture
sudo airodump-ng -c <CHANNEL> --bssid <BSSID> -w handshake wlan1mon

# 3. Aggressive deauth (in parallel)
sudo aireplay-ng --deauth 10 -a <BSSID> --ignore-negative-one wlan1mon
```

**Output Files:**
- `handshake-01.cap`: Captured packets
- `handshake-01.csv`: Network statistics

**Verification:**
```bash
# Check if handshake was captured
sudo aircrack-ng handshake-01.cap
# Look for: "1 handshake" in output
```

**Next Steps:**
Use captured handshake with:
- **Aircrack-ng**: Dictionary attack
- **Hashcat**: GPU-accelerated cracking
- **John the Ripper**: Advanced rule-based cracking

#### 3. EVIL TWIN (Rogue Access Point)

**Purpose**: Create fake access point to intercept credentials

**How it works:**
1. Creates rogue AP with same SSID as target
2. Deauths clients from legitimate AP
3. Clients connect to fake AP
4. Captures credentials or serves phishing page

**Technical Implementation:**
```bash
# 1. Lock to target channel
sudo iwconfig wlan1mon channel <CHANNEL>

# 2. Create fake AP
sudo airbase-ng -c <CHANNEL> -e "<SSID>" wlan1mon

# 3. Deauth legitimate clients (parallel process)
sudo aireplay-ng --deauth 0 -a <REAL_BSSID> wlan1mon
```

**Attack Variations:**
- **Open Network**: No encryption, easier client connection
- **WPA2**: Requires credential capture
- **Captive Portal**: Phishing page for password harvesting

**Ethical Considerations:**
- **ONLY** use on networks you own
- Evil Twin attacks are highly illegal on unauthorized networks
- Can be detected by WIDS/WIPS systems

#### 4. PMKID (Clientless Handshake Capture)

**Purpose**: Capture WPA/WPA2 hash without waiting for clients

**How it works:**
1. Sends association request to access point
2. AP responds with PMKID in EAPOL frame
3. PMKID can be cracked offline (like handshake)
4. No clients required!

**Technical Details:**
```bash
# Capture PMKID using hcxdumptool
sudo hcxdumptool -i wlan1mon -o pmkid.pcapng --enable_status=1
```

**Advantages over Handshake:**
- No clients needed
- Faster capture (seconds vs. minutes)
- Less detectable (no deauth packets)

**Limitations:**
- Not all routers support PMKID
- Newer routers may have patched this vulnerability

**Cracking PMKID:**
```bash
# Convert to hashcat format
hcxpcapngtool -o pmkid.hash pmkid.pcapng

# Crack with hashcat
hashcat -m 16800 pmkid.hash wordlist.txt
```

#### 5. PIXIE DUST (WPS PIN Recovery)

**Purpose**: Exploit weak WPS implementations to recover PIN

**How it works:**
1. Sends WPS exchange requests to router
2. Analyzes router's random number generation
3. Exploits weak entropy to calculate PIN
4. Recovers WPA password using PIN

**Technical Command:**
```bash
sudo reaver -i wlan1mon -b <BSSID> -c <CHANNEL> -K 1 -vv
# -K 1 = Enable Pixie Dust attack
```

**Success Indicators:**
- "Pixie Dust attack was successful!"
- WPS PIN displayed
- WPA PSK (password) recovered

**Limitations:**
- Only works on routers with WPS enabled
- Requires vulnerable WPS implementation
- Many modern routers have patched this

#### 6. WIFITE (Automated Wireless Auditing)

**Purpose**: Fully automated WiFi penetration testing

**How it works:**
1. Scans for all networks in range
2. Prioritizes targets by signal strength and encryption
3. Attempts multiple attack vectors automatically:
   - WPS Pixie Dust
   - WPA handshake capture + deauth
   - PMKID capture
4. Cracks captured hashes with built-in wordlist

**Technical Process:**
```bash
sudo wifite --kill -i wlan1mon
```

**Wifite Attack Sequence:**
1. **WPS Scan**: Checks for WPS-enabled networks
2. **Pixie Dust**: Attempts WPS PIN recovery
3. **Handshake Capture**: Deauths clients and captures handshake
4. **PMKID**: Attempts clientless capture
5. **Cracking**: Uses aircrack-ng with wordlist

**Advantages:**
- Fully automated (no manual intervention)
- Tries multiple attack vectors
- Built-in cracking capabilities

**Disadvantages:**
- Less control over individual attacks
- May be noisier (more detectable)
- Slower than targeted attacks

---

## Network Reconnaissance

**Location**: RECON tab

### Scan Types

#### 1. QUICK SCAN (Host Discovery)

**Purpose**: Rapidly identify live hosts on network

**Technical Command:**
```bash
nmap -sn <TARGET>
# -sn = Ping scan (no port scan)
```

**What it does:**
- Sends ICMP echo requests (ping)
- Sends TCP SYN to port 443
- Sends TCP ACK to port 80
- Sends ICMP timestamp request

**Output:**
- List of IP addresses that responded
- MAC addresses (if on local network)
- Vendor information (MAC OUI lookup)

**Use Case**: Initial network mapping before deeper scans

**Duration**: ~10-30 seconds for /24 subnet

#### 2. FULL SCAN (Comprehensive Enumeration)

**Purpose**: Deep analysis of target system

**Technical Command:**
```bash
nmap -sV -sC -O -A -p- <TARGET>
# -sV = Version detection
# -sC = Default scripts
# -O = OS detection
# -A = Aggressive (enables OS, version, script, traceroute)
# -p- = All 65535 ports
```

**What it detects:**
- **Open Ports**: All TCP ports (1-65535)
- **Service Versions**: e.g., "Apache 2.4.41"
- **Operating System**: e.g., "Linux 5.4.0"
- **Vulnerabilities**: Via NSE scripts
- **Hostnames**: DNS reverse lookup

**Duration**: 5-30 minutes (depends on target)

**Example Output:**
```
PORT    STATE SERVICE VERSION
22/tcp  open  ssh     OpenSSH 8.2p1 Ubuntu
80/tcp  open  http    Apache httpd 2.4.41
443/tcp open  ssl/http Apache httpd 2.4.41
```

#### 3. STEALTH SCAN (Evasion Techniques)

**Purpose**: Avoid detection by IDS/IPS systems

**Technical Command:**
```bash
nmap -sS -T2 -f -D RND:10 <TARGET>
# -sS = SYN scan (half-open, stealthier)
# -T2 = Slow timing (polite)
# -f = Fragment packets
# -D RND:10 = Use 10 random decoy IPs
```

**Evasion Techniques:**
- **SYN Scan**: Doesn't complete TCP handshake
- **Slow Timing**: Reduces detection probability
- **Fragmentation**: Splits packets to evade filters
- **Decoys**: Hides real source IP among fake IPs

**Trade-offs:**
- **Slower**: Can take hours for full scan
- **Less Accurate**: Some services may not respond
- **Stealthier**: Lower chance of triggering alerts

#### 4. VULNERABILITY SCAN

**Purpose**: Identify known security vulnerabilities

**Technical Command:**
```bash
nmap --script vuln <TARGET>
```

**NSE Scripts Used:**
- `http-vuln-*`: Web application vulnerabilities
- `smb-vuln-*`: SMB/Windows vulnerabilities
- `ssl-*`: SSL/TLS weaknesses

**Common Vulnerabilities Detected:**
- EternalBlue (MS17-010)
- Heartbleed (OpenSSL)
- Shellshock (Bash)
- SQL injection points
- Cross-site scripting (XSS)

**Output Example:**
```
| smb-vuln-ms17-010:
|   VULNERABLE:
|   Remote Code Execution vulnerability in Microsoft SMBv1
|     State: VULNERABLE
|     Risk factor: HIGH
```

#### 5. WEB DIRECTORY FUZZING

**Purpose**: Discover hidden files and directories on web servers

**Technical Command:**
```bash
gobuster dir -u <URL> -w <WORDLIST> -x php,html,txt,js
# -u = Target URL
# -w = Wordlist path
# -x = File extensions to check
```

**What it finds:**
- Admin panels (`/admin`, `/wp-admin`)
- Backup files (`/backup.zip`, `/db.sql`)
- Configuration files (`/config.php`, `/.env`)
- Hidden directories (`/uploads`, `/api`)

**Wordlists Used:**
- `/usr/share/wordlists/dirb/common.txt` (default)
- `/usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt` (comprehensive)

**Example Output:**
```
/admin                (Status: 301) [Size: 312]
/uploads              (Status: 200) [Size: 1024]
/config.php.bak       (Status: 200) [Size: 4096]
```

---

## Automated Scenarios

**Location**: SCENARIOS tab

### Quick Check

**Purpose**: 5-minute rapid network assessment

**Workflow:**
1. **Host Discovery** (30s)
   - Ping scan on local subnet
   - Identifies live hosts

2. **Port Scan** (2m)
   - Top 1000 ports on discovered hosts
   - Service version detection

3. **Vulnerability Check** (2m)
   - NSE vuln scripts on open ports
   - Identifies critical vulnerabilities

**Output:**
- List of live hosts with open ports
- Identified services and versions
- Critical vulnerabilities (if any)

**Use Case**: Initial assessment before deeper testing

---

## Reports System

**Location**: REPORTS tab

### Features

#### Operations Summary Table
Displays all completed and active operations:

| Column | Description |
|--------|-------------|
| **TIME** | Timestamp of operation start |
| **TYPE** | Attack/scan type (e.g., "WIFI (DEAUTH)") |
| **TARGET** | SSID, IP, or network identifier |
| **STATUS** | Running, Completed, Failed |
| **FULL OUTPUT** | Button to view detailed logs |

#### Log Viewer
- **Truncated Display**: Shows last 2000 lines for performance
- **Download Full**: Button to download complete log file
- **Syntax Highlighting**: Color-coded output for readability

#### Report Optimization
- **No Horizontal Scroll**: Table fits screen width
- **Full-Width Layout**: Sidebar hidden on Reports page
- **Vertical Scroll**: Allows browsing long operation lists

---

## System Management

**Location**: SYSTEM tab

### Maintenance Controls

#### REBOOT
- Restarts Raspberry Pi
- Useful after driver updates or configuration changes

#### SHUTDOWN
- Powers down Raspberry Pi safely
- Prevents SD card corruption

#### SWITCH TO HDMI
- Runs `restore_hdmi.sh` script
- Switches display output from TFT to HDMI
- Automatically reboots

#### SWITCH TO TFT
- Runs `install_lcd.sh` script
- Switches display output from HDMI to TFT
- Automatically reboots
- **Note**: No confirmation prompt (runs immediately)

---

## Device Inventory

**Location**: Right sidebar (all tabs except Reports)

### Purpose
Tracks discovered devices for easy targeting

### Features

#### Automatic Discovery
Devices are automatically added when discovered via:
- Network scans (Nmap)
- WiFi scans (Airodump-ng)
- ARP scans

#### Device Information
Each device shows:
- **IP Address**: IPv4 address
- **MAC Address**: Hardware address
- **Hostname**: Resolved DNS name (if available)
- **Vendor**: Manufacturer (from MAC OUI)
- **Open Ports**: Discovered services

#### Device Selection
- Click device card to select as target
- Selected device highlighted in purple
- Used for targeted attacks and scans

#### Metadata Management
- **Notes**: Add custom notes to devices
- **Tags**: Categorize devices (e.g., "server", "IoT", "critical")
- **CLEAR**: Remove all devices from inventory

---

## Live HUD

**Location**: Bottom panel (all tabs)

### Purpose
Real-time monitoring of attack progress and system events

### Features

#### Log Streaming
- **Real-time Updates**: Logs appear as attacks execute
- **Color Coding**:
  - 🟢 Green: Success messages
  - 🔴 Red: Errors and critical events
  - ⚪ White: Informational messages

#### Log Types
- **Attack Progress**: "Sending DeAuth packets...", "Handshake captured!"
- **System Events**: "Monitor mode enabled", "Scan completed"
- **Errors**: "Failed to start attack", "Target not selected"

#### Auto-Scroll
- Automatically scrolls to newest log entry
- Shows most recent 50 entries
- Older logs available in Reports tab

---

## Advanced Features

### Stop All Attacks

**Location**: Header (red button, top-right)

**Purpose**: Emergency kill switch for all active operations

**What it stops:**
- `aireplay-ng` (deauth attacks)
- `airodump-ng` (packet captures)
- `airbase-ng` (evil twin)
- `wifite` (automated auditing)
- `nmap` (network scans)
- `reaver` (WPS attacks)
- `bettercap` (MITM attacks)

**Technical Implementation:**
```bash
# Kills all attack processes
sudo killall aireplay-ng airodump-ng airbase-ng wifite nmap reaver bettercap
```

**Use Cases:**
- Accidentally started wrong attack
- Need to quickly stop all operations
- Emergency shutdown before disconnecting

---

## Best Practices

### Target Selection
1. Always select target before starting attack
2. Verify target SSID/IP in confirmation
3. Use Device Inventory for organized targeting

### Attack Monitoring
1. Watch Live HUD for progress indicators
2. Check Reports tab for detailed output
3. Download logs for offline analysis

### Resource Management
1. Stop attacks when complete (don't leave running)
2. Clear old reports periodically
3. Monitor disk space (logs can grow large)

### Security
1. Only test authorized networks
2. Document all testing activities
3. Secure captured handshakes/credentials
4. Delete sensitive data after testing

---

*For technical implementation details, see [Technical Reference](./TECHNICAL_REFERENCE.md).*
*For hardware setup, see [Hardware Setup Guide](./HARDWARE_SETUP.md).*
