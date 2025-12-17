# VoidPWN Web Dashboard

## Overview

The VoidPWN Web Dashboard provides a real-time, terminal-style web interface for monitoring system stats, attack progress, and viewing results. It works on both the 3.5" LCD touchscreen and standard HDMI displays.

## Features

- Real-time system metrics (CPU, memory, disk, temperature)
- Attack statistics tracking
- Live activity logs
- Captured networks display
- Discovered hosts table
- WiFi captures and recon results viewer
- Responsive design for small screens (LCD compatible)
- Terminal/hacker aesthetic

## Installation

The dashboard is automatically set up during VoidPWN installation. Flask and psutil are installed by `setup.sh`.

## Usage

### Start the Dashboard

```bash
# From VoidPWN menu
voidpwn
# Select option 7 (Web Dashboard)
# Select option 1 (Start Dashboard)

# Or directly
cd ~/VoidPWN
./dashboard.sh start
```

### Access the Dashboard

Once started, access from any device on the network:

```
http://<RASPBERRY_PI_IP>:5000
```

Example:
```
http://192.168.1.100:5000
```

### On the Pi itself

Open Chromium browser:
```bash
chromium-browser http://localhost:5000 --kiosk
```

This opens in fullscreen kiosk mode, perfect for the LCD screen.

### Stop the Dashboard

```bash
./dashboard.sh stop
```

### Check Status

```bash
./dashboard.sh status
```

## Dashboard Sections

### Header
- System status indicator
- IP address
- Uptime
- Temperature
- WiFi adapter status

### System Metrics
- CPU usage with progress bar
- Memory usage with progress bar
- Disk usage with progress bar

### Attack Statistics
- WiFi scans performed
- Handshakes captured
- Network scans completed
- Hosts discovered
- Open ports found
- Vulnerabilities detected

### Active Targets
- Currently targeted systems
- Attack type
- Status

### Recent Activity Log
- Real-time log of all operations
- Color-coded by severity:
  - Green: Success
  - Blue: Info
  - Yellow: Warning
  - Red: Error

### Captured Networks
- ESSID (network name)
- BSSID (MAC address)
- Channel
- Signal strength

### Discovered Hosts
- IP addresses
- MAC addresses
- Open ports

## API Endpoints

The dashboard server provides REST API endpoints:

| Endpoint | Description |
|----------|-------------|
| `/api/system` | System information and metrics |
| `/api/stats` | Attack statistics |
| `/api/logs` | Recent activity logs |
| `/api/captures` | List of capture files |
| `/api/recon` | List of recon results |
| `/api/networks` | Scanned WiFi networks |
| `/api/hosts` | Discovered hosts |

## Customization

### Change Port

Edit `dashboard/server.py`:
```python
app.run(host='0.0.0.0', port=5000, debug=False)
```

Change `5000` to your desired port.

### Modify Refresh Rate

Edit `dashboard/index.html`:
```javascript
// Auto-refresh every 5 seconds
setInterval(() => {
    updateSystemInfo();
    updateStats();
}, 5000);  // Change 5000 to desired milliseconds
```

### Color Scheme

Edit `dashboard/index.html` CSS section:
```css
body {
    background: #0a0a0a;  /* Background color */
    color: #00ff00;       /* Text color */
}
```

## Kiosk Mode (LCD Screen)

To auto-start dashboard in kiosk mode on boot:

1. Start dashboard on boot:
```bash
# Add to /etc/rc.local (before exit 0)
/home/kali/VoidPWN/dashboard.sh start
```

2. Auto-open browser in kiosk mode:
```bash
# Create autostart file
mkdir -p ~/.config/autostart
cat > ~/.config/autostart/dashboard.desktop << EOF
[Desktop Entry]
Type=Application
Name=VoidPWN Dashboard
Exec=chromium-browser --kiosk http://localhost:5000
EOF
```

## Troubleshooting

### Dashboard won't start

```bash
# Check if Flask is installed
python3 -c "import flask"

# Install if missing
pip3 install flask psutil

# Check logs
tail -f /tmp/voidpwn_dashboard.log
```

### Can't access from other devices

```bash
# Check if server is running
./dashboard.sh status

# Check firewall
sudo ufw allow 5000

# Verify IP address
hostname -I
```

### Port already in use

```bash
# Find process using port 5000
sudo lsof -i :5000

# Kill it
sudo kill <PID>

# Or change port in server.py
```

## Performance

- Minimal CPU usage (< 5%)
- Low memory footprint (< 50MB)
- Works smoothly on 3.5" LCD (480x320)
- Auto-refresh every 5 seconds
- Responsive on slower networks

## Security Notes

- Dashboard runs on local network only (0.0.0.0:5000)
- No authentication by default
- For public access, use SSH tunnel:
  ```bash
  ssh -L 5000:localhost:5000 kali@<PI_IP>
  ```
- Consider adding basic auth for production use

## Files

```
VoidPWN/
├── dashboard/
│   ├── index.html      # Frontend dashboard
│   └── server.py       # Flask backend
└── dashboard.sh        # Control script
```

## Development

To modify the dashboard:

1. Edit `dashboard/index.html` for frontend changes
2. Edit `dashboard/server.py` for backend/API changes
3. Restart dashboard:
   ```bash
   ./dashboard.sh restart
   ```

## Future Enhancements

Planned features:
- Live packet capture visualization
- Network topology map
- Attack automation controls
- Report generation
- Multi-user support
- WebSocket for real-time updates
- Dark/light theme toggle
