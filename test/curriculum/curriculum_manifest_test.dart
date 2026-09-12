import 'dart:io';

import 'package:llm_dataset/llm_dataset.dart';
import 'package:test/test.dart';

void main() {
  group('CurriculumManifest parsing', () {
    test('sorts stages by order', () {
      final manifest = CurriculumManifest.fromJson({
        'id': 'sort-v1',
        'initialLayers': 2,
        'stages': [
          _stageJson(id: 'second', order: 1),
          _stageJson(id: 'first', order: 0),
        ],
      });

      expect(manifest.stages.map((s) => s.id), ['first', 'second']);
    });

    test('parses variationsPerEntry on stage and source', () {
      final manifest = CurriculumManifest.fromJson({
        'id': 'var-v1',
        'initialLayers': 2,
        'stages': [
          {
            ..._stageJson(id: 's', order: 0),
            'variationsPerEntry': 3,
            'sources': [
              {
                'kind': 'language_basics',
                'locale': 'en',
                'variationsPerEntry': 1,
              },
            ],
          },
        ],
      });

      expect(manifest.stages.first.variationsPerEntry, 3);
      expect(manifest.stages.first.sources.first.variationsPerEntry, 1);
    });

    test('rejects negative variationsPerEntry', () {
      expect(
        () => CurriculumManifest.fromJson({
          'id': 'x',
          'initialLayers': 2,
          'stages': [
            {..._stageJson(id: 's', order: 0), 'variationsPerEntry': -1},
          ],
        }),
        throwsA(isA<CurriculumException>()),
      );
    });

    test('rejects mixed mode without reviewStages', () {
      expect(
        () => CurriculumManifest.fromJson({
          'id': 'x',
          'initialLayers': 2,
          'stages': [
            {
              ..._stageJson(id: 's', order: 0),
              'mixing': {'mode': 'mixed', 'reviewRatio': 0.1},
            },
          ],
        }),
        throwsA(isA<CurriculumException>()),
      );
    });

    test('rejects invalid mixing mode', () {
      expect(
        () => CurriculumManifest.fromJson({
          'id': 'x',
          'initialLayers': 2,
          'stages': [
            {
              ..._stageJson(id: 's', order: 0),
              'mixing': {'mode': 'blend'},
            },
          ],
        }),
        throwsA(isA<CurriculumException>()),
      );
    });

    test('stage lookup throws for unknown id', () {
      final manifest = CurriculumManifest.fromJson({
        'id': 'x',
        'initialLayers': 2,
        'stages': [_stageJson(id: 'only', order: 0)],
      });

      expect(
        () => manifest.stage('missing'),
        throwsA(isA<CurriculumException>()),
      );
    });

    test('toJson roundtrip preserves core fields', () {
      final original = CurriculumManifest.fromJson({
        'id': 'roundtrip-v1',
        'initialLayers': 4,
        'stages': [
          {
            'id': 'math',
            'order': 0,
            'layersWhenActive': 8,
            'dataset': 'curriculum',
            'datasetVersion': 'math-v1',
            'mixing': {
              'mode': 'mixed',
              'reviewStages': ['phrases'],
              'reviewRatio': 0.2,
            },
            'variationsPerEntry': 2,
            'sources': [
              {'kind': 'math_catalog', 'locale': 'en'},
            ],
          },
        ],
      });

      final restored = CurriculumManifest.fromJson(original.toJson());
      expect(restored.id, original.id);
      expect(restored.initialLayers, 4);
      expect(restored.stages.single.id, 'math');
      expect(restored.stages.single.mixing.reviewRatio, 0.2);
      expect(restored.stages.single.variationsPerEntry, 2);
    });

    test('loadFile reads example manifest', () async {
      final manifest = await CurriculumManifest.loadFile(
        'example/curriculum/curriculum.json',
      );

      expect(manifest.id, 'shallow-progressive-v1');
      expect(manifest.stages, hasLength(6));
      expect(manifest.stages.first.id, 'language_basics');
      expect(manifest.stages.last.id, 'coding');
    });

    test('loadFile throws when file missing', () async {
      expect(
        () => CurriculumManifest.loadFile('missing/curriculum.json'),
        throwsA(isA<CurriculumException>()),
      );
    });

    test('loadFile throws on invalid JSON', () async {
      final path = '${Directory.systemTemp.path}/bad_curriculum.json';
      await File(path).writeAsString('{ not json');
      addTearDown(() => File(path).deleteSync());

      expect(
        () => CurriculumManifest.loadFile(path),
        throwsA(isA<CurriculumException>()),
      );
    });
  });
}

Map<String, dynamic> _stageJson({required String id, required int order}) {
  return {
    'id': id,
    'order': order,
    'layersWhenActive': 2,
    'dataset': 'curriculum',
    'datasetVersion': '$id-v1',
    'mixing': {'mode': 'exclusive'},
    'sources': [
      {'kind': 'language_basics', 'locale': 'en', 'profile': 'generic'},
    ],
  };
}
