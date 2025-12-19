# 🛰️ NETWORK_INTEL // SYSTEM_INTELLIGENCE

This document provides standardized operational protocols for the network discovery and reconnaissance capabilities of the VoidPWN platform.

---

## [ // ASSESSMENT_METHODOLOGIES ]

### 1. Asset Discovery (Quick Scan)
- **Script Target**: `recon.sh --quick <TARGET>`
- **Internal Command**:
  ```bash
  nmap -sn [target_subnet]
  ```
- **System Logic**: Performs multiple discovery attempts using ICMP echo requests, TCP SYN to port 443, TCP ACK to port 80, and ICMP timestamp requests by default. For local subnets, it utilizes ARP-level discovery.

### 2. Full Service Discovery (Deep Scan)
- **Script Target**: `recon.sh --full <TARGET>`
- **Internal Command**:
  ```bash
  nmap -sV -sC -O -A -p- -oA [output] [target]
  ```
- **Flag Breakdown**:
  - `-sV`: Probes open ports to determine service/version info.
  - `-sC`: Equivalent to `--script=default`; runs a set of safe, useful scripts.
  - `-O`: Employs TCP/IP stack fingerprinting to guess the remote Operating System.
  - `-A`: Enables OS detection, version detection, script scanning, and traceroute.
  - `-p-`: Scans every possible TCP port (1-65535).

### 3. Low-Visibility Reconnaissance
- **Script Target**: `recon.sh --stealth <TARGET>`
- **Internal Command**:
  ```bash
  nmap -sS -T2 -f -D RND:10 -oA [output] [target]
  ```
- **Detection Evasion Logic**:
  - `-sS (SYN Scan)`: Never completes the 3-way handshake, reducing log visibility on the target application layer.
  - `-T2 (Polite)`: Serializes port probes with a significant delay to evade rate-limiting IDS/IPS.
  - `-f (Fragmentation)`: Splits the IP header into multiple fragments to bypass simple stateless packet filters.
  - `-D RND:10 (Decoy)`: Spoofs 10 additional IP addresses in the scan to obscure the source origin.

### 4. Vulnerability Auditing
- **Script Target**: `recon.sh --vuln <TARGET>`
- **Internal Command**:
  ```bash
  nmap --script vuln -oA [output] [target]
  ```
- **Implementation**: Utilizes the Nmap Scripting Engine (NSE) to cross-reference identified versions against documented security vulnerabilities and common misconfigurations.

---

## [ // TECHNICAL_FLAG_REFERENCE ]

| Flag | Category | Description |
| :--- | :--- | :--- |
| `-sS` | Discovery | TCP SYN (Half-Open) scanning method. |
| `-O` | Fingerprinting | Operating System identification via stack analysis. |
| `-sV` | Identification | Service and version identification via banner grabbing. |
| `-f` | Evasion | IP header fragmentation. |
| `-T[0-5]` | Timing | Adjusts scan speed (0=Paranoid, 5=Insane). |
| `--script vuln` | Audit | NSE category for vulnerability identification. |

---
*For direct API mappings and script parameter definitions, see the [Technical Reference](./TECHNICAL_REFERENCE.md).*
