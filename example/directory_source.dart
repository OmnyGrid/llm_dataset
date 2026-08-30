/// Load plain-text files from a directory and run a summarization pipeline.
library;

import 'dart:io';

import 'package:llm_dataset/llm_dataset.dart';

Future<void> main() async {
  final tempDir = await Directory.systemTemp.createTemp('llm_dataset_dir_');
  final docsDir = Directory('${tempDir.path}/docs');
  await docsDir.create(recursive: true);

  await File('${docsDir.path}/france.txt').writeAsString(
    'Paris is the capital of France. The Eiffel Tower is a famous landmark.',
  );
  await File('${docsDir.path}/spain.txt').writeAsString(
    'Madrid is the capital of Spain. Flamenco music originated in Andalusia.',
  );
  await File('${docsDir.path}/notes.json').writeAsString('{"ignored": true}');

  final store = MemoryDatasetStore();
  final config = GeneratorConfig(
    dataset: 'wiki-snippets',
    datasetVersion: 'v1',
    language: 'en',
    pipelineVersion: 'dir-example',
    seed: 1,
  );

  print('== Pipeline from DirectorySource (.txt only) ==');
  final result = await DatasetPipeline(
    source: DirectorySource(docsDir.path, extensions: {'.txt'}),
    generator: SummarizationGenerator(config),
    validators: [EmptyContentValidator(), LengthValidator(minInputLength: 10)],
    store: store,
    dataset: 'wiki-snippets',
    datasetVersion: 'v1',
  ).run();

  print(
    'docs=${result.documentsSeen} stored=${result.entriesStored} '
    'rejected=${result.entriesRejected}',
  );

  for (final entry in await store.query().orderByCreatedAt().toList()) {
    final title = entry.metadata['sourceTitle'];
    print('[$title] ${entry.input} → ${entry.output}');
  }

  await tempDir.delete(recursive: true);
}
