import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

class DriveBackupService {
  static const String _driveApi = 'https://www.googleapis.com/drive/v3';
  static const String _uploadApi = 'https://www.googleapis.com/upload/drive/v3';
  static const String _backupFolder = 'Precarium Respaldos';
  static const String _songsFolder = 'Canciones Respaldo';
  static const _timeout = Duration(seconds: 60);

  http.Client _client = http.Client();
  late final GoogleSignIn _googleSignIn;

  DriveBackupService() {
    _googleSignIn = GoogleSignIn(
      scopes: [dotenv.env['GOOGLE_DRIVE_SCOPE']!],
      serverClientId: dotenv.env['GOOGLE_WEB_CLIENT_ID']!,
    );
  }

  void dispose() {
    _client.close();
  }

  bool get isLoggedIn => _googleSignIn.currentUser != null;

  Future<bool> tryRestore() async {
    try {
      await _googleSignIn.signInSilently();
      return _googleSignIn.currentUser != null;
    } catch (_) {
      return false;
    }
  }

  Future<void> login() async {
    final account = await _googleSignIn.signIn();
    if (account == null) {
      throw Exception('Inicio de sesión cancelado');
    }
  }

  Future<void> logout() async {
    await _googleSignIn.disconnect();
  }

  Map<String, String>? _cachedHeaders;
  DateTime? _headerExpiry;

  Future<Map<String, String>> _getAuthHeaders() async {
    if (_cachedHeaders != null && _headerExpiry != null &&
        DateTime.now().isBefore(_headerExpiry!)) {
      return _cachedHeaders!;
    }

    final user = _googleSignIn.currentUser;
    if (user == null) {
      throw Exception('No hay sesión de Google activa.');
    }

    final auth = await user.authentication;
    _cachedHeaders = {
      'Authorization': 'Bearer ${auth.accessToken}',
    };
    _headerExpiry = DateTime.now().add(const Duration(minutes: 55));
    return _cachedHeaders!;
  }

  // ── Folder management ──

  Future<String> _ensureFolder(String name, {String? parentId}) async {
    final headers = await _getAuthHeaders();
    final parentQuery = parentId != null ? " and '$parentId' in parents" : '';

    final listResponse = await _client.get(
      Uri.parse(
          '$_driveApi/files?q=name=\'${Uri.encodeQueryComponent(name)}\' and mimeType=\'application/vnd.google-apps.folder\' and trashed=false$parentQuery&fields=files(id)'),
      headers: headers,
    ).timeout(_timeout);

    if (listResponse.statusCode == 200) {
      final data = json.decode(listResponse.body) as Map<String, dynamic>;
      final files = data['files'] as List<dynamic>? ?? [];
      if (files.isNotEmpty) {
        return (files.first as Map<String, dynamic>)['id'] as String;
      }
    }

    final createBody = <String, dynamic>{
      'name': name,
      'mimeType': 'application/vnd.google-apps.folder',
    };
    if (parentId != null) createBody['parents'] = [parentId];

    final createResponse = await _client.post(
      Uri.parse('$_driveApi/files'),
      headers: {...headers, 'Content-Type': 'application/json'},
      body: json.encode(createBody),
    ).timeout(_timeout);

    if (createResponse.statusCode != 200) {
      throw Exception('Error al crear carpeta en Drive: ${createResponse.statusCode}');
    }

    return (json.decode(createResponse.body) as Map<String, dynamic>)['id'] as String;
  }

  Future<String> ensureBackupFolder() => _ensureFolder(_backupFolder);

  Future<String> ensureTypeFolder(String backupFolderId, String typeName) =>
      _ensureFolder(typeName, parentId: backupFolderId);

  Future<String> ensureSongsFolder(String parentFolderId) =>
      _ensureFolder(_songsFolder, parentId: parentFolderId);

  Future<void> deleteAllFilesInFolder(String folderId) async {
    final headers = await _getAuthHeaders();

    final listResponse = await _client.get(
      Uri.parse(
          '$_driveApi/files?q=\'$folderId\' in parents and trashed=false&fields=files(id)'),
      headers: headers,
    ).timeout(_timeout);

    if (listResponse.statusCode != 200) return;

    final data = json.decode(listResponse.body) as Map<String, dynamic>;
    final files = data['files'] as List<dynamic>? ?? [];

    for (final f in files) {
      final id = (f as Map<String, dynamic>)['id'] as String;
      await _client.delete(Uri.parse('$_driveApi/files/$id'), headers: headers).timeout(_timeout);
    }
  }

  Future<String?> findBackupFolder() async {
    final headers = await _getAuthHeaders();
    final q = 'name=\'${Uri.encodeQueryComponent(_backupFolder)}\''
        ' and mimeType=\'application/vnd.google-apps.folder\' and trashed=false';
    final response = await _client.get(
      Uri.parse('$_driveApi/files?q=$q&fields=files(id)'),
      headers: headers,
    ).timeout(_timeout);
    if (response.statusCode != 200) return null;
    final data = json.decode(response.body) as Map<String, dynamic>;
    final files = data['files'] as List<dynamic>? ?? [];
    if (files.isEmpty) return null;
    return (files.first as Map<String, dynamic>)['id'] as String;
  }

  Future<void> deleteFolder(String folderId) async {
    final headers = await _getAuthHeaders();
    await _client.delete(Uri.parse('$_driveApi/files/$folderId'), headers: headers).timeout(_timeout);
  }

  Future<void> deleteFile(String fileId) async {
    final headers = await _getAuthHeaders();
    await _client.delete(Uri.parse('$_driveApi/files/$fileId'), headers: headers).timeout(_timeout);
  }

  // ── JSON file operations ──

  Future<String> uploadJsonFile(String folderId, String fileName, String jsonContent) async {
    final headers = await _getAuthHeaders();

    final createResponse = await _client.post(
      Uri.parse('$_driveApi/files'),
      headers: {...headers, 'Content-Type': 'application/json'},
      body: json.encode({
        'name': fileName,
        'parents': [folderId],
        'mimeType': 'application/json',
      }),
    ).timeout(_timeout);

    if (createResponse.statusCode != 200) {
      throw Exception('Error al crear archivo en Drive: ${createResponse.statusCode}');
    }

    final fileId = (json.decode(createResponse.body) as Map<String, dynamic>)['id'] as String;

    final uploadResponse = await _client.patch(
      Uri.parse('$_uploadApi/files/$fileId?uploadType=media'),
      headers: {...headers, 'Content-Type': 'application/json'},
      body: jsonContent,
    ).timeout(_timeout);

    if (uploadResponse.statusCode != 200) {
      throw Exception('Error al subir contenido a Drive: ${uploadResponse.statusCode}');
    }

    return fileId;
  }

  Future<String?> findFileByName(String folderId, String name) async {
    final headers = await _getAuthHeaders();

    final listResponse = await _client.get(
      Uri.parse(
          '$_driveApi/files?q=name=\'${Uri.encodeQueryComponent(name)}\' and \'$folderId\' in parents and trashed=false&pageSize=1&fields=files(id)'),
      headers: headers,
    ).timeout(_timeout);

    if (listResponse.statusCode != 200) return null;

    final data = json.decode(listResponse.body) as Map<String, dynamic>;
    final files = data['files'] as List<dynamic>? ?? [];
    if (files.isEmpty) return null;

    return (files.first as Map<String, dynamic>)['id'] as String;
  }

  Future<String?> downloadJsonFile(String fileId) async {
    final headers = await _getAuthHeaders();

    final response = await _client.get(
      Uri.parse('$_driveApi/files/$fileId?alt=media'),
      headers: headers,
    ).timeout(_timeout);

    if (response.statusCode != 200) return null;
    return response.body;
  }

  // ── Song file operations ──

  Future<List<Map<String, dynamic>>> listSongFiles(String folderId, {void Function(int count)? onPage}) async {
    final headers = await _getAuthHeaders();
    final allFiles = <Map<String, dynamic>>[];
    String? pageToken;

    do {
      var url = '$_driveApi/files?q=\'$folderId\' in parents and trashed=false'
          '&fields=files(id,name,size),nextPageToken&pageSize=1000';
      if (pageToken != null) {
        url += '&pageToken=$pageToken';
      }

      final listResponse = await _client.get(Uri.parse(url), headers: headers).timeout(_timeout);
      if (listResponse.statusCode != 200) break;

      final data = json.decode(listResponse.body) as Map<String, dynamic>;
      final files = data['files'] as List<dynamic>? ?? [];
      for (final f in files) {
        allFiles.add(Map<String, dynamic>.from(f as Map));
      }
      pageToken = data['nextPageToken'] as String?;
      onPage?.call(allFiles.length);
    } while (pageToken != null);

    return allFiles;
  }

  http.Client _uploadClient = http.Client();

  void resetUploadClient() {
    _uploadClient.close();
    _uploadClient = http.Client();
  }

  void cancelUpload() {
    _client.close();
    _uploadClient.close();
    _client = http.Client();
    _uploadClient = http.Client();
  }

  Future<String> createSongMetadata(String folderId, String fileName) async {
    final headers = await _getAuthHeaders();
    final createResponse = await _client.post(
      Uri.parse('$_driveApi/files'),
      headers: {...headers, 'Content-Type': 'application/json'},
      body: json.encode({
        'name': fileName,
        'parents': [folderId],
      }),
    ).timeout(_timeout);
    if (createResponse.statusCode != 200) {
      throw Exception('Error al crear archivo en Drive: ${createResponse.statusCode}');
    }
    return (json.decode(createResponse.body) as Map<String, dynamic>)['id'] as String;
  }

  Future<void> uploadSongContent(String fileId, String localPath) async {
    final headers = await _getAuthHeaders();
    final file = File(localPath);
    if (!await file.exists()) {
      throw Exception('Archivo no encontrado: $localPath');
    }
    final length = await file.length();
    final request = http.StreamedRequest('PATCH', Uri.parse('$_uploadApi/files/$fileId?uploadType=media'));
    request.contentLength = length;
    request.headers.addAll({...headers, 'Content-Type': 'application/octet-stream'});
    file.openRead().pipe(request.sink);
    final uploadResponse = await _uploadClient.send(request).timeout(_timeout);
    if (uploadResponse.statusCode != 200) {
      final body = await uploadResponse.stream.bytesToString();
      throw Exception('Error al subir canción a Drive: ${uploadResponse.statusCode} $body');
    }
  }

  Future<String> uploadSongFile(String folderId, String localPath, String fileName) async {
    final headers = await _getAuthHeaders();
    final file = File(localPath);
    if (!await file.exists()) {
      throw Exception('Archivo no encontrado: $localPath');
    }
    final createResponse = await _client.post(
      Uri.parse('$_driveApi/files'),
      headers: {...headers, 'Content-Type': 'application/json'},
      body: json.encode({
        'name': fileName,
        'parents': [folderId],
      }),
    ).timeout(_timeout);
    if (createResponse.statusCode != 200) {
      throw Exception('Error al crear archivo en Drive: ${createResponse.statusCode}');
    }
    final fileId = (json.decode(createResponse.body) as Map<String, dynamic>)['id'] as String;

    final length = await file.length();
    final request = http.StreamedRequest('PATCH', Uri.parse('$_uploadApi/files/$fileId?uploadType=media'));
    request.contentLength = length;
    request.headers.addAll({...headers, 'Content-Type': 'application/octet-stream'});
    file.openRead().pipe(request.sink);
    final uploadResponse = await _uploadClient.send(request).timeout(_timeout);
    if (uploadResponse.statusCode != 200) {
      final body = await uploadResponse.stream.bytesToString();
      throw Exception('Error al subir canción a Drive: ${uploadResponse.statusCode} $body');
    }
    return fileId;
  }

  Future<void> downloadSongFile(String fileId, String destPath) async {
    final headers = await _getAuthHeaders();

    final response = await _client.get(
      Uri.parse('$_driveApi/files/$fileId?alt=media'),
      headers: headers,
    ).timeout(_timeout);

    if (response.statusCode != 200) {
      throw Exception('Error al descargar canción de Drive: ${response.statusCode}');
    }

    final file = File(destPath);
    await file.writeAsBytes(response.bodyBytes);
  }
}
