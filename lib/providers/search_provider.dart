import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/youtube_search_service.dart';

class SearchProvider extends ChangeNotifier {
  final YouTubeSearchService _searchService = YouTubeSearchService();
  final List<YouTubeSearchResult> _results = [];
  final List<String> _suggestions = [];
  final List<String> _searchHistory = [];
  bool _isLoading = false;
  final bool _hasMore = false;
  String _currentQuery = '';
  String? _error;
  bool _historyLoaded = false;

  List<YouTubeSearchResult> get results => List.unmodifiable(_results);
  List<String> get suggestions => List.unmodifiable(_suggestions);
  List<String> get searchHistory => List.unmodifiable(_searchHistory);
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;
  String get currentQuery => _currentQuery;
  String? get error => _error;

  Future<void> loadHistory() async {
    if (_historyLoaded) return;
    final prefs = await SharedPreferences.getInstance();
    _searchHistory.clear();
    _searchHistory.addAll(prefs.getStringList('search_history') ?? []);
    _historyLoaded = true;
    notifyListeners();
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('search_history', _searchHistory);
  }

  Future<void> search(String query) async {
    if (query.trim().isEmpty) {
      _results.clear();
      notifyListeners();
      return;
    }

    _currentQuery = query.trim();
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await _searchService.search(_currentQuery);
      _results.clear();
      _results.addAll(results);

      _searchHistory.remove(_currentQuery);
      _searchHistory.insert(0, _currentQuery);
      if (_searchHistory.length > 20) {
        _searchHistory.removeLast();
      }
      _saveHistory();
    } catch (e) {
      _error = e.toString();
      _results.clear();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> clearHistory() async {
    _searchHistory.clear();
    _saveHistory();
    notifyListeners();
  }

  Future<void> removeHistoryItem(String query) async {
    _searchHistory.remove(query);
    _saveHistory();
    notifyListeners();
  }

  Future<void> fetchSuggestions(String query) async {
    if (query.trim().length < 3) {
      _suggestions.clear();
      notifyListeners();
      return;
    }

    try {
      final suggestions = await _searchService.getSuggestions(query.trim());
      _suggestions.clear();
      _suggestions.addAll(suggestions);
    } catch (_) {
      _suggestions.clear();
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _searchService.dispose();
    super.dispose();
  }
}
