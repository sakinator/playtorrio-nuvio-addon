import 'dart:async';
import 'dart:convert';
import 'dart:io';

class EpisodeInfo {
  final int season;
  final int episode;
  final int? absoluteEpisode;
  final String? title;
  final String? overview;
  final String? released;
  final String? thumbnail;

  EpisodeInfo({
    required this.season,
    required this.episode,
    this.absoluteEpisode,
    this.title,
    this.overview,
    this.released,
    this.thumbnail,
  });

  Map<String, dynamic> toJson() => {
        'season': season,
        'episode': episode,
        if (absoluteEpisode != null) 'absoluteEpisode': absoluteEpisode,
        if (title != null) 'title': title,
        if (overview != null) 'overview': overview,
        if (released != null) 'released': released,
        if (thumbnail != null) 'thumbnail': thumbnail,
      };
}

class TvSeriesMapping {
  final String imdbId;
  final String? title;
  final int? tvdbId;
  final Map<String, EpisodeInfo> episodes; // "S{season}E{episode}" -> EpisodeInfo
  final Map<int, EpisodeInfo> absoluteMap; // absoluteNumber -> EpisodeInfo

  TvSeriesMapping({
    required this.imdbId,
    this.title,
    this.tvdbId,
    required this.episodes,
    required this.absoluteMap,
  });
}

class TvdbService {
  static final TvdbService instance = TvdbService._();

  TvdbService._();

  static final Map<String, TvSeriesMapping> _cache = {};
  static final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 4);

  /// Resolves TV series episode mapping, episode names, and absolute episode numbers.
  Future<TvSeriesMapping?> getSeriesMapping({
    required String imdbId,
    String? title,
  }) async {
    if (_cache.containsKey(imdbId)) {
      return _cache[imdbId];
    }

    final episodes = <String, EpisodeInfo>{};
    final absoluteMap = <int, EpisodeInfo>{};
    int? resolvedTvdbId;

    // 1. Try Cinemeta series metadata (fastest and covers all Stremio/Nuvio catalog)
    try {
      final uri = Uri.parse('https://v3-cinemeta.strem.io/meta/series/$imdbId.json');
      final req = await _client.getUrl(uri).timeout(const Duration(milliseconds: 3500));
      final res = await req.close().timeout(const Duration(milliseconds: 3500));

      if (res.statusCode == 200) {
        final body = await utf8.decodeStream(res);
        final json = jsonDecode(body);
        final meta = json['meta'] as Map?;
        final videos = meta?['videos'] as List?;

        if (videos != null && videos.isNotEmpty) {
          int absCounter = 1;
          // Sort by season and number ascending to compute proper absolute count
          final sortedVideos = List<Map<dynamic, dynamic>>.from(
            videos.whereType<Map<dynamic, dynamic>>(),
          );
          sortedVideos.sort((a, b) {
            final sA = (a['season'] is int) ? a['season'] as int : int.tryParse(a['season'].toString()) ?? 0;
            final sB = (b['season'] is int) ? b['season'] as int : int.tryParse(b['season'].toString()) ?? 0;
            if (sA != sB) return sA.compareTo(sB);
            final eA = (a['number'] is int) ? a['number'] as int : int.tryParse(a['number'].toString()) ?? 0;
            final eB = (b['number'] is int) ? b['number'] as int : int.tryParse(b['number'].toString()) ?? 0;
            return eA.compareTo(eB);
          });

          for (final v in sortedVideos) {
            final s = (v['season'] is int) ? v['season'] as int : int.tryParse(v['season'].toString()) ?? 0;
            final e = (v['number'] is int) ? v['number'] as int : int.tryParse(v['number'].toString()) ?? 0;
            if (s == 0 && e == 0) continue; // Skip specials if unnumbered

            final epTitle = v['title']?.toString() ?? v['name']?.toString();
            final overview = v['overview']?.toString() ?? v['description']?.toString();
            final released = v['released']?.toString();
            final thumb = v['thumbnail']?.toString();

            // Season > 0 contributes to absolute count
            final currentAbs = s > 0 ? absCounter++ : null;

            final info = EpisodeInfo(
              season: s,
              episode: e,
              absoluteEpisode: currentAbs,
              title: epTitle,
              overview: overview,
              released: released,
              thumbnail: thumb,
            );

            episodes['S${s}E$e'] = info;
            if (currentAbs != null) {
              absoluteMap[currentAbs] = info;
            }
          }
        }
      } else {
        await res.drain<void>();
      }
    } catch (_) {}

    // 2. Try TVMaze lookup to enrich episode titles or fill missing series
    if (episodes.isEmpty && imdbId.startsWith('tt')) {
      try {
        final lookupUri = Uri.parse('https://api.tvmaze.com/lookup/shows?imdb=$imdbId');
        final req = await _client.getUrl(lookupUri).timeout(const Duration(milliseconds: 3000));
        final res = await req.close().timeout(const Duration(milliseconds: 3000));
        if (res.statusCode == 200) {
          final body = await utf8.decodeStream(res);
          final show = jsonDecode(body) as Map;
          final showId = show['id'];
          final externals = show['externals'] as Map?;
          if (externals != null && externals['thetvdb'] != null) {
            resolvedTvdbId = int.tryParse(externals['thetvdb'].toString());
          }

          if (showId != null) {
            final epUri = Uri.parse('https://api.tvmaze.com/shows/$showId/episodes');
            final epReq = await _client.getUrl(epUri).timeout(const Duration(milliseconds: 3000));
            final epRes = await epReq.close().timeout(const Duration(milliseconds: 3000));
            if (epRes.statusCode == 200) {
              final epBody = await utf8.decodeStream(epRes);
              final epList = jsonDecode(epBody) as List;
              int absCounter = 1;
              for (final ep in epList) {
                if (ep is Map) {
                  final s = ep['season'] as int? ?? 1;
                  final e = ep['number'] as int? ?? 1;
                  final name = ep['name']?.toString();
                  final summary = ep['summary']?.toString();
                  final airdate = ep['airdate']?.toString();
                  final imageMap = ep['image'] as Map?;
                  final thumb = imageMap?['medium']?.toString() ?? imageMap?['original']?.toString();
                  final currentAbs = absCounter++;

                  final info = EpisodeInfo(
                    season: s,
                    episode: e,
                    absoluteEpisode: currentAbs,
                    title: name,
                    overview: summary,
                    released: airdate,
                    thumbnail: thumb,
                  );
                  episodes['S${s}E$e'] = info;
                  absoluteMap[currentAbs] = info;
                }
              }
            } else {
              await epRes.drain<void>();
            }
          }
        } else {
          await res.drain<void>();
        }
      } catch (_) {}
    }

    final mapping = TvSeriesMapping(
      imdbId: imdbId,
      title: title,
      tvdbId: resolvedTvdbId,
      episodes: episodes,
      absoluteMap: absoluteMap,
    );

    _cache[imdbId] = mapping;
    return mapping;
  }

  /// Retrieves specific episode details (name, absolute number) for SxxExx.
  Future<EpisodeInfo?> getEpisodeInfo({
    required String imdbId,
    required int season,
    required int episode,
    String? title,
  }) async {
    final mapping = await getSeriesMapping(imdbId: imdbId, title: title);
    if (mapping == null) return null;
    return mapping.episodes['S${season}E$episode'];
  }

  /// Generates multi-format scraper query aliases for Indian, Anime, and Western scrapers.
  List<String> generateSearchAliases({
    required String seriesTitle,
    required int season,
    required int episode,
    EpisodeInfo? epInfo,
  }) {
    final queries = <String>[];
    final sStr = season.toString().padLeft(2, '0');
    final eStr = episode.toString().padLeft(2, '0');

    // 1. Standard Scene notation (e.g. "Game of Thrones S01E01")
    queries.add('$seriesTitle S${sStr}E$eStr');
    queries.add('$seriesTitle S$season E$episode');

    // 2. Absolute Episode notation for Anime & Serials (e.g. "One Piece Episode 1089")
    if (epInfo?.absoluteEpisode != null) {
      queries.add('$seriesTitle Episode ${epInfo!.absoluteEpisode}');
      queries.add('$seriesTitle EP${epInfo.absoluteEpisode}');
      queries.add('$seriesTitle EP ${epInfo.absoluteEpisode}');
    }

    // 3. Named Episode Title (e.g. "Breaking Bad Ozymandias")
    if (epInfo?.title != null && epInfo!.title!.isNotEmpty && epInfo.title!.length > 3) {
      // Avoid generic episode titles like "Episode 1"
      if (!epInfo.title!.toLowerCase().startsWith('episode ')) {
        queries.add('$seriesTitle ${epInfo.title}');
      }
    }

    return queries;
  }
}
