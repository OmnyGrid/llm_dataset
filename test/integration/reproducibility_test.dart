import 'package:llm_dataset/llm_dataset.dart';
import 'package:test/test.dart';

void main() {
  test('reproducible generate + vary + sample', () async {
    Future<List<String>> run() async {
      final store = MemoryDatasetStore();
      final config = GeneratorConfig(
        dataset: 'general',
        datasetVersion: 'v1',
        seed: 123,
        pipelineVersion: 'pipe-1',
        generatorVersion: '1.0.0',
      );
      await DatasetPipeline(
        source: MemorySource([
          DatasetSourceDocument(
            id: 'france',
            content: 'Paris is the capital of France.',
          ),
          DatasetSourceDocument(
            id: 'spain',
            content: 'Madrid is the capital of Spain.',
          ),
        ]),
        generator: QuestionAnswerGenerator(config),
        variations: [
          RuleBasedVariationGenerator(
            strategies: [
              VariationStrategy.paraphrase,
              VariationStrategy.formal,
              VariationStrategy.casual,
            ],
            seed: 123,
            generatorVersion: '1.0.0',
          ),
        ],
        validators: [EmptyContentValidator()],
        store: store,
        dataset: 'general',
        datasetVersion: 'v1',
      ).run();

      return store
          .query()
          .sample(4, seed: 5)
          .stream()
          .map((e) => '${e.id}:${e.variationIndex}:${e.input}')
          .toList();
    }

    expect(await run(), await run());
  });

  test('dataset version isolation', () async {
    final store = MemoryDatasetStore();
    for (final version in ['v1', 'v2']) {
      await DatasetPipeline(
        source: MemorySource([
          DatasetSourceDocument(id: 'd', content: 'hello $version world'),
        ]),
        generator: TextGenerator(
          GeneratorConfig(
            dataset: 'general',
            datasetVersion: version,
            seed: version.hashCode,
          ),
        ),
        store: store,
        dataset: 'general',
        datasetVersion: version,
      ).run();
    }

    expect(await store.query().datasetVersion('v1').toList(), hasLength(1));
    expect(await store.query().datasetVersion('v2').toList(), hasLength(1));
  });
}
