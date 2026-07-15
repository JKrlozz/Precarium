import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class YouTubeSearchResult {
  final String id;
  final String title;
  final String channel;
  final String? thumbnailUrl;
  final Duration duration;

  YouTubeSearchResult({
    required this.id,
    required this.title,
    required this.channel,
    this.thumbnailUrl,
    this.duration = Duration.zero,
  });

  String get formattedDuration {
    if (duration == Duration.zero) return '';
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

class YouTubeSearchService {
  final YoutubeExplode _yt = YoutubeExplode();

  Future<List<YouTubeSearchResult>> search(String query, {bool musicOnly = true}) async {
    try {
      final searchQuery = musicOnly ? '$query música' : query;
      final results = await _yt.search.search(searchQuery);

      final videos = <YouTubeSearchResult>[];
      for (final result in results) {
        try {
          videos.add(YouTubeSearchResult(
            id: result.id.value,
            title: result.title,
            channel: result.author,
            thumbnailUrl: result.thumbnails.mediumResUrl,
            duration: result.duration ?? Duration.zero,
          ));
          if (videos.length >= 20) break;
        } catch (_) {
          continue;
        }
      }
      return videos;
    } catch (e) {
      throw Exception('Error al buscar: $e');
    }
  }

  Future<List<String>> getSuggestions(String query) async {
    try {
      return await _yt.search.getQuerySuggestions(query);
    } catch (_) {
      return [];
    }
  }

  void dispose() {
    _yt.close();
  }
}
