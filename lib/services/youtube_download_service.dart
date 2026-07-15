import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

enum DownloadState { pending, downloading, completed, cancelled, failed }

class DownloadProgress {
  final String videoId;
  final String title;
  final double progress;
  final DownloadState state;
  final String? filePath;
  final String? error;

  DownloadProgress({
    required this.videoId,
    required this.title,
    this.progress = 0.0,
    this.state = DownloadState.pending,
    this.filePath,
    this.error,
  });

  DownloadProgress copyWith({
    String? videoId,
    String? title,
    double? progress,
    DownloadState? state,
    String? filePath,
    String? error,
  }) {
    return DownloadProgress(
      videoId: videoId ?? this.videoId,
      title: title ?? this.title,
      progress: progress ?? this.progress,
      state: state ?? this.state,
      filePath: filePath ?? this.filePath,
      error: error ?? this.error,
    );
  }
}

class YouTubeDownloadService {
  final Map<String, bool> _cancelled = {};
  final StreamController<DownloadProgress> _progressController =
      StreamController<DownloadProgress>.broadcast();
  static const _channel = MethodChannel('com.example.precarium/downloader');
  static const _progressChannel = EventChannel('com.example.precarium/download_progress');

  StreamSubscription? _progressSub;
  void Function(String videoId, int percent)? onProgress;

  YouTubeDownloadService() {
    _progressSub = _progressChannel.receiveBroadcastStream().listen((event) {
      if (event is Map) {
        final videoId = event['videoId'] as String?;
        final pct = event['percent'] as int? ?? 0;
        if (videoId != null) {
          onProgress?.call(videoId, pct);
        }
      }
    });
  }

  Stream<DownloadProgress> get progressStream => _progressController.stream;

  Future<DownloadProgress> startDownload(String videoId) async {
    _cancelled.remove(videoId);
    var progress = DownloadProgress(videoId: videoId, title: '');
    _emit(progress);

    try {
      final jsonStr = await _channel
          .invokeMethod<String>('extractAudio', {'videoId': videoId})
          .timeout(const Duration(seconds: 30));

      if (_isCancelled(videoId)) return _cancelledResult(videoId);

      final data = json.decode(jsonStr!) as Map<String, dynamic>;
      final audioUrl = data['url'] as String;
      final title = _sanitizeFileName(data['title'] as String? ?? 'Unknown');
      final format = data['format'] as String? ?? 'm4a';

      progress = progress.copyWith(title: title, state: DownloadState.downloading, progress: 0.0);
      _emit(progress);

      final dir = await _getDownloadDirectory();
      final filePath = '${dir.path}${Platform.pathSeparator}$title.$format';

      if (_isCancelled(videoId)) return _cancelledResult(videoId);

      await _channel
          .invokeMethod<String>('download', {
            'url': audioUrl,
            'filePath': filePath,
            'videoId': videoId,
          })
          .timeout(const Duration(minutes: 10));

      if (_isCancelled(videoId)) {
        if (await File(filePath).exists()) await File(filePath).delete();
        return _cancelledResult(videoId);
      }

      final result = progress.copyWith(
        state: DownloadState.completed,
        progress: 1.0,
        filePath: filePath,
      );
      _emit(result);
      return result;
    } catch (e) {
      if (_isCancelled(videoId)) return _cancelledResult(videoId);
      final result = progress.copyWith(
        state: DownloadState.failed,
        error: e.toString(),
      );
      _emit(result);
      return result;
    }
  }

  void cancelDownload(String videoId) {
    _cancelled[videoId] = true;
  }

  bool _isCancelled(String videoId) => _cancelled[videoId] == true;

  DownloadProgress _cancelledResult(String videoId) {
    _cancelled.remove(videoId);
    final result = DownloadProgress(videoId: videoId, title: '', state: DownloadState.cancelled);
    _emit(result);
    return result;
  }

  Future<Directory> _getDownloadDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}${Platform.pathSeparator}music');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  String _sanitizeFileName(String name) {
    return name.replaceAll(RegExp(r'[<>"/\\|?*]'), '_').trim();
  }

  void _emit(DownloadProgress p) {
    if (!_progressController.isClosed) _progressController.add(p);
  }

  void dispose() {
    _progressSub?.cancel();
    _progressController.close();
  }
}
