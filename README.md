# 🌌 VoidPWN: Tactical Neural Console V3

VoidPWN is a professional-grade, automated network pentesting platform optimized for Raspberry Pi. It provides a high-fidelity "VoidOS" HUD for managing complex security operations through automation and intelligent device tracking.

![Dashboard Preview](https://img.shields.io/badge/Console-V3.0_RELEASE-cyan)
![Design](https://img.shields.io/badge/Aesthetic-Cyberpunk_HUD-magenta)

---

## � Cyber Security Tutorial Suite

Welcome, Operative. The platform is documented with an illustrated, tutorial-first approach. Explore the modules below to master the console:

### �️ [HUD Tactical Manual](./docs/HUD_MANUAL.md)
*   **Visual walkthrough** of every tab and button in the VoidOS interface.
*   Learn how the **Global Target Inventory** syncs across the entire platform.

### �️ [Network Intelligence Guide](./docs/NETWORK_INTEL.md)
*   **Technical Deep-Dive** into Nmap flags (`-sS`, `-sV`, `-A`).
*   Tutorial on the **Reconnaissance Pipeline**: from ARP sweeps to vulnerability identification.

### ⚔️ [Wireless Arsenal Manual](./docs/WIFI_ARSENAL.md)
*   **Step-by-step illustrations** of modern WiFi attacks.
*   Learn the physics behind **PMKID Sniper**, **MDK4 Chaos**, and **WPS Pixie-Dust**.

### 🤖 [Scenario Automation Guide](./docs/SCENARIO_GUIDE.md)
*   **Walkthroughs of Mission Workflows**: Stealth Recon, Web Application Hunting, and full WiFi Audits.
*   Understand the state-machine logic behind our **"One-Button"** automation.

---

## 🛠️ Quick Installation

### 1. Clone & Prep
```bash
git clone https://github.com/void0x11/VoidPWN.git
cd VoidPWN
sudo ./scripts/core/install_lcd.sh  # If using a TFT LCD screen
```

### 2. Install Tools
```bash
sudo ./scripts/core/install_tools.sh           # Standard Suite
sudo ./scripts/core/install_advanced_tools.sh  # Modern WiFi (MDK4, PMKID)
```

### 3. Initialize HUD
```bash
cd dashboard
sudo python3 server.py
# Console accessible at http://<PI_IP>:5000
```

---

## 📖 Deep Technical Manual
For a direct reference of script paths and non-visual user instructions, see the **[USER_GUIDE.md](./USER_GUIDE.md)**.

---
*Created by void0x11 for ethical security research.*
