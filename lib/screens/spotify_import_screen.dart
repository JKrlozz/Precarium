import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/csv_import_service.dart';
import '../providers/library_provider.dart';
import '../providers/download_provider.dart';
import '../providers/import_provider.dart';
import '../providers/navigation_provider.dart';
import '../theme/app_theme.dart';

enum _ImportStep { input, selecting, downloading, done }

class SpotifyImportScreen extends StatefulWidget {
  const SpotifyImportScreen({super.key});

  @override
  State<SpotifyImportScreen> createState() => _SpotifyImportScreenState();
}

class _SpotifyImportScreenState extends State<SpotifyImportScreen> {
  final CsvImportService _csvImport = CsvImportService();
  final _tracksScrollController = ScrollController();

  _ImportStep _step = _ImportStep.input;

  List<_ImportTrack> _tracks = [];
  final Set<int> _selectedIndices = {};
  String? _sourceName;

  bool _isLoading = false;
  String? _error;

  Set<int> _existingIndices = {};

  @override
  void dispose() {
    _tracksScrollController.dispose();
    super.dispose();
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
        });
        _computeExistingIndices();
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

  Future<void> _uncheckExisting() async {
    await _computeExistingIndices();
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

  Future<void> _computeExistingIndices() async {
    _existingIndices = {};
    final songs = context.read<LibraryProvider>().songs.toList();
    if (songs.isEmpty || _tracks.isEmpty) return;
    final names = _tracks.map((t) => t.name).toList();
    final artists = _tracks.map((t) => t.artists).toList();

    await Future.delayed(Duration.zero);

    _existingIndices = ImportProvider.batchFindExisting(names, artists, songs);

    if (mounted) setState(() {});
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
            'Sube un archivo CSV exportado desde Exportify, Soundiiz, etc.',
            style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
          ),
          const SizedBox(height: 24),

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
          const SizedBox(height: 24),
          _buildFileInput(theme),
        ],
      ),
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
