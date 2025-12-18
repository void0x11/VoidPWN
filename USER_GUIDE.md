# 📖 VoidPWN Operative's Reference (Technical Deep Dive)

This document provides the binary-level technical breakdown of the VoidPWN platform. It is intended for operatives who need to know exactly what is happening "under the hood."

---

## 📡 Scanning & Intelligence

### 1. RADAR - Network Scanning
The RADAR tab executes `scripts/network/recon.sh` using the following technical implementations:

- **Quick Scan**:
  - `nmap -sn <target>`
  - Performs a Ping Sweep to detect live hosts without scanning ports.
- **Deep Scan**:
  - `nmap -sV -sC -O -A -p- <target>`
  - Enters the "No Holds Barred" mode: Version detection (`-sV`), Default scripts (`-sC`), OS detection (`-O`), Aggressive mode (`-A`), and scanning ALL 65,535 ports (`-p-`).
- **Target Logic**:
  - Discovered hosts are stored in `output/devices.json` with metadata.
  - The dashboard dynamically parses Nmap XML output to extract service banners and port numbers.

### 2. Reconnaissance Modes
- **Stealth Mode**: `nmap -sS -T2 -f -D RND:10`
  - Uses SYN stealth scanning (`-sS`), Slow "Sneaky" timing (`-T2`), Packet fragmentation (`-f`), and 10 random Decoy IPs (`-D`) to evade Firewalls/IDS.
- **Vulnerability Mode**: `nmap --script vuln`
  - Executes the Nmap Scripting Engine (NSE) vulnerability category.
- **Web Enumeration**: `gobuster dir -u <url> -w dirb_common.txt -x php,html,txt,js`
  - Automated directory fuzzing identifying hidden web structures.

---

## 🎯 Tactical Artillery

### 1. WiFi Attack Vectors
The ATTACK tab executes `scripts/network/wifi_tools.sh` using primary tools from the Aircrack-ng and Modern suites:

- **Deauth Attack**: `aireplay-ng --deauth 0 -a <BSSID>`
  - Sends death packets to force target disconnects. 
- **WPA Handshake**: `airodump-ng -c <ch> --bssid <BSSID> -w <output>`
  - Listens for EAPOL frames during a client reconnection.
- **PMKID Sniper**: `hcxdumptool -o <output> -i <iface> --enable_status=1`
  - Leverages the RSN IE (Robust Security Network Information Element) to capture master keys without a connected client.
- **WPS Pixie**: `reaver -i <iface> -b <BSSID> -K 1 -vv`
  - Online/Offline brute force using the Pixie-Dust entropy attack.

### 2. Chaotic Neutral (MDK4)
- **Beacon Flood**: `mdk4 <iface> b`
  - Rapidly broadcasts beacons for nonexistent SSIDs to saturate the area Spectrum.
- **Auth Flood**: `mdk4 <iface> a -a <BSSID>`
  - Floods an AP with randomized authentication frames to overflow its client table.

---

## ✨ Automated Scenarios

Scenarios are orchestrated by `scripts/network/scenarios.sh`.

### WiFi Audit
1. **Monitor Mode**: Toggles interface to `monitor` state.
2. **Recon Phase**: 10min `airodump-ng` sweep to identify target rich environment.
3. **Capture Phase**: Sequential handshake attempts on all top-signal WPA2 networks.
4. **WPS Phase**: `wash` scan followed by targeted `reaver` sessions on vulnerable pins.

### Web Application Hunt
1. **Discovery**: Scans network for ports `80, 443, 8080, 8443`.
2. **Fingerprinting**: Executes `whatweb` to identify CMS (WordPress, Joomla, etc.).
3. **Fuzzing**: Parallel `gobuster` sessions on every identified host.
4. **Vuln Check**: Targeted `nikto` and `sqlmap` (batch mode) for critical web flaws.

---

## ⚙️ System Forensics

- **Dashboard Backend**: Lightweight Python Flask server (`server.py`) handling asynchronous `subprocess.Popen` calls for non-blocking UI.
- **Reporting Manager**: Custom Python class that catches script `stdout/stderr` and translates them into the JSON format displayed in the **REPORTS** tab.
- **Device Management**: Advanced `TargetSelection` logic that differentiates between IP (Layer 3) and BSSID (Layer 2) targets depending on the tool selected.

---
*End of Operational Reference.*
