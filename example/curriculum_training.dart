/// Progressive curriculum training demo (self-contained, in-memory).
///
/// Builds a small two-stage curriculum, streams exclusive and mixed batches,
/// and exports a phase slice to JSONL. No SQLite file required.
///
/// Run:
/// ```bash
/// dart run example/curriculum_training.dart
/// ```
library;

import 'dart:io';

import 'package:llm_dataset/llm_dataset.dart';

Future<void> main() async {
  final manifest = CurriculumManifest.fromJson({
    'id': 'demo-progressive-v1',
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
        'id': 'math',
        'order': 1,
        'layersWhenActive': 4,
        'dataset': 'curriculum',
        'datasetVersion': 'math-v1',
        'mixing': {
          'mode': 'mixed',
          'reviewStages': ['language_basics'],
          'reviewRatio': 0.25,
        },
        'sources': [
          {'kind': 'math_catalog', 'locale': 'en'},
        ],
      },
    ],
  });

  final store = MemoryDatasetStore();
  final builder = CurriculumBuilder(
    manifest: manifest,
    store: store,
    variationOptions: const CurriculumVariationOptions(variationsPerEntry: 2),
  );

  print('== Building curriculum stages ==');
  final buildResult = await builder.buildAll();
  for (final stage in manifest.stages) {
    final stageResult = buildResult.resultFor(stage.id)!;
    print(
      '  ${stage.id}: ${stageResult.entriesStored} entries '
      '(target layers: ${stage.layersWhenActive})',
    );
  }

  final curriculum = CurriculumDataset(store: store, manifest: manifest);
  final lifecycle = CurriculumLifecycle(store: store, manifest: manifest);

  print('\n== Exclusive: language_basics ==');
  await for (final entry in curriculum.exclusive('language_basics').stream()) {
    print('  ${entry.input}');
  }

  print('\n== Mixed batches: math (75% math, 25% language_basics review) ==');
  print(
    '(language_basics entries include up to 2 meaning-preserving variations)',
  );
  var batchIndex = 0;
  await for (final batch in curriculum.batchesPhase('math', 4, seed: 7)) {
    batchIndex++;
    print('Batch $batchIndex:');
    for (final entry in batch) {
      final stage = entry.metadata[CurriculumMetadataKeys.curriculumStage];
      print('  [$stage] ${entry.input} → ${entry.output}');
    }
  }

  print('\n== Lifecycle ==');
  print('Stages in store: ${await lifecycle.listStages()}');
  print(
    'language_basics count: ${await lifecycle.countStage('language_basics')}',
  );
  print('math count: ${await lifecycle.countStage('math')}');

  final exportPath = '${Directory.systemTemp.path}/curriculum_math_phase.jsonl';
  await lifecycle.exportStageJsonl('math', exportPath);
  final lineCount = await File(exportPath).readAsLines().then((l) => l.length);
  print('Exported math phase to $exportPath ($lineCount lines)');

  final descriptor = buildResult.phaseDescriptor(
    manifest.stage('math'),
    exportPath: exportPath,
    entryCount: await lifecycle.countStage('math'),
  );
  print(
    '\nTrainingPhaseDescriptor: stage=${descriptor.stageId}, '
    'layers=${descriptor.targetLayers}, entries=${descriptor.entryCount}',
  );

  print('\ndone');
}
