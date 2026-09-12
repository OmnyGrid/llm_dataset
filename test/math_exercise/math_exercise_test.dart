import 'package:llm_dataset/llm_dataset.dart';
import 'package:test/test.dart';

void main() {
  group('MathExerciseCatalog', () {
    test('documents cover all pattern kinds', () {
      final catalog = mathExerciseCatalogFor(locale: 'en');
      final kinds = catalog.patterns.map((p) => p.kind).toSet();

      expect(
        kinds,
        containsAll([
          MathPatternKind.arithmetic,
          MathPatternKind.wordProblem,
          MathPatternKind.stepSolution,
        ]),
      );
      expect(catalog.documents(), hasLength(catalog.patterns.length));
    });

    test('rejects unsupported locale', () {
      expect(
        () => mathExerciseCatalogFor(locale: 'fr'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('MathExerciseGenerator', () {
    late MathExerciseGenerator generator;
    late MathExerciseCatalog catalog;

    setUp(() {
      catalog = mathExerciseCatalogFor(locale: 'en');
      generator = MathExerciseGenerator(
        config: const GeneratorConfig(
          dataset: 'curriculum',
          datasetVersion: 'math-v1',
          language: 'en',
        ),
        patterns: catalog.patternMap(),
      );
    });

    test('evaluates arithmetic correctly', () {
      expect(evaluateMathOperands(2, 3, '+'), 5);
      expect(evaluateMathOperands(8, 3, '-'), 5);
      expect(evaluateMathOperands(4, 5, '*'), 20);
      expect(evaluateMathOperands(10, 2, '/'), 5);
    });

    test('division by zero throws', () {
      expect(() => evaluateMathOperands(1, 0, '/'), throwsArgumentError);
    });

    test('unsupported operator throws', () {
      expect(() => evaluateMathOperands(1, 2, '%'), throwsArgumentError);
    });

    test('generates text type for arithmetic and word problems', () async {
      for (final id in ['math-arith-add-1', 'math-word-add-1']) {
        final doc = catalog.documents().firstWhere((d) => d.id == id);
        final entry = await generator.generate(doc).first;
        expect(entry.type, DatasetEntryType.text);
        expect(entry.output, isNotEmpty);
      }
    });

    test('step solution emits reasoning type with steps', () async {
      final doc = catalog.documents().firstWhere(
        (d) => d.id == 'math-step-add-1',
      );
      final entry = await generator.generate(doc).first;

      expect(entry.type, DatasetEntryType.reasoning);
      expect(entry.output, contains('Step 1:'));
      expect(entry.output, contains('Answer: 10'));
      expect(entry.metadata['result'], 10);
    });

    test('unknown pattern id throws', () {
      expect(
        generator.generate(DatasetSourceDocument(id: 'missing', content: 'x')),
        emitsError(isA<ArgumentError>()),
      );
    });
  });
}
