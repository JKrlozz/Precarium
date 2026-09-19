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

  static final _accentMap = <String, String>{
    'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a', 'ā': 'a',
    'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', 'ē': 'e', 'ė': 'e', 'ę': 'e',
    'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i', 'ī': 'i',
    'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', 'ø': 'o', 'ō': 'o',
    'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u', 'ū': 'u',
    'ñ': 'n', 'ç': 'c', 'ć': 'c', 'č': 'c',
    'ý': 'y', 'ÿ': 'y', 'ğ': 'g', 'š': 's', 'ş': 's', 'ž': 'z',
    'æ': 'ae', 'œ': 'oe',
  };

  static String _removeAccents(String s) {
    return s.split('').map((c) => _accentMap[c] ?? c).join();
  }

  static String _stripMetadata(String s) {
    final result = s
        .replaceAll(RegExp(r'\(official\s*(music\s*)?(video|audio|lyric|lyrics)\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\[official\s*(music\s*)?(video|audio|lyric|lyrics)\]', caseSensitive: false), '')
        .replaceAll(RegExp(r'\(720p\)|\(1080p\)|\(4k\)|\(hd\)|\(ultra\s*hd\)|\(audio\)|\(visualizer\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*\([^)]*\)\s*$'), '')
        .replaceAll(RegExp(r'\s*\[[^\]]*\]\s*$'), '')
        .trim();
    return result;
  }

  static String _normalize(String s) {
    s = s.trim().toLowerCase();
    s = _removeAccents(s);
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
    if (artist.isEmpty) return [];
    var s = artist.toLowerCase().trim();
    s = s.replaceAll(RegExp(r'\s*(feat\.|featuring|ft\.|f\.)\s*'), ';');
    s = s.replaceAll(RegExp(r'\s*[,;&+]\s*'), ';');
    s = s.replaceAll(RegExp(r'\s+(and|y|vs\.?|x)\s+'), ';');
    return s.split(';').map((x) => _normalize(x)).where((x) => x.isNotEmpty).toList();
  }

  static final Set<String> _stopWords = {
    'the', 'and', 'for', 'you', 'are', 'not', 'but', 'all', 'can',
    'had', 'her', 'was', 'one', 'our', 'out', 'its', 'his', 'has',
    'she', 'get', 'got', 'did', 'say', 'let', 'see', 'way', 'may',
    'too', 'now', 'new', 'how', 'why', 'any', 'man', 'old', 'own',
  };

  static List<String> _words(String s) {
    return _removeAccents(s).toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 2 && !_stopWords.contains(w))
        .toList();
  }

  static bool _artistsMatch(List<String> a, List<String> b) {
    return a.any((na) => b.any((lb) =>
        lb.contains(na) || na.contains(lb)));
  }

  static bool _titlesMatchRelaxed(String rawA, String rawB) {
    final a = _normalize(rawA);
    final b = _normalize(rawB);
    if (a.isEmpty || b.isEmpty) return false;
    if (a == b) return true;

    final wa = _words(rawA);
    final wb = _words(rawB);
    if (wa.isEmpty || wb.isEmpty) return false;

    final shorter = wa.length <= wb.length ? wa : wb;
    final longer = wa.length <= wb.length ? wb : wa;

    if (shorter.length < 2) {
      return shorter.length == 1 && shorter[0].length >= 5 && longer.contains(shorter[0]);
    }

    return shorter.every((w) => longer.contains(w));
  }

  static bool _titlesMatchStrict(String rawA, String rawB) {
    final a = _normalize(rawA);
    final b = _normalize(rawB);
    if (a.isEmpty || b.isEmpty) return false;
    if (a == b) return true;

    if (b.contains(a) && a.length >= b.length * 0.8) return true;
    if (a.contains(b) && b.length >= a.length * 0.8) return true;

    final wa = _words(rawA);
    final wb = _words(rawB);
    if (wa.length < 2 || wb.length < 2) return false;

    final shorter = wa.length <= wb.length ? wa : wb;
    final longer = wa.length <= wb.length ? wb : wa;

    final common = shorter.where((w) => longer.contains(w)).toList();
    if (common.length < 2) return false;
    if (!common.any((w) => w.length >= 4)) return false;

    return common.length >= shorter.length * 0.65;
  }

  static bool matchesExisting(String importName, String importArtist, List<Song> librarySongs) {
    try {
      final needleArtists = _artistParts(importArtist);
      final needleName = _normalize(importName);
      if (needleName.isEmpty) return false;

      return librarySongs.any((s) {
        try {
          if (s.title.isEmpty) return false;
          final ln = _normalize(s.title);
          if (ln.isEmpty) return false;
          if (ln == needleName) return true;

          final libArtists = s.artist.isNotEmpty
              ? _artistParts(s.artist)
              : <String>[];
          final hasBothArtists =
              needleArtists.isNotEmpty && libArtists.isNotEmpty;

          if (hasBothArtists && _artistsMatch(needleArtists, libArtists)) {
            return _titlesMatchRelaxed(importName, s.title);
          }

          return _titlesMatchStrict(importName, s.title);
        } catch (_) {
          return false;
        }
      });
    } catch (_) {
      return false;
    }
  }

  static Set<int> batchFindExisting(List<String> importNames, List<String> importArtists, List<Song> librarySongs) {
    if (importNames.isEmpty || librarySongs.isEmpty) return {};

    final libNorms = librarySongs.map((s) {
      try {
        final t = _normalize(s.title);
        return (
          title: t,
          rawTitle: s.title,
          artists: s.artist.isNotEmpty ? _artistParts(s.artist) : <String>[],
          words: t.isNotEmpty ? _words(s.title) : <String>[],
        );
      } catch (_) {
        return (title: '', rawTitle: s.title, artists: <String>[], words: <String>[]);
      }
    }).toList();

    final importNorms = List.generate(importNames.length, (i) {
      try {
        final t = _normalize(importNames[i]);
        return (
          name: t,
          rawName: importNames[i],
          artists: _artistParts(importArtists[i]),
          words: t.isNotEmpty ? _words(importNames[i]) : <String>[],
        );
      } catch (_) {
        return (name: '', rawName: importNames[i], artists: <String>[], words: <String>[]);
      }
    });

    final existing = <int>{};
    for (int i = 0; i < importNorms.length; i++) {
      final imp = importNorms[i];
      if (imp.name.isEmpty) continue;

      for (final lib in libNorms) {
        if (lib.title.isEmpty) continue;

        if (lib.title == imp.name) { existing.add(i); break; }

        final hasBothArtists = imp.artists.isNotEmpty && lib.artists.isNotEmpty;
        bool match = false;

        if (hasBothArtists && _artistsMatch(imp.artists, lib.artists)) {
          match = _relaxedPre(imp.name, imp.words, imp.rawName, lib.title, lib.words, lib.rawTitle);
        } else {
          match = _strictPre(imp.name, imp.words, imp.rawName, lib.title, lib.words, lib.rawTitle);
        }

        if (match) { existing.add(i); break; }
      }
    }
    return existing;
  }

  static bool _relaxedPre(String normA, List<String> wordsA, String rawA,
      String normB, List<String> wordsB, String rawB) {
    if (normA == normB) return true;

    if (wordsA.length < 2) {
      return wordsA.length == 1 && wordsA[0].length >= 5 && wordsB.contains(wordsA[0]);
    }

    final shorter = wordsA.length <= wordsB.length ? wordsA : wordsB;
    final longer = wordsA.length <= wordsB.length ? wordsB : wordsA;
    return shorter.every((w) => longer.contains(w));
  }

  static bool _strictPre(String normA, List<String> wordsA, String rawA,
      String normB, List<String> wordsB, String rawB) {
    if (normA == normB) return true;

    if (normB.contains(normA) && normA.length >= normB.length * 0.8) return true;
    if (normA.contains(normB) && normB.length >= normA.length * 0.8) return true;

    if (wordsA.length < 2 || wordsB.length < 2) return false;

    final shorter = wordsA.length <= wordsB.length ? wordsA : wordsB;
    final longer = wordsA.length <= wordsB.length ? wordsB : wordsA;

    final common = shorter.where((w) => longer.contains(w)).toList();
    if (common.length < 2) return false;
    if (!common.any((w) => w.length >= 4)) return false;

    return common.length >= shorter.length * 0.65;
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
          final String officialQuery = '${names[i]} Audio Oficial';
          final String officialQueryEn = '${names[i]} Official Audio';
          List<YouTubeSearchResult> searchResults;

          searchResults = await _ytSearch.search(officialQuery);
          if (searchResults.isEmpty) {
            searchResults = await _ytSearch.search(officialQueryEn);
          }
          if (searchResults.isEmpty) {
            searchResults = await _ytSearch.search(searchQueries[i]);
          }

          if (searchResults.isNotEmpty) {
            final first = searchResults.first;
            downloadProvider.addDownload(
              first.id,
              names[i],
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
      downloadProvider.cancelAllPending();
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
