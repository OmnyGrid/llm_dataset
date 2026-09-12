import '../source/dataset_source.dart';

/// Resolves [DatasetSourceDocument.id] against a catalog [patternMap].
mixin CatalogExerciseGenerator<TPattern> {
  /// Patterns keyed by document id.
  Map<String, TPattern> get patternMap;

  /// Returns the pattern for [document] or throws [ArgumentError].
  TPattern requirePattern(DatasetSourceDocument document) {
    final pattern = patternMap[document.id];
    if (pattern == null) {
      throw ArgumentError(
        'Unknown pattern "${document.id}". Known: ${patternMap.keys.join(', ')}',
      );
    }
    return pattern;
  }
}
