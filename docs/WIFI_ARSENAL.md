# Wireless Assessment Guide

This guide details the wireless security assessment capabilities of VoidPWN and provides technical instructions for executing Layer 2 assessments.

---

## Technical Overview

Wireless security assessments primarily focus on the WPA2/WPA3 4-way handshake and protocol-specific vulnerabilities such as WPS misconfigurations and RSN IE exploits.

### Assessment Methodologies

#### 1. PMKID Capture
The PMKID attack is a clientless methodology that targets the Robust Security Network Information Element (RSN IE). 
*   **Mechanism**: Captures the Pairwise Master Key ID from the first association request.
*   **Advantage**: Does not require an active client connection or deauthentication.
*   **Tools**: `hcxdumptool`, `hcxpcapngtool`.

#### 2. MDK4 Protocol Stress Testing
The MDK4 suite provides tools for testing environment stability and signal obfuscation.
*   **Beacon Flooding**: Injects high volumes of randomized Beacon frames to test client-side network discovery resilience.
*   **Authentication Flooding**: Tests an Access Point's capacity to handle abnormal authentication request volumes from spoofed source addresses.
*   **Tools**: `mdk4`.

#### 3. WPS Vulnerability Research
Targeting predictable nonces in Wi-Fi Protected Setup implementations.
*   **Mechanism**: Offline calculation of the WPS PIN based on captured nonces with low entropy.
*   **Tools**: `reaver`, `pixiewps`.

#### 4. Handshake Interception
Traditional methodology involving the interception of EAPOL frames.
*   **Mechanism**: Forcing a client reconnection through targeted deauthentication.
*   **Tools**: `aircrack-ng` suite.

---

## Operational Workflow

### Preparation
1.  **Monitor Mode**: Navigate to the **SYSTEM** tab and enable monitor mode on the primary wireless interface (typically `wlan1`). This executes `airmon-ng` to terminate conflicting system processes and switch the chipset state.
2.  **Signal Acquisition**: Utilize the **WIFI RADAR** function to identify available targets and signal strengths.

### Execution
1.  **Target Selection**: Select the desired BSSID from the inventory.
2.  **Attack Initialization**: Choose the appropriate assessment vector (e.g., PMKID Capture).
3.  **Data Management**: Captured handshake files and logs are automatically organized in the **REPORTS** tab for retrieval and offline analysis.

### Hardware Considerations
For optimal packet injection and monitoring range, the use of an external high-gain wireless adapter is recommended. Internal adapters may exhibit reduced performance or limited driver support for specialized injection frames.

---
*For a comprehensive theoretical analysis, refer to the [Attack and Feature Reference](./ATTACK_REFERENCE.md).*
