import '../model/dataset_entry.dart';

/// Produces variation entries linked to a canonical (or parent) entry.
///
/// Implementations must preserve [DatasetEntry.variationGroup], set a unique
/// [DatasetEntry.variationIndex], and reference the parent through provenance.
/// Do not couple variations to a specific LLM provider.
abstract interface class DatasetVariationGenerator {
  /// Generates zero or more variations of [entry].
  ///
  /// The API returns a [Future] list for simplicity. Streaming variation
  /// generators can be added later without changing this contract by wrapping
  /// results in a stream at the call site.
  Future<List<DatasetEntry>> generate(DatasetEntry entry);
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
