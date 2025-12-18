# Attack and Feature Reference

This document provides a technical overview of the security assessment methodologies and tools integrated into the VoidPWN platform. 

---

## Wireless Network Assessments (Layer 2)

### PMKID Attack
The PMKID (Pairwise Master Key ID) attack is a clientless methodology used to obtain WPA2 credentials. 
*   **Methodology**: It exploits the Robust Security Network Information Element (RSN IE) by capturing the PMKID field during a single association request to the Access Point (AP).
*   **Prerequisites**: The AP must support the RSN IE field; however, no active client connection is required.
*   **Tools**: `hcxdumptool` handles the frame interaction, and `hcxpcapngtool` is utilized for hash extraction and conversion.
*   **Implementation**: VoidPWN automates the signal targeting and capture duration, outputting results in a format ready for offline analysis via Hashcat.

### WPS Pixie-Dust
The Pixie-Dust attack targets vulnerabilities in the Wi-Fi Protected Setup (WPS) protocol.
*   **Methodology**: It exploits low-entropy or predictable pseudo-random number generators (PRNG) used by certain wireless chipsets during the WPS exchange. By capturing specific nonces (E-S1, E-S2), the PIN can be recovered offline.
*   **Tools**: `reaver` executes the protocol interaction, while `pixiewps` performs the cryptographic calculations.
*   **Implementation**: The platform identifies WPS-enabled networks and provides integrated parameters for targeted execution against vulnerable chipsets.

### Denial of Service and Obfuscation (MDK4)
The MDK4 suite is utilized for both stress testing and environmental obfuscation.
*   **Beacon Flooding**: Generates and broadcasts fake Beacon frames with randomized SSIDs to saturate client scan lists and mask legitimate signals.
*   **Authentication Flooding**: Floods an AP's association table with authentication requests from spoofed MAC addresses, testing the target's resource management and stability.
*   **Tools**: `mdk4`.

### Handshake Capture
Traditional WPA/WPA2 security assessments rely on capturing the 4-way handshake.
*   **Methodology**: Spoofed deauthentication frames are sent to force a client reconnection, allowing for the interception of EAPOL frames.
*   **Tools**: `airodump-ng` (monitoring), `aireplay-ng` (injection), `aircrack-ng` (verification).

---

## Network Reconnaissance (Layer 3/4)

### TCP SYN Scanning
VoidPWN implements SYN stealth scanning to identify open ports and services with minimal detection risk.
*   **Methodology**: The scanner initiates a connection with a SYN packet and resets it (RST) upon receiving a response, avoiding the completion of the 3-way handshake.
*   **Context**: This bypasses many application-level logging mechanisms that only record established connections.
*   **Tools**: `nmap` using the `-sS` flag.

### Service and OS Fingerprinting
*   **Methodology**: By analyzing TCP/IP stack implementation differences (e.g., TTL, window size, and TCP options), the platform identifies host operating systems and service versions.
*   **Tools**: `nmap` with `-sV` and `-O` flags.

### SMB and Network Discovery
*   **Methodology**: Automated enumeration of Server Message Block (SMB) protocols to identify shared directories, user accounts, and host configurations.
*   **Tools**: `enum4linux`, `smbclient`, and `nmap` scripting engine (NSE).

---

## Automated Workflow Orchestration

VoidPWN utilizes a state-machine logic to chain these technical tools into cohesive workflows. Each automated scenario follows a strict sequence of discovery, target filtering, focused assessment, and reporting. 

### Mission Profiles
1.  **Wireless Audit**: Conducts an automated rotation through detected APs, attempting both clientless (PMKID) and client-based (Handshake) captures.
2.  **Internal Network Recon**: Performs multi-stage discovery focusing on service enumeration and vulnerability identification without manual flag configuration.
3.  **Web Application Assessment**: Specifically targets HTTP/HTTPS services to identify misconfigurations, hidden directories, and known web vulnerabilities using tools like `nikto` and `gobuster`.
