import 'package:shared_preferences/shared_preferences.dart';

const String _enabledKey = 'auto_backup_enabled';
const String _typeKey = 'auto_backup_type';
const String _hourKey = 'auto_backup_hour';
const String _minuteKey = 'auto_backup_minute';

class AutoBackupService {
  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? false;
  }

  static Future<Map<String, dynamic>> getSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'enabled': prefs.getBool(_enabledKey) ?? false,
      'type': prefs.getString(_typeKey) ?? 'light',
      'hour': prefs.getInt(_hourKey) ?? 3,
      'minute': prefs.getInt(_minuteKey) ?? 0,
    };
  }

  static Future<void> saveSettings({
    required bool enabled,
    required String type,
    required int hour,
    required int minute,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);
    await prefs.setString(_typeKey, type);
    await prefs.setInt(_hourKey, hour);
    await prefs.setInt(_minuteKey, minute);
  }

  static Future<void> disable() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, false);
  }
}
