/// BadgeService: Evaluates stream metadata against Nuvio / NardBadges rules
/// and directly enriches the scraped links with high-fidelity badges,
/// technical audio/video specs, and clean scene formatting.
class BadgeService {
  static final List<BadgeFilter> filters = [
    // Resolution (gr) - mutually exclusive
    BadgeFilter(id: 'r-4k', groupId: 'gr', name: '4K', priority: 100, pattern: RegExp(r'\b(?:2160[pi]?|4k|uhd)\b', caseSensitive: false)),
    BadgeFilter(id: 'r-1080', groupId: 'gr', name: 'FHD', priority: 80, pattern: RegExp(r'\b(?:1080[pi]?|fhd|full[\s._-]?hd)\b', caseSensitive: false)),
    BadgeFilter(id: 'r-720', groupId: 'gr', name: 'HD', priority: 60, pattern: RegExp(r'\b720[pi]?\b', caseSensitive: false)),

    // Quality / Release Source (grl) - mutually exclusive
    BadgeFilter(id: 'q-remux', groupId: 'grl', name: 'Remux', priority: 100, pattern: RegExp(r'\bremux\b', caseSensitive: false)),
    BadgeFilter(id: 'q-bluray', groupId: 'grl', name: 'BluRay', priority: 80, pattern: RegExp(r'\b(?:bluray|blu[\s._-]?ray|bdrip)\b', caseSensitive: false)),
    BadgeFilter(id: 'q-webdl', groupId: 'grl', name: 'WEB-DL', priority: 60, pattern: RegExp(r'\b(?:web[\s._-]?dl|webdl)\b', caseSensitive: false)),
    BadgeFilter(id: 'q-webrip', groupId: 'grl', name: 'WEBRip', priority: 40, pattern: RegExp(r'\bweb[\s._-]?rip\b', caseSensitive: false)),
    BadgeFilter(id: 'q-hdtv', groupId: 'grl', name: 'HDTV', priority: 30, pattern: RegExp(r'\bhdtv\b', caseSensitive: false)),
    BadgeFilter(id: 'q-predvd', groupId: 'grl', name: 'PreDVD', priority: 20, pattern: RegExp(r'\b(?:predvd|pre-dvd|dvdrip)\b', caseSensitive: false)),
    BadgeFilter(id: 'q-tc', groupId: 'grl', name: 'TeleCine', priority: 15, pattern: RegExp(r'\b(?:tc|telecine|hdtc)\b', caseSensitive: false)),
    BadgeFilter(id: 'q-ts', groupId: 'grl', name: 'TeleSync', priority: 10, pattern: RegExp(r'\b(?:ts|telesync|hdts|hd-ts)\b', caseSensitive: false)),
    BadgeFilter(id: 'q-cam', groupId: 'grl', name: 'CAM', priority: 5, pattern: RegExp(r'\b(?:cam|camrip|hdcam|hd-cam)\b', caseSensitive: false)),

    // Visual Enhancements (gv)
    BadgeFilter(id: 'v-atmos-dv', groupId: 'gv', name: 'Atmos+DV', priority: 100, pattern: RegExp(r'(?=.*\batmos\b)(?=.*\b(?:dv|dovi|dolby[\s._-]?vision)\b)', caseSensitive: false)),
    BadgeFilter(id: 'v-dv', groupId: 'gv', name: 'DV', priority: 90, pattern: RegExp(r'\b(?:dv|dovi|dolby[\s._-]?vision)\b', caseSensitive: false)),
    BadgeFilter(id: 'v-hdr10p', groupId: 'gv', name: 'HDR10+', priority: 80, pattern: RegExp(r'hdr[\s._-]?10[\s._-]?(?:\+|plus)', caseSensitive: false)),
    BadgeFilter(id: 'v-hdr10', groupId: 'gv', name: 'HDR10', priority: 70, pattern: RegExp(r'hdr[\s._-]?10', caseSensitive: false)),
    BadgeFilter(id: 'v-hdr', groupId: 'gv', name: 'HDR', priority: 60, pattern: RegExp(r'\b(?:hdr|hlg|pq)\b', caseSensitive: false)),
    BadgeFilter(id: 'v-sdr', groupId: 'gv', name: 'SDR', priority: 55, pattern: RegExp(r'\bsdr\b', caseSensitive: false)),
    BadgeFilter(id: 'v-imax-e', groupId: 'gv', name: 'IMAX Enhanced', priority: 50, pattern: RegExp(r'imax[\s._-]?enhanced', caseSensitive: false)),
    BadgeFilter(id: 'v-imax', groupId: 'gv', name: 'IMAX', priority: 40, pattern: RegExp(r'\bimax\b', caseSensitive: false)),
    BadgeFilter(id: 'v-3d', groupId: 'gv', name: '3D', priority: 30, pattern: RegExp(r'\b(?:3d|sbs|half[\s._-]?sbs|hsbs)\b', caseSensitive: false)),

    // Video Codec (gvc) - mutually exclusive
    BadgeFilter(id: 'c-av1', groupId: 'gvc', name: 'AV1', priority: 100, pattern: RegExp(r'\bav1\b', caseSensitive: false)),
    BadgeFilter(id: 'c-hevc', groupId: 'gvc', name: 'HEVC', priority: 80, pattern: RegExp(r'\b(?:x265|hevc|h\.?265)\b', caseSensitive: false)),
    BadgeFilter(id: 'c-avc', groupId: 'gvc', name: 'AVC', priority: 60, pattern: RegExp(r'\b(?:x264|avc|h\.?264)\b', caseSensitive: false)),
    BadgeFilter(id: 'c-10bit', groupId: 'gvc', name: '10-Bit', priority: 50, pattern: RegExp(r'\b(?:10[\s._-]?bit|hi10p)\b', caseSensitive: false)),

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
    BadgeFilter(id: 'l-mar', groupId: 'gl', name: 'Marathi', priority: 80, pattern: RegExp(r'\bmarathi\b', caseSensitive: false)),
    BadgeFilter(id: 'l-guj', groupId: 'gl', name: 'Gujarati', priority: 80, pattern: RegExp(r'\bgujarati\b', caseSensitive: false)),
    BadgeFilter(id: 'l-bho', groupId: 'gl', name: 'Bhojpuri', priority: 80, pattern: RegExp(r'\bbhojpuri\b', caseSensitive: false)),
    BadgeFilter(id: 'l-urd', groupId: 'gl', name: 'Urdu', priority: 80, pattern: RegExp(r'\burdu\b', caseSensitive: false)),
    BadgeFilter(id: 'l-eng', groupId: 'gl', name: 'English', priority: 70, pattern: RegExp(r'\b(?:english|eng)\b', caseSensitive: false)),
    BadgeFilter(id: 'l-jap', groupId: 'gl', name: 'Japanese', priority: 70, pattern: RegExp(r'\b(?:japanese|jap)\b', caseSensitive: false)),

    // Stream Source Brands (gs) - Global & India Regional OTT
    BadgeFilter(id: 's-nflx', groupId: 'gs', name: 'NETFLIX', priority: 50, pattern: RegExp(r'\b(?:nflx|netflix)\b', caseSensitive: false)),
    BadgeFilter(id: 's-amzn', groupId: 'gs', name: 'PRIME', priority: 50, pattern: RegExp(r'\b(?:amzn|prime[\s._-]?video)\b', caseSensitive: false)),
    BadgeFilter(id: 's-atvp', groupId: 'gs', name: 'APPLE TV+', priority: 50, pattern: RegExp(r'\b(?:atvp|apple[\s._-]?tv)\b', caseSensitive: false)),
    BadgeFilter(id: 's-dsnp', groupId: 'gs', name: 'DISNEY+', priority: 50, pattern: RegExp(r'\b(?:dsnp|disney[\s._-]?(?:\+|plus))\b', caseSensitive: false)),
    BadgeFilter(id: 's-hmax', groupId: 'gs', name: 'MAX', priority: 50, pattern: RegExp(r'\b(?:hmax|hbomax|hbo[\s._-]?max)\b', caseSensitive: false)),
    BadgeFilter(id: 's-hulu', groupId: 'gs', name: 'HULU', priority: 50, pattern: RegExp(r'\bhulu\b', caseSensitive: false)),
    BadgeFilter(id: 's-hotstar', groupId: 'gs', name: 'HOTSTAR', priority: 50, pattern: RegExp(r'\b(?:hotstar|disney[\s._-]?hotstar|jio[\s._-]?hotstar)\b', caseSensitive: false)),
    BadgeFilter(id: 's-sonyliv', groupId: 'gs', name: 'SONYLIV', priority: 50, pattern: RegExp(r'\b(?:sonyliv|sony[\s._-]?liv)\b', caseSensitive: false)),
    BadgeFilter(id: 's-zee5', groupId: 'gs', name: 'ZEE5', priority: 50, pattern: RegExp(r'\bzee5\b', caseSensitive: false)),
    BadgeFilter(id: 's-jio', groupId: 'gs', name: 'JIOCINEMA', priority: 50, pattern: RegExp(r'\b(?:jio(?:cinema)?|jiovideo)\b', caseSensitive: false)),
    BadgeFilter(id: 's-sunnxt', groupId: 'gs', name: 'SUNNXT', priority: 50, pattern: RegExp(r'\b(?:sun[\s._-]?nxt|sunnxt)\b', caseSensitive: false)),
    BadgeFilter(id: 's-aha', groupId: 'gs', name: 'AHA', priority: 50, pattern: RegExp(r'\b(?:aha|ahavideo)\b', caseSensitive: false)),
    BadgeFilter(id: 's-hoichoi', groupId: 'gs', name: 'HOICHOI', priority: 50, pattern: RegExp(r'\bhoichoi\b', caseSensitive: false)),
    BadgeFilter(id: 's-manorama', groupId: 'gs', name: 'MANORAMAMAX', priority: 50, pattern: RegExp(r'\b(?:manorama[\s._-]?max|manoramamax)\b', caseSensitive: false)),
    BadgeFilter(id: 's-chaupal', groupId: 'gs', name: 'CHAUPAL', priority: 50, pattern: RegExp(r'\bchaupal\b', caseSensitive: false)),
    BadgeFilter(id: 's-planetm', groupId: 'gs', name: 'PLANET MARATHI', priority: 50, pattern: RegExp(r'\b(?:planet[\s._-]?marathi)\b', caseSensitive: false)),
    BadgeFilter(id: 's-mx', groupId: 'gs', name: 'MX PLAYER', priority: 50, pattern: RegExp(r'\b(?:mx[\s._-]?player|mxplayer)\b', caseSensitive: false)),
    BadgeFilter(id: 's-lionsgate', groupId: 'gs', name: 'LIONSGATE', priority: 50, pattern: RegExp(r'\b(?:lionsgate|lionsgateplay)\b', caseSensitive: false)),
    BadgeFilter(id: 's-shemaroo', groupId: 'gs', name: 'SHEMAROOME', priority: 50, pattern: RegExp(r'\b(?:shemaroo(?:me)?)\b', caseSensitive: false)),
    BadgeFilter(id: 's-voot', groupId: 'gs', name: 'VOOT', priority: 50, pattern: RegExp(r'\bvoot\b', caseSensitive: false)),
    BadgeFilter(id: 's-eros', groupId: 'gs', name: 'EROS NOW', priority: 50, pattern: RegExp(r'\b(?:eros[\s._-]?now|erosnow)\b', caseSensitive: false)),
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

  static const List<String> ottBrandNames = [
    'NETFLIX', 'HOTSTAR', 'PRIME', 'JIOCINEMA', 'SONYLIV', 'ZEE5', 'AHA',
    'SUNNXT', 'HOICHOI', 'APPLE TV+', 'DISNEY+', 'CRUNCHYROLL', 'MAX', 'HULU',
    'MANORAMAMAX', 'CHAUPAL', 'PLANET MARATHI', 'MX PLAYER', 'LIONSGATE',
    'SHEMAROOME', 'VOOT', 'EROS NOW'
  ];

  static String? normalizeOttPlatform(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final s = raw.toLowerCase().trim();
    if (s.contains('netflix') || s == 'nflx') return 'NETFLIX';
    if (s.contains('hotstar') || s.contains('disney')) return 'HOTSTAR';
    if (s.contains('prime') || s.contains('amazon')) return 'PRIME';
    if (s.contains('jiocinema') || s.contains('jio cinema')) return 'JIOCINEMA';
    if (s.contains('sonyliv') || s.contains('sony liv') || s == 'sony') return 'SONYLIV';
    if (s.contains('zee5') || s.contains('zee 5') || s == 'zee') return 'ZEE5';
    if (s.contains('aha')) return 'AHA';
    if (s.contains('sun nxt') || s.contains('sunnxt')) return 'SUNNXT';
    if (s.contains('hoichoi')) return 'HOICHOI';
    if (s.contains('apple tv') || s.contains('atvp') || s == 'apple') return 'APPLE TV+';
    if (s.contains('crunchyroll')) return 'CRUNCHYROLL';
    if (s.contains('max') || s.contains('hbo')) return 'MAX';
    if (s.contains('hulu')) return 'HULU';
    if (s.contains('manorama')) return 'MANORAMAMAX';
    if (s.contains('chaupal')) return 'CHAUPAL';
    if (s.contains('planet marathi')) return 'PLANET MARATHI';
    if (s.contains('mx player') || s == 'mxplayer') return 'MX PLAYER';
    if (s.contains('lionsgate')) return 'LIONSGATE';
    return null;
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
    String? ottPlatform,
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

    // Detect OTT platform: from detectedBadges in filename OR from API-detected ottPlatform
    String? effectiveOtt;
    for (final b in ottBrandNames) {
      if (detectedBadges.contains(b)) {
        effectiveOtt = b;
        break;
      }
    }
    effectiveOtt ??= normalizeOttPlatform(ottPlatform);

    // 3. Assemble badge pills
    final badgePills = detectedBadges.map((b) => '[$b]').join(' ');

    // 4. Line 2: Details & Badges
    final details = <String>[];
    if (effectiveOtt != null && effectiveOtt.isNotEmpty) {
      details.add('🏷️ $effectiveOtt');
    }
    if (badgePills.isNotEmpty) {
      details.add(badgePills);
    } else if (resolvedRes.isNotEmpty) {
      details.add('[$resolvedRes]');
    }

    if (fileSize != null && fileSize.isNotEmpty) {
      details.add('💾 $fileSize');
    }

    if (isCached) {
      details.add('⚡ TorBox Cached');
    } else if (providerName.toLowerCase().contains('cachable')) {
      details.add('🌐 TorBox Cachable');
    } else if (isHls) {
      details.add('🌐 HLS Stream');
    } else {
      details.add('🌐 Direct HTTP');
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

    // 6. Built-in Header Badges: [OTT] [Resolution] [Release] [Visual] [Audio] [Language]
    final headerBadges = <String>[];
    if (effectiveOtt != null && effectiveOtt.isNotEmpty) {
      headerBadges.add(effectiveOtt);
    }
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
    final badgeHeader = headerBadges.take(5).map((b) => '[$b]').join(' ');
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
