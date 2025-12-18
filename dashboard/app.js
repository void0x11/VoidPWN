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
    await checkSelectedDevice();
    loadReports();
    refreshSystemInfo();
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
    log(`Starting ${mode} device discovery...`);
    const res = await api('/api/devices/scan', 'POST', { mode });
    if (res.status === 'success') {
        log(`✓ Discovered ${res.count} devices.`);
        state.devices = res.devices;
        renderDeviceList();
    } else {
        log(`ERROR: ${res.error}`, 'error');
    }
}

function renderDeviceList() {
    const container = document.getElementById('inventory-list');
    if (!container) return;

    container.innerHTML = '';
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
    inputs.forEach(i => i.value = state.selectedDevice ? state.selectedDevice.ip : (state.selectedNetwork ? state.selectedNetwork.bssid : ''));
}

// --- WiFi / Network ---
async function scanWifi() {
    const btn = document.getElementById('scan-wifi-btn');
    btn.textContent = "SCANNING...";
    btn.disabled = true;

    const list = document.getElementById('wifi-list');
    list.innerHTML = '<div style="text-align:center; padding: 20px;">ACCESSING ADAPTER...</div>';

    const res = await api('/api/wifi/networks');
    btn.textContent = "REFRESH";
    btn.disabled = false;

    if (res.error) {
        list.innerHTML = `<div class="log-entry error">${res.error}</div>`;
        return;
    }

    list.innerHTML = '';
    res.networks.forEach(net => {
        const row = document.createElement('div');
        row.className = 'device-card';
        row.innerHTML = `
            <div style="display:flex; justify-content:space-between">
                <span>${net.ssid}</span>
                <span style="color:var(--primary)">${net.signal}%</span>
            </div>
            <div style="font-size:0.75rem; color:var(--text-dim)">${net.security}</div>
        `;
        row.onclick = () => {
            state.selectedNetwork = net;
            selectTargetNetwork(net);
        };
        list.appendChild(row);
    });
}

async function selectTargetNetwork(net) {
    state.selectedNetwork = net;
    // Notify backend
    await api('/api/target/select', 'POST', net);

    document.getElementById('wifi-password-input').placeholder = `Password for ${net.ssid}`;
    updateTargetDisplays();
    log(`NETWORK TARGET: ${net.ssid} (${net.bssid || 'Managed'})`);
}

async function connectWifi() {
    if (!state.selectedNetwork) return alert("Select a network!");
    const net = state.selectedNetwork;
    const pass = document.getElementById('wifi-password-input').value;
    log(`Connecting to ${net.ssid}...`);
    const res = await api('/api/wifi/connect', 'POST', { ssid: net.ssid, password: pass });
    if (res.status === 'success') log(res.message, 'success');
}

// --- Attacks & Recon ---
async function runAction(action, data = {}) {
    const ipTarget = state.selectedDevice ? state.selectedDevice.ip : null;
    const wifiTarget = state.selectedNetwork ? state.selectedNetwork.bssid : null;

    // Determine target based on action type
    const wifiActions = ['deauth', 'evil_twin', 'handshake', 'pmkid', 'pixie', 'auth', 'wifite'];
    const target = wifiActions.includes(action) ? wifiTarget : ipTarget;

    if (action === 'recon' && !target) return alert("Select a Device Target!");
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
    const target = state.selectedDevice ? state.selectedDevice.ip : null;
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
    entry.innerHTML = `<span class="time">[${time}]</span> ${msg}`;

    container.appendChild(entry);
    container.scrollTop = container.scrollHeight;
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
