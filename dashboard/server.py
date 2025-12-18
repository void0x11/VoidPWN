#!/usr/bin/env python3

"""
VoidPWN Dashboard Server
Simple Flask server to provide API endpoints for the dashboard
"""

from flask import Flask, jsonify, send_from_directory, request, session, redirect, url_for
import subprocess
import os
import glob
import psutil
import csv
import re
import time
import json
from datetime import datetime
import uuid

# --- Reporting System ---
class ReportManager:
    def __init__(self, filepath):
        self.filepath = filepath
        self.reports = self._load()

    def _load(self):
        if os.path.exists(self.filepath):
            try:
                with open(self.filepath, 'r') as f:
                    return json.load(f)
            except:
                return []
        return []

    def _save(self):
        try:
            with open(self.filepath, 'w') as f:
                json.dump(self.reports, f, indent=2)
        except Exception as e:
            print(f"Failed to save report: {e}")

    def add_report(self, action_type, target, status="Running", details=""):
        report = {
            "id": str(uuid.uuid4()),
            "timestamp": datetime.now().isoformat(),
            "type": action_type,
            "target": target,
            "status": status,
            "details": details
        }
        self.reports.insert(0, report) # Prepend
        self._save()
        return report

    def update_status(self, report_id, new_status):
        for r in self.reports:
            if r['id'] == report_id:
                r['status'] = new_status
                self._save()
                break

    def get_all(self):
        return self.reports

# --- Device Management System ---
class DeviceManager:
    def __init__(self, filepath):
        self.filepath = filepath
        self.devices = self._load()
        self.selected_device = None

    def _load(self):
        if os.path.exists(self.filepath):
            try:
                with open(self.filepath, 'r') as f:
                    return json.load(f)
            except:
                return []
        return []

    def _save(self):
        try:
            with open(self.filepath, 'w') as f:
                json.dump(self.devices, f, indent=2)
        except Exception as e:
            print(f"Failed to save devices: {e}")

    def add_device(self, ip, mac="", hostname="", device_type="unknown", ports=None, notes="", tags=None):
        # Check if device already exists
        for device in self.devices:
            if device['ip'] == ip:
                # Update existing
                device['mac'] = mac or device.get('mac', '')
                device['hostname'] = hostname or device.get('hostname', '')
                device['device_type'] = device_type
                device['ports'] = ports or device.get('ports', [])
                device['notes'] = notes or device.get('notes', '')
                device['tags'] = tags if tags is not None else device.get('tags', [])
                device['last_seen'] = datetime.now().isoformat()
                self._save()
                return device
        
        # Add new device
        device = {
            "id": str(uuid.uuid4()),
            "ip": ip,
            "mac": mac,
            "hostname": hostname,
            "device_type": device_type,
            "ports": ports or [],
            "notes": notes,
            "tags": tags or [],
            "first_seen": datetime.now().isoformat(),
            "last_seen": datetime.now().isoformat()
        }
        self.devices.append(device)
        self._save()
        return device

    def update_metadata(self, device_id, notes=None, tags=None):
        for device in self.devices:
            if device['id'] == device_id or device['ip'] == device_id:
                if notes is not None: device['notes'] = notes
                if tags is not None: device['tags'] = tags
                self._save()
                return device
        return None

    def get_all(self):
        return self.devices

    def clear(self):
        self.devices = []
        self._save()

    def select(self, device_id):
        for device in self.devices:
            if device['id'] == device_id or device['ip'] == device_id:
                self.selected_device = device
                return device
        return None

    def get_selected(self):
        return self.selected_device

app = Flask(__name__, static_folder='.')
app.secret_key = os.urandom(24) # Change this to a static key if you want persistent sessions across restarts

# Authentication Configuration
DASHBOARD_PASSWORD = "voidpwn" # Default password

def is_local_request():
    """Check if the request is coming from the local machine (Pi) or localhost"""
    remote = request.remote_addr
    # Usually 127.0.0.1 or ::1 for localhost
    # Also check if it's the Pi's own IP if we can determine it
    return remote in ['127.0.0.1', '::1']

@app.before_request
def check_auth():
    """Check authentication before every request"""
    # Allow access to static files and login endpoint
    if request.path.startswith('/static') or \
       request.path == '/api/login' or \
       request.path == '/login.html' or \
       is_local_request():
        return
    
    # Check session
    if not session.get('authenticated'):
        # For API requests, return 401
        if request.path.startswith('/api/'):
            return jsonify({'error': 'Unauthorized', 'login_required': True}), 401
        # For page requests, we'll handle this in the frontend app.js to show the overlay
        # or we could redirect here, but integrated overlay is "cooler"
        pass

@app.route('/api/login', methods=['POST'])
def login():
    data = request.get_json()
    password = data.get('password')
    if password == DASHBOARD_PASSWORD:
        session['authenticated'] = True
        return jsonify({'status': 'success', 'message': 'Authenticated'})
    return jsonify({'status': 'error', 'message': 'Invalid password'}), 401

@app.route('/api/logout', methods=['POST'])
def logout():
    session.pop('authenticated', None)
    return jsonify({'status': 'success', 'message': 'Logged out'})

@app.route('/api/auth/status')
def auth_status():
    return jsonify({
        'authenticated': session.get('authenticated', False) or is_local_request(),
        'is_local': is_local_request()
    })

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

# Initialize Reporter
REPORTS_FILE = os.path.join(VOIDPWN_DIR, 'output', 'reports.json')
reporter = ReportManager(REPORTS_FILE)

# Initialize Device Manager
DEVICES_FILE = os.path.join(VOIDPWN_DIR, 'output', 'devices.json')
device_manager = DeviceManager(DEVICES_FILE)

@app.route('/')
def index():
    return send_from_directory('.', 'index.html')

@app.route('/api/reports')
def get_reports():
    return jsonify({'reports': reporter.get_all()})

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

# --- Device Management Endpoints ---
@app.route('/api/devices/list')
def list_devices():
    return jsonify({'devices': device_manager.get_all()})

@app.route('/api/devices/scan', methods=['POST'])
def scan_devices():
    """Discover hosts on the network using nmap"""
    try:
        data = request.get_json() or {}
        mode = data.get('mode', 'quick') # quick or full
        
        # Get local network
        ip_result = subprocess.run(['hostname', '-I'], capture_output=True, text=True)
        if not ip_result.stdout:
            return jsonify({'error': 'No local IP found'}), 400
            
        local_ip = ip_result.stdout.strip().split()[0]
        network = '.'.join(local_ip.split('.')[:-1]) + '.0/24'
        
        # Perform nmap scan
        log_msg = f"Starting {mode} network discovery on {network}..."
        reporter.add_report("SCAN", "Local Network", "Running", log_msg)
        
        # Use nmap -sn for fast discovery (ping scan)
        # or nmap -sV for more info
        if mode == 'full':
            cmd = ['sudo', 'nmap', '-sV', '-T4', network]
        else:
            cmd = ['sudo', 'nmap', '-sn', network]
            
        result = subprocess.run(cmd, capture_output=True, text=True)
        
        # Simple parsing of nmap output
        # Format: Nmap scan report for <hostname> (<ip>)
        # or Nmap scan report for <ip>
        found_count = 0
        current_ip = None
        current_host = "Unknown"
        
        for line in result.stdout.split('\n'):
            if "Nmap scan report for" in line:
                match = re.search(r"for ([\d\.]+)", line)
                if match:
                    current_ip = match.group(1)
                    host_match = re.search(r"for (.*) \([\d\.]+\)", line)
                    current_host = host_match.group(1) if host_match else "Unknown"
                else:
                    match = re.search(r"for (.*)", line)
                    current_ip = match.group(1)
                    current_host = "Unknown"
                
                if current_ip:
                    device_manager.add_device(current_ip, hostname=current_host)
                    found_count += 1
        
        reporter.add_report("SCAN", "Local Network", "Success", f"Discovered {found_count} devices")
        return jsonify({'status': 'success', 'count': found_count, 'devices': device_manager.get_all()})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/devices/update', methods=['POST'])
def update_device():
    data = request.get_json()
    device_id = data.get('id')
    notes = data.get('notes')
    tags = data.get('tags')
    
    device = device_manager.update_metadata(device_id, notes, tags)
    if device:
        return jsonify({'status': 'success', 'device': device})
    return jsonify({'error': 'Device not found'}), 404

@app.route('/api/devices/select', methods=['POST'])
def select_device():
    data = request.get_json()
    device_id = data.get('id')
    device = device_manager.select(device_id)
    if device:
        return jsonify({'status': 'success', 'device': device})
    return jsonify({'error': 'Device not found'}), 404

@app.route('/api/devices/selected')
def get_selected_device():
    return jsonify({'device': device_manager.get_selected()})

@app.route('/api/devices/clear', methods=['POST'])
def clear_devices():
    device_manager.clear()
    return jsonify({'status': 'success'})

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
        # Use wifi_tools.sh to perform scan
        output_dir = os.path.join(VOIDPWN_DIR, 'output', 'captures')
        os.makedirs(output_dir, exist_ok=True)
        
        # Kill any existing scans
        subprocess.run(['sudo', 'killall', 'airodump-ng'], stderr=subprocess.DEVNULL)
        
        # Clean old scan results
        output_base = os.path.join(output_dir, 'scan_results')
        subprocess.run(f"sudo rm -f {output_base}*", shell=True, stderr=subprocess.DEVNULL)
        
        # Start scan using wifi_tools.sh --scan (15 second scan)
        cmd = f"{VOIDPWN_DIR}/scripts/network/wifi_tools.sh --scan"
        subprocess.Popen(cmd, shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        
        SCAN_RUNNING = True
        
        reporter.add_report(
            "SCAN", 
            "WiFi Networks", 
            "Running", 
            "15-second network scan started"
        )
        
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
        reporter.add_report("SYSTEM", "Interface", "Success", "Enabled Monitor Mode")
        return jsonify({'status': 'success', 'message': 'Monitor mode enabling...'})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/action/monitor/off')
def action_monitor_off():
    """Disable monitor mode"""
    try:
        cmd = f"sudo {VOIDPWN_DIR}/scripts/network/wifi_tools.sh --monitor-off"
        subprocess.Popen(cmd.split(), stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        reporter.add_report("SYSTEM", "Interface", "Success", "Disabled Monitor Mode")
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
        
        reporter.add_report(
            "EVIL_TWIN", 
            ssid, 
            "Started", 
            f"Launched Evil Twin on Ch {channel}"
        )
        
        return jsonify({'status': 'success', 'message': f'Starting Evil Twin on {ssid}...'})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/action/deauth', methods=['POST'])
def action_display_deauth():
    """Deauth current target"""
    if not CURRENT_TARGET:
        return jsonify({'status': 'error', 'message': 'No target selected!'}), 400
        
    bssid = CURRENT_TARGET.get('bssid')
    ssid = CURRENT_TARGET.get('essid', 'Unknown')
    
    try:
        cmd = f"sudo {VOIDPWN_DIR}/scripts/network/wifi_tools.sh --deauth {bssid} 0"
        subprocess.Popen(cmd, shell=True)
        
        reporter.add_report(
            "DEAUTH", 
            ssid, 
            "Running", 
            f"Deauthing BSSID {bssid}"
        )
        
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
        # Use shell=True to ensure proper execution
        cmd = f"{VOIDPWN_DIR}/scripts/core/restore_hdmi.sh"
        subprocess.Popen(cmd, shell=True)
        
        reporter.add_report(
            "SYSTEM", 
            "Display", 
            "Rebooting", 
            "Switching to HDMI output"
        )
        
        return jsonify({'status': 'success', 'message': 'Switching to HDMI & Rebooting...'})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/action/handshake', methods=['POST'])
def action_handshake():
    """Capture WPA Handshake"""
    if not CURRENT_TARGET:
        return jsonify({'status': 'error', 'message': 'No target selected!'}), 400

    bssid = CURRENT_TARGET.get('bssid')
    channel = CURRENT_TARGET.get('channel')
    ssid = CURRENT_TARGET.get('essid', 'Unknown')
    
    try:
        cmd = f"sudo {VOIDPWN_DIR}/scripts/network/wifi_tools.sh --handshake {bssid} {channel} \"{ssid}\""
        subprocess.Popen(cmd, shell=True)
        
        reporter.add_report(
            "HANDSHAKE", 
            ssid, 
            "Started", 
            f"Capturing Handshake on Ch {channel}"
        )
        return jsonify({'status': 'success', 'message': f'Capturing handshake for {ssid}...'})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/action/crack', methods=['POST'])
def action_crack():
    """Crack latest handshake"""
    # Find latest .cap file
    try:
        files = glob.glob(os.path.join(CAPTURES_DIR, '*.cap'))
        if not files:
            return jsonify({'status': 'error', 'message': 'No capture files found!'}), 400
            
        latest_cap = max(files, key=os.path.getctime)
        filename = os.path.basename(latest_cap)
        
        cmd = f"sudo {VOIDPWN_DIR}/scripts/network/wifi_tools.sh --crack \"{latest_cap}\""
        # Running in background, but ideally needs output streaming
        subprocess.Popen(cmd, shell=True)
        
        reporter.add_report(
            "CRACK", 
            filename, 
            "Started", 
            "Wordlist attack initiated"
        )
        return jsonify({'status': 'success', 'message': f'Cracking {filename}...'})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/action/wifite')
def action_wifite():
    """Launch automated Wifite attack"""
    try:
        cmd = f"sudo {VOIDPWN_DIR}/scripts/network/wifi_tools.sh --auto-attack"
        subprocess.Popen(cmd, shell=True)
        
        reporter.add_report(
            "WIFITE", 
            "ALL", 
            "Started", 
            "Automated Wifite Attack"
        )
        return jsonify({'status': 'success', 'message': 'Launched Wifite Auto-Attack'})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/action/recon', methods=['POST'])
def action_recon():
    """Run Nmap Recon"""
    data = request.get_json()
    target = data.get('target')
    mode = data.get('mode', 'quick') # quick, full, stealth, vuln
    
    if not target:
        return jsonify({'error': 'Target required'}), 400
        
    try:
        flag = f"--{mode}"
        cmd = f"sudo {VOIDPWN_DIR}/scripts/network/recon.sh {flag} \"{target}\""
        subprocess.Popen(cmd, shell=True)
        
        reporter.add_report(
            "RECON", 
            target, 
            "Started", 
            f"Mode: {mode.upper()}"
        )
        return jsonify({'status': 'success', 'message': f'Starting {mode} scan on {target}...'})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/action/pmkid', methods=['POST'])
def action_pmkid():
    """Capture PMKID (Clientless)"""
    data = request.get_json() or {}
    duration = data.get('duration', 300)
    
    try:
        cmd = f"sudo {VOIDPWN_DIR}/scripts/network/wifi_tools.sh --pmkid {duration}"
        subprocess.Popen(cmd, shell=True)
        
        reporter.add_report(
            "PMKID", 
            "ALL", 
            "Started", 
            f"Capture running for {duration}s"
        )
        return jsonify({'status': 'success', 'message': f'PMKID capture started ({duration}s)...'})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/action/beacon', methods=['POST'])
def action_beacon():
    """MDK4 Beacon Flood"""
    data = request.get_json() or {}
    ssid_file = data.get('ssid_file', '')
    
    try:
        cmd = f"sudo {VOIDPWN_DIR}/scripts/network/wifi_tools.sh --beacon {ssid_file}"
        subprocess.Popen(cmd, shell=True)
        
        reporter.add_report(
            "BEACON_FLOOD", 
            "CHAOS", 
            "Running", 
            "MDK4 Beacon Flooding active"
        )
        return jsonify({'status': 'success', 'message': 'Beacon flood started...'})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/action/auth', methods=['POST'])
def action_auth_flood():
    """MDK4 Auth Flood"""
    data = request.get_json() or {}
    target = data.get('target', '')
    
    try:
        cmd = f"sudo {VOIDPWN_DIR}/scripts/network/wifi_tools.sh --auth {target}"
        subprocess.Popen(cmd, shell=True)
        
        reporter.add_report(
            "AUTH_FLOOD", 
            target or "ALL", 
            "Running", 
            "MDK4 Authentication Flooding active"
        )
        return jsonify({'status': 'success', 'message': f'Auth flood against {target or "ALL"} started...'})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/action/pixie', methods=['POST'])
def action_pixie():
    """WPS Pixie-Dust attack"""
    data = request.get_json() or {}
    target = data.get('target', '')
    
    if not target:
        return jsonify({'error': 'Target BSSID required'}), 400
        
    try:
        cmd = f"sudo {VOIDPWN_DIR}/scripts/network/wifi_tools.sh --pixie {target}"
        subprocess.Popen(cmd, shell=True)
        
        reporter.add_report(
            "PIXIE_DUST", 
            target, 
            "Started", 
            "WPS Pixie-Dust attack initiated"
        )
        return jsonify({'status': 'success', 'message': f'Pixie-Dust attack launched on {target}...'})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

# --- Automated Scenario Endpoints ---
def run_scenario(name, cmd):
    """Helper to run a scenario and log it"""
    try:
        subprocess.Popen(cmd, shell=True)
        reporter.add_report("SCENARIO", name, "Started", f"Launched scenario: {name}")
        return jsonify({'status': 'success', 'message': f'Scenario {name} started in background'})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/scenario/wifi_audit', methods=['POST'])
def scenario_wifi_audit():
    cmd = f"sudo {VOIDPWN_DIR}/scripts/network/wifi_tools.sh --scan"
    return run_scenario("WiFi Audit", cmd)

@app.route('/api/scenario/network_sweep', methods=['POST'])
def scenario_network_sweep():
    cmd = f"sudo {VOIDPWN_DIR}/scripts/network/recon.sh --discover"
    return run_scenario("Network Sweep", cmd)

@app.route('/api/scenario/web_hunt', methods=['POST'])
def scenario_web_hunt():
    data = request.get_json() or {}
    target = data.get('target')
    if not target: return jsonify({'error': 'Target required'}), 400
    cmd = f"sudo {VOIDPWN_DIR}/scripts/network/recon.sh --web {target}"
    return run_scenario("Web Hunt", cmd)

@app.route('/api/scenario/stealth_recon', methods=['POST'])
def scenario_stealth_recon():
    data = request.get_json() or {}
    target = data.get('target')
    if not target: return jsonify({'error': 'Target required'}), 400
    cmd = f"sudo {VOIDPWN_DIR}/scripts/network/recon.sh --stealth {target}"
    return run_scenario("Stealth Recon", cmd)

@app.route('/api/scenario/quick_check', methods=['POST'])
def scenario_quick_check():
    data = request.get_json() or {}
    target = data.get('target')
    if not target: return jsonify({'error': 'Target required'}), 400
    cmd = f"sudo {VOIDPWN_DIR}/scripts/network/recon.sh --quick {target}"
    return run_scenario("Quick Check", cmd)

@app.route('/api/action/throttle', methods=['POST'])
def action_throttle():
    data = request.get_json() or {}
    target = data.get('target')
    speed = data.get('speed', '1mbit')
    if not target: return jsonify({'error': 'Target required'}), 400
    
    try:
        cmd = f"sudo {VOIDPWN_DIR}/scripts/network/wifi_throttle.sh {target} {speed}"
        subprocess.Popen(cmd, shell=True)
        reporter.add_report("THROTTLE", target, "Running", f"Limiting to {speed}")
        return jsonify({'status': 'success', 'message': f'Throttling {target} to {speed}'})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    print("Starting VoidPWN Dashboard Server...")
    
    # Optional SSL support
    cert_path = os.path.join(os.path.dirname(__file__), 'cert.pem')
    key_path = os.path.join(os.path.dirname(__file__), 'key.pem')
    
    ssl_context = None
    if os.path.exists(cert_path) and os.path.exists(key_path):
        print("SSL Certificates found. Starting in HTTPS mode...")
        ssl_context = (cert_path, key_path)
        protocol = "https"
    else:
        print("No SSL certs found. Starting in HTTP mode.")
        protocol = "http"
        
    print(f"Access dashboard at: {protocol}://<PI_IP>:5000")
    app.run(host='0.0.0.0', port=5000, debug=False, ssl_context=ssl_context)
