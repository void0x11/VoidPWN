# VoidPWN: Automated Penetration Testing Platform

VoidPWN is an automated network security assessment platform optimized for the Raspberry Pi. It provides a centralized web interface (HUD) for managing complex security operations, network reconnaissance, and wireless audits through intelligent automation and device tracking.

---

## Technical Documentation Suite

The platform includes comprehensive technical guidance across several modules:

### [System Overview and HUD Manual](./docs/HUD_MANUAL.md)
*   Detailed walkthrough of the web-based operation console.
*   Instructions for global target inventory management.

### [Network Reconnaissance Guide](./docs/NETWORK_INTEL.md)
*   Technical analysis of Nmap scanning methodologies (SYN scans, version detection, OS fingerprinting).
*   Overview of the reconnaissance pipeline and stealth scanning theory.

### [Wireless Assessment Guide](./docs/WIFI_ARSENAL.md)
*   Methodology for Layer 2 wireless assessments.
*   Technical breakdown of PMKID capture, MDK4 stress testing, and WPS vulnerability research.

### [Scenario Automation Guide](./docs/SCENARIO_GUIDE.md)
*   Technical workflows for multi-stage missions (Stealth Recon, Web Application Audits, Wireless Audits).
*   Operation of the state-machine logic for automated toolchain execution.

### [Attack and Feature Reference](./docs/ATTACK_REFERENCE.md)
*   Technical master reference for all integrated assessment vectors.
*   Theoretical background and tool-specific configuration details.

---

## Installation and Deployment

### 1. Repository Acquisition
```bash
git clone https://github.com/void0x11/VoidPWN.git
cd VoidPWN
sudo ./scripts/core/install_lcd.sh  # Optional for TFT LCD support
```

### 2. Dependency Installation
```bash
sudo ./scripts/core/install_tools.sh           # Core security suite
sudo ./scripts/core/install_advanced_tools.sh  # Specialized wireless and MDK4 tools
```

### 3. Service Initialization
```bash
cd dashboard
sudo python3 server.py
# The web interface is accessible at http://<PI_IP>:5000
```

---

## Deep Technical Reference
For detailed script paths and internal configuration logic, refer to the **[Technical User Guide](./USER_GUIDE.md)**.

---
*Developed for authorized security research and ethical penetration testing.*
