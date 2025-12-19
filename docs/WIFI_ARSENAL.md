# 📶 WIRELESS_SECURITY // SYSTEM_PROTOCOL_SUITE

This document provides a detailed technical reference for the Layer 2 wireless security assessment features integrated into the VoidPWN platform.

---

## [ // WIRELESS_SECURITY_METHODOLOGIES ]

### 1. PMKID Clientless Capture
- **Script Target**: `wifi_tools.sh --pmkid [duration]`
- **Technical Implementation**: 
  - Utilizes `hcxdumptool` to intercept the Pairwise Master Key ID field from the RSN IE during an association request.
- **Command Line**:
  ```bash
  hcxdumptool -o out.pcapng -i wlan1mon --enable_status=1
  ```
- **Prerequisites**: Access Point must support Robust Security Network (RSN) features. No active client connection is required.

### 2. WPS Pixie-Dust Research
- **Script Target**: `wifi_tools.sh --pixie <BSSID>`
- **Technical Implementation**:
  - Leverages `reaver` and `pixiewps` to perform an offline cryptographic attack on low-entropy nonces (E-S1, E-S2).
- **Command Line**:
  ```bash
  reaver -i wlan1mon -b AA:BB:CC:DD:EE:FF -K 1 -vv
  ```
- **System Logic**: Recovers the 8-digit WPS PIN, which is then utilized to query the WPA2 passphrase.

### 3. MDK4 Protocol Stress Testing
- **Script Target**: `wifi_tools.sh --beacon` | `wifi_tools.sh --auth`
- **Beacon Flooding**:
  - Command: `mdk4 wlan1mon b -f [ssid_list]`
  - Implementation: Broadcasts randomized Beacon frames to test client-side AP discovery resilience.
- **Authentication Flooding**:
  - Command: `mdk4 wlan1mon a -a [BSSID]`
  - Implementation: Floods the target AP's association table with requests from spoofed MAC addresses.

### 4. WPA/WPA2 Handshake Capture
- **Script Target**: `wifi_tools.sh --handshake <BSSID> <CH>`
- **Technical Implementation**:
  - Chained execution of `airodump-ng` (sniffing) and `aireplay-ng` (injection).
- **Workflow**:
  1. Initialize sniffer: `airodump-ng -c [ch] --bssid [bssid] -w [output] wlan1mon`
  2. Trigger Disassociation Frames: `aireplay-ng --deauth 10 -a [bssid] wlan1mon`
- **Requirement**: Requires at least one active client connection to satisfy the 4-way handshake exchange.

---

## [ // SYSTEM_ORCHESTRATION_LOGIC ]

VoidPWN manages the transition of Chipset states and data persistence automatically:

1.  **Process Shielding**: Calls `airmon-ng check kill` to prevent interference from `NetworkManager`.
2.  **Monitor State Transition**: Executes `airmon-ng start wlan1` or manual `iwconfig` fallback.
3.  **Data Persistence**: All captured files are timestamped and moved to `output/captures/` for centralized management.

---
*For direct API mappings and script parameter definitions, see the [Technical Reference](./TECHNICAL_REFERENCE.md).*
