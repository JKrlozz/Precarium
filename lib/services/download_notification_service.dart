import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class DownloadNotificationService {
  static final FlutterLocalNotificationsPlugin _notif =
      FlutterLocalNotificationsPlugin();
  static const _channelId = 'precarium_downloads';
  static const _notifId = 2;

  static int _completed = 0;
  static int _total = 0;
  static int _failed = 0;
  static String _current = '';

  static Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _notif.initialize(const InitializationSettings(android: android));

    await FlutterBackgroundService().configure(
      androidConfiguration: AndroidConfiguration(
        onStart: _onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: _channelId,
        initialNotificationTitle: 'Precarium',
        initialNotificationContent: 'Iniciando descargas...',
        foregroundServiceNotificationId: _notifId,
        foregroundServiceTypes: [AndroidForegroundType.dataSync],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: _onStart,
      ),
    );
  }

  @pragma('vm:entry-point')
  static void _onStart(ServiceInstance service) {
    service.on('stop').listen((_) => service.stopSelf());
  }

  static Future<void> start(int total) async {
    _completed = 0;
    _total = total;
    _failed = 0;
    _current = '';
    await FlutterBackgroundService().startService();
    _update();
  }

  static Future<void> updateProgress({
    int? completed,
    int? total,
    int? failed,
    String? currentTitle,
  }) async {
    if (completed != null) _completed = completed;
    if (total != null) _total = total;
    if (failed != null) _failed = failed;
    if (currentTitle != null) _current = currentTitle;
    _update();
  }

  static Future<void> _update() async {
    final pct = _total > 0 ? (_completed * 100 ~/ _total) : 0;
    final body = _failed > 0
        ? '$_completed de $_total · $_current · $_failed fallida(s)'
        : '$_completed de $_total · $_current';

    await _notif.show(
      _notifId,
      'Descargando canciones…',
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          'Descargas',
          channelDescription: 'Progreso de descarga de canciones',
          importance: Importance.low,
          priority: Priority.low,
          progress: pct,
          maxProgress: 100,
          showProgress: true,
          onlyAlertOnce: true,
          ongoing: true,
          silent: true,
        ),
      ),
    );
  }

  static Future<void> stop({String? message}) async {
    if (message != null && _total > 0) {
      final pct = _total > 0 ? (_completed * 100 ~/ _total) : 0;
      await _notif.show(
        _notifId,
        'Descargas completadas',
        message,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            'Descargas',
            importance: Importance.low,
            priority: Priority.low,
            progress: pct,
            maxProgress: 100,
            showProgress: false,
            onlyAlertOnce: true,
            ongoing: false,
            autoCancel: true,
          ),
        ),
      );
    } else {
      await _notif.cancel(_notifId);
    }
    FlutterBackgroundService().invoke('stop');
  }
}
