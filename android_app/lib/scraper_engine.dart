import 'dart:async';
import 'dart:convert';
import 'scraper_registry.dart';
import 'config.dart';
import 'metadata_service.dart';
import 'upstream/models/stream/stream_model.dart';
import 'upstream/services/scraper/stream_scraper.dart';
import 'badge_service.dart';

class ScrapedStream {
  final String name;
  final String title;
  final String url;
  final Map<String, dynamic>? behaviorHints;
  final String provider;
  final String? quality;

  ScrapedStream({
    required this.name,
    required this.title,
    required this.url,
    this.behaviorHints,
    required this.provider,
    this.quality,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'title': title,
        'url': url,
        if (behaviorHints != null) 'behaviorHints': behaviorHints,
      };
}

class ScraperEngine {
  static final ScraperEngine instance = ScraperEngine._();
  List<StreamScraper> _allScrapers = [];

  /// In-flight deduplication cache: if two Nuvio clients request the same
  /// content simultaneously we reuse the same scrape Future instead of
  /// launching 46×2 parallel requests.
  final Map<String, Future<List<ScrapedStream>>> _inFlight = {};

  ScraperEngine._() {
    _initScrapers();
  }

  void _initScrapers() {
    _allScrapers = ScraperRegistry.getAllScrapers();
    print('[ScraperEngine] Registered ${_allScrapers.length} PlayTorrio HTTP scrapers.');
  }

  void reloadScrapers() {
    _inFlight.clear(); // Invalidate any in-flight results after a reload
    _initScrapers();
  }

  List<StreamScraper> get activeScrapers {
    final cfg = AddonConfig.instance;
    return _allScrapers.where((s) => cfg.isProviderEnabled(s.providerId)).toList();
  }

  List<Map<String, dynamic>> getProviderList() {
    final cfg = AddonConfig.instance;
    return _allScrapers.map((s) {
      return {
        'id': s.providerId,
        'name': s.providerName,
        'enabled': cfg.isProviderEnabled(s.providerId),
      };
    }).toList();
  }

  Future<List<ScrapedStream>> scrapeAll({
    required MediaMetadata meta,
    required String localBaseUrl,
  }) {
    // Deduplicate concurrent requests for the same content.
    // Key on type+id – localBaseUrl is always the same server LAN address.
    final key = '${meta.type}|${meta.id}';
    if (_inFlight.containsKey(key)) {
      print('[ScraperEngine] Deduplicating concurrent request for "$key".');
      return _inFlight[key]!;
    }
    final future = _doScrapeAll(meta: meta, localBaseUrl: localBaseUrl);
    _inFlight[key] = future;
    future.whenComplete(() => _inFlight.remove(key));
    return future;
  }

  Future<List<ScrapedStream>> _doScrapeAll({
    required MediaMetadata meta,
    required String localBaseUrl,
  }) async {
    final scrapers = activeScrapers;
    final cfg = AddonConfig.instance;
    final timeout = Duration(seconds: cfg.timeoutSeconds);

    print('[ScraperEngine] Scraping "${meta.title}" (${meta.year ?? 'N/A'}, ${meta.type}) '
        'across ${scrapers.length} active scrapers (timeout: ${cfg.timeoutSeconds}s)...');

    // Each scraper collects into its own list to avoid concurrent-write races.
    final futures = scrapers.map((scraper) async {
      final localResults = <StreamSource>[];
      try {
        final stream = scraper.scrapeStream(
          type: meta.type,
          title: meta.title,
          year: meta.year,
          season: meta.season,
          episode: meta.episode,
          imdbId: meta.imdbId,
        );
        await for (final item in stream.timeout(timeout)) {
          localResults.add(item);
        }
      } catch (_) {
        // Individual scraper error / timeout – silently swallowed.
      }
      return localResults;
    });

    final perScraperResults = await Future.wait(futures);
    // Merge sequentially – no concurrent list mutation.
    final rawResults = <StreamSource>[
      for (final list in perScraperResults) ...list,
    ];
    final seenUrls = <String>{};
    final finalStreams = <ScrapedStream>[];

    for (final src in rawResults) {
      final rawUrl = src.url ?? src.externalUrl;
      if (rawUrl == null || rawUrl.isEmpty || !rawUrl.startsWith('http')) continue;
      if (seenUrls.contains(rawUrl)) continue;
      seenUrls.add(rawUrl);

      final providerName = src.providerName ?? src.name ?? 'PlayTorrio';
      final q = src.quality ?? '';
      final isHls = rawUrl.contains('.m3u8');
      final badge = src.getAudioBadge(mediaTitle: meta.title) ?? '';
      final headers = src.headers ?? {};

      // ── URL & proxy decision ───────────────────────────────────────────
      // If the stream requires custom headers (Referer / Origin / etc.) and
      // proxy is enabled, route through our local proxy so any player can play
      // it without needing to set headers itself.
      String streamUrl = rawUrl;
      bool isProxied = false;
      if (cfg.enableProxyForHeaders && headers.isNotEmpty) {
        final headersJson = jsonEncode(headers);
        streamUrl = '$localBaseUrl/proxy?url=${Uri.encodeComponent(rawUrl)}'
            '&headers=${Uri.encodeComponent(headersJson)}';
        isProxied = true;
      }

      // ── behaviorHints ─────────────────────────────────────────────────
      // notWebReady: true  → stream can't be played directly in a browser tab
      //                       (most HLS streams with auth/referer headers)
      // notWebReady: false → browser can play it (proxy handles headers, or
      //                       no headers needed at all)
      final behaviorHints = <String, dynamic>{
        'notWebReady': !isProxied && headers.isNotEmpty,
      };

      // Also advertise proxyHeaders so Nuvio native clients (Android/iOS) can
      // attach them directly without going through our proxy.
      if (headers.isNotEmpty && !isProxied) {
        behaviorHints['proxyHeaders'] = {'request': headers};
      }

      // ── Display strings (No mention of saket, standard scene filename & badges) ──
      final titleLines = <String>[];
      final originalTitle = (src.title ?? '').trim();

      // 1. Generate standard scene filename (so Nuvio's regex-based badges trigger)
      final sceneFilename = BadgeService.formatSceneFilename(
        title: meta.title,
        year: meta.year,
        season: meta.season,
        episode: meta.episode,
        quality: q,
        codec: src.codec,
        audio: badge.isNotEmpty ? badge : null,
        originalFilename: (originalTitle.contains('.') && !originalTitle.contains('Direct Cloud') && !originalTitle.contains('\n'))
            ? originalTitle
            : null,
      );
      titleLines.add(sceneFilename);

      // 2. Extract badges & technical details
      final matchedBadges = BadgeService.getBadges('$sceneFilename $originalTitle $q $badge ${src.codec ?? ""}');
      final badgeStr = matchedBadges.isNotEmpty
          ? matchedBadges.map((b) => '[$b]').join(' ')
          : (q.isNotEmpty ? '[$q]' : '');

      final details = <String>[];
      if (badgeStr.isNotEmpty) details.add(badgeStr);
      if (src.fileSize != null && src.fileSize!.isNotEmpty) details.add('💾 ${src.fileSize}');
      if (isHls) {
        details.add('⚡ HLS');
      } else {
        details.add('⚡ Direct');
      }
      if (isProxied) details.add('🔀 Proxied');

      if (details.isNotEmpty) titleLines.add(details.join(' • '));

      // 3. Provider / Source Name (Never mentions saket)
      titleLines.add('🌐 Source: $providerName');

      final displayTitle = titleLines.join('\n');
      final displayName = q.isNotEmpty
          ? '$providerName\n$q'
          : providerName;

      finalStreams.add(ScrapedStream(
        name: displayName,
        title: displayTitle,
        url: streamUrl,
        behaviorHints: behaviorHints,
        provider: providerName,
        quality: q,
      ));
    }

    // Sort: 4K > 1080p > 720p > 480p > unknown
    finalStreams.sort((a, b) => _qualityRank(b.quality).compareTo(_qualityRank(a.quality)));

    print('[ScraperEngine] Found ${finalStreams.length} stream(s) for "${meta.title}".');
    return finalStreams;
  }

  static int _qualityRank(String? q) {
    switch (q?.toUpperCase()) {
      case '4K':
      case '2160P':
        return 4;
      case '1080P':
        return 3;
      case '720P':
        return 2;
      case '480P':
        return 1;
      default:
        return 0;
    }
  }
}
