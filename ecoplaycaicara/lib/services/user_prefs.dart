import 'package:shared_preferences/shared_preferences.dart';

class UserPrefs {
  UserPrefs._();

  static SharedPreferences? _prefs;

  static const String _keyAudioEnabled = 'toca_audio_enabled';

  static Future<SharedPreferences> _instance() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  static Future<bool> getAudioEnabled({bool defaultValue = true}) async {
    final prefs = await _instance();
    return prefs.getBool(_keyAudioEnabled) ?? defaultValue;
  }

  static Future<void> setAudioEnabled(bool value) async {
    final prefs = await _instance();
    await prefs.setBool(_keyAudioEnabled, value);
  }
}
