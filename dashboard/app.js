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
    kbVisible: false,
    scanningWiFi: false
};

// --- Initialization ---
document.addEventListener('DOMContentLoaded', async () => {
    initTabs();
    initRefresh();
    await loadDeviceList();
    await loadInterfaces();
    await checkSelectedDevice();
    loadReports();
    loadSettings();
    setInterval(refreshSystemInfo, 5000);
    setInterval(pollLiveLogs, 1000);
    setInterval(loadReports, 10000); // Poll reports every 10s
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

    // Toggle body class for reports page (hides sidebar)
    document.body.classList.toggle('reports-active', tabId === 'reports');

    if (tabId === 'reports') loadReports();
}

function initRefresh() {
    setInterval(refreshSystemInfo, 5000);
}

// --- Security: HTML escape to prevent XSS ---
function escHtml(str) {
    if (str == null) return '';
    return String(str)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#39;');
}

// --- API Helper ---
async function api(path, method = 'GET', body = null) {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 30000);
    try {
        const options = {
            method,
            headers: { 'Content-Type': 'application/json' },
            signal: controller.signal
        };
        if (body) options.body = JSON.stringify(body);

        const response = await fetch(path, options);
        return await response.json();
    } catch (err) {
        console.error(`API Error (${path}):`, err);
        return { error: err.message };
    } finally {
        clearTimeout(timeout);
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
            <div class="ip">${escHtml(state.selectedNetwork.cidr || state.selectedNetwork.ssid)}</div>
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

        let tagsHtml = device.tags ? device.tags.map(t => `<span class="tag">${escHtml(t)}</span>`).join('') : '';

        card.innerHTML = `
            <div class="ip">${escHtml(device.ip)}</div>
            <div class="host">${escHtml(device.hostname || 'Unknown Host')}</div>
            <div class="tag-container">${tagsHtml}</div>
            <div class="card-actions">
                <button class="btn-mini" onclick="event.stopPropagation(); selectDeviceByID('${escHtml(device.id)}')">TARGET</button>
                <button class="btn-mini" onclick="event.stopPropagation(); openDeviceModal('${escHtml(device.id)}')">DETAILS</button>
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
    log(`SETTING TARGET SUBNET: ${subnet} (${name})...`, 'info');
    const res = await api('/api/target/subnet', 'POST', { subnet, interface: name });
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

// --- WiFi Target Selection & Scanning ---
async function startWiFiScan() {
    if (state.scanningWiFi) return;
    state.scanningWiFi = true;

    const btn = document.getElementById('wifi-refresh-btn');
    const container = document.getElementById('nearby-wifi-list');

    log("INITIATING WIFI SPECTRUM SCAN (15s)...", "info");
    const res = await api('/api/scan/start');

    if (res.status === 'success') {
        let countdown = res.duration || 15;
        btn.disabled = true;

        const timer = setInterval(() => {
            btn.textContent = `SCANNING... ${countdown}s`;
            countdown--;
            if (countdown < 0) {
                clearInterval(timer);
                btn.disabled = false;
                btn.textContent = "REFRESH NETWORKS";
                state.scanningWiFi = false;
                loadWiFiResults();
            }
        }, 1000);

        container.innerHTML = '<div style="text-align:center; padding: 20px; color:var(--primary)">SCANNING SPECTRUM... PLEASE WAIT</div>';
    } else {
        state.scanningWiFi = false;
        log("WiFi scan failed to start", "error");
    }
}

async function loadWiFiResults() {
    const container = document.getElementById('nearby-wifi-list');
    container.innerHTML = '<div style="text-align:center; padding: 20px;">FETCHING RESULTS...</div>';

    const res = await api('/api/scan/results');
    if (res.networks && res.networks.length > 0) {
        container.innerHTML = '';
        res.networks.forEach(net => {
            const card = document.createElement('div');
            card.className = `device-card ${state.selectedNetwork?.bssid === net.bssid ? 'selected' : ''}`;
            card.style.cursor = 'pointer';
            card.style.borderLeft = `4px solid ${net.privacy.includes('WPA') ? '#ff3366' : '#ffee00'}`;

            card.innerHTML = `
                <div style="display:flex; justify-content:space-between; align-items:center;">
                    <span style="font-weight:bold">${escHtml(net.essid) || '&lt;HIDDEN&gt;'}</span>
                    <span style="color:var(--text-dim); font-size:0.7rem">${escHtml(net.power)} dBm</span>
                </div>
                <div style="font-size:0.7rem; color:var(--primary); font-family:var(--font-mono)">${escHtml(net.bssid)}</div>
                <div style="display:flex; justify-content:space-between; font-size:0.65rem; margin-top:5px">
                    <span>CH: ${escHtml(net.channel)}</span>
                    <span>${escHtml(net.privacy)}</span>
                </div>
            `;
            card.onclick = () => selectWiFiNetwork(net.bssid, net.essid, net.channel);
            container.appendChild(card);
        });
        log(`✓ Found ${res.networks.length} networks`, 'success');
    } else {
        container.innerHTML = '<div style="text-align:center; padding: 20px; color:var(--text-dim)">No networks found. Try scanning again.</div>';
    }
}

async function selectWiFiNetwork(bssid, essid, channel) {
    state.selectedNetwork = {
        type: 'wifi',
        bssid: bssid,
        ssid: essid || bssid,
        channel: channel
    };
    state.selectedDevice = null;

    // Notify server of target change if needed (optional for BSSID as runAction handles it)
    await api('/api/target/select', 'POST', state.selectedNetwork);

    updateTargetDisplays();
    loadWiFiResults(); // Re-render to show selection
    renderDeviceList(); // Sync inventory
    log(`Target WiFi set to: ${essid || bssid}`);
}

// --- Attacks & Recon ---
async function runAction(action, data = {}) {
    const ipTarget = state.selectedDevice ? state.selectedDevice.ip : null;
    const wifiTarget = state.selectedNetwork ? state.selectedNetwork.bssid : null;

    // Determine target based on action type
    const wifiActions = ['deauth', 'evil_twin', 'handshake', 'pmkid', 'pixie', 'auth', 'wifite', 'karma', 'eaphammer'];
    let target = wifiActions.includes(action) ? wifiTarget : ipTarget;

    // Special handling for Crack: doesn't strictly need a live target if file exists
    if (action === 'crack') target = 'LATEST_CAPTURE';

    // Special handling for ARP
    if (action === 'recon' && data.mode === 'arp') {
        if (state.selectedNetwork && state.selectedNetwork.interface) {
            target = state.selectedNetwork.interface;
        } else {
            return alert("Select an active Interface first!");
        }
    }

    // Fallback to subnet CIDR for network-wide actions (nmap discovery)
    if (!target && action === 'recon' && state.selectedNetwork) {
        if (['quick', 'full', 'stealth', 'vuln', 'comprehensive', 'discover'].includes(data.mode)) {
            target = state.selectedNetwork.cidr;
        }
    }

    if (action === 'recon' && !target) {
        if (['web', 'smb', 'dns'].includes(data.mode)) {
            return alert("Host-specific recon requires a specific Device Target (IP)!");
        }
        return alert("Select a Device or Subnet Target!");
    }

    if (wifiActions.includes(action) && !target && !['pmkid', 'wifite', 'beacon', 'auth', 'karma', 'eaphammer'].includes(action)) {
        return alert("Select a WiFi Network Target!");
    }

    // bettercap / sslstrip / pcredz: pass optional target, don't require one
    if (['bettercap', 'sslstrip', 'pcredz'].includes(action)) {
        data.target = ipTarget || undefined;
        target = 'MITM';
    }

    // eaphammer: pass ssid from selected wifi network
    if (action === 'eaphammer' && state.selectedNetwork) {
        data.ssid = state.selectedNetwork.essid || 'Corporate-WiFi';
        target = data.ssid;
    }

    log(`INITIATING ${action.toUpperCase()}...`);
    const res = await api(`/api/action/${action}`, 'POST', { target, ...data });

    if (res.status === 'success') {
        log(`✓ ${action.toUpperCase()} started`, 'success');
    } else {
        log(`ERROR: ${res.error || res.message}`, 'error');
    }
}

async function stopAttacks() {
    log('STOPPING ALL ATTACKS...');
    const res = await api('/api/action/stop', 'POST');
    if (res.status === 'success') {
        log('🛑 ALL ATTACKS STOPPED', 'error'); // Red color for visibility
    } else {
        alert("Failed to stop: " + res.error);
    }
}

async function switchToTFT() {
    log('SWITCHING TO TFT OUTPUT...');
    const res = await api('/api/action/tft', 'POST');
    if (res.status === 'success') {
        log('✓ Switching to TFT mode. System will reboot...', 'success');
    } else {
        log(`ERROR: ${res.error}`, 'error');
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
    entry.innerHTML = `<span class="time">[${time}]</span> <span class="msg">${escHtml(msg)}</span>`;

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
            entry.innerHTML = `<span class="time">[${l.time}]</span> <span class="msg">${escHtml(l.msg)}</span>`;
            container.appendChild(entry);
        });
        container.scrollTop = container.scrollHeight;

        // If logs changed, there might be new devices or report status updates
        loadDeviceList();
        loadReports();
    }
}

async function loadReports() {
    const res = await api('/api/reports');
    const container = document.getElementById('reports-body');
    if (!container) return;

    container.innerHTML = '';
    res.reports.forEach(r => {
        const tr = document.createElement('tr');
        const logBtn = r.log_file ? `<button class="btn" style="padding:2px 8px; font-size:0.6rem" onclick="viewFullLog('${r.log_file}', '${r.type} @ ${r.target}')">VIEW OUTPUT</button>` : '<span style="color:var(--text-dim)">N/A</span>';
        const aiBtn = r.log_file
            ? `<button class="btn" style="padding:2px 8px; font-size:0.6rem; border-color:var(--secondary); color:var(--secondary)" onclick="openAiModal('${r.id}', '${r.log_file}', '${r.type} @ ${r.target}')">AI</button>`
            : '<span style="color:var(--text-dim)">—</span>';

        tr.innerHTML = `
            <td style="padding:10px">${r.timestamp.split('T')[1].split('.')[0]}</td>
            <td style="color:var(--primary)">${r.type}</td>
            <td>${r.target}</td>
            <td class="${r.status.toLowerCase()}">${r.status}</td>
            <td>${logBtn}</td>
            <td>${aiBtn}</td>
        `;
        container.appendChild(tr);
    });
}

async function viewFullLog(filename, title) {
    const overlay = document.getElementById('log-viewer-overlay');
    const content = document.getElementById('log-viewer-content');
    const titleEl = document.getElementById('log-viewer-title');
    const downloadBtn = document.getElementById('log-download-btn');

    titleEl.textContent = `MISSION LOG: ${title}`;
    content.textContent = 'Loading last 2000 lines...';

    // Setup download button
    if (downloadBtn) {
        downloadBtn.onclick = () => {
            window.location.href = `/api/logs/download/${filename}`;
        };
    }

    overlay.classList.add('active');

    const res = await api(`/api/logs/view/${filename}`);
    if (res.content) {
        content.textContent = res.content;
        // Scroll to bottom
        setTimeout(() => content.scrollTop = content.scrollHeight, 100);
    } else {
        content.textContent = `Error: ${res.error || 'Failed to load log content.'}`;
    }
}

function closeLogViewer() {
    document.getElementById('log-viewer-overlay').classList.remove('active');
}

// --- AI Settings ---
async function loadSettings() {
    const res = await api('/api/settings');
    if (res.error) return;

    const providerEl = document.getElementById('ai-provider');
    const statusEl = document.getElementById('ai-key-status');
    if (providerEl) providerEl.value = res.provider || 'gemini';
    if (statusEl) {
        if (res.has_key) {
            statusEl.textContent = `Key saved: ${res.api_key_masked}`;
            statusEl.style.color = 'var(--accent)';
        } else {
            statusEl.textContent = 'Not configured';
            statusEl.style.color = 'var(--text-dim)';
        }
    }
}

async function saveSettings() {
    const provider = document.getElementById('ai-provider').value;
    const apiKey = document.getElementById('ai-api-key').value.trim();
    const statusEl = document.getElementById('ai-key-status');

    if (!apiKey) {
        statusEl.textContent = 'Enter an API key to save.';
        statusEl.style.color = '#ff4444';
        return;
    }

    const res = await api('/api/settings', 'POST', { provider, api_key: apiKey });
    if (res.status === 'success') {
        document.getElementById('ai-api-key').value = '';
        statusEl.textContent = 'Key saved ✓';
        statusEl.style.color = 'var(--accent)';
        log('AI settings saved', 'success');
        await loadSettings();
    } else {
        statusEl.textContent = `Error: ${res.error}`;
        statusEl.style.color = '#ff4444';
    }
}

// --- AI Analysis Modal ---
const aiModalState = { reportId: null, logFilename: null, reportType: '' };

function openAiModal(reportId, logFilename, reportType) {
    aiModalState.reportId = reportId;
    aiModalState.logFilename = logFilename;
    aiModalState.reportType = reportType;

    document.getElementById('ai-modal-subtitle').textContent = reportType;
    document.getElementById('ai-output').innerHTML = '<span style="color:var(--text-dim)">Select sections and click GENERATE REPORT...</span>';
    document.getElementById('ai-status-msg').textContent = '';
    document.getElementById('ai-modal-overlay').classList.add('active');
}

function closeAiModal() {
    document.getElementById('ai-modal-overlay').classList.remove('active');
}

async function analyzeWithAI() {
    const checked = [...document.querySelectorAll('#ai-modal-overlay input[type="checkbox"]:checked')]
        .map(cb => cb.value);

    if (checked.length === 0) {
        document.getElementById('ai-status-msg').textContent = 'Select at least one section.';
        return;
    }

    const outputEl = document.getElementById('ai-output');
    const statusEl = document.getElementById('ai-status-msg');

    outputEl.textContent = 'Contacting LLM... please wait.';
    statusEl.textContent = 'Analyzing...';
    statusEl.style.color = 'var(--primary)';

    const res = await api('/api/ai/analyze', 'POST', {
        report_id: aiModalState.reportId,
        log_filename: aiModalState.logFilename,
        report_type: aiModalState.reportType,
        checklist: checked
    });

    if (res.analysis) {
        outputEl.textContent = res.analysis;
        statusEl.textContent = '✓ Report generated';
        statusEl.style.color = 'var(--accent)';
    } else {
        outputEl.textContent = `Error: ${res.error || 'Unknown error from server.'}`;
        statusEl.textContent = 'Failed';
        statusEl.style.color = '#ff4444';
    }
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

// --- DNS Spoof Modal ---
function openDnsSpoofModal() {
    document.getElementById('dnsspoof-domain').value = '';
    document.getElementById('dnsspoof-redirect').value = '';
    document.getElementById('dnsspoof-modal').classList.add('active');
}

function closeDnsSpoofModal(e) {
    if (e && e.target !== document.getElementById('dnsspoof-modal')) return;
    document.getElementById('dnsspoof-modal').classList.remove('active');
}

async function runDnsSpoof() {
    const domain = document.getElementById('dnsspoof-domain').value.trim();
    const redirectIp = document.getElementById('dnsspoof-redirect').value.trim();

    if (!domain || !redirectIp) {
        alert('Both domain and redirect IP are required.');
        return;
    }

    document.getElementById('dnsspoof-modal').classList.remove('active');
    log(`INITIATING DNS SPOOF: ${escHtml(domain)} → ${escHtml(redirectIp)}...`);

    const res = await api('/api/action/dnsspoof', 'POST', { domain, redirect_ip: redirectIp });
    if (res.status === 'success') {
        log(`✓ DNS SPOOF started: ${escHtml(domain)} → ${escHtml(redirectIp)}`, 'success');
    } else {
        log(`ERROR: ${escHtml(res.error || res.message)}`, 'error');
    }
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
