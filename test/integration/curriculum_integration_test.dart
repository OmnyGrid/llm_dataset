import 'dart:convert';
import 'dart:io';

import 'package:llm_dataset/llm_dataset.dart';
import 'package:test/test.dart';

/// Shared registry for tests that load phrase templates from the repo.
CurriculumStageBuilderRegistry curriculumTestRegistry() {
  return CurriculumStageBuilderRegistry(
    phraseTemplateRootResolver: (path) => path,
  );
}

void main() {
  group('Curriculum end-to-end (memory)', () {
    late CurriculumManifest manifest;
    late MemoryDatasetStore store;

    setUp(() async {
      manifest = await CurriculumManifest.loadFile(
        'example/curriculum/curriculum.json',
      );
      store = MemoryDatasetStore();
    });

    test('buildAll populates every stage with tagged entries', () async {
      final result = await CurriculumBuilder(
        manifest: manifest,
        store: store,
        registry: curriculumTestRegistry(),
      ).buildAll();

      expect(result.curriculumId, 'shallow-progressive-v1');
      expect(
        result.stageResults.keys,
        manifest.stages.map((s) => s.id).toSet(),
      );

      for (final stage in manifest.stages) {
        final stageResult = result.resultFor(stage.id)!;
        expect(stageResult.entriesStored, greaterThan(0), reason: stage.id);

        final count = await CurriculumLifecycle(
          store: store,
          manifest: manifest,
        ).countStage(stage.id);
        expect(count, stageResult.entriesStored);
      }

      expect(result.totalEntriesStored, greaterThan(100));
    });

    test('exclusive vs mixed consumption differ for phrases stage', () async {
      await CurriculumBuilder(
        manifest: manifest,
        store: store,
        registry: curriculumTestRegistry(),
      ).buildAll();

      final curriculum = CurriculumDataset(store: store, manifest: manifest);
      final exclusive = await curriculum.exclusive('phrases').stream().toList();
      final mixed = await curriculum
          .streamPhase('phrases', seed: 42, limit: 50)
          .toList();

      expect(
        exclusive.every((e) => e.metadata['curriculumStage'] == 'phrases'),
        isTrue,
      );
      expect(
        mixed.any((e) => e.metadata['curriculumStage'] == 'language_basics'),
        isTrue,
      );
    });

    test('paragraph variations increase stored count when enabled', () async {
      final miniManifest = CurriculumManifest.fromJson({
        'id': 'paragraph-var-v1',
        'initialLayers': 2,
        'stages': [
          {
            'id': 'paragraphs',
            'order': 0,
            'layersWhenActive': 6,
            'dataset': 'curriculum',
            'datasetVersion': 'paragraphs-v1',
            'mixing': {'mode': 'exclusive'},
            'variationsPerEntry': 2,
            'sources': [
              {'kind': 'paragraph_catalog', 'locale': 'en'},
            ],
          },
        ],
      });

      await CurriculumBuilder(
        manifest: miniManifest,
        store: store,
        registry: curriculumTestRegistry(),
      ).buildAll();

      final entries = await CurriculumMixing.stageQuery(
        store,
        'paragraphs',
      ).stream().toList();

      expect(entries.length, greaterThan(2));
      expect(entries.any((e) => e.variationIndex > 0), isTrue);
    });

    test('TrainingPhaseDescriptor reflects build counts', () async {
      final buildResult = await CurriculumBuilder(
        manifest: manifest,
        store: store,
        registry: curriculumTestRegistry(),
      ).buildStage('math');

      final stage = manifest.stage('math');
      final lifecycle = CurriculumLifecycle(store: store, manifest: manifest);
      final exportPath = '${Directory.systemTemp.path}/math_phase.jsonl';

      final descriptor = buildResult.phaseDescriptor(
        stage,
        exportPath: exportPath,
        entryCount: await lifecycle.countStage('math'),
      );

      expect(descriptor.stageId, 'math');
      expect(descriptor.targetLayers, 8);
      expect(descriptor.mixing.reviewStages, ['paragraphs']);
      expect(
        descriptor.entryCount,
        buildResult.resultFor('math')!.entriesStored,
      );
    });
  });

  group('Curriculum end-to-end (SQLite)', () {
    late File dbFile;

    setUp(() {
      dbFile = File(
        '${Directory.systemTemp.path}/curriculum_integration_${DateTime.now().microsecondsSinceEpoch}.db',
      );
    });

    tearDown(() {
      if (dbFile.existsSync()) {
        dbFile.deleteSync();
      }
    });

    test('buildAll export and listStages via SQLite', () async {
      final manifest = await CurriculumManifest.loadFile(
        'example/curriculum/curriculum.json',
      );
      final store = SqliteDatasetStore(dbFile.path);
      addTearDown(store.close);

      await CurriculumBuilder(
        manifest: manifest,
        store: store,
        registry: curriculumTestRegistry(),
        configureBulkInsert: true,
      ).buildAll();

      final lifecycle = CurriculumLifecycle(store: store, manifest: manifest);
      final stages = await lifecycle.listStages();
      expect(stages, containsAll(['language_basics', 'math', 'coding']));

      final exportPath = '${dbFile.path}.jsonl';
      await lifecycle.exportStageJsonl('language_basics', exportPath);

      final lines = await File(exportPath).readAsLines();
      expect(lines, isNotEmpty);
      final decoded = jsonDecode(lines.first) as Map<String, dynamic>;
      expect(decoded['metadata']['curriculumId'], manifest.id);

      addTearDown(() => File(exportPath).deleteSync());
    });

    test('listDistinctMetadataValues returns sorted stage ids', () async {
      final store = SqliteDatasetStore(dbFile.path);
      addTearDown(store.close);

      await store.addAll(
        Stream.fromIterable([
          _taggedEntry('alpha'),
          _taggedEntry('beta'),
          _taggedEntry('alpha'),
        ]),
      );

      expect(
        await store.listDistinctMetadataValues(
          CurriculumMetadataKeys.curriculumStage,
        ),
        ['alpha', 'beta'],
      );
    });
  });

  group('CurriculumBuildResult', () {
    test('aggregates totals across stages', () {
      const result = CurriculumBuildResult(
        curriculumId: 'c',
        stageResults: {
          'a': CurriculumStageBuildResult(
            stageId: 'a',
            documentsSeen: 2,
            entriesGenerated: 4,
            entriesStored: 3,
            entriesRejected: 1,
          ),
          'b': CurriculumStageBuildResult(
            stageId: 'b',
            documentsSeen: 1,
            entriesGenerated: 2,
            entriesStored: 2,
            entriesRejected: 0,
          ),
        },
      );

      expect(result.totalEntriesStored, 5);
      expect(result.resultFor('a')!.entryCount, 3);
      expect(result.resultFor('missing'), isNull);
    });
  });
}

DatasetEntry _taggedEntry(String stage) {
  return DatasetEntry(
    id: '$stage-${DateTime.now().microsecondsSinceEpoch}',
    dataset: 'curriculum',
    type: DatasetEntryType.text,
    language: 'en',
    input: stage,
    variationGroup: stage,
    variationIndex: 0,
    metadata: {CurriculumMetadataKeys.curriculumStage: stage},
    createdAt: DateTime.utc(2026),
  );
}
