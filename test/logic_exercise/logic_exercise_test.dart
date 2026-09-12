import 'package:llm_dataset/llm_dataset.dart';
import 'package:test/test.dart';

void main() {
  group('LogicExerciseCatalog', () {
    test('includes all pattern kinds', () {
      final catalog = logicExerciseCatalogFor(locale: 'en');
      final kinds = catalog.patterns.map((p) => p.kind).toSet();

      expect(
        kinds,
        containsAll([
          LogicPatternKind.syllogism,
          LogicPatternKind.sequence,
          LogicPatternKind.classification,
          LogicPatternKind.trueFalse,
        ]),
      );
    });
  });

  group('LogicExerciseGenerator', () {
    late LogicExerciseGenerator generator;
    late LogicExerciseCatalog catalog;

    setUp(() {
      catalog = logicExerciseCatalogFor(locale: 'en');
      generator = LogicExerciseGenerator(
        config: const GeneratorConfig(
          dataset: 'curriculum',
          datasetVersion: 'logic-v1',
          language: 'en',
        ),
        patterns: catalog.patternMap(),
        seed: 42,
      );
    });

    test('syllogism emits reasoning with thinking trace', () async {
      final doc = catalog.documents().firstWhere(
        (d) => d.id == 'logic-syllogism-1',
      );
      final entry = await generator.generate(doc).first;

      expect(entry.type, DatasetEntryType.reasoning);
      expect(entry.output, contains('Answer: Whiskers is a mammal.'));
      expect(entry.metadata['exerciseKind'], 'syllogism');
    });

    test('sequence emits reasoning output', () async {
      final doc = catalog.documents().firstWhere(
        (d) => d.id == 'logic-sequence-1',
      );
      final entry = await generator.generate(doc).first;

      expect(entry.metadata['answer'], '10');
      expect(entry.output, contains('10'));
    });

    test('true_false includes explanation', () async {
      final doc = catalog.documents().firstWhere(
        (d) => d.id == 'logic-true-false-1',
      );
      final entry = await generator.generate(doc).first;

      expect(entry.metadata['answer'], 'true');
      expect(entry.type, DatasetEntryType.reasoning);
    });

    test('generates all catalog documents', () async {
      var count = 0;
      for (final doc in catalog.documents()) {
        final entries = await generator.generate(doc).toList();
        expect(entries, hasLength(1));
        count++;
      }
      expect(count, catalog.documents().length);
    });
  });
}
