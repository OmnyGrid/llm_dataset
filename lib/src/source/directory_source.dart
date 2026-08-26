import 'dart:convert';
import 'dart:io';

import 'dataset_source.dart';

/// Streams text files from a directory as [DatasetSourceDocument]s.
///
/// Does not load the entire directory contents into memory: files are listed
/// and each file is read when yielded.
class DirectorySource implements DatasetSource {
  /// Creates a directory source.
  ///
  /// When [extensions] is non-null and non-empty, only files whose lowercase
  /// extension is in the set are included (e.g. `{'.txt', '.md'}`).
  ///
  /// When [recursive] is true, subdirectories are walked.
  DirectorySource(
    this.directoryPath, {
    this.extensions,
    this.recursive = false,
    this.encoding = utf8,
  });

  /// Root directory path.
  final String directoryPath;

  /// Optional allowed file extensions including the leading dot.
  final Set<String>? extensions;

  /// Whether to recurse into subdirectories.
  final bool recursive;

  /// Text encoding used when reading files.
  final Encoding encoding;

  @override
  Stream<DatasetSourceDocument> load() async* {
    final root = Directory(directoryPath);
    if (!await root.exists()) {
      throw FileSystemException('Directory does not exist', directoryPath);
    }

    final rootPath = root.absolute.path;
    final normalizedRoot = rootPath.endsWith(Platform.pathSeparator)
        ? rootPath
        : '$rootPath${Platform.pathSeparator}';

    final entities = root.list(recursive: recursive, followLinks: false);

    await for (final entity in entities) {
      if (entity is! File) {
        continue;
      }
      final filePath = entity.path;
      final ext = _extension(filePath).toLowerCase();
      if (extensions != null &&
          extensions!.isNotEmpty &&
          !extensions!.contains(ext)) {
        continue;
      }

      final absoluteFile = entity.absolute.path;
      final relative = absoluteFile.startsWith(normalizedRoot)
          ? absoluteFile.substring(normalizedRoot.length)
          : absoluteFile;
      final content = await entity.readAsString(encoding: encoding);
      yield DatasetSourceDocument(
        id: relative,
        content: content,
        title: _basename(filePath),
        metadata: <String, dynamic>{
          'path': absoluteFile,
          'relativePath': relative,
        },
      );
    }
  }
}

String _basename(String path) {
  final normalized = path.replaceAll('\\', '/');
  final index = normalized.lastIndexOf('/');
  return index < 0 ? normalized : normalized.substring(index + 1);
}

String _extension(String path) {
  final name = _basename(path);
  final index = name.lastIndexOf('.');
  if (index <= 0) {
    return '';
  }
  return name.substring(index);
}
