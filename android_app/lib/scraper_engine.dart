import 'dart:async';
import 'dart:convert';
import 'scraper_registry.dart';
import 'config.dart';
import 'metadata_service.dart';
import 'upstream/models/stream/stream_model.dart';
import 'upstream/services/scraper/stream_scraper.dart';
import 'badge_service.dart';
import 'torbox_service.dart';

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

      String providerName = src.providerName ?? src.name ?? 'MegaScraper';
      if (providerName.toLowerCase().contains('playtorrio')) {
        providerName = providerName.replaceAll(RegExp(r'PlayTorrio(HTTP)?', caseSensitive: false), 'MegaScraper').trim();
        if (providerName.isEmpty) providerName = 'MegaScraper';
      }
      final q = src.quality ?? '';
      final isHls = rawUrl.contains('.m3u8');
      final badge = src.getAudioBadge(mediaTitle: meta.title) ?? '';
      final headers = src.headers ?? {};

      // ── URL & proxy decision ───────────────────────────────────────────
      // ── Torbox Caching & Debrid Integration ───────────────────────────
      final torboxKey = cfg.torboxApiKey.trim();
      bool isTorboxCached = false;
      if (torboxKey.isNotEmpty && TorboxService.instance.isSupportedHoster(rawUrl)) {
        try {
          isTorboxCached = await TorboxService.instance.checkCached(rawUrl, torboxKey);
        } catch (_) {}
      }

      // ── URL & proxy / Torbox decision ───────────────────────────────────
      String streamUrl = rawUrl;
      bool isProxied = false;

      if (isTorboxCached && torboxKey.isNotEmpty) {
        // Route through local Torbox streaming resolver
        streamUrl = '$localBaseUrl/torbox/play?url=${Uri.encodeComponent(rawUrl)}';
      } else if (cfg.enableProxyForHeaders && headers.isNotEmpty) {
        final headersJson = jsonEncode(headers);
        streamUrl = '$localBaseUrl/proxy?url=${Uri.encodeComponent(rawUrl)}'
            '&headers=${Uri.encodeComponent(headersJson)}';
        isProxied = true;
      }

      // ── behaviorHints ─────────────────────────────────────────────────
      final behaviorHints = <String, dynamic>{
        'notWebReady': !isProxied && !isTorboxCached && headers.isNotEmpty,
      };

      if (headers.isNotEmpty && !isProxied && !isTorboxCached) {
        behaviorHints['proxyHeaders'] = {'request': headers};
      }

      // ── Enrich Stream Links Using BadgeService JSON Filters ───────────
      String rawTitle = src.title ?? src.name ?? meta.title;
      rawTitle = rawTitle
          .replaceAll(RegExp(r'PlayTorrio(HTTP)?', caseSensitive: false), 'MegaScraper')
          .replaceAll(RegExp(r'\b(saket|sakinator)\b', caseSensitive: false), '')
          .trim();
      final enriched = BadgeService.enrichStream(
        rawTitle: rawTitle,
        mediaTitle: meta.title,
        year: meta.year,
        season: meta.season,
        episode: meta.episode,
        quality: q,
        codec: src.codec,
        audioBadge: badge,
        fileSize: src.fileSize,
        providerName: providerName,
        isCached: isTorboxCached,
        isHls: isHls,
        isProxied: isProxied,
      );

      finalStreams.add(ScrapedStream(
        name: enriched['name']!,
        title: enriched['title']!,
        url: streamUrl,
        behaviorHints: behaviorHints,
        provider: providerName,
        quality: q,
      ));

      // ── If not cached but supported by TorBox, provide 1-click "Cache via Nuvio" stream ──
      if (!isTorboxCached && torboxKey.isNotEmpty && TorboxService.instance.isSupportedHoster(rawUrl)) {
        final headersParam = headers.isNotEmpty ? '&headers=${Uri.encodeComponent(jsonEncode(headers))}' : '';
        final cachePlayUrl = '$localBaseUrl/torbox/play?url=${Uri.encodeComponent(rawUrl)}$headersParam';
        final qLabel = q.isNotEmpty ? q : 'HD';

        final cacheEnriched = BadgeService.enrichStream(
          rawTitle: rawTitle,
          mediaTitle: meta.title,
          year: meta.year,
          season: meta.season,
          episode: meta.episode,
          quality: q,
          codec: src.codec,
          audioBadge: badge,
          fileSize: src.fileSize,
          providerName: '$providerName [TorBox Cache]',
          isCached: false,
          isHls: isHls,
          isProxied: false,
        );

        finalStreams.add(ScrapedStream(
          name: 'TorBox Cache\n$qLabel',
          title: '${cacheEnriched['title']}\n⚡ Click via Nuvio to cache to TorBox & start playback',
          url: cachePlayUrl,
          behaviorHints: const {'notWebReady': false},
          provider: '$providerName (TorBox)',
          quality: q,
        ));
      }
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
