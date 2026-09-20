import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class DownloadNotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static const int _notificationId = 1002;
  static AndroidNotificationChannel? _channel;

  static Future<void> initialize() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    final settings = InitializationSettings(android: androidInit);
    await _plugin.initialize(settings: settings);

    _channel = AndroidNotificationChannel(
      'precarium_download',
      'Descargas',
      description: 'Progreso de descargas',
      importance: Importance.low,
    );
    await _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(_channel!);
  }

  static Future<void> show(int total) async {
    try {
      await _plugin.show(
        id: _notificationId,
        title: 'Descargando canciones',
        body: '0 de $total canciones',
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channel!.id,
            _channel!.name,
            channelDescription: _channel!.description,
            importance: Importance.low,
            priority: Priority.low,
            ongoing: true,
            onlyAlertOnce: true,
            showProgress: true,
            progress: 0,
            maxProgress: total,
          ),
        ),
        payload: 'download_$total',
      );
    } catch (_) {}
  }

  static Future<void> update(int completed, int total) async {
    try {
      final percent = total > 0 ? (completed / total * 100).toInt() : 0;
      await _plugin.show(
        id: _notificationId,
        title: 'Descargando canciones',
        body: '$completed de $total canciones ($percent%)',
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channel!.id,
            _channel!.name,
            channelDescription: _channel!.description,
            importance: Importance.low,
            priority: Priority.low,
            ongoing: true,
            onlyAlertOnce: true,
            showProgress: true,
            progress: completed,
            maxProgress: total,
          ),
        ),
        payload: 'download_$total',
      );
    } catch (_) {}
  }

  static Future<void> hide() async {
    try {
      await _plugin.cancel(id: _notificationId);
    } catch (_) {}
  }
}