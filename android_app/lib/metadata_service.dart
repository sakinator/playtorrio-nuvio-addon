import 'dart:convert';
import 'package:http/http.dart' as http;
import 'config.dart';

class MediaMetadata {
  final String id;
  final String type; // 'movie' or 'series'
  final String title;
  final int? year;
  final int? season;
  final int? episode;
  final String? imdbId;
  final int? tmdbId;

  MediaMetadata({
    required this.id,
    required this.type,
    required this.title,
    this.year,
    this.season,
    this.episode,
    this.imdbId,
    this.tmdbId,
  });

  @override
  String toString() =>
      'MediaMetadata($type, "$title", year: $year, S${season}E${episode}, imdb: $imdbId, tmdb: $tmdbId)';
}

class MetadataService {
  // API key is read from AddonConfig so users can supply their own key in
  // data/config.json without recompiling.
  static String get _apiKey => AddonConfig.instance.tmdbApiKey;

  static const _tmdbDirect = 'https://api.themoviedb.org/3';
  static const _tmdbProxy = 'https://db.speedracelight.com/3';
  static const _cinemeta = 'https://v3-cinemeta.strem.io/meta';

  static const _headers = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
    'Accept': 'application/json',
  };

  static final Map<String, MediaMetadata> _cache = {};

  /// Resolves an incoming Stremio / Nuvio media ID into complete metadata.
  /// Supports:
  /// - `tt1375666` (movie)
  /// - `tt0944947:1:1` (series: S01E01)
  /// - `tmdb:27205`
  /// - `tmdb:1399:1:1`
  static Future<MediaMetadata?> resolve({
    required String type, // 'movie' or 'series'
    required String rawId,
  }) async {
    final cacheKey = '$type|$rawId';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey];
    }

    String baseId = rawId;
    int? season;
    int? episode;

    if (rawId.contains(':')) {
      final parts = rawId.split(':');
      if (parts[0] == 'tmdb' && parts.length >= 4) {
        baseId = 'tmdb:${parts[1]}';
        season = int.tryParse(parts[2]);
        episode = int.tryParse(parts[3]);
      } else if (parts[0] == 'tmdb' && parts.length == 2) {
        baseId = rawId;
      } else if (parts.length >= 3) {
        baseId = parts[0];
        season = int.tryParse(parts[1]);
        episode = int.tryParse(parts[2]);
      } else if (parts.length == 2 && parts[0].startsWith('tt')) {
        baseId = parts[0];
        season = int.tryParse(parts[1]);
      }
    }

    String? imdbId;
    int? tmdbId;
    String? title;
    int? year;

    final isTv = (type == 'series' || type == 'tv');
    final cinemetaType = isTv ? 'series' : 'movie';
    final tmdbType = isTv ? 'tv' : 'movie';

    if (baseId.startsWith('tt')) {
      imdbId = baseId;

      // 1. Try Cinemeta (Fast, reliable for Stremio/Nuvio ecosystem)
      try {
        final uri = Uri.parse('$_cinemeta/$cinemetaType/$imdbId.json');
        final res = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 4));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          final meta = data['meta'];
          if (meta != null) {
            title = meta['name']?.toString();
            final yStr = meta['year']?.toString();
            if (yStr != null) {
              year = int.tryParse(yStr.split('–')[0].split('-')[0].trim());
            }
          }
        }
      } catch (_) {}

      // 2. Query TMDB Find to get TMDB ID and confirm title/year
      try {
        final uri = Uri.parse('$_tmdbDirect/find/$imdbId?api_key=$_apiKey&external_source=imdb_id');
        final res = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 4));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          final results = isTv ? (data['tv_results'] as List?) : (data['movie_results'] as List?);
          if (results != null && results.isNotEmpty) {
            final first = results.first;
            tmdbId = first['id'] as int?;
            title ??= (first['name'] ?? first['title'])?.toString();
            final dateStr = (first['first_air_date'] ?? first['release_date'])?.toString();
            if (year == null && dateStr != null && dateStr.length >= 4) {
              year = int.tryParse(dateStr.substring(0, 4));
            }
          }
        }
      } catch (_) {
        // Fallback to TMDB proxy
        try {
          final uri = Uri.parse('$_tmdbProxy/find/$imdbId?external_source=imdb_id');
          final res = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 4));
          if (res.statusCode == 200) {
            final data = jsonDecode(res.body);
            final results = isTv ? (data['tv_results'] as List?) : (data['movie_results'] as List?);
            if (results != null && results.isNotEmpty) {
              final first = results.first;
              tmdbId = first['id'] as int?;
              title ??= (first['name'] ?? first['title'])?.toString();
            }
          }
        } catch (_) {}
      }
    } else if (baseId.startsWith('tmdb:')) {
      final numericStr = baseId.replaceFirst('tmdb:', '');
      tmdbId = int.tryParse(numericStr);
      if (tmdbId != null) {
        try {
          final uri = Uri.parse('$_tmdbDirect/$tmdbType/$tmdbId?api_key=$_apiKey');
          final res = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 4));
          if (res.statusCode == 200) {
            final data = jsonDecode(res.body);
            title = (data['name'] ?? data['title'])?.toString();
            imdbId = data['imdb_id']?.toString();
            final dateStr = (data['first_air_date'] ?? data['release_date'])?.toString();
            if (dateStr != null && dateStr.length >= 4) {
              year = int.tryParse(dateStr.substring(0, 4));
            }
          }
        } catch (_) {}
      }
    }

    if (title == null || title.isEmpty) {
      return null;
    }

    final result = MediaMetadata(
      id: rawId,
      type: isTv ? 'series' : 'movie',
      title: title,
      year: year,
      season: season,
      episode: episode,
      imdbId: imdbId,
      tmdbId: tmdbId,
    );

    _cache[cacheKey] = result;
    return result;
  }
}
