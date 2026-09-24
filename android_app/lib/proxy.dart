import 'dart:convert';
import 'dart:io';

class StreamProxy {
  static final HttpClient _client = HttpClient()
    ..badCertificateCallback = ((X509Certificate cert, String host, int port) => true)
    ..userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36'
    ..connectionTimeout = const Duration(seconds: 15);

  /// Handles incoming /proxy HTTP requests.
  static Future<void> handleRequest(HttpRequest request) async {
    final query = request.uri.queryParameters;
    final targetUrl = query['url'];

    if (targetUrl == null || targetUrl.isEmpty) {
      request.response
        ..statusCode = HttpStatus.badRequest
        ..write('Missing "url" query parameter')
        ..close();
      return;
    }

    Uri targetUri;
    try {
      targetUri = Uri.parse(targetUrl);
    } catch (e) {
      request.response
        ..statusCode = HttpStatus.badRequest
        ..write('Invalid target url: $e')
        ..close();
      return;
    }

    Map<String, String> customHeaders = {};
    if (query['headers'] != null && query['headers']!.isNotEmpty) {
      try {
        final decoded = jsonDecode(query['headers']!) as Map;
        customHeaders = decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
      } catch (_) {}
    }

    try {
      final req = await _client.getUrl(targetUri);

      // Forward request headers
      request.headers.forEach((name, values) {
        final lower = name.toLowerCase();
        if (lower != 'host' && lower != 'connection' && lower != 'content-length') {
          for (final val in values) {
            req.headers.add(name, val);
          }
        }
      });

      // Apply custom headers (e.g. Referer, Origin, User-Agent)
      customHeaders.forEach((name, value) {
        req.headers.set(name, value);
      });

      final res = await req.close();

      request.response.statusCode = res.statusCode;

      // Copy response headers
      res.headers.forEach((name, values) {
        final lower = name.toLowerCase();
        if (lower != 'connection' && lower != 'transfer-encoding') {
          for (final val in values) {
            request.response.headers.add(name, val);
          }
        }
      });

      // Ensure CORS for Nuvio web/app
      request.response.headers.set('Access-Control-Allow-Origin', '*');
      request.response.headers.set('Access-Control-Allow-Methods', 'GET, HEAD, OPTIONS');
      request.response.headers.set('Access-Control-Allow-Headers', '*');

      final contentType = res.headers.contentType?.mimeType.toLowerCase() ?? '';
      final isHls = contentType.contains('mpegurl') || targetUrl.contains('.m3u8');

      if (isHls && res.statusCode == HttpStatus.ok) {
        // Rewrite HLS playlist relative URLs
        final bytes = await res.fold<List<int>>([], (prev, elem) => prev..addAll(elem));
        final body = utf8.decode(bytes, allowMalformed: true);
        final rewritten = _rewriteHlsPlaylist(
          body: body,
          baseUri: targetUri,
          proxyBaseUrl: '${request.requestedUri.scheme}://${request.requestedUri.host}:${request.requestedUri.port}/proxy',
          customHeadersJson: query['headers'] ?? '',
        );
        request.response.headers.contentLength = utf8.encode(rewritten).length;
        request.response.write(rewritten);
        await request.response.close();
      } else {
        await request.response.addStream(res);
        await request.response.close();
      }
    } catch (e) {
      if (!request.response.headers.chunkedTransferEncoding) {
        request.response
          ..statusCode = HttpStatus.badGateway
          ..write('Proxy error: $e')
          ..close();
      }
    }
  }

  static String _rewriteHlsPlaylist({
    required String body,
    required Uri baseUri,
    required String proxyBaseUrl,
    required String customHeadersJson,
  }) {
    final lines = body.split('\n');
    final out = <String>[];

    for (var line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        out.add(line);
        continue;
      }

      if (trimmed.startsWith('#')) {
        // Check for URI in tags like #EXT-X-KEY:METHOD=AES-128,URI="..."
        if (trimmed.contains('URI="')) {
          final rewrittenTag = trimmed.replaceAllMapped(
            RegExp(r'URI="([^"]+)"'),
            (m) {
              final rawUri = m.group(1)!;
              final resolved = baseUri.resolve(rawUri).toString();
              final proxied = '$proxyBaseUrl?url=${Uri.encodeComponent(resolved)}&headers=${Uri.encodeComponent(customHeadersJson)}';
              return 'URI="$proxied"';
            },
          );
          out.add(rewrittenTag);
        } else {
          out.add(line);
        }
      } else {
        // Segment or variant URI
        final resolved = baseUri.resolve(trimmed).toString();
        final proxied = '$proxyBaseUrl?url=${Uri.encodeComponent(resolved)}&headers=${Uri.encodeComponent(customHeadersJson)}';
        out.add(proxied);
      }
    }

    return out.join('\n');
  }
}
