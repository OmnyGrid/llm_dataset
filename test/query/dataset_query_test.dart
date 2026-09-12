import 'package:llm_dataset/llm_dataset.dart';
import 'package:test/test.dart';

void main() {
  group('DatasetQuery', () {
    late MemoryDatasetStore store;

    setUp(() async {
      store = MemoryDatasetStore();
      final config = GeneratorConfig(
        dataset: 'q',
        datasetVersion: 'v1',
        language: 'en',
        seed: 1,
      );
      await DatasetPipeline(
        source: MemorySource([
          DatasetSourceDocument(
            id: 'a',
            content: 'Alpha text.',
            language: 'en',
          ),
          DatasetSourceDocument(id: 'b', content: 'Beta text.', language: 'en'),
        ]),
        generator: TextGenerator(config),
        store: store,
        dataset: 'q',
        datasetVersion: 'v1',
        failIfVersionExists: false,
      ).run();
    });

    test('filters by dataset and language', () async {
      final entries = await store.query().dataset('q').language('en').toList();
      expect(entries, hasLength(2));
    });

    test('sample with seed is deterministic', () async {
      final a = await store.query().sample(1, seed: 99).toList();
      final b = await store.query().sample(1, seed: 99).toList();
      expect(a.single.id, b.single.id);
    });

    test('limit caps stream length', () async {
      final entries = await store.query().limit(1).toList();
      expect(entries, hasLength(1));
    });
  });
}
