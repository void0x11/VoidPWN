# Network Reconnaissance Guide

This document provides technical guidance on the network discovery and reconnaissance capabilities of VoidPWN, focusing on Layer 3 and Layer 4 scanning methodologies.

---

## Technical Methodology

Network reconnaissance in VoidPWN is structured into a logical pipeline that prioritizes discovery, identification, and vulnerability assessment.

### 1. Host Discovery
The primary objective of host discovery is to identify active devices within a target subnet while minimizing network traffic and detection risk.
*   **Mechanism**: ARP-based discovery for local subnets and ICMP echo requests (ping) for routed networks.
*   **Implementation**: `nmap -sn`. This mode suppresses port scanning, focusing solely on host presence.
*   **Platform Integration**: The **QUICK SCAN** feature in the dashboard automates this process, populating the device inventory with detected IP and MAC addresses.

### 2. Service and OS Fingerprinting
Once hosts are identified, deeper inspection is conducted to determine the host's attack surface.
*   **Service Detection**: Version scanning (`-sV`) queries open ports for service-specific banners and response patterns to identify software versions (e.g., Apache 2.4.x).
*   **OS Detection**: Analyzing micro-behaviors in the TCP/IP stack (e.g., TTL, IP ID sequences, TCP window sizes) to identify the underlying operating system.
*   **Tools**: `nmap`.

### 3. Vulnerability Identification
Cross-referencing identified services against known vulnerability databases and execution of targeted security scripts.
*   **Implementation**: Utilization of the **Nmap Scripting Engine (NSE)** with the `vuln` script category to identify common misconfigurations and documented CVEs.

---

## Stealth Scanning Strategies

VoidPWN provides specialized scanning profiles for assessments in monitored environments where detection must be minimized.

### SYN Stealth Scanning
The SYN scan (`-sS`) is the default privileged scan method. 
*   **Technique**: Sends a SYN packet and waits for a SYN/ACK. Upon receipt, it immediately sends a RST packet to terminate the connection before the 3-way handshake is completed.
*   **Benefit**: This prevents the connection from being recorded by application-level logs that only trigger on established sessions.

### Packet Fragmentation and Decoys
*   **Fragmentation (`-f`)**: Splits the TCP header across multiple small packets to complicate packet inspection by simple stateless firewalls.
*   **Decoys (`-D`)**: Includes multiple spoofed "Decoy" IP addresses in the scan. The target's Intrusion Detection System (IDS) will report simultaneous scans from all decoy addresses, obscuring the platform's actual IP address.

---

## Tool Reference

| Profile | Core Command | Primary Objective |
| :--- | :--- | :--- |
| **Discovery** | `nmap -sn` | Map active hosts in subnet |
| **Full Recon** | `nmap -sV -sC -O` | Detailed service and OS mapping |
| **Stealth Scan** | `nmap -sS -T2 -f` | Evasive reconnaissance |
| **Vuln Audit** | `nmap --script vuln` | Automated CVE identification |

---
*For a comprehensive theoretical analysis, refer to the [Attack and Feature Reference](./ATTACK_REFERENCE.md).*
