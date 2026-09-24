import 'dart:async';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import '../stream_scraper.dart';
import '../../../models/stream/stream_model.dart';

/// PlayDesi / DesiRulez Non-Torrent Stream Scraper.
/// Extracts direct streaming sources for Indian TV serials
/// (Star Plus, Zee TV, Colors, Sony SAB, Bigg Boss) & Pakistani Dramas.
class PlayDesiScraper extends StreamScraper {
  @override
  String get name => 'PlayDesi';

  @override
  String get providerId => 'playdesi';

  @override
  String get providerName => 'PlayDesi';

  static const List<String> _baseUrls = [
    'https://playdesi.net',
    'https://playdesi.com.pk',
    'https://desiruleztv.net',
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
        final articles = doc.querySelectorAll('article a, h2.entry-title a, .post-title a');

        for (final art in articles) {
          final link = art.attributes['href'];
          final postTitle = art.text.trim();
          if (link == null || link.isEmpty || !link.startsWith('http')) continue;

          // Check if post title matches target
          final firstWord = cleanTitle.split(' ').first.toLowerCase();
          if (!postTitle.toLowerCase().contains(firstWord)) continue;

          // Fetch episode page
          final postRes = await http.get(Uri.parse(link), headers: _headers).timeout(const Duration(seconds: 4));
          if (postRes.statusCode != 200) continue;

          final postDoc = html_parser.parse(postRes.body);
          final players = postDoc.querySelectorAll('iframe[src*="dailymotion"], iframe[src*="vk"], iframe[src*="stream"], a[href*="dailymotion"], a[href*="watch"]');

          for (final p in players) {
            final srcUrl = p.attributes['src'] ?? p.attributes['href'];
            if (srcUrl == null || srcUrl.isEmpty) continue;

            yield StreamSource(
              name: 'PlayDesi',
              title: '$postTitle\n📺 🇮🇳 Indian Serial / Drama Episode Stream',
              url: srcUrl.startsWith('//') ? 'https:$srcUrl' : srcUrl,
              addonName: 'PlayDesi',
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
