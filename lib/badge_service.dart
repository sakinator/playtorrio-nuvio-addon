/// BadgeService: Evaluates stream metadata against Nuvio / NardBadges rules
/// and provides badges and standardized filename formatting.
class BadgeService {
  static final List<BadgeFilter> filters = [
    // Resolution
    BadgeFilter(id: 'r-4k', name: '4K', pattern: RegExp(r'(?:2160[pi]?|4k|uhd)', caseSensitive: false)),
    BadgeFilter(id: 'r-1080', name: 'FHD', pattern: RegExp(r'(?:1080[pi]?|fhd|full[ ._-]?hd)', caseSensitive: false)),
    BadgeFilter(id: 'r-720', name: 'HD', pattern: RegExp(r'720[pi]?', caseSensitive: false)),

    // Quality / Source
    BadgeFilter(id: 'q-remux', name: 'Remux', pattern: RegExp(r'\bremux\b', caseSensitive: false)),
    BadgeFilter(id: 'q-bluray', name: 'BluRay', pattern: RegExp(r'\b(?:bluray|blu-ray|bdrip)\b', caseSensitive: false)),
    BadgeFilter(id: 'q-webdl', name: 'WEB-DL', pattern: RegExp(r'\b(?:web[-_. ]?dl|webdl)\b', caseSensitive: false)),
    BadgeFilter(id: 'q-webrip', name: 'WEBRip', pattern: RegExp(r'\bweb[-_. ]?rip\b', caseSensitive: false)),

    // Visual
    BadgeFilter(id: 'v-atmos-dv', name: 'Atmos+DV', pattern: RegExp(r'(?=.*atmos)(?=.*(?:dv|dovi|dolby[\s._-]?vision))', caseSensitive: false)),
    BadgeFilter(id: 'v-dv', name: 'Dolby Vision', pattern: RegExp(r'\b(?:dv|dovi|dolby[\s._-]?vision)\b', caseSensitive: false)),
    BadgeFilter(id: 'v-hdr10p', name: 'HDR10+', pattern: RegExp(r'hdr[\s._-]?10[\s._-]?(?:\+|plus)', caseSensitive: false)),
    BadgeFilter(id: 'v-hdr10', name: 'HDR10', pattern: RegExp(r'hdr[\s._-]?10', caseSensitive: false)),
    BadgeFilter(id: 'v-hdr', name: 'HDR', pattern: RegExp(r'\b(?:hdr|hlg|pq)\b', caseSensitive: false)),
    BadgeFilter(id: 'v-imax-e', name: 'IMAX Enhanced', pattern: RegExp(r'imax[\s._-]?enhanced', caseSensitive: false)),
    BadgeFilter(id: 'v-imax', name: 'IMAX', pattern: RegExp(r'\bimax\b', caseSensitive: false)),

    // Video Codec
    BadgeFilter(id: 'c-hevc', name: 'HEVC', pattern: RegExp(r'\b(?:x265|hevc|h\.?265)\b', caseSensitive: false)),
    BadgeFilter(id: 'c-avc', name: 'AVC', pattern: RegExp(r'\b(?:x264|avc|h\.?264)\b', caseSensitive: false)),
    BadgeFilter(id: 'c-av1', name: 'AV1', pattern: RegExp(r'\bav1\b', caseSensitive: false)),

    // Audio Codec
    BadgeFilter(id: 'a-atmos', name: 'Atmos', pattern: RegExp(r'\batmos\b', caseSensitive: false)),
    BadgeFilter(id: 'a-truehd', name: 'TrueHD', pattern: RegExp(r'\btrue[\s._-]?hd\b', caseSensitive: false)),
    BadgeFilter(id: 'a-dtsx', name: 'DTS:X', pattern: RegExp(r'\bdts[-_.: ]?x\b', caseSensitive: false)),
    BadgeFilter(id: 'a-dtshd', name: 'DTS-HD', pattern: RegExp(r'\bdts[-_. ]?hd\b', caseSensitive: false)),
    BadgeFilter(id: 'a-dts', name: 'DTS', pattern: RegExp(r'\bdts\b', caseSensitive: false)),
    BadgeFilter(id: 'a-ddp', name: 'DD+', pattern: RegExp(r'\b(?:ddp\d?|dd\+|eac3|e-ac3|dolby[\s._-]?digital[\s._-]?plus)\b', caseSensitive: false)),
    BadgeFilter(id: 'a-dd', name: 'DD', pattern: RegExp(r'\b(?:dd[25]?|ac3|dolby[\s._-]?digital)\b', caseSensitive: false)),
    BadgeFilter(id: 'a-aac', name: 'AAC', pattern: RegExp(r'\baac\b', caseSensitive: false)),
    BadgeFilter(id: 'a-flac', name: 'FLAC', pattern: RegExp(r'\bflac\b', caseSensitive: false)),

    // Audio Channels
    BadgeFilter(id: 'ch-71', name: '7.1', pattern: RegExp(r'\b7\.1\b', caseSensitive: false)),
    BadgeFilter(id: 'ch-51', name: '5.1', pattern: RegExp(r'\b5\.1\b', caseSensitive: false)),
    BadgeFilter(id: 'ch-20', name: '2.0', pattern: RegExp(r'\b2\.0\b', caseSensitive: false)),

    // Stream Services
    BadgeFilter(id: 's-nflx', name: 'NETFLIX', pattern: RegExp(r'\b(?:nflx|netflix)\b', caseSensitive: false)),
    BadgeFilter(id: 's-amzn', name: 'PRIME', pattern: RegExp(r'\b(?:amzn|prime[\s._-]?video)\b', caseSensitive: false)),
    BadgeFilter(id: 's-atvp', name: 'APPLE TV+', pattern: RegExp(r'\b(?:atvp|apple[\s._-]?tv)\b', caseSensitive: false)),
    BadgeFilter(id: 's-dsnp', name: 'DISNEY+', pattern: RegExp(r'\b(?:dsnp|disney[\s._-]?(?:\+|plus))\b', caseSensitive: false)),
    BadgeFilter(id: 's-hmax', name: 'MAX', pattern: RegExp(r'\b(?:hmax|hbomax|hbo[\s._-]?max)\b', caseSensitive: false)),
    BadgeFilter(id: 's-hulu', name: 'HULU', pattern: RegExp(r'\bhulu\b', caseSensitive: false)),
    BadgeFilter(id: 's-hotstar', name: 'HOTSTAR', pattern: RegExp(r'\b(?:hotstar|disney[\s._-]?hotstar)\b', caseSensitive: false)),
    BadgeFilter(id: 's-sonyliv', name: 'SONYLIV', pattern: RegExp(r'\bsonyliv\b', caseSensitive: false)),
    BadgeFilter(id: 's-zee5', name: 'ZEE5', pattern: RegExp(r'\bzee5\b', caseSensitive: false)),
    BadgeFilter(id: 's-jio', name: 'JIOCINEMA', pattern: RegExp(r'\bjio(?:cinema)?\b', caseSensitive: false)),
  ];

  /// Detects matching badges from the input text
  static List<String> getBadges(String text) {
    final matched = <String>[];
    for (final f in filters) {
      if (f.pattern.hasMatch(text)) {
        matched.add(f.name);
      }
    }
    return matched;
  }

  /// Formats a standardized scene-style release title so Nuvio's badge system matches perfectly
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
    // If the original already looks like a valid release filename, preserve and clean it
    if (originalFilename != null && originalFilename.length > 10 && originalFilename.contains('.')) {
      var cleaned = originalFilename.replaceAll(RegExp(r'[\(\)\[\]]'), '.').replaceAll(RegExp(r'\.+'), '.');
      if (cleaned.endsWith('.')) cleaned = cleaned.substring(0, cleaned.length - 1);
      return cleaned;
    }

    final parts = <String>[];
    // Clean title with dots
    final cleanTitle = title.replaceAll(RegExp(r'[^\w\s]'), '').trim().replaceAll(RegExp(r'\s+'), '.');
    parts.add(cleanTitle);

    if (year != null) {
      parts.add(year.toString());
    }

    if (season != null && episode != null) {
      final s = season.toString().padLeft(2, '0');
      final e = episode.toString().padLeft(2, '0');
      parts.add('S${s}E$e');
    }

    // Resolution / Quality
    final q = quality?.toUpperCase() ?? '';
    if (q.contains('2160') || q.contains('4K')) {
      parts.add('2160p');
      parts.add('WEB-DL');
    } else if (q.contains('1080') || q.contains('FHD')) {
      parts.add('1080p');
      parts.add('WEB-DL');
    } else if (q.contains('720') || q.contains('HD')) {
      parts.add('720p');
      parts.add('WEBRip');
    } else {
      parts.add('1080p');
      parts.add('WEB-DL');
    }

    // Audio & Codec
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
  final String name;
  final RegExp pattern;

  BadgeFilter({
    required this.id,
    required this.name,
    required this.pattern,
  });
}
