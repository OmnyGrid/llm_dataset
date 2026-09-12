import '../generator/dataset_generator.dart';
import '../generator/generator_helpers.dart';
import '../model/dataset_entry.dart';
import '../model/dataset_entry_type.dart';
import '../source/dataset_source.dart';
import 'coding_exercise_catalog.dart';

/// Builds coding exercise entries from [CodingPatternConfig] definitions.
class CodingExerciseGenerator implements DatasetGenerator {
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
  Stream<DatasetEntry> generate(DatasetSourceDocument document) async* {
    final pattern = patterns[document.id];
    if (pattern == null) {
      throw ArgumentError(
        'Unknown coding pattern "${document.id}". '
        'Known: ${patterns.keys.join(', ')}',
      );
    }

    yield buildCanonicalEntry(
      config: config,
      document: document,
      generatorName: 'CodingExerciseGenerator',
      type: DatasetEntryType.coding,
      input: pattern.prompt,
      output: pattern.solution,
      extraMetadata: {
        'exerciseKind': pattern.kind.name,
        'codingLanguage': pattern.language,
        'patternId': pattern.id,
        'complexityTier': pattern.complexityTier,
      },
    );
  }
}
