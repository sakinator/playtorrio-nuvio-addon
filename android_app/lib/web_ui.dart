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
    final cfg = AddonConfig.instance;
    final torboxApiKey = cfg.torboxApiKey;
    final omdbApiKey = cfg.omdbApiKey;
    final fanartApiKey = cfg.fanartApiKey;
    final tvdbApiKey = cfg.tvdbApiKey;
    final showRatingsChecked = cfg.showRatingsInStreams ? 'checked' : '';
    final excludeCamsChecked = cfg.excludeCams ? 'checked' : '';
    final dedupeChecked = cfg.enableDeduplication ? 'checked' : '';
    final deadLinkChecked = cfg.enableDeadLinkFilter ? 'checked' : '';
    final maxRes = cfg.maxResolution;
    final prefLang = cfg.preferredLanguage;

    final providerCheckboxes = providers.map((p) {
      final id = p['id'];
      final name = p['name'];
      final checked = p['enabled'] == true ? 'checked' : '';
      return '''
        <label class="provider-card" data-name="${name.toString().toLowerCase()}" data-id="${id.toString().toLowerCase()}">
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
  <!-- HLS.js for embedded web stream player preview -->
  <script src="https://cdn.jsdelivr.net/npm/hls.js@1.5.8/dist/hls.min.js"></script>
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
      --green-light: #3fb950;
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
      padding: 28px 0 20px;
    }
    h1 {
      font-size: 2.2rem;
      background: var(--accent-grad);
      -webkit-background-clip: text;
      -webkit-text-fill-color: transparent;
      margin-bottom: 6px;
    }
    p.subtitle { color: var(--text-muted); font-size: 1.05rem; }

    /* Engine Status Banner */
    .status-banner {
      display: flex;
      flex-wrap: wrap;
      gap: 10px;
      justify-content: center;
      margin-bottom: 24px;
    }
    .status-chip {
      background: rgba(22, 27, 34, 0.9);
      border: 1px solid var(--border);
      border-radius: 20px;
      padding: 6px 14px;
      font-size: 0.82rem;
      color: var(--text);
      display: inline-flex;
      align-items: center;
      gap: 8px;
    }
    .status-dot {
      width: 8px;
      height: 8px;
      border-radius: 50%;
      background: var(--green-light);
      box-shadow: 0 0 8px var(--green-light);
    }

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
    .password-wrapper {
      flex: 1;
      position: relative;
      display: flex;
    }
    .password-wrapper input {
      width: 100%;
      padding-right: 44px;
    }
    .password-toggle-btn {
      position: absolute;
      right: 8px;
      top: 50%;
      transform: translateY(-50%);
      background: none;
      border: none;
      color: var(--text-muted);
      cursor: pointer;
      font-size: 1.1rem;
      padding: 4px;
      border-radius: 4px;
    }
    .password-toggle-btn:hover {
      color: var(--text);
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
    .btn-play {
      background: #1f6feb;
      border-color: #388bfd;
      color: #fff;
    }
    .btn-play:hover {
      background: #388bfd;
    }
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
      max-height: 520px;
      overflow-y: auto;
      font-size: 0.88rem;
      display: none;
    }
    .stream-filter-bar {
      display: flex;
      gap: 8px;
      margin-bottom: 14px;
      flex-wrap: wrap;
      align-items: center;
    }
    .stream-filter-chip {
      background: #161b22;
      border: 1px solid var(--border);
      color: var(--text-muted);
      padding: 4px 10px;
      border-radius: 16px;
      cursor: pointer;
      font-size: 0.78rem;
      font-weight: 600;
      transition: all 0.15s;
    }
    .stream-filter-chip:hover, .stream-filter-chip.active {
      background: #21262d;
      color: var(--text);
      border-color: var(--blue);
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

    /* Modal Player Styles */
    .player-modal {
      display: none;
      position: fixed;
      top: 0;
      left: 0;
      width: 100%;
      height: 100%;
      background: rgba(0,0,0,0.85);
      z-index: 99999;
      justify-content: center;
      align-items: center;
      padding: 20px;
    }
    .player-modal-content {
      background: #161b22;
      border: 1px solid var(--border);
      border-radius: 12px;
      width: 100%;
      max-width: 900px;
      overflow: hidden;
      box-shadow: 0 8px 32px rgba(0,0,0,0.8);
      display: flex;
      flex-direction: column;
    }
    .player-header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      padding: 14px 18px;
      border-bottom: 1px solid var(--border);
      background: #0d1117;
    }
    .player-title {
      font-weight: 600;
      font-size: 1rem;
      color: var(--text);
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }
    .player-close-btn {
      background: none;
      border: none;
      color: var(--text-muted);
      font-size: 1.5rem;
      cursor: pointer;
      line-height: 1;
      padding: 0 4px;
    }
    .player-close-btn:hover { color: #fff; }
    .video-wrapper {
      position: relative;
      width: 100%;
      padding-top: 56.25%; /* 16:9 Aspect Ratio */
      background: #000;
    }
    .video-wrapper video {
      position: absolute;
      top: 0;
      left: 0;
      width: 100%;
      height: 100%;
    }
  </style>
</head>
<body>
  <div class="container">
    <header>
      <h1>⚡ sakinator-MegaScraper</h1>
      <p class="subtitle">56 Non-Torrent Cloud Scrapers + Badges + TorBox Debrid for Nuvio & Stremio</p>
    </header>

    <!-- Architecture & Engine Status Pills -->
    <div class="status-banner">
      <div class="status-chip"><span class="status-dot"></span> <strong>DNS-over-HTTPS:</strong> Cloudflare & Google Fallback (Active)</div>
      <div class="status-chip"><span class="status-dot"></span> <strong>HLS Segment Cache:</strong> 35MB RAM Ring Buffer (Active)</div>
      <div class="status-chip"><span class="status-dot"></span> <strong>DASH to HLS:</strong> Virtual Transmuxer Ready</div>
      <div class="status-chip"><span class="status-dot"></span> <strong>Circuit Breaker:</strong> 56 Providers Monitored</div>
    </div>

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
        <div class="password-wrapper">
          <input class="url-input" type="password" id="torboxApiKey" value="$torboxApiKey" placeholder="Enter your TorBox API Key">
          <button type="button" class="password-toggle-btn" onclick="togglePasswordVisibility()" title="Show/Hide Key">👁️</button>
        </div>
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

    <!-- Stream Filtering Profiles & Optimization -->
    <div class="card">
      <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom: 14px; flex-wrap:wrap; gap:8px;">
        <h2>🎛️ Stream Filtering Profiles & Optimization</h2>
        <button class="btn btn-primary" id="btnSaveSettings" onclick="saveSettings()">💾 Save Settings</button>
      </div>
      <p style="color:var(--text-muted); margin-bottom:16px; font-size:0.9rem;">
        Fine-tune how streams are filtered, deduplicated, and ranked in your Nuvio drawer.
      </p>

      <div style="display:grid; grid-template-columns:repeat(auto-fit, minmax(280px, 1fr)); gap:16px; margin-bottom:16px;">
        <div style="background:#090d13; border:1px solid var(--border); border-radius:8px; padding:14px;">
          <label style="font-weight:600; display:block; margin-bottom:6px;">Preferred Audio Language:</label>
          <select id="prefLangSelect" style="width:100%; padding:8px; background:#161b22; border:1px solid var(--border); border-radius:6px; color:var(--text); font-size:0.88rem;">
            <option value="any" ${prefLang == 'any' ? 'selected' : ''}>Any / Default Order</option>
            <option value="hindi" ${prefLang == 'hindi' ? 'selected' : ''}>🇮🇳 Hindi</option>
            <option value="english" ${prefLang == 'english' ? 'selected' : ''}>🇬🇧 English</option>
            <option value="dual" ${prefLang == 'dual' ? 'selected' : ''}>🌐 Dual Audio / Multi Audio</option>
            <option value="tamil" ${prefLang == 'tamil' ? 'selected' : ''}>🇮🇳 Tamil</option>
            <option value="telugu" ${prefLang == 'telugu' ? 'selected' : ''}>🇮🇳 Telugu</option>
            <option value="malayalam" ${prefLang == 'malayalam' ? 'selected' : ''}>🇮🇳 Malayalam</option>
            <option value="kannada" ${prefLang == 'kannada' ? 'selected' : ''}>🇮🇳 Kannada</option>
            <option value="bengali" ${prefLang == 'bengali' ? 'selected' : ''}>🇮🇳 Bengali</option>
            <option value="punjabi" ${prefLang == 'punjabi' ? 'selected' : ''}>🇮🇳 Punjabi</option>
            <option value="marathi" ${prefLang == 'marathi' ? 'selected' : ''}>🇮🇳 Marathi</option>
            <option value="gujarati" ${prefLang == 'gujarati' ? 'selected' : ''}>🇮🇳 Gujarati</option>
          </select>
          <div style="color:var(--text-muted); font-size:0.78rem; margin-top:6px;">Boosts matching releases directly to the top of the stream list.</div>
        </div>

        <div style="background:#090d13; border:1px solid var(--border); border-radius:8px; padding:14px;">
          <label style="font-weight:600; display:block; margin-bottom:6px;">Max Resolution Cap:</label>
          <select id="maxResSelect" style="width:100%; padding:8px; background:#161b22; border:1px solid var(--border); border-radius:6px; color:var(--text); font-size:0.88rem;">
            <option value="all" ${maxRes == 'all' ? 'selected' : ''}>Unlimited (4K / 2160p Allowed)</option>
            <option value="1080p" ${maxRes == '1080p' ? 'selected' : ''}>1080p Max (Filters out 4K for lower bandwidth)</option>
            <option value="720p" ${maxRes == '720p' ? 'selected' : ''}>720p Max (Fastest playback & lowest data)</option>
          </select>
          <div style="color:var(--text-muted); font-size:0.78rem; margin-top:6px;">Prevents high-bitrate 4K streams on smaller devices or slow WiFi.</div>
        </div>
      </div>

      <div style="display:flex; flex-direction:column; gap:10px;">
        <label style="display:flex; align-items:center; gap:10px; cursor:pointer;">
          <input type="checkbox" id="chkExcludeCams" $excludeCamsChecked style="width:18px; height:18px;">
          <div>
            <strong style="color:var(--text);">Clean Drawer Mode (Exclude CAMs & TeleSync)</strong>
            <div style="color:var(--text-muted); font-size:0.8rem;">Automatically strips CAM, TS, PreDVD, and Telesync copies when high-grade WEB-DL or BluRay copies exist.</div>
          </div>
        </label>

        <label style="display:flex; align-items:center; gap:10px; cursor:pointer;">
          <input type="checkbox" id="chkDedupe" $dedupeChecked style="width:18px; height:18px;">
          <div>
            <strong style="color:var(--text);">Smart Stream Deduplication</strong>
            <div style="color:var(--text-muted); font-size:0.8rem;">Merges identical CDN streams from multiple providers into a single card with combined tags.</div>
          </div>
        </label>

        <label style="display:flex; align-items:center; gap:10px; cursor:pointer;">
          <input type="checkbox" id="chkDeadLink" $deadLinkChecked style="width:18px; height:18px;">
          <div>
            <strong style="color:var(--text);">Ultra-Fast Dead-Link Filter</strong>
            <div style="color:var(--text-muted); font-size:0.8rem;">Runs a rapid 1200ms parallel HEAD probe on direct stream links to eliminate 404/broken file hosters.</div>
          </div>
        </label>

        <label style="display:flex; align-items:center; gap:10px; cursor:pointer;">
          <input type="checkbox" id="chkShowRatings" $showRatingsChecked style="width:18px; height:18px;">
          <div>
            <strong style="color:var(--text);">Display Live Ratings in Stream Cards</strong>
            <div style="color:var(--text-muted); font-size:0.8rem;">Stamps IMDb ⭐, Rotten Tomatoes 🍅, and Metacritic Ⓜ️ scores directly onto stream links and /meta responses.</div>
          </div>
        </label>
      </div>
    </div>

    <!-- Metadata & Artwork API Integrations -->
    <div class="card">
      <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom: 14px; flex-wrap:wrap; gap:8px;">
        <h2>🎨 Metadata & Artwork API Integrations (OMDb, Fanart, TVDB)</h2>
        <button class="btn btn-primary" onclick="saveSettings()">💾 Save API Keys</button>
      </div>
      <p style="color:var(--text-muted); margin-bottom:16px; font-size:0.9rem;">
        Elevate Nuvio and Stremio with crystal-clear transparent ClearLogos, 4K banners, live Rotten Tomatoes/IMDb ratings, and anime absolute episode mappings. <strong>All keys are 100% optional</strong> — built-in zero-key public fallbacks (Cinemeta, Metahub, TVMaze) operate out of the box!
      </p>

      <div style="display:grid; grid-template-columns:repeat(auto-fit, minmax(300px, 1fr)); gap:16px;">
        <div style="background:#090d13; border:1px solid var(--border); border-radius:8px; padding:14px;">
          <label style="font-weight:600; display:block; margin-bottom:6px;">⭐ OMDb API Key <span style="font-weight:normal; font-size:0.8rem; color:#3fb950;">(Optional)</span>:</label>
          <input type="text" id="omdbApiKey" value="$omdbApiKey" placeholder="Pre-configured fallback key active" style="width:100%; padding:8px; background:#161b22; border:1px solid var(--border); border-radius:6px; color:var(--text); font-size:0.88rem;">
          <div style="color:var(--text-muted); font-size:0.78rem; margin-top:6px;">Supplies live IMDb ratings, RT tomatometer, and Metacritic scores. Falls back to Cinemeta ratings if empty.</div>
        </div>

        <div style="background:#090d13; border:1px solid var(--border); border-radius:8px; padding:14px;">
          <label style="font-weight:600; display:block; margin-bottom:6px;">✨ Fanart.tv API Key <span style="font-weight:normal; font-size:0.8rem; color:#3fb950;">(Optional)</span>:</label>
          <input type="text" id="fanartApiKey" value="$fanartApiKey" placeholder="Leave empty for Metahub ClearLogos" style="width:100%; padding:8px; background:#161b22; border:1px solid var(--border); border-radius:6px; color:var(--text); font-size:0.88rem;">
          <div style="color:var(--text-muted); font-size:0.78rem; margin-top:6px;">Renders transparent PNG ClearLogos and 4K backdrops. Automatically falls back to Metahub CDN with zero keys.</div>
        </div>

        <div style="background:#090d13; border:1px solid var(--border); border-radius:8px; padding:14px;">
          <label style="font-weight:600; display:block; margin-bottom:6px;">📺 TheTVDB API Key <span style="font-weight:normal; font-size:0.8rem; color:#3fb950;">(Optional)</span>:</label>
          <input type="text" id="tvdbApiKey" value="$tvdbApiKey" placeholder="Leave empty for Cinemeta & TVMaze" style="width:100%; padding:8px; background:#161b22; border:1px solid var(--border); border-radius:6px; color:var(--text); font-size:0.88rem;">
          <div style="color:var(--text-muted); font-size:0.78rem; margin-top:6px;">Maps absolute episode numbers and titles. Automatically falls back to Cinemeta & TVMaze with zero keys.</div>
        </div>
      </div>
    </div>

    <!-- Scraper Providers -->
    <div class="card">
      <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom: 14px; flex-wrap:wrap; gap:8px;">
        <h2>📦 HTTP Scraper Providers (<span id="enabledCount">$enabledCount</span>/${providers.length} Active)</h2>
        <div style="display:flex; gap:8px;">
          <button class="btn" onclick="bulkToggle(true)">Enable All</button>
          <button class="btn" onclick="bulkToggle(false)">Disable All</button>
        </div>
      </div>
      <!-- Instant Search Filter -->
      <div style="display:flex; gap:10px; margin-bottom:12px; align-items:center;">
        <input type="text" id="providerSearchInput" placeholder="🔍 Search 56 providers (e.g. hubcloud, 111477, vidsrc, bollyflix)..." oninput="filterProvidersList()" style="flex:1; padding:8px 12px; background:#090d13; border:1px solid var(--border); border-radius:6px; color:var(--text); font-size:0.88rem;">
        <span id="providerFilteredCount" style="font-size:0.82rem; color:var(--text-muted); white-space:nowrap;">Showing ${providers.length} of ${providers.length}</span>
      </div>
      <div class="grid" id="providersGrid">
        $providerCheckboxes
      </div>
    </div>

    <!-- Live Stream Tester -->
    <div class="card">
      <h2>🔍 Live Stream Tester & Preview Player</h2>
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

  <!-- Inline Stream Player Modal -->
  <div id="playerModal" class="player-modal" onclick="closePlayerModal(event)">
    <div class="player-modal-content" onclick="event.stopPropagation()">
      <div class="player-header">
        <div class="player-title" id="playerStreamTitle">Stream Preview</div>
        <button class="player-close-btn" onclick="closePlayerModal()">✕</button>
      </div>
      <div class="video-wrapper">
        <video id="previewVideoPlayer" controls playsinline></video>
      </div>
    </div>
  </div>

  <div id="toast" class="toast">Copied to clipboard!</div>

  <script>
    let currentStreams = [];
    let activeFilter = 'all';
    let currentHls = null;

    function showToast(msg) {
      const toast = document.getElementById('toast');
      toast.innerText = msg;
      toast.style.display = 'block';
      setTimeout(() => { toast.style.display = 'none'; }, 3000);
    }

    function copyText(id) {
      const copyText = document.getElementById(id);
      copyText.select();
      copyText.setSelectionRange(0, 99999);
      navigator.clipboard.writeText(copyText.value);
      showToast('📋 Copied: ' + copyText.value);
    }

    function togglePasswordVisibility() {
      const input = document.getElementById('torboxApiKey');
      input.type = input.type === 'password' ? 'text' : 'password';
    }

    function filterProvidersList() {
      const query = document.getElementById('providerSearchInput').value.trim().toLowerCase();
      const cards = document.querySelectorAll('#providersGrid .provider-card');
      let visible = 0;
      cards.forEach(c => {
        const name = c.getAttribute('data-name') || '';
        const id = c.getAttribute('data-id') || '';
        if (!query || name.includes(query) || id.includes(query)) {
          c.style.display = '';
          visible++;
        } else {
          c.style.display = 'none';
        }
      });
      document.getElementById('providerFilteredCount').innerText = 'Showing ' + visible + ' of ' + cards.length;
    }

    async function toggleProvider(id, enabled) {
      try {
        const res = await fetch('/api/provider/' + id, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ enabled: enabled })
        });
        const data = await res.json();
        if (data.success) {
          const countSpan = document.getElementById('enabledCount');
          let current = parseInt(countSpan.innerText);
          countSpan.innerText = enabled ? current + 1 : current - 1;
          showToast((enabled ? 'Enabled ' : 'Disabled ') + id);
        }
      } catch (err) {
        showToast('Error updating provider');
      }
    }

    async function bulkToggle(enable) {
      const checkboxes = document.querySelectorAll('input[name="provider"]');
      const ids = Array.from(checkboxes).map(c => c.value);
      try {
        const res = await fetch('/api/providers/bulk', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ ids: ids, enabled: enable })
        });
        const data = await res.json();
        if (data.success) {
          checkboxes.forEach(c => c.checked = enable);
          document.getElementById('enabledCount').innerText = enable ? checkboxes.length : 0;
          showToast(enable ? 'All providers enabled' : 'All providers disabled');
        }
      } catch (err) {
        showToast('Error updating providers');
      }
    }

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
        const acc = (data.account && data.account.valid !== undefined) ? data.account : data;
        if (data.success && acc.valid) {
          badge.innerText = '✅ ' + (acc.plan ? acc.plan.toUpperCase() : 'Connected');
          badge.style.background = 'rgba(35, 134, 54, 0.3)';
          badge.style.color = '#3fb950';
          info.style.display = 'block';
          info.innerHTML = '<strong>Account:</strong> ' + escapeHtml(acc.email || 'Active User') + ' | <strong>Plan:</strong> ' + escapeHtml(acc.plan || 'Standard') + (acc.expires ? ' (Expires: ' + escapeHtml(acc.expires) + ')' : '');
          showToast('✅ TorBox Connected: ' + (acc.plan || 'Active'));
        } else {
          badge.innerText = '❌ Invalid Key';
          badge.style.background = 'rgba(248, 81, 73, 0.3)';
          badge.style.color = '#f85149';
          info.style.display = 'block';
          info.innerHTML = '<span style="color:#f85149;">' + escapeHtml(acc.message || data.message || 'Invalid API Key') + '</span>';
          showToast('❌ Invalid TorBox API Key' + (acc.message ? ': ' + acc.message : ''));
        }
      } catch (e) {
        showToast('Error validating TorBox key: ' + e);
      } finally {
        btn.disabled = false;
        btn.innerText = '💾 Save & Validate';
      }
    }

    async function saveSettings() {
      const btn = document.getElementById('btnSaveSettings');
      btn.disabled = true;
      btn.innerText = 'Saving...';
      try {
        const res = await fetch('/api/settings', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            excludeCams: document.getElementById('chkExcludeCams').checked,
            maxResolution: document.getElementById('maxResSelect').value,
            preferredLanguage: document.getElementById('prefLangSelect').value,
            enableDeduplication: document.getElementById('chkDedupe').checked,
            enableDeadLinkFilter: document.getElementById('chkDeadLink').checked,
            showRatingsInStreams: document.getElementById('chkShowRatings').checked,
            omdbApiKey: document.getElementById('omdbApiKey').value.trim(),
            fanartApiKey: document.getElementById('fanartApiKey').value.trim(),
            tvdbApiKey: document.getElementById('tvdbApiKey').value.trim(),
          })
        });
        const data = await res.json();
        if (data.success) {
          showToast('✅ Playback & API Settings Saved!');
        } else {
          showToast('❌ Error saving settings');
        }
      } catch (e) {
        showToast('Error saving settings: ' + e);
      } finally {
        btn.disabled = false;
        btn.innerText = '💾 Save Settings';
      }
    }

    async function uploadLinkToTorbox(targetUrl) {
      const url = targetUrl || document.getElementById('torboxUploadUrl').value.trim();
      const status = document.getElementById('torboxUploadStatus');
      if (!url) {
        showToast('Please enter a link to cache');
        return;
      }

      status.style.display = 'block';
      status.innerHTML = '<span style="color:var(--blue);">Submitting link to TorBox cloud cache...</span>';

      try {
        const res = await fetch('/api/torbox/upload', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ url: url })
        });
        const data = await res.json();
        if (data.success) {
          status.innerHTML = '<span style="color:var(--green);">✅ ' + escapeHtml(data.message) + '</span>';
          showToast('✅ Queued to TorBox Cache!');
        } else {
          status.innerHTML = '<span style="color:#f85149;">❌ ' + escapeHtml(data.message) + '</span>';
          showToast('❌ Failed: ' + data.message);
        }
      } catch (e) {
        status.innerHTML = '<span style="color:#f85149;">Upload error: ' + e + '</span>';
      }
    }

    async function loadTorboxHosters() {
      const grid = document.getElementById('hostersGrid');
      grid.innerHTML = '<div style="color:var(--text-muted); padding:8px;">Fetching active hosters from TorBox...</div>';

      try {
        const res = await fetch('/api/torbox/hosters');
        const data = await res.json();
        if (data.success && data.hosters) {
          window.torboxHosters = data.hosters;
          renderHosters(data.hosters);
        } else {
          grid.innerHTML = '<div style="color:#f85149; padding:8px;">Failed to load hosters.</div>';
        }
      } catch (e) {
        grid.innerHTML = '<div style="color:#f85149; padding:8px;">Error loading hosters: ' + e + '</div>';
      }
    }

    function renderHosters(hosters) {
      const grid = document.getElementById('hostersGrid');
      if (!hosters || hosters.length === 0) {
        grid.innerHTML = '<div style="color:var(--text-muted); padding:8px;">No hosters found.</div>';
        return;
      }
      grid.innerHTML = hosters.map(h => {
        const isUp = h.status === 'online' || h.status === true || h.status === 'up';
        const domains = (h.domains || []).slice(0, 3).join(', ');
        return `
          <div class="hoster-card">
            <div style="display:flex; justify-content:space-between; align-items:center;">
              <span class="hoster-name">\${escapeHtml(h.name || h.id)}</span>
              <span class="hoster-status \${isUp ? 'status-up' : 'status-down'}">\${isUp ? 'ONLINE' : 'DOWN'}</span>
            </div>
            <div class="hoster-domains">\${escapeHtml(domains)}</div>
          </div>
        `;
      }).join('');
    }

    function filterHosters() {
      const q = document.getElementById('hosterSearch').value.toLowerCase().trim();
      if (!window.torboxHosters) return;
      const filtered = window.torboxHosters.filter(h => {
        const name = (h.name || h.id || '').toLowerCase();
        const domains = (h.domains || []).join(' ').toLowerCase();
        return name.includes(q) || domains.includes(q);
      });
      renderHosters(filtered);
    }

    function normalizeStreamUrl(url) {
      if (!url) return '';
      if (url.startsWith('/')) {
        return window.location.origin + url;
      }
      return url;
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
      resultsDiv.innerHTML = '<div style="color:var(--text-muted); padding:10px;">Scraping 56 providers for "' + escapeHtml(id) + '"...</div>';

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
            isCached: rawName.includes('[Cached]') || rawTitle.includes('Cached on TorBox'),
            isCache: rawName.includes('[Cache]') || rawTitle.includes('cache to TorBox'),
            is4K: rawName.includes('4K') || rawTitle.includes('[4K]'),
            is1080p: rawName.includes('1080p') || rawTitle.includes('[FHD]') || rawTitle.includes('1080p'),
          };
        });

        if (currentStreams.length === 0) {
          resultsDiv.innerHTML = '<div style="color:#f85149; padding:10px;">No streams found. Try another title or check your enabled providers.</div>';
        } else {
          renderFilteredStreams('all');
        }
      } catch (err) {
        resultsDiv.innerHTML = '<div style="color:#f85149; padding:10px;">Error testing scrape: ' + err + '</div>';
      } finally {
        btn.disabled = false;
        btn.innerText = '🚀 Test Scrape';
      }
    }

    function renderFilteredStreams(filter) {
      activeFilter = filter;
      const resultsDiv = document.getElementById('testResults');

      const count4K = currentStreams.filter(s => s.is4K).length;
      const count1080p = currentStreams.filter(s => s.is1080p).length;
      const countCached = currentStreams.filter(s => s.isCached).length;
      const countCache = currentStreams.filter(s => s.isCache).length;
      const countDirect = currentStreams.filter(s => !s.isCached && !s.isCache).length;

      let filtered = currentStreams;
      if (filter === '4k') filtered = currentStreams.filter(s => s.is4K);
      else if (filter === '1080p') filtered = currentStreams.filter(s => s.is1080p);
      else if (filter === 'cached') filtered = currentStreams.filter(s => s.isCached);
      else if (filter === 'cache') filtered = currentStreams.filter(s => s.isCache);
      else if (filter === 'direct') filtered = currentStreams.filter(s => !s.isCached && !s.isCache);

      let html = `
        <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:10px; flex-wrap:wrap; gap:8px;">
          <div style="font-weight:600; color:var(--green); font-size:1rem;">Found \${currentStreams.length} stream(s):</div>
          <div class="stream-filter-bar">
            <span class="stream-filter-chip \${filter === 'all' ? 'active' : ''}" onclick="renderFilteredStreams('all')">All (\${currentStreams.length})</span>
            <span class="stream-filter-chip \${filter === '4k' ? 'active' : ''}" onclick="renderFilteredStreams('4k')">4K UHD (\${count4K})</span>
            <span class="stream-filter-chip \${filter === '1080p' ? 'active' : ''}" onclick="renderFilteredStreams('1080p')">1080p FHD (\${count1080p})</span>
            <span class="stream-filter-chip \${filter === 'cached' ? 'active' : ''}" onclick="renderFilteredStreams('cached')">⚡ Cached (\${countCached})</span>
            <span class="stream-filter-chip \${filter === 'cache' ? 'active' : ''}" onclick="renderFilteredStreams('cache')">⚡ Cache (\${countCache})</span>
            <span class="stream-filter-chip \${filter === 'direct' ? 'active' : ''}" onclick="renderFilteredStreams('direct')">🌐 Direct (\${countDirect})</span>
          </div>
        </div>
      `;

      for (let i = 0; i < filtered.length; i++) {
        const s = filtered[i];
        const isTorbox = s.url.includes('/torbox/play') || s.title.includes('Torbox') || s.title.includes('Cached');
        html += '<div class="stream-item">';
        html += '  <div class="stream-info">';
        html += '    <div class="stream-title">' + escapeHtml(s.name) + '</div>';
        html += '    <div class="stream-sub">' + escapeHtml(s.title) + '</div>';
        html += '  </div>';
        html += '  <div class="stream-actions">';
        html += '    <button class="btn btn-play" onclick="openPlayerModal(' + s.index + ')">▶️ Play Stream</button>';
        html += '    <button class="btn btn-primary" onclick="copyStreamUrl(' + s.index + ')">📋 Copy URL</button>';
        html += '    <a class="btn" href="' + s.url + '" target="_blank" rel="noreferrer">🔗 Open URL</a>';
        if (!isTorbox) {
          html += '    <button class="btn btn-success" onclick="uploadLinkToTorbox(\\'' + escapeHtml(s.url) + '\\')">⚡ Cache to TorBox</button>';
        }
        html += '  </div>';
        html += '</div>';
      }

      resultsDiv.innerHTML = html;
    }

    function openPlayerModal(idx) {
      const s = currentStreams[idx];
      if (!s || !s.url) return;

      const modal = document.getElementById('playerModal');
      const title = document.getElementById('playerStreamTitle');
      const video = document.getElementById('previewVideoPlayer');

      title.innerText = s.name + ' - ' + s.title.split('\\n')[0];
      modal.style.display = 'flex';

      if (currentHls) {
        currentHls.destroy();
        currentHls = null;
      }

      const streamUrl = s.url;
      const isHls = streamUrl.includes('.m3u8') || streamUrl.includes('/proxy');

      if (isHls && Hls.isSupported()) {
        currentHls = new Hls({
          enableWorker: true,
          lowLatencyMode: true,
        });
        currentHls.loadSource(streamUrl);
        currentHls.attachMedia(video);
        currentHls.on(Hls.Events.MANIFEST_PARSED, function() {
          video.play().catch(() => {});
        });
        currentHls.on(Hls.Events.ERROR, function(event, data) {
          if (data.fatal) {
            video.src = streamUrl;
            video.play().catch(() => {});
          }
        });
      } else {
        video.src = streamUrl;
        video.play().catch(() => {});
      }
    }

    function closePlayerModal(e) {
      const modal = document.getElementById('playerModal');
      const video = document.getElementById('previewVideoPlayer');
      video.pause();
      if (currentHls) {
        currentHls.destroy();
        currentHls = null;
      }
      video.removeAttribute('src');
      video.load();
      modal.style.display = 'none';
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

    // Handle ESC key to close player modal
    window.addEventListener('keydown', (e) => {
      if (e.key === 'Escape') {
        closePlayerModal();
      }
    });
  </script>
</body>
</html>
    ''';
  }
}
