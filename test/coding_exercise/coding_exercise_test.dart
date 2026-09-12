import 'package:llm_dataset/llm_dataset.dart';
import 'package:test/test.dart';

void main() {
  group('CodingExerciseCatalog', () {
    test('python catalog includes all pattern kinds', () {
      final catalog = codingExerciseCatalogFor(language: 'python');
      final kinds = catalog.patterns.map((p) => p.kind).toSet();

      expect(
        kinds,
        containsAll([
          CodingPatternKind.completeFunction,
          CodingPatternKind.fixBug,
          CodingPatternKind.predictOutput,
          CodingPatternKind.trace,
        ]),
      );
    });

    test('dart catalog is available', () {
      final catalog = codingExerciseCatalogFor(language: 'dart');
      expect(catalog.patterns, isNotEmpty);
      expect(catalog.patterns.first.language, 'dart');
    });

    test('rejects unknown language', () {
      expect(
        () => codingExerciseCatalogFor(language: 'rust'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('CodingExerciseGenerator', () {
    test('emits coding type entries for python', () async {
      final catalog = codingExerciseCatalogFor(language: 'python');
      final generator = CodingExerciseGenerator(
        config: const GeneratorConfig(
          dataset: 'curriculum',
          datasetVersion: 'coding-v1',
          language: 'en',
        ),
        patterns: catalog.patternMap(),
      );

      for (final doc in catalog.documents()) {
        final entry = await generator.generate(doc).first;
        expect(entry.type, DatasetEntryType.coding);
        expect(entry.metadata['codingLanguage'], 'python');
        expect(entry.output, isNotEmpty);
      }
    });

    test('predict_output solution preserves newlines', () async {
      final catalog = codingExerciseCatalogFor(language: 'python');
      final generator = CodingExerciseGenerator(
        config: const GeneratorConfig(
          dataset: 'curriculum',
          datasetVersion: 'coding-v1',
          language: 'en',
        ),
        patterns: catalog.patternMap(),
      );

      final doc = catalog.documents().firstWhere(
        (d) => d.id == 'code-py-predict-1',
      );
      final entry = await generator.generate(doc).first;
      expect(entry.output, '0\n1\n2');
    });
  });
}
