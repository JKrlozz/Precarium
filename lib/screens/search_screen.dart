import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/search_provider.dart';
import '../providers/download_provider.dart';
import '../widgets/search_result_tile.dart';
import '../theme/app_theme.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    context.read<SearchProvider>().loadHistory();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) setState(() {});
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearch(String query) {
    if (query.trim().isNotEmpty) {
      _showSuggestions = false;
      _focusNode.unfocus();
      context.read<SearchProvider>().search(query.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          focusNode: _focusNode,
          autofocus: false,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: InputDecoration(
            hintText: 'Buscar en YouTube...',
            hintStyle: const TextStyle(color: AppTheme.textSecondary),
            border: InputBorder.none,
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      _showSuggestions = false;
                      _focusNode.requestFocus();
                      context.read<SearchProvider>().search('');
                    },
                  )
                : null,
          ),
          onSubmitted: _onSearch,
          onChanged: (value) {
            setState(() {});
            if (value.length >= 3) {
              _showSuggestions = true;
              context.read<SearchProvider>().fetchSuggestions(value);
            } else {
              _showSuggestions = false;
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _onSearch(_searchController.text),
          ),
        ],
      ),
      body: Consumer<SearchProvider>(
        builder: (context, searchProvider, _) {
          if (searchProvider.isLoading && searchProvider.results.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (searchProvider.error != null) {
            return _buildError(searchProvider);
          }

          if (_showSuggestions && searchProvider.suggestions.isNotEmpty) {
            return _buildSuggestions(searchProvider);
          }

          if (searchProvider.results.isEmpty &&
              _searchController.text.trim().isEmpty) {
            return _buildHistory(searchProvider);
          }

          if (searchProvider.results.isEmpty) {
            return _buildEmptySearch();
          }

          return _buildResults(searchProvider);
        },
      ),
    );
  }

  Widget _buildError(SearchProvider searchProvider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off, size: 64, color: AppTheme.accentColor),
          const SizedBox(height: 16),
          const Text(
            'Error de conexión',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              searchProvider.error ?? 'No se pudo conectar con YouTube',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => searchProvider.search(searchProvider.currentQuery),
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestions(SearchProvider searchProvider) {
    return ListView.builder(
      itemCount: searchProvider.suggestions.length,
      itemBuilder: (context, index) {
        final suggestion = searchProvider.suggestions[index];
        return ListTile(
          leading: const Icon(Icons.search, color: AppTheme.textSecondary),
          title: Text(suggestion),
          onTap: () {
            _searchController.text = suggestion;
            _showSuggestions = false;
            searchProvider.search(suggestion);
          },
        );
      },
    );
  }

  Widget _buildHistory(SearchProvider searchProvider) {
    if (searchProvider.searchHistory.isEmpty) {
      return _buildEmptySearch();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              const Text(
                'Búsquedas recientes',
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              ),
              const Spacer(),
              GestureDetector(
                onTap: searchProvider.clearHistory,
                child: const Text(
                  'Borrar todo',
                  style: TextStyle(fontSize: 13, color: AppTheme.accentColor),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: searchProvider.searchHistory.length,
            itemBuilder: (context, index) {
              final query = searchProvider.searchHistory[index];
              return ListTile(
                leading: const Icon(Icons.history, color: AppTheme.textSecondary),
                title: Text(query),
                trailing: IconButton(
                  icon: const Icon(Icons.close, size: 18, color: AppTheme.textSecondary),
                  onPressed: () => searchProvider.removeHistoryItem(query),
                ),
                onTap: () {
                  _searchController.text = query;
                  _showSuggestions = false;
                  searchProvider.search(query);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptySearch() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search, size: 80, color: AppTheme.textSecondary.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          const Text(
            'Busca música en YouTube',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Encuentra canciones, artistas o álbumes\npara descargar y escuchar sin conexión',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildResults(SearchProvider searchProvider) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              Text(
                '${searchProvider.results.length} resultados',
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: searchProvider.results.length + (searchProvider.isLoading ? 1 : 0),
            itemBuilder: (context, index) {
              if (index >= searchProvider.results.length) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              final video = searchProvider.results[index];
              return SearchResultTile(
                video: video,
                onDownload: () {
                  context.read<DownloadProvider>().addDownload(
                    video.id,
                    video.title,
                    artist: video.channel,
                    thumbnailUrl: video.thumbnailUrl,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Descargando: ${video.title}')),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
