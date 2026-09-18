import 'package:flutter/services.dart';

class DownloadNotificationService {
  static const _channel = MethodChannel('com.example.precarium/media_notification');

  static Future<void> show(int total) async {
    try {
      await _channel.invokeMethod('showDownload', {'total': total});
    } catch (_) {}
  }

  static Future<void> update(int completed, int total) async {
    try {
      await _channel.invokeMethod('updateDownload', {'completed': completed, 'total': total});
    } catch (_) {}
  }

  static Future<void> hide() async {
    try {
      await _channel.invokeMethod('hideDownload');
    } catch (_) {}
  }
}
