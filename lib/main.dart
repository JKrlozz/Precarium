import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:permission_handler/permission_handler.dart';
import 'providers/settings_provider.dart';
import 'app.dart';
import 'services/download_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await AndroidAlarmManager.initialize();
  final settings = SettingsProvider();
  await settings.load();
  await Permission.notification.request();
  await DownloadNotificationService.initialize();
  runApp(PrecariumApp(settingsProvider: settings));
}
