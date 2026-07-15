import 'package:flutter_test/flutter_test.dart';
import 'package:precarium/models/download_task.dart';

void main() {
  group('DownloadTask model', () {
    test('creates a download task with pending status', () {
      final task = DownloadTask(
        id: '1',
        title: 'Test Video',
        videoId: 'abc123',
      );

      expect(task.id, '1');
      expect(task.title, 'Test Video');
      expect(task.videoId, 'abc123');
      expect(task.status, DownloadStatus.pending);
      expect(task.progress, 0.0);
    });

    test('copyWith updates fields', () {
      final task = DownloadTask(id: '1', title: 'Test', videoId: 'abc');
      final updated = task.copyWith(
        status: DownloadStatus.downloading,
        progress: 0.5,
      );

      expect(updated.status, DownloadStatus.downloading);
      expect(updated.progress, 0.5);
      expect(updated.id, '1');
    });

    test('durationFormatted shows percentage', () {
      final task = DownloadTask(
        id: '1',
        title: 'Test',
        videoId: 'abc',
        progress: 0.75,
      );

      expect(task.durationFormatted, '75%');
    });
  });
}
