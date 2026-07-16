import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/backup_provider.dart';
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
              _SectionHeader(title: 'Copia de seguridad'),
              const SizedBox(height: 8),
              _BackupSection(backup: backup),
              const SizedBox(height: 24),
              _SectionHeader(title: 'Google Drive'),
              const SizedBox(height: 8),
              _DriveSection(backup: backup),
              const SizedBox(height: 24),
              _SectionHeader(title: 'Acerca de'),
              const SizedBox(height: 8),
              _InfoTile(label: 'Versión', value: '1.0.0'),
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

class _BackupSection extends StatelessWidget {
  final BackupProvider backup;
  const _BackupSection({required this.backup});

  Future<void> _onExport(BuildContext context) async {
    try {
      final library = context.read<LibraryProvider>();
      final settings = context.read<SettingsProvider>();
      final backupProv = context.read<BackupProvider>();
      final playlists = await DatabaseService.getPlaylistRows();
      final playlistSongs = await DatabaseService.getAllPlaylistSongRows();

      await backupProv.exportBackup(
            songs: library.songs,
            playlists: playlists,
            playlistSongs: playlistSongs,
            themeMode: settings.themeMode.index,
            primaryColor: settings.primaryColor.toARGB32(),
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Copia de seguridad creada correctamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _onImport(BuildContext context) async {
    try {
      await context.read<BackupProvider>().importBackup(
            onRestore: (songs, playlists, playlistSongs, settings) {
              if (!context.mounted) return;
              if (settings != null) {
                final s = context.read<SettingsProvider>();
                final themeModeIndex = settings['themeMode'] as int?;
                final primaryColor = settings['primaryColor'] as int?;
                if (themeModeIndex != null) {
                  s.setThemeMode(ThemeMode.values[themeModeIndex.clamp(
                      0, ThemeMode.values.length - 1)]);
                }
                if (primaryColor != null) {
                  s.setPrimaryColor(Color(primaryColor));
                }
              }
              context.read<LibraryProvider>().loadLibrary();
            },
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Restauración completada'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lastBackup = backup.lastBackupDate;
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
            'Respalda o restaura tus datos',
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          if (lastBackup != null) ...[
            const SizedBox(height: 4),
            Text(
              'Última copia: ${lastBackup.day.toString().padLeft(2, '0')}/${lastBackup.month.toString().padLeft(2, '0')}/${lastBackup.year}',
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: backup.isExporting ? null : () => _onExport(context),
                  icon: backup.isExporting
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : const Icon(Icons.upload, size: 18),
                  label: Text(backup.isExporting ? 'Exportando...' : 'Exportar',
                      style: const TextStyle(color: Colors.black)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: backup.isImporting ? null : () => _onImport(context),
                  icon: backup.isImporting
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download, size: 18),
                  label: Text(backup.isImporting ? 'Restaurando...' : 'Restaurar'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DriveSection extends StatelessWidget {
  final BackupProvider backup;
  const _DriveSection({required this.backup});

  Future<void> _onConnect(BuildContext context) async {
    try {
      await context.read<BackupProvider>().connectToDrive();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Conectado a Google Drive'),
            backgroundColor: Colors.green,
          ),
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

  Future<void> _onDisconnect(BuildContext context) async {
    await context.read<BackupProvider>().disconnectFromDrive();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Desconectado de Google Drive')),
      );
    }
  }

  Future<void> _onExportDrive(BuildContext context) async {
    try {
      final library = context.read<LibraryProvider>();
      final settings = context.read<SettingsProvider>();
      final backupProv = context.read<BackupProvider>();
      final playlists = await DatabaseService.getPlaylistRows();
      final playlistSongs = await DatabaseService.getAllPlaylistSongRows();

      await backupProv.exportToDrive(
        songs: library.songs,
        playlists: playlists,
        playlistSongs: playlistSongs,
        themeMode: settings.themeMode.index,
        primaryColor: settings.primaryColor.toARGB32(),
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Copia de seguridad subida a Drive'),
            backgroundColor: Colors.green,
          ),
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

  Future<void> _onImportDrive(BuildContext context) async {
    try {
      final backupProv = context.read<BackupProvider>();
      final message = await backupProv.importFromDrive(
        onRestore: (songs, playlists, playlistSongs, settings) {
          if (!context.mounted) return;
          if (settings != null) {
            final s = context.read<SettingsProvider>();
            final themeModeIndex = settings['themeMode'] as int?;
            final primaryColor = settings['primaryColor'] as int?;
            if (themeModeIndex != null) {
              s.setThemeMode(ThemeMode.values[themeModeIndex.clamp(
                  0, ThemeMode.values.length - 1)]);
            }
            if (primaryColor != null) {
              s.setPrimaryColor(Color(primaryColor));
            }
          }
          context.read<LibraryProvider>().loadLibrary();
        },
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.green),
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
          if (backup.driveConnected) ...[
            Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 18),
                const SizedBox(width: 8),
                Text('Conectado', style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 14)),
                const Spacer(),
                TextButton(
                  onPressed: () => _onDisconnect(context),
                  child: const Text('Desconectar', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: backup.isExporting ? null : () => _onExportDrive(context),
                    icon: backup.isExporting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                        : const Icon(Icons.cloud_upload, size: 18),
                    label: Text(backup.isExporting ? 'Subiendo...' : 'Subir backup',
                        style: const TextStyle(color: Colors.black)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: backup.isImporting ? null : () => _onImportDrive(context),
                    icon: backup.isImporting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.cloud_download, size: 18),
                    label: Text(backup.isImporting ? 'Descargando...' : 'Restaurar'),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                  ),
                ),
              ],
            ),
          ] else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: backup.isDriveConnecting ? null : () => _onConnect(context),
                icon: backup.isDriveConnecting
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : const Icon(Icons.login, size: 18),
                label: Text(backup.isDriveConnecting ? 'Conectando...' : 'Iniciar sesión con Google',
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
