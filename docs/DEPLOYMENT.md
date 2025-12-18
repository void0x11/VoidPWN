# VoidPWN Deployment Guide

## Step-by-Step Deployment to Raspberry Pi

### Prerequisites
- Kali Linux ARM flashed and booting
- SSH enabled and working
- Pi connected to internet
- LCD disconnected (HDMI working)

---

## Method 1: Git Clone (Recommended)

### On Your Raspberry Pi:

```bash
# SSH into your Pi
ssh kali@<PI_IP>

# Clone the repository
cd ~
git clone https://github.com/void0x11/VoidPWN.git
cd VoidPWN

# Make scripts executable
chmod +x *.sh */*/*.sh

# Run setup
sudo ./scripts/core/setup.sh
```

---

## Method 2: Direct Transfer from Windows

### From Your Windows Machine:

```bash
# Navigate to the project directory
cd C:\Users\ahmedamin\Github\VoidPWN

# Transfer to Pi using SCP (requires SSH client)
scp -r . kali@<PI_IP>:~/VoidPWN/
```

### Then on the Pi:

```bash
ssh kali@<PI_IP>
cd ~/VoidPWN
chmod +x *.sh */*/*.sh
sudo ./scripts/core/setup.sh
```

---

## Method 3: USB Transfer

1. Copy the entire `VoidPWN` folder to a USB drive
2. Plug USB into Raspberry Pi
3. Mount and copy:

```bash
# Find USB device
lsblk

# Mount USB (assuming it's /dev/sda1)
sudo mount /dev/sda1 /mnt

# Copy files
cp -r /mnt/VoidPWN ~/
cd ~/VoidPWN

# Make executable
chmod +x *.sh */*/*.sh

# Run setup
sudo ./scripts/core/setup.sh
```

---

## Installation Checklist

### 1. Initial Setup (30-60 minutes)

```bash
cd ~/VoidPWN
sudo ./scripts/core/setup.sh
```

This installs:
- All pentesting tools (aircrack, nmap, metasploit, etc.)
- WiFi adapter configuration
- PiSugar battery management
- Auto-login configuration
- Power optimizations
- System shortcuts

### 2. Reboot

```bash
sudo reboot
```

### 3. Verify Installation

```bash
# Check if voidpwn command works
voidpwn

# Or run directly
cd ~/VoidPWN
./voidpwn.sh
```

### 4. Test WiFi Adapter

```bash
# Plug in ALFA adapter
# Check detection
iwconfig

# Should see:
# wlan0 - Built-in WiFi
# wlan1 - ALFA adapter

# Test monitor mode
sudo ./scripts/network/wifi_tools.sh --monitor-on
iwconfig  # Should see wlan1mon
sudo ./scripts/network/wifi_tools.sh --monitor-off
```

### 5. Optional: Install Additional Tools

```bash
sudo ./scripts/core/install_tools.sh
```

Choose from menu:
1. Advanced wireless tools
2. Social Engineering Toolkit
3. Post-exploitation frameworks
4. Forensics tools
5. Reverse engineering tools
6. Mobile analysis tools

### 6. Install LCD Display (Required for Touch)
**WARNING:** This step will reboot your Pi and switch output from HDMI to the LCD.

```bash
sudo ./scripts/core/install_lcd.sh
```

### 7. Enable Touch Screen Interface (Kiosk Mode)
This configures the Pi to auto-login and launch the VoidPWN Dashboard control panel on boot.

```bash
sudo ./scripts/core/setup_kiosk.sh
```

### 8. Final Reboot
Reboot to apply all changes and launch the interface.

```bash
sudo reboot
```

---

## Post-Installation Verification

1. **Display:** The 3.5" screen should show the VoidPWN Dashboard.
2. **Touch:** You should be able to tap buttons (e.g., "REFRESH ALL").
3. **WiFi:** The dashboard should show "ADAPTER: DETECTED".

---

## Switching Display Modes

### Switch to HDMI (Desktop/CLI)
If you need to use a monitor or diagnose issues:
1. Tap **SWITCH TO HDMI** on the Dashboard Control Panel.
2. OR run via SSH: `sudo ./scripts/core/restore_hdmi.sh`

### Switch back to LCD
Run the installer again: `sudo ./scripts/core/install_lcd.sh`

## Testing Your Setup

### Test 1: WiFi Scanning

```bash
sudo ./scripts/network/wifi_tools.sh --scan
```

Should show nearby WiFi networks.

### Test 2: Network Discovery

```bash
sudo ./scripts/network/recon.sh --discover
```

Should show devices on your network.

### Test 3: Interactive Menu

```bash
voidpwn
```

Should display the main menu.

---

## Post-Installation Configuration

### Configure WiFi Interface

If your ALFA adapter is on a different interface:

```bash
# Edit wifi_tools.sh
nano ~/VoidPWN/scripts/network/wifi_tools.sh

# Change line 18:
INTERFACE="wlan1"  # Change to your interface name
```

### Set Default Wordlist

```bash
# Extract rockyou.txt
sudo gunzip /usr/share/wordlists/rockyou.txt.gz

# It's already configured in the scripts
```

### Configure Auto-Start (Optional)

To launch VoidPWN menu on boot:

```bash
# Add to .bashrc
echo "voidpwn" >> ~/.bashrc
```

---

## Remote Access Setup

### Find Your Pi's IP

```bash
hostname -I
# or
ip a | grep inet
```

### SSH from Another Computer

```bash
ssh kali@<PI_IP>
```

### Access PiSugar Web Interface

Open browser: `http://<PI_IP>:8421`

---

## First Attack Test (Legal Network Only)

### Capture WiFi Handshake

```bash
# 1. Scan
sudo ./scripts/network/wifi_tools.sh --scan
# Note the BSSID and Channel of YOUR network

# 2. Capture handshake
sudo ./scripts/network/wifi_tools.sh --handshake <BSSID> <CHANNEL>

# 3. Crack (if you have the password for testing)
sudo ./scripts/network/wifi_tools.sh --crack ~/VoidPWN/output/captures/handshake-01.cap
```

---

## Troubleshooting

### Setup Script Fails

```bash
# Check internet connection
ping google.com

# Update package lists
sudo apt update

# Try setup again
sudo ./scripts/core/setup.sh
```

### WiFi Adapter Not Working

```bash
# Check USB connection
lsusb | grep -i alfa

# Try different USB port (use USB 3.0 - blue port)

# Restart network manager
sudo systemctl restart NetworkManager
```

### Permission Denied Errors

```bash
# Make sure scripts are executable
chmod +x ~/VoidPWN/voidpwn.sh ~/VoidPWN/scripts/*/*.sh

# Run with sudo for system changes
sudo ./scripts/core/setup.sh
```

### Out of Space

```bash
# Check disk space
df -h

# Clean up
sudo apt clean
sudo apt autoremove
```

---

## Expected Resource Usage

| Component | Requirement |
|-----------|-------------|
| **Disk Space** | Approximately 10GB after full install |
| **RAM** | 2GB minimum, 8GB recommended |
| **Installation Time** | 30-60 minutes |
| **Battery Life** | 8-10 hours typical use |

---

## Updating VoidPWN

```bash
cd ~/VoidPWN
git pull
chmod +x *.sh */*/*.sh
```

---

## Need Help?

1. Check [docs/QUICKSTART.md](docs/QUICKSTART.md)
2. Review script help: `./script.sh --help`
3. Check Kali docs: https://www.kali.org/docs/

---

## Deployment Complete

You should now have:
- Fully functional VoidPWN device
- All pentesting tools installed
- WiFi adapter configured
- Remote access enabled
- Interactive menu system
- Automated attack scripts

Happy ethical hacking.
