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
  final List<Map<String, dynamic>>? subtitles;

  ScrapedStream({
    required this.name,
    required this.title,
    required this.url,
    this.behaviorHints,
    required this.provider,
    this.quality,
    this.subtitles,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'title': title,
        'url': url,
        if (behaviorHints != null) 'behaviorHints': behaviorHints,
        if (subtitles != null && subtitles!.isNotEmpty) 'subtitles': subtitles,
      };
}

class ScraperEngine {
  static final ScraperEngine instance = ScraperEngine._();
  List<StreamScraper> _allScrapers = [];

  /// In-flight deduplication cache: if two Nuvio clients request the same
  /// content simultaneously we reuse the same scrape Future instead of
  /// launching 46×2 parallel requests.
  final Map<String, Future<List<ScrapedStream>>> _inFlight = {};

  /// Circuit Breaker: maps providerId to consecutive failure count
  final Map<String, int> _consecutiveFailures = {};
  /// Circuit Breaker: maps providerId to expiration of tripped state
  final Map<String, DateTime> _trippedUntil = {};

  ScraperEngine._() {
    _initScrapers();
  }

  void _initScrapers() {
    _allScrapers = ScraperRegistry.getAllScrapers();
    print('[ScraperEngine] Registered ${_allScrapers.length} PlayTorrio HTTP scrapers.');
  }

  void reloadScrapers() {
    _inFlight.clear(); // Invalidate any in-flight results after a reload
    _consecutiveFailures.clear();
    _trippedUntil.clear();
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
    final allActive = activeScrapers;
    final now = DateTime.now();
    final scrapers = allActive.where((s) {
      final tripExp = _trippedUntil[s.providerId];
      if (tripExp != null && tripExp.isAfter(now)) {
        return false;
      }
      return true;
    }).toList();

    final cfg = AddonConfig.instance;
    final timeout = Duration(seconds: cfg.timeoutSeconds);

    print('[ScraperEngine] Scraping "${meta.title}" (${meta.year ?? 'N/A'}, ${meta.type}) '
        'across ${scrapers.length} active scrapers (${allActive.length - scrapers.length} tripped, timeout: ${cfg.timeoutSeconds}s)...');

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
        _consecutiveFailures[scraper.providerId] = 0;
        _trippedUntil.remove(scraper.providerId);
      } catch (_) {
        final fails = (_consecutiveFailures[scraper.providerId] ?? 0) + 1;
        _consecutiveFailures[scraper.providerId] = fails;
        if (fails >= 3) {
          _trippedUntil[scraper.providerId] = DateTime.now().add(const Duration(minutes: 10));
          print('[CircuitBreaker] Scraper ${scraper.providerId} tripped for 10m (3 consecutive failures).');
        }
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
      final isSupportedHoster = torboxKey.isNotEmpty && TorboxService.instance.isSupportedHoster(rawUrl);
      bool isTorboxCached = false;
      if (isSupportedHoster) {
        try {
          isTorboxCached = await TorboxService.instance.checkCached(rawUrl, torboxKey);
        } catch (_) {}
      }

      // ── Direct (Uncached) Stream Configuration ────────────────────────
      String directStreamUrl = rawUrl;
      bool isDirectProxied = false;
      if (cfg.enableProxyForHeaders && headers.isNotEmpty) {
        final headersJson = jsonEncode(headers);
        directStreamUrl = '$localBaseUrl/proxy?url=${Uri.encodeComponent(rawUrl)}'
            '&headers=${Uri.encodeComponent(headersJson)}';
        isDirectProxied = true;
      }

      final directBehaviorHints = <String, dynamic>{
        'notWebReady': !isDirectProxied && headers.isNotEmpty,
      };
      if (headers.isNotEmpty && !isDirectProxied) {
        directBehaviorHints['proxyHeaders'] = {'request': headers};
      }

      String rawTitle = src.title ?? src.name ?? meta.title;
      rawTitle = rawTitle
          .replaceAll(RegExp(r'PlayTorrio(HTTP)?', caseSensitive: false), 'MegaScraper')
          .replaceAll(RegExp(r'\b(saket|sakinator)\b', caseSensitive: false), '')
          .trim();

      final directEnriched = BadgeService.enrichStream(
        rawTitle: rawTitle,
        mediaTitle: meta.title,
        year: meta.year,
        season: meta.season,
        episode: meta.episode,
        quality: q,
        codec: src.codec,
        audioBadge: badge,
        fileSize: src.fileSize,
        providerName: isSupportedHoster ? '$providerName [Direct]' : providerName,
        isCached: false,
        isHls: isHls,
        isProxied: isDirectProxied,
      );

      final qLabel = q.isNotEmpty ? q : (isHls ? 'HLS' : 'HD');
      final subList = src.subtitles?.map((s) => {
        'id': s.language,
        'url': s.downloadUrl,
        'lang': s.language,
      }).toList();

      if (isTorboxCached) {
        // ── 1. Link is ALREADY TorBox cached: show 2 links (Cached + Uncached) ──
        final torboxPlayUrl = '$localBaseUrl/torbox/play?url=${Uri.encodeComponent(rawUrl)}';
        final cachedEnriched = BadgeService.enrichStream(
          rawTitle: rawTitle,
          mediaTitle: meta.title,
          year: meta.year,
          season: meta.season,
          episode: meta.episode,
          quality: q,
          codec: src.codec,
          audioBadge: badge,
          fileSize: src.fileSize,
          providerName: '$providerName [TorBox Cached]',
          isCached: true,
          isHls: false,
          isProxied: false,
        );

        // 1a. Cached Link (instant TorBox CDN stream)
        final cachedBadge = cachedEnriched['badgeHeader'] ?? qLabel;
        finalStreams.add(ScrapedStream(
          name: '⚡ TorBox [Cached]\n$cachedBadge',
          title: '${cachedEnriched['title']}\n⚡ Cached on TorBox CDN • Instant High-Speed Playback',
          url: torboxPlayUrl,
          behaviorHints: const {'notWebReady': false},
          provider: '$providerName (TorBox Cached)',
          quality: q,
          subtitles: subList,
        ));

        // 1b. Uncached Link (original direct hoster link)
        finalStreams.add(ScrapedStream(
          name: directEnriched['name']!,
          title: '${directEnriched['title']}\n🌐 Original Direct Hoster Link (Uncached)',
          url: directStreamUrl,
          behaviorHints: directBehaviorHints,
          provider: providerName,
          quality: q,
          subtitles: subList,
        ));
      } else if (isSupportedHoster) {
        // ── 2. Link is NOT cached but IS cachable: show 2 links (Click to Cache + Uncached) ──
        final headersParam = headers.isNotEmpty ? '&headers=${Uri.encodeComponent(jsonEncode(headers))}' : '';
        final cachePlayUrl = '$localBaseUrl/torbox/play?url=${Uri.encodeComponent(rawUrl)}$headersParam';

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

        // 2a. Click to Cache Link (initiates cloud caching on TorBox)
        final cacheBadge = cacheEnriched['badgeHeader'] ?? qLabel;
        finalStreams.add(ScrapedStream(
          name: '⚡ TorBox [Cache]\n$cacheBadge',
          title: '${cacheEnriched['title']}\n⚡ Click via Nuvio to cache to TorBox & start playback',
          url: cachePlayUrl,
          behaviorHints: const {'notWebReady': false},
          provider: '$providerName (TorBox Cache)',
          quality: q,
          subtitles: subList,
        ));

        // 2b. Uncached Link (original direct stream link)
        finalStreams.add(ScrapedStream(
          name: directEnriched['name']!,
          title: '${directEnriched['title']}\n🌐 Original Direct Hoster Link (Uncached)',
          url: directStreamUrl,
          behaviorHints: directBehaviorHints,
          provider: providerName,
          quality: q,
          subtitles: subList,
        ));
      } else {
        // ── 3. Standard Non-Hoster / Direct Stream (1 link) ──
        finalStreams.add(ScrapedStream(
          name: directEnriched['name']!,
          title: directEnriched['title']!,
          url: directStreamUrl,
          behaviorHints: directBehaviorHints,
          provider: providerName,
          quality: q,
          subtitles: subList,
        ));
      }
    }

    // Sort: Resolution first (4K > 1080p > 720p > 480p), then Cached > Cache > Direct
    finalStreams.sort((a, b) => _streamRank(b).compareTo(_streamRank(a)));

    print('[ScraperEngine] Found ${finalStreams.length} stream(s) for "${meta.title}".');
    return finalStreams;
  }

  static int _streamRank(ScrapedStream s) {
    int rank = _qualityRank(s.quality) * 10;
    if (s.name.contains('[Cached]')) {
      rank += 3;
    } else if (s.name.contains('[Cache]')) {
      rank += 2;
    } else {
      rank += 1;
    }
    return rank;
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
