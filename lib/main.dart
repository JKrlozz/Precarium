import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'providers/settings_provider.dart';
import 'app.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Workmanager().initialize(callbackDispatcher);
  final settings = SettingsProvider();
  await settings.load();
  runApp(PrecariumApp(settingsProvider: settings));
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task != 'precariumAutoBackup') return true;
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('auto_backup_enabled') ?? false;
    if (!enabled) return true;
    return true;
  });
}
