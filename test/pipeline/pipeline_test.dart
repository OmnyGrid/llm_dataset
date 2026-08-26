import 'package:llm_dataset/llm_dataset.dart';
import 'package:test/test.dart';

void main() {
  test('full pipeline with variations and rejections', () async {
    final store = MemoryDatasetStore();
    final config = GeneratorConfig(
      dataset: 'general',
      datasetVersion: 'v1',
      seed: 1,
      pipelineVersion: 'pipe',
    );

    final result = await DatasetPipeline(
      source: MemorySource([
        DatasetSourceDocument(
          id: 'ok',
          content: 'Paris is the capital of France.',
        ),
        DatasetSourceDocument(id: 'short', content: 'no'),
      ]),
      generator: TextGenerator(config),
      variations: [
        RuleBasedVariationGenerator(
          strategies: [VariationStrategy.paraphrase, VariationStrategy.casual],
          seed: 1,
        ),
      ],
      validators: [
        EmptyContentValidator(),
        LengthValidator(minInputLength: 10),
        DuplicateValidator(store: store),
      ],
      store: store,
      dataset: 'general',
      datasetVersion: 'v1',
    ).run();

    expect(result.documentsSeen, 2);
    expect(result.entriesRejected, greaterThan(0));
    expect(result.entriesStored, greaterThan(0));
    expect(store.length, result.entriesStored);

    final stored = await store.stream().toList();
    expect(
      stored.every((e) => e.provenance?.pipelineVersion == 'pipe'),
      isTrue,
    );

    expect(stored.any((e) => e.isCanonical), isTrue);
    expect(stored.any((e) => !e.isCanonical), isTrue);
    for (final parent in stored.where((e) => e.isCanonical)) {
      final children = stored.where(
        (e) => e.provenance?.parentEntryId == parent.id,
      );
      expect(children, isNotEmpty);
      expect(
        children.every((e) => e.variationGroup == parent.variationGroup),
        isTrue,
      );
    }
  });

  test('refuses existing dataset version', () async {
    final store = MemoryDatasetStore();
    final config = GeneratorConfig(
      dataset: 'general',
      datasetVersion: 'v1',
      seed: 2,
    );
    final pipeline = DatasetPipeline(
      source: MemorySource([
        DatasetSourceDocument(id: 'a', content: 'hello world'),
      ]),
      generator: TextGenerator(config),
      store: store,
      dataset: 'general',
      datasetVersion: 'v1',
    );
    await pipeline.run();
    expect(() => pipeline.run(), throwsA(isA<DatasetVersionExistsException>()));
  });

  test('store failures propagate', () async {
    final store = MemoryDatasetStore();
    final config = GeneratorConfig(dataset: 'd', seed: 3);
    final entry = await TextGenerator(config)
        .generate(DatasetSourceDocument(id: 'x', content: 'hello'))
        .first;
    await store.add(entry);

    expect(
      () => DatasetPipeline(
        source: MemorySource([
          DatasetSourceDocument(id: 'x', content: 'hello'),
        ]),
        generator: TextGenerator(config),
        store: store,
        failIfVersionExists: false,
      ).run(),
      throwsA(isA<DuplicateEntryException>()),
    );
  });
}
