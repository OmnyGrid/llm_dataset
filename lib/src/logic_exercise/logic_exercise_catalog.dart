import '../source/dataset_source.dart';

/// Kind of logic exercise pattern.
enum LogicPatternKind {
  /// Classic syllogism with conclusion.
  syllogism,

  /// Numeric or lexical sequence continuation.
  sequence,

  /// Pick the odd one out / classify.
  classification,

  /// True or false statement evaluation.
  trueFalse,
}

/// Configuration for one logic exercise pattern.
class LogicPatternConfig {
  /// Creates a logic pattern.
  const LogicPatternConfig({
    required this.id,
    required this.kind,
    required this.prompt,
    required this.answer,
    this.thinking,
    this.complexityTier = 0,
  });

  /// Stable pattern id.
  final String id;

  /// Pattern kind.
  final LogicPatternKind kind;

  /// Question or scenario text.
  final String prompt;

  /// Expected answer.
  final String answer;

  /// Optional chain-of-thought explanation.
  final String? thinking;

  /// Difficulty tier within the logic stage.
  final int complexityTier;
}

/// Catalog of built-in logic exercises.
class LogicExerciseCatalog {
  /// Creates a catalog.
  const LogicExerciseCatalog({required this.patterns, required this.language});

  /// Pattern definitions.
  final List<LogicPatternConfig> patterns;

  /// Language code for documents.
  final String language;

  /// Source documents for the pipeline.
  List<DatasetSourceDocument> documents() {
    return [
      for (final pattern in patterns)
        DatasetSourceDocument(
          id: pattern.id,
          content: pattern.prompt,
          title: pattern.id,
          language: language,
          metadata: {
            'exerciseKind': pattern.kind.name,
            'patternId': pattern.id,
            'complexityTier': pattern.complexityTier,
          },
        ),
    ];
  }

  /// Patterns keyed by id.
  Map<String, LogicPatternConfig> patternMap() {
    return {for (final pattern in patterns) pattern.id: pattern};
  }
}

const _englishLogicPatterns = [
  LogicPatternConfig(
    id: 'logic-syllogism-1',
    kind: LogicPatternKind.syllogism,
    prompt: 'All cats are mammals. Whiskers is a cat. What can we conclude about Whiskers?',
    answer: 'Whiskers is a mammal.',
    thinking:
        'Premise 1: cats ⊆ mammals. Premise 2: Whiskers ∈ cats. '
        'Therefore Whiskers ∈ mammals.',
    complexityTier: 0,
  ),
  LogicPatternConfig(
    id: 'logic-sequence-1',
    kind: LogicPatternKind.sequence,
    prompt: 'Continue the sequence: 2, 4, 6, 8, ?',
    answer: '10',
    thinking: 'Each term increases by 2.',
    complexityTier: 0,
  ),
  LogicPatternConfig(
    id: 'logic-classification-1',
    kind: LogicPatternKind.classification,
    prompt: 'Which item does not belong: apple, banana, carrot, grape?',
    answer: 'carrot',
    thinking: 'Apple, banana, and grape are fruits; carrot is a vegetable.',
    complexityTier: 1,
  ),
  LogicPatternConfig(
    id: 'logic-true-false-1',
    kind: LogicPatternKind.trueFalse,
    prompt: 'True or false: Every square is a rectangle.',
    answer: 'true',
    thinking:
        'A square has four right angles and opposite sides equal, '
        'which satisfies the definition of a rectangle.',
    complexityTier: 1,
  ),
];

/// Returns the logic catalog for [locale].
LogicExerciseCatalog logicExerciseCatalogFor({required String locale}) {
  if (locale != 'en') {
    throw ArgumentError('logic_catalog currently supports locale "en" only');
  }
  return const LogicExerciseCatalog(
    language: 'en',
    patterns: _englishLogicPatterns,
  );
}
