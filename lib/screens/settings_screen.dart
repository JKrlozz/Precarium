import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/backup_provider.dart';
import '../providers/download_provider.dart';
import '../providers/import_provider.dart';
import '../providers/library_provider.dart';
import '../providers/settings_provider.dart';
import '../services/database_service.dart';
import 'spotify_import_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const List<Color> presetColors = [
    Color(0xFF1DB954), // Green
    Color(0xFF2196F3), // Blue
    Color(0xFF9C27B0), // Purple
    Color(0xFFE91E63), // Pink
    Color(0xFFF44336), // Red
    Color(0xFFFF9800), // Orange
    Color(0xFF009688), // Teal
    Color(0xFF3F51B5), // Indigo
    Color(0xFF00BCD4), // Cyan
    Color(0xFFFFEB3B), // Yellow
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Configuración'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Consumer2<SettingsProvider, BackupProvider>(
        builder: (context, settings, backup, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SectionHeader(title: 'Apariencia'),
              const SizedBox(height: 16),
              _ThemeSelector(settings: settings),
              const SizedBox(height: 24),
              _ColorPicker(settings: settings),
              const SizedBox(height: 24),
              _SectionHeader(title: 'Spotify'),
              const SizedBox(height: 8),
              _SettingsButton(
                icon: Icons.queue_music,
                label: 'Importar lista de Spotify',
                subtitle: 'Busca y descarga canciones desde una playlist',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SpotifyImportScreen()),
                ),
              ),
              const SizedBox(height: 24),
              _SectionHeader(title: 'Google Drive'),
              const SizedBox(height: 8),
              _DriveSection(backup: backup),
              const SizedBox(height: 24),
              _SectionHeader(title: 'Respaldo automático'),
              const SizedBox(height: 8),
              const _AutoBackupSection(),
              const SizedBox(height: 24),
              _SectionHeader(title: 'Acerca de'),
              const SizedBox(height: 8),
              _InfoTile(label: 'Versión', value: '1.0.4'),
            ],
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      title,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
        letterSpacing: 1,
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  const _InfoTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Text(label, style: TextStyle(color: theme.colorScheme.onSurface)),
          const Spacer(),
          Text(value, style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
        ],
      ),
    );
  }
}

class _ThemeSelector extends StatelessWidget {
  final SettingsProvider settings;
  const _ThemeSelector({required this.settings});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Modo de tema',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: theme.colorScheme.onSurface),
            ),
          ),
          _ThemeOption(
            icon: Icons.brightness_auto,
            label: 'Sistema',
            subtitle: 'Usar la configuración del dispositivo',
            isSelected: settings.themeMode == ThemeMode.system,
            onTap: () => settings.setThemeMode(ThemeMode.system),
          ),
          _ThemeOption(
            icon: Icons.dark_mode,
            label: 'Oscuro',
            subtitle: 'Tema oscuro permanente',
            isSelected: settings.themeMode == ThemeMode.dark,
            onTap: () => settings.setThemeMode(ThemeMode.dark),
          ),
          _ThemeOption(
            icon: Icons.light_mode,
            label: 'Claro',
            subtitle: 'Tema claro permanente',
            isSelected: settings.themeMode == ThemeMode.light,
            onTap: () => settings.setThemeMode(ThemeMode.light),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon, color: theme.colorScheme.primary),
      title: Text(label, style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
      trailing: isSelected
          ? Icon(Icons.check_circle, color: theme.colorScheme.primary, size: 20)
          : null,
      onTap: onTap,
    );
  }
}

class _SettingsButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  const _SettingsButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(label, style: TextStyle(color: theme.colorScheme.onSurface)),
        subtitle: Text(subtitle, style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _DriveSection extends StatefulWidget {
  final BackupProvider backup;
  const _DriveSection({required this.backup});

  @override
  State<_DriveSection> createState() => _DriveSectionState();
}

class _DriveSectionState extends State<_DriveSection> {
  bool _cancelled = false;
  BackupProvider get _backup => widget.backup;

  @override
  void dispose() {
    _cancelled = true;
    super.dispose();
  }

  Future<void> _onConnect() async {
    try {
      await context.read<BackupProvider>().connectToDrive();
      if (!mounted || _cancelled) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Conectado a Google Drive'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted || _cancelled) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _onDisconnect() async {
    await context.read<BackupProvider>().disconnectFromDrive();
    if (!mounted || _cancelled) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Desconectado de Google Drive')),
    );
  }

  Future<void> _showBackedUpSongs() async {
    try {
      final files = await context.read<BackupProvider>().listBackedUpSongs();
      if (!mounted) return;
      final sorted = List<Map<String, dynamic>>.from(files)
        ..sort((a, b) => ((a['name'] as String?) ?? '').compareTo((b['name'] as String?) ?? ''));
      await _showBackedUpSongsDialog(sorted);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _showBackedUpSongsDialog(List<Map<String, dynamic>> files) async {
    final theme = Theme.of(context);
    String query = '';
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          List<Map<String, dynamic>> filtered(List<Map<String, dynamic>> all) {
            if (query.trim().isEmpty) return all;
            final q = query.toLowerCase();
            return all.where((f) {
              final name = ((f['displayTitle'] as String?) ?? '').toLowerCase();
              return name.contains(q);
            }).toList();
          }

          return AlertDialog(
            backgroundColor: theme.colorScheme.surface,
            title: Text('Canciones respaldadas (${files.length})'),
            content: SizedBox(
              width: double.maxFinite,
              height: 400,
              child: Column(
                children: [
                  TextField(
                    style: TextStyle(color: theme.colorScheme.onSurface),
                    decoration: InputDecoration(
                      hintText: 'Buscar canción por título o artista...',
                      hintStyle: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                      prefixIcon: Icon(Icons.search, size: 20, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (v) => setDialogState(() => query = v),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: files.isEmpty
                        ? const Center(child: Text('No hay canciones respaldadas'))
                        : filtered(files).isEmpty
                            ? const Center(child: Text('Sin resultados'))
                            : ListView.separated(
                                itemCount: filtered(files).length,
                                separatorBuilder: (_, _) => const Divider(height: 1),
                                itemBuilder: (_, i) {
                                  final f = filtered(files)[i];
                                  final name = f['displayTitle'] as String? ?? '';
                                  final size = f['size'] as String?;
                                  return ListTile(
                                    dense: true,
                                    title: Text(name, style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface)),
                                    subtitle: size != null
                                        ? Text(_formatSize(int.tryParse(size) ?? 0),
                                            style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)))
                                        : null,
                                    trailing: IconButton(
                                      icon: Icon(Icons.delete_outline, color: Colors.red.shade300, size: 20),
                                      onPressed: () async {
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (c) => AlertDialog(
                                            backgroundColor: theme.colorScheme.surface,
                                            title: const Text('¿Eliminar?'),
                                            content: Text('Eliminar "$name" de Drive?'),
                                            actions: [
                                              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
                                              TextButton(
                                                onPressed: () => Navigator.pop(c, true),
                                                style: TextButton.styleFrom(foregroundColor: Colors.red),
                                                child: const Text('Eliminar'),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (confirm == true) {
                                          try {
                                            await context.read<BackupProvider>().deleteBackedUpSong(f['id'] as String);
                                            if (context.mounted) {
                                              files.remove(f);
                                              setDialogState(() {});
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('Eliminado'), backgroundColor: Colors.green),
                                              );
                                            }
                                          } catch (e) {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
                                              );
                                            }
                                          }
                                        }
                                      },
                                    ),
                                  );
                                },
                              ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
            ],
          );
        },
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _onPurge() async {
    final first = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar todos los respaldos?'),
        content: const Text(
          'Se borrarán todos tus datos de respaldo en Google Drive. Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sí, eliminar'),
          ),
        ],
      ),
    );
    if (first != true || !mounted || _cancelled) return;

    final second = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Estás completamente seguro?'),
        content: const Text(
          'Esta es tu última oportunidad. Todos los archivos de respaldo en Drive serán eliminados permanentemente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No, conservar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sí, purgar todo'),
          ),
        ],
      ),
    );
    if (second != true || !mounted || _cancelled) return;

    try {
      await context.read<BackupProvider>().purgeAllBackupData();
      if (!mounted || _cancelled) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Datos de respaldo eliminados de Drive'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted || _cancelled) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _showBackupTypeDialog() async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => _BackupChoiceDialog(isUpload: true),
    );
    if (result == null || !mounted) return;
    final library = context.read<LibraryProvider>();
    final settings = context.read<SettingsProvider>();
    final backupProv = context.read<BackupProvider>();
    final playlists = await DatabaseService.getPlaylistRows();
    final playlistSongs = await DatabaseService.getAllPlaylistSongRows();

    try {
      if (result == 'light') {
        await backupProv.uploadLigeroBackup(
          songs: library.songs,
          playlists: playlists,
          playlistSongs: playlistSongs,
          themeMode: settings.themeMode.index,
          primaryColor: settings.primaryColor.toARGB32(),
        );
      } else {
        await backupProv.uploadCompletoBackup(
          songs: library.songs,
          playlists: playlists,
          playlistSongs: playlistSongs,
          themeMode: settings.themeMode.index,
          primaryColor: settings.primaryColor.toARGB32(),
        );
      }
      if (!mounted || _cancelled) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result == 'full'
              ? 'Respaldo completo subido a Drive'
              : 'Respaldo ligero subido a Drive'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted || _cancelled) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _showRestoreTypeDialog() async {
    final result = await showDialog<BackupChoice>(
      context: context,
      builder: (ctx) => _BackupChoiceDialog(isUpload: false),
    );
    if (result == null || !mounted) return;
    final backupProv = context.read<BackupProvider>();

    try {
      switch (result) {
        case BackupChoice.config:
          final config = await backupProv.downloadConfigFromDrive();
          if (config != null && mounted) {
            final s = context.read<SettingsProvider>();
            final themeModeIndex = config['themeMode'] as int?;
            final primaryColor = config['primaryColor'] as int?;
            if (themeModeIndex != null) {
              s.setThemeMode(ThemeMode.values[themeModeIndex.clamp(
                  0, ThemeMode.values.length - 1)]);
            }
            if (primaryColor != null) {
              s.setPrimaryColor(Color(primaryColor));
            }
          }
        case BackupChoice.songs:
          final songs = await backupProv.restoreSongsFromDrive();
          if (mounted && songs.isNotEmpty) {
            final importProv = context.read<ImportProvider>();
            final downloadProv = context.read<DownloadProvider>();
            final lib = context.read<LibraryProvider>();
            importProv.startImport(
              names: songs.map((s) => s.title).toList(),
              artists: songs.map((s) => s.artist).toList(),
              searchQueries: songs.map((s) => '${s.artist} ${s.title}').toList(),
              existingLibrarySongs: lib.songs,
              downloadProvider: downloadProv,
              libraryProvider: lib,
            );
          }
        case BackupChoice.playlists:
          await backupProv.restorePlaylistsFromDrive();
          if (mounted) {
            context.read<LibraryProvider>().loadLibrary();
          }
        case BackupChoice.full:
          await backupProv.downloadFullRestore();
          if (mounted) {
            context.read<LibraryProvider>().loadLibrary();
          }
      }
      if (!mounted || _cancelled) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Restauración completada'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted || _cancelled) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Conecta tu cuenta de Google para respaldar\ntus datos automáticamente en la nube',
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 12),
          if (_backup.driveConnected) ...[
            Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 18),
                const SizedBox(width: 8),
                Text('Conectado', style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 14)),
                const Spacer(),
                TextButton(
                  onPressed: _onDisconnect,
                  child: const Text('Desconectar', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_backup.isExporting || _backup.isImporting) ...[
              if (_backup.fullProgress > 0 && _backup.fullProgress < 1) ...[
                LinearProgressIndicator(value: _backup.fullProgress),
                const SizedBox(height: 8),
                Text(_backup.fullStatus,
                    style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => context.read<BackupProvider>().cancelUpload(),
                    icon: const Icon(Icons.cancel, size: 18),
                    label: const Text('Cancelar'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ] else ...[
                const Center(child: CircularProgressIndicator()),
              ],
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _showBackupTypeDialog,
                      icon: const Icon(Icons.cloud_upload, size: 18),
                      label: const Text('Subir backup',
                          style: TextStyle(color: Colors.black)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _showRestoreTypeDialog,
                      icon: const Icon(Icons.cloud_download, size: 18),
                      label: const Text('Restaurar'),
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _showBackedUpSongs,
                  icon: const Icon(Icons.music_note, size: 18),
                  label: const Text('Canciones respaldadas'),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10)),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _onPurge,
                  icon: const Icon(Icons.delete_forever, size: 18),
                  label: const Text('Purgar todo'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ] else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _backup.isDriveConnecting ? null : _onConnect,
                icon: _backup.isDriveConnecting
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : const Icon(Icons.login, size: 18),
                label: Text(_backup.isDriveConnecting ? 'Conectando...' : 'Iniciar sesión con Google',
                    style: const TextStyle(color: Colors.black)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AutoBackupSection extends StatelessWidget {
  const _AutoBackupSection();

  @override
  Widget build(BuildContext context) {
    final backup = context.watch<BackupProvider>();
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Respaldo programado',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: theme.colorScheme.onSurface)),
                    const SizedBox(height: 4),
                    Text(
                      backup.autoBackupEnabled
                          ? '${backup.autoBackupType == 'light' ? 'Ligero' : 'Completo'} — ${backup.autoBackupHour.toString().padLeft(2, '0')}:${backup.autoBackupMinute.toString().padLeft(2, '0')} h'
                          : 'Programa un respaldo diario automático',
                      style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                    ),
                  ],
                ),
              ),
              Switch(
                value: backup.autoBackupEnabled,
                onChanged: (v) => _toggle(context, v),
              ),
            ],
          ),
          if (backup.autoBackupEnabled) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () => _showConfigDialog(context),
                icon: const Icon(Icons.edit, size: 16),
                label: const Text('Cambiar configuración'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _toggle(BuildContext context, bool value) async {
    final backup = context.read<BackupProvider>();
    if (!value) {
      await backup.saveAutoBackupSettings(
        enabled: false,
        type: backup.autoBackupType,
        hour: backup.autoBackupHour,
        minute: backup.autoBackupMinute,
      );
      return;
    }
    await _showConfigDialog(context);
  }

  Future<void> _showConfigDialog(BuildContext context) async {
    final backup = context.read<BackupProvider>();
    String type = backup.autoBackupType;
    TimeOfDay time = TimeOfDay(
      hour: backup.autoBackupHour,
      minute: backup.autoBackupMinute,
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: Theme.of(context).colorScheme.surface,
            title: const Text('Respaldo automático'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: type,
                  decoration: const InputDecoration(labelText: 'Tipo de respaldo'),
                  items: const [
                    DropdownMenuItem(value: 'light', child: Text('Ligero (config + canciones + listas)')),
                    DropdownMenuItem(value: 'full', child: Text('Completo (incluye archivos de audio)')),
                  ],
                  onChanged: (v) => setDialogState(() => type = v ?? 'light'),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.schedule),
                  title: const Text('Hora del día'),
                  subtitle: Text(time.format(context)),
                  onTap: () async {
                    final picked = await showTimePicker(context: context, initialTime: time);
                    if (picked != null) setDialogState(() => time = picked);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );

    if (result != true) return;

    await backup.saveAutoBackupSettings(
      enabled: true,
      type: type,
      hour: time.hour,
      minute: time.minute,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Respaldo automático configurado'),
        backgroundColor: Colors.green,
      ),
    );
  }
}

enum BackupChoice { config, songs, playlists, full }

class _BackupChoiceDialog extends StatelessWidget {
  final bool isUpload;
  const _BackupChoiceDialog({required this.isUpload});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      backgroundColor: theme.colorScheme.surface,
      title: Text(isUpload ? 'Subir backup' : 'Restaurar'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: isUpload
            ? [
                _ChoiceTile(
                  icon: Icons.cloud_upload,
                  title: 'Ligero',
                  subtitle: 'Configuración, canciones y listas (sin audio)',
                  onTap: () => Navigator.pop(context, 'light'),
                ),
                const Divider(height: 1),
                _ChoiceTile(
                  icon: Icons.backup,
                  title: 'Completo',
                  subtitle: 'Configuración, canciones, listas y archivos de audio',
                  onTap: () => Navigator.pop(context, 'full'),
                ),
              ]
            : [
                _ChoiceTile(
                  icon: Icons.settings,
                  title: 'Configuración',
                  subtitle: 'Tema y color de la aplicación',
                  onTap: () => Navigator.pop(context, BackupChoice.config),
                ),
                const Divider(height: 1),
                _ChoiceTile(
                  icon: Icons.music_note,
                  title: 'Canciones',
                  subtitle: 'Metadatos de canciones para importar',
                  onTap: () => Navigator.pop(context, BackupChoice.songs),
                ),
                const Divider(height: 1),
                _ChoiceTile(
                  icon: Icons.queue_music,
                  title: 'Listas de reproducción',
                  subtitle: 'Estructura de tus listas',
                  onTap: () => Navigator.pop(context, BackupChoice.playlists),
                ),
                const Divider(height: 1),
                _ChoiceTile(
                  icon: Icons.backup,
                  title: 'Completo',
                  subtitle: 'Configuración, canciones, listas y archivos de audio',
                  onTap: () => Navigator.pop(context, BackupChoice.full),
                ),
              ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _ChoiceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon, color: theme.colorScheme.primary),
      title: Text(title, style: TextStyle(color: theme.colorScheme.onSurface)),
      subtitle: Text(subtitle,
          style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
      onTap: onTap,
    );
  }
}

class _ColorPicker extends StatelessWidget {
  final SettingsProvider settings;
  const _ColorPicker({required this.settings});

  void _showCustomColorDialog(BuildContext context, SettingsProvider settings) {
    final theme = Theme.of(context);
    String hexText = '#${settings.primaryColor.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
    Color previewColor = settings.primaryColor;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: theme.colorScheme.surface,
            title: const Text('Color personalizado'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: previewColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Hex color',
                      hintText: '#FF5733',
                      border: OutlineInputBorder(),
                    ),
                    style: TextStyle(color: theme.colorScheme.onSurface),
                    controller: TextEditingController(text: hexText),
                    onChanged: (value) {
                      final cleaned = value.replaceAll('#', '');
                      if (cleaned.length == 6 || cleaned.length == 8) {
                        final intVal = int.tryParse(cleaned, radix: 16);
                        if (intVal != null) {
                          final color = cleaned.length == 6
                              ? Color(0xFF000000 | intVal)
                              : Color(intVal);
                          setDialogState(() {
                            hexText = '#${cleaned.toUpperCase()}';
                            previewColor = color;
                          });
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text('Colores rápidos:',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ...SettingsScreen.presetColors.map((c) => GestureDetector(
                        onTap: () => setDialogState(() {
                          previewColor = c;
                          hexText = '#${c.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
                        }),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                        ),
                      )),
                      ...([0xFF607D8B, 0xFF795548, 0xFF212121, 0xFF455A64].map((v) => GestureDetector(
                        onTap: () => setDialogState(() {
                          previewColor = Color(v);
                          hexText = '#${Color(v).toARGB32().toRadixString(16).substring(2).toUpperCase()}';
                        }),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Color(v),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ))),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () {
                  settings.setPrimaryColor(previewColor);
                  Navigator.pop(ctx);
                },
                child: const Text('Aplicar'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Color principal',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: theme.colorScheme.onSurface),
          ),
          const SizedBox(height: 4),
          Text(
            'Elige el color de acento de la aplicación',
            style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              ...SettingsScreen.presetColors.map((color) {
                final isSelected = settings.primaryColor.toARGB32() == color.toARGB32();
                return GestureDetector(
                  onTap: () => settings.setPrimaryColor(color),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(color: Colors.white, width: 3)
                          : null,
                      boxShadow: isSelected
                          ? [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 8)]
                          : null,
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 22)
                        : null,
                  ),
                );
              }),
              GestureDetector(
                onTap: () => _showCustomColorDialog(context, settings),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: Icon(Icons.add, color: theme.colorScheme.onSurface.withValues(alpha: 0.6), size: 24),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
