import 'package:flutter/material.dart';
import '../models/song.dart';
import '../theme/app_theme.dart';

class SongTile extends StatelessWidget {
  final Song song;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onDelete;
  final VoidCallback? onAddToPlaylist;
  final VoidCallback? onAddToQueue;
  final String? subtitleExtra;

  const SongTile({
    super.key,
    required this.song,
    this.onTap,
    this.onLongPress,
    this.onDelete,
    this.onAddToPlaylist,
    this.onAddToQueue,
    this.subtitleExtra,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Icon(Icons.music_note, color: AppTheme.textSecondary),
      ),
      title: Text(
        song.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            song.artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          if (subtitleExtra != null && subtitleExtra!.isNotEmpty)
            Text(
              subtitleExtra!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
            ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            song.formattedDuration,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppTheme.textSecondary, size: 20),
            onSelected: (value) {
              if (value == 'delete') onDelete?.call();
              if (value == 'add_playlist') onAddToPlaylist?.call();
              if (value == 'add_queue') onAddToQueue?.call();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, color: AppTheme.accentColor, size: 20),
                    SizedBox(width: 8),
                    Text('Eliminar'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'add_playlist',
                child: Row(
                  children: [
                    Icon(Icons.playlist_add, color: AppTheme.primaryColor, size: 20),
                    SizedBox(width: 8),
                    Text('Añadir a lista'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'add_queue',
                child: Row(
                  children: [
                    Icon(Icons.queue_music, color: AppTheme.primaryColor, size: 20),
                    SizedBox(width: 8),
                    Text('Añadir a la fila'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }
}
