import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../models/song.dart';

class DatabaseService {
  static Database? _db;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  static Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'precarium.db');
    return openDatabase(
      path,
      version: 3,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE songs (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            artist TEXT NOT NULL DEFAULT 'Unknown Artist',
            album TEXT NOT NULL DEFAULT 'Unknown Album',
            albumArtPath TEXT,
            filePath TEXT NOT NULL,
            duration INTEGER NOT NULL DEFAULT 0,
            trackNumber INTEGER NOT NULL DEFAULT 0,
            discNumber INTEGER,
            year INTEGER,
            genre TEXT,
            downloadDate TEXT,
            fileSize INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE playlists (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            createdAt TEXT NOT NULL,
            updatedAt TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE playlist_songs (
            playlistId TEXT NOT NULL,
            songId TEXT NOT NULL,
            addedAt TEXT NOT NULL,
            PRIMARY KEY (playlistId, songId),
            FOREIGN KEY (playlistId) REFERENCES playlists(id) ON DELETE CASCADE,
            FOREIGN KEY (songId) REFERENCES songs(id) ON DELETE CASCADE
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE songs ADD COLUMN fileSize INTEGER NOT NULL DEFAULT 0');
        } else if (oldVersion == 2) {
          try {
            await db.execute('ALTER TABLE songs ADD COLUMN fileSize INTEGER NOT NULL DEFAULT 0');
          } catch (_) {
            // column may already exist
          }
        }
      },
    );
  }

  // Playlist songs - all rows
  static Future<List<Map<String, dynamic>>> getAllPlaylistSongRows() async {
    final db = await database;
    return db.query('playlist_songs');
  }

  // Songs
  static Future<List<Song>> getSongs() async {
    final db = await database;
    final maps = await db.query('songs');
    return maps.map((m) => Song.fromDbMap(m)).toList();
  }

  static Future<Song?> getSong(String id) async {
    final db = await database;
    final maps = await db.query('songs', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Song.fromDbMap(maps.first);
  }

  static Future<void> upsertSong(Song song) async {
    final db = await database;
    await db.insert('songs', song.toDbMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<void> deleteSong(String id) async {
    final db = await database;
    await db.delete('songs', where: 'id = ?', whereArgs: [id]);
    await db.delete('playlist_songs', where: 'songId = ?', whereArgs: [id]);
  }

  // Playlists
  static Future<List<Map<String, dynamic>>> getPlaylistRows() async {
    final db = await database;
    return db.query('playlists');
  }

  static Future<void> upsertPlaylist(
      String id, String name, String createdAt, String updatedAt) async {
    final db = await database;
    await db.insert('playlists', {
      'id': id,
      'name': name,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<void> renamePlaylist(String id, String name) async {
    final db = await database;
    await db.update('playlists', {
      'name': name,
      'updatedAt': DateTime.now().toIso8601String(),
    }, where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> deletePlaylist(String id) async {
    final db = await database;
    await db.delete('playlist_songs',
        where: 'playlistId = ?', whereArgs: [id]);
    await db.delete('playlists', where: 'id = ?', whereArgs: [id]);
  }

  // Playlist songs
  static Future<List<Map<String, dynamic>>> getPlaylistSongRows(
      String playlistId) async {
    final db = await database;
    return db.query('playlist_songs',
        where: 'playlistId = ?', whereArgs: [playlistId]);
  }

  static Future<DateTime?> getSongAddedToPlaylistDate(
      String playlistId, String songId) async {
    final db = await database;
    final maps = await db.query('playlist_songs',
        where: 'playlistId = ? AND songId = ?',
        whereArgs: [playlistId, songId]);
    if (maps.isEmpty) return null;
    return DateTime.parse(maps.first['addedAt'] as String);
  }

  static Future<void> addSongToPlaylist(
      String playlistId, String songId, DateTime addedAt) async {
    final db = await database;
    await db.insert('playlist_songs', {
      'playlistId': playlistId,
      'songId': songId,
      'addedAt': addedAt.toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<void> removeSongFromPlaylist(
      String playlistId, String songId) async {
    final db = await database;
    await db.delete('playlist_songs',
        where: 'playlistId = ? AND songId = ?',
        whereArgs: [playlistId, songId]);
  }

  static Future<List<Song>> getPlaylistSongs(String playlistId) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT s.*, ps.addedAt as _addedAt
      FROM songs s
      INNER JOIN playlist_songs ps ON s.id = ps.songId
      WHERE ps.playlistId = ?
      ORDER BY ps.addedAt ASC
    ''', [playlistId]);
    return rows.map((m) {
      final s = Song.fromDbMap(m);
      return s;
    }).toList();
  }

  static Future<DateTime?> getPlaylistSongAddedAt(
      String playlistId, String songId) async {
    final db = await database;
    final maps = await db.query('playlist_songs',
        where: 'playlistId = ? AND songId = ?',
        whereArgs: [playlistId, songId]);
    if (maps.isEmpty) return null;
    return DateTime.parse(maps.first['addedAt'] as String);
  }

  static Future<void> setSongDownloadDate(
      String songId, DateTime date) async {
    final db = await database;
    await db.update('songs', {'downloadDate': date.toIso8601String()},
        where: 'id = ?', whereArgs: [songId]);
  }
}
