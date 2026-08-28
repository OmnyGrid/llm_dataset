import 'package:llm_dataset/llm_dataset.dart';
import 'package:test/test.dart';

void main() {
  group('DatasetLifecycle', () {
    late SqliteDatasetStore store;
    late DatasetLifecycle lifecycle;

    setUp(() async {
      store = SqliteDatasetStore(':memory:');
      lifecycle = DatasetLifecycle(store);
      await store.addAll(
        Stream.fromIterable([
          DatasetEntry(
            id: 'a1',
            dataset: 'geo',
            datasetVersion: 'v1',
            type: DatasetEntryType.text,
            language: 'en',
            input: 'q1',
            variationGroup: 'g1',
            variationIndex: 0,
            metadata: {'topic': 'capitals'},
            createdAt: DateTime.utc(2024, 1, 1),
          ),
          DatasetEntry(
            id: 'a2',
            dataset: 'geo',
            datasetVersion: 'v2',
            type: DatasetEntryType.text,
            language: 'en',
            input: 'q2',
            variationGroup: 'g2',
            variationIndex: 0,
            createdAt: DateTime.utc(2024, 2, 1),
          ),
        ]),
      );
    });

    tearDown(() => store.close());

    test('lists datasets and versions', () async {
      expect(await lifecycle.listDatasets(), ['geo']);
      expect(await lifecycle.listVersions('geo'), ['v1', 'v2']);
    });

    test('counts and deletes version slice', () async {
      expect(await lifecycle.count(dataset: 'geo', version: 'v1'), 1);
      expect(await lifecycle.deleteDataset('geo', version: 'v1'), 1);
      expect(await lifecycle.count(dataset: 'geo', version: 'v1'), 0);
      expect(await lifecycle.count(dataset: 'geo', version: 'v2'), 1);
    });
  });

  group('Sqlite metadata SQL filter', () {
    test('filters scalar metadata without loading all into Dart', () async {
      final store = SqliteDatasetStore(':memory:');
      addTearDown(store.close);
      await store.add(
        DatasetEntry(
          id: 'm1',
          dataset: 'd',
          type: DatasetEntryType.text,
          language: 'en',
          input: 'x',
          variationGroup: 'g',
          variationIndex: 0,
          metadata: {'topic': 'geo'},
          createdAt: DateTime.utc(2024),
        ),
      );
      final found = await store
          .query()
          .metadata('topic', 'geo')
          .stream()
          .toList();
      expect(found, hasLength(1));
      expect(found.single.id, 'm1');
    });
  });

  group('Sqlite streaming query', () {
    test('streams filtered rows in batches', () async {
      final store = SqliteDatasetStore(':memory:');
      addTearDown(store.close);
      await store.addAll(
        Stream.fromIterable([
          for (var i = 0; i < 1200; i++)
            DatasetEntry(
              id: 'id-$i',
              dataset: 'bulk',
              type: DatasetEntryType.text,
              language: 'en',
              input: 'x$i',
              variationGroup: 'g-$i',
              variationIndex: 0,
              createdAt: DateTime.utc(2024),
            ),
        ]),
      );

      var count = 0;
      await for (final _ in store.query().dataset('bulk').stream()) {
        count++;
      }
      expect(count, 1200);
    });
  });

  group('PipelineStoreErrorPolicy', () {
    test('continueProcessing records store failures', () async {
      final store = MemoryDatasetStore();
      final config = GeneratorConfig(dataset: 'd', seed: 1);
      final canonical = await TextGenerator(config)
          .generate(DatasetSourceDocument(id: 'x', content: 'hello world'))
          .first;
      await store.add(canonical);

      final result = await DatasetPipeline(
        source: MemorySource([
          DatasetSourceDocument(id: 'x', content: 'hello world again'),
        ]),
        generator: TextGenerator(config),
        store: store,
        storeErrorPolicy: PipelineStoreErrorPolicy.continueProcessing,
        failIfVersionExists: false,
      ).run();

      expect(result.storeErrors, isNotEmpty);
      expect(result.entriesRejected, greaterThan(0));
    });
  });
}
