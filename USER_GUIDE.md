# 📟 OPERATION_MANUAL // VOID_PWN PLATFORM

> **[ // SYSTEM_LOG ]**: This document outlines the operational methodologies for the VoidPWN hardware security platform. Intended for use by authorized security researchers and auditors.

---

## 🛰️ NETWORK_LOGIC: Infrastructure Assessment

The `recon.sh` core is the primary system for mapping network boundaries and indentifying infrastructure assets.

### [ // ASSESSMENT_PROFILES ]

| Profile | Interface Flag | Objective | Visibility |
| :--- | :--- | :--- | :--- |
| **QUICK_DISCOVERY** | `--quick` | Rapid host identification via ARP/ICMP. | HIGH |
| **FULL_ENUMERATION** | `--full` | Comprehensive service & OS fingerprinting (-A). | VERY HIGH |
| **STEALTH_ASSESS** | `--stealth` | Packet fragmentation & decoy IP injection. | **LOW** |
| **VULN_AUDIT** | `--vuln` | Automated CVE NSE script execution. | MEDIUM |

### [ // OPERATIONAL_CONSIDERATIONS ]
- **Decoy Evasion**: When using `STEALTH_ASSESS`, its effectiveness depends on baseline network congestion. Excessive decoys on low-traffic subnets may trigger anomaly detection systems.
- **Timing Profiles**: Timing `T2` is recommended for balanced accuracy and evasion. `T1` is often too slow for standard assessments, while `T3+` may trigger network security alerts.

---

## 🎯 WIRELESS_LOGIC: Protocol Audit Suite

The `wifi_tools.sh` engine facilitates Layer 2 security assessments and protocol audits.

### [ // ASSESSMENT_VECTORS ]

*   **RF_INTERFACE_MANAGEMENT**: 
    - Toggle using `--monitor-on` / `--monitor-off`.
    - Manages driver states and terminates conflicting system processes.
*   **HANDSHAKE_ACQUISITION**: 
    - Analyzes the 4-way WPA handshake exchange.
    - Utilizes controlled deauthentication frames to evaluate client re-association security.
*   **PMKID_EXTRACTION**: 
    - Passive capture of RSN IE hashes from the first exchange.
    - **No client interaction required**. Ideal for low-profile security audits.
*   **WPS_ENTROPY_ANALYSIS**: 
    - Evaluation of random number generation in legacy WPS implementations.
    - Demonstrates vulnerabilities in weak PIN generation logic.

### [ // OPERATIONAL_CONSIDERATIONS ]
- **Interface Stability**: Ensure the wireless adapter is not locked by other processes. If the interface reports "Device or resource busy," toggle the Monitor Mode state within the dashboard.
- **Acquisition Reliability**: If active deauthentication fails to result in a handshake capture, it may indicate client distance issues or 802.11w (Management Frame Protection) implementation. Fall back to **PMKID_EXTRACTION** for passive analysis.

---

## 🤖 AUTOMATION_LOGIC: Workflow Orchestration

Scenarios are pre-configured assessment sequences designed for standardized security testing.

### [ // WORKFLOW_MODELS ]

1.  **WIRELESS_AUDIT_SEQUENCE**:
    - **Logic**: Automated monitor initialization -> Spectrum Scan -> Data acquisition.
    - **Context**: Systematic auditing of local wireless infrastructure.
2.  **SERVICE_ENUMERATION_SUITE**:
    - **Logic**: Comprehensive port mapping -> Service identification -> Asset discovery.
    - **Context**: Identification of unlinked web assets and service configurations.
3.  **LOW_VISIBILITY_RECON**:
    - **Logic**: Optimized timing profiles with packet fragmentation.
    - **Context**: Assessments within environments utilizing active intrusion detection.

### [ // OPERATIONAL_CONSIDERATIONS ]
- **Automation Constraints**: Automated workflows are resource-intensive. For environments requiring high precision or minimal signal footprint, manual tool orchestration is recommended.

---

## ⚙️ System Interface & Telemetry

### Telemetry Interpretation
The **Live Interface** utilizes unbuffered I/O for real-time visibility. If minor rendering delays occur, it is due to the backend's real-time regex parsing and intelligence extraction. Do not refresh the interface during an active process to maintain the transient log buffer.

### Process Termination
If a background process becomes unresponsive, utilize the **GLOBAL_STOP** control. This initiates a system-wide `SIGKILL` to all associated assessment processes to ensure immediate system stability.

### Intelligence Persistence
Assessment data is persisted in the following directories:
- `output/devices.json`: Cumulative host and device inventory.
- `output/reports/`: Complete process logs and metadata.

---

> **[ // SYSTEM_STANDBY ]**: Ensure all interfaces are restored to managed mode after the assessment is concluded.

*For deep technical flag references, see the [Technical Reference](./docs/TECHNICAL_REFERENCE.md).*
