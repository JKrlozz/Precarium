import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../models/song.dart';
import '../services/backup_service.dart';
import '../services/database_service.dart';
import '../services/drive_backup_service.dart';

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

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final ts = prefs.getInt(_lastBackupKey);
    if (ts != null) {
      _lastBackupDate = DateTime.fromMillisecondsSinceEpoch(ts);
    }
    await _driveService.loadTokens();
    _driveConnected = _driveService.isLoggedIn;
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
    await _driveService.clearTokens();
    _driveConnected = false;
    notifyListeners();
  }

  Future<void> exportToDrive({
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

      final jsonContent = const JsonEncoder.withIndent('  ').convert(data.toJson());
      await _driveService.uploadBackup(jsonContent);
      await _saveLastBackupDate();
    } catch (e) {
      rethrow;
    } finally {
      _isExporting = false;
      notifyListeners();
    }
  }

  Future<String> importFromDrive({
    required void Function(List<Song> songs,
            List<Map<String, dynamic>> playlists,
            List<Map<String, dynamic>> playlistSongs,
            Map<String, dynamic>? settings)
        onRestore,
  }) async {
    _isImporting = true;
    notifyListeners();

    try {
      final jsonContent = await _driveService.downloadLatestBackup();
      if (jsonContent == null) {
        throw Exception('No se encontraron backups en Google Drive.');
      }

      final decoded = json.decode(jsonContent) as Map<String, dynamic>;
      final data = BackupData.fromJson(decoded);

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
      return 'Restauración completada: ${data.songs.length} canciones, ${data.playlists.length} listas';
    } catch (e) {
      rethrow;
    } finally {
      _isImporting = false;
      notifyListeners();
    }
  }
}
