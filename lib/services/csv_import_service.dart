import 'dart:convert';

import 'package:excel/excel.dart';
import 'package:flutter/services.dart';

class CsvTrack {
  final String name;
  final String artists;
  final String? album;

  CsvTrack({required this.name, required this.artists, this.album});

  String get searchQuery => '$name ${artists.split(',').first.trim()}';
}

class CsvImportResult {
  final String fileName;
  final List<CsvTrack> tracks;

  CsvImportResult({required this.fileName, required this.tracks});
}

class CsvImportService {
  static const _channel = MethodChannel('com.example.precarium/file_picker');

  Future<CsvImportResult?> pickAndParse() async {
    final bytes = await _channel.invokeMethod<Uint8List>('pickCsvFile');
    if (bytes == null) return null;

    final isXlsx = bytes.length >= 2 &&
        bytes[0] == 0x50 &&
        bytes[1] == 0x4b;

    final tracks = isXlsx ? _parseXlsx(bytes) : _parseCsv(utf8.decode(bytes));
    return CsvImportResult(
      fileName: 'archivo.${isXlsx ? "xlsx" : "csv"}',
      tracks: tracks,
    );
  }

  List<CsvTrack> _parseXlsx(Uint8List bytes) {
    final excel = Excel.decodeBytes(bytes);
    final sheet = excel.tables.values.first;
    if (sheet.rows.isEmpty) {
      throw Exception('El archivo XLSX está vacío.');
    }

    final headers = sheet.rows[0]
        .map((c) => c?.value?.toString() ?? '')
        .toList();

    final nameIdx = _findColumnIndex(headers, [
      'Track Name', 'track name', 'name', 'title', 'track',
    ]);
    final artistIdx = _findColumnIndex(headers, [
      'Artist Name(s)', 'artist name(s)', 'artist(s)', 'artist', 'artists', 'author',
    ]);
    final albumIdx = _findColumnIndex(headers, ['album', 'collection']);

    if (nameIdx == -1) {
      throw Exception(
        'No se encontró la columna "Name" o "Title" en el XLSX.\n'
        'Encabezados encontrados: ${headers.join(", ")}');
    }

    final tracks = <CsvTrack>[];
    for (int i = 1; i < sheet.rows.length; i++) {
      final row = sheet.rows[i];
      if (nameIdx >= row.length) continue;

      final name = row[nameIdx]?.value?.toString().trim() ?? '';
      if (name.isEmpty) continue;

      tracks.add(CsvTrack(
        name: name,
        artists: artistIdx != -1 && artistIdx < row.length
            ? (row[artistIdx]?.value?.toString().trim() ?? '')
            : '',
        album: albumIdx != -1 && albumIdx < row.length
            ? row[albumIdx]?.value?.toString().trim()
            : null,
      ));
    }

    if (tracks.isEmpty) {
      throw Exception(
        'No se encontraron canciones en el archivo.\n'
        'Asegúrate de que el XLSX tenga filas con datos.');
    }

    return tracks;
  }

  List<CsvTrack> _parseCsv(String content) {
    final lines = content
        .split(RegExp(r'\r?\n'))
        .where((l) => l.trim().isNotEmpty)
        .toList();

    if (lines.isEmpty) return [];

    final headers = _parseCsvLine(lines[0]);
    final nameIdx = _findColumnIndex(headers, [
      'Track Name', 'track name', 'name', 'title', 'track',
    ]);
    final artistIdx = _findColumnIndex(headers, [
      'Artist Name(s)', 'artist name(s)', 'artist(s)', 'artist', 'artists', 'author',
    ]);
    final albumIdx = _findColumnIndex(headers, ['album', 'collection']);

    if (nameIdx == -1) {
      throw Exception(
        'No se encontró la columna "Name" o "Title" en el CSV.\n'
        'Encabezados encontrados: ${headers.join(", ")}');
    }

    final tracks = <CsvTrack>[];
    for (int i = 1; i < lines.length; i++) {
      final values = _parseCsvLine(lines[i]);
      if (values.length <= nameIdx) continue;

      final name = values[nameIdx].trim();
      if (name.isEmpty) continue;

      tracks.add(CsvTrack(
        name: name,
        artists: artistIdx != -1 && values.length > artistIdx
            ? values[artistIdx].trim()
            : '',
        album: albumIdx != -1 && values.length > albumIdx
            ? values[albumIdx].trim()
            : null,
      ));
    }

    if (tracks.isEmpty) {
      throw Exception(
        'No se encontraron canciones en el archivo.\n'
        'Asegúrate de que el CSV tenga filas con datos.');
    }

    return tracks;
  }

  int _findColumnIndex(List<String> headers, List<String> names) {
    for (final name in names) {
      final lower = name.toLowerCase();
      final idx = headers.indexWhere(
        (h) => h.trim().toLowerCase().contains(lower),
      );
      if (idx != -1) return idx;
    }
    return -1;
  }

  List<String> _parseCsvLine(String line) {
    final result = <String>[];
    bool inQuotes = false;
    String current = '';

    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          current += '"';
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        result.add(current);
        current = '';
      } else {
        current += char;
      }
    }
    result.add(current);
    return result;
  }
}
