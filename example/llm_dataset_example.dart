/// End-to-end example: source → generate → variations → store → train stream.
library;

import 'package:llm_dataset/llm_dataset.dart';

Future<void> main() async {
  final store = MemoryDatasetStore();
  final config = GeneratorConfig(
    dataset: 'general',
    datasetVersion: 'v1',
    seed: 42,
    pipelineVersion: 'example-1',
  );

  final result = await DatasetPipeline(
    source: MemorySource([
      DatasetSourceDocument(
        id: 'france',
        content: 'Paris is the capital of France. It is a major European city.',
        title: 'France',
      ),
    ]),
    generator: QuestionAnswerGenerator(config),
    variations: [RuleBasedVariationGenerator(seed: 42)],
    validators: [
      EmptyContentValidator(),
      DuplicateValidator(store: store),
    ],
    store: store,
    dataset: 'general',
    datasetVersion: 'v1',
  ).run();

  print('stored=${result.entriesStored}');

  final dataset = Dataset(
    store: store,
    variationSelection: VariationSelection.onePerGroup,
  );
  await for (final entry in dataset.stream()) {
    print('${entry.id}: ${entry.input}');
  }
}
