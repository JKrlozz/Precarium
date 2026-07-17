import 'package:flutter/material.dart';
import 'providers/settings_provider.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = SettingsProvider();
  await settings.load();
  runApp(PrecariumApp(settingsProvider: settings));
}
