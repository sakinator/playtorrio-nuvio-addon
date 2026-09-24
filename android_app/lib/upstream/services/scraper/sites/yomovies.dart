import 'dart:async';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import '../stream_scraper.dart';
import '../../../models/stream/stream_model.dart';

/// YoMovies Non-Torrent Stream Scraper for PlayTorrio / Saket.
/// Extracts direct streaming and player links for Bollywood,
/// South Indian Hindi Dubbed, and Hollywood Hindi releases.
class YoMoviesScraper extends StreamScraper {
  @override
  String get name => 'YoMovies';

  @override
  String get providerId => 'yomovies';

  @override
  String get providerName => 'YoMovies';

  static const List<String> _baseUrls = [
    'https://yomovies.church',
    'https://yomovies.capital',
    'https://yomovies.ac',
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
    final cleanTitle = title.replaceAll(RegExp(r'[^\w\s]'), ' ').trim();
    final query = cleanTitle.split(' ').take(3).join(' ');

    for (final base in _baseUrls) {
      try {
        final searchUrl = Uri.parse('$base/?s=${Uri.encodeComponent(query)}');
        final res = await http.get(searchUrl, headers: _headers).timeout(const Duration(seconds: 4));
        if (res.statusCode != 200) continue;

        final doc = html_parser.parse(res.body);
        final articles = doc.querySelectorAll('.ml-item a, .movies-list .ml-item, div.post-item a');

        for (final art in articles) {
          final link = art.attributes['href'];
          final postTitle = art.attributes['title'] ?? art.text.trim();
          if (link == null || link.isEmpty || !link.startsWith('http')) continue;

          final firstWord = cleanTitle.split(' ').first.toLowerCase();
          if (!postTitle.toLowerCase().contains(firstWord)) continue;

          // Fetch watch page
          final postRes = await http.get(Uri.parse(link), headers: _headers).timeout(const Duration(seconds: 4));
          if (postRes.statusCode != 200) continue;

          final postDoc = html_parser.parse(postRes.body);
          final iframes = postDoc.querySelectorAll('iframe[src*="stream"], iframe[src*="embed"], iframe[src*="player"], a.btn-stream');

          for (final frame in iframes) {
            final srcUrl = frame.attributes['src'] ?? frame.attributes['href'];
            if (srcUrl == null || srcUrl.isEmpty) continue;

            final isHindi = postTitle.toLowerCase().contains('hindi') || postTitle.toLowerCase().contains('dual');

            yield StreamSource(
              name: 'YoMovies',
              title: '$postTitle\n⚡ ${isHindi ? "🇮🇳 Hindi • " : ""}Direct Cloud Player (Non-Torrent)',
              url: srcUrl.startsWith('//') ? 'https:$srcUrl' : srcUrl,
              addonName: 'YoMovies',
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
