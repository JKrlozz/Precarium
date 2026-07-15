enum DownloadStatus { pending, downloading, completed, cancelled, failed }

class DownloadTask {
  final String id;
  final String title;
  final String? artist;
  final String? thumbnailUrl;
  final String videoId;
  final String? videoUrl;
  final String? audioUrl;
  final DownloadStatus status;
  final double progress;
  final String? filePath;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime? completedAt;

  DownloadTask({
    required this.id,
    required this.title,
    this.artist,
    this.thumbnailUrl,
    required this.videoId,
    this.videoUrl,
    this.audioUrl,
    this.status = DownloadStatus.pending,
    this.progress = 0.0,
    this.filePath,
    this.errorMessage,
    DateTime? createdAt,
    this.completedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  String get durationFormatted {
    return '${(progress * 100).toStringAsFixed(0)}%';
  }

  DownloadTask copyWith({
    String? id,
    String? title,
    String? artist,
    String? thumbnailUrl,
    String? videoId,
    String? videoUrl,
    String? audioUrl,
    DownloadStatus? status,
    double? progress,
    String? filePath,
    String? errorMessage,
    DateTime? createdAt,
    DateTime? completedAt,
  }) {
    return DownloadTask(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      videoId: videoId ?? this.videoId,
      videoUrl: videoUrl ?? this.videoUrl,
      audioUrl: audioUrl ?? this.audioUrl,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      filePath: filePath ?? this.filePath,
      errorMessage: errorMessage ?? this.errorMessage,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}
