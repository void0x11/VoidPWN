# VoidPWN: Automated Penetration Testing Platform

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Platform: Raspberry Pi](https://img.shields.io/badge/Platform-Raspberry%20Pi-red.svg)](https://www.raspberrypi.org/)
[![Python: 3.8+](https://img.shields.io/badge/Python-3.8%2B-green.svg)](https://www.python.org/)

**VoidPWN** is a comprehensive, automated network security assessment platform designed for the Raspberry Pi. It provides a centralized web-based dashboard (HUD) for managing complex penetration testing operations, including network reconnaissance, wireless auditing, and automated attack scenarios—all through an intuitive interface optimized for portable deployment.

---

## 🎯 Key Features

### 🌐 Network Reconnaissance
- **Nmap Integration**: Quick, full, stealth, and vulnerability scans
- **Port Discovery**: Comprehensive service enumeration
- **OS Fingerprinting**: Automated operating system detection
- **Web Directory Fuzzing**: GoBuster integration for web application discovery

### 📡 Wireless Security Assessment
- **WPA/WPA2 Attacks**: Handshake capture, PMKID extraction, Evil Twin
- **Deauthentication**: Aggressive client disconnection with channel locking
- **WPS Exploitation**: Pixie Dust and Reaver-based PIN recovery
- **MDK4 Stress Testing**: Beacon flooding and authentication attacks
- **Wifite Integration**: Automated wireless network auditing

### 🤖 Automated Scenarios
- **Quick Check**: 5-minute rapid network assessment
- **Stealth Recon**: Low-profile network scanning with decoys
- **Web Application Audit**: Automated web vulnerability discovery
- **Wireless Audit**: Complete WiFi penetration testing workflow

### 📊 Operational Dashboard
- **Live HUD**: Real-time attack monitoring and log streaming
- **Device Inventory**: Automatic target tracking and metadata management
- **Report System**: Comprehensive operation logs with download capability
- **Stop All Attacks**: Global kill switch for active operations
- **Display Management**: TFT/HDMI switching for portable deployment

---

## 🛠️ Hardware Requirements

### Recommended Configuration

#### Core Hardware
- **Raspberry Pi 4 Model B** (4GB+ RAM recommended)
  - ARM Cortex-A72 quad-core processor
  - Dual-band WiFi (2.4GHz/5GHz) for management interface
  - Gigabit Ethernet for wired network access

#### Display
- **Waveshare 3.5" TFT LCD** (480x320 resolution)
  - SPI interface for low-latency rendering
  - Touch-enabled for field operations
  - HDMI output also supported for desktop use

#### Wireless Adapter
- **Alfa AWUS036ACH** (or compatible)
  - Realtek RTL8812AU chipset
  - Monitor mode and packet injection support
  - Dual-band (2.4GHz/5GHz) operation
  - High-gain external antenna

#### Storage
- **32GB+ microSD Card** (Class 10 or UHS-I)
  - Fast read/write for log storage
  - Sufficient space for captured handshakes and reports

#### Power Supply
- **Official Raspberry Pi 4 Power Supply** (5V/3A USB-C)
  - Stable power delivery for sustained operations
  - Portable battery pack compatible (15W minimum)

### Alternative Hardware
- **Raspberry Pi 3B+**: Supported but slower performance
- **Other WiFi Adapters**: Any adapter with monitor mode support (e.g., Alfa AWUS036NHA, TP-Link TL-WN722N v1)
- **HDMI Display**: Any HDMI monitor can replace the TFT screen

---

## 📦 Installation

### Prerequisites
- Raspberry Pi OS (Kali Linux ARM recommended for pre-installed tools)
- Python 3.8 or higher
- Root/sudo access

### Quick Start

#### 1. Clone Repository
```bash
git clone https://github.com/void0x11/VoidPWN.git
cd VoidPWN
```

#### 2. Install Dependencies
```bash
# Core security tools (aircrack-ng, nmap, reaver, etc.)
sudo ./scripts/core/setup.sh

# Optional: Install TFT LCD drivers (run LAST, will reboot)
sudo ./scripts/core/install_lcd.sh
```

#### 3. Launch Dashboard
```bash
cd dashboard
sudo python3 server.py
```

#### 4. Access Web Interface
Open a browser and navigate to:
```
http://<RASPBERRY_PI_IP>:5000
```

---

## 📚 Documentation

### User Guides
- **[User Guide](./USER_GUIDE.md)**: Complete operational manual with tutorials
- **[Hardware Setup](./docs/HARDWARE_SETUP.md)**: Detailed hardware assembly and configuration

### Feature Documentation
- **[Feature Guide](./docs/FEATURE_GUIDE.md)**: Comprehensive explanation of every feature
- **[WiFi Arsenal](./docs/WIFI_ARSENAL.md)**: Wireless attack methodologies
- **[Network Intel](./docs/NETWORK_INTEL.md)**: Reconnaissance techniques
- **[Scenario Guide](./docs/SCENARIO_GUIDE.md)**: Automated workflow documentation

### Technical Reference
- **[API Reference](./docs/API_REFERENCE.md)**: REST API endpoints and schemas
- **[Technical Reference](./docs/TECHNICAL_REFERENCE.md)**: Architecture and internals
- **[Attack Reference](./docs/ATTACK_REFERENCE.md)**: Complete attack vector catalog

### Development
- **[Development Guide](./docs/DEVELOPMENT.md)**: Contributing and extending VoidPWN

---

## 🚀 Quick Example

### Running a WiFi Handshake Capture

1. **Navigate to WiFi Attacks tab**
2. **Click "REFRESH NETWORKS"** to scan for access points
3. **Select target network** from the list
4. **Click "HANDSHAKE"** to initiate capture
5. **Monitor progress** in the Live HUD
6. **View results** in the Reports tab

---

## 🔒 Legal Disclaimer

**VoidPWN is intended for authorized security research and ethical penetration testing only.**

- Only use on networks you own or have explicit written permission to test
- Unauthorized access to computer networks is illegal in most jurisdictions
- The developers assume no liability for misuse of this software

---

## 🤝 Contributing

Contributions are welcome! Please see [DEVELOPMENT.md](./docs/DEVELOPMENT.md) for guidelines.

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 👤 Author

**void0x11** - [GitHub](https://github.com/void0x11)

---

## 🙏 Acknowledgments

- **Aircrack-ng Suite**: Wireless security assessment tools
- **Nmap Project**: Network discovery and security auditing
- **Reaver/Pixiewps**: WPS vulnerability research
- **Wifite**: Automated wireless auditing framework
- **Flask**: Python web framework
- **Raspberry Pi Foundation**: Affordable computing platform

---

*Developed for authorized security research and ethical penetration testing.*
