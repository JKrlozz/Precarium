import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../providers/library_provider.dart';
import '../providers/player_provider.dart';
import '../widgets/song_tile.dart';
import '../theme/app_theme.dart';
import 'playlist_detail_screen.dart';

enum _LibraryTab { songs, artists, albums, playlists }

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  _LibraryTab _currentTab = _LibraryTab.songs;
  final _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final library = context.read<LibraryProvider>();
      if (!library.isInitialized && !library.isLoading) {
        library.loadLibrary();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showSongContextMenu(BuildContext context, Song song, List<dynamic> songs, int index) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceColor,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppTheme.accentColor),
              title: const Text('Eliminar canción'),
              subtitle: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDeleteSong(song);
              },
            ),
            ListTile(
              leading: const Icon(Icons.playlist_add, color: AppTheme.primaryColor),
              title: const Text('Añadir a lista'),
              onTap: () {
                Navigator.pop(ctx);
                _showAddToPlaylistDialog(song);
              },
            ),
            ListTile(
              leading: const Icon(Icons.queue_music, color: AppTheme.primaryColor),
              title: const Text('Añadir a la fila'),
              onTap: () {
                Navigator.pop(ctx);
                context.read<PlayerProvider>().addToQueue(song);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Añadida a la fila de reproducción')),
                );
              },
            ),
          ],
        ),
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

  void _showAddToPlaylistDialog(Song song) {
    final library = context.read<LibraryProvider>();
    if (library.playlists.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay listas de reproducción. Crea una primero.')),
      );
      return;
    }
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
              return ListTile(
                title: Text(playlist.name),
                subtitle: Text('${playlist.songCount} canciones'),
                onTap: () {
                  library.addSongToPlaylist(playlist.id, song);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Añadida a "${playlist.name}"')),
                  );
                },
              );
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

  void _showCreatePlaylistDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: const Text('Nueva lista'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Nombre de la lista',
            border: OutlineInputBorder(),
          ),
          style: const TextStyle(color: AppTheme.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                context.read<LibraryProvider>().createPlaylist(controller.text.trim());
                Navigator.pop(ctx);
              }
            },
            child: const Text('Crear'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LibraryProvider>(
      builder: (context, library, _) {
        return Scaffold(
          appBar: AppBar(
            title: _isSearching
                ? TextField(
                    controller: _searchController,
                    autofocus: true,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: const InputDecoration(
                      hintText: 'Buscar en biblioteca...',
                      hintStyle: TextStyle(color: AppTheme.textSecondary),
                      border: InputBorder.none,
                    ),
                    onChanged: (_) => setState(() {}),
                  )
                : Text(
                    library.isInitialized
                        ? 'Tu Biblioteca'
                        : 'Precarium',
                  ),
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
              if (_currentTab == _LibraryTab.playlists)
                TextButton.icon(
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text('Nueva'),
                  onPressed: _showCreatePlaylistDialog,
                ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => library.loadLibrary(),
                tooltip: 'Escanear',
              ),
            ],
          ),
          body: _buildBody(library),
        );
      },
    );
  }

  Widget _buildBody(LibraryProvider library) {
    if (library.isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Escaneando biblioteca...', style: TextStyle(color: AppTheme.textSecondary)),
          ],
        ),
      );
    }

    if (library.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppTheme.accentColor),
            const SizedBox(height: 16),
            Text(library.error!, style: const TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => library.loadLibrary(),
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
            ),
          ],
        ),
      );
    }

    if (!library.isInitialized) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.library_music_outlined, size: 80,
                color: AppTheme.textSecondary),
            const SizedBox(height: 16),
            const Text(
              'Bienvenido a Precarium',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Escanea tu dispositivo para encontrar\ntu música local',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => library.loadLibrary(),
              icon: const Icon(Icons.search),
              label: const Text('Escanear dispositivo'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        _buildTabs(),
        const Divider(height: 1),
        Expanded(child: _buildTabContent(library)),
      ],
    );
  }

  Widget _buildTabs() {
    return Row(
      children: _LibraryTab.values.map((tab) {
        final isSelected = _currentTab == tab;
        final labels = {
          _LibraryTab.songs: 'Canciones',
          _LibraryTab.artists: 'Artistas',
          _LibraryTab.albums: 'Álbumes',
          _LibraryTab.playlists: 'Listas',
        };
        final icons = {
          _LibraryTab.songs: Icons.music_note,
          _LibraryTab.artists: Icons.person,
          _LibraryTab.albums: Icons.album,
          _LibraryTab.playlists: Icons.playlist_play,
        };
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _currentTab = tab),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isSelected ? AppTheme.primaryColor : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icons[tab], size: 16, color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    labels[tab]!,
                    style: TextStyle(
                      color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTabContent(LibraryProvider library) {
    switch (_currentTab) {
      case _LibraryTab.songs:
        return _buildSongsView(library);
      case _LibraryTab.artists:
        return _buildArtistsView(library);
      case _LibraryTab.albums:
        return _buildAlbumsView(library);
      case _LibraryTab.playlists:
        return _buildPlaylistsView(library);
    }
  }

  Widget _buildSongsView(LibraryProvider library) {
    final query = _searchController.text.trim();
    final songs = query.isEmpty ? library.songs : library.search(query);

    if (songs.isEmpty) {
      return Center(
        child: Text(
          query.isEmpty ? 'No hay canciones' : 'Sin resultados para "$query"',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
      );
    }

    return Column(
      children: [
        if (query.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Text(
                  '${songs.length} canciones',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                ),
                const Spacer(),
                Text(
                  '${library.totalDuration.inHours}h ${library.totalDuration.inMinutes.remainder(60)}m',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: songs.length,
            itemBuilder: (context, index) {
              final song = songs[index];
              final extra = song.downloadDate != null
                  ? '${song.formattedFileSize} • ${song.formattedDownloadDate}'
                  : song.formattedFileSize;
              return SongTile(
                song: song,
                subtitleExtra: extra,
                onTap: () => context.read<PlayerProvider>().playQueue(songs, startIndex: index),
                onLongPress: () => _showSongContextMenu(context, song, songs, index),
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
      ],
    );
  }

  Widget _buildArtistsView(LibraryProvider library) {
    final artists = library.artists;
    if (artists.isEmpty) {
      return const Center(child: Text('Sin artistas', style: TextStyle(color: AppTheme.textSecondary)));
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: artists.length,
      itemBuilder: (context, index) {
        final artist = artists[index];
        final count = library.getSongsByArtist(artist).length;
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: AppTheme.cardColor,
            child: const Icon(Icons.person),
          ),
          title: Text(artist, style: const TextStyle(fontWeight: FontWeight.w500)),
          subtitle: Text('$count canciones', style: const TextStyle(color: AppTheme.textSecondary)),
          onTap: () {
            final songs = library.getSongsByArtist(artist);
            context.read<PlayerProvider>().playQueue(songs);
          },
        );
      },
    );
  }

  Widget _buildAlbumsView(LibraryProvider library) {
    final albums = library.albums;
    if (albums.isEmpty) {
      return const Center(child: Text('Sin álbumes', style: TextStyle(color: AppTheme.textSecondary)));
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: albums.length,
      itemBuilder: (context, index) {
        final album = albums[index];
        final songs = library.getSongsByAlbum(album);
        return ListTile(
          leading: Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.album),
          ),
          title: Text(album, style: const TextStyle(fontWeight: FontWeight.w500)),
          subtitle: Text('${songs.length} canciones', style: const TextStyle(color: AppTheme.textSecondary)),
          onTap: () => context.read<PlayerProvider>().playQueue(songs),
        );
      },
    );
  }

  Widget _buildPlaylistsView(LibraryProvider library) {
    if (library.playlists.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.playlist_add, size: 64, color: AppTheme.textSecondary),
            const SizedBox(height: 16),
            const Text('Sin listas de reproducción', style: TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _showCreatePlaylistDialog,
              icon: const Icon(Icons.add),
              label: const Text('Crear lista'),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: library.playlists.length,
      itemBuilder: (context, index) {
        final playlist = library.playlists[index];
        return ListTile(
          leading: Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.playlist_play, color: AppTheme.primaryColor),
          ),
          title: Text(playlist.name, style: const TextStyle(fontWeight: FontWeight.w500)),
          subtitle: Text(
            '${playlist.songCount} canciones',
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline, color: AppTheme.textSecondary),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: AppTheme.surfaceColor,
                  title: const Text('Eliminar lista'),
                  content: Text('¿Eliminar "${playlist.name}"?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancelar'),
                    ),
                    TextButton(
                      onPressed: () {
                        library.deletePlaylist(playlist.id);
                        Navigator.pop(ctx);
                      },
                      child: const Text('Eliminar', style: TextStyle(color: AppTheme.accentColor)),
                    ),
                  ],
                ),
              );
            },
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChangeNotifierProvider.value(
                  value: context.read<LibraryProvider>(),
                  child: PlaylistDetailScreen(playlist: playlist),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
