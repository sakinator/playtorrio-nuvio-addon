import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'config.dart';

class ArtworkMetadata {
  final String? logo;
  final String? background;
  final String? poster;
  final String? banner;
  final String? thumb;

  ArtworkMetadata({
    this.logo,
    this.background,
    this.poster,
    this.banner,
    this.thumb,
  });

  Map<String, dynamic> toJson() => {
        if (logo != null) 'logo': logo,
        if (background != null) 'background': background,
        if (poster != null) 'poster': poster,
        if (banner != null) 'banner': banner,
        if (thumb != null) 'thumb': thumb,
      };
}

class FanartService {
  static final FanartService instance = FanartService._();

  FanartService._();

  static final Map<String, ArtworkMetadata> _cache = {};
  static final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 4);

  // Common community fallback Fanart API key
  static const String _defaultFanartKey = 'd71912953e34b92b60389332e29fd610';

  /// Resolves high-resolution transparent ClearLogos, 4K backdrops, and posters
  /// from Fanart.tv, with automatic instant fallback to Metahub CDN.
  Future<ArtworkMetadata> getArtwork({
    required String type, // 'movie' or 'series' / 'tv'
    required String? imdbId,
    int? tmdbId,
    int? tvdbId,
  }) async {
    final key = '${type}_${imdbId ?? tmdbId ?? tvdbId}';
    if (_cache.containsKey(key)) {
      return _cache[key]!;
    }

    String? logoUrl;
    String? backgroundUrl;
    String? posterUrl;
    String? bannerUrl;
    String? thumbUrl;

    // 1. Attempt Fanart.tv Query
    final configuredKey = AddonConfig.instance.fanartApiKey.trim();
    final apiKey = configuredKey.isNotEmpty ? configuredKey : _defaultFanartKey;

    final isTv = (type == 'series' || type == 'tv');
    final queryId = (isTv ? (tvdbId?.toString() ?? tmdbId?.toString() ?? imdbId) : (tmdbId?.toString() ?? imdbId));

    if (queryId != null && queryId.isNotEmpty && apiKey.isNotEmpty) {
      try {
        final endpoint = isTv ? 'tv' : 'movies';
        final uri = Uri.parse('https://webservice.fanart.tv/v3/$endpoint/$queryId?api_key=$apiKey');
        final req = await _client.getUrl(uri).timeout(const Duration(milliseconds: 3500));
        final res = await req.close().timeout(const Duration(milliseconds: 3500));

        if (res.statusCode == 200) {
          final body = await utf8.decodeStream(res);
          final json = jsonDecode(body) as Map<String, dynamic>;

          // Extract best transparent ClearLogo (prefer English 'en' or highest likes)
          final logos = (isTv
                  ? (json['hdtvlogo'] ?? json['clearlogo'])
                  : (json['hdmovielogo'] ?? json['movielogo'])) as List?;
          if (logos != null && logos.isNotEmpty) {
            final enLogos = logos.where((l) => l is Map && l['lang'] == 'en').toList();
            final chosen = enLogos.isNotEmpty ? enLogos.first : logos.first;
            if (chosen is Map) logoUrl = chosen['url']?.toString();
          }

          // Extract best 4K Backdrop / Background
          final backgrounds = (isTv ? json['showbackground'] : json['moviebackground']) as List?;
          if (backgrounds != null && backgrounds.isNotEmpty) {
            final chosen = backgrounds.first;
            if (chosen is Map) backgroundUrl = chosen['url']?.toString();
          }

          // Extract Poster
          final posters = (isTv ? json['tvposter'] : json['movieposter']) as List?;
          if (posters != null && posters.isNotEmpty) {
            final enPosters = posters.where((p) => p is Map && p['lang'] == 'en').toList();
            final chosen = enPosters.isNotEmpty ? enPosters.first : posters.first;
            if (chosen is Map) posterUrl = chosen['url']?.toString();
          }

          // Extract Banner
          final banners = (isTv ? json['tvbanner'] : json['moviebanner']) as List?;
          if (banners != null && banners.isNotEmpty) {
            final chosen = banners.first;
            if (chosen is Map) bannerUrl = chosen['url']?.toString();
          }

          // Extract Thumb
          final thumbs = (isTv ? json['tvthumb'] : json['moviethumb']) as List?;
          if (thumbs != null && thumbs.isNotEmpty) {
            final chosen = thumbs.first;
            if (chosen is Map) thumbUrl = chosen['url']?.toString();
          }
        } else {
          await res.drain<void>();
        }
      } catch (_) {
        // Fallback to Metahub
      }
    }

    // 2. Metahub CDN Fallback for ClearLogo & Background (100% reliable for IMDb IDs)
    if (imdbId != null && imdbId.startsWith('tt')) {
      logoUrl ??= 'https://images.metahub.space/logo/medium/$imdbId/img';
      backgroundUrl ??= 'https://images.metahub.space/background/medium/$imdbId/img';
      posterUrl ??= 'https://images.metahub.space/poster/medium/$imdbId/img';
    }

    final artwork = ArtworkMetadata(
      logo: logoUrl,
      background: backgroundUrl,
      poster: posterUrl,
      banner: bannerUrl,
      thumb: thumbUrl,
    );

    _cache[key] = artwork;
    return artwork;
  }
}
