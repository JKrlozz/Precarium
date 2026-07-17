import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/song.dart';
import '../models/playlist.dart';
import '../services/music_scan_service.dart';
import '../services/database_service.dart';

class LibraryProvider extends ChangeNotifier {
  static const String likedPlaylistId = '__liked__';
  static const String likedPlaylistName = 'Canciones que me gustan';

  final MusicScanService _scanService = MusicScanService();
  final List<Song> _songs = [];
  final List<Playlist> _playlists = [];
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _error;

  List<Song> get songs => List.unmodifiable(_songs);
  List<Playlist> get playlists => List.unmodifiable(_playlists);
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String? get error => _error;
  int get songCount => _songs.length;
  Duration get totalDuration {
    if (_songs.isEmpty) return Duration.zero;
    return _songs.fold(Duration.zero, (sum, s) => sum + s.duration);
  }

  int get totalFileSize {
    if (_songs.isEmpty) return 0;
    return _songs.fold(0, (sum, s) => sum + s.fileSize);
  }

  String get formattedTotalFileSize {
    final bytes = totalFileSize;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  Playlist? get likedPlaylist {
    final idx = _playlists.indexWhere((p) => p.id == likedPlaylistId);
    return idx != -1 ? _playlists[idx] : null;
  }

  bool isLiked(String songId) {
    final p = likedPlaylist;
    return p?.songs.any((s) => s.id == songId) ?? false;
  }

  Future<DateTime?> getSongAddedAt(String playlistId, String songId) async {
    return DatabaseService.getSongAddedToPlaylistDate(playlistId, songId);
  }

  void toggleLike(Song song) {
    if (!_playlists.any((p) => p.id == likedPlaylistId)) {
      _createLikedPlaylist();
    }
    final idx = _playlists.indexWhere((p) => p.id == likedPlaylistId);
    if (idx == -1) return;
    final p = _playlists[idx];
    if (p.songs.any((s) => s.id == song.id)) {
      _playlists[idx] = p.copyWith(
        songs: p.songs.where((s) => s.id != song.id).toList(),
      );
      DatabaseService.removeSongFromPlaylist(likedPlaylistId, song.id);
    } else {
      _playlists[idx] = p.copyWith(songs: [...p.songs, song]);
      DatabaseService.addSongToPlaylist(likedPlaylistId, song.id, DateTime.now());
    }
    notifyListeners();
  }

  void _createLikedPlaylist() {
    final now = DateTime.now();
    _playlists.add(Playlist(id: likedPlaylistId, name: likedPlaylistName));
    DatabaseService.upsertPlaylist(
        likedPlaylistId, likedPlaylistName, now.toIso8601String(), now.toIso8601String());
  }

  List<Song> search(String query) {
    if (query.isEmpty) return _songs;
    final q = query.toLowerCase();
    return _songs.where((s) =>
      s.title.toLowerCase().contains(q) ||
      s.artist.toLowerCase().contains(q) ||
      s.album.toLowerCase().contains(q)
    ).toList();
  }

  List<Song> getSongsByArtist(String artist) {
    return _songs.where((s) => s.artist == artist).toList();
  }

  List<Song> getSongsByAlbum(String album) {
    return _songs.where((s) => s.album == album).toList();
  }

  List<String> get artists {
    return _songs.map((s) => s.artist).toSet().toList()..sort();
  }

  List<String> get albums {
    return _songs.map((s) => s.album).toSet().toList()..sort();
  }

  Future<void> loadLibrary() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final dbSongs = await DatabaseService.getSongs();
      final scannedSongs = await _scanService.scanDownloadedMusic();

      _songs.clear();
      for (final scanned in scannedSongs) {
        final existingIdx = dbSongs.indexWhere((s) => s.filePath == scanned.filePath);
        if (existingIdx != -1) {
          final existing = dbSongs[existingIdx];
          _songs.add(Song(
            id: existing.id,
            title: existing.title,
            artist: existing.artist,
            album: existing.album,
            albumArtPath: existing.albumArtPath ?? scanned.albumArtPath,
            filePath: scanned.filePath,
            duration: scanned.duration,
            downloadDate: existing.downloadDate,
            fileSize: scanned.fileSize,
          ));
        } else {
          final fileDate = await File(scanned.filePath).lastModified();
          _songs.add(Song(
            id: scanned.id,
            title: scanned.title,
            artist: scanned.artist,
            album: scanned.album,
            albumArtPath: scanned.albumArtPath,
            filePath: scanned.filePath,
            duration: scanned.duration,
            downloadDate: fileDate,
            fileSize: scanned.fileSize,
          ));
          DatabaseService.upsertSong(Song(
            id: scanned.id,
            title: scanned.title,
            artist: scanned.artist,
            album: scanned.album,
            albumArtPath: scanned.albumArtPath,
            filePath: scanned.filePath,
            duration: scanned.duration,
            downloadDate: fileDate,
            fileSize: scanned.fileSize,
          ));
        }
      }

      await _loadPlaylistsFromDb();
      _isInitialized = true;
    } catch (e) {
      _error = 'Error al escanear: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadPlaylistsFromDb() async {
    _playlists.clear();
    final playlistRows = await DatabaseService.getPlaylistRows();
    for (final row in playlistRows) {
      final pid = row['id'] as String;
      final songIds = await DatabaseService.getPlaylistSongRows(pid);
      final songs = <Song>[];
      for (final s in songIds) {
        final songId = s['songId'] as String;
        final song = _songs.where((s) => s.id == songId).toList();
        if (song.isNotEmpty) {
          songs.add(song.first);
        }
      }
      _playlists.add(Playlist(
        id: pid,
        name: row['name'] as String,
        songs: songs,
        createdAt: DateTime.parse(row['createdAt'] as String),
        updatedAt: DateTime.parse(row['updatedAt'] as String),
      ));
    }
    if (!_playlists.any((p) => p.id == likedPlaylistId)) {
      _createLikedPlaylist();
    }
  }

  Future<void> addSong(Song song) async {
    _songs.add(song);
    await DatabaseService.upsertSong(song);
    notifyListeners();
  }

  Future<void> removeSong(String id) async {
    _songs.removeWhere((s) => s.id == id);
    for (int i = 0; i < _playlists.length; i++) {
      if (_playlists[i].songs.any((s) => s.id == id)) {
        _playlists[i] = _playlists[i].copyWith(
          songs: _playlists[i].songs.where((s) => s.id != id).toList(),
        );
      }
    }
    await DatabaseService.deleteSong(id);
    notifyListeners();
  }

  Future<void> createPlaylist(String name) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final now = DateTime.now();
    _playlists.add(Playlist(id: id, name: name));
    await DatabaseService.upsertPlaylist(
        id, name, now.toIso8601String(), now.toIso8601String());
    notifyListeners();
  }

  Future<void> deletePlaylist(String id) async {
    _playlists.removeWhere((p) => p.id == id);
    await DatabaseService.deletePlaylist(id);
    notifyListeners();
  }

  Future<void> addSongToPlaylist(String playlistId, Song song) async {
    final index = _playlists.indexWhere((p) => p.id == playlistId);
    if (index != -1) {
      final playlist = _playlists[index];
      if (playlist.songs.any((s) => s.id == song.id)) return;
      _playlists[index] = playlist.copyWith(songs: [...playlist.songs, song]);
      await DatabaseService.addSongToPlaylist(playlistId, song.id, DateTime.now());
      if (!_songs.any((s) => s.id == song.id)) {
        _songs.add(song);
        await DatabaseService.upsertSong(song);
      }
      notifyListeners();
    }
  }

  Future<void> removeSongFromPlaylist(String playlistId, String songId) async {
    final index = _playlists.indexWhere((p) => p.id == playlistId);
    if (index != -1) {
      final playlist = _playlists[index];
      _playlists[index] = playlist.copyWith(
        songs: playlist.songs.where((s) => s.id != songId).toList(),
      );
      await DatabaseService.removeSongFromPlaylist(playlistId, songId);
      notifyListeners();
    }
  }
}
