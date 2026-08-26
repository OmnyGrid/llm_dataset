import 'dart:convert';
import 'dart:io';

import 'dataset_source.dart';

/// Streams [DatasetSourceDocument]s from a JSON Lines file.
///
/// Each non-empty line must be a JSON object with a required `id` and
/// `content` (or `text` as an alias for content). Optional `title` and
/// `language` are read when present; all other keys are placed in metadata
/// (except a nested `metadata` object, which is merged).
///
/// The file is read line-by-line and never fully buffered as a single string.
class JsonlSource implements DatasetSource {
  /// Creates a JSONL source for [filePath].
  JsonlSource(this.filePath, {this.encoding = utf8});

  /// Path to the `.jsonl` file.
  final String filePath;

  /// Text encoding.
  final Encoding encoding;

  @override
  Stream<DatasetSourceDocument> load() async* {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('JSONL file does not exist', filePath);
    }

    var lineNumber = 0;
    await for (final line
        in file
            .openRead()
            .transform(encoding.decoder)
            .transform(const LineSplitter())) {
      lineNumber++;
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        continue;
      }

      late final Object? decoded;
      try {
        decoded = jsonDecode(trimmed);
      } on FormatException catch (error) {
        throw FormatException(
          'Invalid JSON on line $lineNumber of $filePath: ${error.message}',
          trimmed,
        );
      }

      if (decoded is! Map) {
        throw FormatException(
          'Expected JSON object on line $lineNumber of $filePath',
          trimmed,
        );
      }

      final map = Map<String, dynamic>.from(decoded);
      final id = map['id'];
      if (id is! String || id.isEmpty) {
        throw FormatException(
          'Missing or empty "id" on line $lineNumber of $filePath',
          trimmed,
        );
      }

      final contentValue = map.containsKey('content')
          ? map['content']
          : map['text'];
      if (contentValue is! String) {
        throw FormatException(
          'Missing string "content" (or "text") on line $lineNumber of $filePath',
          trimmed,
        );
      }

      final metadata = <String, dynamic>{};
      final nested = map['metadata'];
      if (nested is Map) {
        metadata.addAll(Map<String, dynamic>.from(nested));
      }

      const reserved = {
        'id',
        'content',
        'text',
        'title',
        'language',
        'metadata',
      };
      for (final entry in map.entries) {
        if (!reserved.contains(entry.key)) {
          metadata[entry.key] = entry.value;
        }
      }

      yield DatasetSourceDocument(
        id: id,
        content: contentValue,
        title: map['title'] as String?,
        language: map['language'] as String?,
        metadata: metadata,
      );
    }
  }
}
