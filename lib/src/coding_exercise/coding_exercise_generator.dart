import '../exercise/catalog_exercise_generator.dart';
import '../generator/dataset_generator.dart';
import '../model/exercise_metadata.dart';
import '../generator/generator_helpers.dart';
import '../model/dataset_entry.dart';
import '../model/dataset_entry_type.dart';
import '../source/dataset_source.dart';
import 'coding_exercise_catalog.dart';

/// Builds coding exercise entries from [CodingPatternConfig] definitions.
class CodingExerciseGenerator
    with CatalogExerciseGenerator<CodingPatternConfig>
    implements DatasetGenerator {
  /// Creates a coding generator.
  CodingExerciseGenerator({
    required this.config,
    required this.patterns,
    this.generatorVersion = '1.0.0',
  });

  /// Shared generator configuration.
  final GeneratorConfig config;

  /// Patterns keyed by id.
  final Map<String, CodingPatternConfig> patterns;

  /// Provenance version string.
  final String generatorVersion;

  @override
  Map<String, CodingPatternConfig> get patternMap => patterns;

  @override
  Stream<DatasetEntry> generate(DatasetSourceDocument document) async* {
    final pattern = requirePattern(document);

    yield buildCanonicalEntry(
      config: config,
      document: document,
      generatorName: 'CodingExerciseGenerator',
      type: DatasetEntryType.coding,
      input: pattern.prompt,
      output: pattern.solution,
      extraMetadata: {
        ExerciseMetadataKeys.exerciseKind: pattern.kind.name,
        'codingLanguage': pattern.language,
        ExerciseMetadataKeys.patternId: pattern.id,
        ExerciseMetadataKeys.complexityTier: pattern.complexityTier,
      },
    );
  }
}
