/// Continue processing when individual store writes fail.
library;

import 'package:llm_dataset/llm_dataset.dart';

Future<void> main() async {
  final store = MemoryDatasetStore();
  final config = GeneratorConfig(dataset: 'dup-demo', seed: 1);

  // Pre-seed the store with a canonical entry that the pipeline will regenerate.
  final existing = await TextGenerator(config)
      .generate(DatasetSourceDocument(id: 'doc-a', content: 'hello world'))
      .first;
  await store.add(existing);
  print('preloaded id=${existing.id} store=${store.length}');

  print('== abort (default): store failure stops pipeline ==');
  try {
    await DatasetPipeline(
      source: MemorySource([
        DatasetSourceDocument(id: 'doc-a', content: 'hello world again'),
      ]),
      generator: TextGenerator(config),
      store: store,
      failIfVersionExists: false,
    ).run();
    print('unexpected success');
  } on DuplicateEntryException catch (error) {
    print('aborted: $error');
  }

  print('== continueProcessing: record errors, keep going ==');
  final result = await DatasetPipeline(
    source: MemorySource([
      DatasetSourceDocument(id: 'doc-a', content: 'hello world again'),
      DatasetSourceDocument(id: 'doc-b', content: 'unique content here'),
    ]),
    generator: TextGenerator(config),
    store: store,
    storeErrorPolicy: PipelineStoreErrorPolicy.continueProcessing,
    failIfVersionExists: false,
  ).run();

  print(
    'stored=${result.entriesStored} rejected=${result.entriesRejected} '
    'storeErrors=${result.storeErrors.length}',
  );
  for (final error in result.storeErrors) {
    print('  store error: $error');
  }
  print('final store size=${store.length}');
}
