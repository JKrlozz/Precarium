import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

const String _taskName = 'precariumAutoBackup';
const String _enabledKey = 'auto_backup_enabled';
const String _typeKey = 'auto_backup_type';

class AutoBackupService {
  static Future<void> schedule(String type, int hour, int minute) async {
    await Workmanager().registerPeriodicTask(
      _taskName,
      _taskName,
      frequency: const Duration(hours: 24),
      constraints: Constraints(networkType: NetworkType.connected),
      initialDelay: _initialDelay(hour, minute),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, true);
    await prefs.setString(_typeKey, type);
  }

  static Future<void> cancel() async {
    await Workmanager().cancelByUniqueName(_taskName);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, false);
  }

  static Duration _initialDelay(int hour, int minute) {
    final now = DateTime.now();
    var next = DateTime(now.year, now.month, now.day, hour, minute);
    if (next.isBefore(now) || next.isAtSameMomentAs(now)) {
      next = next.add(const Duration(days: 1));
    }
    return next.difference(now);
  }

  static Future<bool> isScheduled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? false;
  }
}
