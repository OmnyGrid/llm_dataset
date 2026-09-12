import 'dart:convert';
import 'dart:io';

import 'package:llm_dataset/llm_dataset.dart';
import 'package:test/test.dart';

import '../test_paths.dart';

CurriculumStageBuilderRegistry _registry() {
  return CurriculumStageBuilderRegistry(
    phraseTemplateRootResolver: (path) => path,
  );
}

void main() {
  group('CurriculumLifecycle stageStats', () {
    test('returns counts for every manifest stage', () async {
      final manifest = await CurriculumManifest.loadFile(
        TestPaths.curriculumManifest,
      );
      final store = MemoryDatasetStore();
      await CurriculumBuilder(
        manifest: manifest,
        store: store,
        registry: _registry(),
      ).buildAll();

      final lifecycle = CurriculumLifecycle(store: store, manifest: manifest);
      final stats = await lifecycle.stageStats();

      for (final stage in manifest.stages) {
        expect(stats[stage.id], greaterThan(0));
      }
      expect(stats.keys, manifest.stages.map((s) => s.id).toSet());
    });
  });

  group('CurriculumLifecycle export and listStages', () {
    late CurriculumManifest manifest;
    late MemoryDatasetStore store;

    setUp(() async {
      manifest = await CurriculumManifest.loadFile(
        TestPaths.curriculumManifest,
      );
      store = MemoryDatasetStore();
      await CurriculumBuilder(
        manifest: manifest,
        store: store,
        registry: _registry(),
      ).buildAll();
    });

    test('listStages returns sorted stage ids from memory store', () async {
      final lifecycle = CurriculumLifecycle(store: store, manifest: manifest);
      final stages = await lifecycle.listStages();
      expect(stages, containsAll(['language_basics', 'phrases', 'math']));
      expect(stages, equals(stages.toList()..sort()));
    });

    test('exportStageJsonl exclusive writes only stage entries', () async {
      final lifecycle = CurriculumLifecycle(store: store, manifest: manifest);
      final path =
          '${Directory.systemTemp.path}/stage_export_${DateTime.now().microsecondsSinceEpoch}.jsonl';
      addTearDown(() {
        final file = File(path);
        if (file.existsSync()) {
          file.deleteSync();
        }
      });

      await lifecycle.exportStageJsonl('language_basics', path);
      final lines = await File(path).readAsLines();
      expect(lines, isNotEmpty);
      for (final line in lines) {
        final json = jsonDecode(line) as Map<String, dynamic>;
        expect(json['metadata']['curriculumStage'], 'language_basics');
      }
    });

    test('exportStageJsonl mixed phase can include review entries', () async {
      final lifecycle = CurriculumLifecycle(store: store, manifest: manifest);
      final path =
          '${Directory.systemTemp.path}/mixed_export_${DateTime.now().microsecondsSinceEpoch}.jsonl';
      addTearDown(() {
        final file = File(path);
        if (file.existsSync()) {
          file.deleteSync();
        }
      });

      await lifecycle.exportStageJsonl('phrases', path, seed: 3, limit: 30);
      final lines = await File(path).readAsLines();
      final stages = {
        for (final line in lines)
          (jsonDecode(line)
                  as Map<String, dynamic>)['metadata']['curriculumStage']
              as String,
      };
      expect(stages, contains('phrases'));
      expect(stages.any((s) => s != 'phrases'), isTrue);
    });

    test('countStage returns tagged entry count', () async {
      final lifecycle = CurriculumLifecycle(store: store, manifest: manifest);
      final count = await lifecycle.countStage('language_basics');
      expect(count, greaterThan(0));
      expect(
        count,
        await lifecycle.stageStats().then((s) => s['language_basics']),
      );
    });

    test('exportStageJsonl with mixing override uses custom ratio', () async {
      final lifecycle = CurriculumLifecycle(store: store, manifest: manifest);
      final path =
          '${Directory.systemTemp.path}/override_export_${DateTime.now().microsecondsSinceEpoch}.jsonl';
      addTearDown(() {
        final file = File(path);
        if (file.existsSync()) file.deleteSync();
      });

      await lifecycle.exportStageJsonl(
        'phrases',
        path,
        mixing: const CurriculumMixingPolicy(
          mode: 'mixed',
          reviewStages: ['language_basics'],
          reviewRatio: 0.5,
        ),
        seed: 5,
        limit: 20,
      );

      final lines = await File(path).readAsLines();
      expect(lines.length, lessThanOrEqualTo(20));
      expect(lines, isNotEmpty);
    });

    test('exportStageJsonl exclusive respects limit', () async {
      final lifecycle = CurriculumLifecycle(store: store, manifest: manifest);
      final path =
          '${Directory.systemTemp.path}/limited_export_${DateTime.now().microsecondsSinceEpoch}.jsonl';
      addTearDown(() {
        final file = File(path);
        if (file.existsSync()) file.deleteSync();
      });

      await lifecycle.exportStageJsonl('phrases', path, limit: 3);
      expect(await File(path).readAsLines(), hasLength(3));
    });
  });
}
