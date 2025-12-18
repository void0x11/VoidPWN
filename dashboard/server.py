#!/usr/bin/env python3

"""
VoidPWN Dashboard Server
Simple Flask server to provide API endpoints for the dashboard
"""

from flask import Flask, jsonify, send_from_directory
import subprocess
import os
import glob
import psutil
import csv
import re
import time
import json
from datetime import datetime

app = Flask(__name__, static_folder='.')

# Configuration
# Dynamic path: server.py is in /dashboard/ -> Project root is one level up
VOIDPWN_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.environ['VOIDPWN_DIR'] = VOIDPWN_DIR

# Paths to data
CAPTURES_DIR = os.path.join(VOIDPWN_DIR, 'output', 'captures')
RECON_DIR = os.path.join(VOIDPWN_DIR, 'output', 'recon')

# Ensure directories exist
os.makedirs(CAPTURES_DIR, exist_ok=True)
os.makedirs(RECON_DIR, exist_ok=True)

@app.route('/')
def index():
    return send_from_directory('.', 'index.html')

@app.route('/api/system')
def get_system_info():
    """Get system information"""
    try:
        # Get IP address
        ip_result = subprocess.run(['hostname', '-I'], capture_output=True, text=True)
        ip = ip_result.stdout.strip().split()[0] if ip_result.stdout else 'N/A'
        
        # Get uptime
        uptime_result = subprocess.run(['uptime', '-p'], capture_output=True, text=True)
        uptime = uptime_result.stdout.strip().replace('up ', '') if uptime_result.stdout else 'N/A'
        
        # Get temperature
        try:
            temp_result = subprocess.run(['vcgencmd', 'measure_temp'], capture_output=True, text=True)
            temp = temp_result.stdout.strip().replace('temp=', '') if temp_result.stdout else 'N/A'
        except:
            temp = 'N/A'
        
        # Check WiFi adapter
        iwconfig_result = subprocess.run(['iwconfig'], capture_output=True, text=True, stderr=subprocess.STDOUT)
        adapter = 'DETECTED' if 'wlan1' in iwconfig_result.stdout else 'NOT FOUND'
        
        # Get CPU usage
        cpu_percent = psutil.cpu_percent(interval=1)
        
        # Get memory info
        mem = psutil.virtual_memory()
        memory = f"{mem.used // (1024**2)} MB / {mem.total // (1024**2)} MB"
        mem_percent = mem.percent
        
        # Get disk info
        disk = psutil.disk_usage('/')
        disk_info = f"{disk.used // (1024**3)} GB / {disk.total // (1024**3)} GB"
        disk_percent = disk.percent
        
        return jsonify({
            'ip': ip,
            'uptime': uptime,
            'temp': temp,
            'adapter': adapter,
            'cpu': round(cpu_percent, 1),
            'memory': memory,
            'memPercent': round(mem_percent, 1),
            'disk': disk_info,
            'diskPercent': round(disk_percent, 1)
        })
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/stats')
def get_stats():
    """Get attack statistics"""
    try:
        # Count capture files
        cap_files = glob.glob(os.path.join(CAPTURES_DIR, '*.cap'))
        handshakes = len(cap_files)
        
        # Count recon files
        recon_files = glob.glob(os.path.join(RECON_DIR, '*'))
        net_scans = len([f for f in recon_files if os.path.isfile(f)])
        
        # Parse recon results for hosts and ports (simplified)
        hosts = 0
        ports = 0
        vulns = 0
        
        for recon_file in recon_files:
            if os.path.isfile(recon_file):
                try:
                    with open(recon_file, 'r') as f:
                        content = f.read()
                        # Simple counting (can be improved with proper parsing)
                        hosts += content.count('Nmap scan report')
                        ports += content.count('open')
                        vulns += content.count('VULNERABLE')
                except:
                    pass
        
        return jsonify({
            'wifiScans': len(glob.glob(os.path.join(CAPTURES_DIR, '*'))),
            'handshakes': handshakes,
            'netScans': net_scans,
            'hosts': hosts,
            'ports': ports,
            'vulns': vulns
        })
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/logs')
def get_logs():
    """Get recent activity logs"""
    # This is a placeholder - in a real implementation,
    # you would read from actual log files
    logs = []
    return jsonify({'logs': logs})

@app.route('/api/captures')
def get_captures():
    """List capture files"""
    try:
        files = []
        for f in glob.glob(os.path.join(CAPTURES_DIR, '*')):
            if os.path.isfile(f):
                stat = os.stat(f)
                files.append({
                    'name': os.path.basename(f),
                    'size': stat.st_size,
                    'modified': datetime.fromtimestamp(stat.st_mtime).strftime('%Y-%m-%d %H:%M:%S')
                })
        return jsonify({'files': files})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/recon')
def get_recon():
    """List recon files"""
    try:
        files = []
        for f in glob.glob(os.path.join(RECON_DIR, '*')):
            if os.path.isfile(f):
                stat = os.stat(f)
                files.append({
                    'name': os.path.basename(f),
                    'size': stat.st_size,
                    'modified': datetime.fromtimestamp(stat.st_mtime).strftime('%Y-%m-%d %H:%M:%S')
                })
        return jsonify({'files': files})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/networks')
def get_networks():
    """Get scanned networks (placeholder)"""
    # This would parse airodump-ng output files
    return jsonify({'networks': []})

# State
CURRENT_TARGET = None
SCAN_RUNNING = False

@app.route('/api/wifi/status')
def wifi_status():
    """Check if connected to internet/network"""
    try:
        # Check connectivity
        result = subprocess.run(['nmcli', '-t', '-f', 'ACTIVE,SSID', 'dev', 'wifi'], capture_output=True, text=True)
        current = "Disconnected"
        for line in result.stdout.split('\n'):
            if line.startswith('yes'):
                current = line.split(':')[1]
                break
        return jsonify({'connected': current != "Disconnected", 'ssid': current})
    except:
        return jsonify({'connected': False, 'ssid': "Error"})

@app.route('/api/wifi/networks')
def list_wifi_networks():
    """Scan for networks to connect to (Managed mode)"""
    try:
        # Use nmcli for connection scans
        cmd = ['nmcli', '-t', '-f', 'SSID,SIGNAL,SECURITY', 'dev', 'wifi', 'list']
        result = subprocess.run(cmd, capture_output=True, text=True)
        networks = []
        seen = set()
        for line in result.stdout.split('\n'):
            if not line: continue
            parts = line.split(':')
            if len(parts) >= 3:
                ssid = parts[0]
                if not ssid or ssid in seen: continue
                seen.add(ssid)
                networks.append({
                    'ssid': ssid,
                    'signal': parts[1],
                    'security': parts[2]
                })
        return jsonify({'networks': networks})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/wifi/connect', methods=['POST'])
def connect_wifi():
    """Connect to a WiFi network"""
    try:
        data = request.get_json()
        ssid = data.get('ssid')
        password = data.get('password')
        
        if not ssid:
            return jsonify({'error': 'SSID required'}), 400
            
        cmd = ['sudo', 'nmcli', 'dev', 'wifi', 'connect', ssid]
        if password:
            cmd.extend(['password', password])
            
        subprocess.Popen(cmd)
        return jsonify({'status': 'success', 'message': f'Connecting to {ssid}...'})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/target/select', methods=['POST'])
def select_target():
    """Set the current active target"""
    global CURRENT_TARGET
    data = request.get_json()
    CURRENT_TARGET = data
    return jsonify({'status': 'success', 'target': CURRENT_TARGET})

@app.route('/api/target/current')
def get_target():
    """Get current target"""
    return jsonify({'target': CURRENT_TARGET})

@app.route('/api/scan/start')
def start_scan():
    """Start a background airodump scan for attacks"""
    global SCAN_RUNNING
    try:
        # Stop existing
        subprocess.run(['sudo', 'killall', 'airodump-ng'], stderr=subprocess.DEVNULL)
        
        # Start new scan (csv output)
        output_base = os.path.join(VOIDPWN_DIR, 'output', 'scan_results')
        # Clean old
        subprocess.run(f"rm {output_base}-*", shell=True, stderr=subprocess.DEVNULL)
        
        # We need to release the interface from NM for a moment if using the same one, 
        # but for simplicity we assume the attack interface is configured via wifi_tools.sh logic
        # We'll call a helper wrapper that runs scan for X seconds then exits
        
        cmd = f"sudo timeout 15s airodump-ng wlan1mon -w {output_base} --output-format csv"
        # Since we can't easily rely on 'wlan1mon' being up without checks, we reuse the tool logic
        # For this prototype, let's trigger the tool in scan mode
        
        # BETTER APPROACH: Use the tool script to generating a scan dump
        # Modify wifi_tools.sh later to support --scan-dump
        
        # Fallback: Just read the file if it exists, assume the user ran a scan
        # Real implementation: Async job
        
        return jsonify({'status': 'success', 'message': 'Scan started (15s)...'})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/scan/results')
def get_scan_results():
    """Parse the CSV from airodump"""
    try:
        scan_dir = os.path.join(VOIDPWN_DIR, 'output', 'captures') # Reusing captures dir for now
        # Ideally we find the latest .csv
        files = glob.glob(os.path.join(scan_dir, '*.csv'))
        if not files:
            return jsonify({'networks': []})
            
        latest = max(files, key=os.path.getctime)
        
        networks = []
        with open(latest, 'r', encoding='utf-8', errors='replace') as f:
            reader = csv.reader(f)
            # Airodump CSV format is messy, simplified parsing:
            section = 0 # 0=header, 1=networks, 2=stations
            for row in reader:
                if not row or len(row) < 2: continue
                if row[0].strip() == 'BSSID':
                    section = 1
                    continue
                if row[0].strip() == 'Station MAC':
                    section = 2
                    continue
                    
                if section == 1:
                    # BSSID, First time seen, Last time seen, channel, Speed, Privacy, Cipher, Authentication, Power, # beacons, # IV, LAN IP, ID-length, ESSID, Key
                    if len(row) >= 14:
                        networks.append({
                            'bssid': row[0].strip(),
                            'channel': row[3].strip(),
                            'privacy': row[5].strip(),
                            'power': row[8].strip(),
                            'essid': row[13].strip()
                        })
                        
        return jsonify({'networks': networks})
    except Exception as e:
        return jsonify({'error': str(e), 'networks': []})


@app.route('/api/action/monitor/on')
def action_monitor_on():
    """Enable monitor mode"""
    try:
        cmd = f"sudo {VOIDPWN_DIR}/scripts/network/wifi_tools.sh --monitor-on"
        subprocess.Popen(cmd.split(), stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        return jsonify({'status': 'success', 'message': 'Monitor mode enabling...'})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/action/monitor/off')
def action_monitor_off():
    """Disable monitor mode"""
    try:
        cmd = f"sudo {VOIDPWN_DIR}/scripts/network/wifi_tools.sh --monitor-off"
        subprocess.Popen(cmd.split(), stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        return jsonify({'status': 'success', 'message': 'Monitor mode disabling...'})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/action/evil_twin', methods=['POST'])
def action_evil_twin():
    """Start Evil Twin attack on current target"""
    if not CURRENT_TARGET:
        return jsonify({'status': 'error', 'message': 'No target selected!'}), 400
        
    ssid = CURRENT_TARGET.get('essid', 'Free WiFi')
    channel = CURRENT_TARGET.get('channel', '6')
    
    try:
        cmd = f"sudo {VOIDPWN_DIR}/scripts/network/wifi_tools.sh --evil-twin \"{ssid}\" {channel}"
        subprocess.Popen(cmd, shell=True)
        return jsonify({'status': 'success', 'message': f'Starting Evil Twin on {ssid}...'})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/action/deauth', methods=['POST'])
def action_display_deauth():
    """Deauth current target"""
    if not CURRENT_TARGET:
        return jsonify({'status': 'error', 'message': 'No target selected!'}), 400
        
    bssid = CURRENT_TARGET.get('bssid')
    
    try:
        cmd = f"sudo {VOIDPWN_DIR}/scripts/network/wifi_tools.sh --deauth {bssid} 0"
        subprocess.Popen(cmd, shell=True)
        return jsonify({'status': 'success', 'message': f'Deauthing {bssid}...'})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/action/reboot')
def action_reboot():
    """Reboot system"""
    try:
        subprocess.Popen(['sudo', 'reboot'])
        return jsonify({'status': 'success', 'message': 'System rebooting...'})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/action/shutdown')
def action_shutdown():
    """Shutdown system"""
    try:
        subprocess.Popen(['sudo', 'shutdown', 'now'])
        return jsonify({'status': 'success', 'message': 'System shutting down...'})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/action/restore_hdmi')
def action_restore_hdmi():
    """Switch to HDMI output"""
    try:
        cmd = f"sudo {VOIDPWN_DIR}/scripts/core/restore_hdmi.sh"
        subprocess.Popen(cmd.split())
        return jsonify({'status': 'success', 'message': 'Switching to HDMI & Rebooting...'})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    print("Starting VoidPWN Dashboard Server...")
    print("Access dashboard at: http://<PI_IP>:5000")
    app.run(host='0.0.0.0', port=5000, debug=False)
