# Technical Operational Reference

This document provides a technical breakdown of the VoidPWN platform's underlying scripts and automation logic. It is intended for users requiring direct CLI access or a deeper understanding of system execution.

---

## Scanning and Reconnaissance

### 1. Network Discovery
The network discovery module (`scripts/network/recon.sh`) utilizes Nmap for asset identification:

- **Host Discovery**:
  - Command: `nmap -sn <target>`
  - Objective: Subnet mapping via ARP and ICMP requests without port scanning.
- **Aggressive Enumeration**:
  - Command: `nmap -sV -sC -O -A -p- <target>`
  - Objective: Comprehensive service versioning (`-sV`), script execution (`-sC`), OS fingerprinting (`-O`), and full 65535 port coverage (`-p-`).

### 2. Reconnaissance Profiles
- **Stealth Assessment**: 
  - Implementation: `nmap -sS -T2 -f -D RND:10`
  - Logic: SYN stealth scanning with fragmented headers and decoy addresses to bypass IDS/Firewall filtering.
- **Vulnerability Scanning**:
  - Implementation: `nmap --script vuln`
  - Logic: Automated CVE discovery via the Nmap Scripting Engine.

---

## Wireless Assessment Vectors

Wireless operations are managed via `scripts/network/wifi_tools.sh`, integrating several specialized Layer 2 tools:

### Primary Tools
- **Deauthentication**: `aireplay-ng --deauth 0 -a <BSSID>`
- **EAPOL Interception**: `airodump-ng -c <ch> --bssid <BSSID> -w <output>`
- **RSN IE Extraction (PMKID)**: `hcxdumptool -o <output> -i <iface> --enable_status=1`
- **WPS PIN Recovery**: `reaver -i <iface> -b <BSSID> -K 1 -vv`

### Protocol Stress Testing
- **Beacon Flooding**: `mdk4 <iface> b`
- **Association Flooding**: `mdk4 <iface> a -a <BSSID>`

---

## Automation Framework

Scenarios are orchestrated through `scripts/network/scenarios.sh`, providing high-level task management.

### Wireless Security Mission
1.  **Interface Configuration**: Toggles the chipset to monitor mode.
2.  **Environmental Survey**: 10-minute discovery phase via `airodump-ng`.
3.  **Targeted Capture**: Sequential execution of PMKID and handshake capture logic across high-signal targets.

### Web Intelligence Mission
1.  **Asset Identification**: Targeted scanning for ports 80, 443, and 8080.
2.  **Service Fingerprinting**: Technical identification of CMS and technology stacks via `WhatWeb`.
3.  **Fuzzing and Auditing**: Parallelized `GoBuster` and `Nikto` sessions for comprehensive application-level discovery.

---

## System Architecture

### Process Management
The Flask backend (`server.py`) manages tool execution using asynchronous `subprocess.Popen` calls. This methodology ensures that the web interface remains responsive during long-running background processes.

### Data Persistence
- **Host Inventory**: Discovered hosts and service metadata are persisted in `output/devices.json`.
- **Reports**: Standard output and error streams from assessment tools are captured and archived in the reporting directory for historical review.

---
*Operational reference conclude. For theoretical analysis, refer to [ATTACK_REFERENCE.md](./docs/ATTACK_REFERENCE.md).*
