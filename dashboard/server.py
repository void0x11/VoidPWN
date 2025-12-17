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
from datetime import datetime

app = Flask(__name__, static_folder='.')

# Paths
VOIDPWN_DIR = os.path.expanduser('~/VoidPWN')
CAPTURES_DIR = os.path.join(VOIDPWN_DIR, 'captures')
RECON_DIR = os.path.join(VOIDPWN_DIR, 'recon')

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

@app.route('/api/hosts')
def get_hosts():
    """Get discovered hosts (placeholder)"""
    # This would parse nmap output files
    return jsonify({'hosts': []})

if __name__ == '__main__':
    print("Starting VoidPWN Dashboard Server...")
    print("Access dashboard at: http://<PI_IP>:5000")
    app.run(host='0.0.0.0', port=5000, debug=False)
