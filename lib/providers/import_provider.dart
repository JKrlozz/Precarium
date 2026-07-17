import 'package:flutter/foundation.dart';
import '../models/song.dart';
import '../services/youtube_search_service.dart';
import 'download_provider.dart';
import 'library_provider.dart';

class ImportProvider extends ChangeNotifier {
  final YouTubeSearchService _ytSearch = YouTubeSearchService();

  bool _isImporting = false;
  bool get isImporting => _isImporting;

  int _downloaded = 0;
  int get downloaded => _downloaded;
  int _failed = 0;
  int get failed => _failed;
  int _skipped = 0;
  int get skipped => _skipped;
  int _total = 0;
  int get total => _total;
  String _statusText = '';
  String get statusText => _statusText;

  double get progress =>
      _total > 0 ? (_downloaded + _failed + _skipped) / _total : 0;

  Future<void> startImport({
    required List<String> names,
    required List<String> artists,
    required List<String> searchQueries,
    required List<Song> existingLibrarySongs,
    required DownloadProvider downloadProvider,
    required LibraryProvider libraryProvider,
  }) async {
    _isImporting = true;
    _downloaded = 0;
    _failed = 0;
    _skipped = 0;
    _total = names.length;
    _statusText = 'Iniciando importación...';
    notifyListeners();

    for (int i = 0; i < names.length; i++) {
      _statusText = '(${i + 1}/$_total) Buscando ${names[i]}...';
      notifyListeners();

      if (_matchesExisting(names[i], existingLibrarySongs)) {
        _skipped++;
        notifyListeners();
        continue;
      }

      try {
        final searchResults = await _ytSearch.search(searchQueries[i]);
        if (searchResults.isNotEmpty) {
          final first = searchResults.first;
          downloadProvider.addDownload(
            first.id,
            first.title,
            artist: artists[i],
            thumbnailUrl: first.thumbnailUrl,
          );
          _downloaded++;
        } else {
          _failed++;
        }
      } catch (_) {
        _failed++;
      }
      notifyListeners();

      await Future.delayed(const Duration(milliseconds: 2000));
    }

    _isImporting = false;
    _statusText = '';
    notifyListeners();
    libraryProvider.loadLibrary();
  }

  bool _matchesExisting(String importName, List<Song> librarySongs) {
    String normalize(String s) {
      return s.trim().toLowerCase().replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
    }
    final needle = normalize(importName);
    if (needle.isEmpty) return false;
    return librarySongs.any((s) {
      final title = normalize(s.title);
      return title.contains(needle) || needle.contains(title);
    });
  }

  void reset() {
    _isImporting = false;
    _downloaded = 0;
    _failed = 0;
    _skipped = 0;
    _total = 0;
    _statusText = '';
    notifyListeners();
  }

  @override
  void dispose() {
    _ytSearch.dispose();
    super.dispose();
  }
}
