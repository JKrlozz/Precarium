import 'package:flutter/material.dart' hide RepeatMode;
import 'package:provider/provider.dart';
import '../providers/library_provider.dart';
import '../providers/player_provider.dart';
import '../services/audio_player_service.dart';
import '../theme/app_theme.dart';

class FullPlayerScreen extends StatelessWidget {
  const FullPlayerScreen({super.key});

  void _showQueue(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Consumer<PlayerProvider>(
        builder: (context, player, _) {
          final queue = player.queue;
          final currentIndex = player.currentIndex;
          return DraggableScrollableSheet(
            initialChildSize: 0.6,
            maxChildSize: 0.85,
            minChildSize: 0.3,
            expand: false,
            builder: (_, scrollController) => Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.queue_music, color: AppTheme.primaryColor),
                      const SizedBox(width: 8),
                      Text(
                        'Fila de reproducción (${queue.length})',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.delete_sweep, color: AppTheme.textSecondary),
                        onPressed: () {
                          player.clearQueue();
                          Navigator.pop(ctx);
                        },
                        tooltip: 'Limpiar fila',
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: AppTheme.dividerColor),
                Expanded(
                  child: queue.isEmpty
                      ? const Center(
                          child: Text('Fila vacía',
                              style: TextStyle(color: AppTheme.textSecondary)),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: queue.length,
                          itemBuilder: (_, index) {
                            final song = queue[index];
                            final isCurrent = index == currentIndex;
                            return ListTile(
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: isCurrent
                                      ? AppTheme.primaryColor
                                      : AppTheme.cardColor,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Icon(
                                  Icons.music_note,
                                  size: 20,
                                  color: isCurrent ? Colors.black : AppTheme.textSecondary,
                                ),
                              ),
                              title: Text(
                                song.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight:
                                      isCurrent ? FontWeight.bold : FontWeight.normal,
                                  color: isCurrent
                                      ? AppTheme.primaryColor
                                      : AppTheme.textPrimary,
                                ),
                              ),
                              subtitle: Text(
                                song.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 12, color: AppTheme.textSecondary),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    song.formattedDuration,
                                    style: const TextStyle(
                                        color: AppTheme.textSecondary, fontSize: 12),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close,
                                        size: 18, color: AppTheme.textSecondary),
                                    onPressed: () => player.removeFromQueue(index),
                                  ),
                                ],
                              ),
                              onTap: () {
                                player.audioService.seekToIndex(index);
                                Navigator.pop(ctx);
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<PlayerProvider, LibraryProvider>(
      builder: (context, player, library, _) {
        final song = player.currentSong;
        if (song == null) {
          return const Scaffold(body: Center(child: Text('No hay canción seleccionada')));
        }

        final isLiked = library.isLiked(song.id);

        return Scaffold(
          backgroundColor: AppTheme.backgroundColor,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.keyboard_arrow_down),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text(
              'REPRODUCIENDO',
              style: TextStyle(fontSize: 12, letterSpacing: 2, color: AppTheme.textSecondary),
            ),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.queue_music),
                onPressed: () => _showQueue(context),
                tooltip: 'Fila de reproducción',
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const Spacer(flex: 1),
                Container(
                  width: double.infinity,
                  height: MediaQuery.of(context).size.width - 80,
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(Icons.music_note, size: 80, color: AppTheme.textSecondary),
                  ),
                ),
                const Spacer(flex: 1),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            song.title,
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            song.artist,
                            style: const TextStyle(fontSize: 16, color: AppTheme.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        isLiked ? Icons.favorite : Icons.favorite_border,
                      ),
                      onPressed: () => library.toggleLike(song),
                      color: isLiked ? Colors.redAccent : AppTheme.textSecondary,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      _formatDuration(player.position),
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                    Expanded(
                      child: Slider(
                        value: player.progress.clamp(0.0, 1.0),
                        onChanged: (value) => player.seek(
                          Duration(milliseconds: (value * player.duration.inMilliseconds).round()),
                        ),
                      ),
                    ),
                    Text(
                      _formatDuration(player.duration),
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.shuffle,
                        color: player.isShuffled ? AppTheme.primaryColor : Colors.white,
                      ),
                      iconSize: 28,
                      onPressed: () => player.toggleShuffle(),
                    ),
                    IconButton(
                      icon: const Icon(Icons.skip_previous_rounded),
                      iconSize: 36,
                      onPressed: () => player.previous(),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(
                          player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          color: Colors.black,
                          size: 36,
                        ),
                        onPressed: () => player.togglePlayPause(),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.skip_next_rounded),
                      iconSize: 36,
                      onPressed: () => player.next(),
                    ),
                    IconButton(
                      icon: Icon(
                        player.repeatMode == PlayerRepeatMode.one
                            ? Icons.repeat_one
                            : Icons.repeat,
                        color: player.repeatMode != PlayerRepeatMode.off ? AppTheme.primaryColor : Colors.white,
                      ),
                      iconSize: 28,
                      onPressed: () => player.cycleRepeatMode(),
                    ),
                  ],
                ),
                const Spacer(flex: 2),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
