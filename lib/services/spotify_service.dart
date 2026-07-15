import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const String _clientId = 'c136a495825845b2b2cc2ed6880d80ff';
const String _clientSecret = '5e0f0021597d498da4f11132d7a7c51d';
const String _redirectUri = 'precarium://callback';
const String _authUrl = 'https://accounts.spotify.com/authorize';
const String _tokenUrl = 'https://accounts.spotify.com/api/token';
const String _apiBase = 'https://api.spotify.com/v1';
const String _scope = 'playlist-read-private playlist-read-collaborative';

class SpotifyTrack {
  final String id;
  final String title;
  final List<String> artists;
  final String? album;
  final String? albumArtUrl;
  final Duration duration;

  SpotifyTrack({
    required this.id,
    required this.title,
    required this.artists,
    this.album,
    this.albumArtUrl,
    this.duration = Duration.zero,
  });

  String get artistString => artists.join(', ');
  String get searchQuery => '$title ${artists.first}';
}

class SpotifyPlaylist {
  final String id;
  final String name;
  final String? description;
  final String? owner;
  final List<SpotifyTrack> tracks;

  SpotifyPlaylist({
    required this.id,
    required this.name,
    this.description,
    this.owner,
    required this.tracks,
  });
}

class SpotifyService {
  // App token (Client Credentials) - no user needed
  String? _appToken;
  DateTime? _appTokenExpiry;

  // User token (OAuth PKCE) - user login
  String? _userToken;
  String? _refreshToken;
  DateTime? _userTokenExpiry;

  bool get isLoggedIn => _userToken != null;

  bool get _hasValidAppToken =>
      _appToken != null &&
      _appTokenExpiry != null &&
      DateTime.now().isBefore(_appTokenExpiry!);

  bool get _hasValidUserToken =>
      _userToken != null &&
      _userTokenExpiry != null &&
      DateTime.now().isBefore(_userTokenExpiry!);

  Future<void> loadTokens() async {
    final prefs = await SharedPreferences.getInstance();
    _userToken = prefs.getString('spotify_access_token');
    _refreshToken = prefs.getString('spotify_refresh_token');
    final expiry = prefs.getInt('spotify_token_expiry');
    if (expiry != null) {
      _userTokenExpiry = DateTime.fromMillisecondsSinceEpoch(expiry);
    }
  }

  Future<void> _saveTokens() async {
    final prefs = await SharedPreferences.getInstance();
    if (_userToken != null) {
      await prefs.setString('spotify_access_token', _userToken!);
    }
    if (_refreshToken != null) {
      await prefs.setString('spotify_refresh_token', _refreshToken!);
    }
    if (_userTokenExpiry != null) {
      await prefs.setInt('spotify_token_expiry', _userTokenExpiry!.millisecondsSinceEpoch);
    }
  }

  Future<void> clearTokens() async {
    _userToken = null;
    _refreshToken = null;
    _userTokenExpiry = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('spotify_access_token');
    await prefs.remove('spotify_refresh_token');
    await prefs.remove('spotify_token_expiry');
  }

  // ── App Token (Client Credentials) ──

  Future<void> _ensureAppToken() async {
    if (_hasValidAppToken) return;

    final basicAuth = base64Encode(utf8.encode('$_clientId:$_clientSecret'));
    final response = await http.post(
      Uri.parse(_tokenUrl),
      headers: {
        'Authorization': 'Basic $basicAuth',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: 'grant_type=client_credentials',
    );

    if (response.statusCode != 200) {
      throw Exception(
          'Error al conectar con Spotify: ${response.statusCode} ${response.body}');
    }

    final data = json.decode(response.body) as Map<String, dynamic>;
    _appToken = data['access_token'] as String?;
    final expiresIn = data['expires_in'] as int? ?? 3600;
    _appTokenExpiry = DateTime.now().add(Duration(seconds: expiresIn - 60));
  }

  // ── User Token (OAuth PKCE) ──

  String _generateCodeVerifier() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~';
    final random = Random.secure();
    return List.generate(64, (_) => chars[random.nextInt(chars.length)]).join();
  }

  String _generateCodeChallenge(String verifier) {
    final bytes = utf8.encode(verifier);
    final digest = sha256.convert(bytes);
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }

  String _generateState() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    return List.generate(16, (_) => chars[random.nextInt(chars.length)]).join();
  }

  Future<void> login() async {
    final verifier = _generateCodeVerifier();
    final challenge = _generateCodeChallenge(verifier);
    final state = _generateState();

    final authUrl = Uri.parse(_authUrl).replace(queryParameters: {
      'response_type': 'code',
      'client_id': _clientId,
      'redirect_uri': _redirectUri,
      'scope': _scope,
      'state': state,
      'code_challenge_method': 'S256',
      'code_challenge': challenge,
    });

    final result = await FlutterWebAuth2.authenticate(
      url: authUrl.toString(),
      callbackUrlScheme: 'precarium',
    );

    final callbackUri = Uri.parse(result);
    final returnedState = callbackUri.queryParameters['state'];
    if (returnedState == null || returnedState != state) {
      throw Exception('Error de seguridad: state mismatch');
    }

    final code = callbackUri.queryParameters['code'];
    if (code == null) {
      final error = callbackUri.queryParameters['error'] ?? 'Error desconocido';
      throw Exception('Inicio de sesión cancelado: $error');
    }

    final tokenResponse = await http.post(
      Uri.parse(_tokenUrl),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type': 'authorization_code',
        'code': code,
        'redirect_uri': _redirectUri,
        'client_id': _clientId,
        'code_verifier': verifier,
      },
    );

    if (tokenResponse.statusCode != 200) {
      throw Exception('Error al obtener el token: ${tokenResponse.statusCode} ${tokenResponse.body}');
    }

    final tokenData = json.decode(tokenResponse.body) as Map<String, dynamic>;
    _userToken = tokenData['access_token'] as String?;
    _refreshToken = tokenData['refresh_token'] as String?;
    final expiresIn = tokenData['expires_in'] as int? ?? 3600;
    _userTokenExpiry = DateTime.now().add(Duration(seconds: expiresIn - 60));
    await _saveTokens();
  }

  Future<void> _refreshUserToken() async {
    if (_refreshToken == null) {
      await clearTokens();
      throw Exception('La sesión de Spotify ha expirado. Inicia sesión nuevamente.');
    }

    final response = await http.post(
      Uri.parse(_tokenUrl),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type': 'refresh_token',
        'refresh_token': _refreshToken!,
        'client_id': _clientId,
      },
    );

    if (response.statusCode != 200) {
      await clearTokens();
      throw Exception('La sesión de Spotify ha expirado. Inicia sesión nuevamente.');
    }

    final data = json.decode(response.body) as Map<String, dynamic>;
    _userToken = data['access_token'] as String?;
    final expiresIn = data['expires_in'] as int? ?? 3600;
    _userTokenExpiry = DateTime.now().add(Duration(seconds: expiresIn - 60));

    if (data['refresh_token'] != null) {
      _refreshToken = data['refresh_token'] as String?;
    }

    await _saveTokens();
  }

  // ── Playlist Fetching ──

  /// Tries API with app token first; falls back to user token if available,
  /// then finally tries web scraping as last resort.
  Future<SpotifyPlaylist> getPlaylist(String playlistUrl) async {
    final playlistId = _extractPlaylistId(playlistUrl);
    if (playlistId == null) {
      throw Exception('URL de playlist no válida');
    }

    await _ensureAppToken();

    // 1) Try API with app token
    try {
      return await _fetchPlaylistWithToken(playlistId, _appToken!);
    } on RequiresPremiumException {
      // App token rejected — try scraping
    } catch (e) {
      // 2) Try API with user token (if available)
      if (_userToken != null) {
        if (!_hasValidUserToken && _refreshToken != null) {
          try {
            await _refreshUserToken();
          } catch (_) {
            // refresh failed, continue to scraping
          }
        }
        if (_userToken != null) {
          try {
            return await _fetchPlaylistWithToken(playlistId, _userToken!);
          } on RequiresPremiumException {
            // User token also rejected — try scraping
          } catch (_) {
            // Other error — try scraping
          }
        }
      }
    }

    // 3) Last resort: scrape the public web page
    return await _scrapePlaylist(playlistId);
  }

  Future<SpotifyPlaylist> _fetchPlaylistWithToken(
      String playlistId, String token) async {
    final response = await http.get(
      Uri.parse('$_apiBase/playlists/$playlistId'),
      headers: {
        'Authorization': 'Bearer $token',
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': 'application/json',
      },
    );

    if (response.statusCode == 401) {
      throw Exception('Token inválido');
    }

    if (response.statusCode == 403) {
      final body = response.body;
      if (body.contains('premium') || body.contains('subscription')) {
        throw RequiresPremiumException();
      }
      throw Exception('Acceso denegado a la playlist: $body');
    }

    if (response.statusCode != 200) {
      throw Exception('Error de Spotify: ${response.statusCode} ${response.body}');
    }

    final data = json.decode(response.body) as Map<String, dynamic>;
    final tracks = <SpotifyTrack>[];

    final items = data['tracks']['items'] as List<dynamic>;
    for (final item in items) {
      final track = item['track'] as Map<String, dynamic>?;
      if (track == null) continue;

      final artists = (track['artists'] as List<dynamic>)
          .map((a) => a['name'] as String)
          .toList();
      final album = track['album'] as Map<String, dynamic>?;
      final images = album?['images'] as List<dynamic>?;
      String? albumArtUrl;
      if (images != null && images.isNotEmpty) {
        albumArtUrl = images.first['url'] as String?;
      }

      tracks.add(SpotifyTrack(
        id: track['id'] as String,
        title: track['name'] as String,
        artists: artists,
        album: album?['name'] as String?,
        albumArtUrl: albumArtUrl,
        duration: Duration(milliseconds: (track['duration_ms'] as int?) ?? 0),
      ));
    }

    return SpotifyPlaylist(
      id: data['id'] as String,
      name: data['name'] as String,
      description: data['description'] as String?,
      owner: data['owner']?['display_name'] as String?,
      tracks: tracks,
    );
  }

  /// Fallback: scrape the public Spotify web page with a bot User-Agent
  /// to extract playlist data when the API rejects the request.
  Future<SpotifyPlaylist> _scrapePlaylist(String playlistId) async {
    final response = await http.get(
      Uri.parse('https://open.spotify.com/playlist/$playlistId'),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)',
        'Accept': 'text/html,application/xhtml+xml',
        'Accept-Language': 'es-ES,es;q=0.9,en;q=0.8',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('No se pudo acceder a la playlist (${response.statusCode})');
    }

    final html = response.body;

    // Extract playlist name from Open Graph meta tag
    String playlistName = 'Playlist';
    final ogTitleMatch = RegExp(
      r'<meta[^>]*property="og:title"[^>]*content="([^"]*)"',
    ).firstMatch(html);
    if (ogTitleMatch != null) {
      playlistName = ogTitleMatch.group(1)!
          .replaceAll('&#x27;', "'")
          .replaceAll('&amp;', '&')
          .replaceAll('&quot;', '"');
    }

    // Extract owner name from Open Graph
    String? ownerName;
    final ogSiteMatch = RegExp(
      r'<meta[^>]*name="description"[^>]*content="([^"]*)"',
    ).firstMatch(html);
    if (ogSiteMatch != null) {
      final desc = ogSiteMatch.group(1)!;
      final ownerMatch = RegExp(r'por\s+(.+?)(?:\s*•|$)').firstMatch(desc);
      if (ownerMatch != null) ownerName = ownerMatch.group(1)!.trim();
    }

    // Try JSON-LD structured data
    final jsonLdMatch = RegExp(
      r'<script[^>]*type="application/ld\+json"[^>]*>(.*?)</script>',
      dotAll: true,
      caseSensitive: false,
    ).firstMatch(html);

    if (jsonLdMatch != null) {
      try {
        final jsonStr = jsonLdMatch.group(1)!;
        final data = json.decode(jsonStr);
        final tracks = <SpotifyTrack>[];
        final trackList = _extractTracksFromJsonLd(data);
        if (trackList.isNotEmpty) {
          for (int i = 0; i < trackList.length; i++) {
            final t = trackList[i];
            tracks.add(SpotifyTrack(
              id: t['id'] ?? 'track_$i',
              title: t['name'] ?? 'Unknown',
              artists: t['artists'] ?? ['Unknown'],
              duration: t['duration'],
            ));
          }
          return SpotifyPlaylist(
            id: playlistId,
            name: playlistName,
            description: null,
            owner: ownerName,
            tracks: tracks,
          );
        }
      } catch (_) {
        // JSON parse failed, try other methods
      }
    }

    // Try __NEXT_DATA__ (server-rendered React state)
    final nextDataMatch = RegExp(
      r'<script[^>]*id="__NEXT_DATA__"[^>]*>(.*?)</script>',
      dotAll: true,
      caseSensitive: false,
    ).firstMatch(html);

    if (nextDataMatch != null) {
      try {
        final jsonStr = nextDataMatch.group(1)!;
        final data = json.decode(jsonStr) as Map<String, dynamic>;
        final tracks = <SpotifyTrack>[];
        final trackList = _extractTracksFromNextData(data);
        if (trackList.isNotEmpty) {
          for (int i = 0; i < trackList.length; i++) {
            final t = trackList[i];
            tracks.add(SpotifyTrack(
              id: t['id'] ?? 'track_$i',
              title: t['name'] ?? 'Unknown',
              artists: t['artists'] ?? ['Unknown'],
              duration: t['duration'],
            ));
          }
          return SpotifyPlaylist(
            id: playlistId,
            name: playlistName,
            description: null,
            owner: ownerName,
            tracks: tracks,
          );
        }
      } catch (_) {
        // JSON parse failed
      }
    }

    // Fallback: try to find track names in simple meta or script data
    // Look for "track" mentions in any embedded JSON
    final anyJsonMatch = RegExp(
      r'<(?:script|div|section)[^>]*>(.*?\{"@type":\s*"MusicRecording".*?)</(?:script|div|section)>',
      dotAll: true,
    ).firstMatch(html);

    if (anyJsonMatch != null) {
      try {
        final jsonStr = anyJsonMatch.group(1)!;
        final data = json.decode(jsonStr);
        final tracks = <SpotifyTrack>[];
        final trackList = _extractTracksFromJsonLd(data);
        if (trackList.isNotEmpty) {
          for (int i = 0; i < trackList.length; i++) {
            final t = trackList[i];
            tracks.add(SpotifyTrack(
              id: t['id'] ?? 'track_$i',
              title: t['name'] ?? 'Unknown',
              artists: t['artists'] ?? ['Unknown'],
              duration: t['duration'],
            ));
          }
          return SpotifyPlaylist(
            id: playlistId,
            name: playlistName,
            description: null,
            owner: ownerName,
            tracks: tracks,
          );
        }
      } catch (_) {}
    }

    throw Exception(
      'No se pudieron extraer las canciones de esta playlist. '
      'Prueba con otra playlist o inicia sesión con una cuenta Premium.',
    );
  }

  /// Extract track list from JSON-LD structured data (Schema.org).
  List<Map<String, dynamic>> _extractTracksFromJsonLd(dynamic data) {
    final result = <Map<String, dynamic>>[];

    if (data is Map<String, dynamic>) {
      // Handle single playlist object
      if (data['@type'] == 'MusicPlaylist' || data['@graph'] != null) {
        final tracks = data['track'] ?? <dynamic>[];
        if (tracks is List) {
          for (final item in tracks) {
            if (item is Map<String, dynamic>) {
              result.add(_parseTrackJsonLd(item));
            }
          }
        }
      }

      // Handle @graph (list of items)
      final graph = data['@graph'];
      if (graph is List) {
        for (final item in graph) {
          if (item is Map<String, dynamic> &&
              item['@type'] == 'MusicRecording') {
            result.add(_parseTrackJsonLd(item));
          }
        }
      }
    }

    return result;
  }

  Map<String, dynamic> _parseTrackJsonLd(Map<String, dynamic> item) {
    final name = item['name'] as String? ?? 'Unknown';

    List<String> artists = ['Unknown'];
    final artist = item['byArtist'];
    if (artist is Map<String, dynamic>) {
      artists = [artist['name'] as String? ?? 'Unknown'];
    } else if (artist is List) {
      artists = artist
          .map((a) => (a is Map ? a['name'] : a?.toString()) ?? 'Unknown')
          .cast<String>()
          .toList();
    }

    return {
      'id': item['@id'] ?? item['url'] ?? '',
      'name': _decodeHtmlEntities(name),
      'artists': artists.map((a) => _decodeHtmlEntities(a)).toList(),
      'duration': Duration.zero,
    };
  }

  /// Extract track list from Next.js __NEXT_DATA__ state.
  List<Map<String, dynamic>> _extractTracksFromNextData(
      Map<String, dynamic> data) {
    final result = <Map<String, dynamic>>[];

    try {
      final props = data['props'] as Map<String, dynamic>?;
      final pageProps = props?['pageProps'] as Map<String, dynamic>?;
      final state = pageProps?['state'] as Map<String, dynamic>?;
      final playlistData = state?['playlist'] as Map<String, dynamic>?;
      final items = playlistData?['items'] as List<dynamic>?;

      if (items != null) {
        for (final item in items) {
          if (item is Map<String, dynamic>) {
            final track = item['track'] as Map<String, dynamic>?;
            if (track == null) continue;

            final artists = (track['artists'] as List<dynamic>?)
                    ?.map((a) => a['name'] as String)
                    .toList() ??
                ['Unknown'];

            result.add({
              'id': track['id'] as String? ?? '',
              'name': track['name'] as String? ?? 'Unknown',
              'artists': artists,
              'duration': Duration(
                milliseconds: (track['duration_ms'] as int?) ?? 0,
              ),
            });
          }
        }
      }
    } catch (_) {}

    return result;
  }

  String _decodeHtmlEntities(String text) {
    return text
        .replaceAll('&#x27;', "'")
        .replaceAll('&#39;', "'")
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');
  }

  String? _extractPlaylistId(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri != null && uri.host.contains('spotify.com')) {
      final segments = uri.pathSegments;
      for (int i = 0; i < segments.length - 1; i++) {
        if (segments[i] == 'playlist') return segments[i + 1];
      }
    }
    final match = RegExp(r'spotify:playlist:(\w+)').firstMatch(url);
    if (match != null) return match.group(1);
    return null;
  }
}

class RequiresPremiumException implements Exception {
  @override
  String toString() =>
      'Esta playlist requiere cuenta Premium. Inicia sesión con una cuenta Premium o prueba con otra playlist.';
}
