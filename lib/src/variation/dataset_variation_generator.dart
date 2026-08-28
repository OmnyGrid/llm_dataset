import '../model/dataset_entry.dart';
import 'variation_generate_options.dart';

/// Produces variation entries linked to a canonical (or parent) entry.
///
/// Implementations must preserve [DatasetEntry.variationGroup], set a unique
/// [DatasetEntry.variationIndex], and reference the parent through provenance.
/// Do not couple variations to a specific LLM provider.
abstract interface class DatasetVariationGenerator {
  /// Generates zero or more variations of [entry].
  ///
  /// [options] is supplied by [DatasetPipeline] to assign unique indexes and
  /// instance ids across multiple generators.
  Future<List<DatasetEntry>> generate(
    DatasetEntry entry, {
    VariationGenerateOptions options = defaultVariationGenerateOptions,
  });
}

/// Named variation strategies supported by built-in generators.
enum VariationStrategy {
  /// Paraphrase the input (and output when present).
  paraphrase,

  /// Translate-style rewrite markers (no external MT).
  translation,

  /// More formal wording.
  formal,

  /// More casual wording.
  casual,

  /// Adjust perceived difficulty via prompt framing.
  difficulty,

  /// Change surface format (e.g. bullet vs paragraph framing).
  format,
}
