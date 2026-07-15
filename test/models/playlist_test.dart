import 'package:flutter_test/flutter_test.dart';
import 'package:precarium/models/playlist.dart';
import 'package:precarium/models/song.dart';

void main() {
  group('Playlist model', () {
    test('creates a playlist with required fields', () {
      final playlist = Playlist(id: '1', name: 'My Playlist');

      expect(playlist.id, '1');
      expect(playlist.name, 'My Playlist');
      expect(playlist.songs, isEmpty);
      expect(playlist.songCount, 0);
      expect(playlist.totalDuration, Duration.zero);
    });

    test('calculates song count and duration', () {
      final songs = [
        Song(id: '1', title: 'A', artist: 'X', filePath: '/a.mp3', duration: const Duration(seconds: 120)),
        Song(id: '2', title: 'B', artist: 'Y', filePath: '/b.mp3', duration: const Duration(seconds: 180)),
      ];

      final playlist = Playlist(id: '1', name: 'Test', songs: songs);

      expect(playlist.songCount, 2);
      expect(playlist.totalDuration, const Duration(seconds: 300));
    });

    test('copyWith updates fields correctly', () {
      final playlist = Playlist(id: '1', name: 'Original');
      final updated = playlist.copyWith(name: 'Updated');

      expect(updated.name, 'Updated');
      expect(updated.id, '1');
      expect(updated.createdAt, playlist.createdAt);
    });
  });
}
