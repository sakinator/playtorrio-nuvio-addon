import 'dart:async';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import '../stream_scraper.dart';
import '../../../models/stream/stream_model.dart';

/// KissAsian / ViewAsian Non-Torrent Stream Scraper for PlayTorrio / Saket.
/// Extracts direct streaming sources for Korean, Chinese, Japanese,
/// and Taiwanese dramas & movies.
class KissAsianScraper extends StreamScraper {
  @override
  String get name => 'KissAsian';

  @override
  String get providerId => 'kissasian';

  @override
  String get providerName => 'KissAsian';

  static const List<String> _baseUrls = [
    'https://kissasian.lu',
    'https://viewasian.co',
    'https://kissasian.cam',
  ];

  static const _headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
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
    final query = cleanTitle.split(' ').take(3).join(' ');

    for (final base in _baseUrls) {
      try {
        final searchUrl = Uri.parse('$base/Search/Drama?keyword=${Uri.encodeComponent(query)}');
        final res = await http.get(searchUrl, headers: _headers).timeout(const Duration(seconds: 4));
        if (res.statusCode != 200) continue;

        final doc = html_parser.parse(res.body);
        final dramaLinks = doc.querySelectorAll('.item a, .list-drama a, .bar-content a');

        for (final drama in dramaLinks) {
          final dramaUrl = drama.attributes['href'];
          final dramaTitle = drama.text.trim();
          if (dramaUrl == null || dramaUrl.isEmpty) continue;

          final firstWord = cleanTitle.split(' ').first.toLowerCase();
          if (!dramaTitle.toLowerCase().contains(firstWord)) continue;

          // Build episode URL or follow link
          final fullDramaUrl = dramaUrl.startsWith('http') ? dramaUrl : '$base$dramaUrl';
          final epUrl = '$fullDramaUrl-episode-$epNum';

          final epRes = await http.get(Uri.parse(epUrl), headers: _headers).timeout(const Duration(seconds: 4));
          if (epRes.statusCode != 200) continue;

          final epDoc = html_parser.parse(epRes.body);
          final serverLinks = epDoc.querySelectorAll('iframe[src*="asian"], iframe[src*="stream"], a[data-video], li.linkserver');

          for (final s in serverLinks) {
            final srcUrl = s.attributes['src'] ?? s.attributes['data-video'];
            if (srcUrl == null || srcUrl.isEmpty) continue;

            yield StreamSource(
              name: 'KissAsian',
              title: '$dramaTitle - Episode $epNum\n🎭 Asian Drama Direct Stream (Non-Torrent)',
              url: srcUrl.startsWith('//') ? 'https:$srcUrl' : srcUrl,
              addonName: 'KissAsian',
              providerId: providerId,
              providerName: providerName,
              behaviorHints: {
                'notWebReady': false,
              },
            );
          }
        }
        break;
      } catch (_) {}
    }
  }
}
