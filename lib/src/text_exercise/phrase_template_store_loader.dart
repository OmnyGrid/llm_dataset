import 'dart:convert';
import 'dart:io';

import 'phrase_template_locale_manifest.dart';
import 'phrase_template_store.dart';
import 'phrase_template_store_codec.dart';
import 'phrase_template_store_exception.dart';

/// Loads [PhraseTemplateStore] datasets from a locale directory on disk.
///
/// Expected layout:
/// ```
/// <localeDirectory>/
///   manifest.json
///   words/*.json
///   templates/*.json
/// ```
class PhraseTemplateStoreLoader {
  /// Creates a loader for [localeDirectory].
  const PhraseTemplateStoreLoader({required this.localeDirectory});

  /// Creates a loader from a filesystem path string.
  factory PhraseTemplateStoreLoader.fromPath(String path) {
    return PhraseTemplateStoreLoader(localeDirectory: Directory(path));
  }

  /// Locale directory containing `manifest.json`.
  final Directory localeDirectory;

  /// Loads and validates the locale dataset from disk.
  Future<PhraseTemplateStore> load() async {
    final manifestFile = File('${localeDirectory.path}/manifest.json');
    if (!manifestFile.existsSync()) {
      throw PhraseTemplateStoreException(
        'Missing manifest.json',
        path: manifestFile.path,
      );
    }

    late final Map<String, dynamic> manifestJson;
    try {
      manifestJson =
          jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>;
    } on FormatException catch (error) {
      throw PhraseTemplateStoreException(
        'Invalid JSON in manifest.json',
        path: manifestFile.path,
        cause: error,
      );
    }

    final manifest = PhraseTemplateLocaleManifest.fromJson(manifestJson);
    final wordSets = <String, Map<String, dynamic>>{};
    final templateGroups = <String, Map<String, dynamic>>{};

    for (final relativePath in manifest.wordSetPaths) {
      wordSets[relativePath] = await _readJson(relativePath);
    }
    for (final relativePath in manifest.templateGroupPaths) {
      templateGroups[relativePath] = await _readJson(relativePath);
    }

    return PhraseTemplateStoreCodec.assemble(
      manifest: manifest,
      wordSetsByPath: wordSets,
      templateGroupsByPath: templateGroups,
      rootDirectory: localeDirectory.path,
    );
  }

  Future<Map<String, dynamic>> _readJson(String relativePath) async {
    PhraseTemplateLocaleManifest.assertSafeRelativePath(relativePath);

    final file = File('${localeDirectory.path}/$relativePath');
    if (!file.existsSync()) {
      throw PhraseTemplateStoreException(
        'Missing file listed in manifest',
        path: file.path,
      );
    }

    try {
      return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    } on FormatException catch (error) {
      throw PhraseTemplateStoreException(
        'Invalid JSON document',
        path: file.path,
        cause: error,
      );
    }
  }
}
