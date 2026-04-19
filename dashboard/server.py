#!/usr/bin/env python3

"""
VoidPWN Dashboard Server
Simple Flask server to provide API endpoints for the dashboard
"""

from flask import Flask, jsonify, send_from_directory, request
import subprocess
import os
import glob
import json
import csv
import fcntl
from datetime import datetime
import re
import urllib.request
import urllib.parse

try:
    import psutil
except ImportError:
    psutil = None
import time
import uuid
import collections
import threading

# --- Circular Log for Live HUD ---
LIVE_LOGS = collections.deque(maxlen=100)

def add_live_log(msg, type="info"):
    timestamp = datetime.now().strftime('%H:%M:%S')
    LIVE_LOGS.append({'time': timestamp, 'msg': msg, 'type': type})

def parse_inventory_info(line):
    """Parse a line of output for device info and update inventory"""
    # Look for Nmap patterns: "Nmap scan report for 192.168.1.1" or "Nmap scan report for host (192.168.1.1)"
    if "Nmap scan report for" in line:
        match = re.search(r"for ([\d\.]+)", line)
        ip = match.group(1) if match else None
        if not ip:
            match = re.search(r"for (.*) \(([\d\.]+)\)", line)
            if match:
                hostname = match.group(1)
                ip = match.group(2)
                device_manager.add_device(ip, hostname=hostname)
                return
        if ip:
            device_manager.add_device(ip)

    # Look for pure IP patterns in typical tool outputs
    # e.g., "[+] Host: 192.168.1.1" or "IP: 192.168.1.1"
    ip_match = re.search(r"(?:Host|IP|Target):\s*([\d\.]+)", line, re.I)
    if ip_match:
        device_manager.add_device(ip_match.group(1))

    # Look for MAC patterns
    mac_match = re.search(r"([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})", line)
    if mac_match:
        # If we have a MAC but no IP on this line, it's hard to attribute without more context,
        # but we can look for specific tools like airodump or nmap
        pass

def run_proc_and_capture(cmd_str, log_file=None, report_id=None):
    """Run a process in the background and capture its output to LIVE_LOGS and optionally a file"""
    try:
        if not cmd_str.startswith('stdbuf'):
            cmd_str = f"stdbuf -oL -eL {cmd_str}"
            
        proc = subprocess.Popen(
            cmd_str,
            shell=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1,
            universal_newlines=True
        )
        
        def capture():
            log_path = os.path.join(LOGS_DIR, log_file) if log_file else None
            f_log = open(log_path, 'w') if log_path else None
            
            for line in iter(proc.stdout.readline, ""):
                if line:
                    clean_line = line.strip()
                    add_live_log(clean_line)
                    parse_inventory_info(clean_line) # Live inventory update
                    if f_log:
                        f_log.write(line)
                        f_log.flush()
            
            proc.stdout.close()
            proc.wait()
            
            if f_log:
                f_log.close()
            
            # Extract mission name from command string
            parts = cmd_str.split()
            mission_name = "Mission"
            for p in parts:
                if not p.startswith('-') and p not in ['sudo', 'stdbuf', '-oL', '-eL']:
                    mission_name = p.split('/')[-1].replace('"','')
                    break
                    
            add_live_log(f"✅ MISSION COMPLETE: {mission_name.upper()}", "success")
            
            if report_id:
                reporter.update_status(report_id, "Completed")
            
        t = threading.Thread(target=capture, daemon=True)
        t.start()
        return proc
    except Exception as e:
        add_live_log(f"Error starting process: {str(e)}", "error")
        return None

def gen_log_name(action):
    """Generate a unique filename for a mission log"""
    ts = datetime.now().strftime('%Y%m%d_%H%M%S')
    clean_action = action.lower().replace(' ', '_')
    return f"{clean_action}_{ts}.txt"

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
                fcntl.flock(f, fcntl.LOCK_EX)
                json.dump(self.reports, f, indent=2)
                fcntl.flock(f, fcntl.LOCK_UN)
        except Exception as e:
            print(f"Failed to save report: {e}")

    def add_report(self, action_type, target, status="Running", details="", log_file=None):
        report = {
            "id": str(uuid.uuid4()),
            "timestamp": datetime.now().isoformat(),
            "type": action_type,
            "target": target,
            "status": status,
            "details": details,
            "log_file": log_file
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
                fcntl.flock(f, fcntl.LOCK_EX)
                json.dump(self.devices, f, indent=2)
                fcntl.flock(f, fcntl.LOCK_UN)
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

app = Flask(__name__, static_folder='.', static_url_path='')

# Configuration
# Dynamic path: server.py is in /dashboard/ -> Project root is one level up
VOIDPWN_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.environ['VOIDPWN_DIR'] = VOIDPWN_DIR

# Paths to data
CAPTURES_DIR = os.path.join(VOIDPWN_DIR, 'output', 'captures')
RECON_DIR = os.path.join(VOIDPWN_DIR, 'output', 'recon')
LOGS_DIR = os.path.join(VOIDPWN_DIR, 'output', 'logs')

# Ensure directories exist
os.makedirs(CAPTURES_DIR, exist_ok=True)
os.makedirs(RECON_DIR, exist_ok=True)
os.makedirs(LOGS_DIR, exist_ok=True)

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
        try:
            ip_result = subprocess.run(['hostname', '-I'], capture_output=True, text=True, timeout=2)
            ip = ip_result.stdout.strip().split()[0] if ip_result.stdout else 'N/A'
        except:
            ip = 'N/A'
        
        # Get uptime
        try:
            uptime_result = subprocess.run(['uptime', '-p'], capture_output=True, text=True, timeout=2)
            uptime = uptime_result.stdout.strip().replace('up ', '') if uptime_result.stdout else 'N/A'
        except:
            uptime = 'N/A'
        
        # Get temperature — try Pi-specific first, fall back to thermal zone
        try:
            temp_result = subprocess.run(['vcgencmd', 'measure_temp'], capture_output=True, text=True, timeout=3)
            if temp_result.returncode == 0 and temp_result.stdout:
                temp = temp_result.stdout.strip().replace('temp=', '')
            else:
                raise FileNotFoundError
        except:
            try:
                with open('/sys/class/thermal/thermal_zone0/temp', 'r') as tf:
                    temp = f"{int(tf.read().strip()) / 1000:.1f}'C"
            except:
                temp = 'N/A'
        
        # Check WiFi adapter using iw (works with any naming convention)
        try:
            iw_result = subprocess.run(['iw', 'dev'], capture_output=True, text=True, timeout=3)
            ifaces = [l.split()[-1] for l in iw_result.stdout.splitlines() if 'Interface' in l]
            adapter = 'DETECTED' if ifaces else 'NOT FOUND'
        except:
            # Fallback to iwconfig
            try:
                iw_result = subprocess.run(['iwconfig'], capture_output=True, text=True, stderr=subprocess.STDOUT, timeout=3)
                adapter = 'DETECTED' if re.search(r'IEEE 802\.11', iw_result.stdout) else 'NOT FOUND'
            except:
                adapter = 'UNKNOWN'
        
        if psutil:
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
        else:
            cpu_percent = 0
            memory = "psutil missing"
            mem_percent = 0
            disk_info = "psutil missing"
            disk_percent = 0
        
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
        
        # Get target network/subnet
        target_subnet = data.get('subnet')
        interface = data.get('interface')
        
        if not target_subnet:
            if interface:
                # Get IP of interface
                ip_cmd = r"ip -4 addr show " + interface + r" | grep -oP '(?<=inet\s)\d+(\.\d+){3}'"
                ip_res = subprocess.run(ip_cmd, shell=True, capture_output=True, text=True)
                local_ip = ip_res.stdout.strip()
                if not local_ip:
                    return jsonify({'error': f'No IP on {interface}'}), 400
                target_subnet = '.'.join(local_ip.split('.')[:-1]) + '.0/24'
            else:
                # Fallback to hostname -I
                ip_result = subprocess.run(['hostname', '-I'], capture_output=True, text=True)
                if not ip_result.stdout:
                    return jsonify({'error': 'No local IP found'}), 400
                local_ip = ip_result.stdout.strip().split()[0]
                target_subnet = '.'.join(local_ip.split('.')[:-1]) + '.0/24'
        
        # Perform nmap scan via background capture
        log_file = gen_log_name(f"discovery_{mode}")
        if mode == 'full':
            cmd_list = ['sudo', 'nmap', '-sV', '-T4', target_subnet]
        else:
            cmd_list = ['sudo', 'nmap', '-sn', target_subnet]
        
        cmd = " ".join(cmd_list)
        run_proc_and_capture(cmd, log_file=log_file)
        
        reporter.add_report(f"SCAN ({mode.upper()})", target_subnet, "Started", f"Network discovery ({mode})", log_file=log_file)
        add_live_log(f"NETWORK DISCOVERY STARTED: {target_subnet}", "info")
        
        return jsonify({'status': 'success', 'message': f'Discovery started on {target_subnet}'})
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

@app.route('/api/interfaces')
def list_interfaces():
    """List UP network interfaces and their IPs"""
    try:
        if not psutil:
            return jsonify({'error': 'psutil dependency missing. Please run build_voidpwn.sh again.'}), 500
            
        interfaces = []
        stats = psutil.net_if_stats()
        addrs = psutil.net_if_addrs()
        
        for name, stat in stats.items():
            if stat.isup and name != 'lo':
                ip = "N/A"
                if name in addrs:
                    for addr in addrs[name]:
                        if addr.family == 2: # AF_INET
                            ip = addr.address
                            break
                interfaces.append({
                    'name': name,
                    'ip': ip,
                    'speed': stat.speed
                })
        return jsonify({'interfaces': interfaces})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/wifi/status')
def wifi_status():
    """Check if connected to internet/network"""
    try:
        # Simplified: just return primary default interface IP
        result = subprocess.run(['hostname', '-I'], capture_output=True, text=True)
        ips = result.stdout.strip().split()
        return jsonify({'connected': len(ips) > 0, 'ip': ips[0] if ips else "N/A"})
    except:
        return jsonify({'connected': False, 'ip': "N/A"})

@app.route('/api/target/subnet', methods=['POST'])
def select_subnet_target():
    """Set the current active target to a subnet"""
    global CURRENT_TARGET
    data = request.get_json()
    subnet = data.get('subnet')
    interface = data.get('interface')
    if subnet:
        CURRENT_TARGET = {
            'type': 'subnet', 
            'cidr': subnet, 
            'ssid': subnet, 
            'interface': interface
        }
        return jsonify({'status': 'success', 'target': CURRENT_TARGET})
    return jsonify({'error': 'Subnet required'}), 400

@app.route('/api/target/select', methods=['POST'])
def select_target():
    """Set the current active target"""
    global CURRENT_TARGET
    data = request.get_json()
    CURRENT_TARGET = data
    return jsonify({'status': 'success', 'target': CURRENT_TARGET})

@app.route('/api/logs/live')
def get_live_logs():
    """Get the latest logs for the HUD"""
    return jsonify({'logs': list(LIVE_LOGS)})

@app.route('/api/logs/view/<filename>')
def view_full_log(filename):
    """Read the content of a specific log file (truncated)"""
    # Security: strip any path traversal attempts
    safe_name = os.path.basename(filename)
    log_path = os.path.join(LOGS_DIR, safe_name)
    
    if os.path.exists(log_path):
        try:
            # Read only last 2000 lines for performance
            cmd = f"tail -n 2000 \"{log_path}\""
            result = subprocess.check_output(cmd, shell=True).decode('utf-8', errors='replace')
            return jsonify({'content': result})
        except Exception as e:
            return jsonify({'error': f"Failed to read log: {str(e)}"}), 500
    return jsonify({'error': 'Log file not found'}), 404

@app.route('/api/logs/download/<filename>')
def download_log(filename):
    """Download the full raw log file"""
    safe_name = os.path.basename(filename)
    log_path = os.path.join(LOGS_DIR, safe_name)
    if os.path.exists(log_path):
        return send_from_directory(LOGS_DIR, safe_name, as_attachment=True)
    return jsonify({'error': 'File not found'}), 404

@app.route('/api/action/tft', methods=['POST'])
def action_switch_tft():
    """Switch to TFT output (install_lcd.sh)"""
    try:
        cmd = f"sudo {VOIDPWN_DIR}/scripts/core/install_lcd.sh"
        subprocess.Popen(cmd, shell=True)
        
        reporter.add_report(
            "SYSTEM", 
            "Display", 
            "Rebooting", 
            "Switching to TFT output"
        )
        
        return jsonify({'status': 'success', 'message': 'Switching to TFT & Rebooting...'})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/action/hdmi', methods=['POST'])
def action_switch_hdmi():
    """Switch to HDMI output"""
    try:
        script = os.path.join(VOIDPWN_DIR, 'scripts', 'core', 'restore_hdmi.sh')
        os.chmod(script, 0o755)
        subprocess.Popen(['bash', script])
        
        reporter.add_report(
            "SYSTEM", 
            "Display", 
            "Rebooting", 
            "Switching to HDMI output"
        )
        
        return jsonify({'status': 'success', 'message': 'Switching to HDMI & Rebooting...'})
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.route('/api/action/stop', methods=['POST'])
def action_stop_all():
    """Stop all active attacks and scans"""
    global SCAN_RUNNING
    try:
        # Kill common attack tools
        tools = ['aireplay-ng', 'airodump-ng', 'airbase-ng', 'wifite', 'bettercap', 'hcxdumptool', 'mdk4', 'nmap', 'reaver', 'bully']
        for tool in tools:
            subprocess.run(['sudo', 'killall', tool], stderr=subprocess.DEVNULL)
            
        SCAN_RUNNING = False
        add_live_log("🛑 STOPPED ALL ATTACKS", "error")
        return jsonify({'status': 'success', 'message': 'All active attacks stopped.'})
    except Exception as e:
        return jsonify({'error': str(e)}), 500


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
        cmd = f"sudo {VOIDPWN_DIR}/scripts/network/wifi_tools.sh --scan"
        subprocess.Popen(cmd, shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        
        SCAN_RUNNING = True
        
        reporter.add_report(
            "SCAN", 
            "WiFi Networks", 
            "Running", 
            "15-second network scan started"
        )
        
        return jsonify({'status': 'success', 'message': 'Scan started', 'duration': 15})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/scan/stop')
def stop_scan():
    """Stop the background airodump scan"""
    global SCAN_RUNNING
    try:
        subprocess.run(['sudo', 'killall', 'airodump-ng'], stderr=subprocess.DEVNULL)
        SCAN_RUNNING = False
        reporter.add_report("SCAN", "WiFi Networks", "Stopped", "Network scan stopped")
        return jsonify({'status': 'success', 'message': 'Scan stopped'})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/scan/results')
def get_scan_results():
    """Parse airodump CSV and return networks"""
    output_dir = os.path.join(VOIDPWN_DIR, 'output', 'captures')
    
    # Return empty if scan is running but no file yet
    try:
        files = glob.glob(os.path.join(output_dir, '*.csv'))
        if not files:
            if SCAN_RUNNING:
                return jsonify({'networks': [], 'message': 'Scan running, no results yet.'})
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
        reporter.add_report("WIFI (MONITOR-ON)", "Interface", "Success", "Enabled Monitor Mode")
        return jsonify({'status': 'success', 'message': 'Monitor mode enabling...'})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/action/monitor/off')
def action_monitor_off():
    """Disable monitor mode"""
    try:
        cmd = f"sudo {VOIDPWN_DIR}/scripts/network/wifi_tools.sh --monitor-off"
        subprocess.Popen(cmd.split(), stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        reporter.add_report("WIFI (MONITOR-OFF)", "Interface", "Success", "Disabled Monitor Mode")
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
        log_file = gen_log_name(f"eviltwin_{ssid}")
        cmd = f"sudo {VOIDPWN_DIR}/scripts/network/wifi_tools.sh --evil-twin \"{ssid}\" {channel}"
        
        report = reporter.add_report(
            "WIFI (EVIL TWIN)", 
            ssid, 
            "Started", 
            f"Launched Evil Twin on Ch {channel}",
            log_file=log_file
        )
        
        run_proc_and_capture(cmd, log_file=log_file, report_id=report['id'])
        
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
    
    channel = CURRENT_TARGET.get('channel', '')
    
    try:
        log_file = gen_log_name(f"deauth_{ssid}")
        cmd = f"sudo {VOIDPWN_DIR}/scripts/network/wifi_tools.sh --deauth {bssid} 0 {channel}"
        
        report = reporter.add_report(
            "WIFI (DEAUTH)", 
            ssid, 
            "Running", 
            f"Deauthing BSSID {bssid} (Ch {channel})",
            log_file=log_file
        )
        
        run_proc_and_capture(cmd, log_file=log_file, report_id=report['id'])
        
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
        script = os.path.join(VOIDPWN_DIR, 'scripts', 'core', 'restore_hdmi.sh')
        os.chmod(script, 0o755)
        subprocess.Popen(['bash', script])
        
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
        log_file = gen_log_name(f"handshake_{ssid}")
        cmd = f"sudo {VOIDPWN_DIR}/scripts/network/wifi_tools.sh --handshake {bssid} {channel} \"{ssid}\""
        
        report = reporter.add_report(
            "WIFI (HANDSHAKE)", 
            ssid, 
            "Started", 
            f"Capturing Handshake on Ch {channel}",
            log_file=log_file
        )
        
        run_proc_and_capture(cmd, log_file=log_file, report_id=report['id'])
        
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
        log_file = gen_log_name("crack")
        
        cmd = f"sudo {VOIDPWN_DIR}/scripts/network/wifi_tools.sh --crack \"{latest_cap}\""
        run_proc_and_capture(cmd, log_file=log_file)
        
        reporter.add_report(
            "WIFI (CRACK)", 
            filename, 
            "Started", 
            "Wordlist attack initiated",
            log_file=log_file
        )
        add_live_log(f"CRACKING STARTED: {filename}", "info")
        return jsonify({'status': 'success', 'message': f'Cracking {filename}...'})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/action/wifite', methods=['POST'])
def action_wifite():
    """Launch automated Wifite attack"""
    log_file = gen_log_name("wifite")
    try:
        report = reporter.add_report(
            "WIFI (AUTO-ATTACK)", 
            "ALL", 
            "Started", 
            "Automated Wifite Attack",
            log_file=log_file
        )
        
        cmd = f"sudo {VOIDPWN_DIR}/scripts/network/wifi_tools.sh --auto-attack"
        run_proc_and_capture(cmd, log_file=log_file, report_id=report['id'])
        add_live_log("WIFITE AUTO-ATTACK STARTED", "info")
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

    # Sanitize target: allow only IPs, CIDRs, and simple domain names
    if not re.match(r'^[a-zA-Z0-9\.\-\/: ]+$', target) or len(target) > 100:
        return jsonify({'error': 'Invalid target format'}), 400
        
    # Sanitize mode to whitelist only
    allowed_modes = {'quick', 'full', 'stealth', 'vuln', 'web', 'smb', 'dns', 'discover', 'comprehensive'}
    if mode not in allowed_modes:
        return jsonify({'error': 'Invalid mode'}), 400
        
    try:
        log_file = gen_log_name(f"recon_{mode}")
        flag = f"--{mode}"
        flag = f"--{mode}"
        cmd = f"sudo {VOIDPWN_DIR}/scripts/network/recon.sh {flag} \"{target}\""
        
        report = reporter.add_report(
            f"RECON ({mode.upper()})", 
            target, 
            "Started", 
            f"Mode: {mode.upper()}",
            log_file=log_file
        )
        
        run_proc_and_capture(cmd, log_file=log_file, report_id=report['id'])
        return jsonify({'status': 'success', 'message': f'Starting {mode} scan on {target}...'})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/action/pmkid', methods=['POST'])
def action_pmkid():
    """Capture PMKID (Clientless)"""
    data = request.get_json() or {}
    duration = data.get('duration', 300)
    
    log_file = gen_log_name("pmkid")
    try:
        cmd = f"sudo {VOIDPWN_DIR}/scripts/network/wifi_tools.sh --pmkid {duration}"
        run_proc_and_capture(cmd, log_file=log_file)
        
        reporter.add_report(
            "WIFI (PMKID)", 
            "ALL", 
            "Started", 
            f"Capture running for {duration}s",
            log_file=log_file
        )
        return jsonify({'status': 'success', 'message': f'PMKID capture started ({duration}s)...'})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/action/beacon', methods=['POST'])
def action_beacon():
    """MDK4 Beacon Flood"""
    data = request.get_json() or {}
    ssid_file = data.get('ssid_file', '')
    
    log_file = gen_log_name("beacon")
    try:
        cmd = f"sudo {VOIDPWN_DIR}/scripts/network/wifi_tools.sh --beacon {ssid_file}"
        run_proc_and_capture(cmd, log_file=log_file)
        
        reporter.add_report(
            "WIFI (BEACON)", 
            "CHAOS", 
            "Running", 
            "MDK4 Beacon Flooding active",
            log_file=log_file
        )
        return jsonify({'status': 'success', 'message': 'Beacon flood started...'})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/action/auth', methods=['POST'])
def action_auth_flood():
    """MDK4 Auth Flood"""
    data = request.get_json() or {}
    target = data.get('target', '')
    
    log_file = gen_log_name("auth_flood")
    try:
        cmd = f"sudo {VOIDPWN_DIR}/scripts/network/wifi_tools.sh --auth {target}"
        run_proc_and_capture(cmd, log_file=log_file)
        
        reporter.add_report(
            "WIFI (AUTH)", 
            target or "ALL", 
            "Running", 
            "MDK4 Authentication Flooding active",
            log_file=log_file
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
        
    log_file = gen_log_name("pixie")
    try:
        cmd = f"sudo {VOIDPWN_DIR}/scripts/network/wifi_tools.sh --pixie {target}"
        run_proc_and_capture(cmd, log_file=log_file)
        
        reporter.add_report(
            "WIFI (PIXIE)", 
            target, 
            "Started", 
            "WPS Pixie-Dust attack initiated",
            log_file=log_file
        )
        return jsonify({'status': 'success', 'message': f'Pixie-Dust attack launched on {target}...'})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

# --- Automated Scenario Endpoints ---
def run_scenario(name, cmd):
    """Helper to run a scenario and log it"""
    log_file = gen_log_name(name)
    try:
        report = reporter.add_report(f"SCENARIO ({name.upper()})", name, "Started", f"Launched scenario: {name}", log_file=log_file)
        run_proc_and_capture(cmd, log_file=log_file, report_id=report['id'])
        add_live_log(f"SCENARIO STARTED: {name}", "success")
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
    
    log_file = gen_log_name("throttle")
    try:
        cmd = f"sudo {VOIDPWN_DIR}/scripts/network/wifi_throttle.sh {target} {speed}"
        run_proc_and_capture(cmd, log_file=log_file)
        reporter.add_report("NETWORK (THROTTLE)", target, "Running", f"Limiting to {speed}", log_file=log_file)
        return jsonify({'status': 'success', 'message': f'Throttling {target} to {speed}'})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

# --- Configuration / Settings ---
CONFIG_FILE = os.path.join(VOIDPWN_DIR, 'output', 'config.json')

def load_config():
    if os.path.exists(CONFIG_FILE):
        try:
            with open(CONFIG_FILE, 'r') as f:
                return json.load(f)
        except:
            pass
    return {}

def save_config(data):
    try:
        os.makedirs(os.path.dirname(CONFIG_FILE), exist_ok=True)
        with open(CONFIG_FILE, 'w') as f:
            json.dump(data, f, indent=2)
        return True
    except Exception as e:
        print(f"Failed to save config: {e}")
        return False

@app.route('/api/settings', methods=['GET'])
def get_settings():
    """Return current settings - API key is masked, never returned in plaintext"""
    cfg = load_config()
    api_key = cfg.get('api_key', '')
    masked = ('*' * (len(api_key) - 4) + api_key[-4:]) if len(api_key) > 4 else ('*' * len(api_key))
    return jsonify({
        'provider': cfg.get('provider', 'gemini'),
        'api_key_masked': masked,
        'has_key': bool(api_key)
    })

@app.route('/api/settings', methods=['POST'])
def save_settings():
    """Save LLM provider and API key to config file"""
    data = request.get_json()
    if not data:
        return jsonify({'error': 'No data provided'}), 400
    cfg = load_config()
    if 'provider' in data:
        cfg['provider'] = data['provider']
    if 'api_key' in data and data['api_key']:
        cfg['api_key'] = data['api_key']
    if save_config(cfg):
        return jsonify({'status': 'success'})
    return jsonify({'error': 'Failed to save configuration'}), 500


# --- AI Analysis ---
def summarize_log(content, max_lines=3000):
    """
    Pre-process raw log content into a structured summary before sending to LLM.
    Extracts key findings: open ports, services, vulnerabilities, OS, errors.
    Returns a condensed structured text block.
    """
    lines = content.splitlines()[:max_lines]

    open_ports = []
    services = []
    vulnerabilities = []
    os_detected = []
    hosts = []
    errors = []
    wifi_networks = []
    handshakes = []
    misc_findings = []

    for line in lines:
        stripped = line.strip()
        if not stripped:
            continue

        # Nmap open ports
        if re.search(r'\d+/(tcp|udp)\s+open', stripped, re.I):
            open_ports.append(stripped)
        # Service/version lines
        elif re.search(r'\d+/(tcp|udp)\s+open\s+\S+\s+.+', stripped, re.I):
            services.append(stripped)
        # VULNERABLE findings
        elif 'VULNERABLE' in stripped or re.search(r'CVE-\d{4}-\d+', stripped):
            vulnerabilities.append(stripped)
        # OS detection
        elif re.search(r'OS (details|guess|CPE):', stripped, re.I) or re.search(r'Running:', stripped):
            os_detected.append(stripped)
        # Nmap host up
        elif 'Nmap scan report for' in stripped:
            hosts.append(stripped)
        # Handshake captures
        elif re.search(r'(handshake|WPA|PMKID|\.cap)', stripped, re.I):
            handshakes.append(stripped)
        # WiFi networks
        elif re.search(r'(ESSID|BSSID|beacon|channel|privacy)', stripped, re.I):
            wifi_networks.append(stripped)
        # Errors/warnings
        elif re.search(r'\b(error|warning|failed|denied|timeout)\b', stripped, re.I):
            errors.append(stripped)
        # NSE script output / interesting lines
        elif stripped.startswith('|') and len(stripped) > 4:
            misc_findings.append(stripped)

    # Cap each category to avoid token bloat
    def cap(lst, n): return lst[:n]

    summary_parts = [
        "=== STRUCTURED SCAN SUMMARY ===",
        f"Total log lines processed: {len(lines)}",
        "",
    ]

    if hosts:
        summary_parts += [f"--- DISCOVERED HOSTS ({len(hosts)}) ---"] + cap(hosts, 50) + [""]
    if open_ports:
        summary_parts += [f"--- OPEN PORTS ({len(open_ports)}) ---"] + cap(open_ports, 100) + [""]
    if services:
        summary_parts += [f"--- SERVICES & VERSIONS ({len(services)}) ---"] + cap(services, 60) + [""]
    if vulnerabilities:
        summary_parts += [f"--- VULNERABILITIES & CVEs ({len(vulnerabilities)}) ---"] + cap(vulnerabilities, 80) + [""]
    if os_detected:
        summary_parts += [f"--- OS DETECTION ({len(os_detected)}) ---"] + cap(os_detected, 20) + [""]
    if wifi_networks:
        summary_parts += [f"--- WIFI NETWORKS ({len(wifi_networks)}) ---"] + cap(wifi_networks, 40) + [""]
    if handshakes:
        summary_parts += [f"--- HANDSHAKES / CAPTURES ({len(handshakes)}) ---"] + cap(handshakes, 20) + [""]
    if misc_findings:
        summary_parts += [f"--- SCRIPT OUTPUT / FINDINGS ({len(misc_findings)}) ---"] + cap(misc_findings, 60) + [""]
    if errors:
        summary_parts += [f"--- ERRORS & WARNINGS ({len(errors)}) ---"] + cap(errors, 20) + [""]

    if not any([hosts, open_ports, vulnerabilities, wifi_networks]):
        # Fallback: send first 300 lines if nothing structured found
        summary_parts += ["--- RAW LOG EXCERPT (first 300 lines) ---"] + lines[:300]

    return "\n".join(summary_parts)


def call_gemini(api_key, prompt):
    url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent?key={api_key}"
    payload = json.dumps({
        "contents": [{"parts": [{"text": prompt}]}],
        "generationConfig": {"temperature": 0.3, "maxOutputTokens": 4096}
    }).encode('utf-8')
    req = urllib.request.Request(url, data=payload, headers={"Content-Type": "application/json", "X-goog-api-key": api_key}, method="POST")
    with urllib.request.urlopen(req, timeout=60) as resp:
        result = json.loads(resp.read().decode('utf-8'))
    return result['candidates'][0]['content']['parts'][0]['text']


def call_groq(api_key, prompt):
    url = "https://api.groq.com/openai/v1/chat/completions"
    payload = json.dumps({
        "model": "llama3-8b-8192",
        "messages": [{"role": "user", "content": prompt}],
        "temperature": 0.3,
        "max_tokens": 4096
    }).encode('utf-8')
    req = urllib.request.Request(url, data=payload, headers={
        "Content-Type": "application/json",
        "Authorization": f"Bearer {api_key}"
    }, method="POST")
    with urllib.request.urlopen(req, timeout=60) as resp:
        result = json.loads(resp.read().decode('utf-8'))
    return result['choices'][0]['message']['content']


def call_openai(api_key, prompt):
    url = "https://api.openai.com/v1/chat/completions"
    payload = json.dumps({
        "model": "gpt-4o-mini",
        "messages": [{"role": "user", "content": prompt}],
        "temperature": 0.3,
        "max_tokens": 4096
    }).encode('utf-8')
    req = urllib.request.Request(url, data=payload, headers={
        "Content-Type": "application/json",
        "Authorization": f"Bearer {api_key}"
    }, method="POST")
    with urllib.request.urlopen(req, timeout=60) as resp:
        result = json.loads(resp.read().decode('utf-8'))
    return result['choices'][0]['message']['content']


@app.route('/api/ai/analyze', methods=['POST'])
def ai_analyze():
    """
    Analyze a scan report using an LLM.
    Reads the log file, pre-processes it into a structured summary,
    then sends to the configured LLM with a checklist-driven prompt.
    """
    data = request.get_json()
    if not data:
        return jsonify({'error': 'No data provided'}), 400

    log_filename = data.get('log_filename')
    checklist = data.get('checklist', [])
    report_type = data.get('report_type', 'network scan')

    if not checklist:
        return jsonify({'error': 'Select at least one analysis section'}), 400

    # Load config
    cfg = load_config()
    api_key = cfg.get('api_key', '').strip()
    provider = cfg.get('provider', 'gemini')

    if not api_key:
        return jsonify({'error': 'No API key configured. Go to System > AI Configuration to add your key.'}), 400

    # Load log file content
    log_content = ""
    if log_filename:
        safe_name = os.path.basename(log_filename)
        log_path = os.path.join(LOGS_DIR, safe_name)
        if os.path.exists(log_path):
            try:
                with open(log_path, 'r', errors='replace') as f:
                    log_content = f.read()
            except Exception as e:
                return jsonify({'error': f'Failed to read log file: {str(e)}'}), 500

    # Pre-process into structured summary
    if log_content:
        structured_summary = summarize_log(log_content)
    else:
        structured_summary = f"No log file available. Report type: {report_type}"

    # Build sections string from checklist
    sections = "\n".join(f"- {item}" for item in checklist)

    # Build LLM prompt
    system_context = (
        "You are a senior penetration tester and security analyst with 15 years of experience. "
        "You have been given a structured summary of a pentest/network scan. "
        "Produce a professional, clear security report covering ONLY the sections requested. "
        "For each vulnerability or finding, include: description, severity (Critical/High/Medium/Low/Info), "
        "and specific actionable remediation steps. Use markdown formatting."
    )

    prompt = f"""{system_context}

SCAN TYPE: {report_type}

STRUCTURED SCAN DATA:
{structured_summary}

REQUESTED REPORT SECTIONS:
{sections}

Write the full professional security report now, covering each requested section. Be specific and actionable."""

    try:
        if provider == 'gemini':
            analysis = call_gemini(api_key, prompt)
        elif provider == 'groq':
            analysis = call_groq(api_key, prompt)
        elif provider == 'openai':
            analysis = call_openai(api_key, prompt)
        else:
            return jsonify({'error': f'Unknown provider: {provider}'}), 400

        return jsonify({'analysis': analysis})
    except urllib.error.HTTPError as e:
        body = e.read().decode('utf-8', errors='replace')
        return jsonify({'error': f'LLM API error ({e.code}): {body[:300]}'}), 502
    except Exception as e:
        return jsonify({'error': f'Failed to contact LLM: {str(e)}'}), 502


if __name__ == '__main__':
    print("Starting VoidPWN Dashboard Server...")
    print("Access dashboard at: http://<PI_IP>:5000")
    app.run(host='0.0.0.0', port=5000, debug=False)
