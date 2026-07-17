import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../models/song.dart';
import '../services/backup_service.dart';
import '../services/database_service.dart';
import '../services/drive_backup_service.dart';

class BackupProvider extends ChangeNotifier {
  static const _lastBackupKey = 'last_backup_timestamp';

  static const _autoEnabledKey = 'auto_backup_enabled';
  static const _autoTypeKey = 'auto_backup_type';
  static const _autoHourKey = 'auto_backup_hour';
  static const _autoMinuteKey = 'auto_backup_minute';

  final DriveBackupService _driveService = DriveBackupService();

  bool _isExporting = false;
  bool _isImporting = false;
  bool _isDriveConnecting = false;
  DateTime? _lastBackupDate;
  bool _driveConnected = false;

  bool _autoBackupEnabled = false;
  String _autoBackupType = 'light';
  int _autoBackupHour = 3;
  int _autoBackupMinute = 0;

  bool get isExporting => _isExporting;
  bool get isImporting => _isImporting;
  bool get isDriveConnecting => _isDriveConnecting;
  DateTime? get lastBackupDate => _lastBackupDate;
  bool get driveConnected => _driveConnected;
  DriveBackupService get driveService => _driveService;

  double _fullProgress = 0;
  String _fullStatus = '';
  double get fullProgress => _fullProgress;
  String get fullStatus => _fullStatus;

  bool get autoBackupEnabled => _autoBackupEnabled;
  String get autoBackupType => _autoBackupType;
  int get autoBackupHour => _autoBackupHour;
  int get autoBackupMinute => _autoBackupMinute;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final ts = prefs.getInt(_lastBackupKey);
    if (ts != null) {
      _lastBackupDate = DateTime.fromMillisecondsSinceEpoch(ts);
    }
    _driveConnected = await _driveService.tryRestore();
    _autoBackupEnabled = prefs.getBool(_autoEnabledKey) ?? false;
    _autoBackupType = prefs.getString(_autoTypeKey) ?? 'light';
    _autoBackupHour = prefs.getInt(_autoHourKey) ?? 3;
    _autoBackupMinute = prefs.getInt(_autoMinuteKey) ?? 0;
    notifyListeners();
  }

  Future<void> saveAutoBackupSettings({
    required bool enabled,
    required String type,
    required int hour,
    required int minute,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoEnabledKey, enabled);
    await prefs.setString(_autoTypeKey, type);
    await prefs.setInt(_autoHourKey, hour);
    await prefs.setInt(_autoMinuteKey, minute);
    _autoBackupEnabled = enabled;
    _autoBackupType = type;
    _autoBackupHour = hour;
    _autoBackupMinute = minute;
    notifyListeners();
  }

  Future<void> _saveLastBackupDate() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastBackupKey, DateTime.now().millisecondsSinceEpoch);
    _lastBackupDate = DateTime.now();
    notifyListeners();
  }

  // ── Local file backup ──

  Future<void> exportBackup({
    required List<Song> songs,
    required List<Map<String, dynamic>> playlists,
    required List<Map<String, dynamic>> playlistSongs,
    required int themeMode,
    required int primaryColor,
  }) async {
    _isExporting = true;
    notifyListeners();

    try {
      final data = BackupData(
        version: 1,
        exportedAt: DateTime.now(),
        songs: songs,
        playlists: playlists,
        playlistSongs: playlistSongs,
        settings: {'themeMode': themeMode, 'primaryColor': primaryColor},
      );

      final file = await BackupService.createBackupFile(data);
      await BackupService.shareBackup(file);
      await _saveLastBackupDate();
    } catch (e) {
      rethrow;
    } finally {
      _isExporting = false;
      notifyListeners();
    }
  }

  Future<void> importBackup({
    required void Function(List<Song> songs,
            List<Map<String, dynamic>> playlists,
            List<Map<String, dynamic>> playlistSongs,
            Map<String, dynamic>? settings)
        onRestore,
  }) async {
    _isImporting = true;
    notifyListeners();

    try {
      final data = await BackupService.pickAndParseBackup();
      if (data == null) return;

      final db = await DatabaseService.database;
      await db.transaction((txn) async {
        for (final song in data.songs) {
          await txn.insert('songs', song.toDbMap(),
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
        for (final p in data.playlists) {
          await txn.insert('playlists', {
            'id': p['id'],
            'name': p['name'],
            'createdAt': p['createdAt'],
            'updatedAt': p['updatedAt'],
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
        for (final ps in data.playlistSongs) {
          await txn.insert('playlist_songs', {
            'playlistId': ps['playlistId'],
            'songId': ps['songId'],
            'addedAt': ps['addedAt'],
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      });

      onRestore(data.songs, data.playlists, data.playlistSongs, data.settings);
    } catch (e) {
      rethrow;
    } finally {
      _isImporting = false;
      notifyListeners();
    }
  }

  // ── Google Drive auth ──

  Future<void> connectToDrive() async {
    _isDriveConnecting = true;
    notifyListeners();

    try {
      await _driveService.login();
      _driveConnected = true;
    } catch (e) {
      rethrow;
    } finally {
      _isDriveConnecting = false;
      notifyListeners();
    }
  }

  Future<void> disconnectFromDrive() async {
    await _driveService.logout();
    _driveConnected = false;
    notifyListeners();
  }

  // ── Helpers ──

  Future<String> _backupFolder() => _driveService.ensureBackupFolder();

  Future<String> _typeFolder(String type) async {
    final root = await _backupFolder();
    return _driveService.ensureTypeFolder(root, type);
  }

  Future<void> _clearAndUpload(String folderId, String fileName, String jsonContent) async {
    await _driveService.deleteAllFilesInFolder(folderId);
    await _driveService.uploadJsonFile(folderId, fileName, jsonContent);
  }

  // ── Drive backup by type ──

  Future<void> uploadConfigToDrive({
    required int themeMode,
    required int primaryColor,
  }) async {
    _isExporting = true;
    notifyListeners();

    try {
      final folderId = await _typeFolder('Config');
      await _clearAndUpload(
        folderId,
        'config.json',
        const JsonEncoder.withIndent('  ').convert({
          'version': 1,
          'exportedAt': DateTime.now().toIso8601String(),
          'themeMode': themeMode,
          'primaryColor': primaryColor,
        }),
      );
      await _saveLastBackupDate();
    } catch (e) {
      rethrow;
    } finally {
      _isExporting = false;
      notifyListeners();
    }
  }

  Future<void> uploadSongsToDrive({
    required List<Song> songs,
  }) async {
    _isExporting = true;
    notifyListeners();

    try {
      final folderId = await _typeFolder('Songs');
      await _clearAndUpload(
        folderId,
        'songs.json',
        const JsonEncoder.withIndent('  ').convert({
          'version': 1,
          'exportedAt': DateTime.now().toIso8601String(),
          'songs': songs.map((s) => s.toJson()).toList(),
        }),
      );
      await _saveLastBackupDate();
    } catch (e) {
      rethrow;
    } finally {
      _isExporting = false;
      notifyListeners();
    }
  }

  Future<void> uploadPlaylistsToDrive({
    required List<Map<String, dynamic>> playlists,
    required List<Map<String, dynamic>> playlistSongs,
  }) async {
    _isExporting = true;
    notifyListeners();

    try {
      final folderId = await _typeFolder('Playlists');
      await _clearAndUpload(
        folderId,
        'playlists.json',
        const JsonEncoder.withIndent('  ').convert({
          'version': 1,
          'exportedAt': DateTime.now().toIso8601String(),
          'playlists': playlists,
          'playlistSongs': playlistSongs,
        }),
      );
      await _saveLastBackupDate();
    } catch (e) {
      rethrow;
    } finally {
      _isExporting = false;
      notifyListeners();
    }
  }

  // ── Full backup ──

  Future<void> uploadFullBackup({
    required List<Song> songs,
    required List<Map<String, dynamic>> playlists,
    required List<Map<String, dynamic>> playlistSongs,
    required int themeMode,
    required int primaryColor,
  }) async {
    _isExporting = true;
    _fullProgress = 0;
    _fullStatus = 'Iniciando respaldo completo...';
    notifyListeners();

    try {
      final fullFolderId = await _typeFolder('Full');
      await _driveService.deleteAllFilesInFolder(fullFolderId);

      _fullStatus = 'Subiendo configuración...';
      _fullProgress = 0.05;
      notifyListeners();
      await _driveService.uploadJsonFile(
          fullFolderId, 'config.json',
          const JsonEncoder.withIndent('  ').convert({
            'version': 1, 'exportedAt': DateTime.now().toIso8601String(),
            'themeMode': themeMode, 'primaryColor': primaryColor,
          }));

      _fullStatus = 'Subiendo canciones...';
      _fullProgress = 0.1;
      notifyListeners();
      await _driveService.uploadJsonFile(
          fullFolderId, 'songs.json',
          const JsonEncoder.withIndent('  ').convert({
            'version': 1, 'exportedAt': DateTime.now().toIso8601String(),
            'songs': songs.map((s) => s.toJson()).toList(),
          }));

      _fullStatus = 'Subiendo listas de reproducción...';
      _fullProgress = 0.15;
      notifyListeners();
      await _driveService.uploadJsonFile(
          fullFolderId, 'playlists.json',
          const JsonEncoder.withIndent('  ').convert({
            'version': 1, 'exportedAt': DateTime.now().toIso8601String(),
            'playlists': playlists, 'playlistSongs': playlistSongs,
          }));

      _fullStatus = 'Preparando canciones descargadas...';
      _fullProgress = 0.2;
      notifyListeners();

      final songsFolderId = await _driveService.ensureSongsFolder(fullFolderId);
      await _driveService.deleteAllFilesInFolder(songsFolderId);

      final seen = <String>{};
      final localSongs = <Song>[];
      for (final s in songs) {
        if (s.filePath.isNotEmpty && File(s.filePath).existsSync() && seen.add(s.filePath)) {
          localSongs.add(s);
        }
      }

      if (localSongs.isEmpty) {
        _fullStatus = 'No hay canciones descargadas para respaldar';
        _fullProgress = 1.0;
        notifyListeners();
      } else {
        for (int i = 0; i < localSongs.length; i++) {
          final song = localSongs[i];
          _fullStatus = 'Subiendo canción ${i + 1} de ${localSongs.length}: ${song.title}';
          _fullProgress = 0.2 + (0.8 * (i / localSongs.length));
          notifyListeners();

          try {
            await _driveService.uploadSongFile(
                songsFolderId, song.filePath, '${song.id}.${_extension(song.filePath)}');
          } catch (_) {}
        }

        _fullStatus = 'Respaldo completo finalizado: ${localSongs.length} canciones';
        _fullProgress = 1.0;
        notifyListeners();
      }

      await _saveLastBackupDate();
    } catch (e) {
      rethrow;
    } finally {
      _isExporting = false;
      notifyListeners();
    }
  }

  String _extension(String path) {
    final dot = path.lastIndexOf('.');
    return dot >= 0 ? path.substring(dot + 1) : 'm4a';
  }

  // ── Drive restore helpers ──

  Future<String?> _findJsonFile(String typeFolder, String name) async {
    return _driveService.findFileByName(typeFolder, name);
  }

  Future<Map<String, dynamic>?> _downloadAndParse(String fileId) async {
    final raw = await _driveService.downloadJsonFile(fileId);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> _restoreSongsToDb(List<Song> songs) async {
    final db = await DatabaseService.database;
    final batch = db.batch();
    for (final song in songs) {
      batch.insert('songs', song.toDbMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<void> _restorePlaylistsToDb(
      List<Map<String, dynamic>> playlists,
      List<Map<String, dynamic>> playlistSongs) async {
    final db = await DatabaseService.database;
    final batch = db.batch();
    for (final p in playlists) {
      batch.insert('playlists', {
        'id': p['id'], 'name': p['name'],
        'createdAt': p['createdAt'], 'updatedAt': p['updatedAt'],
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    for (final ps in playlistSongs) {
      batch.insert('playlist_songs', {
        'playlistId': ps['playlistId'], 'songId': ps['songId'],
        'addedAt': ps['addedAt'],
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  // ── Drive restore by type ──

  Future<Map<String, dynamic>?> downloadConfigFromDrive() async {
    _isImporting = true;
    notifyListeners();

    try {
      final folderId = await _typeFolder('Config');
      final fileId = await _findJsonFile(folderId, 'config.json');
      if (fileId == null) throw Exception('No se encontró configuración.');
      return _downloadAndParse(fileId);
    } catch (e) {
      rethrow;
    } finally {
      _isImporting = false;
      notifyListeners();
    }
  }

  Future<void> restoreSongsFromDrive() async {
    _isImporting = true;
    notifyListeners();

    try {
      final folderId = await _typeFolder('Songs');
      final fileId = await _findJsonFile(folderId, 'songs.json');
      if (fileId == null) throw Exception('No se encontraron canciones.');
      final data = await _downloadAndParse(fileId);
      if (data == null) throw Exception('Error al descargar canciones.');
      final songsList = data['songs'] as List<dynamic>? ?? [];
      final songs = songsList
          .map((e) => Song.fromJson(e as Map<String, dynamic>))
          .toList();
      await _restoreSongsToDb(songs);
    } catch (e) {
      rethrow;
    } finally {
      _isImporting = false;
      notifyListeners();
    }
  }

  Future<void> restorePlaylistsFromDrive() async {
    _isImporting = true;
    notifyListeners();

    try {
      final folderId = await _typeFolder('Playlists');
      final fileId = await _findJsonFile(folderId, 'playlists.json');
      if (fileId == null) throw Exception('No se encontraron listas.');
      final data = await _downloadAndParse(fileId);
      if (data == null) throw Exception('Error al descargar listas.');
      final playlistsList = data['playlists'] as List<dynamic>? ?? [];
      final playlistSongsList = data['playlistSongs'] as List<dynamic>? ?? [];
      await _restorePlaylistsToDb(
        playlistsList.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
        playlistSongsList.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
      );
    } catch (e) {
      rethrow;
    } finally {
      _isImporting = false;
      notifyListeners();
    }
  }

  // ── Full restore ──

  Future<String> downloadFullRestore() async {
    _isImporting = true;
    _fullProgress = 0;
    _fullStatus = 'Iniciando restauración completa...';
    notifyListeners();

    try {
      final fullFolderId = await _typeFolder('Full');

      _fullStatus = 'Restaurando configuración...';
      _fullProgress = 0.05;
      notifyListeners();

      final configId = await _findJsonFile(fullFolderId, 'config.json');
      if (configId != null) {
        await _downloadAndParse(configId);
      }

      _fullStatus = 'Restaurando canciones...';
      _fullProgress = 0.1;
      notifyListeners();

      final songsId = await _findJsonFile(fullFolderId, 'songs.json');
      if (songsId != null) {
        final data = await _downloadAndParse(songsId);
        if (data != null) {
          final songsList = data['songs'] as List<dynamic>? ?? [];
          final songs = songsList
              .map((e) => Song.fromJson(e as Map<String, dynamic>))
              .toList();
          await _restoreSongsToDb(songs);
        }
      }

      _fullStatus = 'Restaurando listas de reproducción...';
      _fullProgress = 0.15;
      notifyListeners();

      final playlistsId = await _findJsonFile(fullFolderId, 'playlists.json');
      if (playlistsId != null) {
        final data = await _downloadAndParse(playlistsId);
        if (data != null) {
          final playlistsList = data['playlists'] as List<dynamic>? ?? [];
          final playlistSongsList = data['playlistSongs'] as List<dynamic>? ?? [];
          await _restorePlaylistsToDb(
            playlistsList.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
            playlistSongsList.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
          );
        }
      }

      _fullStatus = 'Descargando archivos de audio...';
      _fullProgress = 0.2;
      notifyListeners();

      final songsFolderId = await _driveService.ensureSongsFolder(fullFolderId);
      final songFiles = await _driveService.listSongFiles(songsFolderId);
      final appDir = await _getSongsDirectory();

      if (songFiles.isEmpty) {
        _fullStatus = 'No hay archivos de audio en Drive';
      } else {
        for (int i = 0; i < songFiles.length; i++) {
          final info = songFiles[i];
          final fileId = info['id'] as String;
          final fileName = info['name'] as String;
          _fullStatus = 'Descargando archivo ${i + 1} de ${songFiles.length}: $fileName';
          _fullProgress = 0.2 + (0.8 * (i / songFiles.length));
          notifyListeners();

          try {
            await _driveService.downloadSongFile(
                fileId, '${appDir.path}${Platform.pathSeparator}$fileName');
          } catch (_) {}
        }
        _fullStatus = 'Restauración completa: ${songFiles.length} archivos descargados';
      }

      _fullProgress = 1.0;
      notifyListeners();
      return 'Restauración completada: ${songFiles.length} canciones';
    } catch (e) {
      rethrow;
    } finally {
      _isImporting = false;
      notifyListeners();
    }
  }

  Future<Directory> _getSongsDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}${Platform.pathSeparator}music');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }
}
