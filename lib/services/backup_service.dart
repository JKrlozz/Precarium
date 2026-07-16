import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/song.dart';

class BackupData {
  final int version;
  final DateTime exportedAt;
  final List<Song> songs;
  final List<Map<String, dynamic>> playlists;
  final List<Map<String, dynamic>> playlistSongs;
  final Map<String, dynamic>? settings;

  BackupData({
    required this.version,
    required this.exportedAt,
    required this.songs,
    required this.playlists,
    required this.playlistSongs,
    this.settings,
  });

  Map<String, dynamic> toJson() => {
        'version': version,
        'exportedAt': exportedAt.toIso8601String(),
        'songs': songs.map((s) => s.toJson()).toList(),
        'playlists': playlists,
        'playlistSongs': playlistSongs,
        if (settings != null) 'settings': settings,
      };

  factory BackupData.fromJson(Map<String, dynamic> json) {
    final version = json['version'] as int? ?? 1;
    return BackupData(
      version: version,
      exportedAt: json['exportedAt'] != null
          ? DateTime.parse(json['exportedAt'] as String)
          : DateTime.now(),
      songs: (json['songs'] as List<dynamic>?)
              ?.map((e) => Song.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      playlists: (json['playlists'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [],
      playlistSongs: (json['playlistSongs'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [],
      settings: json['settings'] as Map<String, dynamic>?,
    );
  }
}

class BackupService {
  static Future<File> createBackupFile(BackupData data) async {
    final dir = await getTemporaryDirectory();
    final fileName =
        'precarium_backup_${DateTime.now().millisecondsSinceEpoch}.json';
    final file = File('${dir.path}/$fileName');
    final jsonStr = const JsonEncoder.withIndent('  ').convert(data.toJson());
    await file.writeAsString(jsonStr, flush: true);
    return file;
  }

  static Future<void> shareBackup(File file) async {
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Copia de seguridad de Precarium',
    );
  }

  static Future<BackupData?> pickAndParseBackup() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.isEmpty) return null;
    final file = File(result.files.single.path!);
    final content = await file.readAsString();
    final decoded = json.decode(content) as Map<String, dynamic>;
    return BackupData.fromJson(decoded);
  }
}
