/// Implement [DatasetGenerator] for domain-specific entry shapes.
library;

import 'package:llm_dataset/llm_dataset.dart';

/// Emits a classification pair from the first line of each document.
class FirstLineClassifierGenerator implements DatasetGenerator {
  FirstLineClassifierGenerator(
    this.config, {
    this.labels = const ['fact', 'opinion'],
  });

  final GeneratorConfig config;
  final List<String> labels;

  @override
  Stream<DatasetEntry> generate(DatasetSourceDocument document) async* {
    final firstLine = document.content
        .split('\n')
        .map((line) => line.trim())
        .firstWhere((line) => line.isNotEmpty, orElse: () => document.content);

    final label = firstLine.contains('I think') ? 'opinion' : 'fact';

    yield DatasetEntry(
      id: '${document.id}-classify',
      dataset: config.dataset,
      datasetVersion: config.datasetVersion,
      type: DatasetEntryType.classification,
      language: document.language ?? config.language,
      input: firstLine,
      output: label,
      variationGroup: document.id,
      variationIndex: 0,
      metadata: {'sourceDocumentId': document.id, 'labels': labels},
      provenance: DatasetProvenance(
        source: 'document',
        sourceId: document.id,
        generator: 'FirstLineClassifierGenerator',
        generatorVersion: config.generatorVersion,
        pipelineVersion: config.pipelineVersion,
      ),
      createdAt: DateTime.now().toUtc(),
    );
  }
}

Future<void> main() async {
  final store = MemoryDatasetStore();
  final config = GeneratorConfig(
    dataset: 'classify',
    datasetVersion: 'v1',
    pipelineVersion: 'custom-gen',
  );

  final result = await DatasetPipeline(
    source: MemorySource([
      DatasetSourceDocument(
        id: 'f1',
        content: 'Paris is the capital of France.',
      ),
      DatasetSourceDocument(
        id: 'f2',
        content: 'I think summer is the best season.',
      ),
    ]),
    generator: FirstLineClassifierGenerator(config),
    validators: [
      LanguageValidator({'en'}),
      MetadataValidator(requiredKeys: ['labels']),
    ],
    store: store,
    dataset: 'classify',
    datasetVersion: 'v1',
  ).run();

  print('stored=${result.entriesStored} rejected=${result.entriesRejected}');
  for (final entry in await store.query().toList()) {
    print(
      '${entry.metadata['sourceDocumentId']}: ${entry.output} ← ${entry.input}',
    );
  }
}
