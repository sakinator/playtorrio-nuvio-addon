# ⚡ sakinator-MegaScraper Addon for Nuvio & Stremio

A high-performance local Stremio & Nuvio-compatible addon server featuring **56 Direct HTTP/HLS Cloud Scrapers**, **TorBox Debrid Integration**, **Live Hoster Cloud Caching**, and rich public catalogs (**YouTube, Internet Archive & Dailymotion**) with automatic badge tagging and streaming proxy.

---

## 🌟 Features

- **100% Non-Torrent (Zero P2P):** No seeders, no torrent clients, and no IP seeding exposure. Streams directly from fast cloud storage and HTTP/HLS CDNs.
- **56 Cloud Scraper Providers:** Extracts streams across 56 scrapers including *4KHDHub, Vadapav, HindMoviez, RiveStream, LookMovie, VidLink, Movy, Videasy, Cinejoy, FlyStream, X-Downloader, Vuflix, FSOnline, KissKH, Megasource, Nova, Purstream*, and more.
- **TorBox Debrid Integration:**
  - **Instant Cache Detection:** Checks TorBox servers in real-time to see if scraped hoster links (HubCloud, PixelDrain, DriveSeed, GoFile, etc.) are already cached.
  - **1-Click Cloud Caching:** Direct "⚡ Cache to TorBox" links in Nuvio and the Web Dashboard. Submits uncached links to TorBox's WebDL downloader in 1 click.
  - **High-Speed CDN Playback:** Streams cached hoster files through TorBox's ultra-fast Indian and global CDN nodes with full byte-range HTTP 206 seeking in Nuvio (MPV player).
  - **Strict Privacy Guarantee:** Your TorBox API key is strictly manual-input only. It is saved in gitignored `data/config.json` and is **never** auto-scanned from personal directories or leaked in stream titles or GitHub commits.
- **4 Rich Media Catalogs:**
  - 🎬 **YouTube Indian Cinema:** Bollywood classics, South Indian Hindi dubbed movies, comedy, and web series.
  - 🌍 **YouTube International:** Curated action, sci-fi, thriller, documentaries, and indie films.
  - 🏛️ **Internet Archive Classics:** Golden Era Hollywood, film noir, silent cinema, classic horror, and vintage Indian cinema.
  - 📺 **Dailymotion Indian & Global:** Hindi movies, dramas, Pakistani serials, and international titles.
- **NardBadges Visual Quality Tagging:** Automatically matches video resolutions (4K, 1080p, 720p), HDR/Dolby Vision, audio formats (Atmos, DTS:X, 5.1/7.1, AAC), and video codecs (HEVC, AV1, AVC) with high-res badges.
- **Embedded Streaming Proxy (`/proxy`):** Transparently forwards protected HLS (`.m3u8`) playlists and injects required `Referer`, `Origin`, and `User-Agent` headers so that Nuvio's internal player plays restricted streams without HTTP 403 errors.
- **Interactive Web Dashboard (`/configure`):** Dark-mode web interface to test scrape titles, toggle scrapers, manage your TorBox key, inspect live supported hosters, and check for updates.
- **Android TV & Mobile APK:** Native Flutter client for NVIDIA Shield, Fire TV, Google TV, and Android phones with full D-pad remote navigation and 24/7 background foreground service.

---

## 🚀 Quick Start (Windows PC)

### Method 1: Double-Click the Executable
Run `sakinator-MegaScraper.exe` (or `start.bat`) inside this directory:
```powershell
.\sakinator-MegaScraper.exe 7002
```

Console output:
```text
===============================================================
          ⚡ sakinator-MegaScraper Addon for Nuvio ⚡         
===============================================================
 Status: RUNNING
 Port:   7002
 Local:  http://localhost:7002
 LAN IP: http://192.168.0.127:7002
---------------------------------------------------------------
 🔌 Nuvio Addon Manifest URLs:
    Localhost: http://localhost:7002/manifest.json
    LAN (TV):  http://192.168.0.127:7002/manifest.json
---------------------------------------------------------------
 🌐 Web Dashboard: http://localhost:7002/configure
===============================================================
```

### Method 2: PowerShell Script
```powershell
.\start.ps1
```

---

## 📱 Android TV (NVIDIA Shield, Fire TV) & Mobile APK

The `android_app` directory contains the complete cross-platform Flutter application tailored for Android TV and mobile devices:

- **D-Pad Remote Friendly:** TV remote focus borders, smooth scale animations, and intuitive D-pad navigation.
- **Background Foreground Service:** Keeps the addon server running 24/7 in the background with wake-lock support.
- **TorBox Debrid Settings Card:** Input and validate your TorBox API key directly on your TV or phone with show/hide password toggle.
- **Automatic IP Detection:** Detects local Wi-Fi IP and displays the ready-to-copy Addon Manifest URL.

### 🔨 GitHub Actions Automated Build
The included CI workflow (`.github/workflows/build-apk.yml`) compiles the release APK on every push to `main`:
1. Go to the **Actions** tab on GitHub.
2. Select **Build Android APK (TV & Mobile)** ➔ Click the latest workflow run.
3. Download the artifact `sakinator-MegaScraper-apk`.
4. Sideload the APK onto your Android TV or phone.

---

## 📺 Adding to Nuvio or Stremio

1. Open **Nuvio** or **Stremio**.
2. Navigate to **Settings** ➔ **Add-ons** ➔ **Add Addon / Install from URL**.
3. Paste the Addon Manifest URL:
   - **Running on the same device:** `http://localhost:7002/manifest.json`
   - **Running on PC, streaming on TV/Phone:** `http://<YOUR_PC_LAN_IP>:7002/manifest.json` (e.g. `http://192.168.0.127:7002/manifest.json`)
4. Click **Install**.
5. Select any movie or series to enjoy instant direct cloud streams!

---

## 🔑 TorBox Debrid Configuration

TorBox integration is optional but unlocks high-speed cloud caching for hoster links:
1. Open the Web Dashboard at `http://localhost:7002/configure` (or the Android APK settings screen).
2. Enter your API Key from [torbox.app/settings](https://torbox.app/settings).
3. Click **Save & Validate**.
4. The dashboard will verify your account status and fetch live supported hosters.

> [!IMPORTANT]
> Your TorBox API key is never shared, never committed to git, and never uploaded to third parties. It is stored exclusively in your local `data/config.json`.

---

## 📂 Project Structure

```text
sakinator-MegaScraper/
├── sakinator-MegaScraper.exe # Compiled standalone Windows binary
├── start.bat                 # Windows one-click starter
├── start.ps1                 # PowerShell launcher
├── bin/
│   └── server.dart           # Standalone HTTP Addon Server
├── lib/
│   ├── badge_service.dart    # NardBadges stream badge matching engine
│   ├── catalog_service.dart  # YouTube, Archive.org & Dailymotion catalogs
│   ├── config.dart           # Port, timeouts, provider toggles & settings
│   ├── metadata_service.dart # IMDB/TMDB/Cinemeta metadata resolver
│   ├── proxy.dart            # HLS .m3u8 proxy & header injection engine
│   ├── scraper_engine.dart   # Parallel scraper dispatcher & sanitizer
│   ├── scraper_registry.dart # Auto-generated registry of 56 scrapers
│   ├── torbox_service.dart   # TorBox WebDL, cache verification & CDN streaming
│   └── web_ui.dart           # Dark-mode Web Configuration Dashboard
├── android_app/              # Android TV & Mobile Flutter application
│   ├── lib/main.dart         # TV/Mobile UI with TorBox settings card
│   └── lib/server_service.dart # Background server service
└── .github/workflows/
    └── build-apk.yml         # Automated GitHub Actions APK builder
```

---

## 🛠️ List of Active Scrapers (56 Total)

| Scraper Provider | ID | Description |
| :--- | :--- | :--- |
| **4KHDHub** | `fourkhdhub` | 4K UHD & HD direct cloud and hoster links |
| **Vadapav** | `vadapav` | Direct high-speed media storage |
| **HindMoviez** | `hindmoviez` | Bollywood, Hindi Dual-Audio & Hollywood |
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
| *And 10 additional cloud scrapers* | ... | Continuous updates via upstream pipeline |
