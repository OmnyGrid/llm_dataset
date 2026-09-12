import '../generator/dataset_generator.dart';
import '../generator/generator_helpers.dart';
import '../model/dataset_entry.dart';
import '../model/dataset_entry_type.dart';
import '../source/dataset_source.dart';
import 'math_exercise_catalog.dart';

/// Builds math exercise entries from [MathPatternConfig] definitions.
class MathExerciseGenerator implements DatasetGenerator {
  /// Creates a math generator.
  MathExerciseGenerator({
    required this.config,
    required this.patterns,
    this.generatorVersion = '1.0.0',
  });

  /// Shared generator configuration.
  final GeneratorConfig config;

  /// Patterns keyed by id.
  final Map<String, MathPatternConfig> patterns;

  /// Provenance version string.
  final String generatorVersion;

  @override
  Stream<DatasetEntry> generate(DatasetSourceDocument document) async* {
    final pattern = patterns[document.id];
    if (pattern == null) {
      throw ArgumentError(
        'Unknown math pattern "${document.id}". '
        'Known: ${patterns.keys.join(', ')}',
      );
    }

    final a = pattern.operands[0];
    final b = pattern.operands[1];
    final result = evaluateMathOperands(a, b, pattern.operatorSymbol);
    final prompt = pattern.template
        .replaceAll('{a}', '$a')
        .replaceAll('{b}', '$b')
        .replaceAll('{op}', pattern.operatorSymbol);

    final output = switch (pattern.kind) {
      MathPatternKind.stepSolution =>
        'Step 1: Start with $a.\n'
            'Step 2: Apply ${pattern.operatorSymbol} $b.\n'
            'Answer: $result',
      _ => '$result',
    };

    final type = pattern.kind == MathPatternKind.stepSolution
        ? DatasetEntryType.reasoning
        : DatasetEntryType.text;

    yield buildCanonicalEntry(
      config: config,
      document: document,
      generatorName: 'MathExerciseGenerator',
      type: type,
      input: prompt,
      output: output,
      extraMetadata: {
        'exerciseKind': pattern.kind.name,
        'patternId': pattern.id,
        'operandA': a,
        'operandB': b,
        'operator': pattern.operatorSymbol,
        'result': result,
        'complexityTier': pattern.complexityTier,
      },
    );
  }
}
