import '../variation/dataset_variation_generator.dart';

/// Controls meaning-preserving variation generation during curriculum builds.
class CurriculumVariationOptions {
  /// Creates variation options.
  ///
  /// When [variationsPerEntry] is `null` or `0`, no variations are generated
  /// unless a stage/source manifest field or [generators] override applies.
  const CurriculumVariationOptions({this.variationsPerEntry, this.generators});

  /// Default number of variations per canonical entry for text exercise sources.
  ///
  /// Stage and source manifest fields override this value. Combinatorial phrase
  /// sources skip variations automatically.
  final int? variationsPerEntry;

  /// When set, used instead of auto-resolved generators for every source.
  final List<DatasetVariationGenerator>? generators;
}

/// Resolves the effective variations-per-entry count for a source.
int? resolveCurriculumVariationsPerEntry({
  required CurriculumVariationOptions? builderOptions,
  required int? stageVariationsPerEntry,
  required int? sourceVariationsPerEntry,
  required bool combinatorial,
}) {
  if (combinatorial) {
    return null;
  }
  final resolved =
      sourceVariationsPerEntry ??
      stageVariationsPerEntry ??
      builderOptions?.variationsPerEntry;
  if (resolved == null || resolved <= 0) {
    return null;
  }
  return resolved;
}
