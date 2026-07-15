import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../models/song.dart';

class MusicScanService {
  static const _channel = MethodChannel('com.example.precarium/downloader');
  static const List<String> _audioExtensions = [
    '.mp3', '.wav', '.flac', '.m4a', '.aac', '.ogg', '.wma', '.opus', '.webm',
  ];

  Future<List<Song>> scanDownloadedMusic() async {
    final songs = <Song>[];
    final dir = await _getMusicDirectory();

    if (!await dir.exists()) return songs;

    try {
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File && _isAudioFile(entity.path)) {
          try {
            final song = await _extractMetadata(entity);
            if (song != null) songs.add(song);
          } catch (_) {}
        }
      }
    } catch (_) {}

    return songs;
  }

  Future<Directory> _getMusicDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    return Directory('${appDir.path}${Platform.pathSeparator}music');
  }

  bool _isAudioFile(String path) {
    final ext = path.toLowerCase();
    return _audioExtensions.any((e) => ext.endsWith(e));
  }

  Future<Song?> _extractMetadata(File file) async {
    try {
      final filePath = file.path;
      final fileName = filePath.split(Platform.pathSeparator).last;
      final nameWithoutExt = fileName.substring(0, fileName.lastIndexOf('.'));

      String title = nameWithoutExt;
      String artist = 'Unknown Artist';

      final dashIndex = nameWithoutExt.indexOf(' - ');
      if (dashIndex > 0 && dashIndex < nameWithoutExt.length - 3) {
        artist = nameWithoutExt.substring(0, dashIndex).trim();
        title = nameWithoutExt.substring(dashIndex + 3).trim();
      }

      final durationMs = await _channel
          .invokeMethod<int>('getDuration', {'filePath': filePath})
          .timeout(const Duration(seconds: 5));

      final fileSize = await file.length();

      return Song(
        id: filePath.hashCode.toString(),
        title: title,
        artist: artist,
        filePath: filePath,
        duration: Duration(milliseconds: durationMs ?? 0),
        fileSize: fileSize,
      );
    } catch (_) {
      return null;
    }
  }
}
