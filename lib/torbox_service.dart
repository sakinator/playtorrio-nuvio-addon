import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

/// TorboxService: Integrates TorBox API (v1) for cloud caching,
/// live hosters list, cache checks, and debriding web/hoster links.
class TorboxService {
  static final TorboxService instance = TorboxService._();

  TorboxService._();

  static const String _apiBase = 'https://api.torbox.app/v1/api';

  // In-memory cache for hosters list & checkcached results
  static List<Map<String, dynamic>>? _cachedHosters;
  static DateTime? _hostersExpiry;
  static final Map<String, bool> _cacheLookup = {};

  /// Checks if an API key is valid and returns user plan information
  Future<Map<String, dynamic>> validateAccount(String apiKey) async {
    if (apiKey.isEmpty) {
      return {'valid': false, 'message': 'API key is empty'};
    }
    try {
      final res = await http.get(
        Uri.parse('$_apiBase/user/me'),
        headers: {'Authorization': 'Bearer $apiKey'},
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map && data['success'] == true) {
          final userData = data['data'] ?? {};
          final plan = userData['plan'] ?? 'standard';
          final email = userData['email'] ?? 'Active User';
          return {
            'valid': true,
            'email': email,
            'plan': plan,
            'message': 'Connected to Torbox ($plan plan)',
          };
        }
      }
      return {'valid': false, 'message': 'Invalid API Key (HTTP ${res.statusCode})'};
    } catch (e) {
      return {'valid': false, 'message': 'Connection error: $e'};
    }
  }

  /// Fetches live list of supported hosters from TorBox
  Future<List<Map<String, dynamic>>> getHosters({String? apiKey}) async {
    final now = DateTime.now();
    if (_cachedHosters != null && _hostersExpiry != null && now.isBefore(_hostersExpiry!)) {
      return _cachedHosters!;
    }

    try {
      final headers = <String, String>{};
      if (apiKey != null && apiKey.isNotEmpty) {
        headers['Authorization'] = 'Bearer $apiKey';
      }
      final res = await http.get(
        Uri.parse('$_apiBase/webdl/hosters'),
        headers: headers,
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = (data is Map && data['data'] is List)
            ? data['data'] as List
            : (data is List)
                ? data
                : [];

        _cachedHosters = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _hostersExpiry = now.add(const Duration(hours: 1));
        return _cachedHosters!;
      }
    } catch (_) {}

    return _cachedHosters ?? [];
  }

  /// Checks if a direct link or web hoster link is cached on Torbox servers
  Future<bool> checkCached(String url, String apiKey) async {
    if (apiKey.isEmpty) return false;
    final hash = md5.convert(utf8.encode(url.trim())).toString();

    if (_cacheLookup.containsKey(hash)) {
      return _cacheLookup[hash]!;
    }

    try {
      final uri = Uri.parse('$_apiBase/webdl/checkcached?hash=$hash&format=object');
      final res = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $apiKey'},
      ).timeout(const Duration(seconds: 3));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map && data['data'] is Map) {
          final hashData = data['data'][hash];
          final isCached = hashData != null && (hashData is Map || hashData == true);
          _cacheLookup[hash] = isCached;
          return isCached;
        }
      }
    } catch (_) {}

    _cacheLookup[hash] = false;
    return false;
  }

  /// Uploads / sends a web download link to Torbox to cache/download it
  Future<Map<String, dynamic>> uploadToTorbox(String url, String apiKey) async {
    if (apiKey.isEmpty) {
      return {'success': false, 'message': 'Torbox API key not configured'};
    }
    try {
      final createUrl = Uri.parse('$_apiBase/webdl/createwebdownload');
      final res = await http.post(
        createUrl,
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'link': url.trim(),
          'client': 'MegaScraper',
        }),
      ).timeout(const Duration(seconds: 8));

      final data = jsonDecode(res.body);
      if (res.statusCode == 200 && data is Map && data['success'] == true) {
        return {
          'success': true,
          'message': data['detail'] ?? 'Successfully uploaded to Torbox!',
          'data': data['data'],
        };
      } else {
        return {
          'success': false,
          'message': data is Map ? (data['detail'] ?? 'Upload failed') : 'HTTP ${res.statusCode}',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Error sending to Torbox: $e'};
    }
  }

  /// Initiates or retrieves a debrided Torbox web download stream URL
  Future<String?> debridLink(String url, String apiKey) async {
    if (apiKey.isEmpty) return null;
    try {
      final res = await uploadToTorbox(url, apiKey);
      if (res['success'] == true) {
        final webId = res['data']?['webdownload_id'] ?? res['data']?['id'];
        if (webId != null) {
          // Request direct streaming link
          final dlRes = await http.get(
            Uri.parse('$_apiBase/webdl/requestdl?token=$apiKey&web_id=$webId'),
          ).timeout(const Duration(seconds: 5));

          if (dlRes.statusCode == 200) {
            final dlData = jsonDecode(dlRes.body);
            if (dlData is Map && dlData['data'] is String) {
              return dlData['data'] as String;
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }

  /// Returns true if the hoster is supported by TorBox
  bool isSupportedHoster(String url) {
    final lower = url.toLowerCase();
    // Check known domains (HubCloud, HubDrive, Pixeldrain, Mega, 1fichier, etc.)
    return lower.contains('pixeldrain.com') ||
        lower.contains('1fichier.com') ||
        lower.contains('rapidgator.net') ||
        lower.contains('mega.nz') ||
        lower.contains('mediafire.com') ||
        lower.contains('ddownload.com') ||
        lower.contains('uptobox.com') ||
        lower.contains('drive.google.com') ||
        lower.contains('hubcloud') ||
        lower.contains('hubdrive') ||
        lower.contains('driveseed') ||
        lower.contains('fastdl') ||
        lower.contains('vcloud') ||
        lower.endsWith('.mp4') ||
        lower.endsWith('.mkv') ||
        lower.endsWith('.avi');
  }
}
