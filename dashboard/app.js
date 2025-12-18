/**
 * VoidPWN Dashboard V3 - Application Logic
 * Handles device management, tab switching, and API interaction
 */

const state = {
    activeTab: 'connect',
    devices: [],
    selectedDevice: null,
    targetNetwork: null,
    system: {},
    stats: {},
    reports: [],
    kbVisible: false
};

// --- Initialization ---
document.addEventListener('DOMContentLoaded', async () => {
    initTabs();
    initRefresh();
    await loadDeviceList();
    await loadInterfaces();
    await checkSelectedDevice();
    loadReports();
    setInterval(refreshSystemInfo, 5000);
    setInterval(pollLiveLogs, 1000);
});

async function checkSelectedDevice() {
    const res = await api('/api/devices/selected');
    if (res.device) {
        state.selectedDevice = res.device;
        updateTargetDisplays();
    }
}

function initTabs() {
    const btns = document.querySelectorAll('.nav-btn');
    btns.forEach(btn => {
        btn.onclick = () => {
            const tab = btn.dataset.tab;
            switchTab(tab);
        };
    });
}

function switchTab(tabId) {
    state.activeTab = tabId;

    // Update navigation
    document.querySelectorAll('.nav-btn').forEach(b => {
        b.classList.toggle('active', b.dataset.tab === tabId);
    });

    // Update content
    document.querySelectorAll('.tab-content').forEach(c => {
        c.classList.toggle('active', c.id === `tab-${tabId}`);
    });

    if (tabId === 'reports') loadReports();
}

function initRefresh() {
    setInterval(refreshSystemInfo, 5000);
}

// --- API Helper ---
async function api(path, method = 'GET', body = null) {
    try {
        const options = {
            method,
            headers: { 'Content-Type': 'application/json' }
        };
        if (body) options.body = JSON.stringify(body);

        const response = await fetch(path, options);
        return await response.json();
    } catch (err) {
        console.error(`API Error (${path}):`, err);
        return { error: err.message };
    }
}

// --- Device Management ---
async function loadDeviceList() {
    const res = await api('/api/devices/list');
    if (res.devices) {
        state.devices = res.devices;
        renderDeviceList();
    }
}

async function scanDevices(mode = 'quick') {
    log(`Starting ${mode} network discovery...`);
    // Use currently selected network if it's a subnet
    const body = { mode };
    if (state.selectedNetwork && state.selectedNetwork.type === 'subnet') {
        body.subnet = state.selectedNetwork.cidr;
    }

    const res = await api('/api/devices/scan', 'POST', body);
    if (res.status === 'success') {
        log(`✓ Discovered ${res.count} devices on ${res.subnet || 'default subnet'}. Added to inventory.`, 'success');
        await loadDeviceList();
    } else {
        log(`ERROR: ${res.error}`, 'error');
    }
}

function renderDeviceList() {
    const container = document.getElementById('inventory-list');
    const targetDisplay = document.getElementById('active-target-display');
    if (!container) return;

    container.innerHTML = '';

    // 1. Show Network Target if any
    if (state.selectedNetwork) {
        targetDisplay.style.display = 'block';
        const badge = targetDisplay.querySelector('.active-target-badge');
        badge.textContent = state.selectedNetwork.cidr || state.selectedNetwork.ssid || state.selectedNetwork.bssid;

        // Add a special card for the subnet in the inventory too
        const subnetCard = document.createElement('div');
        subnetCard.className = 'device-card selected';
        subnetCard.style.borderColor = 'var(--secondary)';
        subnetCard.innerHTML = `
            <div style="font-size:0.6rem; color:var(--secondary); text-transform:uppercase">Active Network</div>
            <div class="ip">${state.selectedNetwork.cidr || state.selectedNetwork.ssid}</div>
            <div class="host">Broadcasting / Subnet</div>
        `;
        container.appendChild(subnetCard);
    } else {
        targetDisplay.style.display = 'none';
    }

    // 2. Show Devices
    state.devices.forEach(device => {
        const card = document.createElement('div');
        card.className = `device-card ${state.selectedDevice?.id === device.id ? 'selected' : ''}`;

        let tagsHtml = device.tags ? device.tags.map(t => `<span class="tag">${t}</span>`).join('') : '';

        card.innerHTML = `
            <div class="ip">${device.ip}</div>
            <div class="host">${device.hostname || 'Unknown Host'}</div>
            <div class="tag-container">${tagsHtml}</div>
            <div class="card-actions">
                <button class="btn-mini" onclick="event.stopPropagation(); selectDeviceByID('${device.id}')">TARGET</button>
                <button class="btn-mini" onclick="event.stopPropagation(); openDeviceModal('${device.id}')">DETAILS</button>
            </div>
        `;
        card.onclick = () => selectDevice(device);
        container.appendChild(card);
    });
}

function selectDeviceByID(id) {
    const dev = state.devices.find(d => d.id === id);
    if (dev) selectDevice(dev);
}

async function selectDevice(device) {
    state.selectedDevice = device;
    await api('/api/devices/select', 'POST', { id: device.id });

    // Update UI
    renderDeviceList();
    updateTargetDisplays();
    log(`Target set to: ${device.ip} (${device.hostname})`);
}

function updateTargetDisplays() {
    let targetText = "NONE SELECTED";
    if (state.selectedDevice) {
        targetText = `[IP] ${state.selectedDevice.ip} (${state.selectedDevice.hostname})`;
    } else if (state.selectedNetwork) {
        targetText = `[WiFi] ${state.selectedNetwork.ssid} (${state.selectedNetwork.bssid || '???'})`;
    }

    const badges = document.querySelectorAll('.active-target-badge');
    badges.forEach(b => b.textContent = targetText);

    // Update inputs
    const inputs = document.querySelectorAll('.target-input');
    inputs.forEach(i => {
        if (state.selectedDevice) i.value = state.selectedDevice.ip;
        else if (state.selectedNetwork) i.value = state.selectedNetwork.cidr || state.selectedNetwork.ssid || state.selectedNetwork.bssid;
        else i.value = "";
    });
}

// --- WiFi / Network ---
// --- Network Interfaces & Discovery ---
async function loadInterfaces() {
    const btn = document.getElementById('scan-wifi-btn');
    btn.textContent = "REFRESHING...";
    btn.disabled = true;

    const list = document.getElementById('wifi-list');
    list.innerHTML = '<div style="text-align:center; padding: 20px;">FETCHING NICS...</div>';

    const res = await api('/api/interfaces');
    btn.textContent = "REFRESH";
    btn.disabled = false;

    if (res.error) {
        list.innerHTML = `<div class="log-entry error">${res.error}</div>`;
        return;
    }

    if (res.interfaces) {
        list.innerHTML = '';
        res.interfaces.forEach(nic => {
            const row = document.createElement('div');
            row.className = `device-card ${state.selectedNetwork?.cidr?.includes(nic.ip.split('.').slice(0, 3).join('.')) ? 'selected' : ''}`;
            row.style.cursor = 'pointer';
            row.innerHTML = `
                <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:5px">
                    <span style="font-weight:bold">${nic.name}</span>
                    <span style="color:var(--primary); font-size:0.8rem">${nic.ip}</span>
                </div>
                <div style="font-size:0.75rem; color:var(--text-dim)">Speed: ${nic.speed}Mb/s</div>
                <div style="font-size:0.65rem; color:var(--primary); margin-top:5px; text-transform:uppercase">Click to set target subnet</div>
            `;
            row.onclick = () => selectInterface(nic.name, nic.ip);
            list.appendChild(row);
        });
    }
}

async function selectInterface(name, ip) {
    if (ip === "N/A" || !ip) return log("Interface has no IP!", "error");
    const subnet = ip.split('.').slice(0, 3).join('.') + '.0/24';
    log(`SETTING TARGET SUBNET: ${subnet}...`, 'info');
    const res = await api('/api/target/subnet', 'POST', { subnet });
    if (res.status === 'success') {
        state.selectedNetwork = res.target;
        state.selectedDevice = null; // Clear selected device when switching subnets
        updateTargetDisplays();
        renderDeviceList(); // Refresh inventory to show subnet card
        loadInterfaces(); // Refresh interface list to show selection
        log(`✓ Target updated to ${subnet}`, 'success');
    }
}

async function scanSubnet(name, ip) {
    if (ip === "N/A" || !ip) return log("Interface has no IP!", "error");
    const subnet = ip.split('.').slice(0, 3).join('.') + '.0/24';
    log(`Starting automated discovery on ${subnet} via ${name}...`);

    // Switch to Scan Tab visually
    document.querySelector('[data-tab="scan"]').click();

    const res = await api('/api/devices/scan', 'POST', { interface: name, mode: 'quick' });
    if (res.status === 'success') {
        log(`Discovered ${res.count} devices on ${res.subnet}`, 'success');
        await loadDeviceList();
    } else {
        log(res.error, 'error');
    }
}

// --- Attacks & Recon ---
async function runAction(action, data = {}) {
    const ipTarget = state.selectedDevice ? state.selectedDevice.ip : null;
    const wifiTarget = state.selectedNetwork ? state.selectedNetwork.bssid : null;

    // Determine target based on action type
    const wifiActions = ['deauth', 'evil_twin', 'handshake', 'pmkid', 'pixie', 'auth', 'wifite'];
    let target = wifiActions.includes(action) ? wifiTarget : ipTarget;

    // Fallback to subnet CIDR for network-wide actions (recon)
    if (!target && action === 'recon' && state.selectedNetwork) {
        target = state.selectedNetwork.cidr;
    }

    if (action === 'recon' && !target) return alert("Select a Device or Subnet Target!");
    if (wifiActions.includes(action) && !target && !['pmkid', 'wifite', 'beacon', 'auth'].includes(action)) {
        return alert("Select a WiFi Network Target!");
    }

    log(`INITIATING ${action.toUpperCase()}...`);
    const res = await api(`/api/action/${action}`, 'POST', { target, ...data });

    if (res.status === 'success') {
        log(`✓ ${action.toUpperCase()} started`, 'success');
    } else {
        log(`ERROR: ${res.error || res.message}`, 'error');
    }
}

async function runScenario(scenario) {
    let target = state.selectedDevice ? state.selectedDevice.ip : null;

    // Fallback to subnet if no device is selected
    if (!target && state.selectedNetwork) {
        target = state.selectedNetwork.cidr;
    }

    if (!target) return alert("Select a Device or Subnet Target!");

    log(`EXECUTING SCENARIO: ${scenario.toUpperCase()}...`);

    const res = await api(`/api/scenario/${scenario}`, 'POST', { target });
    if (res.status === 'success') {
        log(`✓ Scenario ${scenario} running`, 'success');
        switchTab('reports');
    } else {
        log(`FAILED: ${res.error}`, 'error');
    }
}

// --- Logging & UI Helpers ---
function log(msg, type = '') {
    const container = document.getElementById('attack-log');
    if (!container) return;

    const time = new Date().toLocaleTimeString([], { hour12: false });
    const entry = document.createElement('div');
    entry.className = `log-entry ${type}`;
    entry.innerHTML = `<span class="time">[${time}]</span> <span class="msg">${msg}</span>`;

    container.appendChild(entry);
    container.scrollTop = container.scrollHeight;
}

let lastLogsHash = "";
async function pollLiveLogs() {
    const res = await api('/api/logs/live');
    if (res.logs) {
        const logsJSON = JSON.stringify(res.logs);
        if (logsJSON === lastLogsHash) return; // No changes

        lastLogsHash = logsJSON;
        const container = document.getElementById('attack-log');
        if (!container) return;

        container.innerHTML = '';
        res.logs.forEach(l => {
            const entry = document.createElement('div');
            entry.className = `log-entry ${l.type}`;
            entry.innerHTML = `<span class="time">[${l.time}]</span> <span class="msg">${l.msg}</span>`;
            container.appendChild(entry);
        });
        container.scrollTop = container.scrollHeight;
    }
}

async function loadReports() {
    const res = await api('/api/reports');
    const container = document.getElementById('reports-body');
    if (!container) return;

    container.innerHTML = '';
    res.reports.forEach(r => {
        const tr = document.createElement('tr');
        tr.innerHTML = `
            <td>${r.timestamp.split('T')[1].split('.')[0]}</td>
            <td style="color:var(--primary)">${r.type}</td>
            <td>${r.target}</td>
            <td class="${r.status.toLowerCase()}">${r.status}</td>
        `;
        container.appendChild(tr);
    });
}

async function refreshSystemInfo() {
    const res = await api('/api/system');
    if (res.error) return;

    document.getElementById('val-cpu').textContent = res.cpu + '%';
    document.getElementById('val-ram').textContent = res.memPercent + '%';
    document.getElementById('val-temp').textContent = res.temp;
    document.getElementById('val-ip').textContent = res.ip;
}

// --- Keyboard ---
function showKeyboard(targetId) {
    state.activeInput = document.getElementById(targetId);
    document.getElementById('keyboard').classList.add('active');
}

function typeKey(key) {
    if (!state.activeInput) return;
    if (key === 'BACK') {
        state.activeInput.value = state.activeInput.value.slice(0, -1);
    } else if (key === 'ENTER') {
        document.getElementById('keyboard').classList.remove('active');
    } else {
        state.activeInput.value += key;
    }
}

// --- Modal Logic ---
function openDeviceModal(id) {
    const device = state.devices.find(d => d.id === id);
    if (!device) return;

    state.editingDevice = device;

    document.getElementById('modal-title').textContent = (device.hostname || device.ip).toUpperCase();
    document.getElementById('det-ip').textContent = device.ip;
    document.getElementById('det-mac').textContent = device.mac || '??:??:??:??:??:??';
    document.getElementById('det-vendor').textContent = device.device_type || 'Unknown';

    const ports = document.getElementById('det-ports');
    ports.innerHTML = device.ports && device.ports.length
        ? device.ports.map(p => {
            const num = p.toString().split('/')[0];
            return `<span class="tag secondary">PORT ${num}</span>`;
        }).join('')
        : '<span style="color:var(--text-dim)">No ports discovered. Run Deep Scan.</span>';

    document.getElementById('det-notes').value = device.notes || '';
    document.getElementById('det-tags').value = device.tags ? device.tags.join(', ') : '';

    document.getElementById('device-modal').classList.add('active');
}

function closeModal() {
    document.getElementById('device-modal').classList.remove('active');
}

async function saveDeviceMetadata() {
    const dev = state.editingDevice;
    if (!dev) return;

    const notes = document.getElementById('det-notes').value;
    const tags = document.getElementById('det-tags').value.split(',').map(t => t.trim()).filter(t => t !== "");

    log(`Saving metadata for ${dev.ip}...`);
    const res = await api('/api/devices/update', 'POST', { id: dev.id, notes, tags });

    if (res.status === 'success') {
        log(`✓ Metadata updated`, 'success');
        await loadDeviceList();
        closeModal();
    } else {
        alert("Failed to save: " + res.error);
    }
}
