/// BadgeService: Evaluates stream metadata against Nuvio / NardBadges rules
/// and directly enriches the scraped links with high-fidelity badges,
/// technical audio/video specs, and clean scene formatting.
class BadgeService {
  static final List<BadgeFilter> filters = [
    // Resolution (gr) - mutually exclusive
    BadgeFilter(id: 'r-4k', groupId: 'gr', name: '4K', priority: 100, pattern: RegExp(r'(?:2160[pi]?|4k|uhd)', caseSensitive: false)),
    BadgeFilter(id: 'r-1080', groupId: 'gr', name: 'FHD', priority: 80, pattern: RegExp(r'(?:1080[pi]?|fhd|full[\s._-]?hd)', caseSensitive: false)),
    BadgeFilter(id: 'r-720', groupId: 'gr', name: 'HD', priority: 60, pattern: RegExp(r'720[pi]?', caseSensitive: false)),

    // Quality / Release Source (grl) - mutually exclusive
    BadgeFilter(id: 'q-remux', groupId: 'grl', name: 'Remux', priority: 100, pattern: RegExp(r'\bremux\b', caseSensitive: false)),
    BadgeFilter(id: 'q-bluray', groupId: 'grl', name: 'BluRay', priority: 80, pattern: RegExp(r'\b(?:bluray|blu[\s._-]?ray|bdrip)\b', caseSensitive: false)),
    BadgeFilter(id: 'q-webdl', groupId: 'grl', name: 'WEB-DL', priority: 60, pattern: RegExp(r'\b(?:web[\s._-]?dl|webdl)\b', caseSensitive: false)),
    BadgeFilter(id: 'q-webrip', groupId: 'grl', name: 'WEBRip', priority: 40, pattern: RegExp(r'\bweb[\s._-]?rip\b', caseSensitive: false)),

    // Visual Enhancements (gv)
    BadgeFilter(id: 'v-atmos-dv', groupId: 'gv', name: 'Atmos+DV', priority: 100, pattern: RegExp(r'(?=.*atmos)(?=.*(?:dv|dovi|dolby[\s._-]?vision))', caseSensitive: false)),
    BadgeFilter(id: 'v-dv', groupId: 'gv', name: 'DV', priority: 90, pattern: RegExp(r'\b(?:dv|dovi|dolby[\s._-]?vision)\b', caseSensitive: false)),
    BadgeFilter(id: 'v-hdr10p', groupId: 'gv', name: 'HDR10+', priority: 80, pattern: RegExp(r'hdr[\s._-]?10[\s._-]?(?:\+|plus)', caseSensitive: false)),
    BadgeFilter(id: 'v-hdr10', groupId: 'gv', name: 'HDR10', priority: 70, pattern: RegExp(r'hdr[\s._-]?10', caseSensitive: false)),
    BadgeFilter(id: 'v-hdr', groupId: 'gv', name: 'HDR', priority: 60, pattern: RegExp(r'\b(?:hdr|hlg|pq)\b', caseSensitive: false)),
    BadgeFilter(id: 'v-imax-e', groupId: 'gv', name: 'IMAX Enhanced', priority: 50, pattern: RegExp(r'imax[\s._-]?enhanced', caseSensitive: false)),
    BadgeFilter(id: 'v-imax', groupId: 'gv', name: 'IMAX', priority: 40, pattern: RegExp(r'\bimax\b', caseSensitive: false)),
    BadgeFilter(id: 'v-3d', groupId: 'gv', name: '3D', priority: 30, pattern: RegExp(r'\b(?:3d|sbs|half[\s._-]?sbs|hsbs)\b', caseSensitive: false)),

    // Video Codec (gvc) - mutually exclusive
    BadgeFilter(id: 'c-av1', groupId: 'gvc', name: 'AV1', priority: 100, pattern: RegExp(r'\bav1\b', caseSensitive: false)),
    BadgeFilter(id: 'c-hevc', groupId: 'gvc', name: 'HEVC', priority: 80, pattern: RegExp(r'\b(?:x265|hevc|h\.?265)\b', caseSensitive: false)),
    BadgeFilter(id: 'c-avc', groupId: 'gvc', name: 'AVC', priority: 60, pattern: RegExp(r'\b(?:x264|avc|h\.?264)\b', caseSensitive: false)),

    // Audio Codec (ga) - mutually exclusive
    BadgeFilter(id: 'a-truehd', groupId: 'ga', name: 'TrueHD', priority: 100, pattern: RegExp(r'\btrue[\s._-]?hd\b', caseSensitive: false)),
    BadgeFilter(id: 'a-atmos', groupId: 'ga', name: 'Atmos', priority: 90, pattern: RegExp(r'\batmos\b', caseSensitive: false)),
    BadgeFilter(id: 'a-dtsx', groupId: 'ga', name: 'DTS:X', priority: 85, pattern: RegExp(r'\bdts[-_.: ]?x\b', caseSensitive: false)),
    BadgeFilter(id: 'a-dtshd', groupId: 'ga', name: 'DTS-HD', priority: 80, pattern: RegExp(r'\bdts[-_. ]?hd\b', caseSensitive: false)),
    BadgeFilter(id: 'a-dts', groupId: 'ga', name: 'DTS', priority: 70, pattern: RegExp(r'\bdts\b', caseSensitive: false)),
    BadgeFilter(id: 'a-ddp', groupId: 'ga', name: 'DD+', priority: 60, pattern: RegExp(r'\b(?:ddp\d?|dd\+|eac3|e-ac3|dolby[\s._-]?digital[\s._-]?plus)\b', caseSensitive: false)),
    BadgeFilter(id: 'a-dd', groupId: 'ga', name: 'DD', priority: 50, pattern: RegExp(r'\b(?:dd[25]?|ac3|dolby[\s._-]?digital)\b', caseSensitive: false)),
    BadgeFilter(id: 'a-flac', groupId: 'ga', name: 'FLAC', priority: 40, pattern: RegExp(r'\bflac\b', caseSensitive: false)),
    BadgeFilter(id: 'a-aac', groupId: 'ga', name: 'AAC', priority: 30, pattern: RegExp(r'\baac\b', caseSensitive: false)),

    // Audio Channels (gc) - mutually exclusive
    BadgeFilter(id: 'ch-71', groupId: 'gc', name: '7.1', priority: 100, pattern: RegExp(r'\b7\.1\b', caseSensitive: false)),
    BadgeFilter(id: 'ch-51', groupId: 'gc', name: '5.1', priority: 80, pattern: RegExp(r'\b5\.1\b', caseSensitive: false)),
    BadgeFilter(id: 'ch-20', groupId: 'gc', name: '2.0', priority: 60, pattern: RegExp(r'\b2\.0\b', caseSensitive: false)),

    // Audio Languages (gl)
    BadgeFilter(id: 'l-dual', groupId: 'gl', name: 'Dual Audio', priority: 100, pattern: RegExp(r'\b(?:dual[\s._-]?audio)\b', caseSensitive: false)),
    BadgeFilter(id: 'l-multi', groupId: 'gl', name: 'Multi Audio', priority: 95, pattern: RegExp(r'\b(?:multi[\s._-]?audio)\b', caseSensitive: false)),
    BadgeFilter(id: 'l-hin', groupId: 'gl', name: 'Hindi', priority: 80, pattern: RegExp(r'\bhindi\b', caseSensitive: false)),
    BadgeFilter(id: 'l-tam', groupId: 'gl', name: 'Tamil', priority: 80, pattern: RegExp(r'\btamil\b', caseSensitive: false)),
    BadgeFilter(id: 'l-tel', groupId: 'gl', name: 'Telugu', priority: 80, pattern: RegExp(r'\btelugu\b', caseSensitive: false)),
    BadgeFilter(id: 'l-mal', groupId: 'gl', name: 'Malayalam', priority: 80, pattern: RegExp(r'\bmalayalam\b', caseSensitive: false)),
    BadgeFilter(id: 'l-kan', groupId: 'gl', name: 'Kannada', priority: 80, pattern: RegExp(r'\bkannada\b', caseSensitive: false)),
    BadgeFilter(id: 'l-ben', groupId: 'gl', name: 'Bengali', priority: 80, pattern: RegExp(r'\bbengali\b', caseSensitive: false)),
    BadgeFilter(id: 'l-pun', groupId: 'gl', name: 'Punjabi', priority: 80, pattern: RegExp(r'\bpunjabi\b', caseSensitive: false)),
    BadgeFilter(id: 'l-eng', groupId: 'gl', name: 'English', priority: 70, pattern: RegExp(r'\b(?:english|eng)\b', caseSensitive: false)),
    BadgeFilter(id: 'l-jap', groupId: 'gl', name: 'Japanese', priority: 70, pattern: RegExp(r'\b(?:japanese|jap)\b', caseSensitive: false)),

    // Stream Source Brands (gs)
    BadgeFilter(id: 's-nflx', groupId: 'gs', name: 'NETFLIX', priority: 50, pattern: RegExp(r'\b(?:nflx|netflix)\b', caseSensitive: false)),
    BadgeFilter(id: 's-amzn', groupId: 'gs', name: 'PRIME', priority: 50, pattern: RegExp(r'\b(?:amzn|prime[\s._-]?video)\b', caseSensitive: false)),
    BadgeFilter(id: 's-atvp', groupId: 'gs', name: 'APPLE TV+', priority: 50, pattern: RegExp(r'\b(?:atvp|apple[\s._-]?tv)\b', caseSensitive: false)),
    BadgeFilter(id: 's-dsnp', groupId: 'gs', name: 'DISNEY+', priority: 50, pattern: RegExp(r'\b(?:dsnp|disney[\s._-]?(?:\+|plus))\b', caseSensitive: false)),
    BadgeFilter(id: 's-hmax', groupId: 'gs', name: 'MAX', priority: 50, pattern: RegExp(r'\b(?:hmax|hbomax|hbo[\s._-]?max)\b', caseSensitive: false)),
    BadgeFilter(id: 's-hulu', groupId: 'gs', name: 'HULU', priority: 50, pattern: RegExp(r'\bhulu\b', caseSensitive: false)),
    BadgeFilter(id: 's-hotstar', groupId: 'gs', name: 'HOTSTAR', priority: 50, pattern: RegExp(r'\b(?:hotstar|disney[\s._-]?hotstar)\b', caseSensitive: false)),
    BadgeFilter(id: 's-sonyliv', groupId: 'gs', name: 'SONYLIV', priority: 50, pattern: RegExp(r'\bsonyliv\b', caseSensitive: false)),
    BadgeFilter(id: 's-zee5', groupId: 'gs', name: 'ZEE5', priority: 50, pattern: RegExp(r'\bzee5\b', caseSensitive: false)),
    BadgeFilter(id: 's-jio', groupId: 'gs', name: 'JIOCINEMA', priority: 50, pattern: RegExp(r'\bjio(?:cinema)?\b', caseSensitive: false)),
  ];

  /// Detects matching badges from the input text with group exclusivity
  static List<String> getBadges(String text) {
    // Single-choice groups where only the highest priority match is allowed
    const singleChoiceGroups = {'gr', 'grl', 'gvc', 'ga', 'gc'};
    final groupBest = <String, BadgeFilter>{};
    final multiMatches = <BadgeFilter>[];

    for (final f in filters) {
      if (f.pattern.hasMatch(text)) {
        if (singleChoiceGroups.contains(f.groupId)) {
          final existing = groupBest[f.groupId];
          if (existing == null || f.priority > existing.priority) {
            groupBest[f.groupId] = f;
          }
        } else {
          multiMatches.add(f);
        }
      }
    }

    final result = <String>[];
    // Add single choice winners in logical order: Resolution -> Quality -> Codec -> Audio -> Channels
    for (final gid in ['gr', 'grl', 'gvc', 'ga', 'gc']) {
      final winner = groupBest[gid];
      if (winner != null && !result.contains(winner.name)) {
        result.add(winner.name);
      }
    }
    // Add multi-matches (Visuals, Brands)
    for (final f in multiMatches) {
      if (!result.contains(f.name)) {
        result.add(f.name);
      }
    }
    return result;
  }

  /// Enriches scraped stream metadata with badges and clean formatting
  static Map<String, String> enrichStream({
    required String rawTitle,
    required String mediaTitle,
    int? year,
    int? season,
    int? episode,
    String? quality,
    String? codec,
    String? audioBadge,
    String? fileSize,
    required String providerName,
    bool isCached = false,
    bool isHls = false,
    bool isProxied = false,
  }) {
    // Determine effective resolution
    String resolvedRes = quality ?? '';
    final combinedCheck = '$rawTitle $quality'.toUpperCase();
    if (combinedCheck.contains('2160') || combinedCheck.contains('4K') || combinedCheck.contains('UHD')) {
      resolvedRes = '4K';
    } else if (combinedCheck.contains('1080') || combinedCheck.contains('FHD')) {
      resolvedRes = '1080p';
    } else if (combinedCheck.contains('720') || combinedCheck.contains('HD')) {
      resolvedRes = '720p';
    }

    // 1. Build standardized clean scene filename
    final sceneFilename = formatSceneFilename(
      title: mediaTitle,
      year: year,
      season: season,
      episode: episode,
      quality: resolvedRes,
      codec: codec,
      audio: audioBadge,
      originalFilename: (rawTitle.contains('.') && !rawTitle.contains('Direct Cloud') && !rawTitle.contains('\n'))
          ? rawTitle
          : null,
    );

    // 2. Evaluate all JSON badge filters against filename and clean specs
    final fullText = '$sceneFilename $resolvedRes ${audioBadge ?? ""} ${codec ?? ""}';
    final detectedBadges = getBadges(fullText);

    // 3. Assemble badge pills
    final badgePills = detectedBadges.map((b) => '[$b]').join(' ');

    // 4. Line 2: Details & Badges
    final details = <String>[];
    if (badgePills.isNotEmpty) {
      details.add(badgePills);
    } else if (resolvedRes.isNotEmpty) {
      details.add('[$resolvedRes]');
    }

    if (fileSize != null && fileSize.isNotEmpty) {
      details.add('💾 $fileSize');
    }

    if (isCached) {
      details.add('⚡ Torbox Cached');
    } else if (isHls) {
      details.add('⚡ HLS Stream');
    } else {
      details.add('⚡ Direct HTTP');
    }

    if (isProxied) {
      details.add('🔀 Proxied');
    }

    // Clean provider name (remove redundant resolution labels inside provider string)
    var cleanProvider = providerName
        .replaceAll(RegExp(r'\b(?:4K|1080p|720p|FHD|HD)\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\[\s*\]'), '')
        .replaceAll(RegExp(r'\s+-\s*$'), '')
        .trim();
    if (cleanProvider.isEmpty) cleanProvider = providerName;

    // 5. Build multi-line title for Nuvio stream card
    final titleLines = [
      sceneFilename,
      if (details.isNotEmpty) details.join(' • '),
      '🌐 Source: $cleanProvider',
    ];

    // 6. Built-in Header Badges: resolution, release, visual, audio, and language
    final headerBadges = <String>[];
    if (resolvedRes.isNotEmpty) {
      headerBadges.add(resolvedRes);
    }
    for (final b in ['Remux', 'BluRay', 'WEB-DL', 'DV', 'HDR10+', 'HDR', 'Atmos', 'DTS-HD', '5.1']) {
      if (detectedBadges.contains(b) && !headerBadges.contains(b)) {
        headerBadges.add(b);
      }
    }
    for (final l in ['Dual Audio', 'Multi Audio', 'Hindi', 'Tamil', 'Telugu', 'Malayalam', 'Kannada', 'English', 'Japanese']) {
      if (detectedBadges.contains(l) && !headerBadges.contains(l)) {
        headerBadges.add(l);
        break;
      }
    }
    final badgeHeader = headerBadges.take(4).map((b) => '[$b]').join(' ');
    final displayName = badgeHeader.isNotEmpty ? '$cleanProvider\n$badgeHeader' : cleanProvider;

    return {
      'name': displayName,
      'title': titleLines.join('\n'),
      'badgeHeader': badgeHeader.isNotEmpty ? badgeHeader : (resolvedRes.isNotEmpty ? '[$resolvedRes]' : ''),
    };
  }

  /// Formats a standardized scene-style release title so any media center
  /// correctly parses tokens (Resolution, Codec, Audio, Source)
  static String formatSceneFilename({
    required String title,
    int? year,
    int? season,
    int? episode,
    String? quality,
    String? codec,
    String? audio,
    String? originalFilename,
  }) {
    if (originalFilename != null && originalFilename.length > 10 && originalFilename.contains('.')) {
      var cleaned = originalFilename.replaceAll(RegExp(r'[\(\)\[\]]'), '.').replaceAll(RegExp(r'\.+'), '.');
      if (cleaned.endsWith('.')) cleaned = cleaned.substring(0, cleaned.length - 1);
      return cleaned;
    }

    final parts = <String>[];
    final cleanTitle = title.replaceAll(RegExp(r'[^\w\s]'), '').trim().replaceAll(RegExp(r'\s+'), '.');
    parts.add(cleanTitle);

    if (year != null) parts.add(year.toString());

    if (season != null && episode != null) {
      final s = season.toString().padLeft(2, '0');
      final e = episode.toString().padLeft(2, '0');
      parts.add('S${s}E$e');
    }

    final q = quality?.toUpperCase() ?? '';
    if (q.contains('2160') || q.contains('4K')) {
      parts.add('2160p.WEB-DL');
    } else if (q.contains('1080') || q.contains('FHD')) {
      parts.add('1080p.WEB-DL');
    } else if (q.contains('720') || q.contains('HD')) {
      parts.add('720p.WEBRip');
    } else {
      parts.add('1080p.WEB-DL');
    }

    if (audio != null && audio.isNotEmpty) {
      parts.add(audio.replaceAll(RegExp(r'[^\w\.]'), ''));
    } else {
      parts.add('DDP5.1');
    }

    if (codec != null && codec.isNotEmpty) {
      parts.add(codec);
    } else if (q.contains('2160') || q.contains('4K')) {
      parts.add('HEVC');
    } else {
      parts.add('x264');
    }

    parts.add('mkv');
    return parts.join('.');
  }
}

class BadgeFilter {
  final String id;
  final String groupId;
  final String name;
  final int priority;
  final RegExp pattern;

  BadgeFilter({
    required this.id,
    required this.groupId,
    required this.name,
    this.priority = 50,
    required this.pattern,
  });
}
