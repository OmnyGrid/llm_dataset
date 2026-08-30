/// Compose validators and inspect pipeline rejections.
library;

import 'package:llm_dataset/llm_dataset.dart';

Future<void> main() async {
  final store = MemoryDatasetStore();
  final config = GeneratorConfig(
    dataset: 'strict',
    datasetVersion: 'v1',
    language: 'en',
    seed: 3,
  );

  final validators = CompositeValidator([
    EmptyContentValidator(),
    LengthValidator(minInputLength: 20, minOutputLength: 5),
    LanguageValidator({'en'}),
    TokenCountValidator(maxInputTokens: 50, maxOutputTokens: 50),
    DuplicateValidator(store: store, checkContentFingerprint: true),
  ]);

  final source = MemorySource([
    DatasetSourceDocument(id: 'ok', content: 'Tokyo is the capital of Japan.'),
    DatasetSourceDocument(id: 'short', content: 'Hi.'),
    DatasetSourceDocument(id: 'dup', content: 'Tokyo is the capital of Japan.'),
  ]);

  print('== First pass: expect 1 stored, 2 rejected ==');
  final first = await DatasetPipeline(
    source: source,
    generator: QuestionAnswerGenerator(config),
    validators: [validators],
    store: store,
    dataset: 'strict',
    datasetVersion: 'v1',
  ).run();

  print('stored=${first.entriesStored} rejected=${first.entriesRejected}');
  for (final rejection in first.rejections) {
    print(
      '  entry=${rejection.entryId} valid=${rejection.isValid} '
      '${rejection.messages.join('; ')}',
    );
  }

  print('== Second pass on same version: version guard ==');
  try {
    await DatasetPipeline(
      source: MemorySource([
        DatasetSourceDocument(id: 'more', content: 'Berlin is in Germany.'),
      ]),
      generator: QuestionAnswerGenerator(config),
      store: store,
      dataset: 'strict',
      datasetVersion: 'v1',
      failIfVersionExists: true,
    ).run();
  } on DatasetVersionExistsException catch (error) {
    print('blocked: $error');
  }

  print('== Unversioned dataset slice ==');
  final unversioned = MemoryDatasetStore();
  await DatasetPipeline(
    source: MemorySource([
      DatasetSourceDocument(
        id: 'u1',
        content: 'Oslo is the capital of Norway.',
      ),
    ]),
    generator: TextGenerator(
      GeneratorConfig(dataset: 'scratch', pipelineVersion: 'v-none'),
    ),
    store: unversioned,
    dataset: 'scratch',
    failIfVersionExists: true,
  ).run();
  print('unversioned rows=${unversioned.length}');
}
