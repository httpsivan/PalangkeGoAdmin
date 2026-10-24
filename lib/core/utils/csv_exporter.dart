import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';

import 'platform_file_saver.dart';

Object? _sanitizeCell(Object? value) {
  if (value is String && RegExp(r'^[=+\-@\t\r]').hasMatch(value)) {
    return "'$value";
  }
  return value;
}

String buildCsv(List<List<Object?>> rows) {
  final sanitized = rows.map((row) => row.map(_sanitizeCell).toList()).toList();
  return const ListToCsvConverter().convert(sanitized);
}

void downloadCsv(String csv, String filename) {
  final bytes = Uint8List.fromList(utf8.encode(csv));
  saveFileBytes(
      bytes: bytes, filename: filename, mimeType: 'text/csv;charset=utf-8');
}
