import 'dart:convert';
import 'dart:io';
import 'package:playtorrio_nuvio_addon/config.dart';
import 'package:playtorrio_nuvio_addon/metadata_service.dart';
import 'package:playtorrio_nuvio_addon/proxy.dart';
import 'package:playtorrio_nuvio_addon/scraper_engine.dart';
import 'package:playtorrio_nuvio_addon/web_ui.dart';
import 'package:playtorrio_nuvio_addon/catalog_service.dart';
import 'package:playtorrio_nuvio_addon/torbox_service.dart';

void main(List<String> args) async {
  // ── CWD fix ──────────────────────────────────────────────────────────────
  // All file paths in the app (data/config.json, upstream/..., etc.) are
  // relative. Lock the CWD to the project root now so they resolve correctly
  // regardless of how the user launched the binary (double-click, Task
  // Scheduler, Windows Service, etc.).
  _ensureProjectRoot();

  final cfg = AddonConfig.instance;
  await cfg.load();

  // Allow port override from CLI (saved to config so it persists)
  if (args.isNotEmpty) {
    final parsedPort = int.tryParse(args[0]);
    if (parsedPort != null) {
      cfg.port = parsedPort;
      await cfg.save();
    }
  }

  final lanIp = await _getLocalIp();
  final server = await HttpServer.bind(InternetAddress.anyIPv4, cfg.port);

  print('===============================================================');
  print('          ⚡ sakinator-MegaScraper Addon for Nuvio ⚡         ');
  print('===============================================================');
  print(' Status: RUNNING');
  print(' Port:   ${cfg.port}');
  print(' Local:  http://localhost:${cfg.port}');
  print(' LAN IP: http://$lanIp:${cfg.port}');
  print('---------------------------------------------------------------');
  print(' 🔌 Nuvio Addon Manifest URLs:');
  print('    Localhost: http://localhost:${cfg.port}/manifest.json');
  print('    LAN (TV):  http://$lanIp:${cfg.port}/manifest.json');
  print('---------------------------------------------------------------');
  print(' 🌐 Web Dashboard: http://localhost:${cfg.port}/configure');
  print('===============================================================\n');

  await for (final request in server) {
    // Don't await – each request runs independently so the server stays responsive.
    _handleRequest(request, lanIp, cfg.port);
  }
}

Future<void> _handleRequest(HttpRequest request, String lanIp, int port) async {
  final path = request.uri.path;
  final method = request.method.toUpperCase();

  // Always enable CORS for Nuvio TV, Mobile, Desktop & Web
  request.response.headers.set('Access-Control-Allow-Origin', '*');
  request.response.headers.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS, HEAD');
  request.response.headers.set('Access-Control-Allow-Headers', '*');

  if (method == 'OPTIONS') {
    request.response.statusCode = HttpStatus.ok;
    await request.response.close();
    return;
  }

  // Use the incoming Host header if present (e.g. localhost:7002 from this PC,
  // or 192.168.0.127:7002 from TV on LAN), ensuring proxy URLs are always
  // directly reachable by whoever made the request.
  final hostHeader = request.headers.host;
  final localBaseUrl = (hostHeader != null && hostHeader.isNotEmpty)
      ? 'http://$hostHeader'
      : 'http://$lanIp:$port';

  try {
    // ── 1. Root / Configure Web UI ────────────────────────────────────────
    if (path == '/' || path == '/configure') {
      request.response.headers.contentType = ContentType.html;
      request.response.write(WebUI.render(localIp: lanIp, port: port));
      await request.response.close();
      return;
    }

    // ── 2. Stremio/Nuvio Addon Manifest ───────────────────────────────────
    if (path == '/manifest.json') {
      final manifest = {
        'id': 'org.sakinator.megascraper',
        'version': '1.5.0',
        'name': 'sakinator-MegaScraper',
        'description': '56 Direct Cloud Scrapers + Torbox Debrid + YouTube, Archive.org & Dailymotion Catalogs (100% Non-Torrent)',
        'resources': ['catalog', 'meta', 'stream'],
        'types': ['movie', 'series'],
        'idPrefixes': ['tt', 'tmdb', 'kitsu', 'yt:', 'archive:', 'dm:'],
        'catalogs': CatalogService.getCatalogs(),
        'behaviorHints': {
          'configurable': true,
          'configurationRequired': false,
        },
      };

      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(manifest));
      await request.response.close();
      return;
    }

    // ── 3. Catalogs Endpoint: /catalog/:type/:id.json or with extra params ──
    if (path.startsWith('/catalog/')) {
      final segments = request.uri.pathSegments; // ['catalog', 'movie', 'yt_indian.json'] or ['catalog', 'movie', 'yt_indian', 'genre=Bollywood.json']
      if (segments.length >= 3) {
        final type = segments[1];
        var catId = segments[2];
        if (catId.endsWith('.json')) {
          catId = catId.substring(0, catId.length - 5);
        }

        String? search;
        String? genre;
        int skip = 0;

        if (segments.length >= 4) {
          var extra = Uri.decodeComponent(segments[3]);
          if (extra.endsWith('.json')) {
            extra = extra.substring(0, extra.length - 5);
          }
          final parts = extra.split('&');
          for (final p in parts) {
            if (p.startsWith('search=')) search = p.substring(7);
            if (p.startsWith('genre=')) genre = p.substring(6);
            if (p.startsWith('skip=')) skip = int.tryParse(p.substring(5)) ?? 0;
          }
        }

        print('[Catalog] Query catId=$catId, type=$type, search=$search, genre=$genre, skip=$skip');
        final items = await CatalogService.instance.getCatalogItems(
          type: type,
          id: catId,
          search: search,
          genre: genre,
          skip: skip,
        );

        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({'metas': items}));
        await request.response.close();
        return;
      }
    }

    // ── 4. Metadata Detail Endpoint: /meta/:type/:id.json ──────────────────
    if (path.startsWith('/meta/')) {
      final segments = request.uri.pathSegments;
      if (segments.length >= 3) {
        final type = segments[1];
        var metaId = Uri.decodeComponent(segments[2]);
        if (metaId.endsWith('.json')) {
          metaId = metaId.substring(0, metaId.length - 5);
        }

        final meta = await CatalogService.instance.getMetaDetail(type, metaId);
        if (meta != null) {
          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode({'meta': meta}));
          await request.response.close();
          return;
        }
      }
    }

    // ── 5. Stremio/Nuvio Streams Endpoint: /stream/:type/:id.json ─────────
    if (path.startsWith('/stream/')) {
      final segments = request.uri.pathSegments; // ['stream', 'movie', 'tt1375666.json']
      if (segments.length >= 3) {
        final type = segments[1];
        var idWithExt = Uri.decodeComponent(segments[2]);
        if (idWithExt.endsWith('.json')) {
          idWithExt = idWithExt.substring(0, idWithExt.length - 5);
        }

        print('[Server] Received stream request: type=$type, id=$idWithExt');

        // Check custom video streams (YouTube, Archive.org, Dailymotion)
        if (idWithExt.startsWith('yt:') || idWithExt.startsWith('archive:') || idWithExt.startsWith('dm:')) {
          final customStreams = await CatalogService.instance.resolveCustomStreams(type, idWithExt);
          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode({'streams': customStreams}));
          await request.response.close();
          return;
        }

        // Standard IMDB / TMDB / Kitsu scraper pipeline
        MediaMetadata? meta = await MetadataService.resolve(type: type, rawId: idWithExt);
        if (meta == null) {
          meta = MediaMetadata(
            id: idWithExt,
            type: type,
            title: idWithExt.replaceAll(RegExp(r'\+|_'), ' '),
          );
        }

        final streams = await ScraperEngine.instance.scrapeAll(
          meta: meta,
          localBaseUrl: localBaseUrl,
        );

        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({
          'streams': streams.map((s) => s.toJson()).toList(),
        }));
        await request.response.close();
        return;
      }
    }


    // ── 4. Stream Proxy Endpoint: /proxy?url=... ──────────────────────────
    if (path == '/proxy') {
      await StreamProxy.handleRequest(request);
      return;
    }

    // ── 4b. Torbox Debrid Play Endpoint: /torbox/play?url=... ──────────────
    if (path == '/torbox/play') {
      final targetUrl = request.uri.queryParameters['url'];
      if (targetUrl == null || targetUrl.isEmpty) {
        request.response.statusCode = HttpStatus.badRequest;
        request.response.write('Missing url parameter');
        await request.response.close();
        return;
      }
      final apiKey = AddonConfig.instance.torboxApiKey.trim();
      final debridedUrl = await TorboxService.instance.debridLink(targetUrl, apiKey);
      if (debridedUrl != null && debridedUrl.isNotEmpty) {
        request.response.redirect(Uri.parse(debridedUrl), status: HttpStatus.found);
        return;
      }
      // Fallback: redirect to original URL
      request.response.redirect(Uri.parse(targetUrl), status: HttpStatus.found);
      return;
    }

    // ── 5. API: Toggle provider: POST /api/provider/:id ───────────────────
    if (path.startsWith('/api/provider/') && method == 'POST') {
      final providerId = path.replaceFirst('/api/provider/', '');
      final bodyStr = await utf8.decodeStream(request);
      final bodyJson = jsonDecode(bodyStr) as Map;
      final enabled = bodyJson['enabled'] == true;

      AddonConfig.instance.toggleProvider(providerId, enabled);
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({'success': true, 'id': providerId, 'enabled': enabled}));
      await request.response.close();
      return;
    }

    // ── 5b. API: Configure Torbox: POST /api/torbox/config ────────────────
    if (path == '/api/torbox/config' && method == 'POST') {
      final bodyStr = await utf8.decodeStream(request);
      final bodyJson = jsonDecode(bodyStr) as Map;
      final apiKey = bodyJson['apiKey']?.toString().trim() ?? '';
      AddonConfig.instance.torboxApiKey = apiKey;
      await AddonConfig.instance.save();
      final account = await TorboxService.instance.validateAccount(apiKey);
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({'success': true, 'account': account}));
      await request.response.close();
      return;
    }

    // ── 5c. API: Live Torbox Hosters: GET /api/torbox/hosters ─────────────
    if (path == '/api/torbox/hosters') {
      final apiKey = AddonConfig.instance.torboxApiKey.trim();
      final hosters = await TorboxService.instance.getHosters(apiKey: apiKey.isNotEmpty ? apiKey : null);
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({'success': true, 'hosters': hosters}));
      await request.response.close();
      return;
    }

    // ── 5d. API: Upload / Cache Link to Torbox: POST /api/torbox/upload ───
    if (path == '/api/torbox/upload' && method == 'POST') {
      final bodyStr = await utf8.decodeStream(request);
      final bodyJson = jsonDecode(bodyStr) as Map;
      final url = bodyJson['url']?.toString().trim() ?? '';
      final apiKey = AddonConfig.instance.torboxApiKey.trim();
      final uploadRes = await TorboxService.instance.uploadToTorbox(url, apiKey);
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(uploadRes));
      await request.response.close();
      return;
    }

    // ── 6. API: Upstream update pipeline: POST /api/pipeline/update ───────
    if (path == '/api/pipeline/update' && method == 'POST') {
      final result = await _runUpdatePipeline();
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(result));
      await request.response.close();
      return;
    }

    // ── 7. Health check ───────────────────────────────────────────────────
    if (path == '/health') {
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({'status': 'ok', 'port': AddonConfig.instance.port}));
      await request.response.close();
      return;
    }

    // ── 8. Nuvio Badges Configuration ─────────────────────────────────────
    if (path == '/badges.json') {
      request.response.headers.contentType = ContentType.json;
      final exeParent = File(Platform.resolvedExecutable).parent.path;
      final candidates = [
        File('data/badges.json'),
        File('$exeParent/data/badges.json'),
        File('${Directory.current.path}/data/badges.json'),
      ];
      File? found;
      for (final f in candidates) {
        if (f.existsSync()) {
          found = f;
          break;
        }
      }
      if (found != null) {
        request.response.write(await found.readAsString());
      } else {
        request.response.write(jsonEncode({'status': 'ok', 'badges': 'configured'}));
      }
      await request.response.close();
      return;
    }

    // Fallback: 404
    request.response.statusCode = HttpStatus.notFound;
    request.response.write('Not found: $path');
    await request.response.close();
  } catch (e, stack) {
    print('[Server] Internal error handling $path: $e\n$stack');
    try {
      request.response.statusCode = HttpStatus.internalServerError;
      request.response.write('Internal error: $e');
      await request.response.close();
    } catch (_) {
      // Response already partially sent – nothing we can do.
    }
  }
}

// ── Update Pipeline ──────────────────────────────────────────────────────────

Future<Map<String, dynamic>> _runUpdatePipeline() async {
  try {
    String gitOutput = 'Up to date';
    if (Directory('upstream/PlayTorrioV3/.git').existsSync()) {
      print('[Pipeline] Running upstream git pull in upstream/PlayTorrioV3...');
      final gitRes = await Process.run(
        'git',
        ['pull', 'origin', 'main'],
        workingDirectory: 'upstream/PlayTorrioV3',
      );
      gitOutput = '${gitRes.stdout}\n${gitRes.stderr}'.trim();
      print('[Pipeline] Git pull output:\n$gitOutput');
    }

    print('[Pipeline] Regenerating scraper registry...');

    // Platform.resolvedExecutable points to the compiled .exe when running AOT.
    // We can't use it to run Dart source files – find dart.exe explicitly.
    final dartExe = await _findDartExe();
    late ProcessResult regRes;
    if (dartExe != null) {
      regRes = await Process.run(dartExe, ['run', 'tool/generate_registry.dart']);
    } else {
      regRes = ProcessResult(-1, 1, '', 'dart executable not found – skipping registry regen');
    }
    final regOutput = '${regRes.stdout}\n${regRes.stderr}'.trim();
    print('[Pipeline] Registry output:\n$regOutput');

    // Reload scraper instances already in memory.
    // NOTE: Truly new scraper CLASSES added upstream require a server restart
    // (or recompile when using the .exe). Existing scrapers are refreshed.
    ScraperEngine.instance.reloadScrapers();

    final isUpToDate = gitOutput.contains('Already up to date');
    return {
      'success': true,
      'message': isUpToDate
          ? 'Already up to date with PlayTorrio! Scrapers refreshed.'
          : 'Updated from PlayTorrio! Restart the server to load any brand-new scraper classes.',
      'output': '$gitOutput\n$regOutput',
    };
  } catch (e) {
    return {
      'success': false,
      'message': 'Update failed: $e',
    };
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────

/// Locks the process CWD to the project root so all relative paths resolve
/// correctly regardless of how the binary was launched.
void _ensureProjectRoot() {
  try {
    if (Platform.script.scheme == 'file') {
      // dart run bin/server.dart → script is …/bin/server.dart → parent.parent is project root
      final scriptFile = File(Platform.script.toFilePath());
      Directory.current = scriptFile.parent.parent;
    } else {
      // Compiled AOT exe: the exe should live in the project root.
      Directory.current = File(Platform.resolvedExecutable).parent;
    }
  } catch (e) {
    // Non-fatal: best-effort. Relative paths will resolve from wherever the
    // process was started.
    print('[Server] Warning: could not set CWD to project root: $e');
  }
}

/// Finds the dart executable: bundled SDK, sibling dir, CWD, then system PATH.
/// Works on Windows (dart.exe), Linux, macOS, and Android (Termux).
Future<String?> _findDartExe() async {
  final dartBin = Platform.isWindows ? 'dart.exe' : 'dart';
  final exeDir = File(Platform.resolvedExecutable).parent;

  final candidates = [
    File('${exeDir.path}/../dart-sdk/bin/$dartBin'), // bundled next to exe
    File('${exeDir.path}/$dartBin'),                 // same dir as exe
    File('dart-sdk/bin/$dartBin'),                   // project-root-relative
  ];
  for (final f in candidates) {
    if (await f.exists()) return f.path;
  }
  try {
    final res = await Process.run(dartBin, ['--version']);
    if (res.exitCode == 0) return dartBin;
  } catch (_) {}
  return null;
}

/// Returns the best LAN IPv4 address for this machine.
Future<String> _getLocalIp() async {
  try {
    final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
    // 1. High priority: standard home LAN private subnets (192.168.0.x / 192.168.1.x)
    for (final iface in interfaces) {
      for (final addr in iface.addresses) {
        if (!addr.isLoopback &&
            addr.address.startsWith('192.168.') &&
            !addr.address.startsWith('192.168.56.')) {
          return addr.address;
        }
      }
    }
    // 2. Medium priority: 10.x.x.x
    for (final iface in interfaces) {
      for (final addr in iface.addresses) {
        if (!addr.isLoopback && addr.address.startsWith('10.')) {
          return addr.address;
        }
      }
    }
    // 3. Fallback: other non-virtual adapters (exclude link-local, WSL, VPNs)
    for (final iface in interfaces) {
      for (final addr in iface.addresses) {
        if (!addr.isLoopback &&
            !addr.address.startsWith('169.254.') &&
            !addr.address.startsWith('172.') &&
            !addr.address.startsWith('192.168.56.') &&
            !addr.address.startsWith('45.')) {
          return addr.address;
        }
      }
    }
  } catch (_) {}
  return '127.0.0.1';
}


