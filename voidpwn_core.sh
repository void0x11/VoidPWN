#!/bin/bash

###############################################################################
# VoidPWN Core Orchestrator
# Unified hardened script for install lifecycle, dashboard service control,
# and aggressive attack/service shutdown.
###############################################################################

set -u

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DASHBOARD_DIR="$ROOT_DIR/dashboard"
SERVER_FILE="$DASHBOARD_DIR/server.py"

LOG_DIR="/var/log/voidpwn"
LOG_FILE="$LOG_DIR/voidpwn.log"
RUN_DIR="/var/run/voidpwn"
LOCK_FILE="/var/lock/voidpwn.lock"
INSTALL_DIR="/etc/voidpwn"
INSTALLED_FLAG="$INSTALL_DIR/.installed"

MASTER_PID_FILE="$RUN_DIR/master.pid"
DASHBOARD_PID_FILE="$RUN_DIR/dashboard.pid"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    local level="$1"
    shift
    local msg="$*"
    local ts
    ts="$(date '+%Y-%m-%d %H:%M:%S')"
    mkdir -p "$LOG_DIR" >/dev/null 2>&1 || true
    echo "[$ts] [$level] $msg" | tee -a "$LOG_FILE"
}

log_info() { log "INFO" "$*"; }
log_warn() { log "WARN" "$*"; }
log_error() { log "ERROR" "$*"; }
log_ok() { log "OK" "$*"; }

require_root() {
    if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
        echo -e "${RED}This script must run as root (sudo).${NC}"
        exit 1
    fi
}

ensure_runtime_dirs() {
    mkdir -p "$LOG_DIR" "$RUN_DIR" "$INSTALL_DIR"
}

write_master_pid() {
    echo "$$" > "$MASTER_PID_FILE"
}

acquire_lock() {
    ensure_runtime_dirs
    exec 9>"$LOCK_FILE"
    if ! flock -n 9; then
        log_error "Another voidpwn_core.sh instance is already running."
        exit 1
    fi
}

cleanup_on_exit() {
    rm -f "$MASTER_PID_FILE"
}

retry_cmd() {
    local attempts="$1"
    shift
    local n=1
    until "$@"; do
        if [[ "$n" -ge "$attempts" ]]; then
            return 1
        fi
        n=$((n + 1))
        log_warn "Command failed. Retrying ($n/$attempts): $*"
        sleep 2
    done
    return 0
}

run_critical() {
    local description="$1"
    shift
    log_info "$description"
    if ! retry_cmd 3 "$@"; then
        log_error "Critical step failed: $description"
        exit 1
    fi
}

run_best_effort() {
    local description="$1"
    shift
    log_info "$description"
    if ! retry_cmd 2 "$@"; then
        log_warn "Non-critical step failed: $description"
    fi
}

is_installed() {
    [[ -f "$INSTALLED_FLAG" ]]
}

mark_installed() {
    date '+%Y-%m-%d %H:%M:%S' > "$INSTALLED_FLAG"
}

ensure_dashboard_deps() {
    if ! python3 -c "import flask, psutil" >/dev/null 2>&1; then
        run_critical "Installing dashboard python dependencies" apt install -y python3-flask python3-psutil
    fi
}

install_packages() {
    run_best_effort "Refreshing package lists" apt update -y

    run_critical "Installing foundation packages" apt install -y \
        xserver-xorg x11-xserver-utils xinit xinput \
        matchbox-window-manager chromium unclutter \
        python3 python3-pip python3-flask python3-psutil \
        git wget curl iw pciutils net-tools iproute2

    run_best_effort "Installing wireless suite" apt install -y \
        aircrack-ng wifite bettercap mdk4 hcxdumptool hcxtools \
        reaver pixiewps hostapd dnsmasq

    run_best_effort "Installing network recon suite" apt install -y \
        nmap masscan wireshark tshark ettercap-text-only arp-scan dsniff \
        gdb ltrace strace

    run_best_effort "Installing exploit and cracking suite" apt install -y \
        hashcat john hydra medusa sqlmap responder enum4linux \
        gobuster dirb nikto wpscan whatweb

    run_best_effort "Installing forensic and reverse engineering tools" apt install -y \
        autopsy sleuthkit binwalk foremost exiftool radare2 ghidra

    run_best_effort "Installing python advanced tools" pip3 install volatility3 --break-system-packages
}

install_git_tools() {
    if [[ ! -d /opt/wifiphisher ]]; then
        run_best_effort "Cloning wifiphisher" git clone https://github.com/wifiphisher/wifiphisher.git /opt/wifiphisher
    fi

    if [[ ! -d /opt/fluxion ]]; then
        run_best_effort "Cloning fluxion" git clone https://github.com/FluxionNetwork/fluxion.git /opt/fluxion
    fi

    if [[ ! -d /opt/eaphammer ]]; then
        run_best_effort "Cloning eaphammer" git clone https://github.com/s0lst1c3/eaphammer /opt/eaphammer
    fi

    if [[ -f /opt/eaphammer/requirements.txt ]]; then
        run_best_effort "Installing eaphammer dependencies" pip3 install -r /opt/eaphammer/requirements.txt --break-system-packages
    fi

    if [[ ! -d /opt/pcredz ]]; then
        run_best_effort "Cloning PCredz" git clone https://github.com/lgandx/PCredz /opt/pcredz
    fi

    if [[ -f /opt/pcredz/requirements.txt ]]; then
        run_best_effort "Installing PCredz dependencies" pip3 install -r /opt/pcredz/requirements.txt --break-system-packages
    fi
}

register_systemd_service() {
    local service_file="/etc/systemd/system/voidpwn.service"
    log_info "Registering systemd service: $service_file"

    cat > "$service_file" <<EOF
[Unit]
Description=VoidPWN Core Orchestrator
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$ROOT_DIR/dashboard
ExecStart=/bin/bash $ROOT_DIR/voidpwn_core.sh start
Restart=on-failure
RestartSec=3
Environment=VOIDPWN_DIR=$ROOT_DIR

[Install]
WantedBy=multi-user.target
EOF

    run_critical "Reloading systemd" systemctl daemon-reload
    run_critical "Enabling voidpwn service" systemctl enable voidpwn.service
}

remove_monitor_interfaces() {
    if ! command -v iw >/dev/null 2>&1; then
        return 0
    fi

    local mon_ifaces
    mon_ifaces="$(iw dev 2>/dev/null | awk '/Interface/ {print $2}' | grep 'mon$' || true)"
    if [[ -n "$mon_ifaces" ]]; then
        while IFS= read -r iface; do
            [[ -z "$iface" ]] && continue
            log_info "Removing monitor interface: $iface"
            iw dev "$iface" del >/dev/null 2>&1 || true
        done <<< "$mon_ifaces"
    fi
}

kill_security_tools() {
    local tools=(
        aircrack-ng airodump-ng aireplay-ng airbase-ng
        mdk4 mdk3 bettercap wifite reaver bully hcxdumptool
        hostapd dnsmasq msfconsole msfvenom sqlmap hydra gobuster
        nikto responder wifiphisher fluxion eaphammer tshark tcpdump
        hashcat john medusa masscan ettercap arpspoof nmap
        wireshark dumpcap
    )

    for tool in "${tools[@]}"; do
        pkill -9 -x "$tool" >/dev/null 2>&1 || true
        pkill -9 -f "$tool" >/dev/null 2>&1 || true
    done
}

stop_system_network_services() {
    local services=(NetworkManager wpa_supplicant dhcpcd dhclient)

    for svc in "${services[@]}"; do
        if systemctl list-unit-files | grep -q "^${svc}\.service"; then
            log_info "Stopping service: $svc"
            systemctl stop "$svc" >/dev/null 2>&1 || true
        fi
    done

    pkill -9 -x dhcpcd >/dev/null 2>&1 || true
    pkill -9 -x dhclient >/dev/null 2>&1 || true
}

dashboard_running() {
    if [[ ! -f "$DASHBOARD_PID_FILE" ]]; then
        return 1
    fi

    local pid
    pid="$(cat "$DASHBOARD_PID_FILE" 2>/dev/null || true)"
    if [[ -z "$pid" ]]; then
        return 1
    fi

    if ps -p "$pid" >/dev/null 2>&1; then
        return 0
    fi

    return 1
}

dashboard_start() {
    if [[ ! -d "$DASHBOARD_DIR" || ! -f "$SERVER_FILE" ]]; then
        log_error "Dashboard path invalid: $DASHBOARD_DIR"
        return 1
    fi

    ensure_dashboard_deps

    if dashboard_running; then
        log_warn "Dashboard already running (PID: $(cat "$DASHBOARD_PID_FILE"))"
        return 0
    fi

    rm -f "$DASHBOARD_PID_FILE"

    log_info "Starting dashboard backend"
    (
        cd "$DASHBOARD_DIR" || exit 1
        nohup /usr/bin/python3 server.py >> "$LOG_FILE" 2>&1 &
        echo "$!" > "$DASHBOARD_PID_FILE"
    )

    local pid
    pid="$(cat "$DASHBOARD_PID_FILE" 2>/dev/null || true)"

    if [[ -z "$pid" ]]; then
        log_error "Failed to capture dashboard PID"
        return 1
    fi

    local i
    for i in {1..15}; do
        if ! ps -p "$pid" >/dev/null 2>&1; then
            log_error "Dashboard process exited early"
            rm -f "$DASHBOARD_PID_FILE"
            return 1
        fi

        if command -v curl >/dev/null 2>&1; then
            if curl -sSf http://127.0.0.1:5000 >/dev/null 2>&1; then
                log_ok "Dashboard healthy at http://127.0.0.1:5000"
                return 0
            fi
        else
            sleep 1
            if [[ "$i" -ge 3 ]]; then
                log_ok "Dashboard running (health check skipped: curl missing)"
                return 0
            fi
        fi
        sleep 1
    done

    log_warn "Dashboard started but health check timed out"
    return 0
}

dashboard_stop() {
    if dashboard_running; then
        local pid
        pid="$(cat "$DASHBOARD_PID_FILE")"
        log_info "Stopping dashboard PID: $pid"
        kill "$pid" >/dev/null 2>&1 || true

        local i
        for i in {1..5}; do
            if ! ps -p "$pid" >/dev/null 2>&1; then
                break
            fi
            sleep 1
        done

        if ps -p "$pid" >/dev/null 2>&1; then
            log_warn "Force killing dashboard PID: $pid"
            kill -9 "$pid" >/dev/null 2>&1 || true
        fi
    fi

    rm -f "$DASHBOARD_PID_FILE"
    pkill -9 -f "python3 .*dashboard/server.py" >/dev/null 2>&1 || true
}

kill_all_services() {
    log_info "Stopping dashboard and all active services/tools"
    dashboard_stop
    kill_security_tools
    stop_system_network_services
    remove_monitor_interfaces
    log_ok "Kill/cancel operation completed"
}

print_status() {
    echo "VoidPWN Core Status"
    echo "-------------------"
    if is_installed; then
        echo "Installed: yes ($(cat "$INSTALLED_FLAG" 2>/dev/null))"
    else
        echo "Installed: no"
    fi

    if dashboard_running; then
        echo "Dashboard: running (PID $(cat "$DASHBOARD_PID_FILE"))"
        echo "URL: http://127.0.0.1:5000"
    else
        echo "Dashboard: stopped"
    fi

    echo ""
    echo "Tracked PID files:"
    ls -1 "$RUN_DIR"/*.pid 2>/dev/null || echo "(none)"

    echo ""
    echo "Active security processes:"
    pgrep -af "airodump-ng|aireplay-ng|aircrack-ng|bettercap|wifite|hcxdumptool|mdk4|reaver|nmap|sqlmap|hashcat|hydra|gobuster|nikto|responder|arpspoof|ettercap" || echo "(none)"
}

do_install() {
    if is_installed; then
        log_ok "Install marker exists; skipping installation"
        register_systemd_service
        return 0
    fi

    log_info "Starting first-run installation"
    install_packages
    install_git_tools
    register_systemd_service
    mark_installed
    log_ok "Installation completed and marker created"
}

cmd_run() {
    if ! is_installed; then
        do_install
    fi
    dashboard_start
}

cmd_install() {
    do_install
}

cmd_start() {
    dashboard_start
}

cmd_stop() {
    kill_all_services
}

cmd_restart() {
    kill_all_services
    sleep 1
    dashboard_start
}

usage() {
    cat <<EOF
Usage: $0 [run|install|start|stop|restart|status]

Commands:
  run      Auto mode: install on first run, then start dashboard
  install  Force install flow (idempotent)
  start    Start dashboard backend only
  stop     Kill/cancel all active services and tools
  restart  Stop all then restart dashboard
  status   Show install state, PIDs, and active processes
EOF
}

main() {
    local cmd="${1:-run}"

    require_root
    acquire_lock
    trap cleanup_on_exit EXIT INT TERM
    write_master_pid

    case "$cmd" in
        run) cmd_run ;;
        install) cmd_install ;;
        start) cmd_start ;;
        stop) cmd_stop ;;
        restart) cmd_restart ;;
        status) print_status ;;
        *)
            usage
            exit 1
            ;;
    esac
}

main "$@"
