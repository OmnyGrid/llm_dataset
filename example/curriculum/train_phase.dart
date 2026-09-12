// Demo streaming mixed batches for a curriculum training phase.
//
// Run from the repository root after building:
//   dart run example/curriculum/build_curriculum.dart
//   dart run example/curriculum/train_phase.dart phrases curriculum.db
import 'dart:io';

import 'package:llm_dataset/llm_dataset.dart';

Future<void> main(List<String> args) async {
  final stageId = args.isNotEmpty ? args[0] : 'phrases';
  final dbPath = args.length > 1 ? args[1] : 'curriculum.db';

  final manifest = await CurriculumManifest.loadFile(
    'example/curriculum/curriculum.json',
  );
  final store = SqliteDatasetStore(dbPath);
  final curriculum = CurriculumDataset(store: store, manifest: manifest);

  final stage = manifest.stage(stageId);
  stdout.writeln(
    'Phase "$stageId" (target layers: ${stage.layersWhenActive}, '
    'mixing: ${stage.mixing.mode})',
  );

  var batchIndex = 0;
  await for (final batch in curriculum.batchesPhase(
    stageId,
    8,
    seed: 42,
    limit: 24,
  )) {
    batchIndex++;
    stdout.writeln('\nBatch $batchIndex (${batch.length} entries):');
    for (final entry in batch) {
      final reviewStage =
          entry.metadata[CurriculumMetadataKeys.curriculumStage];
      stdout.writeln('  [$reviewStage] ${entry.input}');
    }
  }

  store.close();
}
