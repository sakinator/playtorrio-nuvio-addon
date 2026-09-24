import 'config.dart';
import 'scraper_engine.dart';

class WebUI {
  static String render({
    required String localIp,
    required int port,
    String? updateMessage,
  }) {
    final providers = ScraperEngine.instance.getProviderList();
    final enabledCount = providers.where((p) => p['enabled'] == true).length;
    final manifestLocal = 'http://localhost:$port/manifest.json';
    final manifestLan = 'http://$localIp:$port/manifest.json';
    final torboxApiKey = AddonConfig.instance.torboxApiKey;

    final providerCheckboxes = providers.map((p) {
      final id = p['id'];
      final name = p['name'];
      final checked = p['enabled'] == true ? 'checked' : '';
      return '''
        <label class="provider-card">
          <input type="checkbox" name="provider" value="$id" $checked onchange="toggleProvider('$id', this.checked)">
          <div class="card-inner">
            <span class="provider-name">$name</span>
            <span class="badge">$id</span>
          </div>
        </label>
      ''';
    }).join('\n');

    return '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>sakinator-MegaScraper Addon</title>
  <style>
    :root {
      --bg: #0d1117;
      --card-bg: #161b22;
      --border: #30363d;
      --accent: #7928ca;
      --accent-grad: linear-gradient(135deg, #7928ca 0%, #ff0080 100%);
      --text: #f0f6fc;
      --text-muted: #8b949e;
      --green: #238636;
      --blue: #58a6ff;
      --orange: #d29922;
      --red: #f85149;
    }
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      background: var(--bg);
      color: var(--text);
      line-height: 1.5;
      padding: 24px;
    }
    .container { max-width: 1080px; margin: 0 auto; }
    header {
      text-align: center;
      padding: 32px 0 24px;
    }
    h1 {
      font-size: 2.2rem;
      background: var(--accent-grad);
      -webkit-background-clip: text;
      -webkit-text-fill-color: transparent;
      margin-bottom: 8px;
    }
    p.subtitle { color: var(--text-muted); font-size: 1.05rem; }
    .card {
      background: var(--card-bg);
      border: 1px solid var(--border);
      border-radius: 12px;
      padding: 24px;
      margin-bottom: 24px;
      box-shadow: 0 4px 16px rgba(0,0,0,0.3);
    }
    .card h2 {
      font-size: 1.3rem;
      margin-bottom: 16px;
      display: flex;
      align-items: center;
      gap: 8px;
    }
    .url-box {
      display: flex;
      gap: 12px;
      align-items: center;
      margin-bottom: 12px;
    }
    .url-input {
      flex: 1;
      padding: 10px 14px;
      background: #090d13;
      border: 1px solid var(--border);
      border-radius: 6px;
      color: var(--blue);
      font-family: monospace;
      font-size: 0.95rem;
    }
    .btn {
      padding: 8px 14px;
      background: var(--card-bg);
      color: var(--text);
      border: 1px solid var(--border);
      border-radius: 6px;
      cursor: pointer;
      font-size: 0.88rem;
      font-weight: 500;
      transition: all 0.15s ease;
      text-decoration: none;
      display: inline-flex;
      align-items: center;
      gap: 6px;
      white-space: nowrap;
    }
    .btn:hover { background: #21262d; border-color: #8b949e; }
    .btn-primary {
      background: var(--accent);
      border-color: var(--accent);
      color: #fff;
    }
    .btn-primary:hover { background: #9139e8; border-color: #9139e8; }
    .btn-success { background: var(--green); border-color: var(--green); color:#fff; }
    .btn-success:hover { background: #2ea043; }
    .instructions {
      background: rgba(88, 166, 255, 0.08);
      border: 1px solid rgba(88, 166, 255, 0.2);
      border-radius: 8px;
      padding: 14px;
      margin-top: 14px;
      font-size: 0.9rem;
    }
    .instructions ol { margin-left: 20px; }
    .instructions li { margin-bottom: 4px; }
    .grid {
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(180px, 1fr));
      gap: 12px;
      max-height: 400px;
      overflow-y: auto;
      padding: 4px;
    }
    .provider-card {
      position: relative;
      cursor: pointer;
    }
    .provider-card input {
      position: absolute;
      opacity: 0;
    }
    .card-inner {
      background: #0d1117;
      border: 1px solid var(--border);
      border-radius: 8px;
      padding: 12px;
      display: flex;
      flex-direction: column;
      gap: 4px;
      transition: all 0.15s ease;
    }
    .provider-card input:checked + .card-inner {
      border-color: #7928ca;
      background: rgba(121, 40, 202, 0.12);
    }
    .provider-name { font-weight: 600; font-size: 0.95rem; }
    .badge {
      font-size: 0.75rem;
      color: var(--text-muted);
      font-family: monospace;
    }
    .test-box {
      display: flex;
      gap: 12px;
      margin-bottom: 16px;
    }
    .test-input {
      flex: 1;
      padding: 10px 14px;
      background: #090d13;
      border: 1px solid var(--border);
      border-radius: 6px;
      color: var(--text);
    }
    select {
      padding: 10px 14px;
      background: #090d13;
      border: 1px solid var(--border);
      border-radius: 6px;
      color: var(--text);
    }
    #testResults {
      background: #090d13;
      border: 1px solid var(--border);
      border-radius: 8px;
      padding: 14px;
      max-height: 480px;
      overflow-y: auto;
      font-size: 0.88rem;
      display: none;
    }
    .stream-item {
      padding: 12px 10px;
      border-bottom: 1px solid var(--border);
      display: flex;
      justify-content: space-between;
      align-items: center;
      gap: 14px;
    }
    .stream-item:last-child { border-bottom: none; }
    .stream-info { flex: 1; min-width: 0; }
    .stream-title { font-weight: 600; color: var(--blue); font-size: 0.95rem; word-break: break-word; }
    .stream-sub { font-size: 0.82rem; color: var(--text-muted); margin-top: 4px; word-break: break-word; white-space: pre-wrap; }
    .stream-actions { display: flex; gap: 8px; flex-shrink: 0; flex-wrap: wrap; }
    .hoster-card {
      background: #0d1117;
      border: 1px solid var(--border);
      border-radius: 6px;
      padding: 10px;
      font-size: 0.85rem;
      display: flex;
      flex-direction: column;
      gap: 4px;
    }
    .hoster-name { font-weight: 600; color: #fff; }
    .hoster-domains { color: var(--text-muted); font-size: 0.75rem; word-break: break-all; }
    .hoster-status { display: inline-block; font-size: 0.72rem; padding: 2px 6px; border-radius: 4px; width: fit-content; }
    .status-up { background: rgba(35, 134, 54, 0.2); color: #3fb950; }
    .status-down { background: rgba(248, 81, 73, 0.2); color: #f85149; }
    .update-box {
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 14px;
      background: #0d1117;
      border: 1px solid var(--border);
      border-radius: 8px;
    }
    .toast {
      position: fixed;
      bottom: 24px;
      right: 24px;
      background: var(--green);
      color: #fff;
      padding: 12px 20px;
      border-radius: 8px;
      box-shadow: 0 4px 16px rgba(0,0,0,0.5);
      display: none;
      z-index: 10000;
      font-weight: 600;
    }
  </style>
</head>
<body>
  <div class="container">
    <header>
      <h1>⚡ sakinator-MegaScraper</h1>
      <p class="subtitle">56 Non-Torrent Cloud Scrapers + Badges + TorBox Debrid for Nuvio & Stremio</p>
    </header>

    <!-- Installation Box -->
    <div class="card">
      <h2>🔌 Nuvio Addon Manifest URLs</h2>
      <div class="url-box">
        <label style="min-width: 110px; font-weight:600;">LAN (Nuvio TV):</label>
        <input class="url-input" id="lanUrl" value="$manifestLan" readonly>
        <button class="btn btn-primary" onclick="copyText('lanUrl')">📋 Copy LAN URL</button>
      </div>
      <div class="url-box">
        <label style="min-width: 110px; font-weight:600;">PC (Localhost):</label>
        <input class="url-input" id="localUrl" value="$manifestLocal" readonly>
        <button class="btn" onclick="copyText('localUrl')">📋 Copy Local URL</button>
      </div>
      <div class="url-box">
        <label style="min-width: 110px; font-weight:600;">🏷️ Badges JSON:</label>
        <input class="url-input" id="badgesUrl" value="http://$localIp:$port/badges.json" readonly>
        <button class="btn" onclick="copyText('badgesUrl')">📋 Copy Badges URL</button>
      </div>
      
      <div class="instructions">
        <strong>💡 How to install in Nuvio:</strong>
        <ol>
          <li>Open <strong>Nuvio</strong> on your PC, Android TV, or Mobile device.</li>
          <li>Navigate to <strong>Settings</strong> ➔ <strong>Add-ons</strong> ➔ <strong>Install from URL</strong> (or click the <strong>+</strong> button).</li>
          <li>Paste the <strong>LAN URL</strong> (if running Nuvio on Android TV/Phone) or <strong>Localhost URL</strong> (if running on this PC).</li>
          <li>Click <strong>Install</strong>. Streams will now directly populate movie & TV pages!</li>
        </ol>
      </div>
    </div>

    <!-- TorBox Debrid & Cache Integration -->
    <div class="card">
      <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom: 14px; flex-wrap:wrap; gap:8px;">
        <h2>⚡ TorBox Debrid & Cloud Cache</h2>
        <span id="torboxStatusBadge" class="badge" style="background:#21262d; padding:4px 8px; border-radius:4px; font-size:0.85rem;">Not Configured</span>
      </div>
      <p style="color:var(--text-muted); margin-bottom:14px; font-size:0.9rem;">
        Integrate your TorBox API key to stream cached cloud links (HubCloud, HubDrive, DriveSeed, Pixeldrain, Mega, 1fichier, Rapidgator, Google Drive) directly through TorBox CDN at unlimited speed with zero buffering.
      </p>
      
      <div class="url-box">
        <label style="min-width: 130px; font-weight:600;">TorBox API Key:</label>
        <input class="url-input" type="password" id="torboxApiKey" value="$torboxApiKey" placeholder="Enter your TorBox API Key">
        <button class="btn btn-primary" id="btnSaveTorbox" onclick="saveTorboxKey()">💾 Save & Validate</button>
      </div>
      <div id="torboxAccountInfo" style="font-size:0.88rem; color:var(--text-muted); margin-bottom:14px; display:none;"></div>

      <div style="border-top:1px solid var(--border); padding-top:14px; margin-top:14px;">
        <h3 style="font-size:1rem; margin-bottom:8px;">🚀 Upload & Cache Link to TorBox</h3>
        <p style="color:var(--text-muted); font-size:0.82rem; margin-bottom:10px;">
          Paste any non-cached stream or cloud link below to queue a WebDL job to TorBox:
        </p>
        <div class="url-box">
          <input class="url-input" id="torboxUploadUrl" placeholder="https://hubcloud.cx/drive/... or any supported hoster URL">
          <button class="btn btn-success" id="btnUploadTorbox" onclick="uploadLinkToTorbox()">⚡ Cache to TorBox</button>
        </div>
        <div id="torboxUploadStatus" style="font-size:0.85rem; margin-top:6px; display:none;"></div>
      </div>

      <div style="border-top:1px solid var(--border); padding-top:14px; margin-top:14px;">
        <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:12px; flex-wrap:wrap; gap:8px;">
          <h3 style="font-size:1rem;">🌐 TorBox Live Supported Hosters (<a href="https://torbox.app/hosters" target="_blank" style="color:var(--blue); text-decoration:none;">torbox.app/hosters</a>)</h3>
          <div style="display:flex; gap:8px;">
            <input type="text" id="hosterSearch" placeholder="Filter hosters (e.g. hubcloud)..." oninput="filterHosters()" style="padding:6px 10px; background:#090d13; border:1px solid var(--border); border-radius:4px; color:var(--text); font-size:0.85rem;">
            <button class="btn" onclick="loadTorboxHosters()">🔄 Refresh Hosters</button>
          </div>
        </div>
        <div id="hostersGrid" class="grid" style="max-height:240px;">
          <div style="color:var(--text-muted); padding:8px;">Click "Refresh Hosters" to view active debrid hosters.</div>
        </div>
      </div>
    </div>

    <!-- Scraper Providers -->
    <div class="card">
      <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom: 16px;">
        <h2>📦 HTTP Scraper Providers (<span id="enabledCount">$enabledCount</span>/${providers.length} Active)</h2>
        <div style="display:flex; gap:8px;">
          <button class="btn" onclick="bulkToggle(true)">Enable All</button>
          <button class="btn" onclick="bulkToggle(false)">Disable All</button>
        </div>
      </div>
      <div class="grid">
        $providerCheckboxes
      </div>
    </div>

    <!-- Live Stream Tester -->
    <div class="card">
      <h2>🔍 Live Stream Tester</h2>
      <div class="test-box">
        <select id="testType">
          <option value="movie">Movie</option>
          <option value="series">Series</option>
        </select>
        <input class="test-input" id="testId" placeholder="IMDb ID or Title (e.g. tt1375666 or Inception)" value="tt1375666">
        <button class="btn btn-primary" id="btnTest" onclick="runTest()">🚀 Test Scrape</button>
      </div>
      <div id="testResults"></div>
    </div>

    <!-- Upstream Pipeline -->
    <div class="card">
      <h2>🔄 Upstream Pipeline</h2>
      <p style="color:var(--text-muted); margin-bottom:14px;">Automatically pulls upstream updates from <code>ayman708-UX/PlayTorrioV3</code>, regenerates the scraper registry, and hot-reloads all providers.</p>
      <div class="update-box">
        <div>
          <strong>Upstream Source:</strong> <a href="https://github.com/ayman708-UX/PlayTorrioV3" target="_blank" style="color:var(--blue); text-decoration:none;">github.com/ayman708-UX/PlayTorrioV3</a>
          <div style="font-size:0.85rem; color:var(--text-muted); margin-top:4px;">Pipeline Script: <code>pipeline/update.ps1</code></div>
        </div>
        <button class="btn btn-success" id="btnUpdate" onclick="triggerUpdate()">⚡ Check & Pull Updates</button>
      </div>
      <div id="updateStatus" style="margin-top:12px; font-family:monospace; font-size:0.85rem; display:none;"></div>
    </div>
  </div>

  <div id="toast" class="toast">Copied to clipboard!</div>

  <script>
    let currentStreams = [];
    let allHosters = [];

    function showToast(msg) {
      const t = document.getElementById('toast');
      t.innerText = msg;
      t.style.display = 'block';
      setTimeout(() => { t.style.display = 'none'; }, 2500);
    }

    function copyText(id) {
      const el = document.getElementById(id);
      navigator.clipboard.writeText(el.value);
      showToast('Copied to clipboard!');
    }

    async function toggleProvider(id, enabled) {
      await fetch('/api/provider/' + id, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ enabled: enabled })
      });
      updateCounter();
    }

    async function bulkToggle(enabled) {
      const checkboxes = document.querySelectorAll('input[name="provider"]');
      for (const cb of checkboxes) {
        cb.checked = enabled;
        await fetch('/api/provider/' + cb.value, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ enabled: enabled })
        });
      }
      updateCounter();
    }

    function updateCounter() {
      const checked = document.querySelectorAll('input[name="provider"]:checked').length;
      document.getElementById('enabledCount').innerText = checked;
    }

    function normalizeStreamUrl(rawUrl) {
      if (!rawUrl) return '';
      if (rawUrl.includes('/proxy?')) {
        try {
          const u = new URL(rawUrl);
          return window.location.origin + u.pathname + u.search;
        } catch (_) {}
      }
      return rawUrl;
    }

    // ── TorBox API Functions ──
    async function saveTorboxKey() {
      const key = document.getElementById('torboxApiKey').value.trim();
      const btn = document.getElementById('btnSaveTorbox');
      const badge = document.getElementById('torboxStatusBadge');
      const info = document.getElementById('torboxAccountInfo');

      btn.disabled = true;
      btn.innerText = 'Validating...';

      try {
        const res = await fetch('/api/torbox/config', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ apiKey: key })
        });
        const data = await res.json();
        if (data.success && data.account) {
          const acc = data.account;
          badge.style.background = 'rgba(35, 134, 54, 0.2)';
          badge.style.color = '#3fb950';
          badge.innerText = 'Active (Plan: ' + (acc.plan || 'Standard') + ')';
          info.style.display = 'block';
          info.innerHTML = '👤 <strong>Account:</strong> ' + (acc.email || 'TorBox User') + ' | <strong>Plan:</strong> ' + (acc.plan || 'Free') + ' | <strong>Expires:</strong> ' + (acc.expires_at || 'N/A');
          showToast('✅ TorBox API key saved & verified!');
          loadTorboxHosters();
        } else {
          badge.style.background = key ? 'rgba(248, 81, 73, 0.2)' : '#21262d';
          badge.style.color = key ? '#f85149' : 'var(--text-muted)';
          badge.innerText = key ? 'Invalid Key' : 'Not Configured';
          info.style.display = 'none';
          showToast(key ? '❌ Invalid TorBox API Key' : 'TorBox API key cleared');
        }
      } catch (e) {
        showToast('Error validating key: ' + e);
      } finally {
        btn.disabled = false;
        btn.innerText = '💾 Save & Validate';
      }
    }

    async function loadTorboxHosters() {
      const grid = document.getElementById('hostersGrid');
      grid.innerHTML = '<div style="color:var(--text-muted); padding:8px;">Fetching hosters from TorBox...</div>';
      try {
        const res = await fetch('/api/torbox/hosters');
        const data = await res.json();
        allHosters = data.hosters || [];
        renderHosters(allHosters);
      } catch (e) {
        grid.innerHTML = '<div style="color:var(--red); padding:8px;">Failed to load hosters: ' + e + '</div>';
      }
    }

    function renderHosters(hosters) {
      const grid = document.getElementById('hostersGrid');
      if (!hosters || hosters.length === 0) {
        grid.innerHTML = '<div style="color:var(--text-muted); padding:8px;">No hosters found.</div>';
        return;
      }
      let html = '';
      for (const h of hosters) {
        const name = escapeHtml(h.name || h.id || 'Hoster');
        const domains = Array.isArray(h.domains) ? h.domains.join(', ') : '';
        const status = h.status === 'down' ? 'down' : 'up';
        const statusText = status === 'up' ? 'Operational' : 'Down';
        const statusClass = status === 'up' ? 'status-up' : 'status-down';
        html += '<div class="hoster-card">';
        html += '  <div class="hoster-name">' + name + '</div>';
        html += '  <div class="hoster-domains">' + escapeHtml(domains) + '</div>';
        html += '  <span class="hoster-status ' + statusClass + '">' + statusText + '</span>';
        html += '</div>';
      }
      grid.innerHTML = html;
    }

    function filterHosters() {
      const query = document.getElementById('hosterSearch').value.trim().toLowerCase();
      if (!query) {
        renderHosters(allHosters);
        return;
      }
      const filtered = allHosters.filter(h => {
        const name = (h.name || '').toLowerCase();
        const domains = (Array.isArray(h.domains) ? h.domains.join(' ') : '').toLowerCase();
        return name.includes(query) || domains.includes(query);
      });
      renderHosters(filtered);
    }

    async function uploadLinkToTorbox(targetUrl) {
      const url = targetUrl || document.getElementById('torboxUploadUrl').value.trim();
      const statusDiv = document.getElementById('torboxUploadStatus');
      const btn = document.getElementById('btnUploadTorbox');

      if (!url) {
        showToast('Please provide a URL to cache');
        return;
      }

      if (btn) btn.disabled = true;
      statusDiv.style.display = 'block';
      statusDiv.innerHTML = '<span style="color:var(--blue);">Submitting to TorBox WebDL...</span>';

      try {
        const res = await fetch('/api/torbox/upload', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ url: url })
        });
        const data = await res.json();
        if (data.success) {
          statusDiv.innerHTML = '<span style="color:var(--green);">✅ Cached / Queued successfully to TorBox! ID: ' + (data.data?.id || 'Active') + '</span>';
          showToast('✅ Queued to TorBox!');
          if (!targetUrl) document.getElementById('torboxUploadUrl').value = '';
        } else {
          statusDiv.innerHTML = '<span style="color:var(--red);">❌ ' + (data.detail || data.error || 'TorBox upload failed') + '</span>';
        }
      } catch (e) {
        statusDiv.innerHTML = '<span style="color:var(--red);">Error: ' + e + '</span>';
      } finally {
        if (btn) btn.disabled = false;
      }
    }

    async function runTest() {
      const type = document.getElementById('testType').value;
      const id = document.getElementById('testId').value.trim();
      const resultsDiv = document.getElementById('testResults');
      const btn = document.getElementById('btnTest');

      if (!id) return;

      btn.disabled = true;
      btn.innerText = 'Scraping...';
      resultsDiv.style.display = 'block';
      resultsDiv.innerHTML = '<div style="color:var(--text-muted); padding:10px;">Scraping 56 providers for "' + id + '"...</div>';

      try {
        const res = await fetch('/stream/' + type + '/' + encodeURIComponent(id) + '.json');
        const data = await res.json();
        const rawStreams = data.streams || [];

        currentStreams = rawStreams.map((s, idx) => {
          const finalUrl = normalizeStreamUrl(s.url);
          const rawName = (s.name || '').replace(/\\n/g, ' ');
          const rawTitle = (s.title || '').replace(/\\n/g, '\\n');
          return {
            index: idx,
            name: rawName,
            title: rawTitle,
            url: finalUrl,
          };
        });

        if (currentStreams.length === 0) {
          resultsDiv.innerHTML = '<div style="color:#f85149; padding:10px;">No streams found. Try another title or check your enabled providers.</div>';
        } else {
          let html = '<div style="font-weight:600; margin-bottom:12px; color:var(--green); font-size:1rem;">Found ' + currentStreams.length + ' stream(s):</div>';
          for (let i = 0; i < currentStreams.length; i++) {
            const s = currentStreams[i];
            const isTorbox = s.url.includes('/torbox/play') || s.title.includes('Torbox') || s.title.includes('Cached');
            html += '<div class="stream-item">';
            html += '  <div class="stream-info">';
            html += '    <div class="stream-title">' + escapeHtml(s.name) + '</div>';
            html += '    <div class="stream-sub">' + escapeHtml(s.title) + '</div>';
            html += '  </div>';
            html += '  <div class="stream-actions">';
            html += '    <button class="btn btn-primary" onclick="copyStreamUrl(' + i + ')">📋 Copy Stream URL</button>';
            html += '    <a class="btn" href="' + s.url + '" target="_blank" rel="noreferrer">🔗 Open URL</a>';
            if (!isTorbox) {
              html += '    <button class="btn btn-success" onclick="uploadLinkToTorbox(\\'' + escapeHtml(s.url) + '\\')">⚡ Cache to TorBox</button>';
            }
            html += '  </div>';
            html += '</div>';
          }
          resultsDiv.innerHTML = html;
        }
      } catch (err) {
        resultsDiv.innerHTML = '<div style="color:#f85149; padding:10px;">Error testing scrape: ' + err + '</div>';
      } finally {
        btn.disabled = false;
        btn.innerText = '🚀 Test Scrape';
      }
    }

    function escapeHtml(str) {
      return (str || '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
    }

    function copyStreamUrl(idx) {
      const s = currentStreams[idx];
      if (s && s.url) {
        navigator.clipboard.writeText(s.url);
        showToast('✅ Stream URL copied to clipboard!');
      }
    }

    async function triggerUpdate() {
      const btn = document.getElementById('btnUpdate');
      const statusDiv = document.getElementById('updateStatus');
      btn.disabled = true;
      btn.innerText = 'Updating...';
      statusDiv.style.display = 'block';
      statusDiv.innerHTML = '<span style="color:var(--blue);">Contacting update pipeline...</span>';

      try {
        const res = await fetch('/api/pipeline/update', { method: 'POST' });
        const data = await res.json();
        statusDiv.innerHTML = '<span style="color:' + (data.success ? 'var(--green)' : '#f85149') + '">' + (data.message || data.output) + '</span>';
        if (data.success) {
          setTimeout(() => location.reload(), 2000);
        }
      } catch (e) {
        statusDiv.innerHTML = '<span style="color:#f85149;">Pipeline execution error: ' + e + '</span>';
      } finally {
        btn.disabled = false;
        btn.innerText = '⚡ Check & Pull Updates';
      }
    }

    // Auto-check TorBox key status on load if key is present
    window.addEventListener('DOMContentLoaded', () => {
      const key = document.getElementById('torboxApiKey').value.trim();
      if (key) {
        saveTorboxKey();
      }
    });
  </script>
</body>
</html>
    ''';
  }
}
