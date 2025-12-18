# Scenario Automation Guide

Automated scenarios in VoidPWN are designed to orchestrate complex toolchains into streamlined workflows. These scenarios leverage a state-machine logic to execute multi-stage security assessments with minimal manual intervention.

---

## Technical Workflows

### 1. Wireless Security Audit
*   **Objective**: Automated identification and vulnerability assessment of local wireless access points.
*   **Toolchain**: `airodump-ng` -> `hcxdumptool` -> `aireplay-ng` -> `aircrack-ng`.
*   **Workflow Logic**:
    1.  **Passive Discovery**: Interface initialization and background sniffing to catalogue BSSIDs and signal metrics.
    2.  **Clientless Assessment**: Execution of `hcxdumptool` for a defined duration to attempt PMKID hash extraction from all detected APs.
    3.  **Active Assessment**: For networks with active clients, the platform executes targeted deauthentication bursts to capture the WPA 4-way handshake.
*   **Result Persistence**: All captured hashes and logs are timestamped and archived for offline analysis.

### 2. Stealth Network Reconnaissance
*   **Objective**: Subnet mapping and service identification in monitored or restrictive environments.
*   **Tool**: `nmap` (Configured for evasion).
*   **Evasion Logic**:
    - **Timing (T2)**: Implementation of a polite timing template to reduce the frequency of probes, staying below most IDS rate-limiting thresholds.
    - **Decoy Scanning**: Inclusion of randomized decoy IP addresses in the packet headers to obscure the origin of the scan.
*   **Workflow Logic**: The scan is executed within a detached terminal session, ensuring persistence even if the user interface connection is interrupted.

### 3. Web Service Intelligence
*   **Objective**: Identification and vulnerability scanning of HTTP/HTTPS interfaces across the network.
*   **Toolchain**: `nmap` -> `WhatWeb` -> `GoBuster` -> `Nikto`.
*   **Workflow Logic**:
    1.  **Service Discovery**: Targeted port scanning for common web interfaces (80, 443, 8080, 8443).
    2.  **Fingerprinting**: Technical identification of the technology stack (e.g., PHP version, CMS type, web server header).
    3.  **Directory Fuzzing**: Brute-force discovery of unlinked directories and sensitive files.
    4.  **Security Audit**: Execution of comprehensive vulnerability signatures to identify known server-side flaws.

---

## Scenario Comparison Matrix

| Scenario Profile | Execution Speed | Detection Risk | Primary Focus |
| :--- | :--- | :--- | :--- |
| **Wireless Audit** | Moderate | High (Active) | WPA/WPS Vulnerabilities |
| **Stealth Recon** | Low | Very Low | IDS Evasion |
| **Web Service Hunt** | High | Moderate | Application Vulnerabilities |
| **Quick Discovery** | Very High | Moderate | Asset Inventory |

---
*For a comprehensive theoretical analysis, refer to the [Attack and Feature Reference](./ATTACK_REFERENCE.md).*
