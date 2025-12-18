# 🛡️ Network Intelligence & Recon Tutorial

This module explains how VoidPWN discovers, identifies, and catalogues devices on a network. 

## 🛰️ The Reconnaissance Pipeline

VoidPWN follows a professional 3-stage intelligence gathering process:

```mermaid
graph LR
    A[Host Discovery] --> B[Service Fingerprinting]
    B --> C[Vulnerability Analysis]
    C --> D[Intelligence Storage]
```

### Stage 1: Host Discovery (RADAR)
Before we can attack, we must know what is alive.
*   **Protocol**: ARP & ICMP Echo (Ping).
*   **Nmap Flag**: `-sn` (No Port Scan).
*   **Objective**: Find IP and MAC addresses in the subnet without alerting software-based firewalls.

### Stage 2: Service Fingerprinting (DEEP SCAN)
Once a host is selected, we perform deep inspection.
*   **Tool**: `nmap`
*   **Primary Flags**: `-sV -sC -O -A`
    *   `-sV`: Service version detection (e.g., Apache 2.4.41).
    *   `-sC`: Default script scanning (identifies common defaults).
    *   `-O`: OS Fingerprinting (identifies Linux vs Windows vs IoT).
    *   `-A`: Aggressive mode (combines the above for high detail).
*   **Objective**: Identify the "Attack Surface".

### Stage 3: Vulnerability Analysis (STEALTH/VULN)
*   **Stealth**: `nmap -sS -T2 -f -D RND:10`
    *   `T2`: Slow timing to avoid rate-limiting.
    *   `-f`: Fragmented packets to slip through simple firewalls.
    *   `-D`: Uses Decoy IPs to mask the Pi's true identity.
*   **Vuln**: `nmap --script vuln`
    *   Checks the host against the **Nmap Scripting Engine (NSE)** database for known CVEs.

---

## 📊 Technical Reference Table

| Scan Mode | Dash Tab | CLI Flag Equivalent | Tutorial Use Case |
| :--- | :--- | :--- | :--- |
| **Quick Scan** | RADAR | `nmap -sn` | Initial entry into a network. Fast. |
| **Deep Scan** | RADAR/RECON | `nmap -sV -sC -O -A` | Full intel gathering on a target. |
| **Stealth** | RECON | `nmap -sS -T2 -f` | Bypassing IDS/IPS detection. |
| **Vuln** | RECON | `nmap --script vuln` | Identifying low-hanging exploits. |

---

## 💡 Operative's Tip: Parsing Results
When a scan finishes, VoidPWN parses the `.xml` output into the **Details Modal**. 
- **Green Ports (80, 443, 8080)**: Web servers. Highly exploitable.
- **Blue Ports (22, 23)**: Remote access. Critical targets.
- **Port 445**: SMB. Target these for internal network pivoting.

---
*Next: [WIFI_ARSENAL.md](./WIFI_ARSENAL.md) for wireless operations.*
