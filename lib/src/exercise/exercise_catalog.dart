import '../source/dataset_source.dart';

/// Shared catalog contract for built-in exercise modules.
abstract interface class ExerciseCatalog<TPattern> {
  /// Source documents for pipeline consumption.
  List<DatasetSourceDocument> documents();

  /// Patterns keyed by document id.
  Map<String, TPattern> patternMap();
}
