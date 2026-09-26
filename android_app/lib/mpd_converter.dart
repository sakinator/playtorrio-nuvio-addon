import 'dart:convert';
import 'package:html/parser.dart' as html_parser;

/// Converts MPEG-DASH (.mpd) XML manifests into virtual Apple HLS (.m3u8) playlists.
///
/// Enables seamless playback in Nuvio, Apple AVPlayer, and standard HLS video players
/// without requiring external DASH plugins or Widevine players for clear DASH streams.
class MpdConverter {
  /// Checks whether a given body or content-type represents an MPEG-DASH manifest.
  static bool isMpd(String contentType, String body) {
    if (contentType.toLowerCase().contains('dash+xml')) return true;
    final trimmed = body.trim();
    return trimmed.startsWith('<MPD') || trimmed.contains('<MPD ') || trimmed.contains('<MPD\n');
  }

  /// Converts a DASH MPD manifest string into an HLS Master Playlist or Media Playlist.
  static String convertMpdToHls({
    required String mpdXml,
    required Uri baseUri,
    required String proxyBaseUrl,
    required String customHeadersJson,
    String? selectedRepId,
  }) {
    final doc = html_parser.parseFragment(mpdXml);
    final mpdEl = doc.querySelector('mpd');
    if (mpdEl == null) {
      return mpdXml;
    }

    // Parse presentation duration (e.g. PT1H30M25.5S or PT5425.5S)
    final durationStr = mpdEl.attributes['mediapresentationduration'] ?? '';
    final totalSeconds = _parseIsoDuration(durationStr);

    final representations = doc.querySelectorAll('representation');
    if (representations.isEmpty) {
      return mpdXml;
    }

    // If no specific representation is requested, output a Master Playlist (#EXT-X-STREAM-INF)
    if (selectedRepId == null) {
      final buffer = StringBuffer();
      buffer.writeln('#EXTM3U');
      buffer.writeln('#EXT-X-VERSION:6');
      buffer.writeln('#EXT-X-INDEPENDENT-SEGMENTS');

      for (final rep in representations) {
        final id = rep.attributes['id'] ?? 'rep_${representations.indexOf(rep)}';
        final bandwidth = rep.attributes['bandwidth'] ?? '1500000';
        final width = rep.attributes['width'];
        final height = rep.attributes['height'];
        final codecs = rep.attributes['codecs'] ?? 'avc1.4d401f,mp4a.40.2';

        final streamInf = StringBuffer('#EXT-X-STREAM-INF:BANDWIDTH=$bandwidth,CODECS="$codecs"');
        if (width != null && height != null) {
          streamInf.write(',RESOLUTION=${width}x$height');
        }
        buffer.writeln(streamInf.toString());

        final variantUrl = '$proxyBaseUrl?url=${Uri.encodeComponent(baseUri.toString())}'
            '&rep_id=${Uri.encodeComponent(id)}'
            '${customHeadersJson.isNotEmpty ? '&headers=${Uri.encodeComponent(customHeadersJson)}' : ''}';
        buffer.writeln(variantUrl);
      }

      return buffer.toString();
    }

    // Otherwise, generate the Media Playlist for the requested representation
    final targetRep = representations.firstWhere(
      (r) => r.attributes['id'] == selectedRepId,
      orElse: () => representations.first,
    );

    // Look for SegmentTemplate inside representation or parent AdaptationSet
    var segTemplate = targetRep.querySelector('segmenttemplate') ??
        targetRep.parent?.querySelector('segmenttemplate');

    final timescale = int.tryParse(segTemplate?.attributes['timescale'] ?? '1000') ?? 1000;
    final segDuration = int.tryParse(segTemplate?.attributes['duration'] ?? '4000') ?? 4000;
    final startNumber = int.tryParse(segTemplate?.attributes['startnumber'] ?? '1') ?? 1;
    final mediaTemplate = segTemplate?.attributes['media'] ?? 'segment_\$Number\$.m4s';
    final initTemplate = segTemplate?.attributes['initialization'] ?? 'init.mp4';

    final segmentDurationSeconds = segDuration / timescale;
    final targetDuration = segmentDurationSeconds.ceil();

    final buffer = StringBuffer();
    buffer.writeln('#EXTM3U');
    buffer.writeln('#EXT-X-VERSION:6');
    buffer.writeln('#EXT-X-TARGETDURATION:$targetDuration');
    buffer.writeln('#EXT-X-MEDIA-SEQUENCE:$startNumber');

    // Init segment (MAP tag)
    final repId = targetRep.attributes['id'] ?? selectedRepId;
    final initResolved = initTemplate
        .replaceAll('\$RepresentationID\$', repId)
        .replaceAll('\$Number\$', '0');
    final initUrl = baseUri.resolve(initResolved).toString();
    final proxiedInit = '$proxyBaseUrl?url=${Uri.encodeComponent(initUrl)}'
        '${customHeadersJson.isNotEmpty ? '&headers=${Uri.encodeComponent(customHeadersJson)}' : ''}';
    buffer.writeln('#EXT-X-MAP:URI="$proxiedInit"');

    // Segment list
    final numSegments = totalSeconds > 0
        ? (totalSeconds / segmentDurationSeconds).ceil()
        : 60; // Default segment count if duration unknown

    for (int i = 0; i < numSegments; i++) {
      final currentNum = startNumber + i;
      final segResolved = mediaTemplate
          .replaceAll('\$RepresentationID\$', repId)
          .replaceAll('\$Number\$', currentNum.toString())
          .replaceAllMapped(RegExp(r'\$Number%0(\d+)d\$'), (Match m) {
            final pad = int.tryParse(m.group(1) ?? '1') ?? 1;
            return currentNum.toString().padLeft(pad, '0');
          });

      final segmentUrl = baseUri.resolve(segResolved).toString();
      final proxiedSegment = '$proxyBaseUrl?url=${Uri.encodeComponent(segmentUrl)}'
          '${customHeadersJson.isNotEmpty ? '&headers=${Uri.encodeComponent(customHeadersJson)}' : ''}';

      buffer.writeln('#EXTINF:${segmentDurationSeconds.toStringAsFixed(3)},');
      buffer.writeln(proxiedSegment);
    }

    buffer.writeln('#EXT-X-ENDLIST');
    return buffer.toString();
  }

  static double _parseIsoDuration(String iso) {
    if (iso.isEmpty) return 0.0;
    try {
      final match = RegExp(r'PT(?:(\d+)H)?(?:(\d+)M)?(?:([\d.]+)S)?').firstMatch(iso);
      if (match != null) {
        final hours = double.tryParse(match.group(1) ?? '0') ?? 0;
        final minutes = double.tryParse(match.group(2) ?? '0') ?? 0;
        final seconds = double.tryParse(match.group(3) ?? '0') ?? 0;
        return (hours * 3600) + (minutes * 60) + seconds;
      }
    } catch (_) {}
    return 0.0;
  }
}
