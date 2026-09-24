import 'package:shared_preferences/shared_preferences.dart';

class AddonConfig {
  static final AddonConfig instance = AddonConfig._();

  int port = 7002;
  String host = '0.0.0.0';
  int timeoutSeconds = 9;
  bool enableProxyForHeaders = true;
  Set<String> disabledProviders = {};
  List<String> providerOrder = [];
  bool autoCheckUpdates = true;
  String tmdbApiKey = 'b3556f3b206e16f82df4d1f6fd4545e6';

  AddonConfig._();

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      port = prefs.getInt('server_port') ?? 7002;
      timeoutSeconds = prefs.getInt('timeout_seconds') ?? 9;
      enableProxyForHeaders = prefs.getBool('enable_proxy_headers') ?? true;
      final disabled = prefs.getStringList('disabled_providers');
      if (disabled != null) {
        disabledProviders = disabled.map((e) => e.toLowerCase()).toSet();
      }
      final order = prefs.getStringList('provider_order');
      if (order != null) {
        providerOrder = order.map((e) => e.toLowerCase()).toList();
      }
      final key = prefs.getString('tmdb_api_key');
      if (key != null && key.isNotEmpty) {
        tmdbApiKey = key;
      }
    } catch (e) {
      // ignore
    }
  }

  Future<void> save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('server_port', port);
      await prefs.setInt('timeout_seconds', timeoutSeconds);
      await prefs.setBool('enable_proxy_headers', enableProxyForHeaders);
      await prefs.setStringList('disabled_providers', disabledProviders.toList());
      await prefs.setStringList('provider_order', providerOrder);
      await prefs.setString('tmdb_api_key', tmdbApiKey);
    } catch (e) {
      // ignore
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
    save();
  }
}
