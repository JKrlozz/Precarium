import 'dart:async';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _enabledKey = 'auto_backup_enabled';
const String _typeKey = 'auto_backup_type';
const String _hourKey = 'auto_backup_hour';
const String _minuteKey = 'auto_backup_minute';
const String _pendingKey = 'auto_backup_pending';

const int _alarmId = 810273645;

typedef AutoBackupCallback = Future<void> Function(String type);

// ── Top-level callback for Android AlarmManager (background) ──
// Only sets a pending flag. The actual backup runs in the main app.

@pragma('vm:entry-point')
void autoBackupCallback() {
  AndroidAlarmManager.initialize();
  _markPending();
}

Future<void> _markPending() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_enabledKey) ?? false;
    if (!enabled) return;
    await prefs.setBool(_pendingKey, true);
  } catch (_) {}
}

// ── Service class for UI interactions ──

class AutoBackupService {
  static Timer? _timer;
  static AutoBackupCallback? _onDue;

  static void setCallback(AutoBackupCallback callback) {
    _onDue = callback;
  }

  /// Check if a backup was scheduled while the app was closed.
  static Future<bool> consumePendingFlag() async {
    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getBool(_pendingKey) ?? false;
    if (pending) {
      await prefs.setBool(_pendingKey, false);
    }
    return pending;
  }

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

  /// Schedule a precise one-shot timer for the next scheduled backup time.
  /// Called when the app is open.
  static void scheduleNext({required int hour, required int minute}) {
    _timer?.cancel();
    final now = DateTime.now();
    var scheduled = DateTime(now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now) || scheduled.isAtSameMomentAs(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    _timer = Timer(scheduled.difference(now), () async {
      if (_onDue == null) return;
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool(_enabledKey) ?? false;
      if (!enabled) return;
      final type = prefs.getString(_typeKey) ?? 'light';
      await _onDue!(type);
      scheduleNext(hour: hour, minute: minute);
    });
  }

  /// Cancel the in-app timer.
  static void cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }

  // ── Android AlarmManager scheduling ──

  static Future<void> scheduleAlarm(int hour, int minute) async {
    await AndroidAlarmManager.cancel(_alarmId);

    final now = DateTime.now();
    var scheduledDate = DateTime(now.year, now.month, now.day, hour, minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    try {
      await AndroidAlarmManager.periodic(
        const Duration(hours: 24),
        _alarmId,
        autoBackupCallback,
        startAt: scheduledDate,
        exact: true,
        wakeup: true,
        allowWhileIdle: true,
        rescheduleOnReboot: true,
      );
    } catch (_) {
      await AndroidAlarmManager.periodic(
        const Duration(hours: 24),
        _alarmId,
        autoBackupCallback,
        startAt: scheduledDate,
        exact: false,
        wakeup: true,
        allowWhileIdle: true,
        rescheduleOnReboot: true,
      );
    }
  }

  static Future<void> cancelAlarm() async {
    await AndroidAlarmManager.cancel(_alarmId);
  }
}
