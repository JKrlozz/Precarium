import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/download_task.dart';
import '../providers/download_provider.dart';
import '../theme/app_theme.dart';

class DownloadTile extends StatelessWidget {
  final DownloadTask task;

  const DownloadTile({super.key, required this.task});

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
        child: _buildLeadingIcon(),
      ),
      title: Text(
        task.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      subtitle: _buildSubtitle(),
      trailing: _buildTrailing(context),
    );
  }

  Widget _buildLeadingIcon() {
    switch (task.status) {
      case DownloadStatus.completed:
        return Icon(Icons.check_circle, color: AppTheme.primaryColor);
      case DownloadStatus.failed:
        return const Icon(Icons.error, color: AppTheme.accentColor);
      case DownloadStatus.cancelled:
        return const Icon(Icons.cancel, color: AppTheme.textSecondary);
      default:
        return const Icon(Icons.download, color: Colors.blue);
    }
  }

  Widget _buildSubtitle() {
    switch (task.status) {
      case DownloadStatus.pending:
        return const Text('Esperando...', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12));
      case DownloadStatus.downloading:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${(task.progress * 100).toStringAsFixed(1)}%',
              style: const TextStyle(color: Colors.blue, fontSize: 12),
            ),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: task.progress,
              backgroundColor: AppTheme.dividerColor,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
          ],
        );
      case DownloadStatus.completed:
        return Text(
          task.filePath?.split('/').last ?? 'Completado',
          style: TextStyle(color: AppTheme.primaryColor, fontSize: 12),
        );
      case DownloadStatus.failed:
        return Text(
          task.errorMessage ?? 'Error',
          style: const TextStyle(color: AppTheme.accentColor, fontSize: 12),
        );
      case DownloadStatus.cancelled:
        return const Text('Cancelado', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12));
    }
  }

  Widget? _buildTrailing(BuildContext context) {
    switch (task.status) {
      case DownloadStatus.downloading:
      case DownloadStatus.pending:
        return IconButton(
          icon: const Icon(Icons.cancel, color: AppTheme.accentColor),
          onPressed: () => context.read<DownloadProvider>().cancelTask(task.id),
        );
      case DownloadStatus.failed:
        return IconButton(
          icon: const Icon(Icons.refresh, color: Colors.blue),
          onPressed: () => context.read<DownloadProvider>().retryTask(task.id),
        );
      case DownloadStatus.completed:
        return IconButton(
          icon: const Icon(Icons.delete_outline, color: AppTheme.textSecondary),
          onPressed: () => context.read<DownloadProvider>().removeTask(task.id),
        );
      default:
        return null;
    }
  }
}
