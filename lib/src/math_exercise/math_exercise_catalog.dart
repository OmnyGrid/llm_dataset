import '../exercise/exercise_catalog.dart';
import '../model/exercise_metadata.dart';
import '../source/dataset_source.dart';

/// Kind of math exercise pattern.
enum MathPatternKind {
  /// Numeric expression evaluation.
  arithmetic,

  /// Short word problem with numeric answer.
  wordProblem,

  /// Step-by-step solution with reasoning trace.
  stepSolution,
}

/// Configuration for one math exercise pattern.
class MathPatternConfig {
  /// Creates a math pattern.
  const MathPatternConfig({
    required this.id,
    required this.kind,
    required this.template,
    required this.operands,
    required this.operatorSymbol,
    this.complexityTier = 0,
  });

  /// Stable pattern id.
  final String id;

  /// Pattern kind.
  final MathPatternKind kind;

  /// Prompt template with `{a}`, `{b}`, `{op}` placeholders.
  final String template;

  /// Operand values used when generating this pattern.
  final List<int> operands;

  /// Operator symbol (`+`, `-`, `*`, `/`).
  final String operatorSymbol;

  /// Difficulty tier within the math stage.
  final int complexityTier;
}

/// Catalog of built-in math exercises.
class MathExerciseCatalog implements ExerciseCatalog<MathPatternConfig> {
  /// Creates a catalog.
  const MathExerciseCatalog({required this.patterns, required this.language});

  /// Pattern definitions.
  final List<MathPatternConfig> patterns;

  /// Language code for documents.
  final String language;

  /// Source documents for the pipeline.
  @override
  List<DatasetSourceDocument> documents() {
    return [
      for (final pattern in patterns)
        DatasetSourceDocument(
          id: pattern.id,
          content: pattern.template,
          title: pattern.id,
          language: language,
          metadata: {
            ExerciseMetadataKeys.exerciseKind: pattern.kind.name,
            ExerciseMetadataKeys.patternId: pattern.id,
            ExerciseMetadataKeys.complexityTier: pattern.complexityTier,
          },
        ),
    ];
  }

  /// Patterns keyed by id.
  @override
  Map<String, MathPatternConfig> patternMap() {
    return {for (final pattern in patterns) pattern.id: pattern};
  }
}

const _englishMathPatterns = [
  MathPatternConfig(
    id: 'math-arith-add-1',
    kind: MathPatternKind.arithmetic,
    template: 'What is {a} {op} {b}?',
    operands: [2, 3],
    operatorSymbol: '+',
    complexityTier: 0,
  ),
  MathPatternConfig(
    id: 'math-arith-sub-1',
    kind: MathPatternKind.arithmetic,
    template: 'What is {a} {op} {b}?',
    operands: [8, 3],
    operatorSymbol: '-',
    complexityTier: 0,
  ),
  MathPatternConfig(
    id: 'math-arith-mul-1',
    kind: MathPatternKind.arithmetic,
    template: 'What is {a} {op} {b}?',
    operands: [4, 5],
    operatorSymbol: '*',
    complexityTier: 1,
  ),
  MathPatternConfig(
    id: 'math-word-add-1',
    kind: MathPatternKind.wordProblem,
    template:
        'Anna has {a} apples and gets {b} more. How many apples does she have?',
    operands: [3, 2],
    operatorSymbol: '+',
    complexityTier: 1,
  ),
  MathPatternConfig(
    id: 'math-step-add-1',
    kind: MathPatternKind.stepSolution,
    template: 'Solve step by step: {a} {op} {b}',
    operands: [6, 4],
    operatorSymbol: '+',
    complexityTier: 2,
  ),
];

/// Returns the math catalog for [locale].
MathExerciseCatalog mathExerciseCatalogFor({required String locale}) {
  if (locale != 'en') {
    throw ArgumentError('math_catalog currently supports locale "en" only');
  }
  return const MathExerciseCatalog(
    language: 'en',
    patterns: _englishMathPatterns,
  );
}

/// Evaluates [a] [operatorSymbol] [b].
int evaluateMathOperands(int a, int b, String operatorSymbol) {
  switch (operatorSymbol) {
    case '+':
      return a + b;
    case '-':
      return a - b;
    case '*':
      return a * b;
    case '/':
      if (b == 0) {
        throw ArgumentError('Division by zero');
      }
      return a ~/ b;
    default:
      throw ArgumentError('Unsupported operator "$operatorSymbol"');
  }
}
