import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../stream_scraper.dart';
import '../../../models/stream/stream_model.dart';

/// AnimePahe Non-Torrent Stream Scraper for PlayTorrio / Saket.
/// Extracts high-efficiency, lightweight 720p/1080p Kwik player
/// streams for Sub & Dub anime.
class AnimePaheScraper extends StreamScraper {
  @override
  String get name => 'AnimePahe';

  @override
  String get providerId => 'animepahe';

  @override
  String get providerName => 'AnimePahe';

  static const List<String> _apiBases = [
    'https://api-consumet.org/anime/animepahe',
    'https://consumet-api.up.railway.app/anime/animepahe',
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
        final searchUrl = Uri.parse('$base/${Uri.encodeComponent(cleanTitle)}');
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
        if (streamData is! Map) continue;

        final sources = streamData['sources'];
        if (sources is List) {
          for (final s in sources) {
            if (s is Map && s['url'] != null) {
              final fileUrl = s['url'].toString();
              final quality = s['quality']?.toString() ?? 'Default';

              yield StreamSource(
                name: 'AnimePahe ($quality)',
                title: '⛩️ $title - Episode $epNum\n⚡ $quality Kwik Fast Stream (Non-Torrent)',
                url: fileUrl,
                addonName: 'AnimePahe',
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
