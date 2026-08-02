import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../models/song.dart';

class MusicScanService {
  static const _channel = MethodChannel('com.example.precarium/downloader');
  static const List<String> _audioExtensions = [
    '.mp3', '.wav', '.flac', '.m4a', '.aac', '.ogg', '.wma', '.opus', '.webm',
  ];

  Future<Directory> _getMusicDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    return Directory('${appDir.path}${Platform.pathSeparator}music');
  }

  bool _isAudioFile(String path) {
    final ext = path.toLowerCase();
    return _audioExtensions.any((e) => ext.endsWith(e));
  }

  Song? _parseSongFromPath(File file, {Duration? duration}) {
    try {
      final filePath = file.path;
      final fileName = filePath.split(Platform.pathSeparator).last;
      final dot = fileName.lastIndexOf('.');
      if (dot < 0) return null;
      var nameWithoutExt = fileName.substring(0, dot);
      nameWithoutExt = nameWithoutExt
          .replaceAll('\u2013', '-')
          .replaceAll('\u2014', '-');
      nameWithoutExt = nameWithoutExt
          .replaceAll('\u00A0', ' ')
          .replaceAll('\u200B', '');
      nameWithoutExt = nameWithoutExt
          .replaceAll(RegExp(r'[. ]+$'), '')
          .trim();

      String title = nameWithoutExt;
      String artist = 'Unknown Artist';

      final dashIndex = nameWithoutExt.indexOf(' - ');
      if (dashIndex > 0 && dashIndex < nameWithoutExt.length - 3) {
        final rawArtist = nameWithoutExt.substring(0, dashIndex).trim();
        final rawTitle = nameWithoutExt.substring(dashIndex + 3).trim();
        if (rawArtist.isNotEmpty) {
          artist = rawArtist;
          title = rawTitle;
        }
      }

      if (title.isEmpty) title = artist;

      return Song(
        id: filePath.hashCode.toString(),
        title: title,
        artist: artist,
        filePath: filePath,
        duration: duration ?? Duration.zero,
      );
    } catch (_) {
      return null;
    }
  }

  Future<int> getFileSize(File file) async {
    try {
      return await file.length();
    } catch (_) {
      return 0;
    }
  }

  Future<Duration> getFileDuration(File file) async {
    try {
      final ms = await _channel
          .invokeMethod<int>('getDuration', {'filePath': file.path})
          .timeout(const Duration(seconds: 5));
      return Duration(milliseconds: ms ?? 0);
    } catch (_) {
      return Duration.zero;
    }
  }

  Future<List<Song>> scanDownloadedMusic() async {
    final songs = <Song>[];
    final dir = await _getMusicDirectory();
    if (!await dir.exists()) return songs;

    try {
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File && _isAudioFile(entity.path)) {
          final song = _parseSongFromPath(entity);
          if (song != null) {
            final dur = await getFileDuration(entity);
            final size = await getFileSize(entity);
            songs.add(Song(
              id: song.id,
              title: song.title,
              artist: song.artist,
              filePath: song.filePath,
              duration: dur,
              fileSize: size,
            ));
          }
        }
      }
    } catch (_) {}

    return songs;
  }

  Future<List<Song>> listLocalFiles() async {
    final songs = <Song>[];
    final dir = await _getMusicDirectory();
    if (!await dir.exists()) return songs;

    try {
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File && _isAudioFile(entity.path)) {
          final song = _parseSongFromPath(entity);
          if (song != null) songs.add(song);
        }
      }
    } catch (_) {}

    return songs;
  }
}
