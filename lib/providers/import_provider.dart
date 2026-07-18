import 'package:flutter/foundation.dart';
import '../models/song.dart';
import '../services/youtube_search_service.dart';
import 'download_provider.dart';
import 'library_provider.dart';

class ImportProvider extends ChangeNotifier {
  final YouTubeSearchService _ytSearch = YouTubeSearchService();

  bool _isImporting = false;
  bool get isImporting => _isImporting;
  bool _cancelled = false;

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

  void cancelImport() {
    _cancelled = true;
    _isImporting = false;
    notifyListeners();
  }

  static String _normalize(String s) {
    return s.trim().toLowerCase().replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
  }

  bool _matchesExisting(String importName, String importArtist, List<Song> librarySongs) {
    final needleName = _normalize(importName);
    final needleArtist = _normalize(importArtist);
    if (needleName.isEmpty) return false;

    return librarySongs.any((s) {
      final libName = _normalize(s.title);
      final libArtist = _normalize(s.artist);

      if (needleArtist.isNotEmpty && libArtist.isNotEmpty) {
        if (libName.contains(needleName) || needleName.contains(libName)) {
          if (libArtist.contains(needleArtist) || needleArtist.contains(libArtist)) {
            return true;
          }
        }
      }

      return libName.contains(needleName) || needleName.contains(libName);
    });
  }

  Future<void> startImport({
    required List<String> names,
    required List<String> artists,
    required List<String> searchQueries,
    required List<Song> existingLibrarySongs,
    required DownloadProvider downloadProvider,
    required LibraryProvider libraryProvider,
  }) async {
    if (_isImporting) return;
    _cancelled = false;
    _isImporting = true;
    _downloaded = 0;
    _failed = 0;
    _skipped = 0;
    _total = names.length;
    _statusText = 'Iniciando importacion...';
    notifyListeners();

    for (int i = 0; i < names.length; i++) {
      if (_cancelled) break;
      _statusText = '(${i + 1}/$_total) Buscando ${names[i]}...';
      notifyListeners();

      if (_matchesExisting(names[i], artists[i], existingLibrarySongs)) {
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

      if (_cancelled) break;
      await Future.delayed(const Duration(milliseconds: 2000));
    }

    if (_cancelled) {
      _isImporting = false;
      notifyListeners();
      return;
    }

    _isImporting = false;
    _statusText = '';
    notifyListeners();
    libraryProvider.loadLibrary();
  }

  void reset() {
    _cancelled = false;
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
