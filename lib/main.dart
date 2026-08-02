import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/material.dart';
import 'providers/settings_provider.dart';
import 'services/download_notification_service.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AndroidAlarmManager.initialize();
  await DownloadNotificationService.init();
  final settings = SettingsProvider();
  await settings.load();
  runApp(PrecariumApp(settingsProvider: settings));
}
