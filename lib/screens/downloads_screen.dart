import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/download_provider.dart';
import '../providers/import_provider.dart';
import '../widgets/download_tile.dart';
import '../theme/app_theme.dart';

class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 120,
        leading: Consumer2<DownloadProvider, ImportProvider>(
          builder: (context, provider, import, _) {
            final hasActive = provider.pendingTasks.isNotEmpty ||
                provider.downloadingTasks.isNotEmpty;
            if (!hasActive) return const SizedBox.shrink();
            return TextButton(
              onPressed: () {
                import.cancelImport();
                for (final task in provider.activeTasks) {
                  provider.cancelTask(task.id);
                }
              },
              child: const Text('Cancelar todo'),
            );
          },
        ),
        title: const Text('Descargas'),
        centerTitle: true,
        actions: [
          SizedBox(
            width: 120,
            child: Consumer<DownloadProvider>(
              builder: (context, provider, _) {
                if (provider.failedTasks.isEmpty) return const SizedBox.shrink();
                return Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      for (final task in provider.failedTasks) {
                        provider.retryTask(task.id);
                      }
                    },
                    child: const Text('Reintentar todo'),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      body: Consumer<DownloadProvider>(
        builder: (context, downloadProvider, _) {
          if (downloadProvider.tasks.isEmpty) {
            return _buildEmptyState();
          }
          return _buildDownloadList(downloadProvider);
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.download_outlined, size: 80,
              color: AppTheme.textSecondary.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          const Text(
            'Sin descargas',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Busca canciones en YouTube y\ndescárgalas para escucharlas sin conexión',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadList(DownloadProvider provider) {
    final pendingTasks = provider.pendingTasks;
    final downloadingTasks = provider.downloadingTasks;
    final completedTasks = provider.completedTasks;
    final failedTasks = provider.failedTasks;

    return ListView(
      padding: const EdgeInsets.only(bottom: 80),
      children: [
        if (downloadingTasks.isNotEmpty || pendingTasks.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'En cola (${provider.activeCount})',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          if (downloadingTasks.isNotEmpty)
                          ...downloadingTasks.map((task) => DownloadTile(task: task)),
          if (pendingTasks.isNotEmpty)
            ...pendingTasks.map((task) => DownloadTile(task: task)),
          const Divider(height: 24, color: AppTheme.dividerColor),
        ],
        if (failedTasks.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Fallidas',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.accentColor),
            ),
          ),
          ...failedTasks.map((task) => DownloadTile(task: task)),
          const Divider(height: 24, color: AppTheme.dividerColor),
        ],
        if (completedTasks.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Completadas (${completedTasks.length})',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
            ),
          ),
          ...completedTasks.map((task) => DownloadTile(task: task)),
        ],
      ],
    );
  }
}
