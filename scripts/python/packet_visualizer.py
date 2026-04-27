#!/usr/bin/env python3

import sys
import os
import time
import random
import curses
import argparse
from datetime import datetime
try:
    from scapy.all import sniff, IP, TCP, UDP, ICMP
except ImportError:
    print("Scapy not found. Run: sudo apt install python3-scapy")
    sys.exit(1)

# Configuration (overridden by --interface argument)
INTERFACE = "wlan0"
MAX_LINES = 20

class PacketMatrix:
    def __init__(self):
        self.stdscr = curses.initscr()
        curses.start_color()
        curses.use_default_colors()
        curses.noecho()
        curses.cbreak()
        curses.curs_set(0)
        self.stdscr.nodelay(1)
        
        # Matrix colors
        curses.init_pair(1, curses.COLOR_GREEN, -1)  # Normal matrix code
        curses.init_pair(2, curses.COLOR_WHITE, -1)  # Highlights
        curses.init_pair(3, curses.COLOR_RED, -1)    # Alerts
        
        self.rows, self.cols = self.stdscr.getmaxyx()
        self.packets = []
        self.start_time = time.time()
        self.packet_count = 0

    def process_packet(self, packet):
        self.packet_count += 1
        
        timestamp = datetime.now().strftime("%H:%M:%S")
        info = ""
        color = curses.color_pair(1)
        
        if IP in packet:
            src = packet[IP].src
            dst = packet[IP].dst
            proto = packet[IP].proto
            
            if TCP in packet:
                info = f"TCP  {src}:{packet[TCP].sport} -> {dst}:{packet[TCP].dport}"
            elif UDP in packet:
                info = f"UDP  {src}:{packet[UDP].sport} -> {dst}:{packet[UDP].dport}"
            elif ICMP in packet:
                info = f"ICMP {src} -> {dst}"
                color = curses.color_pair(2)
            else:
                info = f"IP   {src} -> {dst} PROTO:{proto}"
        else:
            info = f"ARP/OTHER {packet.summary()[:50]}..."
            
        # Add "Matrix" effect characters
        matrix_chars = "".join([random.choice(['0', '1']) for _ in range(4)])
        display_line = f"{matrix_chars} {timestamp} {info}"
        
        # Trim to screen width
        display_line = display_line[:self.cols-1]
        
        self.packets.insert(0, (display_line, color))
        if len(self.packets) > self.rows - 5:
            self.packets.pop()
            
        self.draw()

    def draw(self):
        self.stdscr.erase()
        
        # Header
        header = f" VOIDPWN TRAFFIC VISUALIZER | Packets: {self.packet_count} | Time: {int(time.time() - self.start_time)}s "
        self.stdscr.addstr(0, 0, header.center(self.cols), curses.A_REVERSE | curses.color_pair(1))
        self.stdscr.addstr(1, 0, "─" * self.cols, curses.color_pair(1))
        
        # Packet stream
        for idx, (line, color) in enumerate(self.packets):
            if idx + 2 < self.rows:
                self.stdscr.addstr(idx + 2, 0, line, color)
        
        # Bottom status
        footer = " Press Ctrl+C to stop "
        self.stdscr.addstr(self.rows-1, 0, footer, curses.color_pair(1))
        
        self.stdscr.refresh()

    def stop(self):
        curses.nocbreak()
        self.stdscr.keypad(False)
        curses.echo()
        curses.endwin()

def packet_callback(packet):
    global matrix
    matrix.process_packet(packet)

def main():
    global matrix, INTERFACE

    parser = argparse.ArgumentParser(description='VoidPWN Packet Visualizer')
    parser.add_argument('-i', '--interface', default=None,
                        help='Network interface to sniff on (default: auto-detect)')
    args = parser.parse_args()

    if os.geteuid() != 0:
        print("Root required for sniffing. Run with sudo.")
        sys.exit(1)

    # Auto-detect interface if not specified
    if args.interface:
        INTERFACE = args.interface
    else:
        # Try to detect a wireless interface
        try:
            import subprocess
            out = subprocess.check_output(['iw', 'dev'], stderr=subprocess.DEVNULL).decode()
            for line in out.splitlines():
                if 'Interface' in line:
                    INTERFACE = line.split()[-1]
                    break
        except Exception:
            pass  # Keep default wlan0

    try:
        matrix = PacketMatrix()
        # Filter out SSH traffic to avoid loop (port 22)
        sniff(iface=INTERFACE, filter="not port 22", prn=packet_callback, store=0)
    except KeyboardInterrupt:
        pass
    except Exception as e:
        # If curses fails, ensure we restore terminal
        try:
            matrix.stop()
        except Exception:
            pass
        print(f"Error: {e}")
    finally:
        try:
            matrix.stop()
        except Exception:
            pass

if __name__ == "__main__":
    main()
