import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../services/spotify_service.dart';
import '../services/csv_import_service.dart';
import '../providers/library_provider.dart';
import '../providers/download_provider.dart';
import '../providers/import_provider.dart';
import '../providers/navigation_provider.dart';
import '../theme/app_theme.dart';

enum _ImportStep { input, selecting, downloading, done }
enum _InputMode { url, file }

class SpotifyImportScreen extends StatefulWidget {
  const SpotifyImportScreen({super.key});

  @override
  State<SpotifyImportScreen> createState() => _SpotifyImportScreenState();
}

class _SpotifyImportScreenState extends State<SpotifyImportScreen> {
  final SpotifyService _spotify = SpotifyService();
  final CsvImportService _csvImport = CsvImportService();
  final _playlistUrlController = TextEditingController();

  _ImportStep _step = _ImportStep.input;
  _InputMode _inputMode = _InputMode.url;

  // Track data from either source
  List<_ImportTrack> _tracks = [];
  final Set<int> _selectedIndices = {};
  String? _sourceName;

  bool _isLoading = false;
  bool _loginLoading = false;
  String? _error;

  Set<int> _existingIndices = {};
  final _tracksScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _spotify.loadTokens();
  }

  @override
  void dispose() {
    _playlistUrlController.dispose();
    _tracksScrollController.dispose();
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

  Future<void> _fetchFromUrl() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final playlist = await _spotify.getPlaylist(_playlistUrlController.text.trim());
      _tracks = playlist.tracks.map((t) => _ImportTrack(
        name: t.title,
        artists: t.artistString,
        searchQuery: t.searchQuery,
      )).toList();
      _sourceName = playlist.name;
      _selectedIndices.addAll(List.generate(_tracks.length, (i) => i));
      if (mounted) {
        setState(() {
          _step = _ImportStep.selecting;
          _computeExistingIndices();
        });
      }
    } on RequiresPremiumException {
      _error = _spotify.isLoggedIn
          ? 'Esta playlist requiere una cuenta Spotify Premium.'
          : 'Esta playlist requiere cuenta Premium. Inicia sesión con una cuenta Premium para acceder.';
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickCsvFile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final result = await _csvImport.pickAndParse();
      if (result == null) {
        setState(() => _isLoading = false);
        return;
      }
      _tracks = result.tracks.map((t) => _ImportTrack(
        name: t.name,
        artists: t.artists,
        searchQuery: t.searchQuery,
      )).toList();
      _sourceName = result.fileName;
      _selectedIndices.addAll(List.generate(_tracks.length, (i) => i));
      if (mounted) {
        setState(() {
          _step = _ImportStep.selecting;
          _computeExistingIndices();
        });
      }
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _startDownload() {
    if (_tracks.isEmpty) return;
    final selected = _selectedIndices.map((i) => _tracks[i]).toList();
    if (selected.isEmpty) return;

    context.read<ImportProvider>().startImport(
      names: selected.map((t) => t.name).toList(),
      artists: selected.map((t) => t.artists).toList(),
      searchQueries: selected.map((t) => t.searchQuery).toList(),
      existingLibrarySongs: context.read<LibraryProvider>().songs.toList(),
      downloadProvider: context.read<DownloadProvider>(),
      libraryProvider: context.read<LibraryProvider>(),
    );

    context.read<NavigationProvider>().switchToTab(2);
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  // ── Helpers ──

  void _uncheckExisting() {
    _computeExistingIndices();
    int count = 0;
    for (final i in _existingIndices) {
      if (_selectedIndices.remove(i)) count++;
    }
    setState(() {});
    if (count > 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$count canción(es) ya descargada(s) — deseleccionadas')),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se encontraron canciones ya descargadas')),
      );
    }
  }

  bool _matchesExisting(String importName, List<Song> librarySongs) {
    String normalize(String s) {
      return s.trim().toLowerCase().replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
    }
    final needle = normalize(importName);
    if (needle.isEmpty) return false;
    return librarySongs.any((s) {
      final title = normalize(s.title);
      return title.contains(needle) || needle.contains(title);
    });
  }

  void _computeExistingIndices() {
    _existingIndices = {};
    final songs = context.read<LibraryProvider>().songs.toList();
    for (int i = 0; i < _tracks.length; i++) {
      if (_matchesExisting(_tracks[i].name, songs)) {
        _existingIndices.add(i);
      }
    }
  }

  void _resetToInput() {
    context.read<ImportProvider>().reset();
    setState(() {
      _step = _ImportStep.input;
      _tracks = [];
      _selectedIndices.clear();
      _error = null;
      _sourceName = null;
      _existingIndices = {};
    });
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          _step == _ImportStep.selecting && _sourceName != null
              ? _sourceName!
              : 'Importar música',
          overflow: TextOverflow.ellipsis,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _step == _ImportStep.selecting ? _resetToInput : () => Navigator.pop(context),
        ),
        actions: [
          if (_step == _ImportStep.input && !_spotify.isLoggedIn)
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
          else if (_step == _ImportStep.input && _spotify.isLoggedIn)
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
      case _ImportStep.input:
        return _buildInput(theme);
      case _ImportStep.selecting:
        return _buildSelection(theme);
      case _ImportStep.downloading:
      case _ImportStep.done:
        return const SizedBox();
    }
  }

  // ── Input screen ──

  Widget _buildInput(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.queue_music, size: 64, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            'Importar música',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
          ),
          const SizedBox(height: 8),
          Text(
            'Pega un enlace de Spotify o sube un archivo CSV exportado desde Exportify, Soundiiz, etc.',
            style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
          ),
          const SizedBox(height: 24),

          // Mode selector
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<_InputMode>(
              segments: const [
                ButtonSegment(value: _InputMode.url, label: Text('Enlace'), icon: Icon(Icons.link)),
                ButtonSegment(value: _InputMode.file, label: Text('Archivo'), icon: Icon(Icons.upload_file)),
              ],
              selected: {_inputMode},
              onSelectionChanged: (v) => setState(() {
                _inputMode = v.first;
                _error = null;
              }),
            ),
          ),
          const SizedBox(height: 24),

          if (_inputMode == _InputMode.url) _buildUrlInput(theme),
          if (_inputMode == _InputMode.file) _buildFileInput(theme),

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

  Widget _buildUrlInput(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!_spotify.isLoggedIn)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
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
        TextField(
          controller: _playlistUrlController,
          decoration: const InputDecoration(
            hintText: 'https://open.spotify.com/playlist/...',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.link),
          ),
          style: TextStyle(color: theme.colorScheme.onSurface),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _fetchFromUrl,
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
      ],
    );
  }

  Widget _buildFileInput(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
              width: 2,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(Icons.upload_file, size: 48, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 12),
              Text(
                'Selecciona un archivo CSV',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: theme.colorScheme.onSurface),
              ),
              const SizedBox(height: 4),
              Text(
                'Exporta tu playlist desde Exportify (CSV o XLSX)\ny selecciona el archivo descargado',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _pickCsvFile,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : const Icon(Icons.folder_open),
                  label: Text(_isLoading ? 'Leyendo archivo...' : 'Importar', style: const TextStyle(color: Colors.black)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Selection screen ──

  Widget _buildSelection(ThemeData theme) {
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
                    if (_sourceName != null)
                      Text(_sourceName!,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
                    const SizedBox(height: 4),
                    Text('${_tracks.length} canciones · ${_selectedIndices.length} seleccionadas',
                        style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.select_all, color: Theme.of(context).colorScheme.primary),
                onPressed: () => setState(() => _selectedIndices.addAll(List.generate(_tracks.length, (i) => i))),
                tooltip: 'Seleccionar todo',
              ),
              IconButton(
                icon: Icon(Icons.deselect, color: Theme.of(context).colorScheme.primary),
                onPressed: () => setState(() => _selectedIndices.clear()),
                tooltip: 'Deseleccionar todo',
              ),
              IconButton(
                icon: Icon(Icons.checklist, color: Theme.of(context).colorScheme.primary),
                onPressed: _uncheckExisting,
                tooltip: 'Detectar ya descargadas',
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: Scrollbar(
            controller: _tracksScrollController,
            thumbVisibility: true,
            interactive: true,
            child: ListView.builder(
            controller: _tracksScrollController,
            itemCount: _tracks.length,
            itemBuilder: (context, index) {
              final track = _tracks[index];
              final selected = _selectedIndices.contains(index);
              return CheckboxListTile(
                value: selected,
                onChanged: (v) => setState(() {
                  if (v == true) {
                    _selectedIndices.add(index);
                  } else {
                    _selectedIndices.remove(index);
                  }
                }),
                title: Text(track.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface)),
                subtitle: Text(
                    _existingIndices.contains(index)
                        ? '${track.artists.isNotEmpty ? track.artists : 'Sin artista'} · ya descargada'
                        : (track.artists.isNotEmpty ? track.artists : 'Sin artista'),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: _existingIndices.contains(index)
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    )),
                secondary: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: _existingIndices.contains(index)
                        ? theme.colorScheme.primary.withValues(alpha: 0.15)
                        : theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(
                    _existingIndices.contains(index) ? Icons.check_circle : Icons.music_note,
                    color: _existingIndices.contains(index)
                        ? theme.colorScheme.primary
                        : AppTheme.textSecondary,
                  ),
                ),
              );
            },
          ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selectedIndices.isEmpty ? null : _startDownload,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(
                  'Descargar ${_selectedIndices.isEmpty ? "" : "${_selectedIndices.length} "}canciones',
                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Download progress ──

}

class _ImportTrack {
  final String name;
  final String artists;
  final String searchQuery;

  _ImportTrack({
    required this.name,
    required this.artists,
    required this.searchQuery,
  });
}
