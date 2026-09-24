/// BadgeService: Evaluates stream metadata against Nuvio / NardBadges rules
/// and directly enriches the scraped links with high-fidelity badges,
/// technical audio/video specs, and clean scene formatting.
class BadgeService {
  static final List<BadgeFilter> filters = [
    // Resolution (gr)
    BadgeFilter(id: 'r-4k', groupId: 'gr', name: '4K', pattern: RegExp(r'(?:2160[pi]?|4k|uhd)', caseSensitive: false)),
    BadgeFilter(id: 'r-1080', groupId: 'gr', name: 'FHD', pattern: RegExp(r'(?:1080[pi]?|fhd|full[ ._-]?hd)', caseSensitive: false)),
    BadgeFilter(id: 'r-720', groupId: 'gr', name: 'HD', pattern: RegExp(r'720[pi]?', caseSensitive: false)),

    // Quality / Release Source (grl)
    BadgeFilter(id: 'q-remux', groupId: 'grl', name: 'Remux', pattern: RegExp(r'\bremux\b', caseSensitive: false)),
    BadgeFilter(id: 'q-bluray', groupId: 'grl', name: 'BluRay', pattern: RegExp(r'\b(?:bluray|blu-ray|bdrip)\b', caseSensitive: false)),
    BadgeFilter(id: 'q-webdl', groupId: 'grl', name: 'WEB-DL', pattern: RegExp(r'\b(?:web[-_. ]?dl|webdl)\b', caseSensitive: false)),
    BadgeFilter(id: 'q-webrip', groupId: 'grl', name: 'WEBRip', pattern: RegExp(r'\bweb[-_. ]?rip\b', caseSensitive: false)),

    // Visual Enhancements (gv)
    BadgeFilter(id: 'v-atmos-dv', groupId: 'gv', name: 'Atmos+DV', pattern: RegExp(r'(?=.*atmos)(?=.*(?:dv|dovi|dolby[\s._-]?vision))', caseSensitive: false)),
    BadgeFilter(id: 'v-dv', groupId: 'gv', name: 'Dolby Vision', pattern: RegExp(r'\b(?:dv|dovi|dolby[\s._-]?vision)\b', caseSensitive: false)),
    BadgeFilter(id: 'v-hdr10p', groupId: 'gv', name: 'HDR10+', pattern: RegExp(r'hdr[\s._-]?10[\s._-]?(?:\+|plus)', caseSensitive: false)),
    BadgeFilter(id: 'v-hdr10', groupId: 'gv', name: 'HDR10', pattern: RegExp(r'hdr[\s._-]?10', caseSensitive: false)),
    BadgeFilter(id: 'v-hdr', groupId: 'gv', name: 'HDR', pattern: RegExp(r'\b(?:hdr|hlg|pq)\b', caseSensitive: false)),
    BadgeFilter(id: 'v-imax-e', groupId: 'gv', name: 'IMAX Enhanced', pattern: RegExp(r'imax[\s._-]?enhanced', caseSensitive: false)),
    BadgeFilter(id: 'v-imax', groupId: 'gv', name: 'IMAX', pattern: RegExp(r'\bimax\b', caseSensitive: false)),
    BadgeFilter(id: 'v-3d', groupId: 'gv', name: '3D', pattern: RegExp(r'\b(?:3d|sbs|half[-_. ]?sbs|hsbs)\b', caseSensitive: false)),

    // Video Codec (gvc)
    BadgeFilter(id: 'c-hevc', groupId: 'gvc', name: 'HEVC', pattern: RegExp(r'\b(?:x265|hevc|h\.?265)\b', caseSensitive: false)),
    BadgeFilter(id: 'c-avc', groupId: 'gvc', name: 'AVC', pattern: RegExp(r'\b(?:x264|avc|h\.?264)\b', caseSensitive: false)),
    BadgeFilter(id: 'c-av1', groupId: 'gvc', name: 'AV1', pattern: RegExp(r'\bav1\b', caseSensitive: false)),

    // Audio Codec (ga)
    BadgeFilter(id: 'a-atmos', groupId: 'ga', name: 'Atmos', pattern: RegExp(r'\batmos\b', caseSensitive: false)),
    BadgeFilter(id: 'a-truehd', groupId: 'ga', name: 'TrueHD', pattern: RegExp(r'\btrue[\s._-]?hd\b', caseSensitive: false)),
    BadgeFilter(id: 'a-dtsx', groupId: 'ga', name: 'DTS:X', pattern: RegExp(r'\bdts[-_.: ]?x\b', caseSensitive: false)),
    BadgeFilter(id: 'a-dtshd', groupId: 'ga', name: 'DTS-HD', pattern: RegExp(r'\bdts[-_. ]?hd\b', caseSensitive: false)),
    BadgeFilter(id: 'a-dts', groupId: 'ga', name: 'DTS', pattern: RegExp(r'\bdts\b', caseSensitive: false)),
    BadgeFilter(id: 'a-ddp', groupId: 'ga', name: 'DD+', pattern: RegExp(r'\b(?:ddp\d?|dd\+|eac3|e-ac3|dolby[\s._-]?digital[\s._-]?plus)\b', caseSensitive: false)),
    BadgeFilter(id: 'a-dd', groupId: 'ga', name: 'DD', pattern: RegExp(r'\b(?:dd[25]?|ac3|dolby[\s._-]?digital)\b', caseSensitive: false)),
    BadgeFilter(id: 'a-aac', groupId: 'ga', name: 'AAC', pattern: RegExp(r'\baac\b', caseSensitive: false)),
    BadgeFilter(id: 'a-flac', groupId: 'ga', name: 'FLAC', pattern: RegExp(r'\bflac\b', caseSensitive: false)),

    // Audio Channels (gc)
    BadgeFilter(id: 'ch-71', groupId: 'gc', name: '7.1', pattern: RegExp(r'\b7\.1\b', caseSensitive: false)),
    BadgeFilter(id: 'ch-51', groupId: 'gc', name: '5.1', pattern: RegExp(r'\b5\.1\b', caseSensitive: false)),
    BadgeFilter(id: 'ch-20', groupId: 'gc', name: '2.0', pattern: RegExp(r'\b2\.0\b', caseSensitive: false)),

    // Stream Source Brands (gs)
    BadgeFilter(id: 's-nflx', groupId: 'gs', name: 'NETFLIX', pattern: RegExp(r'\b(?:nflx|netflix)\b', caseSensitive: false)),
    BadgeFilter(id: 's-amzn', groupId: 'gs', name: 'PRIME', pattern: RegExp(r'\b(?:amzn|prime[\s._-]?video)\b', caseSensitive: false)),
    BadgeFilter(id: 's-atvp', groupId: 'gs', name: 'APPLE TV+', pattern: RegExp(r'\b(?:atvp|apple[\s._-]?tv)\b', caseSensitive: false)),
    BadgeFilter(id: 's-dsnp', groupId: 'gs', name: 'DISNEY+', pattern: RegExp(r'\b(?:dsnp|disney[\s._-]?(?:\+|plus))\b', caseSensitive: false)),
    BadgeFilter(id: 's-hmax', groupId: 'gs', name: 'MAX', pattern: RegExp(r'\b(?:hmax|hbomax|hbo[\s._-]?max)\b', caseSensitive: false)),
    BadgeFilter(id: 's-hulu', groupId: 'gs', name: 'HULU', pattern: RegExp(r'\bhulu\b', caseSensitive: false)),
    BadgeFilter(id: 's-hotstar', groupId: 'gs', name: 'HOTSTAR', pattern: RegExp(r'\b(?:hotstar|disney[\s._-]?hotstar)\b', caseSensitive: false)),
    BadgeFilter(id: 's-sonyliv', groupId: 'gs', name: 'SONYLIV', pattern: RegExp(r'\bsonyliv\b', caseSensitive: false)),
    BadgeFilter(id: 's-zee5', groupId: 'gs', name: 'ZEE5', pattern: RegExp(r'\bzee5\b', caseSensitive: false)),
    BadgeFilter(id: 's-jio', groupId: 'gs', name: 'JIOCINEMA', pattern: RegExp(r'\bjio(?:cinema)?\b', caseSensitive: false)),
  ];

  /// Detects matching badges from the input text and returns distinct badge tags
  static List<String> getBadges(String text) {
    final matched = <String>[];
    for (final f in filters) {
      if (f.pattern.hasMatch(text)) {
        if (!matched.contains(f.name)) {
          matched.add(f.name);
        }
      }
    }
    return matched;
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
    // 1. Build standardized clean scene filename
    final sceneFilename = formatSceneFilename(
      title: mediaTitle,
      year: year,
      season: season,
      episode: episode,
      quality: quality,
      codec: codec,
      audio: audioBadge,
      originalFilename: (rawTitle.contains('.') && !rawTitle.contains('Direct Cloud') && !rawTitle.contains('\n'))
          ? rawTitle
          : null,
    );

    // 2. Evaluate all JSON badge filters against filename and raw text
    final fullText = '$sceneFilename $rawTitle ${quality ?? ""} ${audioBadge ?? ""} ${codec ?? ""}';
    final detectedBadges = getBadges(fullText);

    // 3. Assemble badge pills
    final badgePills = detectedBadges.map((b) => '[$b]').join(' ');

    // 4. Line 2: Details & Badges
    final details = <String>[];
    if (badgePills.isNotEmpty) {
      details.add(badgePills);
    } else if (quality != null && quality.isNotEmpty) {
      details.add('[$quality]');
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

    // 5. Build multi-line title for Nuvio stream card
    final titleLines = [
      sceneFilename,
      if (details.isNotEmpty) details.join(' • '),
      '🌐 Source: $providerName',
    ];

    // 6. Name: Only provider name and resolution (zero mentions of saket or sakinator)
    final q = quality ?? (detectedBadges.contains('4K') ? '4K UHD' : (detectedBadges.contains('FHD') ? '1080p' : ''));
    final displayName = q.isNotEmpty ? '$providerName\n$q' : providerName;

    return {
      'name': displayName,
      'title': titleLines.join('\n'),
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
      parts.add(audio);
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
  final RegExp pattern;

  BadgeFilter({
    required this.id,
    required this.groupId,
    required this.name,
    required this.pattern,
  });
}
