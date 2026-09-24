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
  <title>PlayTorrio HTTP Addon for Nuvio</title>
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
      max-height: 420px;
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
    .stream-title { font-weight: 600; color: var(--blue); font-size: 0.95rem; }
    .stream-sub { font-size: 0.82rem; color: var(--text-muted); margin-top: 4px; word-break: break-word; }
    .stream-actions { display: flex; gap: 8px; flex-shrink: 0; }
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
      <h1>⚡ PlayTorrio HTTP Streams</h1>
      <p class="subtitle">Direct HTTP & HLS Scrapers for Nuvio Media Center</p>
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
      
      <div class="instructions">
        <strong>💡 How to install in Nuvio:</strong>
        <ol>
          <li>Open <strong>Nuvio</strong> on your PC, Android TV, or Mobile device.</li>
          <li>Navigate to <strong>Settings</strong> ➔ <strong>Add-ons</strong> ➔ <strong>Install from URL</strong> (or click the <strong>+</strong> button).</li>
          <li>Paste the <strong>LAN URL</strong> (if running Nuvio on Android TV/Phone) or <strong>Localhost URL</strong> (if running on this PC).</li>
          <li>Click <strong>Install</strong>. PlayTorrio HTTP streams will now populate movie & TV pages!</li>
        </ol>
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
      <h2>🔄 PlayTorrio Upstream Pipeline</h2>
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

    async function runTest() {
      const type = document.getElementById('testType').value;
      const id = document.getElementById('testId').value.trim();
      const resultsDiv = document.getElementById('testResults');
      const btn = document.getElementById('btnTest');

      if (!id) return;

      btn.disabled = true;
      btn.innerText = 'Scraping...';
      resultsDiv.style.display = 'block';
      resultsDiv.innerHTML = '<div style="color:var(--text-muted); padding:10px;">Scraping 46 providers for "' + id + '"...</div>';

      try {
        const res = await fetch('/stream/' + type + '/' + encodeURIComponent(id) + '.json');
        const data = await res.json();
        const rawStreams = data.streams || [];

        currentStreams = rawStreams.map((s, idx) => {
          const finalUrl = normalizeStreamUrl(s.url);
          const rawName = (s.name || '').replace(/\\n/g, ' ');
          const rawTitle = (s.title || '').replace(/\\n/g, ' | ');
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
            html += '<div class="stream-item">';
            html += '  <div class="stream-info">';
            html += '    <div class="stream-title">' + escapeHtml(s.name) + '</div>';
            html += '    <div class="stream-sub">' + escapeHtml(s.title) + '</div>';
            html += '  </div>';
            html += '  <div class="stream-actions">';
            html += '    <button class="btn btn-primary" onclick="copyStreamUrl(' + i + ')">📋 Copy Stream URL</button>';
            html += '    <a class="btn" href="' + s.url + '" target="_blank" rel="noreferrer">🔗 Open URL</a>';
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
  </script>
</body>
</html>
    ''';
  }
}
