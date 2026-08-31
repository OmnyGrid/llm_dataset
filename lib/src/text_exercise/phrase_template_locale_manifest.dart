import 'phrase_template_store_exception.dart';

/// Index manifest for a locale directory under a phrase template store.
///
/// Typically loaded from `manifest.json` and listing relative paths to word-set
/// and template-group JSON files.
class PhraseTemplateLocaleManifest {
  /// Creates a manifest.
  const PhraseTemplateLocaleManifest({
    required this.language,
    required this.version,
    required this.description,
    required this.wordSetPaths,
    required this.templateGroupPaths,
  });

  /// Parses [json] from a locale `manifest.json` file.
  factory PhraseTemplateLocaleManifest.fromJson(Map<String, dynamic> json) {
    final language = json['language'];
    if (language is! String || language.isEmpty) {
      throw PhraseTemplateStoreException(
        'manifest.language must be a non-empty string',
        field: 'language',
      );
    }

    return PhraseTemplateLocaleManifest(
      language: language,
      version: json['version'] as String? ?? '1.0.0',
      description: json['description'] as String? ?? '',
      wordSetPaths: _readPathList(json['wordSets'], field: 'wordSets'),
      templateGroupPaths: _readPathList(
        json['templateGroups'],
        field: 'templateGroups',
      ),
    );
  }

  /// Language code (`en`, `pt`, …).
  final String language;

  /// Dataset version string.
  final String version;

  /// Human-readable description.
  final String description;

  /// Relative paths to word-set JSON files.
  final List<String> wordSetPaths;

  /// Relative paths to template-group JSON files.
  final List<String> templateGroupPaths;

  /// Serializes this manifest to JSON.
  Map<String, dynamic> toJson() {
    return {
      'language': language,
      'version': version,
      'description': description,
      'wordSets': wordSetPaths,
      'templateGroups': templateGroupPaths,
    };
  }

  static List<String> _readPathList(Object? value, {required String field}) {
    if (value is! List) {
      throw PhraseTemplateStoreException(
        'Expected JSON array for manifest.$field',
        field: field,
      );
    }
    return value.map((item) {
      if (item is! String || item.isEmpty) {
        throw PhraseTemplateStoreException(
          'Expected non-empty path strings in manifest.$field',
          field: field,
        );
      }
      _assertSafeRelativePath(item, field: field);
      return item;
    }).toList();
  }

  /// Validates that [path] is a safe manifest-relative path.
  static void assertSafeRelativePath(String path, {String? field}) {
    _assertSafeRelativePath(path, field: field ?? 'path');
  }

  static void _assertSafeRelativePath(String path, {required String field}) {
    if (path.startsWith('/') || path.contains('..')) {
      throw PhraseTemplateStoreException(
        'Unsafe relative path "$path" in manifest.$field',
        field: field,
      );
    }
  }
}
