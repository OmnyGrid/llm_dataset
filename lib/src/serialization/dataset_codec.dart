import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../model/dataset_entry.dart';
import '../serialization/json_maps.dart';

/// Exports [DatasetEntry] values to JSON or JSONL.
class DatasetExporter {
  /// Creates an exporter.
  const DatasetExporter();

  /// Writes a single entry as a deterministic JSON string.
  String entryToJsonString(DatasetEntry entry) =>
      jsonEncode(orderedJsonMap(entry.toJson()));

  /// Encodes entries as a JSON array string (small datasets only).
  Future<String> toJson(Stream<DatasetEntry> entries) async {
    final list = <Map<String, dynamic>>[];
    await for (final entry in entries) {
      list.add(orderedJsonMap(entry.toJson()));
    }
    return jsonEncode(list);
  }

  /// Writes JSONL to [sink] one entry per line without buffering the corpus.
  Future<void> writeJsonl(Stream<DatasetEntry> entries, IOSink sink) async {
    await for (final entry in entries) {
      sink.writeln(entryToJsonString(entry));
    }
    await sink.flush();
  }

  /// Writes JSONL to [filePath].
  Future<void> writeJsonlFile(
    Stream<DatasetEntry> entries,
    String filePath,
  ) async {
    final file = File(filePath);
    final sink = file.openWrite();
    try {
      await writeJsonl(entries, sink);
    } finally {
      await sink.close();
    }
  }
}

/// Imports [DatasetEntry] values from JSON or JSONL.
class DatasetImporter {
  /// Creates an importer.
  const DatasetImporter();

  /// Parses a single entry JSON object string.
  DatasetEntry entryFromJsonString(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map) {
      throw FormatException('Expected JSON object for DatasetEntry', source);
    }
    return DatasetEntry.fromJson(Map<String, dynamic>.from(decoded));
  }

  /// Parses a JSON array of entries (small datasets only).
  List<DatasetEntry> fromJson(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! List) {
      throw FormatException('Expected JSON array of DatasetEntry', source);
    }
    return [
      for (final item in decoded)
        if (item is Map)
          DatasetEntry.fromJson(Map<String, dynamic>.from(item))
        else
          throw FormatException('Expected object in DatasetEntry array'),
    ];
  }

  /// Streams entries from a JSONL file line-by-line.
  Stream<DatasetEntry> readJsonlFile(String filePath) async* {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('JSONL file does not exist', filePath);
    }
    yield* readJsonlLines(
      file.openRead().transform(utf8.decoder).transform(const LineSplitter()),
    );
  }

  /// Streams entries from JSONL [lines].
  Stream<DatasetEntry> readJsonlLines(Stream<String> lines) async* {
    var lineNumber = 0;
    await for (final line in lines) {
      lineNumber++;
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      try {
        yield entryFromJsonString(trimmed);
      } on FormatException catch (error) {
        throw FormatException(
          'Invalid DatasetEntry JSON on line $lineNumber: ${error.message}',
          trimmed,
        );
      }
    }
  }
}
