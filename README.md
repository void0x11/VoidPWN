<h1 align="center">
  <img src="https://socialify.git.ci/void0x11/VoidPWN/image?description=1&descriptionEditable=Cyberpunk%20%26%20Watch%20Dogs%20Themed%20CtOS%20Breach%20Framework&font=Inter&name=1&owner=1&pattern=Circuit%20Board&theme=Dark" width="100%" alt="VoidPWN Logo">
</h1>

<p align="center">
  <img src="assets/Gemini_Generated_Image_ubqnxrubqnxrubqn.png" width="100%" alt="VoidPWN Hardware Platform">
</p>

<p align="center">
  <a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="License: MIT"></a>
  <a href="https://www.raspberrypi.org/"><img src="https://img.shields.io/badge/Platform-Raspberry%20Pi-red.svg" alt="Platform: Raspberry Pi"></a>
  <a href="https://www.python.org/"><img src="https://img.shields.io/badge/Python-3.8%2B-green.svg" alt="Python: 3.8+"></a>
  <img src="https://img.shields.io/badge/Focus-Hardware%20Security-blue.svg" alt="Focus: Hardware Security">
  <img src="https://img.shields.io/badge/Type-Pentesting%20Framework-orange.svg" alt="Type: Pentesting Framework">
</p>

<p align="center">
  <img src="assets/Pi-Isometricv2.jpg" width="100%" alt="VoidPWN Hardware Isometric View">
</p>

<p align="center">
  <b>VoidPWN</b> is a high-performance, mobile-optimized Command-and-Control (C2) framework engineered for <b>Hardware Security Assessments</b> and <b>Enterprise Network Auditing</b>. It streamlines complex network discovery and wireless security assessments by consolidating advanced audit vectors into a unified Raspberry Pi hardware platform.
</p>


---

## 🏗️ System Architecture: The Core C2 Engine

VoidPWN is engineered as a **Modular Security Orchestrator**, decoupling the high-level Command & Control (C2) interface from the underlying execution engines.

### [ FUNCTIONAL_LAYERS ]
```mermaid
graph TB
    subgraph "Presentation & Control"
        UI[Web Dashboard - JS/CSS]
        CLI[voidpwn.sh - Interactive Bash]
    end

    subgraph "Application Core (C2 Logic)"
        SVR[Flask API Server]
        DMG[DeviceManager - Regex Intel]
        RMG[ReportManager - Persistence]
        HUD[Live HUD - Async Data Stream]
    end

    subgraph "Execution Engine (Security Suite)"
        SCN[Scenarios.sh - Orchestration]
        WIFI[wifi_tools.sh - WiFi Suite]
        REC[recon.sh - Nmap Suite]
        PYT[Python Tools - Scapy/Traffic]
    end

    subgraph "Infrastructure (Hardware Interface)"
        MON[Monitor Mode Driver]
        SPI[3.5' TFT SPI/Framebuffer]
        PIS[PiSugar Power Management]
    end

    UI <-->|REST API| SVR
    CLI <-->|Direct Invoke| SCN
    SVR -->|Spawn Subprocess| SCN
    SCN --> WIFI & REC & PYT
    WIFI & REC --> MON
    SVR --> SPI
```

### [ SYSTEM_LIFECYCLE_LOGIC ]
The workflow for a standard security assessment (e.g., "Network Reconnaissance") across the stack:

```mermaid
sequenceDiagram
    participant Res as Security Researcher
    participant API as Flask C2 API
    participant Proc as Subprocess (stdbuf)
    participant Thread as Log Capture Thread
    participant Intel as Regex Heuristics
    participant HUD as Live Interface

    Security Researcher->>API: POST /api/action/recon
    API->>Proc: Spawn Binary (unbuffered)
    API-->>Security Researcher: Returns PID/Success
    loop Stream Execution
        Proc->>Thread: Raw stdout line
        Thread->>Intel: Pass line for analysis
        Intel->>Intel: Match IP/MAC patterns
        Intel-->>API: Update Inventory DB
        Thread->>HUD: Push to circular log back-end
        HUD-->>Security Researcher: SSE/Poll update
    end
    Proc->>API: Process Exit (Code 0)
    API-->>Security Researcher: Broadcast Assessment Complete
```

---

## 🔬 Engineering & Technical Implementation

### Asynchronous C2 Orchestration
VoidPWN utilizes a **Threaded Producer-Consumer** pattern for efficient process management. By leveraging `stdbuf -oL`, the framework forces binaries such as `nmap` and `airodump-ng` to bypass standard memory buffering. this enables **millisecond-latency interface updates**, providing real-time visibility into long-running assessment processes.

### Real-time Intelligence Extraction
The framework incorporates a **Regex-based Heuristic Engine** (`parse_inventory_info`) that audits live process output in real-time to identify:
- **Network Topology Artifacts**: Automatically populating the host inventory from active scanning results.
- **Physical Device Signatures**: Extracting MAC addresses and BSSID identifiers for localized device tracking.

### Hardware Abstraction Layer
The display engine facilitates dynamic switching between the HDMI output and the SPI-based TFT interface. This is achieved through direct modification of the `/boot/config.txt` parameters and re-initialization of the `fbcp` (framebuffer copy) service, enabling seamless transitions between portable and workstation-based operational modes.

---

## 💻 Cross-Platform Operational Interface
VoidPWN provides a responsive, web-based Command-and-Control interface accessible across diverse hardware stacks. Researchers can manage assessments from a **Raspberry Pi TFT**, a **Standard Workstation**, or a **Mobile Device** with full real-time synchronization.

<p align="center">
  <img src="assets/phone.jpeg" width="300" alt="Mobile Dashboard Telemetry">
  <br>
  <i>Synchronized mobile interface showing real-time system logs and process telemetry.</i>
</p>

### 🛡️ Network Infrastructure Enumeration
Deploy sophisticated **Nmap** profiles for rapid host discovery and network mapping. Integrated OS fingerprinting and service discovery provide comprehensive situational awareness during internal security audits.
<p align="center">
  <img src="assets/Net-Discovery.jpeg" width="85%" alt="Network Reconnaissance">
</p>

### 📡 Wireless Security Suite
Execute advanced wireless assessment vectors including **WPA/WPA2 Handshake capture**, **PMKID extraction**, and **Authorized Rogue AP** simulations. Optimized for auditing protocol resilience and credential management.
<p align="center">
  <img src="assets/attack.png" width="85%" alt="Wireless Security Assessment">
</p>

### 📊 Real-time Assessment Logs
Monitor long-running processes through the **Live Interface**, featuring synchronized log streaming. Post-assessment analysis is facilitated through comprehensive, exportable session reports.
<p align="center">
  <img src="assets/Report&Logging.jpeg" width="85%" alt="System Logs">
</p>

### [ SYSTEM_MODALITIES ]
*   **INFRA_RECON**: Automated network mapping and host profiling.
*   **WIRELESS_AUDIT**: WPA/WPA2 protocol resilience and handshake acquisition.
*   **AUTOMATED_ASSESSMENT**: Condition-based security sequences for rapid auditing.
*   **REMOTE_C2**: Web-integrated telemetry and remote platform management.

---

## 🔬 Assessment Methodologies

### [ RECON_LOGIC ]
VoidPWN utilizes optimized **Nmap T3/T4** profiles for thorough perimeter analysis. Assessment phases include:
1. **Host Discovery**: ICMP/ARP sweeps for inventory building.
2. **Service Enumeration**: Comprehensive version detection (-sV) and OS fingerprinting (-O).
3. **Vulnerability Mapping**: Targeted NSE (Nmap Scripting Engine) execution for known service weaknesses.

### [ WIRELESS_SECURITY_LOGIC ]
The wireless assessment engine automates the 802.11 audit lifecycle:
*   **WPA/WPA2 Resilience**: Automated handshake acquisition and PMKID extraction for credential strength testing.
*   **Authorized Rogue AP**: Deployment of test-specific access points for auditing client connection behaviors.
*   **Protocol Hardening**: Integrated stress-testing of access points to evaluate Denial-of-Service (DoS) resilience.

---

## ⚒️ Security Assessment Capabilities

### Network Intelligence
*   **Service Analysis**: Automated host discovery and infrastructure profiling.
*   **Vulnerability Assessment**: High-fidelity Nmap scripting for surface analysis of connected devices.
*   **Directory Enumeration**: Integrated GoBuster for discovery of unlinked web assets.

### Wireless Research
*   **Automated Auditing**: Wifite-powered workflows for streamlined protocol testing.
*   **Credential Strength**: WPA/WPS assessment vectors with targeted channel locking.
*   **Spectrum Analysis**: Real-time monitoring of signal density and target metadata.

### Automation & Workflows
*   **Rapid Audit**: Pre-configured network assessment routines (~5 minutes).
*   **Stealth Profiling**: Low-profile scanning utilizing decoy traffic and timing adjustments.
*   **Full Wireless Assessment**: End-to-end automated penetration testing workflows.

### Deployment & Interface
*   **Live Console**: Sub-second latency process monitoring and data visualization.
*   **Unified Dashboard**: Global process management and host inventory tracking.
*   **Hardware Integration**: Automated SPI TFT and HDMI output switching.

---

## Hardware & Deployment

### Recommended Build
| Component | Specification | Description |
| :--- | :--- | :--- |
| **Processor** | Raspberry Pi 4B (4GB+) | Core computational unit for concurrent scanning. |
| **Radio** | Alfa AWUS036ACH | Dual-band support with RTL8812AU injection. |
| **Display** | Waveshare 3.5" TFT | Local field monitoring and touch-enabled HUD. |
| **Storage** | 32GB+ UHS-I microSD | High-speed logging and handshake storage. |

### [ SYSTEM_INITIALIZATION ]

1. **PROVISION_FILES**:
   ```bash
   # Clone security framework
   git clone https://github.com/void0x11/VoidPWN.git && cd VoidPWN
   ```
2. **RESOLVE_DEPENDENCIES**:
   ```bash
   # Deployment of core security engines and hardware drivers
   sudo ./scripts/core/setup.sh
   sudo ./scripts/core/install_lcd.sh
   ```
3. **START_FRAMEWORK**:
   ```bash
   # Initializing the C2 Dashboard
   cd dashboard && sudo python3 server.py
   ```

---

## 📚 Documentation

### User Guides
- **[Operation Manual](./USER_GUIDE.md)**: Comprehensive guide for security researchers.
- **[Hardware Setup](./docs/HARDWARE_SETUP.md)**: Detailed hardware assembly and configuration.

### Feature Documentation
- **[Feature Catalog](./docs/FEATURE_GUIDE.md)**: In-depth technical breakdown of every module.
- **[WiFi Methodologies](./docs/WIFI_ARSENAL.md)** / **[Recon Techniques](./docs/NETWORK_INTEL.md)**.
- **[Scenario Guide](./docs/SCENARIO_GUIDE.md)**: Automated workflow documentation.

### Technical Reference
- **[Architecture & Design](./docs/TECHNICAL_REFERENCE.md)**: System internals and component orchestration.
- **[Attack Catalog](./docs/ATTACK_REFERENCE.md)**: Details on implemented attack vectors.

---

## Quick Example

### Running a WiFi Handshake Capture

1. **Navigate to Wireless tab**.
2. **Initialize Spectrum Refresh** to identify target access points.
3. **Select target network** for assessment.
4. **Initialize Handshake Acquisition** to start the capture process.
5. **Monitor Telemetry** in the Live Interface.
6. **View results** in the Reports tab.

---

## Legal & Ethical Compliance
**VoidPWN is security research platform.** Use is permitted only on infrastructure where the operator has explicit, written authorization. All data gathered must be handled according to local data protection laws. The developers assume no liability for unauthorized or misuse of this software.

---

## License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## Maintainer
**void0x11** - [GitHub Profile](https://github.com/void0x11) | Research and Development for Advanced Security Auditing.

---

## Acknowledgments
- **Aircrack-ng Suite**: Wireless security assessment tools.
- **Nmap Project**: Network discovery and security auditing.
- **Reaver/Pixiewps**: WPS vulnerability research.
- **Wifite**: Automated wireless auditing framework.
- **Flask**: Python web framework.
- **Raspberry Pi Foundation**: Affordable computing platform.

---

*This project is developed for authorized security assessments and educational purposes.*
