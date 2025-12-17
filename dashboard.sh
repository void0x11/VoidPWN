#!/bin/bash

################################################################################
# VoidPWN - Dashboard Launcher
# Description: Start the web dashboard server
# Author: void0x11
# Usage: ./dashboard.sh [start|stop|status]
################################################################################

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[*]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }

DASHBOARD_DIR="$HOME/VoidPWN/dashboard"
PID_FILE="/tmp/voidpwn_dashboard.pid"

# Check if Flask is installed
check_dependencies() {
    if ! python3 -c "import flask" 2>/dev/null; then
        log_warning "Flask not installed. Installing..."
        pip3 install flask psutil
    fi
}

# Start dashboard
start_dashboard() {
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if ps -p "$PID" > /dev/null 2>&1; then
            log_warning "Dashboard already running (PID: $PID)"
            return 1
        fi
    fi
    
    log_info "Starting VoidPWN Dashboard..."
    cd "$DASHBOARD_DIR"
    
    # Start server in background
    nohup python3 server.py > /tmp/voidpwn_dashboard.log 2>&1 &
    echo $! > "$PID_FILE"
    
    sleep 2
    
    if ps -p $(cat "$PID_FILE") > /dev/null 2>&1; then
        IP=$(hostname -I | awk '{print $1}')
        log_success "Dashboard started successfully"
        echo ""
        log_info "Access dashboard at:"
        echo "  http://$IP:5000"
        echo "  http://localhost:5000"
        echo ""
        log_info "View logs: tail -f /tmp/voidpwn_dashboard.log"
    else
        log_error "Failed to start dashboard"
        return 1
    fi
}

# Stop dashboard
stop_dashboard() {
    if [ ! -f "$PID_FILE" ]; then
        log_warning "Dashboard not running"
        return 1
    fi
    
    PID=$(cat "$PID_FILE")
    if ps -p "$PID" > /dev/null 2>&1; then
        log_info "Stopping dashboard (PID: $PID)..."
        kill "$PID"
        rm "$PID_FILE"
        log_success "Dashboard stopped"
    else
        log_warning "Dashboard not running (stale PID file)"
        rm "$PID_FILE"
    fi
}

# Check status
check_status() {
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if ps -p "$PID" > /dev/null 2>&1; then
            IP=$(hostname -I | awk '{print $1}')
            log_success "Dashboard is running (PID: $PID)"
            echo "  URL: http://$IP:5000"
        else
            log_error "Dashboard not running (stale PID file)"
            rm "$PID_FILE"
        fi
    else
        log_warning "Dashboard is not running"
    fi
}

# Main
case "$1" in
    start)
        check_dependencies
        start_dashboard
        ;;
    stop)
        stop_dashboard
        ;;
    restart)
        stop_dashboard
        sleep 1
        check_dependencies
        start_dashboard
        ;;
    status)
        check_status
        ;;
    *)
        echo "VoidPWN Dashboard Manager"
        echo ""
        echo "Usage: $0 {start|stop|restart|status}"
        echo ""
        echo "Commands:"
        echo "  start   - Start the dashboard server"
        echo "  stop    - Stop the dashboard server"
        echo "  restart - Restart the dashboard server"
        echo "  status  - Check dashboard status"
        exit 1
        ;;
esac
