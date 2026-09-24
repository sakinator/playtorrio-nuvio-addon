import 'dart:convert';
import 'dart:io';

class SharedPreferences {
  static SharedPreferences? _instance;
  final Map<String, Object> _data = {};
  static final File _storeFile = File('data/settings.json');

  static Future<SharedPreferences> getInstance() async {
    if (_instance == null) {
      _instance = SharedPreferences._();
      await _instance!._load();
    }
    return _instance!;
  }

  SharedPreferences._();

  Future<void> _load() async {
    try {
      if (await _storeFile.exists()) {
        final content = await _storeFile.readAsString();
        final map = jsonDecode(content) as Map<String, dynamic>;
        map.forEach((key, value) {
          if (value is Object) _data[key] = value;
        });
      }
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      if (!await _storeFile.parent.exists()) {
        await _storeFile.parent.create(recursive: true);
      }
      await _storeFile.writeAsString(jsonEncode(_data));
    } catch (_) {}
  }

  String? getString(String key) => _data[key] as String?;
  List<String>? getStringList(String key) {
    final v = _data[key];
    if (v is List) return v.map((e) => e.toString()).toList();
    return null;
  }
  bool? getBool(String key) => _data[key] as bool?;
  int? getInt(String key) => _data[key] as int?;
  double? getDouble(String key) => _data[key] as double?;

  Future<bool> setString(String key, String value) async {
    _data[key] = value;
    await _save();
    return true;
  }

  Future<bool> setStringList(String key, List<String> value) async {
    _data[key] = value;
    await _save();
    return true;
  }

  Future<bool> setBool(String key, bool value) async {
    _data[key] = value;
    await _save();
    return true;
  }

  Future<bool> setInt(String key, int value) async {
    _data[key] = value;
    await _save();
    return true;
  }

  Future<bool> setDouble(String key, double value) async {
    _data[key] = value;
    await _save();
    return true;
  }

  Future<bool> remove(String key) async {
    _data.remove(key);
    await _save();
    return true;
  }

  Future<bool> clear() async {
    _data.clear();
    await _save();
    return true;
  }
}
