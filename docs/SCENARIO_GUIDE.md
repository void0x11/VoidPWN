# 🤖 AUTOMATED_WORKFLOWS // SYSTEM_ORCHESTRATION

Automated scenarios in VoidPWN coordinate multiple security tools into single-click workflows.

---

## [ // WORKFLOW_ORCHESTRATION_LOGIC ]

### 1. Wireless Security Audit
- **Objective**: Sequential assessment of all local BSSIDs.
- **Workflow Steps**:
  1.  **Monitor Mode**: Calls `wifi_tools.sh --monitor-on` to initialize the interface.
  2.  **Discovery Phase**: Executes `timeout [duration] airodump-ng -w [output] --output-format csv wlan1mon`.
  3.  **Target Aggregation**: The script parses `scan-01.csv` to catalogue available networks and their signal metrics.
  4.  **Capture Phase**: Attempts PMKID extraction and WPA handshake capture on high-signal targets.
  5.  **Audit Termination**: Calls `wifi_tools.sh --monitor-off` to restore standard networking services.

### 2. Stealth Network Reconnaissance
- **Objective**: Asset mapping with significant focus on IDS/IPS bypass.
- **Workflow Steps**:
  1.  **SYN Probing**: `nmap -sS -T2 -f --data-length 25 -D RND:10 [target]`. Uses 25-byte data padding and 10 random decoys.
  2.  **Service Fingerprinting**: Slow interrogation using `nmap -sV -T1 --version-intensity 0 [target]`. 
  3.  **Encapsulation**: The entire workflow is executed within a detached process, allowing the researcher to terminate the local session without interrupting the background scan process.

### 3. Web Service Intelligence
- **Objective**: Full-stack audit of HTTP/HTTPS services.
- **Workflow Steps**:
  1.  **Port Discovery**: `nmap -p 80,443,8080,8443 --open [network]`.
  2.  **Asset Identification**: For each identified host, executes `WhatWeb` to determine the technology stack.
  3.  **Directory Brute-Force**: Launches `GoBuster` dir fuzzing:
      ```bash
      gobuster dir -u http://[host] -w /usr/share/wordlists/dirb/common.txt
      ```
  4.  **Vulnerability Sweep**: Sequential execution of `Nikto` for generic flaws and `SQLMap --crawl=2` for database vulnerabilities.

---

## [ // WORKFLOW_COMPARISON_MATRIX ]

| Workflow Profile | Key Tools Chained | Orchestration Logic |
| :--- | :--- | :--- |
| **Wireless Audit** | airodump, hcxdumptool, aireplay-ng | Signal-priority loop |
| **Stealth Recon** | nmap (Evasive flags) | Polite timing + False decoys |
| **Web Service Hunt** | nmap, gobuster, nikto, sqlmap | Recursive discovery |
| **Quick Discovery** | nmap -sn, nmap -T4 | Optimized parallel probing |

---
*For direct API mappings and script parameter definitions, see the [Technical Reference](./TECHNICAL_REFERENCE.md).*
