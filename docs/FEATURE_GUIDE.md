```
# [ // SYSTEM_CAPABILITIES ]
## [ // FEATURE_SPECIFICATION_INDEX ]

This document provides a comprehensive technical overview of the VoidPWN platform's capabilities, detailing the underlying mechanisms and operational logic of each module.

---

## [ // TABLE_OF_CONTENTS ]

1. [ // INTERFACE_OVERVIEW ](#dashboard-overview)
2. [ // NETWORK_CONFIGURATION ](#network-interfaces)
3. [ // WIRELESS_SECURITY_SUITE ](#wifi-attacks)
4. [ // NETWORK_INTELLIGENCE ](#network-reconnaissance)
5. [ // AUTOMATED_WORKFLOWS ](#automated-scenarios)
6. [ // DATA_PERSISTENCE ](#reports-system)
7. [ // SYSTEM_ADMINISTRATION ](#system-management)
8. [ // HOST_INVENTORY ](#device-inventory)
9. [ // MONITORING_INTERFACE ](#live-hud)

---

## [ // INTERFACE_OVERVIEW ]

The VoidPWN management interface is a professional web-based platform designed for low-latency orchestration of security research and hardware assessments.

### Navigation Tabs
- **INTERFACES**: System network interface management
- **WIFI ATTACKS**: Wireless protocol security assessment tools
- **RECON**: Network reconnaissance and service enumeration
- **SCENARIOS**: Pre-configured automated security workflows
- **REPORTS**: Persistent assessment logs and data export
- **SYSTEM**: Platform configuration and hardware maintenance
### Header Controls
- **STOP ALL**: Global kill switch for active attacks (red button, top-right)
- **System Stats**: Real-time CPU, RAM, and disk usage monitoring

---

## [ // NETWORK_CONFIGURATION ]

**Location**: `[ // INTERFACES ]` Tab

### [ // SYSTEM_PURPOSE ]
Centralized orchestration of physical and logical network interfaces. This module manages the transition from standard system network connectivity to specialized "Monitor Mode" for packet capture and analysis.

### [ // CORE_TELEMETRY ]

#### 1. Interface Dynamics
Displays real-time state of the hardware stack:
- **Identifier**: Logical name (e.g., `wlan1`).
- **Telemetry**: IP assignment, MAC signatures, and UP/DOWN state.

#### 2. Monitor Mode (Packet Capture)
Activates the `RTL8812AU` chipset's capability for raw 802.11 frame interception and analysis.

> [!IMPORTANT]
> **MONITOR ON** initiates `airmon-ng check kill`, which will terminate `NetworkManager`. This disconnects the RPi from the management WiFi if it is using the same adapter.

**System Logic:**
```bash
# Logic for Monitor Mode Initialization
sudo airmon-ng check kill   # Clear conflicting system processes
sudo airmon-ng start wlan1  # Transition driver to Monitor Mode
# Result: wlan1mon (High-Gain Analysis Interface)
```

---

## [ // WIRELESS_SECURITY_SUITE ]

**Location**: `[ // WIFI_ATTACKS ]` Tab

### [ // SPECTRUM_ANALYSIS ]

#### REFRESH NETWORKS (Spectrum Scan)
**Purpose**: Passive and active identification of BSSIDs within the 2.4/5GHz frequency bands.

**Information Harvested:**
- **SSID/BSSID**: Logical and physical identifiers.
- **CH/PWR**: Channel allocation and RSSI (Signal strength).
- **ENC**: Encryption signatures (identifying weak WEP/WPA nodes).

**Technical Note**: The scanner utilizes `airodump-ng` with `--band abg` to ensure comprehensive coverage across available 802.11 standard frequencies.

---

### [ // ASSESSMENT_METHODS ]

#### 1. DEAUTH (Client Disassociation)
**Objective**: Evaluate network resilience against authorized disassociation frames.

**Technique**: Sends `802.11 deauthentication` packets targeting the client-AP relationship.

> [!TIP]
> **Operational Note**: Utilize disassociation frames to evaluate the security of client re-authentication workflows or to test rogue AP mitigation strategies.

**System Command:**
```bash
# Aggressive disassociation on target BSSID
sudo aireplay-ng --deauth 0 -a <BSSID> --ignore-negative-one wlan1mon
```

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
# 1. Lock interface to target frequency
sudo iwconfig wlan1mon channel <CHANNEL>

# 2. Initialize handshake capture
sudo airodump-ng -c <CHANNEL> --bssid <BSSID> -w handshake wlan1mon

# 3. Targeted disassociation (orchestrated in parallel)
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

#### 3. AUTHORIZED ROGUE AP (System Simulation)

**Purpose**: Evaluate client behavior when interacting with authorized rogue access point simulations.

**How it works:**
1. Initialize authorized Rogue AP with target SSID
2. Broadcast disassociation frames to legitimate AP
3. Audit client connection behavior to the simulation
4. Capture and analyze authentication credentials or serve research-based captive portals

**Technical Implementation:**
```bash
# 1. Initialize simulation on target frequency
sudo iwconfig wlan1mon channel <CHANNEL>

# 2. Create authorized simulation AP
sudo airbase-ng -c <CHANNEL> -e "<SSID>" wlan1mon

# 3. System-initiated disassociation (concurrent process)
sudo aireplay-ng --deauth 0 -a <REAL_BSSID> wlan1mon
```

**Attack Variations:**
- **Open Network**: No encryption, easier client connection
- **WPA2**: Requires credential capture
- **Captive Portal**: Phishing page for password harvesting

**Compliance & Guidelines:**
- **ONLY** execute on infrastructure where explicit authorization has been granted.
- Rogue AP simulations must be conducted within strict legal and organizational boundaries.
- Detection by Enterprise WIDS/WIPS is expected during authorized testing.

#### 4. PMKID (Passive Hash Acquisition)
**Objective**: Acquire WPA2 hashes via the initial RSN IE exchange, enabling assessment without active client association.

**Technical Advantage**: This is a clientless assessment method, requiring only the presence of an active Access Point.

**Directive:**
```bash
# Capture Pulse via hcxdumptool
sudo hcxdumptool -i wlan1mon -o pmkid.pcapng --enable_status=1
```

#### 5. WPS ENTROPY ANALYSIS (PIN Recovery)

**Purpose**: Analyze vulnerabilities in legacy WPS implementations to evaluate PIN generation security.

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
- Applicable only to devices with legacy WPS protocols enabled.
- Effectiveness depends on the presence of vulnerable firmware implementations.
- Modern enterprise-grade access points typically incorporate mitigation for this vector.

#### 6. WIFITE (Automated Security Auditing)

**Purpose**: Systematic, automated wireless security assessments.

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
- Minimal granularity over individual assessment vectors.
- Potential for increased system-to-network signal visibility.
- Time-intensive due to systematic auditing of all identified targets.

---

## [ // NETWORK_INTELLIGENCE ]

**Location**: `[ // RECON ]` Tab

### [ // ASSESSMENT_METHODS ]

#### 1. QUICK_SCAN (Asset Discovery)
**Objective**: Rapid identification of active nodes on the target subnet.
- **Mechanism**: ICMP Echo Requests + TCP SYN (443) + TCP ACK (80).
- **Technical Speed**: Optimized for discovery efficiency (~10-30s).

#### 2. FULL_SCAN (Deep Enumeration)
**Objective**: Comprehensive intelligence gathering on a single target.
- **Mechanism**: Version detection (`-sV`), Default Scripts (`-sC`), and OS Fingerprinting (`-O`).
- **Telemetry**: Full service/version banners and potential exploit entry points.

#### 3. STEALTH_SCAN (Low-Visibility Assessment)
**Objective**: Execution of network assessment while minimizing interference with IDS/IPS systems.
- **Mechanism**: SYN Stealth (`-sS`), Decoy IPs (`-D`), and Packet Fragmentation (`-f`).
- **Technical Advantage**: Designed to minimize the system's visibility to stateless packet filters and standard monitoring systems.

#### 4. VULNERABILITY_ASSESSMENT
**Objective**: Systematic identification of known security vulnerabilities.
- **Mechanism**: NSE (Nmap Scripting Engine) `vuln` script categories.
- **Indicators**: Direct references to CVEs and criticality levels in the monitoring interface.

#### 5. WEB_DIR_FUZZING (Hidden Path Discovery)
**Objective**: Brute-force discovery of unlinked web directories and configuration files.
- **Mechanism**: Dictionary-based fuzzing via `gobuster`.
- **Target Assets**: Admin panels, backups (`.bak`), and environment files (`.env`).

---

## [ // AUTOMATED_WORKFLOWS ]

**Location**: `[ // SCENARIOS ]` Tab

### [ // WORKFLOW_ORCHESTRATION ]

#### QUICK_CHECK (Rapid Assessment)
**Objective**: 5-minute automated sweep of the local environment.
- **Phase 1**: Host discovery on `/24` subnet.
- **Phase 2**: Service enumeration on live nodes.
- **Phase 3**: Vulnerability script execution.

> [!TIP]
> **Operational Note**: Automated workflows are ideal for standardized, hands-off data collection during security assessments.

---

## [ // DATA_PERSISTENCE ]

**Location**: `[ // REPORTS ]` Tab

### [ // ASSESSMENT_LOGS ]
Centralized repository for all system output and captured security data.

- **Dynamics**: Real-time status tracking (Running/Success/Failed).
- **Exfiltration**: Direct access to raw `.cap`, `.pcapng`, and `.nmap` files for offline analysis.
- **Log Management**: Automated truncation for UI stability, with full download capabilities for complete forensic trails.

---

## [ // SYSTEM_ADMINISTRATION ]

**Location**: `[ // SYSTEM ]` Tab

### [ // SYSTEM_CONTROLS ]
lifecycle management for the physical unit.

- **REBOOT / SHUTDOWN**: Controlled power management for hardware integrity.
- **DISPLAY_CONFIGURATION**: Dynamic switching between the `[ TFT_INTERFACE ]` and the `[ HDMI_STATIONARY_INTERFACE ]`. Note: Requires system reboot for kernel-level driver initialization.

---

## [ // HOST_INVENTORY ]

**Location**: Right Sidebar (Global Access)

### [ // NETWORK_NODE_TRACKING ]
Live database of identified nodes within the active assessment environment.

- **Automated Host Discovery**: Real-time data from Nmap, Airodump, and ARP modules is automatically parsed and populated in the inventory.
- **Device Profiling**: Automatic MAC OUI lookup for vendor identification and hostname resolution.
- **Assessment Selection**: Researchers can select individual hosts to target specific assessment modules (scans/audits).

---

## [ // MONITORING_INTERFACE ]

**Location**: Bottom Panel (Global Access)

### [ // REAL_TIME_PROCESS_TELEMETRY ]
The primary monitoring interface for live system activity.

- **System Activity Stream**: Unified feed of stdout/stderr from active background processes.
- **Color Logic**:
    - `[✓] GREEN`: Process success / Achievement of objective.
    - `[✗] RED`: Process error / Service interaction failure.
    - `[?] WHITE`: Informational telemetry.
- **Dynamic Scroll**: Automatically scrolls to provides most recent data updates.

---

## [ // SAFETY_&_TERMINATION_PROTOCOLS ]

### STOP_ALL (Global Process Termination)
**Objective**: Immediate termination of all active subprocesses and RF transmission.
**Mechanism**:
```bash
# Global Termination Sequence
sudo killall aireplay-ng airodump-ng airbase-ng wifite nmap reaver bettercap
```

---

## [ // PROFESSIONAL_OPERATIONAL_GUIDELINES ]

### [ // ASSESSMENT_SUCCESS_FACTORS ]

1. **Target Verification**: Always confirm target identification in the `[ // HOST_INVENTORY ]` before initiating active security assessments.
2. **Persistence Management**: Periodically archive old logs to maintain filesystem health and performance.
3. **Thermal Monitoring**: Monitor the `[ // MONITORING_INTERFACE ]` for system load during sustained wireless auditing to prevent hardware throttling.
4. **Data Validation**: Ensure all captured security artifacts are verified for integrity before conducting offline analysis.

---
*For technical implementation details, see [Technical Reference](./TECHNICAL_REFERENCE.md).*
*For hardware setup, see [Hardware Setup Guide](./HARDWARE_SETUP.md).*
