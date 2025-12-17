# VoidPWN Automated Attack Scenarios

## Overview

VoidPWN includes 5 pre-configured automated attack scenarios that require minimal user input. Perfect for the LCD touchscreen interface - just select a number and go.

## Access Scenarios

### From Main Menu
```bash
voidpwn
# Select 1 (Auto Scenarios)
```

### Direct Access
```bash
cd ~/VoidPWN
sudo ./scenarios.sh
```

---

## Scenario 1: WiFi Audit

**Purpose**: Complete WiFi network assessment

**What it does**:
1. Scans for all nearby WiFi networks
2. Captures handshakes from detected networks
3. Attempts WPS attacks on vulnerable routers
4. Generates comprehensive report

**Duration**: User-defined (default: 10 minutes)

**User Input Required**:
- Scan duration in minutes

**Output**:
- Network scan CSV file
- Captured handshakes
- WPS attack results
- Summary report

**Use Case**: Audit WiFi security in your environment

---

## Scenario 2: Network Sweep

**Purpose**: Complete network discovery and scanning

**What it does**:
1. Discovers all hosts on the network
2. Scans all 65535 ports on each host
3. Identifies services and versions
4. Checks for common vulnerabilities

**Duration**: 15-30 minutes (depends on network size)

**User Input Required**:
- Network range (auto-detected, can override)

**Output**:
- Host discovery results
- Complete port scan
- Vulnerability assessment
- OS detection
- Summary report

**Use Case**: Complete network security assessment

---

## Scenario 3: Web Application Hunt

**Purpose**: Find and enumerate web services

**What it does**:
1. Finds all web servers on network (ports 80, 443, 8080, 8443)
2. Enumerates directories and files
3. Identifies web technologies (CMS, frameworks)
4. Checks for common web vulnerabilities
5. Tests for SQL injection

**Duration**: 20-40 minutes (depends on number of web servers)

**User Input Required**:
- Network range (auto-detected, can override)

**Output**:
- List of web servers
- Directory enumeration results
- Technology fingerprints
- Nikto vulnerability scan
- SQL injection test results
- Summary report

**Use Case**: Web application security testing

---

## Scenario 4: Stealth Reconnaissance

**Purpose**: Low-profile intelligence gathering

**What it does**:
1. Performs slow, stealthy scans (avoids IDS/IPS)
2. Uses packet fragmentation
3. Employs 10 random decoy IPs
4. Gathers intelligence quietly

**Duration**: 30-60 minutes (intentionally slow)

**User Input Required**:
- Target IP or network

**Output**:
- Stealth SYN scan results
- Service detection
- OS fingerprinting
- Safe script scan results
- Summary report

**Use Case**: Reconnaissance without alerting security systems

**Scan Configuration**:
- Timing: T1-T2 (Slow/Sneaky)
- Fragmentation: Enabled
- Decoys: 10 random IPs
- Data padding: 25 bytes

---

## Scenario 5: Quick Assessment

**Purpose**: Fast security check

**What it does**:
1. Rapid host discovery
2. Top 1000 ports scan
3. Quick vulnerability check
4. Risk assessment

**Duration**: 5-10 minutes

**User Input Required**:
- Network range (auto-detected, can override)

**Output**:
- Host discovery
- Top ports scan
- Quick vulnerability assessment
- Risk rating (HIGH/MEDIUM/LOW/MINIMAL)
- Recommendations
- Summary report

**Use Case**: Fast security snapshot of network

---

## Results Management

### View Results

From scenarios menu:
```
Select option 6 (View Results)
```

### Results Location

All scenario results are saved to:
```
~/VoidPWN/scenarios/
```

Each scenario creates a timestamped directory:
```
~/VoidPWN/scenarios/wifi_audit_20250116_143022/
~/VoidPWN/scenarios/network_sweep_20250116_144530/
~/VoidPWN/scenarios/web_hunt_20250116_150045/
etc.
```

### Report Files

Each scenario generates:
- `report.txt` - Human-readable summary
- Multiple `.nmap` files - Detailed scan results
- Additional tool-specific output files

---

## Navigation Tips for LCD Screen

### Menu Navigation
- Numbers only - no typing required
- Clear visual hierarchy
- One-button selection
- Auto-detected defaults
- Minimal confirmations

### Workflow
```
1. Launch voidpwn
2. Press 1 (Auto Scenarios)
3. Select scenario (1-5)
4. Confirm or adjust defaults
5. Wait for completion
6. View report
7. Press Enter to return
```

### Quick Actions
- `0` - Always returns/exits
- `Enter` - Confirms default values
- `y/n` - Simple yes/no prompts

---

## Scenario Comparison

| Scenario | Duration | Stealth | Depth | Best For |
|----------|----------|---------|-------|----------|
| WiFi Audit | 10-20 min | Medium | High | WiFi security |
| Network Sweep | 15-30 min | Low | Very High | Full assessment |
| Web Hunt | 20-40 min | Low | High | Web apps |
| Stealth Recon | 30-60 min | Very High | Medium | Covert ops |
| Quick Assessment | 5-10 min | Medium | Medium | Fast check |

---

## Legal Notice

All scenarios are for authorized testing only:
- Only test networks you own
- Obtain written permission for client networks
- Stealth scenarios may trigger security alerts
- Users are responsible for legal compliance

---

## Tips for Best Results

### WiFi Audit
- Position device centrally for best coverage
- Run during peak hours to capture more handshakes
- Longer duration = more networks discovered

### Network Sweep
- Run during business hours for accurate host count
- May take longer on large networks (100+ hosts)
- Results best when all devices are powered on

### Web Hunt
- Ensure internet connectivity for technology detection
- May generate significant traffic
- Consider running during maintenance windows

### Stealth Recon
- Use when avoiding detection is critical
- Significantly slower than normal scans
- May miss some services due to timing

### Quick Assessment
- Perfect for regular security checks
- Run weekly/monthly for trend analysis
- Good baseline before deeper testing

---

## Customization

To modify scenarios, edit `scenarios.sh`:

```bash
nano ~/VoidPWN/scenarios.sh
```

Common modifications:
- Change default scan duration
- Adjust wordlists for directory enumeration
- Modify nmap timing templates
- Add custom scripts
- Change output formats

---

## Integration with Dashboard

Scenario results automatically appear in:
- Web Dashboard statistics
- Capture file viewer
- Activity logs

Access dashboard to visualize scenario results:
```bash
./dashboard.sh start
# Open http://<PI_IP>:5000
```

---

## Troubleshooting

### Scenario hangs
```bash
# Press Ctrl+C to cancel
# Check if tools are installed:
which nmap gobuster nikto sqlmap
```

### No results generated
```bash
# Check output directory exists:
ls -la ~/VoidPWN/scenarios/

# Check permissions:
sudo chown -R kali:kali ~/VoidPWN/scenarios/
```

### Network not detected
```bash
# Manually specify network:
# When prompted, enter: 192.168.1.0/24
```

---

## Example Session

```
$ sudo ./scenarios.sh

╔═══════════════════════════════════╗
║   AUTOMATED ATTACK SCENARIOS      ║
╚═══════════════════════════════════╝

Select Attack Scenario:

  [1] WiFi Audit
      Complete WiFi network assessment

  [2] Network Sweep
      Full network discovery and scanning

  [3] Web Application Hunt
      Find and enumerate web services

  [4] Stealth Reconnaissance
      Low-profile intelligence gathering

  [5] Quick Assessment
      Fast security check (5-10 min)

  [6] View Results
      Browse previous scenario results

  [0] Exit

Select option [0-6]: 5

[*] SCENARIO 5: Quick Security Assessment

[*] This scenario will:
  1. Rapid host discovery
  2. Top 1000 ports scan
  3. Quick vulnerability check
  4. Generate summary report

[*] Detected network: 192.168.1.0/24
Use this network? (y/n): y

[*] Starting quick assessment...
[*] [1/3] Discovering hosts...
[✓] Found 12 hosts
[*] [2/3] Scanning top 1000 ports...
[*] [3/3] Quick vulnerability check...
[*] Generating report...
[✓] Quick assessment complete!
[*] Results saved to: ~/VoidPWN/scenarios/quick_assessment_20250116_170530

Quick Security Assessment Report
Generated: Mon Jan 16 17:05:30 MST 2025
Network: 192.168.1.0/24

SUMMARY
=======
Hosts discovered: 12
Open ports: 47
Vulnerabilities: 3

RISK ASSESSMENT
===============
LOW RISK - Few vulnerabilities detected

...

Press Enter to continue...
```

---

## Advanced Usage

### Chain Scenarios
```bash
# Run multiple scenarios in sequence
sudo ./scenarios.sh
# Select 5 (Quick Assessment)
# Then 2 (Network Sweep)
# Then 3 (Web Hunt)
```

### Schedule Scenarios
```bash
# Add to crontab for automated runs
crontab -e

# Run Quick Assessment daily at 2 AM
0 2 * * * cd ~/VoidPWN && sudo ./scenarios.sh <<< "5\ny\n"
```

### Export Results
```bash
# Compress all results
tar -czf voidpwn_results_$(date +%Y%m%d).tar.gz ~/VoidPWN/scenarios/

# Transfer to another system
scp voidpwn_results_*.tar.gz user@host:/path/
```

---

The automated scenarios make VoidPWN extremely user-friendly, especially on the LCD screen where typing is difficult. Just select a number and let it run!
