import 'dart:convert';
import 'dart:io';

class AddonConfig {
  static final AddonConfig instance = AddonConfig._();

  int port = 7000;
  String host = '0.0.0.0';
  int timeoutSeconds = 9;
  bool enableProxyForHeaders = false;
  Set<String> disabledProviders = {};
  List<String> providerOrder = [];
  bool autoCheckUpdates = true;

  /// TMDB API key used by metadata_service.dart.
  /// Override in data/config.json with your own key if the default is rate-limited.
  String tmdbApiKey = 'b3556f3b206e16f82df4d1f6fd4545e6';
  String torboxApiKey = '';

  static final File _configFile = File('data/config.json');

  AddonConfig._();

  Future<void> load() async {
    try {
      if (await _configFile.exists()) {
        final content = await _configFile.readAsString();
        final map = jsonDecode(content) as Map<String, dynamic>;
        port = map['port'] is int ? map['port'] : port;
        host = map['host']?.toString() ?? host;
        timeoutSeconds = map['timeoutSeconds'] is int ? map['timeoutSeconds'] : timeoutSeconds;
        enableProxyForHeaders = map['enableProxyForHeaders'] is bool
            ? map['enableProxyForHeaders']
            : enableProxyForHeaders;
        if (map['disabledProviders'] is List) {
          disabledProviders =
              (map['disabledProviders'] as List).map((e) => e.toString().toLowerCase()).toSet();
        }
        if (map['providerOrder'] is List) {
          providerOrder =
              (map['providerOrder'] as List).map((e) => e.toString().toLowerCase()).toList();
        }
        autoCheckUpdates =
            map['autoCheckUpdates'] is bool ? map['autoCheckUpdates'] : autoCheckUpdates;
        if (map['tmdbApiKey'] is String && (map['tmdbApiKey'] as String).isNotEmpty) {
          tmdbApiKey = map['tmdbApiKey'];
        }
        if (map['torboxApiKey'] is String) {
          torboxApiKey = map['torboxApiKey'];
        }
      }

      // If TorBox API key is not yet configured, attempt auto-detection from Nuvio desktop settings
      if (torboxApiKey.isEmpty && Platform.isWindows) {
        try {
          final appData = Platform.environment['APPDATA'] ?? '';
          if (appData.isNotEmpty) {
            final nuvioDebrid = File('$appData\\Nuvio\\nuvio_debrid_settings.properties');
            if (await nuvioDebrid.exists()) {
              final lines = await nuvioDebrid.readAsLines();
              for (final line in lines) {
                final trimmed = line.trim();
                if (trimmed.startsWith('debrid_torbox_api_key_1=')) {
                  final key = trimmed.substring('debrid_torbox_api_key_1='.length).trim();
                  if (key.isNotEmpty) {
                    torboxApiKey = key;
                    print('[AddonConfig] Auto-detected Torbox API key from Nuvio debrid settings.');
                    break;
                  }
                }
              }
            }
          }
        } catch (_) {}
      }
    } catch (e) {
      print('[AddonConfig] Error loading config: $e');
    }
  }

  Future<void> save() async {
    try {
      if (!await _configFile.parent.exists()) {
        await _configFile.parent.create(recursive: true);
      }
      final data = {
        'port': port,
        'host': host,
        'timeoutSeconds': timeoutSeconds,
        'enableProxyForHeaders': enableProxyForHeaders,
        'disabledProviders': disabledProviders.toList(),
        'providerOrder': providerOrder,
        'autoCheckUpdates': autoCheckUpdates,
        'tmdbApiKey': tmdbApiKey,
        'torboxApiKey': torboxApiKey,
      };
      await _configFile.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
    } catch (e) {
      print('[AddonConfig] Error saving config: $e');
    }
  }

  bool isProviderEnabled(String providerId) {
    return !disabledProviders.contains(providerId.toLowerCase());
  }

  void toggleProvider(String providerId, bool enabled) {
    final id = providerId.toLowerCase();
    if (enabled) {
      disabledProviders.remove(id);
    } else {
      disabledProviders.add(id);
    }
    save(); // fire-and-forget – non-blocking
  }
}
