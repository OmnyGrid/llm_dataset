import '../model/dataset_entry.dart';
import '../source/dataset_source.dart';

/// Produces canonical [DatasetEntry] values from a source document.
///
/// Implementations must not depend on a particular LLM provider. LLM-backed
/// generation can be supplied by user adapters outside this package.
abstract interface class DatasetGenerator {
  /// Generates zero or more canonical entries for [document].
  Stream<DatasetEntry> generate(DatasetSourceDocument document);
}

/// Shared configuration for built-in generators.
class GeneratorConfig {
  /// Creates generator configuration.
  const GeneratorConfig({
    required this.dataset,
    this.datasetVersion,
    this.language = 'en',
    this.pipelineVersion,
    this.generatorVersion = '1.0.0',
    this.seed,
  });

  /// Target dataset name written on every entry.
  final String dataset;

  /// Optional dataset version.
  final String? datasetVersion;

  /// Default language when the document does not provide one.
  final String language;

  /// Optional pipeline version recorded in provenance.
  final String? pipelineVersion;

  /// Generator version recorded in provenance.
  final String generatorVersion;

  /// Optional seed for deterministic generators that use randomness.
  final int? seed;
}
