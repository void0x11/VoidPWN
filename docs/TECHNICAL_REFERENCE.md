# 🛠️ VOID_PWN // TECHNICAL_REFERENCE

This document provides a technical deep-dive into the VoidPWN system architecture, mapping internal API logic to binary execution and the data persistence layer.

---

## 1. Asynchronous System Orchestration

VoidPWN operates as a **Threaded Command-and-Control (C2) Orchestrator**. Designed for efficiency, it utilizes unbuffered I/O to provide real-time process telemetry.

### [ // PROCESS_MANAGEMENT ]
- **Core Engine**: `dashboard/server.py`
- **Execution Mechanism**: `subprocess.Popen` with `stdbuf -oL -eL`.
- **Threading Model**: 
  - **The Producer**: `capture()` thread reads `proc.stdout` line-by-line.
  - **The Consumer**: `add_live_log()` appends to a `collections.deque(maxlen=1000)` for O(1) rotation efficiency.
- **Logic**: 
  - Using `stdbuf` (Standard Buffer) forces the underlying binaries (`nmap`, `airodump-ng`, `wifite`) to flush their `stdout` line-by-line rather than filling their internal memory buffers.
  - This allows the **Live HUD** to display progress percentages and scan artifacts as they occur, rather than after the process terminates.

---

## 2. Security Assessment Lifecycle: Data Path Detail

A high-level technical trace of a security assessment action:

1.  **Trigger**: The frontend issues a `fetch()` POST request to `/api/wifi/deauth`.
2.  **Orchestration**: `server.py` validates parameters and spawns the `wifi_tools.sh` subprocess.
3.  **Capture & Audit**:
    - A dedicated thread hooks the process `stdout`.
    - Each line passes through `parse_inventory_info()` for regex-based host discovery.
    - Identified nodes are pushed to `device_manager.add_device()`, which persists to `output/devices.json`.
4.  **Interface Stream**: The log line is appended to `LIVE_LOGS`. The frontend polls `/api/logs` to render the unbuffered data stream.
5.  **Finalization**: Upon process termination, `reporter.update_status()` transitions the assessment from "Running" to "Completed".

---

## 3. Real-time Intelligence Extraction (Regex Heuristics)

The system analyzes all incoming process telemetry through a Regex-based heuristic engine to automatically map the network environment.

### [ // INTEL_EXTRACTION_SCHEMA ]
| Target Type | Regex Pattern Logic | Extraction Script |
| :--- | :--- | :--- |
| **IP_ADDRESS** | `[\\d\\.]+` (contextualized by Nmap headers) | `parse_inventory_info` |
| **HOSTNAME** | `for (.*) \\((.*)\\)` | `parse_inventory_info` |
| **MAC_VENDOR** | OUI Database Lookup | `DeviceManager` |
| **OPEN_PORTS** | `(\\d+)/(tcp|udp)\\s+open` | `ElementTree` XML Parser |

---

## 4. Wireless Security Engine (`wifi_tools.sh`)

### [ // MONITOR_MODE_LIFECYCLE ]
- **Initialization**: `airmon-ng check kill` -> `airmon-ng start <iface>`.
- **Termination**: `airmon-ng stop <iface>mon` -> `systemctl restart NetworkManager`.
- **Fallback**: Uses `iwconfig` and `ip link` for chipsets that utilize older `nl80211` drivers.

### [ // PMKID_ASSESSMENT_VECTOR ]
- **Command**: `timeout [duration] hcxdumptool -o [pcapng] -i [iface] --enable_status=1`
- **Technical Note**: This is a clientless method targeting the RSN Robust Security Network Association. It eliminates the need for active deauthentication frames, significantly reducing the system's signal footprint and minimizing network disruption.

---

## 5. Network Reconnaissance Engine (`recon.sh`)

### [ // PERFORMANCE_PROFILES ]
- **Level 4/5 (Aggressive)**: Optimized for rapid mapping within a known network range.
- **Stealth (T2/Fragmentation)**: Splits IP headers to bypass stateful packet inspection (SPI) and reduces inter-probe intervals to evade threshold-based IDS alerts.

| Flag | Technical Purpose |
| :--- | :--- |
| `-sS` | Stealth SYN Scan (Half-open) |
| `-f` | Segmented packet headers |
| `-D RND:10` | Decoy traffic generation (IP Spoofing) |

---

## 6. Hardware Interfacing & SPI Framing

VoidPWN manages dual output modalities through kernel-level display switching.

### [ // DISPLAY_LOGIC ]
- **Drivers**: Based on `LCD-show` (Waveshare 3.5" TFT).
- **Orchestration**:
  1. **TFT_MODE**: Configures `/boot/config.txt` for SPI clock speed (32MHz) and initializes `fbcp` to mirror the primary framebuffer.
  2. **HDMI_MODE**: Reverts drivers to standard HDMI output and stops the `fbcp` daemon.

---

## 7. Persistence & Data Integrity

- **Reports**: Stored in `output/reports/` with a UUID-based indexing in `reports.json`.
- **Captures**: Handshakes conserved in raw `.cap` and `.pcapng` formats, ready for high-performance cracking (Hashcat/John).

---

> **[ // DOCUMENTATION_END ]**: Authorized security research use only.

*For user-level operational workflows, see the [Operation Manual](../USER_GUIDE.md).*
