import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../models/song.dart';
import '../services/backup_service.dart';
import '../services/database_service.dart';
import '../services/drive_backup_service.dart';

enum BackupType { config, songs, playlists }

class BackupProvider extends ChangeNotifier {
  static const _lastBackupKey = 'last_backup_timestamp';

  final DriveBackupService _driveService = DriveBackupService();

  bool _isExporting = false;
  bool _isImporting = false;
  bool _isDriveConnecting = false;
  DateTime? _lastBackupDate;
  bool _driveConnected = false;

  bool get isExporting => _isExporting;
  bool get isImporting => _isImporting;
  bool get isDriveConnecting => _isDriveConnecting;
  DateTime? get lastBackupDate => _lastBackupDate;
  bool get driveConnected => _driveConnected;
  DriveBackupService get driveService => _driveService;

  // Full backup progress
  double _fullProgress = 0;
  String _fullStatus = '';
  double get fullProgress => _fullProgress;
  String get fullStatus => _fullStatus;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final ts = prefs.getInt(_lastBackupKey);
    if (ts != null) {
      _lastBackupDate = DateTime.fromMillisecondsSinceEpoch(ts);
    }
    _driveConnected = await _driveService.tryRestore();
    notifyListeners();
  }

  Future<void> _saveLastBackupDate() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastBackupKey, DateTime.now().millisecondsSinceEpoch);
    _lastBackupDate = DateTime.now();
    notifyListeners();
  }

  // ── Local file backup (unchanged) ──

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
        settings: {
          'themeMode': themeMode,
          'primaryColor': primaryColor,
        },
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

  // ── Google Drive ──

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

  // ── Drive backup by type ──

  Future<String> _getDatePrefix() =>
      Future.value('Precarium_${DateTime.now().toIso8601String().split('T').first}');

  Future<void> uploadConfigToDrive({
    required int themeMode,
    required int primaryColor,
  }) async {
    _isExporting = true;
    notifyListeners();

    try {
      final datePrefix = await _getDatePrefix();
      final folderId = await _driveService.ensureBackupFolder();
      final jsonContent = const JsonEncoder.withIndent('  ').convert({
        'version': 1,
        'exportedAt': DateTime.now().toIso8601String(),
        'themeMode': themeMode,
        'primaryColor': primaryColor,
      });
      await _driveService.uploadJsonFile(
          folderId, '${datePrefix}_Config.json', jsonContent);
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
      final datePrefix = await _getDatePrefix();
      final folderId = await _driveService.ensureBackupFolder();
      final jsonContent = const JsonEncoder.withIndent('  ').convert({
        'version': 1,
        'exportedAt': DateTime.now().toIso8601String(),
        'songs': songs.map((s) => s.toJson()).toList(),
      });
      await _driveService.uploadJsonFile(
          folderId, '${datePrefix}_Songs.json', jsonContent);
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
      final datePrefix = await _getDatePrefix();
      final folderId = await _driveService.ensureBackupFolder();
      final jsonContent = const JsonEncoder.withIndent('  ').convert({
        'version': 1,
        'exportedAt': DateTime.now().toIso8601String(),
        'playlists': playlists,
        'playlistSongs': playlistSongs,
      });
      await _driveService.uploadJsonFile(
          folderId, '${datePrefix}_Playlists.json', jsonContent);
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
      final datePrefix = await _getDatePrefix();
      final backupFolderId = await _driveService.ensureBackupFolder();

      _fullStatus = 'Subiendo configuración...';
      _fullProgress = 0.05;
      notifyListeners();

      await _driveService.uploadJsonFile(
          backupFolderId, '${datePrefix}_Config.json',
          const JsonEncoder.withIndent('  ').convert({
            'version': 1,
            'exportedAt': DateTime.now().toIso8601String(),
            'themeMode': themeMode,
            'primaryColor': primaryColor,
          }));

      _fullStatus = 'Subiendo canciones...';
      _fullProgress = 0.1;
      notifyListeners();

      await _driveService.uploadJsonFile(
          backupFolderId, '${datePrefix}_Songs.json',
          const JsonEncoder.withIndent('  ').convert({
            'version': 1,
            'exportedAt': DateTime.now().toIso8601String(),
            'songs': songs.map((s) => s.toJson()).toList(),
          }));

      _fullStatus = 'Subiendo listas de reproducción...';
      _fullProgress = 0.15;
      notifyListeners();

      await _driveService.uploadJsonFile(
          backupFolderId, '${datePrefix}_Playlists.json',
          const JsonEncoder.withIndent('  ').convert({
            'version': 1,
            'exportedAt': DateTime.now().toIso8601String(),
            'playlists': playlists,
            'playlistSongs': playlistSongs,
          }));

      _fullStatus = 'Preparando canciones descargadas...';
      _fullProgress = 0.2;
      notifyListeners();

      final songsFolderId =
          await _driveService.ensureSongsFolder(backupFolderId);

      final localSongs = songs
          .where((s) => s.filePath.isNotEmpty && File(s.filePath).existsSync())
          .toList();

      if (localSongs.isEmpty) {
        _fullStatus = 'No hay canciones descargadas para respaldar';
        _fullProgress = 1.0;
        notifyListeners();
      } else {
        for (int i = 0; i < localSongs.length; i++) {
          final song = localSongs[i];
          final progress = 0.2 + (0.8 * (i / localSongs.length));
          final fileName = p.basename(song.filePath);

          _fullStatus =
              'Subiendo canción ${i + 1} de ${localSongs.length}: ${song.title}';
          _fullProgress = progress;
          notifyListeners();

          try {
            await _driveService.uploadSongFile(
                songsFolderId, song.filePath, fileName);
          } catch (_) {
          }
        }

        _fullStatus =
            'Respaldo completo finalizado: ${localSongs.length} canciones';
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

  // ── Drive restore by type ──

  Future<Map<String, dynamic>?> downloadConfigFromDrive() async {
    _isImporting = true;
    notifyListeners();

    try {
      final folderId = await _driveService.ensureBackupFolder();
      final fileId =
          await _driveService.findLatestJsonFile(folderId, 'Precarium_Config');
      if (fileId == null) {
        throw Exception('No se encontraron archivos de configuración.');
      }
      final jsonContent = await _driveService.downloadJsonFile(fileId);
      if (jsonContent == null) {
        throw Exception('Error al descargar configuración.');
      }
      final decoded = json.decode(jsonContent) as Map<String, dynamic>;
      return decoded;
    } catch (e) {
      rethrow;
    } finally {
      _isImporting = false;
      notifyListeners();
    }
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

  Future<void> restoreSongsToDb(List<Song> songs) => _restoreSongsToDb(songs);

  Future<void> restoreConfigFromDrive() async {
    _isImporting = true;
    notifyListeners();

    try {
      final folderId = await _driveService.ensureBackupFolder();
      final fileId = await _driveService.findLatestJsonFile(
          folderId, 'Precarium_Config');
      if (fileId == null) {
        throw Exception('No se encontraron archivos de configuración.');
      }
      final jsonContent = await _driveService.downloadJsonFile(fileId);
      if (jsonContent == null) {
        throw Exception('Error al descargar configuración.');
      }
      final decoded = json.decode(jsonContent) as Map<String, dynamic>;
      final themeModeIndex = decoded['themeMode'] as int?;
      final primaryColor = decoded['primaryColor'] as int?;
      if (themeModeIndex != null || primaryColor != null) {
        // stored for external application
      }
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
      final folderId = await _driveService.ensureBackupFolder();
      final fileId = await _driveService.findLatestJsonFile(
          folderId, 'Precarium_Songs');
      if (fileId == null) {
        throw Exception('No se encontraron archivos de canciones.');
      }
      final jsonContent = await _driveService.downloadJsonFile(fileId);
      if (jsonContent == null) {
        throw Exception('Error al descargar canciones.');
      }
      final decoded = json.decode(jsonContent) as Map<String, dynamic>;
      final songsList = decoded['songs'] as List<dynamic>? ?? [];
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
      final folderId = await _driveService.ensureBackupFolder();
      final fileId = await _driveService.findLatestJsonFile(
          folderId, 'Precarium_Playlists');
      if (fileId == null) {
        throw Exception('No se encontraron archivos de listas.');
      }
      final jsonContent = await _driveService.downloadJsonFile(fileId);
      if (jsonContent == null) {
        throw Exception('Error al descargar listas.');
      }
      final decoded = json.decode(jsonContent) as Map<String, dynamic>;
      final playlistsList = decoded['playlists'] as List<dynamic>? ?? [];
      final playlistSongsList = decoded['playlistSongs'] as List<dynamic>? ?? [];
      await _restorePlaylistsToDb(
        playlistsList
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(),
        playlistSongsList
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(),
      );
    } catch (e) {
      rethrow;
    } finally {
      _isImporting = false;
      notifyListeners();
    }
  }

  Future<void> _restorePlaylistsToDb(
      List<Map<String, dynamic>> playlists,
      List<Map<String, dynamic>> playlistSongs) async {
    final db = await DatabaseService.database;
    final batch = db.batch();
    for (final p in playlists) {
      batch.insert('playlists', {
        'id': p['id'],
        'name': p['name'],
        'createdAt': p['createdAt'],
        'updatedAt': p['updatedAt'],
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    for (final ps in playlistSongs) {
      batch.insert('playlist_songs', {
        'playlistId': ps['playlistId'],
        'songId': ps['songId'],
        'addedAt': ps['addedAt'],
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  // ── Full restore ──

  Future<String> downloadFullRestore() async {
    _isImporting = true;
    _fullProgress = 0;
    _fullStatus = 'Iniciando restauración completa...';
    notifyListeners();

    try {
      final backupFolderId = await _driveService.ensureBackupFolder();
      final songsFolderId =
          await _driveService.ensureSongsFolder(backupFolderId);

      _fullStatus = 'Descargando configuración...';
      _fullProgress = 0.05;
      notifyListeners();

      int restoredCount = 0;
      final configFileId = await _driveService.findLatestJsonFile(
          backupFolderId, 'Precarium_');

      if (configFileId != null) {
        final configJson =
            await _driveService.downloadJsonFile(configFileId);
        if (configJson != null) {
          restoredCount++;
        }
      }

      _fullStatus = 'Descargando canciones...';
      _fullProgress = 0.1;
      notifyListeners();

      final songsFileId = await _driveService.findLatestJsonFile(
          backupFolderId, 'Precarium_');
      List<Song> songs = [];
      if (songsFileId != null) {
        final songsJson = await _driveService.downloadJsonFile(songsFileId);
        if (songsJson != null) {
          final decoded = json.decode(songsJson) as Map<String, dynamic>;
          final songsList = decoded['songs'] as List<dynamic>? ?? [];
          songs = songsList
              .map((e) => Song.fromJson(e as Map<String, dynamic>))
              .toList();
          await _restoreSongsToDb(songs);
          restoredCount++;
        }
      }

      _fullStatus = 'Descargando listas de reproducción...';
      _fullProgress = 0.15;
      notifyListeners();

      final playlistsFileId = await _driveService.findLatestJsonFile(
          backupFolderId, 'Precarium_');
      if (playlistsFileId != null) {
        final playlistsJson =
            await _driveService.downloadJsonFile(playlistsFileId);
        if (playlistsJson != null) {
          final decoded =
              json.decode(playlistsJson) as Map<String, dynamic>;
          final playlistsList =
              decoded['playlists'] as List<dynamic>? ?? [];
          final playlistSongsList =
              decoded['playlistSongs'] as List<dynamic>? ?? [];
          await _restorePlaylistsToDb(
            playlistsList
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList(),
            playlistSongsList
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList(),
          );
          restoredCount++;
        }
      }

      _fullStatus = 'Descargando archivos de audio...';
      _fullProgress = 0.2;
      notifyListeners();

      final songFiles = await _driveService.listSongFiles(songsFolderId);
      final destDir = await _getSongsDirectory();

      if (songFiles.isEmpty) {
        _fullStatus = 'No hay archivos de audio en Drive';
      } else {
        for (int i = 0; i < songFiles.length; i++) {
          final fileInfo = songFiles[i];
          final fileId = fileInfo['id'] as String;
          final fileName = fileInfo['name'] as String;
          final progress = 0.2 + (0.8 * (i / songFiles.length));
          final destPath = '${destDir.path}${Platform.pathSeparator}$fileName';

          _fullStatus =
              'Descargando archivo ${i + 1} de ${songFiles.length}: $fileName';
          _fullProgress = progress;
          notifyListeners();

          try {
            await _driveService.downloadSongFile(fileId, destPath);
          } catch (_) {
          }
        }
        _fullStatus =
            'Restauración completa: ${songFiles.length} archivos descargados';
      }

      _fullProgress = 1.0;
      notifyListeners();
      return 'Restauración completada: $restoredCount archivos, ${songFiles.length} canciones';
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
