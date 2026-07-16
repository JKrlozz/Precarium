import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../secrets.dart';

class DriveBackupService {
  static const String _authUrl = 'https://accounts.google.com/o/oauth2/v2/auth';
  static const String _tokenUrl = 'https://oauth2.googleapis.com/token';
  static const String _driveApi = 'https://www.googleapis.com/drive/v3';
  static const String _uploadApi = 'https://www.googleapis.com/upload/drive/v3';
  static const String _scope = 'https://www.googleapis.com/auth/drive.file';

  String? _accessToken;
  String? _refreshToken;
  DateTime? _tokenExpiry;

  String get _clientId => Secrets.driveClientId;
  String get _redirectUri =>
      'com.googleusercontent.apps.$_clientId:/';
  String get _callbackScheme =>
      'com.googleusercontent.apps.$_clientId';

  bool get isLoggedIn => _accessToken != null;
  bool get _hasValidToken =>
      _accessToken != null &&
      _tokenExpiry != null &&
      DateTime.now().isBefore(_tokenExpiry!);

  // ── Token persistence ──

  Future<void> loadTokens() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('drive_access_token');
    _refreshToken = prefs.getString('drive_refresh_token');
    final expiry = prefs.getInt('drive_token_expiry');
    if (expiry != null) {
      _tokenExpiry = DateTime.fromMillisecondsSinceEpoch(expiry);
    }
  }

  Future<void> _saveTokens() async {
    final prefs = await SharedPreferences.getInstance();
    if (_accessToken != null) {
      await prefs.setString('drive_access_token', _accessToken!);
    }
    if (_refreshToken != null) {
      await prefs.setString('drive_refresh_token', _refreshToken!);
    }
    if (_tokenExpiry != null) {
      await prefs.setInt('drive_token_expiry', _tokenExpiry!.millisecondsSinceEpoch);
    }
  }

  Future<void> clearTokens() async {
    _accessToken = null;
    _refreshToken = null;
    _tokenExpiry = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('drive_access_token');
    await prefs.remove('drive_refresh_token');
    await prefs.remove('drive_token_expiry');
  }

  // ── PKCE ──

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

  // ── Login ──

  Future<void> login() async {
    final verifier = _generateCodeVerifier();
    final challenge = _generateCodeChallenge(verifier);

    final authUri = Uri.parse(_authUrl).replace(queryParameters: {
      'response_type': 'code',
      'client_id': _clientId,
      'redirect_uri': _redirectUri,
      'scope': _scope,
      'code_challenge_method': 'S256',
      'code_challenge': challenge,
      'access_type': 'offline',
      'prompt': 'consent',
    });

    final result = await FlutterWebAuth2.authenticate(
      url: authUri.toString(),
      callbackUrlScheme: _callbackScheme,
    );

    final callbackUri = Uri.parse(result);
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
      throw Exception(
          'Error al obtener el token: ${tokenResponse.statusCode} ${tokenResponse.body}');
    }

    final data = json.decode(tokenResponse.body) as Map<String, dynamic>;
    _accessToken = data['access_token'] as String?;
    _refreshToken = data['refresh_token'] as String?;
    final expiresIn = data['expires_in'] as int? ?? 3600;
    _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn - 60));
    await _saveTokens();
  }

  Future<void> _refreshUserToken() async {
    if (_refreshToken == null) {
      await clearTokens();
      throw Exception('Sesión de Google expirada. Inicia sesión nuevamente.');
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
      throw Exception('Sesión de Google expirada. Inicia sesión nuevamente.');
    }

    final data = json.decode(response.body) as Map<String, dynamic>;
    _accessToken = data['access_token'] as String?;
    final expiresIn = data['expires_in'] as int? ?? 3600;
    _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn - 60));
    // Refresh tokens may not always be returned
    if (data['refresh_token'] != null) {
      _refreshToken = data['refresh_token'] as String?;
    }
    await _saveTokens();
  }

  Future<void> _ensureToken() async {
    if (_hasValidToken) return;
    if (_refreshToken != null) {
      await _refreshUserToken();
      return;
    }
    throw Exception('No hay sesión de Google activa.');
  }

  // ── Drive API operations ──

  /// Upload backup JSON to Google Drive.
  /// Returns the file ID of the uploaded file.
  Future<String> uploadBackup(String jsonContent) async {
    await _ensureToken();

    // 1. Create file metadata
    final fileName =
        'Precarium_Backup_${DateTime.now().toIso8601String().split('T').first}.json';
    final metadata = json.encode({
      'name': fileName,
      'mimeType': 'application/json',
    });

    final createResponse = await http.post(
      Uri.parse('$_driveApi/files'),
      headers: {
        'Authorization': 'Bearer $_accessToken',
        'Content-Type': 'application/json',
      },
      body: metadata,
    );

    if (createResponse.statusCode != 200) {
      throw Exception(
          'Error al crear archivo en Drive: ${createResponse.statusCode}');
    }

    final fileId =
        (json.decode(createResponse.body) as Map<String, dynamic>)['id'] as String;

    // 2. Upload content
    final uploadResponse = await http.patch(
      Uri.parse('$_uploadApi/files/$fileId?uploadType=media'),
      headers: {
        'Authorization': 'Bearer $_accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonContent,
    );

    if (uploadResponse.statusCode != 200) {
      throw Exception(
          'Error al subir contenido a Drive: ${uploadResponse.statusCode}');
    }

    // 3. Delete old backups, keep only last 5
    await _deleteOldBackups();

    return fileId;
  }

  /// Download the latest backup from Google Drive.
  /// Returns the JSON content as a String, or null if no backup found.
  Future<String?> downloadLatestBackup() async {
    await _ensureToken();

    // List backup files
    final listResponse = await http.get(
      Uri.parse(
          '$_driveApi/files?q=name contains \'Precarium_Backup\' and trashed=false&'
          'orderBy=createdTime desc&pageSize=5&fields=files(id,name,createdTime)'),
      headers: {'Authorization': 'Bearer $_accessToken'},
    );

    if (listResponse.statusCode != 200) {
      throw Exception(
          'Error al listar backups en Drive: ${listResponse.statusCode}');
    }

    final listData = json.decode(listResponse.body) as Map<String, dynamic>;
    final files = listData['files'] as List<dynamic>? ?? [];
    if (files.isEmpty) return null;

    final latestFileId = (files.first as Map<String, dynamic>)['id'] as String;

    // Download file content
    final downloadResponse = await http.get(
      Uri.parse('$_driveApi/files/$latestFileId?alt=media'),
      headers: {'Authorization': 'Bearer $_accessToken'},
    );

    if (downloadResponse.statusCode != 200) {
      throw Exception(
          'Error al descargar backup de Drive: ${downloadResponse.statusCode}');
    }

    return downloadResponse.body;
  }

  /// Delete old backups, keeping only the 5 most recent.
  Future<void> _deleteOldBackups() async {
    final listResponse = await http.get(
      Uri.parse(
          '$_driveApi/files?q=name contains \'Precarium_Backup\' and trashed=false&'
          'orderBy=createdTime desc&fields=files(id)'),
      headers: {'Authorization': 'Bearer $_accessToken'},
    );

    if (listResponse.statusCode != 200) return;

    final listData = json.decode(listResponse.body) as Map<String, dynamic>;
    final files = listData['files'] as List<dynamic>? ?? [];
    if (files.length <= 5) return;

    // Delete files beyond the 5 most recent
    for (int i = 5; i < files.length; i++) {
      final fileId = (files[i] as Map<String, dynamic>)['id'] as String;
      await http.delete(
        Uri.parse('$_driveApi/files/$fileId'),
        headers: {'Authorization': 'Bearer $_accessToken'},
      );
    }
  }
}
