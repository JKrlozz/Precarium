import 'package:flutter_test/flutter_test.dart';
import 'package:precarium/models/song.dart';

void main() {
  group('Song model', () {
    test('creates a Song with required fields', () {
      final song = Song(
        id: '1',
        title: 'Test Song',
        artist: 'Test Artist',
        filePath: '/music/test.mp3',
      );

      expect(song.id, '1');
      expect(song.title, 'Test Song');
      expect(song.artist, 'Test Artist');
      expect(song.filePath, '/music/test.mp3');
      expect(song.album, 'Unknown Album');
      expect(song.duration, Duration.zero);
    });

    test('formats duration correctly', () {
      final song = Song(
        id: '1',
        title: 'Test',
        artist: 'Artist',
        filePath: '/test.mp3',
        duration: const Duration(minutes: 3, seconds: 45),
      );

      expect(song.formattedDuration, '03:45');
    });

    test('formats long duration correctly', () {
      final song = Song(
        id: '1',
        title: 'Test',
        artist: 'Artist',
        filePath: '/test.mp3',
        duration: const Duration(hours: 1, minutes: 15, seconds: 30),
      );

      expect(song.formattedDuration, '75:30');
    });

    test('serializes to JSON and back', () {
      final song = Song(
        id: '123',
        title: 'Canción',
        artist: 'Artista',
        album: 'Álbum',
        filePath: '/music/song.mp3',
        duration: const Duration(seconds: 180),
        trackNumber: 1,
        year: 2024,
        genre: 'Pop',
      );

      final json = song.toJson();
      final restored = Song.fromJson(json);

      expect(restored.id, song.id);
      expect(restored.title, song.title);
      expect(restored.artist, song.artist);
      expect(restored.album, song.album);
      expect(restored.filePath, song.filePath);
      expect(restored.duration, song.duration);
      expect(restored.trackNumber, song.trackNumber);
      expect(restored.year, song.year);
      expect(restored.genre, song.genre);
    });
  });
}
