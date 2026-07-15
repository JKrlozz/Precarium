import 'dart:async';
import 'package:flutter/foundation.dart';
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
      _onDownloadComplete?.call();
    }
  }

  void addDownload(String videoId, String title, {String? artist, String? thumbnailUrl}) {
    if (_tasks.any((t) => t.videoId == videoId && t.status != DownloadStatus.failed && t.status != DownloadStatus.cancelled)) {
      return;
    }

    _tasks.removeWhere((t) => t.videoId == videoId);

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
    _processQueue();
  }

  void cancelTask(String id) {
    final index = _tasks.indexWhere((t) => t.id == id);
    if (index == -1) return;
    final videoId = _tasks[index].videoId;
    _downloadQueue.remove(videoId);
    _downloadService.cancelDownload(videoId);
    _tasks[index] = _tasks[index].copyWith(status: DownloadStatus.cancelled);
    notifyListeners();
  }

  void removeTask(String id) {
    final index = _tasks.indexWhere((t) => t.id == id);
    if (index != -1) {
      _downloadQueue.remove(_tasks[index].videoId);
      _tasks.removeAt(index);
      notifyListeners();
    }
  }

  void retryTask(String id) {
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
    _processQueue();
  }

  void _processQueue() {
    while (_downloadQueue.isNotEmpty && _activeCount < _maxConcurrent) {
      final videoId = _downloadQueue.removeAt(0);
      final taskIndex = _tasks.indexWhere((t) => t.videoId == videoId);
      if (taskIndex == -1) continue;
      if (_tasks[taskIndex].status == DownloadStatus.cancelled) continue;

      _activeCount++;
      notifyListeners();
      _downloadService.startDownload(videoId).whenComplete(() {
        _activeCount--;
        notifyListeners();
        _processQueue();
      });
    }
  }

  @override
  void dispose() {
    _progressSub?.cancel();
    _downloadService.dispose();
    super.dispose();
  }
}
