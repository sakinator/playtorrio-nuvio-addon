import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../stream_scraper.dart';
import '../../../models/stream/stream_model.dart';

/// Gogoanime (Anitaku) Non-Torrent Stream Scraper for PlayTorrioHTTP.
/// Extracts direct HLS (.m3u8) / MP4 streams via GogoCDN & Vidstreaming
/// with English Sub & Dub options (Zero Torrents).
class GogoanimeScraper extends StreamScraper {
  @override
  String get name => 'PlayTorrioHTTP';

  @override
  String get providerId => 'gogoanime';

  @override
  String get providerName => 'Gogoanime';

  static const List<String> _apiBases = [
    'https://api-consumet.org/anime/gogoanime',
    'https://consumet-api.up.railway.app/anime/gogoanime',
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

        // Take up to 2 top matches (Sub and Dub versions if available)
        for (final item in results.take(2)) {
          final animeId = item['id']?.toString();
          final animeTitle = item['title']?.toString() ?? title;
          final isDub = animeTitle.toLowerCase().contains('(dub)') || animeId?.endsWith('-dub') == true;

          if (animeId == null || animeId.isEmpty) continue;

          // Fetch episode stream
          final episodeId = '$animeId-episode-$epNum';
          final streamUrl = Uri.parse('$base/watch/$episodeId');
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
                  name: 'Gogoanime ($quality)',
                  title: '⛩️ ${isDub ? "[DUB]" : "[SUB]"} Anime • Episode $epNum • $quality HLS (Non-Torrent)',
                  url: fileUrl,
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
        }
        break; // Stop after first successful API base
      } catch (_) {}
    }
  }
}
