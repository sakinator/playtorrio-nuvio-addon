# ⚡ PlayTorrio HTTP Streams Addon for Nuvio

A high-performance local Stremio & Nuvio-compatible addon server that extracts and executes the **46 HTTP & HLS scrapers** (non-torrent) from [ayman708-UX/PlayTorrioV3](https://github.com/ayman708-UX/PlayTorrioV3).

---

## 🌟 Features

- **100% HTTP/HLS Scrapers (Zero Torrents):** No P2P, no seeders needed. Directly extracts high-speed cloud streams from 46 providers including *RiveStream, Vadapav, LookMovie, VidLink, Movy, Videasy, Cinejoy, FlyStream, X-Downloader, Vuflix, FSOnline*, and more.
- **Nuvio & Stremio Compatible:** Follows the Stremio Addon protocol (`/manifest.json` and `/stream/{type}/{id}.json`), fully compatible with [NuvioTV, NuvioMobile, NuvioDesktop](https://github.com/NuvioMedia).
- **Embedded Streaming Proxy (`/proxy`):** Transparently forwards and rewrites HLS (`.m3u8`) playlists and injects required `Referer`, `Origin`, and `User-Agent` headers so that Nuvio's internal video player plays protected CDN streams without 403 errors.
- **Quality & Multi-Audio Detection:** Automatically tags streams with badges (4K UHD, 1080p, 720p, HDR, HLS, Multi-Audio, Hindi, English, etc.) and sorts highest quality first.
- **Built-in Web Dashboard (`/configure`):** Interactive dark-mode dashboard to enable/disable scrapers, adjust timeout, test scrape any movie/series title in real-time, and trigger updates.
- **Upstream Update Pipeline:** Includes a local pipeline (`pipeline/update.bat` and `update.ps1`) to automatically fetch updates from `PlayTorrioV3`, detect new scrapers, regenerate the registry, and hot-reload them on the fly.
- **Standalone Binary:** Compiled as a standalone Windows executable (`playtorrio-addon.exe`) with zero external runtime requirements.

---

## 🚀 Quick Start (Local Hosting on Windows PC)

### Method 1: Double-Click the Executable
Double-click `playtorrio-addon.exe` (or `start.bat`) inside this folder:
```
D:\playtorrio-nuvio-addon\playtorrio-addon.exe
```

---

## 📱 Android TV (NVIDIA Shield) & Mobile App (APK)

A dedicated Android application (`android_app`) is included, designed specifically for **Android TV (NVIDIA Shield Pro, Fire TV, Chromecast TV)** and **Android Mobile Phones / Tablets**:

- **TV-Friendly Remote / D-Pad Navigation:** High-contrast focus borders, scale animations on hover/focus, and remote-friendly button activation (OK / Select).
- **Background Foreground Service:** Keeps the local HTTP server alive 24/7 on NVIDIA Shield even when you switch to Nuvio or turn off the screen (with automatic WakeLock & auto-start on boot).
- **Zero Configuration:** Automatically detects your Shield/Phone Wi-Fi IP and displays the clickable/copyable Manifest URL on screen.
- **Embedded Web Dashboard:** You can still open `http://<shield-ip>:7002/configure` from your phone or PC browser to toggle any of the 46 scraper providers.

### 🔨 Building the APK in the Cloud (GitHub Actions)

You do **NOT** need Android Studio or Flutter installed on your PC. The included GitHub Actions workflow builds the release `.apk` in 2-3 minutes.

1. **Push this folder to a GitHub repository:**
   ```powershell
   cd D:\playtorrio-nuvio-addon
   git init
   git add .
   git commit -m "feat: PlayTorrio HTTP streams addon for Nuvio (PC & Android TV)"
   git branch -M main
   git remote add origin https://github.com/<YOUR_GITHUB_USERNAME>/<YOUR_REPO_NAME>.git
   git push -u origin main
   ```
2. **Download the APK:**
   - Go to your repository on GitHub.
   - Click the **Actions** tab ➔ select **Build Android APK (TV & Mobile)**.
   - Click on the latest workflow run.
   - Scroll down to **Artifacts** and download `playtorrio-nuvio-addon-tv-mobile` (contains `app-release.apk`).
3. **Install on NVIDIA Shield / Android TV:**
   - Sideload `app-release.apk` onto your Shield (e.g., using a USB drive or the "Send Files to TV" app from the Play Store).
   - Launch the app from your Android TV apps row.
   - The app will start the server and show your Manifest URL:
     ```
     http://<SHIELD_IP>:7002/manifest.json
     ```
   - In **Nuvio** on the same Shield: Go to **Settings** ➔ **Add-ons** ➔ **Install from URL** ➔ enter `http://localhost:7002/manifest.json` (or the LAN IP). Done!

---


### Method 2: Command Line (PowerShell)
```powershell
cd D:\playtorrio-nuvio-addon
.\start.ps1
```

Once running, the console will show:
```
===============================================================
       ⚡ PlayTorrio HTTP Streams Addon for Nuvio ⚡           
===============================================================
 Status: RUNNING
 Port:   7000
 Local:  http://localhost:7000
 LAN IP: http://192.168.0.127:7000
---------------------------------------------------------------
 🔌 Nuvio Addon Manifest URLs:
    Localhost: http://localhost:7000/manifest.json
    LAN (TV):  http://192.168.0.127:7000/manifest.json
---------------------------------------------------------------
 🌐 Web Dashboard: http://localhost:7000/configure
===============================================================
```

---

## 📺 Installing the Addon in Nuvio

1. Open **Nuvio** (on your PC, Android TV, or Phone/Tablet).
2. Go to **Settings** ➔ **Add-ons** (or click the Add-on icon / **+** button).
3. Select **Install from URL** and paste:
   - **For Nuvio on this PC:** `http://localhost:7000/manifest.json`
   - **For Nuvio on Android TV / Phone:** `http://<YOUR_LAN_IP>:7000/manifest.json` (e.g., `http://192.168.0.127:7000/manifest.json`)
4. Click **Install**.
5. Browse any Movie or TV Show in Nuvio. You will now see direct PlayTorrio streams!

---

## 🔄 Local Update Pipeline (Syncing with PlayTorrio)

When the author of PlayTorrio pushes updates (bug fixes, domain changes, or new scraper providers) to [ayman708-UX/PlayTorrioV3](https://github.com/ayman708-UX/PlayTorrioV3):

### Option 1: One-Click Update Batch File
Simply double-click `pipeline\update.bat`.
This will:
1. Run `git pull origin main` in `upstream/PlayTorrioV3`.
2. Automatically scan for any newly added scrapers and regenerate `lib/scraper_registry.dart`.
3. Hot-reload the scrapers in your running addon server (no server restart required!).

### Option 2: Web Dashboard Button
1. Open `http://localhost:7000/configure` in your browser.
2. Scroll to the **PlayTorrio Upstream Pipeline** section.
3. Click **⚡ Check & Pull Updates**.

### Option 3: Automated Daily Scheduled Task (Optional)
To have Windows automatically check for PlayTorrio updates every day at 4:00 AM:
```powershell
powershell -ExecutionPolicy Bypass -File pipeline\setup_auto_update_task.ps1
```

---

## 📂 Project Structure

```
playtorrio-nuvio-addon/
├── playtorrio-addon.exe      # Compiled standalone Windows server binary
├── start.bat                 # One-click Windows starter
├── start.ps1                 # PowerShell starter with auto-detect IP
├── pubspec.yaml              # Dart project manifest
├── bin/
│   └── server.dart           # Stremio & Nuvio HTTP Addon Server
├── lib/
│   ├── config.dart           # Addon settings (port, timeouts, toggles)
│   ├── metadata_service.dart # IMDB/TMDB/Cinemeta metadata resolver
│   ├── proxy.dart            # Streaming proxy with HLS m3u8 header injection
│   ├── scraper_engine.dart   # Parallel multi-scraper orchestrator
│   ├── scraper_registry.dart # Auto-generated registry of all 46 scrapers
│   ├── web_ui.dart           # Interactive Web Dashboard UI
│   └── upstream              # Filesystem junction pointing to upstream scrapers
├── upstream/
│   └── PlayTorrioV3/         # Git clone tracking ayman708-UX/PlayTorrioV3
├── shim/
│   ├── flutter/              # Headless flutter/foundation shim for pure Dart
│   └── shared_preferences/   # Local JSON persistence shim
├── pipeline/
│   ├── update.bat            # One-click update pipeline
│   ├── update.ps1            # Upstream git pull + registry generator + hot-reload
│   └── setup_auto_update_task.ps1 # Optional Windows daily scheduler
└── tool/
    └── generate_registry.dart # Scraper discovery & code generator
```

---

## 🛠️ List of Active Scrapers (46 Total)

| Scraper Provider | Provider ID | Description |
| :--- | :--- | :--- |
| **111477** | `a111477` | Multi-resolution HTTP stream scraper |
| **Vadapav** | `vadapav` | Direct high-speed HTTP media storage |
| **RiveStream** | `rivestream` | Multi-server high bitrate streams & 4K |
| **LookMovie** | `lookmovie` | Multi-quality direct streams |
| **VidLink** | `vidlink` | Fast multi-CDN direct streams |
| **Movy** | `movy` | Encrypted MP4/HLS direct streams |
| **Videasy** | `videasy` | Multi-CDN encrypted HLS scraper |
| **Cinejoy** | `cinejoy` | Multi-CDN video streams |
| **FlyStream** | `flystream` | Ultra-fast HLS streaming network |
| **XDownloader** | `xdownloader` | Multi-source stream extractor |
| **VidSrc** | `vidsrc` | Direct streaming resolver |
| **MultiEmbed** | `multiembed` | 2Embed multi-host aggregator |
| **VidCore** | `vidcore` | Multi-source HD video extractor |
| **MovieNight** | `movienight` | Multi-server HLS streams |
| **DownloadEverything** | `downloadeverything` | Direct media download & stream extractor |
| **Vuflix** | `vuflix` | Fast cloud HLS stream resolver |
| **Dulo** | `dulo` | High-speed direct stream network |
| **VidUp** | `vidup` | Cloud video hosting scraper |
| **FlaxMovies** | `flaxmovies` | Multi-CDN direct streams |
| **VidGod** | `vidgod` | Multi-server cloud video streams |
| **VidFast** | `vidfast` | Low-latency direct streaming provider |
| **PeeStream** | `peestream` | Fast cloud video source provider |
| **Hexa** | `hexa` | Multi-host video extractor |
| **Bcine** | `bcine` | Direct master HLS provider |
| **Mapple** | `mapple` | Fast streaming provider |
| **Nova** | `nova` | Multi-server stream extractor |
| **MegaSource** | `megasource` | Multi-CDN video network |
| **Purstream** | `purstream` | Direct video stream resolver |
| **VidApi** | `vidapi` | Direct video source extractor |
| **VidRock** | `vidrock` | Cloud video provider |
| **VidVault** | `vidvault` | Secure streaming network |
| **VidZee** | `vidzee` | High-speed video provider |
| **CineSrc** | `cinesrc` | Direct master HLS streams |
| **CineSu** | `cinesu` | Direct video stream extractor |
| **Frame** | `frame` | Multi-resolution stream provider |
| **FshareTV** | `fsharetv` | Cloud streaming network |
| **FSonic** | `fsonic` | Direct cloud video scraper |
| **FSOnline** | `fsonline` | Multi-host stream resolver |
| **KissKH** | `kisskh` | Asian drama & anime provider |
| **LMScript** | `lmscript` | Video source extractor |
| **MeowTV** | `meowtv` | Direct streaming network |
| **VixSrc** | `vixsrc` | Master streaming extractor |
| **XPass** | `xpass` | Multi-server video scraper |
| **ZxcStream** | `zxcstream` | Multi-source direct provider |
| **HindMoviez** | `hindmoviez` | Bollywood, Hindi Dual-Audio & Hollywood |
| **4KHDHub** | `fourkhdhub` | 4K & HD direct stream extractor |
