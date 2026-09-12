import 'dart:convert';
import 'dart:io';

import 'package:llm_dataset/llm_dataset.dart';
import 'package:test/test.dart';

void main() {
  group('CurriculumManifest', () {
    test('parses valid manifest', () {
      final manifest = CurriculumManifest.fromJson({
        'id': 'test-v1',
        'initialLayers': 2,
        'stages': [
          {
            'id': 'language_basics',
            'order': 0,
            'layersWhenActive': 2,
            'dataset': 'curriculum',
            'datasetVersion': 'lb-v1',
            'mixing': {'mode': 'exclusive'},
            'sources': [
              {'kind': 'language_basics', 'locale': 'en', 'profile': 'generic'},
            ],
          },
        ],
      });

      expect(manifest.id, 'test-v1');
      expect(manifest.stages, hasLength(1));
      expect(manifest.stages.first.mixing.isExclusive, isTrue);
    });

    test('rejects invalid mixing ratio', () {
      expect(
        () => CurriculumManifest.fromJson({
          'id': 'x',
          'initialLayers': 2,
          'stages': [
            {
              'id': 's',
              'order': 0,
              'layersWhenActive': 2,
              'dataset': 'd',
              'datasetVersion': 'v',
              'mixing': {
                'mode': 'mixed',
                'reviewStages': ['a'],
                'reviewRatio': 1.5,
              },
              'sources': [
                {'kind': 'language_basics'},
              ],
            },
          ],
        }),
        throwsA(isA<CurriculumException>()),
      );
    });

    test('rejects unknown duplicate stage ids', () {
      expect(
        () => CurriculumManifest.fromJson({
          'id': 'x',
          'initialLayers': 2,
          'stages': [
            {
              'id': 'dup',
              'order': 0,
              'layersWhenActive': 2,
              'dataset': 'd',
              'datasetVersion': 'v1',
              'mixing': {'mode': 'exclusive'},
              'sources': [
                {'kind': 'language_basics'},
              ],
            },
            {
              'id': 'dup',
              'order': 1,
              'layersWhenActive': 4,
              'dataset': 'd',
              'datasetVersion': 'v2',
              'mixing': {'mode': 'exclusive'},
              'sources': [
                {'kind': 'language_basics'},
              ],
            },
          ],
        }),
        throwsA(isA<CurriculumException>()),
      );
    });
  });

  group('CurriculumBuilder integration', () {
    late MemoryDatasetStore store;
    late CurriculumManifest manifest;

    setUp(() {
      store = MemoryDatasetStore();
      manifest = CurriculumManifest.fromJson({
        'id': 'integration-v1',
        'initialLayers': 2,
        'stages': [
          {
            'id': 'language_basics',
            'order': 0,
            'layersWhenActive': 2,
            'dataset': 'curriculum',
            'datasetVersion': 'language_basics-v1',
            'mixing': {'mode': 'exclusive'},
            'sources': [
              {'kind': 'language_basics', 'locale': 'en', 'profile': 'generic'},
            ],
          },
          {
            'id': 'phrases',
            'order': 1,
            'layersWhenActive': 4,
            'dataset': 'curriculum',
            'datasetVersion': 'phrases-v1',
            'mixing': {
              'mode': 'mixed',
              'reviewStages': ['language_basics'],
              'reviewRatio': 0.15,
            },
            'sources': [
              {
                'kind': 'phrase_templates',
                'locale': 'en',
                'storePath': 'example/phrase_templates/en',
              },
            ],
          },
        ],
      });
    });

    test('builds language_basics and phrases with curriculum tags', () async {
      final builder = CurriculumBuilder(
        manifest: manifest,
        store: store,
        registry: CurriculumStageBuilderRegistry(
          phraseTemplateRootResolver: (path) => path,
        ),
      );

      await builder.buildStage('language_basics');
      await builder.buildStage('phrases');

      final lifecycle = CurriculumLifecycle(store: store, manifest: manifest);
      expect(
        await lifecycle.listStages(),
        containsAll(['language_basics', 'phrases']),
      );
      expect(await lifecycle.countStage('language_basics'), 4);
      expect(await lifecycle.countStage('phrases'), greaterThan(0));

      final exclusive = CurriculumDataset(
        store: store,
        manifest: manifest,
      ).exclusive('language_basics');
      final basics = await exclusive.stream().toList();
      expect(
        basics,
        everyElement(
          predicate<DatasetEntry>(
            (e) =>
                e.metadata[CurriculumMetadataKeys.curriculumStage] ==
                'language_basics',
          ),
        ),
      );
    });

    test('generates meaning-preserving variations when enabled', () async {
      final builder = CurriculumBuilder(
        manifest: manifest,
        store: store,
        variationOptions: const CurriculumVariationOptions(
          variationsPerEntry: 2,
        ),
        registry: CurriculumStageBuilderRegistry(
          phraseTemplateRootResolver: (path) => path,
        ),
      );

      await builder.buildStage('language_basics');

      final entries = await CurriculumMixing.stageQuery(
        store,
        'language_basics',
      ).stream().toList();
      expect(entries.length, greaterThan(4));
      expect(entries.any((e) => e.variationIndex > 0), isTrue);
      expect(
        entries.every(
          (e) =>
              e.metadata[CurriculumMetadataKeys.curriculumStage] ==
              'language_basics',
        ),
        isTrue,
      );
    });
  });

  group('CurriculumDataset mixing', () {
    test('review ratio is within tolerance per batch', () async {
      final store = MemoryDatasetStore();
      final manifest = CurriculumManifest.fromJson({
        'id': 'mix-v1',
        'initialLayers': 2,
        'stages': [
          {
            'id': 'review',
            'order': 0,
            'layersWhenActive': 2,
            'dataset': 'curriculum',
            'datasetVersion': 'review-v1',
            'mixing': {'mode': 'exclusive'},
            'sources': [
              {'kind': 'math_catalog', 'locale': 'en'},
            ],
          },
          {
            'id': 'primary',
            'order': 1,
            'layersWhenActive': 4,
            'dataset': 'curriculum',
            'datasetVersion': 'primary-v1',
            'mixing': {
              'mode': 'mixed',
              'reviewStages': ['review'],
              'reviewRatio': 0.2,
            },
            'sources': [
              {
                'kind': 'phrase_templates',
                'locale': 'en',
                'storePath': 'example/phrase_templates/en',
              },
            ],
          },
        ],
      });

      final builder = CurriculumBuilder(
        manifest: manifest,
        store: store,
        registry: CurriculumStageBuilderRegistry(
          phraseTemplateRootResolver: (path) => path,
        ),
      );
      await builder.buildAll();

      final batches = await CurriculumDataset(
        store: store,
        manifest: manifest,
      ).batchesPhase('primary', 10, seed: 7, limit: 100).toList();

      final fullBatches = batches.where((b) => b.length == 10).toList();
      expect(fullBatches, isNotEmpty);
      for (final batch in fullBatches) {
        final reviewCount = batch
            .where(
              (e) =>
                  e.metadata[CurriculumMetadataKeys.curriculumStage] ==
                  'review',
            )
            .length;
        expect(reviewCount / batch.length, closeTo(0.2, 0.01));
      }
    });
  });

  group('CurriculumLifecycle export', () {
    test('exportStageJsonl writes tagged entries', () async {
      final store = MemoryDatasetStore();
      final manifest = CurriculumManifest.fromJson({
        'id': 'export-v1',
        'initialLayers': 2,
        'stages': [
          {
            'id': 'language_basics',
            'order': 0,
            'layersWhenActive': 2,
            'dataset': 'curriculum',
            'datasetVersion': 'lb-v1',
            'mixing': {'mode': 'exclusive'},
            'sources': [
              {'kind': 'language_basics', 'locale': 'en', 'profile': 'generic'},
            ],
          },
        ],
      });

      await CurriculumBuilder(manifest: manifest, store: store).buildAll();

      final path = '${Directory.systemTemp.path}/curriculum_export_test.jsonl';
      final lifecycle = CurriculumLifecycle(store: store, manifest: manifest);
      await lifecycle.exportStageJsonl('language_basics', path);

      final lines = await File(path).readAsLines();
      expect(lines, hasLength(4));
      final first = jsonDecode(lines.first) as Map<String, dynamic>;
      expect(first['metadata']['curriculumStage'], 'language_basics');
    });

    test('exportStageJsonl mixed phase includes review entries', () async {
      final store = MemoryDatasetStore();
      final manifest = CurriculumManifest.fromJson({
        'id': 'export-mix-v1',
        'initialLayers': 2,
        'stages': [
          {
            'id': 'review',
            'order': 0,
            'layersWhenActive': 2,
            'dataset': 'curriculum',
            'datasetVersion': 'review-v1',
            'mixing': {'mode': 'exclusive'},
            'sources': [
              {'kind': 'language_basics', 'locale': 'en', 'profile': 'generic'},
            ],
          },
          {
            'id': 'primary',
            'order': 1,
            'layersWhenActive': 4,
            'dataset': 'curriculum',
            'datasetVersion': 'primary-v1',
            'mixing': {
              'mode': 'mixed',
              'reviewStages': ['review'],
              'reviewRatio': 0.25,
            },
            'sources': [
              {'kind': 'math_catalog', 'locale': 'en'},
            ],
          },
        ],
      });

      await CurriculumBuilder(manifest: manifest, store: store).buildAll();

      final path = '${Directory.systemTemp.path}/curriculum_mixed_export.jsonl';
      final lifecycle = CurriculumLifecycle(store: store, manifest: manifest);
      await lifecycle.exportStageJsonl('primary', path, seed: 3);

      final lines = await File(path).readAsLines();
      expect(lines.length, greaterThan(1));

      final stages = lines.map((line) {
        final json = jsonDecode(line) as Map<String, dynamic>;
        return json['metadata']['curriculumStage'] as String;
      }).toSet();
      expect(stages, containsAll(['primary', 'review']));
    });
  });
}
