import 'package:llm_dataset/llm_dataset.dart';
import 'package:test/test.dart';

void main() {
  group('CurriculumStageBuilderRegistry', () {
    final registry = CurriculumStageBuilderRegistry(
      phraseTemplateRootResolver: (path) => path,
    );

    CurriculumStageDefinition stage({
      required String id,
      List<Map<String, dynamic>>? sources,
    }) {
      return CurriculumStageDefinition.fromJson({
        'id': id,
        'order': 0,
        'layersWhenActive': 2,
        'dataset': 'curriculum',
        'datasetVersion': '$id-v1',
        'mixing': {'mode': 'exclusive'},
        'sources':
            sources ??
            [
              {'kind': 'language_basics', 'locale': 'en', 'profile': 'generic'},
            ],
      });
    }

    const baseConfig = GeneratorConfig(
      dataset: 'curriculum',
      datasetVersion: 'base-v1',
      language: 'en',
    );

    test('resolves all built-in source kinds', () async {
      final kinds = [
        ('language_basics', {'kind': 'language_basics', 'locale': 'en'}),
        ('paragraph_catalog', {'kind': 'paragraph_catalog', 'locale': 'en'}),
        ('math_catalog', {'kind': 'math_catalog', 'locale': 'en'}),
        ('logic_catalog', {'kind': 'logic_catalog', 'locale': 'en'}),
        ('coding_catalog', {'kind': 'coding_catalog', 'language': 'python'}),
        (
          'phrase_templates',
          {
            'kind': 'phrase_templates',
            'locale': 'en',
            'storePath': 'example/phrase_templates/en',
          },
        ),
      ];

      for (final (name, sourceJson) in kinds) {
        final plan = await registry.resolve(
          stage: stage(id: name),
          source: CurriculumSourceDefinition.fromJson(sourceJson),
          baseConfig: baseConfig,
        );
        expect(plan.source, isNotNull);
        expect(plan.generator, isNotNull);
        expect(plan.dataset, 'curriculum');
      }
    });

    test('throws for unknown source kind', () async {
      expect(
        () => registry.resolve(
          stage: stage(id: 'bad'),
          source: const CurriculumSourceDefinition(kind: 'unknown_kind'),
          baseConfig: baseConfig,
        ),
        throwsA(isA<CurriculumException>()),
      );
    });

    test('phrase_templates requires storePath', () async {
      expect(
        () => registry.resolve(
          stage: stage(id: 'phrases'),
          source: const CurriculumSourceDefinition(kind: 'phrase_templates'),
          baseConfig: baseConfig,
        ),
        throwsA(isA<CurriculumException>()),
      );
    });

    test('attaches variation generators for text sources', () async {
      final plan = await registry.resolve(
        stage: stage(id: 'paragraphs'),
        source: CurriculumSourceDefinition.fromJson({
          'kind': 'paragraph_catalog',
          'locale': 'en',
        }),
        baseConfig: baseConfig,
        variationOptions: const CurriculumVariationOptions(
          variationsPerEntry: 2,
        ),
      );

      expect(plan.variations, hasLength(1));
      expect(
        plan.variations.single,
        isA<MeaningPreservingVariationGenerator>(),
      );
    });

    test('skips variations for combinatorial phrase_templates', () async {
      final plan = await registry.resolve(
        stage: stage(id: 'phrases'),
        source: CurriculumSourceDefinition.fromJson({
          'kind': 'phrase_templates',
          'locale': 'en',
          'storePath': 'example/phrase_templates/en',
          'combinatorial': true,
        }),
        baseConfig: baseConfig,
        variationOptions: const CurriculumVariationOptions(
          variationsPerEntry: 2,
        ),
      );

      expect(plan.variations, isEmpty);
    });

    test('math and coding sources do not get auto variations', () async {
      for (final kind in ['math_catalog', 'coding_catalog']) {
        final sourceJson = kind == 'coding_catalog'
            ? {'kind': kind, 'language': 'python'}
            : {'kind': kind, 'locale': 'en'};

        final plan = await registry.resolve(
          stage: stage(id: kind),
          source: CurriculumSourceDefinition.fromJson(sourceJson),
          baseConfig: baseConfig,
          variationOptions: const CurriculumVariationOptions(
            variationsPerEntry: 2,
          ),
        );

        expect(plan.variations, isEmpty, reason: kind);
      }
    });
  });
}
