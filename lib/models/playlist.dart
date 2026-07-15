import 'song.dart';

class Playlist {
  final String id;
  final String name;
  final List<Song> songs;
  final DateTime createdAt;
  final DateTime updatedAt;

  Playlist({
    required this.id,
    required this.name,
    this.songs = const [],
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  int get songCount => songs.length;

  Duration get totalDuration {
    return songs.fold(Duration.zero, (sum, song) => sum + song.duration);
  }

  Playlist copyWith({
    String? id,
    String? name,
    List<Song>? songs,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Playlist(
      id: id ?? this.id,
      name: name ?? this.name,
      songs: songs ?? this.songs,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'songIds': songs.map((s) => s.id).toList(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };
}
