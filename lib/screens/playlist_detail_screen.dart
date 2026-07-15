import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../models/playlist.dart';
import '../providers/library_provider.dart';
import '../providers/player_provider.dart';
import '../widgets/song_tile.dart';
import '../widgets/mini_player.dart';
import '../theme/app_theme.dart';
import '../services/database_service.dart';

enum _SortMode { titleAsc, titleDesc, dateAddedAsc, dateAddedDesc, dateDownloaded }

class PlaylistDetailScreen extends StatefulWidget {
  final Playlist playlist;

  const PlaylistDetailScreen({super.key, required this.playlist});

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  _SortMode _sortMode = _SortMode.dateAddedDesc;
  final _searchController = TextEditingController();
  bool _isSearching = false;
  final Map<String, DateTime> _addedDates = {};

  @override
  void initState() {
    super.initState();
    _loadAddedDates();
  }

  Future<void> _loadAddedDates() async {
    final rows = await DatabaseService.getPlaylistSongRows(widget.playlist.id);
    for (final row in rows) {
      _addedDates[row['songId'] as String] = DateTime.parse(row['addedAt'] as String);
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Song> _sortedSongs(List<Song> songs) {
    final sorted = List<Song>.from(songs);
    switch (_sortMode) {
      case _SortMode.titleAsc:
        sorted.sort((a, b) => a.title.compareTo(b.title));
      case _SortMode.titleDesc:
        sorted.sort((a, b) => b.title.compareTo(a.title));
      case _SortMode.dateAddedAsc:
        sorted.sort((a, b) =>
            (_addedDates[a.id] ?? DateTime(2000)).compareTo(_addedDates[b.id] ?? DateTime(2000)));
      case _SortMode.dateAddedDesc:
        sorted.sort((a, b) =>
            (_addedDates[b.id] ?? DateTime(2000)).compareTo(_addedDates[a.id] ?? DateTime(2000)));
      case _SortMode.dateDownloaded:
        sorted.sort((a, b) {
          final da = a.downloadDate ?? DateTime(2000);
          final db = b.downloadDate ?? DateTime(2000);
          return db.compareTo(da);
        });
    }
    return sorted;
  }

  void _showSongContextMenu(BuildContext context, Song song) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceColor,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Material(type: MaterialType.transparency, child: ListTile(
              leading: const Icon(Icons.delete_outline, color: AppTheme.accentColor),
              title: const Text('Eliminar de la lista'),
              subtitle: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () {
                Navigator.pop(ctx);
                context.read<LibraryProvider>().removeSongFromPlaylist(widget.playlist.id, song.id);
              },
            )),
            Material(type: MaterialType.transparency, child: ListTile(
              leading: Icon(Icons.playlist_add, color: AppTheme.primaryColor),
              title: const Text('Añadir a lista'),
              onTap: () {
                Navigator.pop(ctx);
                _showAddToPlaylistDialog(song);
              },
            )),
            Material(type: MaterialType.transparency, child: ListTile(
              leading: Icon(Icons.queue_music, color: AppTheme.primaryColor),
              title: const Text('Añadir a la fila'),
              onTap: () {
                Navigator.pop(ctx);
                context.read<PlayerProvider>().addToQueue(song);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Añadida a la fila de reproducción')),
                );
              },
            )),
          ],
        ),
      ),
    );
  }

  void _showAddToPlaylistDialog(Song song) {
    final library = context.read<LibraryProvider>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: const Text('Añadir a lista'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: library.playlists.length,
            itemBuilder: (_, i) {
              final playlist = library.playlists[i];
              final alreadyIn = playlist.songs.any((s) => s.id == song.id);
              return Material(type: MaterialType.transparency, child: ListTile(
                title: Text(playlist.name),
                subtitle: Text('${playlist.songCount} canciones${alreadyIn ? ' (ya añadida)' : ''}'),
                onTap: () {
                  if (!alreadyIn) {
                    library.addSongToPlaylist(playlist.id, song);
                  }
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(alreadyIn ? 'Ya está en "${playlist.name}"' : 'Añadida a "${playlist.name}"')),
                  );
                },
              ));
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteSong(Song song) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: const Text('Eliminar canción'),
        content: Text('¿Eliminar "${song.title}" del dispositivo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              File(song.filePath).delete().then((_) {}, onError: (_) {});
              context.read<LibraryProvider>().removeSong(song.id);
            },
            child: const Text('Eliminar', style: TextStyle(color: AppTheme.accentColor)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LibraryProvider>(
      builder: (context, library, _) {
        final playlist = library.playlists.firstWhere(
          (p) => p.id == widget.playlist.id,
          orElse: () => widget.playlist,
        );
        final songs = _sortedSongs(playlist.songs);

        return Scaffold(
          backgroundColor: AppTheme.backgroundColor,
          appBar: AppBar(
            title: _isSearching
                ? TextField(
                    controller: _searchController,
                    autofocus: true,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: const InputDecoration(
                      hintText: 'Buscar en lista...',
                      hintStyle: TextStyle(color: AppTheme.textSecondary),
                      border: InputBorder.none,
                    ),
                    onChanged: (_) => setState(() {}),
                  )
                : Text(playlist.name),
            actions: [
              IconButton(
                icon: Icon(_isSearching ? Icons.close : Icons.search),
                onPressed: () {
                  setState(() {
                    _isSearching = !_isSearching;
                    if (!_isSearching) _searchController.clear();
                  });
                },
                tooltip: _isSearching ? 'Cerrar búsqueda' : 'Buscar',
              ),
              PopupMenuButton<_SortMode>(
                icon: const Icon(Icons.sort),
                onSelected: (mode) => setState(() => _sortMode = mode),
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: _SortMode.titleAsc,
                    child: Text('Título (A-Z)'),
                  ),
                  const PopupMenuItem(
                    value: _SortMode.titleDesc,
                    child: Text('Título (Z-A)'),
                  ),
                  const PopupMenuItem(
                    value: _SortMode.dateAddedAsc,
                    child: Text('Fecha añadida (más antigua)'),
                  ),
                  const PopupMenuItem(
                    value: _SortMode.dateAddedDesc,
                    child: Text('Fecha añadida (más reciente)'),
                  ),
                  const PopupMenuItem(
                    value: _SortMode.dateDownloaded,
                    child: Text('Fecha descargada'),
                  ),
                ],
              ),
            ],
          ),
          body: songs.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.playlist_play, size: 64, color: AppTheme.textSecondary),
                      SizedBox(height: 16),
                      Text(
                        'Lista vacía',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 18),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Añade canciones desde tu biblioteca',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    _buildHeader(playlist, songs),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.only(bottom: 80),
                        itemCount: songs.length,
                        itemBuilder: (context, index) {
                          final song = songs[index];
                          final query = _searchController.text.trim();
                          if (query.isNotEmpty &&
                              !song.title.toLowerCase().contains(query.toLowerCase()) &&
                              !song.artist.toLowerCase().contains(query.toLowerCase())) {
                            return const SizedBox.shrink();
                          }
                          final addedDate = _addedDates[song.id];
                          final extra = addedDate != null
                              ? '${song.formattedFileSize} • Añadida: ${addedDate.day.toString().padLeft(2, '0')}/${addedDate.month.toString().padLeft(2, '0')}/${addedDate.year}'
                              : song.formattedFileSize;
                          return SongTile(
                            song: song,
                            subtitleExtra: extra,
                            onTap: () => context.read<PlayerProvider>().playQueue(songs, startIndex: index),
                            onLongPress: () => _showSongContextMenu(context, song),
                            onDelete: () => _confirmDeleteSong(song),
                            onAddToPlaylist: () => _showAddToPlaylistDialog(song),
                            onAddToQueue: () {
                              context.read<PlayerProvider>().addToQueue(song);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Añadida a la fila de reproducción')),
                              );
                            },
                          );
                        },
                      ),
                    ),
                    const MiniPlayer(),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildHeader(Playlist playlist, List<Song> songs) {
    final duration = playlist.totalDuration;
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final durationStr = hours > 0
        ? '${hours}h ${minutes}m'
        : '${minutes}m ${duration.inSeconds.remainder(60)}s';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.dividerColor)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${songs.length} canciones — $durationStr',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
            ),
          ),
          IconButton(
            icon: Icon(Icons.play_circle_fill, color: AppTheme.primaryColor),
            iconSize: 32,
            tooltip: 'Reproducir todo',
            onPressed: () {
              if (songs.isNotEmpty) {
                context.read<PlayerProvider>().playQueue(songs);
              }
            },
          ),
        ],
      ),
    );
  }
}
