#!/usr/bin/env python3

import sys
import time
import os
import subprocess
import argparse
from datetime import datetime
try:
    from scapy.all import sniff, Dot11, Dot11ProbeReq
except ImportError:
    print("Scapy not found. Run: sudo apt install python3-scapy")
    sys.exit(1)

# Colors
RED = '\033[91m'
GREEN = '\033[92m'
BLUE = '\033[94m'
RESET = '\033[0m'

SEEN_DEVICES = set()
WATCHLIST = {}

def load_watchlist(filename):
    if not os.path.exists(filename):
        return
    with open(filename, 'r') as f:
        for line in f:
            if ',' in line:
                mac, name = line.strip().split(',', 1)
                WATCHLIST[mac.lower()] = name

def packet_callback(pkt):
    if pkt.haslayer(Dot11ProbeReq):
        mac = pkt.addr2
        
        # Determine signal strength (RSSI) if available
        rssi = "N/A"
        try:
            if hasattr(pkt, "dBm_AntSignal"):
                rssi = str(pkt.dBm_AntSignal)
        except:
            pass

        # Check various info elements for SSID
        ssid = "Hidden"
        try:
            if pkt.info:
                ssid = pkt.info.decode('utf-8')
        except:
            pass
            
        timestamp = datetime.now().strftime("%H:%M:%S")
        
        # Check if trusted/watched device
        mac_lower = mac.lower()
        if mac_lower in WATCHLIST:
            device_name = WATCHLIST[mac_lower]
            alert_msg = f"[{timestamp}] ALERT: {device_name} detected! ({mac}) Signal: {rssi}dBm searching for '{ssid}'"
            print(f"{RED}{alert_msg}{RESET}")
            # Could trigger beep or LED here
        elif mac_lower not in SEEN_DEVICES:
            SEEN_DEVICES.add(mac_lower)
            print(f"[{timestamp}] New Device: {mac} Signal: {rssi}dBm searching for '{ssid}'")

def main():
    print(f"{BLUE}VoidPWN WiFi Monitor{RESET}")
    print("Monitoring for devices nearby...")

    if os.geteuid() != 0:
        print(f"{RED}Error: Must run as root (sudo){RESET}")
        sys.exit(1)

    if len(sys.argv) < 2:
        print("Usage: sudo python3 wifi_monitor.py <interface>")
        sys.exit(1)

    interface = sys.argv[1]

    if not os.path.exists(f"/sys/class/net/{interface}"):
        print(f"{RED}Error: Interface '{interface}' not found{RESET}")
        sys.exit(1)

    # Set interface to monitor mode
    print(f"Setting {interface} to monitor mode...")
    subprocess.run(['ip', 'link', 'set', interface, 'down'], check=False)
    subprocess.run(['iw', 'dev', interface, 'set', 'type', 'monitor'], check=False)
    subprocess.run(['ip', 'link', 'set', interface, 'up'], check=False)

    # Load watchlist if exists
    load_watchlist("watchlist.txt")
    print(f"Loaded {len(WATCHLIST)} devices to watch for.")

    try:
        sniff(iface=interface, prn=packet_callback, store=0)
    except KeyboardInterrupt:
        print("\nStopping monitor.")
    finally:
        # Restore managed mode
        print(f"Restoring {interface} to managed mode...")
        subprocess.run(['ip', 'link', 'set', interface, 'down'], check=False)
        subprocess.run(['iw', 'dev', interface, 'set', 'type', 'managed'], check=False)
        subprocess.run(['ip', 'link', 'set', interface, 'up'], check=False)

if __name__ == "__main__":
    main()
