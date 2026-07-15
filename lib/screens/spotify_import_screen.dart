import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/spotify_service.dart';
import '../services/youtube_search_service.dart';
import '../providers/library_provider.dart';
import '../providers/download_provider.dart';
import '../theme/app_theme.dart';

enum _ImportStep { url, selecting, downloading, done }

class SpotifyImportScreen extends StatefulWidget {
  const SpotifyImportScreen({super.key});

  @override
  State<SpotifyImportScreen> createState() => _SpotifyImportScreenState();
}

class _SpotifyImportScreenState extends State<SpotifyImportScreen> {
  final SpotifyService _spotify = SpotifyService();
  final YouTubeSearchService _ytSearch = YouTubeSearchService();
  final _playlistUrlController = TextEditingController();

  _ImportStep _step = _ImportStep.url;
  SpotifyPlaylist? _playlist;
  final Set<String> _selectedTracks = {};
  bool _isLoading = false;
  bool _loginLoading = false;
  String? _error;
  int _downloaded = 0;
  int _failed = 0;
  int _total = 0;
  String _statusText = '';

  @override
  void initState() {
    super.initState();
    _spotify.loadTokens();
  }

  @override
  void dispose() {
    _playlistUrlController.dispose();
    _ytSearch.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() => _loginLoading = true);
    try {
      await _spotify.login();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _loginLoading = false);
    }
  }

  Future<void> _fetchPlaylist() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final playlist = await _spotify.getPlaylist(_playlistUrlController.text.trim());
      setState(() {
        _playlist = playlist;
        _selectedTracks.addAll(playlist.tracks.map((t) => t.id));
        _step = _ImportStep.selecting;
      });
    } on RequiresPremiumException {
      if (_spotify.isLoggedIn) {
        _error = 'Esta playlist requiere una cuenta Spotify Premium.';
      } else {
        _error = 'Esta playlist requiere cuenta Premium. Inicia sesión con una cuenta Premium para acceder.';
      }
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _startDownload() async {
    if (_playlist == null) return;
    final selected = _playlist!.tracks.where((t) => _selectedTracks.contains(t.id)).toList();
    if (selected.isEmpty) return;

    setState(() {
      _step = _ImportStep.downloading;
      _downloaded = 0;
      _failed = 0;
      _total = selected.length;
      _statusText = 'Buscando en YouTube...';
    });

    final downloadProvider = context.read<DownloadProvider>();

    for (int i = 0; i < selected.length; i++) {
      final track = selected[i];
      if (!mounted) return;

      setState(() {
        _statusText = '(${i + 1}/$_total) ${track.title}';
      });

      try {
        final results = await _ytSearch.search(track.searchQuery, musicOnly: true);
        if (results.isNotEmpty) {
          final first = results.first;
          downloadProvider.addDownload(
            first.id,
            first.title,
            artist: track.artistString,
            thumbnailUrl: first.thumbnailUrl,
          );
          setState(() => _downloaded++);
        } else {
          setState(() => _failed++);
        }
      } catch (_) {
        setState(() => _failed++);
      }

      await Future.delayed(const Duration(milliseconds: 500));
    }

    if (mounted) {
      setState(() {
        _step = _ImportStep.done;
        _statusText = '';
      });
      context.read<LibraryProvider>().loadLibrary();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Importar Spotify'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (!_spotify.isLoggedIn)
            TextButton.icon(
              onPressed: _loginLoading ? null : _login,
              icon: _loginLoading
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.login, size: 18),
              label: const Text('Iniciar sesión'),
            )
          else
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Cerrar sesión',
              onPressed: () {
                _spotify.clearTokens();
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Sesión de Spotify cerrada')),
                );
              },
            ),
        ],
      ),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    switch (_step) {
      case _ImportStep.url:
        return _buildUrlForm(theme);
      case _ImportStep.selecting:
        return _buildSelection(theme);
      case _ImportStep.downloading:
        return _buildProgress(theme);
      case _ImportStep.done:
        return _buildDone(theme);
    }
  }

  Widget _buildUrlForm(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.queue_music, size: 64, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            'Importar playlist de Spotify',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
          ),
          const SizedBox(height: 8),
          Text(
            'Pega el enlace de cualquier playlist pública de Spotify. La app buscará y descargará las canciones automáticamente desde YouTube.',
            style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
          ),
          if (!_spotify.isLoggedIn) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Playlists públicas funcionan sin iniciar sesión. Para playlists privadas inicia sesión arriba.',
                      style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          TextField(
            controller: _playlistUrlController,
            decoration: const InputDecoration(
              hintText: 'https://open.spotify.com/playlist/...',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.link),
            ),
            style: TextStyle(color: theme.colorScheme.onSurface),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _fetchPlaylist,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : const Text('Obtener canciones', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline, color: AppTheme.accentColor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_error!, style: const TextStyle(color: AppTheme.accentColor, fontSize: 13)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSelection(ThemeData theme) {
    if (_playlist == null) return const SizedBox.shrink();
    final tracks = _playlist!.tracks;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: theme.colorScheme.surface,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_playlist!.name,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
                    const SizedBox(height: 4),
                    Text('${tracks.length} canciones · ${_selectedTracks.length} seleccionadas',
                        style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.select_all, color: Theme.of(context).colorScheme.primary),
                onPressed: () => setState(() => _selectedTracks.addAll(tracks.map((t) => t.id))),
                tooltip: 'Seleccionar todo',
              ),
              IconButton(
                icon: Icon(Icons.deselect, color: Theme.of(context).colorScheme.primary),
                onPressed: () => setState(() => _selectedTracks.clear()),
                tooltip: 'Deseleccionar todo',
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            itemCount: tracks.length,
            itemBuilder: (context, index) {
              final track = tracks[index];
              final selected = _selectedTracks.contains(track.id);
              return CheckboxListTile(
                value: selected,
                onChanged: (v) => setState(() {
                  if (v == true) {
                    _selectedTracks.add(track.id);
                  } else {
                    _selectedTracks.remove(track.id);
                  }
                }),
                title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface)),
                subtitle: Text(track.artistString, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                secondary: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(Icons.music_note, color: AppTheme.textSecondary),
                ),
              );
            },
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selectedTracks.isEmpty ? null : _startDownload,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(
                  'Descargar ${_selectedTracks.isEmpty ? "" : "${_selectedTracks.length} "}canciones',
                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgress(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text('Descargando...', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
            const SizedBox(height: 8),
            Text(_statusText, style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            LinearProgressIndicator(value: _total > 0 ? (_downloaded + _failed) / _total : 0),
            const SizedBox(height: 8),
            Text('$_downloaded descargadas · $_failed fallidas',
                style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
          ],
        ),
      ),
    );
  }

  Widget _buildDone(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 80, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 24),
            Text('Importación completada', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
            const SizedBox(height: 8),
            Text('$_downloaded canciones descargadas · $_failed fallidas',
                style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
              child: const Text('Volver', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
