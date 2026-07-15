class Song {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String? albumArtPath;
  final String filePath;
  final Duration duration;
  final int trackNumber;
  final int? discNumber;
  final int? year;
  final String? genre;
  final DateTime? downloadDate;
  final int fileSize;

  Song({
    required this.id,
    required this.title,
    required this.artist,
    this.album = 'Unknown Album',
    this.albumArtPath,
    required this.filePath,
    this.duration = Duration.zero,
    this.trackNumber = 0,
    this.discNumber,
    this.year,
    this.genre,
    this.downloadDate,
    this.fileSize = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        'album': album,
        'albumArtPath': albumArtPath,
        'filePath': filePath,
        'duration': duration.inMilliseconds,
        'trackNumber': trackNumber,
        'discNumber': discNumber,
        'year': year,
        'genre': genre,
        'downloadDate': downloadDate?.toIso8601String(),
        'fileSize': fileSize,
      };

  factory Song.fromJson(Map<String, dynamic> json) => Song(
        id: json['id'] as String,
        title: json['title'] as String,
        artist: json['artist'] as String,
        album: json['album'] as String? ?? 'Unknown Album',
        albumArtPath: json['albumArtPath'] as String?,
        filePath: json['filePath'] as String,
        duration: Duration(milliseconds: json['duration'] as int? ?? 0),
        trackNumber: json['trackNumber'] as int? ?? 0,
        discNumber: json['discNumber'] as int?,
        year: json['year'] as int?,
        genre: json['genre'] as String?,
        downloadDate: json['downloadDate'] != null ? DateTime.parse(json['downloadDate'] as String) : null,
        fileSize: json['fileSize'] as int? ?? 0,
      );

  Map<String, dynamic> toDbMap() => {
        'id': id,
        'title': title,
        'artist': artist,
        'album': album,
        'albumArtPath': albumArtPath,
        'filePath': filePath,
        'duration': duration.inMilliseconds,
        'trackNumber': trackNumber,
        'discNumber': discNumber,
        'year': year,
        'genre': genre,
        'downloadDate': downloadDate?.toIso8601String(),
        'fileSize': fileSize,
      };

  factory Song.fromDbMap(Map<String, dynamic> map) => Song(
        id: map['id'] as String,
        title: map['title'] as String,
        artist: map['artist'] as String? ?? 'Unknown Artist',
        album: map['album'] as String? ?? 'Unknown Album',
        albumArtPath: map['albumArtPath'] as String?,
        filePath: map['filePath'] as String,
        duration: Duration(milliseconds: map['duration'] as int? ?? 0),
        trackNumber: map['trackNumber'] as int? ?? 0,
        discNumber: map['discNumber'] as int?,
        year: map['year'] as int?,
        genre: map['genre'] as String?,
        downloadDate: map['downloadDate'] != null ? DateTime.parse(map['downloadDate'] as String) : null,
        fileSize: map['fileSize'] as int? ?? 0,
      );

  String get formattedDuration {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String get formattedFileSize {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get formattedDownloadDate {
    if (downloadDate == null) return '';
    final d = downloadDate!;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }
}
