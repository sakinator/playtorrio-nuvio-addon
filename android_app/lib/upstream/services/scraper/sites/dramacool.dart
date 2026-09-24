import 'dart:async';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import '../stream_scraper.dart';
import '../../../models/stream/stream_model.dart';

/// Dramacool / AsianLoad Stream Scraper for PlayTorrioHTTP.
/// Direct streams for K-Dramas, C-Dramas, J-Dramas (zero torrents).
class DramacoolScraper extends StreamScraper {
  @override
  String get name => 'PlayTorrioHTTP';

  @override
  String get providerId => 'dramacool';

  @override
  String get providerName => 'Dramacool';

  static const List<String> _baseUrls = [
    'https://dramacool.city',
    'https://dramacool.hr',
    'https://asianload.io',
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

    for (final base in _baseUrls) {
      try {
        final searchUrl = Uri.parse('$base/search?type=movies&keyword=${Uri.encodeComponent(cleanTitle)}');
        final res = await http.get(searchUrl, headers: _headers).timeout(const Duration(seconds: 4));
        if (res.statusCode != 200) continue;

        final doc = html_parser.parse(res.body);
        final links = doc.querySelectorAll('ul.list-episode-item li a');

        for (final a in links) {
          final dramaHref = a.attributes['href'];
          final dramaTitle = a.text.trim();
          if (dramaHref == null || dramaHref.isEmpty) continue;

          // Check title match
          if (!dramaTitle.toLowerCase().contains(cleanTitle.split(' ').first.toLowerCase())) continue;

          // Construct episode URL or fetch drama page
          final epUrl = dramaHref.contains('episode-')
              ? dramaHref
              : '${dramaHref.replaceAll('.html', '')}-episode-$epNum.html';

          final fullEpUrl = epUrl.startsWith('http') ? epUrl : '$base$epUrl';
          final epRes = await http.get(Uri.parse(fullEpUrl), headers: _headers).timeout(const Duration(seconds: 4));
          if (epRes.statusCode != 200) continue;

          final epDoc = html_parser.parse(epRes.body);
          final iframes = epDoc.querySelectorAll('iframe[src*="asianload"], iframe[src*="standard"], iframe[src*="stream"]');

          for (final iframe in iframes) {
            var src = iframe.attributes['src'];
            if (src == null || src.isEmpty) continue;
            if (src.startsWith('//')) src = 'https:$src';

            yield StreamSource(
              name: 'Dramacool',
              title: '⚡ AsianLoad Direct Stream (K-Drama / C-Drama) • Ep $epNum (Non-Torrent)',
              url: src,
              addonName: 'PlayTorrioHTTP',
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
