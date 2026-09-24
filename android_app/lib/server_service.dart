import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'config.dart';
import 'metadata_service.dart';
import 'proxy.dart';
import 'scraper_engine.dart';
import 'web_ui.dart';
import 'catalog_service.dart';

class ServerService {
  static final ServerService instance = ServerService._();

  ServerService._();

  HttpServer? _server;
  final ValueNotifier<bool> isRunning = ValueNotifier<bool>(false);
  final ValueNotifier<String> localIp = ValueNotifier<String>('127.0.0.1');
  final ValueNotifier<int> requestCount = ValueNotifier<int>(0);
  final ValueNotifier<String> statusMessage = ValueNotifier<String>('Stopped');
  final ValueNotifier<List<String>> logs = ValueNotifier<List<String>>([]);

  void _addLog(String msg) {
    final time = DateTime.now().toIso8601String().substring(11, 19);
    final entry = '[$time] $msg';
    final current = List<String>.from(logs.value);
    if (current.length > 50) current.removeAt(0);
    current.add(entry);
    logs.value = current;
    debugPrint(entry);
  }

  Future<void> init() async {
    await AddonConfig.instance.load();
    await updateLanIp();
    _initForegroundTask();
  }

  void _initForegroundTask() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'playtorrio_server_channel',
        channelName: 'PlayTorrio Server Service',
        channelDescription: 'Keeps PlayTorrio Addon HTTP Server active for Nuvio.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        iconData: const NotificationIconData(
          resType: ResourceType.mipmap,
          resPrefix: ResourcePrefix.ic,
          name: 'launcher',
        ),
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: const ForegroundTaskOptions(
        interval: 5000,
        isOnceEvent: false,
        autoRunOnBoot: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  Future<String> updateLanIp() async {
    try {
      final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback &&
              addr.address.startsWith('192.168.') &&
              !addr.address.startsWith('192.168.56.')) {
            localIp.value = addr.address;
            return addr.address;
          }
        }
      }
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback && addr.address.startsWith('10.')) {
            localIp.value = addr.address;
            return addr.address;
          }
        }
      }
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback &&
              !addr.address.startsWith('169.254.') &&
              !addr.address.startsWith('172.') &&
              !addr.address.startsWith('192.168.56.') &&
              !addr.address.startsWith('45.')) {
            localIp.value = addr.address;
            return addr.address;
          }
        }
      }
    } catch (e) {
      _addLog('IP detection error: $e');
    }
    return localIp.value;
  }

  Future<bool> startServer() async {
    if (isRunning.value) return true;

    try {
      final cfg = AddonConfig.instance;
      await updateLanIp();

      _server = await HttpServer.bind(InternetAddress.anyIPv4, cfg.port);
      isRunning.value = true;
      statusMessage.value = 'Running on port ${cfg.port}';
      _addLog('Server started on http://${localIp.value}:${cfg.port}');

      // Start foreground service to keep CPU awake on Android TV / Mobile
      try {
        if (!await FlutterForegroundTask.isRunningService) {
          await FlutterForegroundTask.startService(
            notificationTitle: 'PlayTorrio Server Active',
            notificationText: 'Serving Nuvio streams on port ${cfg.port}',
          );
        }
      } catch (e) {
        _addLog('Foreground service note: $e');
      }

      _listenToRequests(_server!, cfg.port);
      return true;
    } catch (e) {
      statusMessage.value = 'Error: $e';
      _addLog('Failed to start server: $e');
      isRunning.value = false;
      return false;
    }
  }

  Future<void> stopServer() async {
    if (!isRunning.value) return;
    try {
      await _server?.close(force: true);
      _server = null;
      isRunning.value = false;
      statusMessage.value = 'Stopped';
      _addLog('Server stopped');

      try {
        if (await FlutterForegroundTask.isRunningService) {
          await FlutterForegroundTask.stopService();
        }
      } catch (_) {}
    } catch (e) {
      _addLog('Error stopping server: $e');
    }
  }

  void _listenToRequests(HttpServer server, int port) async {
    await for (final request in server) {
      requestCount.value = requestCount.value + 1;
      _handleRequest(request, port);
    }
  }

  Future<void> _handleRequest(HttpRequest request, int port) async {
    final path = request.uri.path;
    final method = request.method.toUpperCase();

    // CORS
    request.response.headers.set('Access-Control-Allow-Origin', '*');
    request.response.headers.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS, HEAD');
    request.response.headers.set('Access-Control-Allow-Headers', '*');

    if (method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.ok;
      await request.response.close();
      return;
    }

    final lan = localIp.value;
    final hostHeader = request.headers.host;
    final localBaseUrl = (hostHeader != null && hostHeader.isNotEmpty)
        ? 'http://$hostHeader'
        : 'http://$lan:$port';

    try {
      // 1. Web dashboard
      if (path == '/' || path == '/configure') {
        request.response.headers.contentType = ContentType.html;
        request.response.write(WebUI.render(localIp: lan, port: port));
        await request.response.close();
        return;
      }

      // 2. Stremio/Nuvio Addon Manifest
      if (path == '/manifest.json') {
        final manifest = {
          'id': 'org.playtorrio.http',
          'version': '1.2.0',
          'name': 'PlayTorrio HTTP Streams & Cinema',
          'description': '49 Direct Cloud Scrapers + YouTube, Archive.org & Dailymotion Indian & Global Catalogs (100% Non-Torrent)',
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

      // 3. Catalogs Endpoint: /catalog/:type/:id.json
      if (path.startsWith('/catalog/')) {
        final segments = request.uri.pathSegments;
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

          _addLog('Catalog: $catId ($genre)');
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

      // 4. Metadata Detail Endpoint: /meta/:type/:id.json
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

      // 5. Streams endpoint: /stream/:type/:id.json
      if (path.startsWith('/stream/')) {
        final segments = request.uri.pathSegments;
        if (segments.length >= 3) {
          final type = segments[1];
          var idWithExt = Uri.decodeComponent(segments[2]);
          if (idWithExt.endsWith('.json')) {
            idWithExt = idWithExt.substring(0, idWithExt.length - 5);
          }

          _addLog('Stream request: $type/$idWithExt');

          // Custom video streams (YouTube, Archive.org, Dailymotion)
          if (idWithExt.startsWith('yt:') || idWithExt.startsWith('archive:') || idWithExt.startsWith('dm:')) {
            final customStreams = await CatalogService.instance.resolveCustomStreams(type, idWithExt);
            request.response.headers.contentType = ContentType.json;
            request.response.write(jsonEncode({'streams': customStreams}));
            await request.response.close();
            return;
          }

          MediaMetadata? meta = await MetadataService.resolve(type: type, rawId: idWithExt);
          meta ??= MediaMetadata(
            id: idWithExt,
            type: type,
            title: idWithExt.replaceAll(RegExp(r'\+|_'), ' '),
          );

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


      // 4. Stream Proxy: /proxy?url=...
      if (path == '/proxy') {
        await StreamProxy.handleRequest(request);
        return;
      }

      // 5. Provider toggle: POST /api/provider/:id
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

      // 6. Health
      if (path == '/health') {
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({'status': 'ok', 'port': port}));
        await request.response.close();
        return;
      }

      request.response.statusCode = HttpStatus.notFound;
      request.response.write('Not found: $path');
      await request.response.close();
    } catch (e) {
      _addLog('Server error on $path: $e');
      try {
        request.response.statusCode = HttpStatus.internalServerError;
        request.response.write('Error: $e');
        await request.response.close();
      } catch (_) {}
    }
  }
}
