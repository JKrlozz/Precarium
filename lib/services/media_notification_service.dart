import 'dart:async';
import 'package:flutter/services.dart';
import '../providers/player_provider.dart';

class MediaNotificationService {
  static const _channel = MethodChannel('com.example.precarium/media_notification');
  static const _eventChannel = EventChannel('com.example.precarium/media_notification_events');

  StreamSubscription? _eventSub;
  late PlayerProvider _playerProvider;
  bool _initialized = false;

  void init(PlayerProvider playerProvider) {
    _playerProvider = playerProvider;
    if (_initialized) return;
    _initialized = true;

    _eventSub = _eventChannel.receiveBroadcastStream().listen(_handleNativeEvent);

    _playerProvider.addListener(_onPlayerStateChanged);

    if (playerProvider.currentSong != null) {
      _updateNotification();
    }
  }

  void _onPlayerStateChanged() {
    _updateNotification();
  }

  void _updateNotification() {
    final song = _playerProvider.currentSong;
    if (song == null) {
      _channel.invokeMethod('hide');
      return;
    }
    _channel.invokeMethod('update', {
      'title': song.title,
      'artist': song.artist,
      'albumArtPath': song.albumArtPath,
      'isPlaying': _playerProvider.isPlaying,
    });
  }

  void _handleNativeEvent(dynamic event) {
    if (event is! String) return;
    switch (event) {
      case 'play':
        unawaited(_playerProvider.play());
      case 'pause':
        unawaited(_playerProvider.pause());
      case 'next':
        unawaited(_playerProvider.next());
      case 'previous':
        unawaited(_playerProvider.previous());
      case 'stop':
        unawaited(_playerProvider.pause());
        _channel.invokeMethod('hide');
    }
  }

  void dispose() {
    _eventSub?.cancel();
    _playerProvider.removeListener(_onPlayerStateChanged);
    _channel.invokeMethod('hide');
  }
}
