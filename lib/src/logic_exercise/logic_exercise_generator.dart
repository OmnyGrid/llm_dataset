import '../generator/dataset_generator.dart';
import '../generator/generator_helpers.dart';
import '../model/dataset_entry.dart';
import '../model/dataset_entry_type.dart';
import '../source/dataset_source.dart';
import 'logic_exercise_catalog.dart';

/// Builds logic exercise entries from [LogicPatternConfig] definitions.
class LogicExerciseGenerator implements DatasetGenerator {
  /// Creates a logic generator.
  LogicExerciseGenerator({
    required this.config,
    required this.patterns,
    this.seed = 0,
    this.generatorVersion = '1.0.0',
  });

  /// Shared generator configuration.
  final GeneratorConfig config;

  /// Patterns keyed by id.
  final Map<String, LogicPatternConfig> patterns;

  /// Seed for deterministic variant selection (reserved for expansion).
  final int seed;

  /// Provenance version string.
  final String generatorVersion;

  @override
  Stream<DatasetEntry> generate(DatasetSourceDocument document) async* {
    final pattern = patterns[document.id];
    if (pattern == null) {
      throw ArgumentError(
        'Unknown logic pattern "${document.id}". '
        'Known: ${patterns.keys.join(', ')}',
      );
    }

    final hasThinking =
        pattern.thinking != null && pattern.thinking!.isNotEmpty;
    final output = hasThinking
        ? '${pattern.thinking}\nAnswer: ${pattern.answer}'
        : pattern.answer;

    yield buildCanonicalEntry(
      config: config,
      document: document,
      generatorName: 'LogicExerciseGenerator',
      type: hasThinking ? DatasetEntryType.reasoning : DatasetEntryType.text,
      input: pattern.prompt,
      output: output,
      extraMetadata: {
        'exerciseKind': pattern.kind.name,
        'patternId': pattern.id,
        'answer': pattern.answer,
        'complexityTier': pattern.complexityTier,
        'seed': seed,
      },
    );
  }
}
