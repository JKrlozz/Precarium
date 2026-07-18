import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/download_task.dart';
import '../services/youtube_download_service.dart';

class DownloadProvider extends ChangeNotifier {
  final YouTubeDownloadService _downloadService = YouTubeDownloadService();
  final List<DownloadTask> _tasks = [];
  final List<String> _downloadQueue = [];
  StreamSubscription? _progressSub;
  VoidCallback? _onDownloadComplete;
  int _activeCount = 0;
  static const int _maxConcurrent = 2;
  static const int _maxAutoRetries = 3;

  final Map<String, int> _retryCounts = {};

  List<DownloadTask> get tasks => List.unmodifiable(_tasks);
  List<DownloadTask> get activeTasks =>
      _tasks.where((t) => t.status == DownloadStatus.downloading || t.status == DownloadStatus.pending).toList();
  List<DownloadTask> get downloadingTasks =>
      _tasks.where((t) => t.status == DownloadStatus.downloading).toList();
  List<DownloadTask> get pendingTasks =>
      _tasks.where((t) => t.status == DownloadStatus.pending).toList();
  List<DownloadTask> get completedTasks =>
      _tasks.where((t) => t.status == DownloadStatus.completed).toList();
  List<DownloadTask> get failedTasks =>
      _tasks.where((t) => t.status == DownloadStatus.failed).toList();
  int get activeCount => activeTasks.length;
  bool get hasQueue => _downloadQueue.isNotEmpty;

  Future<void> init({VoidCallback? onDownloadComplete}) async {
    _onDownloadComplete = onDownloadComplete;
    _progressSub?.cancel();
    _progressSub = _downloadService.progressStream.listen(_onProgressUpdate);
    _downloadService.onProgress = (videoId, percent) {
      final index = _tasks.indexWhere((t) => t.videoId == videoId);
      if (index == -1) return;
      _tasks[index] = _tasks[index].copyWith(progress: percent / 100.0);
      notifyListeners();
    };
  }

  void _onProgressUpdate(DownloadProgress progress) {
    final index = _tasks.indexWhere((t) => t.videoId == progress.videoId);
    if (index == -1) return;

    DownloadStatus status;
    switch (progress.state) {
      case DownloadState.downloading:
        status = DownloadStatus.downloading;
      case DownloadState.completed:
        status = DownloadStatus.completed;
      case DownloadState.cancelled:
        status = DownloadStatus.cancelled;
      case DownloadState.failed:
        status = DownloadStatus.failed;
      case DownloadState.pending:
        status = DownloadStatus.pending;
    }

    _tasks[index] = _tasks[index].copyWith(
      status: status,
      progress: progress.progress,
      filePath: progress.filePath,
      errorMessage: progress.error,
    );
    notifyListeners();

    if (progress.state == DownloadState.completed) {
      _retryCounts.remove(progress.videoId);
      _onDownloadComplete?.call();
    } else if (progress.state == DownloadState.failed) {
      _scheduleAutoRetry(progress.videoId);
    }

    _updateWakeLock();
  }

  void _scheduleAutoRetry(String videoId) {
    final retries = _retryCounts[videoId] ?? 0;
    if (retries >= _maxAutoRetries) {
      _retryCounts.remove(videoId);
      return;
    }
    _retryCounts[videoId] = retries + 1;
    final delay = Duration(seconds: 1 << retries);

    Future.delayed(delay, () {
      final index = _tasks.indexWhere((t) => t.videoId == videoId);
      if (index == -1) return;
      if (_tasks[index].status != DownloadStatus.failed) return;
      _retryTaskById(_tasks[index].id);
    });
  }

  void addDownload(String videoId, String title, {String? artist, String? thumbnailUrl}) {
    if (_tasks.any((t) => t.videoId == videoId && t.status != DownloadStatus.failed && t.status != DownloadStatus.cancelled)) {
      return;
    }

    _tasks.removeWhere((t) => t.videoId == videoId);
    _retryCounts.remove(videoId);

    final task = DownloadTask(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      artist: artist,
      thumbnailUrl: thumbnailUrl,
      videoId: videoId,
    );

    _tasks.insert(0, task);
    _downloadQueue.add(videoId);
    notifyListeners();
    _updateWakeLock();
    _processQueue();
  }

  void cancelTask(String id) {
    final index = _tasks.indexWhere((t) => t.id == id);
    if (index == -1) return;
    final videoId = _tasks[index].videoId;
    _downloadQueue.remove(videoId);
    _downloadService.cancelDownload(videoId);
    _retryCounts.remove(videoId);
    _tasks[index] = _tasks[index].copyWith(status: DownloadStatus.cancelled);
    notifyListeners();
    _updateWakeLock();
  }

  void removeTask(String id) {
    final index = _tasks.indexWhere((t) => t.id == id);
    if (index != -1) {
      _downloadQueue.remove(_tasks[index].videoId);
      _retryCounts.remove(_tasks[index].videoId);
      _tasks.removeAt(index);
      notifyListeners();
      _updateWakeLock();
    }
  }

  void retryTask(String id) => _retryTaskById(id);

  void _retryTaskById(String id) {
    final index = _tasks.indexWhere((t) => t.id == id);
    if (index == -1) return;

    final task = _tasks[index];
    _tasks[index] = task.copyWith(
      status: DownloadStatus.pending,
      progress: 0.0,
      errorMessage: null,
    );
    _downloadQueue.add(task.videoId);
    notifyListeners();
    _updateWakeLock();
    _processQueue();
  }

  void retryAllFailed() {
    for (final task in _tasks.where((t) => t.status == DownloadStatus.failed).toList()) {
      _retryCounts.remove(task.videoId);
      _retryTaskById(task.id);
    }
  }

  void cancelAllPending() {
    final pending = _tasks.where(
      (t) => t.status == DownloadStatus.pending || t.status == DownloadStatus.downloading,
    ).toList();
    for (final task in pending) {
      cancelTask(task.id);
    }
  }

  void _processQueue() {
    while (_downloadQueue.isNotEmpty && _activeCount < _maxConcurrent) {
      final videoId = _downloadQueue.removeAt(0);
      final taskIndex = _tasks.indexWhere((t) => t.videoId == videoId);
      if (taskIndex == -1) continue;
      if (_tasks[taskIndex].status == DownloadStatus.cancelled) continue;

      _activeCount++;
      _updateWakeLock();
      notifyListeners();
      _downloadService.startDownload(videoId).whenComplete(() {
        _activeCount--;
        _updateWakeLock();
        notifyListeners();
        _processQueue();
      });
    }
  }

  void _updateWakeLock() {
    if (_activeCount > 0 || _downloadQueue.isNotEmpty) {
      WakelockPlus.enable();
    } else {
      WakelockPlus.disable();
    }
  }

  void clearCompleted() {
    _tasks.removeWhere((t) => t.status == DownloadStatus.completed || t.status == DownloadStatus.cancelled);
    notifyListeners();
  }

  @override
  void dispose() {
    _progressSub?.cancel();
    _downloadService.dispose();
    WakelockPlus.disable();
    super.dispose();
  }
}
