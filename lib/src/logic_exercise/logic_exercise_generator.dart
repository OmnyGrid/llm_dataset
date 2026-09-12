import '../exercise/catalog_exercise_generator.dart';
import '../generator/dataset_generator.dart';
import '../model/exercise_metadata.dart';
import '../generator/generator_helpers.dart';
import '../model/dataset_entry.dart';
import '../model/dataset_entry_type.dart';
import '../source/dataset_source.dart';
import 'logic_exercise_catalog.dart';

/// Builds logic exercise entries from [LogicPatternConfig] definitions.
class LogicExerciseGenerator
    with CatalogExerciseGenerator<LogicPatternConfig>
    implements DatasetGenerator {
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
  Map<String, LogicPatternConfig> get patternMap => patterns;

  @override
  Stream<DatasetEntry> generate(DatasetSourceDocument document) async* {
    final pattern = requirePattern(document);

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
        ExerciseMetadataKeys.exerciseKind: pattern.kind.name,
        ExerciseMetadataKeys.patternId: pattern.id,
        'answer': pattern.answer,
        ExerciseMetadataKeys.complexityTier: pattern.complexityTier,
        'seed': seed,
      },
    );
  }
}
