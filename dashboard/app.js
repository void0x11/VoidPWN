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
    const wifiActions = ['deauth', 'evil_twin', 'handshake', 'pmkid', 'pixie', 'auth', 'wifite', 'eaphammer'];
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

    if (wifiActions.includes(action) && !target && !['pmkid', 'wifite', 'beacon', 'auth', 'eaphammer'].includes(action)) {
        return alert("Select a WiFi Network Target!");
    }

    // bettercap / pcredz: pass optional target, don't require one
    if (['bettercap', 'pcredz'].includes(action)) {
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

// ============================================================
// HexStrike AI Integration
// ============================================================
const hs = {
    chain: [],         // current attack chain steps
    missionId: null,   // uuid for this mission
    logFile: null,     // server-side log filename
    executing: false,
    pollInterval: null,
    currentStep: 0
};

// Poll HexStrike status when tab becomes active
const _origSwitchTab = switchTab;
function switchTab(tabId) {
    _origSwitchTab(tabId);
    if (tabId === 'hexstrike') {
        hexstrikeStatus();
    } else {
        // Stop process polling when leaving HexStrike tab
        if (hs.pollInterval) {
            clearInterval(hs.pollInterval);
            hs.pollInterval = null;
        }
    }
}

async function hexstrikeStatus() {
    const badge = document.getElementById('hs-badge');
    if (!badge) return;
    badge.className = 'hexstrike-badge offline';
    badge.textContent = '● CHECKING...';
    const res = await api('/api/hexstrike/status');
    if (res.online) {
        badge.className = 'hexstrike-badge online';
        badge.textContent = `● ONLINE  (${res.tool_count || '?'} tools)`;
    } else {
        badge.className = 'hexstrike-badge offline';
        badge.textContent = '● OFFLINE';
    }
}

async function hexstrikeStartServer() {
    log('⬡ Starting HexStrike AI Engine...', 'info');
    const res = await api('/api/hexstrike/start', 'POST');
    if (res.error) {
        log(`⬡ ERROR: ${res.error}`, 'error');
        return;
    }
    log(`⬡ Engine starting (PID ${res.pid || '?'})...`, 'info');
    // Give it a moment then check status
    setTimeout(hexstrikeStatus, 2000);
}

async function hexstrikeStopServer() {
    const res = await api('/api/hexstrike/stop', 'POST');
    log(`⬡ HexStrike Engine: ${res.status}`, 'info');
    await hexstrikeStatus();
}

async function hexstrikeAnalyze() {
    const target = document.getElementById('hs-target')?.value.trim();
    const objective = document.getElementById('hs-objective')?.value || 'comprehensive';
    const btn = document.getElementById('hs-analyze-btn');

    if (!target) {
        log('⬡ Enter a target before analyzing.', 'error');
        return;
    }

    btn.disabled = true;
    btn.textContent = 'ANALYZING...';
    log(`⬡ HexStrike analyzing: ${escHtml(target)} [${objective}]...`, 'info');

    const res = await api('/api/hexstrike/analyze', 'POST', { target, objective });

    btn.disabled = false;
    btn.textContent = '⬡ ANALYZE TARGET';

    if (res.error) {
        log(`⬡ ANALYZE ERROR: ${res.error}`, 'error');
        return;
    }

    // Show intelligence report
    _renderIntelReport(res.target_profile);

    // Store and render chain
    hs.chain = res.chain || [];
    hs.missionId = null;
    hs.currentStep = 0;
    _renderChain(hs.chain);

    const prob = res.success_probability ? ` | Chain probability: ${(res.success_probability * 100).toFixed(0)}%` : '';
    const eta = res.estimated_time ? ` | ETA: ~${res.estimated_time}s` : '';
    log(`⬡ DecisionEngine chain ready: ${hs.chain.length} step(s)${prob}${eta}. Review and click EXECUTE MISSION.`, 'success');
}

function _renderIntelReport(profile) {
    const panel = document.getElementById('hs-intel-panel');
    const content = document.getElementById('hs-intel-content');
    if (!panel || !content || !profile) return;

    const items = [
        { label: 'Target', value: profile.target || '—' },
        { label: 'Type', value: profile.type || 'unknown' },
        { label: 'Risk Level', value: profile.risk_level || 'unknown' },
        { label: 'Attack Surface', value: profile.attack_surface_score || 'N/A' },
        { label: 'Confidence', value: profile.confidence || 'N/A' },
        { label: 'Technologies', value: (profile.technologies || []).join(', ') || 'N/A' }
    ];

    content.innerHTML = items.map(i => `
        <div class="hexstrike-intel-item">
            <div class="hexstrike-intel-label">${escHtml(i.label)}</div>
            <div class="hexstrike-intel-value">${escHtml(String(i.value))}</div>
        </div>
    `).join('');

    panel.style.display = '';
}

const TOOL_CATEGORIES = {
    nmap: 'scan', rustscan: 'scan', masscan: 'scan',
    gobuster: 'fuzz', dirb: 'fuzz', ffuf: 'fuzz', nikto: 'fuzz',
    sqlmap: 'exploit', metasploit: 'exploit', hydra: 'password',
    john: 'password', hashcat: 'password', bettercap: 'exploit',
    responder: 'exploit', wifite: 'scan'
};

function _renderChain(chain) {
    const panel = document.getElementById('hs-chain-panel');
    const list = document.getElementById('hs-chain-list');
    if (!panel || !list) return;

    list.innerHTML = chain.map((step, i) => {
        const cat = TOOL_CATEGORIES[step.tool] || 'scan';
        const fallbackHtml = step.fallback
            ? `<span class="chain-step-fallback">fallback: ${escHtml(step.fallback)}</span>` : '';
        const timingHtml = step.estimated_time
            ? `<span class="chain-step-timing">~${escHtml(String(step.estimated_time))}s</span>` : '';
        const probHtml = step.success_probability
            ? `<span class="chain-step-timing" style="color:var(--accent)">p=${(step.success_probability * 100).toFixed(0)}%</span>` : '';
        // Summarise the DecisionEngine parameters as readable key=value pairs
        const params = step.parameters || {};
        const paramKeys = Object.keys(params).filter(k => k !== 'target' && k !== 'url' && params[k] != null);
        const paramHtml = paramKeys.length
            ? `<div class="chain-step-desc" style="font-size:0.65rem;opacity:0.7">${paramKeys.map(k => `${escHtml(k)}: ${escHtml(String(params[k]))}`).join(' &nbsp;|&nbsp; ')}</div>` : '';
        return `
            <div class="chain-step ${cat}" id="hs-step-${i}">
                <div class="chain-step-body">
                    <div class="chain-step-tool">${escHtml(step.tool)}</div>
                    <div class="chain-step-desc">${escHtml(step.description || '')}</div>
                    ${paramHtml}
                    <div class="chain-step-meta">${timingHtml}${probHtml}${fallbackHtml}</div>
                </div>
            </div>
        `;
    }).join('');

    panel.style.display = '';
}

async function hexstrikeExecuteChain() {
    if (!hs.chain.length) {
        log('⬡ No attack chain. Run ANALYZE TARGET first.', 'error');
        return;
    }
    if (hs.executing) {
        log('⬡ Mission already running.', 'info');
        return;
    }

    const target = document.getElementById('hs-target')?.value.trim();
    const objective = document.getElementById('hs-objective')?.value || 'comprehensive';
    if (!target) {
        log('⬡ Target missing.', 'error');
        return;
    }

    hs.executing = true;
    hs.missionId = crypto.randomUUID ? crypto.randomUUID() : Date.now().toString(36);
    hs.logFile = `hexstrike_mission_${new Date().toISOString().replace(/[:.]/g, '').slice(0, 15)}.txt`;
    hs.currentStep = 0;

    const btn = document.getElementById('hs-execute-btn');
    if (btn) { btn.disabled = true; btn.textContent = '⏳ EXECUTING...'; }

    const procPanel = document.getElementById('hs-processes-panel');
    if (procPanel) procPanel.style.display = '';

    // Start process polling
    hs.pollInterval = setInterval(_pollHexstrikeProcesses, 3000);

    const chainTools = hs.chain.map(s => s.tool);

    for (let i = 0; i < hs.chain.length; i++) {
        const step = hs.chain[i];
        hs.currentStep = i;

        // Mark current step as running in UI
        document.querySelectorAll('.chain-step').forEach(el => el.classList.remove('running'));
        const stepEl = document.getElementById(`hs-step-${i}`);
        if (stepEl) stepEl.classList.add('running');

        const counter = document.getElementById('hs-step-counter');
        if (counter) counter.textContent = `Step ${i + 1} / ${hs.chain.length}`;

        log(`⬡ [${i + 1}/${hs.chain.length}] Running: ${step.tool}...`, 'info');

        const res = await api('/api/hexstrike/execute', 'POST', {
            target,
            tool: step.tool,
            objective,
            step_index: i,
            total_steps: hs.chain.length,
            mission_id: hs.missionId,
            log_file: hs.logFile,
            chain_tools: chainTools,
            step_params: step.parameters || {}   // DecisionEngine optimized params for this tool
        });

        if (stepEl) {
            stepEl.classList.remove('running');
            stepEl.classList.add('done');
        }

        if (res.error) {
            log(`⬡ Step ${i + 1} error: ${res.error}`, 'error');
        } else {
            log(`⬡ ${step.tool} complete`, 'success');
        }

        // On last step, AI analysis is ready
        if (i + 1 >= hs.chain.length && res.ai_analysis) {
            log('⬡ Gemini AI report generated — check REPORTS tab.', 'success');
            loadReports();
        }
    }

    // Mission complete
    hs.executing = false;
    if (hs.pollInterval) { clearInterval(hs.pollInterval); hs.pollInterval = null; }
    if (btn) { btn.disabled = false; btn.textContent = '▶ EXECUTE MISSION'; }
    if (counter) counter.textContent = `✓ Mission complete — ${hs.chain.length} step(s)`;
    log('⬡ HexStrike mission complete! View full report in REPORTS tab.', 'success');
    switchTab('reports');
}

async function _pollHexstrikeProcesses() {
    const container = document.getElementById('hs-processes-list');
    if (!container) return;

    const res = await api('/api/hexstrike/processes');
    const procs = res.processes || res.active_processes || [];

    if (!procs.length) {
        container.innerHTML = '<div style="font-size:0.75rem; color:var(--text-dim); padding:8px 0">No active processes.</div>';
        return;
    }

    container.innerHTML = procs.map(p => {
        const pct = Math.min(100, Math.max(0, p.progress || p.percent || 0));
        const elapsed = p.elapsed || p.elapsed_time || '';
        return `
            <div class="process-row">
                <span class="process-name">${escHtml(p.tool || p.name || 'unknown')}</span>
                <div class="process-bar-wrap">
                    <div class="process-bar-fill" style="width:${pct}%"></div>
                </div>
                <span class="process-elapsed">${escHtml(String(elapsed))}</span>
            </div>
        `;
    }).join('');
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
        const isHexstrike = r.type === 'HEXSTRIKE MISSION';

        // Type cell: add ⬡ badge for HexStrike missions
        const typeBadge = isHexstrike
            ? ` <span class="hs-chain-badge">\u2b21 AI</span>` : '';

        // Chain tools pill list
        const chainHtml = isHexstrike && r.hexstrike_chain && r.hexstrike_chain.length
            ? `<div style="margin-top:4px; display:flex; flex-wrap:wrap; gap:4px">${r.hexstrike_chain.map(t => `<span class="tag">${escHtml(t)}</span>`).join('')}</div>` : '';

        const logBtn = r.log_file
            ? `<button class="btn" style="padding:2px 8px; font-size:0.6rem" onclick="viewFullLog('${escHtml(r.log_file)}', '${escHtml(r.type)} @ ${escHtml(r.target)}')">VIEW OUTPUT</button>`
            : '<span style="color:var(--text-dim)">N/A</span>';

        // AI button: HexStrike reports show auto-inline analysis; others use the modal
        let aiCell;
        if (isHexstrike && r.ai_analysis) {
            aiCell = `<button class="btn" style="padding:2px 8px; font-size:0.6rem; border-color:var(--accent); color:var(--accent)"
                onclick="toggleHsAnalysis('hs-ai-${escHtml(r.id)}')">AI REPORT</button>`;
        } else if (!isHexstrike && r.log_file) {
            aiCell = `<button class="btn" style="padding:2px 8px; font-size:0.6rem; border-color:var(--secondary); color:var(--secondary)"
                onclick="openAiModal('${escHtml(r.id)}', '${escHtml(r.log_file)}', '${escHtml(r.type)} @ ${escHtml(r.target)}')">AI</button>`;
        } else {
            aiCell = '<span style="color:var(--text-dim)">—</span>';
        }

        // Build AI analysis expandable row
        const aiRow = isHexstrike && r.ai_analysis
            ? `<tr id="hs-ai-${escHtml(r.id)}" style="display:none">
                <td colspan="6" style="padding:0 10px 12px">
                    <div class="ai-analysis-block">${escHtml(r.ai_analysis)}</div>
                </td>
              </tr>` : '';

        const tr = document.createElement('template');
        tr.innerHTML = `
            <tr>
                <td style="padding:10px">${escHtml(r.timestamp.split('T')[1].split('.')[0])}</td>
                <td style="color:var(--primary)">${escHtml(r.type)}${typeBadge}${chainHtml}</td>
                <td>${escHtml(r.target)}</td>
                <td class="${r.status.toLowerCase()}">${escHtml(r.status)}</td>
                <td>${logBtn}</td>
                <td>${aiCell}</td>
            </tr>
            ${aiRow}
        `.trim();
        container.appendChild(tr.content);
    });
}

function toggleHsAnalysis(rowId) {
    const row = document.getElementById(rowId);
    if (!row) return;
    row.style.display = row.style.display === 'none' ? '' : 'none';
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
