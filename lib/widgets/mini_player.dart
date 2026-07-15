import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../screens/full_player_screen.dart';
import '../theme/app_theme.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (context, player, _) {
        if (player.currentSong == null) {
          return const SizedBox.shrink();
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ProgressSlider(player: player),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FullPlayerScreen()),
                );
              },
              child: Container(
                height: 64,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  border: const Border(top: BorderSide(color: AppTheme.dividerColor)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      margin: const EdgeInsets.only(left: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.cardColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: player.currentSong!.albumArtPath != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.file(
                                File(player.currentSong!.albumArtPath!),
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => const Icon(Icons.music_note),
                              ),
                            )
                          : const Icon(Icons.music_note),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            player.currentSong!.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            player.currentSong!.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            color: Colors.white,
                          ),
                          onPressed: () => player.togglePlayPause(),
                        ),
                        IconButton(
                          icon: const Icon(Icons.skip_next_rounded, color: Colors.white),
                          onPressed: () => player.next(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ProgressSlider extends StatelessWidget {
  final PlayerProvider player;

  const _ProgressSlider({required this.player});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 24,
      child: SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: 3,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
          activeTrackColor: AppTheme.primaryColor,
          inactiveTrackColor: AppTheme.dividerColor,
          thumbColor: AppTheme.primaryColor,
        ),
        child: Slider(
          value: player.progress.clamp(0.0, 1.0),
          onChanged: (value) => player.seek(
            Duration(milliseconds: (value * player.duration.inMilliseconds).round()),
          ),
        ),
      ),
    );
  }
}
