/// End-to-end workflow: JSONL source → SQLite pipeline → export → batched training.
library;

import 'dart:io';

import 'package:llm_dataset/llm_dataset.dart';

Future<void> main() async {
  final tempDir = await Directory.systemTemp.createTemp('llm_dataset_e2e_');
  final dbPath = '${tempDir.path}/dataset.db';
  final sourcePath = '${tempDir.path}/source.jsonl';
  final exportPath = '${tempDir.path}/export.jsonl';

  await File(sourcePath).writeAsString('''
{"id":"france","content":"Paris is the capital of France.","title":"France","language":"en"}
{"id":"spain","content":"Madrid is the capital of Spain.","title":"Spain","language":"en"}
''');

  final store = SqliteDatasetStore(dbPath);
  final config = GeneratorConfig(
    dataset: 'geography',
    datasetVersion: 'v1',
    language: 'en',
    pipelineVersion: 'e2e-1',
    seed: 42,
  );

  print('== Pipeline: source → generate → vary → validate → SQLite ==');
  final result = await DatasetPipeline(
    source: JsonlSource(sourcePath),
    generator: QuestionAnswerGenerator(config),
    variations: [
      RuleBasedVariationGenerator(
        strategies: [VariationStrategy.paraphrase, VariationStrategy.formal],
        seed: 42,
      ),
    ],
    validators: [
      EmptyContentValidator(),
      LengthValidator(minInputLength: 5),
      DuplicateValidator(store: store, checkContentFingerprint: true),
    ],
    store: store,
    dataset: 'geography',
    datasetVersion: 'v1',
  ).run();

  print(
    'stored=${result.entriesStored} rejected=${result.entriesRejected} '
    'docs=${result.documentsSeen}',
  );

  final lifecycle = DatasetLifecycle(store);
  print('datasets=${await lifecycle.listDatasets()}');
  print('versions=${await lifecycle.listVersions('geography')}');
  print('count=${await lifecycle.count(dataset: 'geography', version: 'v1')}');

  print('== Export JSONL ==');
  await lifecycle.exportJsonl(exportPath, dataset: 'geography', version: 'v1');
  print('exported lines=${await File(exportPath).readAsLines()}');

  print('== Train in batches (one variation per group) ==');
  final dataset = Dataset(
    store: store,
    variationSelection: VariationSelection.onePerGroup,
    query: store.query().dataset('geography').datasetVersion('v1'),
  );
  await for (final batch in dataset.batches(4)) {
    print('batch(${batch.length}): ${batch.map((e) => e.id).join(', ')}');
  }

  store.close();
  await tempDir.delete(recursive: true);
  print('done');
}
