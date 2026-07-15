import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/youtube_search_service.dart';
import '../theme/app_theme.dart';

class SearchResultTile extends StatelessWidget {
  final YouTubeSearchResult video;
  final VoidCallback? onTap;
  final VoidCallback? onDownload;

  const SearchResultTile({
    super.key,
    required this.video,
    this.onTap,
    this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: CachedNetworkImage(
          imageUrl: video.thumbnailUrl ?? '',
          width: 64,
          height: 48,
          fit: BoxFit.cover,
          placeholder: (_, _) => Container(
            color: AppTheme.cardColor,
            child: const Icon(Icons.music_video, size: 24),
          ),
          errorWidget: (_, _, _) => Container(
            color: AppTheme.cardColor,
            child: const Icon(Icons.music_video, size: 24),
          ),
        ),
      ),
      title: Text(
        video.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      subtitle: Row(
        children: [
          Expanded(
            child: Text(
              video.channel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ),
          if (video.formattedDuration.isNotEmpty) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                video.formattedDuration,
                style: const TextStyle(fontSize: 11, color: Colors.white),
              ),
            ),
          ],
        ],
      ),
      trailing: IconButton(
        icon: const Icon(Icons.download_rounded, color: AppTheme.textSecondary),
        onPressed: onDownload,
        tooltip: 'Descargar',
      ),
      onTap: onTap,
    );
  }
}
