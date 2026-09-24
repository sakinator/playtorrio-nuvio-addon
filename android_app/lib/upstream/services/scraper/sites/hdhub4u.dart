import 'dart:async';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import '../stream_scraper.dart';
import '../../../models/stream/stream_model.dart';

/// HDHub4u Non-Torrent Stream Scraper for PlayTorrio / Saket.
/// High-speed cloud streaming links (HubCloud / PixelDrain / FastDL)
/// for 4K UHD & 1080p FHD Bollywood, South Indian & Dual-Audio movies.
class HDHub4uScraper extends StreamScraper {
  @override
  String get name => 'HDHub4u';

  @override
  String get providerId => 'hdhub4u';

  @override
  String get providerName => 'HDHub4u';

  static const List<String> _baseUrls = [
    'https://hdhub4u.ms',
    'https://hdhub4u.tv',
    'https://hdhub4u.mov',
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
        final articles = doc.querySelectorAll('article.post, div.post-item, a[rel="bookmark"], h2.entry-title a');

        for (final art in articles) {
          final link = art.attributes['href'] ?? art.querySelector('a')?.attributes['href'];
          final postTitle = art.text.trim();
          if (link == null || link.isEmpty || !link.startsWith('http')) continue;

          final firstWord = cleanTitle.split(' ').first.toLowerCase();
          if (!postTitle.toLowerCase().contains(firstWord)) continue;

          // Fetch post page
          final postRes = await http.get(Uri.parse(link), headers: _headers).timeout(const Duration(seconds: 4));
          if (postRes.statusCode != 200) continue;

          final postDoc = html_parser.parse(postRes.body);
          final downloadButtons = postDoc.querySelectorAll('a[href*="hubcloud"], a[href*="pixeldrain"], a[href*="fastdl"], a[href*="vcloud"]');

          for (final btn in downloadButtons) {
            final targetUrl = btn.attributes['href'];
            if (targetUrl == null || targetUrl.isEmpty) continue;

            final btnText = btn.parent?.text.trim() ?? btn.text.trim();
            final quality = btnText.contains('2160p') || btnText.contains('4K')
                ? '4K UHD'
                : btnText.contains('1080p')
                    ? '1080p FHD'
                    : btnText.contains('720p')
                        ? '720p HD'
                        : 'HD';

            final isHindi = btnText.toLowerCase().contains('hindi') || 
                            btnText.toLowerCase().contains('dual') ||
                            postTitle.toLowerCase().contains('hindi');

            yield StreamSource(
              name: 'HDHub4u ($quality)',
              title: '$postTitle\n⚡ ${isHindi ? "🇮🇳 Hindi • " : ""}$quality Direct Cloud Stream (Non-Torrent)',
              url: targetUrl,
              addonName: 'HDHub4u',
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
