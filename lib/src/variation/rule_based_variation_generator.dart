import '../model/dataset_entry.dart';
import '../model/dataset_provenance.dart';
import '../util/ids.dart';
import 'dataset_variation_generator.dart';

/// Built-in, provider-independent variation generator.
///
/// Applies lightweight deterministic text transforms. Optional [seed] makes
/// multi-strategy ordering reproducible when more than one strategy is used.
class RuleBasedVariationGenerator implements DatasetVariationGenerator {
  /// Creates a variation generator for [strategies].
  RuleBasedVariationGenerator({
    this.strategies = const [
      VariationStrategy.paraphrase,
      VariationStrategy.formal,
      VariationStrategy.casual,
    ],
    this.seed,
    this.generatorVersion = '1.0.0',
    this.startIndex = 1,
  });

  /// Strategies to apply in order (after optional seeded shuffle).
  final List<VariationStrategy> strategies;

  /// Optional seed for deterministic strategy ordering.
  final int? seed;

  /// Version recorded in provenance.
  final String generatorVersion;

  /// First variation index to assign (canonical is typically `0`).
  final int startIndex;

  @override
  Future<List<DatasetEntry>> generate(DatasetEntry entry) async {
    if (strategies.isEmpty) {
      return const [];
    }

    final ordered = seed == null
        ? strategies
        : seededShuffle(List<VariationStrategy>.from(strategies), seed!);

    final results = <DatasetEntry>[];
    var index = startIndex;
    for (final strategy in ordered) {
      results.add(_vary(entry, strategy, index));
      index++;
    }
    return results;
  }

  DatasetEntry _vary(
    DatasetEntry entry,
    VariationStrategy strategy,
    int variationIndex,
  ) {
    final transformed = _apply(entry.input, strategy);
    final output = entry.output == null
        ? null
        : _apply(entry.output!, strategy);

    final id = stableDatasetId([
      entry.variationGroup,
      variationIndex,
      strategy.name,
      seed,
    ]);

    return entry.copyWith(
      id: id,
      input: transformed,
      output: output,
      variationIndex: variationIndex,
      metadata: {...entry.metadata, 'variationStrategy': strategy.name},
      provenance: DatasetProvenance(
        source: entry.provenance?.source,
        sourceId: entry.provenance?.sourceId,
        sourceUri: entry.provenance?.sourceUri,
        generator: 'RuleBasedVariationGenerator',
        generatorVersion: generatorVersion,
        transformation: strategy.name,
        parentEntryId: entry.id,
        pipelineVersion: entry.provenance?.pipelineVersion,
      ),
    );
  }

  String _apply(String text, VariationStrategy strategy) {
    switch (strategy) {
      case VariationStrategy.paraphrase:
        return 'In other words: $text';
      case VariationStrategy.translation:
        return '[translated] $text';
      case VariationStrategy.formal:
        return 'Kindly consider the following: $text';
      case VariationStrategy.casual:
        return 'Hey — $text';
      case VariationStrategy.difficulty:
        return 'Advanced challenge:\n$text';
      case VariationStrategy.format:
        return '• $text';
    }
  }
}
