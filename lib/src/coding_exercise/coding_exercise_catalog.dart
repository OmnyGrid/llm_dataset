import '../exercise/exercise_catalog.dart';
import '../model/exercise_metadata.dart';
import '../source/dataset_source.dart';

/// Kind of coding exercise pattern.
enum CodingPatternKind {
  /// Fill in missing function body.
  completeFunction,

  /// Fix a bug in a snippet.
  fixBug,

  /// Predict program output.
  predictOutput,

  /// Trace variable values through execution.
  trace,
}

/// Configuration for one coding exercise pattern.
class CodingPatternConfig {
  /// Creates a coding pattern.
  const CodingPatternConfig({
    required this.id,
    required this.kind,
    required this.language,
    required this.prompt,
    required this.solution,
    this.complexityTier = 0,
  });

  /// Stable pattern id.
  final String id;

  /// Pattern kind.
  final CodingPatternKind kind;

  /// Programming language tag.
  final String language;

  /// Input prompt (code + instruction).
  final String prompt;

  /// Expected solution or output.
  final String solution;

  /// Difficulty tier within the coding stage.
  final int complexityTier;
}

/// Catalog of built-in coding exercises.
class CodingExerciseCatalog implements ExerciseCatalog<CodingPatternConfig> {
  /// Creates a catalog.
  const CodingExerciseCatalog({required this.patterns, required this.language});

  /// Pattern definitions.
  final List<CodingPatternConfig> patterns;

  /// Primary language tag for documents.
  final String language;

  /// Source documents for the pipeline.
  @override
  List<DatasetSourceDocument> documents() {
    return [
      for (final pattern in patterns)
        DatasetSourceDocument(
          id: pattern.id,
          content: pattern.prompt,
          title: pattern.id,
          language: 'en',
          metadata: {
            ExerciseMetadataKeys.exerciseKind: pattern.kind.name,
            'codingLanguage': pattern.language,
            ExerciseMetadataKeys.patternId: pattern.id,
            ExerciseMetadataKeys.complexityTier: pattern.complexityTier,
          },
        ),
    ];
  }

  /// Patterns keyed by id.
  @override
  Map<String, CodingPatternConfig> patternMap() {
    return {for (final pattern in patterns) pattern.id: pattern};
  }
}

const _pythonPatterns = [
  CodingPatternConfig(
    id: 'code-py-complete-1',
    kind: CodingPatternKind.completeFunction,
    language: 'python',
    prompt:
        'Complete the function so it returns the sum of a and b:\n'
        'def add(a, b):\n    # your code here',
    solution: 'def add(a, b):\n    return a + b',
    complexityTier: 0,
  ),
  CodingPatternConfig(
    id: 'code-py-fix-1',
    kind: CodingPatternKind.fixBug,
    language: 'python',
    prompt:
        'Fix the bug:\n'
        'def greet(name):\n    return "Hello, " + name.upper()',
    solution: 'def greet(name):\n    return "Hello, " + name',
    complexityTier: 1,
  ),
  CodingPatternConfig(
    id: 'code-py-predict-1',
    kind: CodingPatternKind.predictOutput,
    language: 'python',
    prompt: 'What does this print?\nfor i in range(3):\n    print(i)',
    solution: '0\n1\n2',
    complexityTier: 0,
  ),
  CodingPatternConfig(
    id: 'code-py-trace-1',
    kind: CodingPatternKind.trace,
    language: 'python',
    prompt:
        'Trace x after each line:\n'
        'x = 1\n'
        'x = x + 2\n'
        'x = x * 3',
    solution: 'After line 1: x=1\nAfter line 2: x=3\nAfter line 3: x=9',
    complexityTier: 1,
  ),
];

const _dartPatterns = [
  CodingPatternConfig(
    id: 'code-dart-complete-1',
    kind: CodingPatternKind.completeFunction,
    language: 'dart',
    prompt:
        'Complete the function:\n'
        'int doubleIt(int n) {\n  // your code here\n}',
    solution: 'int doubleIt(int n) {\n  return n * 2;\n}',
    complexityTier: 0,
  ),
];

/// Returns the coding catalog for [language].
CodingExerciseCatalog codingExerciseCatalogFor({required String language}) {
  switch (language) {
    case 'python':
      return const CodingExerciseCatalog(
        language: 'python',
        patterns: _pythonPatterns,
      );
    case 'dart':
      return const CodingExerciseCatalog(
        language: 'dart',
        patterns: _dartPatterns,
      );
    default:
      throw ArgumentError('Unknown coding catalog language "$language"');
  }
}
