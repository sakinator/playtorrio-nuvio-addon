import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../stream_scraper.dart';
import '../../../models/stream/stream_model.dart';

/// HiAnime (Zoro / Aniwatch) Stream Scraper for PlayTorrioHTTP.
/// Fetches direct HLS (m3u8) streams for Anime (Sub & Dub, zero torrents).
class HiAnimeScraper extends StreamScraper {
  @override
  String get name => 'PlayTorrioHTTP';

  @override
  String get providerId => 'hianime';

  @override
  String get providerName => 'HiAnime';

  static const List<String> _apiBases = [
    'https://api.amvstr.me/api/v2',
    'https://api-consumet.org/anime/zoro',
  ];

  static const _headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    'Accept': 'application/json',
  };

  @override
  Stream<StreamSource> scrapeStream({
    required String type,
    required String title,
    int? year,
    int? season,
    int? episode,
    String? imdbId,
  }) async* {
    final epNum = episode ?? 1;
    final cleanTitle = title.replaceAll(RegExp(r'[^\w\s]'), ' ').trim();

    for (final base in _apiBases) {
      try {
        final searchUrl = Uri.parse('$base/search?q=${Uri.encodeComponent(cleanTitle)}');
        final res = await http.get(searchUrl, headers: _headers).timeout(const Duration(seconds: 4));
        if (res.statusCode != 200) continue;

        final data = jsonDecode(res.body);
        final results = (data is Map && data['results'] is List)
            ? data['results'] as List
            : (data is List)
                ? data
                : [];

        if (results.isEmpty) continue;
        final first = results.first;
        final animeId = first['id']?.toString();
        if (animeId == null || animeId.isEmpty) continue;

        // Fetch episode stream
        final streamUrl = Uri.parse('$base/watch?episodeId=${Uri.encodeComponent(animeId)}\$episode\$$epNum');
        final streamRes = await http.get(streamUrl, headers: _headers).timeout(const Duration(seconds: 4));
        if (streamRes.statusCode != 200) continue;

        final streamData = jsonDecode(streamRes.body);
        final sources = streamData['sources'] as List?;
        if (sources != null && sources.isNotEmpty) {
          for (final s in sources) {
            final file = s['url']?.toString();
            final isM3u8 = s['isM3U8'] == true || (file != null && file.contains('.m3u8'));
            final quality = s['quality']?.toString() ?? 'Auto';

            if (file != null && file.isNotEmpty) {
              yield StreamSource(
                name: 'HiAnime ($quality)',
                title: '⚡ ${isM3u8 ? "HLS Master • " : ""}$quality Sub/Dub Anime Stream (Non-Torrent)',
                url: file,
                addonName: 'PlayTorrioHTTP',
                providerId: providerId,
                providerName: providerName,
                behaviorHints: {
                  'notWebReady': false,
                },
              );
            }
          }
        }
        break;
      } catch (_) {}
    }
  }
}
