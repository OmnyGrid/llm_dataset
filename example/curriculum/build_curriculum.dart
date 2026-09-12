// Build all curriculum stages into a SQLite database.
//
// Run from the repository root:
//   dart run example/curriculum/build_curriculum.dart [output.db]
import 'dart:io';

import 'package:llm_dataset/llm_dataset.dart';

Future<void> main(List<String> args) async {
  final outputPath = args.isNotEmpty ? args.first : 'curriculum.db';
  final manifestPath = 'example/curriculum/curriculum.json';

  if (File(outputPath).existsSync()) {
    stdout.writeln('Removing existing database: $outputPath');
    File(outputPath).deleteSync();
  }

  stdout.writeln('Loading manifest: $manifestPath');
  final manifest = await CurriculumManifest.loadFile(manifestPath);

  final store = SqliteDatasetStore(outputPath);
  store.configureBulkInsertIfSupported();

  final builder = CurriculumBuilder(
    manifest: manifest,
    store: store,
    registry: CurriculumStageBuilderRegistry(
      phraseTemplateRootResolver: (path) => path,
    ),
  );

  stdout.writeln('Building ${manifest.stages.length} stages…');
  final result = await builder.buildAll();

  stdout.writeln('Done. Total entries stored: ${result.totalEntriesStored}');
  for (final stage in manifest.stages) {
    final stageResult = result.resultFor(stage.id)!;
    stdout.writeln(
      '  ${stage.id}: ${stageResult.entriesStored} entries '
      '(${stage.layersWhenActive} layers)',
    );
  }

  store.close();
  stdout.writeln('Wrote $outputPath');
}
