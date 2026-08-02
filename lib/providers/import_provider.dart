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

  static String _stripMetadata(String s) {
    return s
        .replaceAll(RegExp(r'\(official\s*(music\s*)?(video|audio|lyric|lyrics)\)', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\[official\s*(music\s*)?(video|audio|lyric|lyrics)\]', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\(?\d{3,4}p?\)?', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\(hd\)|\(4k\)|\(ultra\s*hd\)|\(audio\)|\(visualizer\)', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String _normalize(String s) {
    s = s.trim().toLowerCase();
    s = _stripMetadata(s);
    s = s.replaceAll('\u2013', '-').replaceAll('\u2014', '-');
    s = s.replaceAll('\u2018', "'").replaceAll('\u2019', "'");
    s = s.replaceAll('\u201C', '"').replaceAll('\u201D', '"');
    s = s.replaceAll('\u00A0', ' ').replaceAll('\u200B', '');
    s = s.replaceAll(RegExp(r'[<>:"/\\|?*#%&{}\[\]^~!@$+=`]'), '_');
    s = s.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
    s = s.replaceAll(RegExp(r'_+'), '_');
    s = s.trim().replaceAll(RegExp(r'[. ]+$'), '');
    return s;
  }

  static List<String> _artistParts(String artist) {
    var s = artist.toLowerCase().trim();
    s = s.replaceAll(RegExp(r'\s*(feat\.|featuring|ft\.|f\.)\s*'), ';');
    s = s.replaceAll(RegExp(r'\s*[,;&+]\s*'), ';');
    s = s.replaceAll(RegExp(r'\s+(and|y|vs\.?|x)\s+'), ';');
    return s.split(';').map((x) => _normalize(x)).where((x) => x.isNotEmpty).toList();
  }

  static bool matchesExisting(String importName, String importArtist, List<Song> librarySongs) {
    final needleName = _normalize(importName);
    final needleArtists = _artistParts(importArtist);
    if (needleName.isEmpty) return false;

    return librarySongs.any((s) {
      final libName = _normalize(s.title);

      if (needleArtists.isNotEmpty) {
        final libArtists = _artistParts(s.artist);
        if (libArtists.isNotEmpty) {
          if (libName.contains(needleName) || needleName.contains(libName)) {
            if (needleArtists.any((na) => libArtists.any((la) => la.contains(na) || na.contains(la)))) {
              return true;
            }
          }
        }
      }

      return libName.contains(needleName) || needleName.contains(libName);
    });
  }

  bool _matchesExisting(String importName, String importArtist, List<Song> librarySongs) {
    return matchesExisting(importName, importArtist, librarySongs);
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
