import 'package:llm_dataset/llm_dataset.dart';
import 'package:test/test.dart';

DatasetEntry entry({
  String id = 'e1',
  String input = 'hello world',
  String? output = 'ok',
  String language = 'en',
  Map<String, dynamic> metadata = const {},
  String? datasetVersion,
}) {
  return DatasetEntry(
    id: id,
    dataset: 'd',
    datasetVersion: datasetVersion,
    type: DatasetEntryType.text,
    language: language,
    input: input,
    output: output,
    variationGroup: 'g',
    variationIndex: 0,
    metadata: metadata,
    createdAt: DateTime.utc(2024),
  );
}

void main() {
  group('variation id collision', () {
    test('multiple generators with same strategy produce unique ids', () async {
      final store = MemoryDatasetStore();
      final result = await DatasetPipeline(
        source: MemorySource([
          DatasetSourceDocument(
            id: 'a',
            content: 'hello world test content here',
          ),
        ]),
        generator: TextGenerator(GeneratorConfig(dataset: 'd', seed: 1)),
        variations: [
          RuleBasedVariationGenerator(
            strategies: [VariationStrategy.paraphrase],
            seed: 1,
          ),
          RuleBasedVariationGenerator(
            strategies: [VariationStrategy.paraphrase],
            seed: 1,
          ),
        ],
        validators: [EmptyContentValidator()],
        store: store,
        failIfVersionExists: false,
      ).run();

      expect(result.entriesStored, 3);
      final stored = await store.stream().toList();
      expect(stored.map((e) => e.id).toSet(), hasLength(3));
      expect(stored.where((e) => !e.isCanonical).map((e) => e.variationIndex), [
        1,
        2,
      ]);
    });
  });

  group('DuplicateValidator', () {
    test('does not burn id when fingerprint fails', () async {
      final v = DuplicateValidator(checkContentFingerprint: true);
      expect((await v.validate(entry(id: 'a', input: 'same'))).isValid, isTrue);
      expect(
        (await v.validate(entry(id: 'b', input: 'same'))).isValid,
        isFalse,
      );
      expect(
        (await v.validate(entry(id: 'b', input: 'unique content'))).isValid,
        isTrue,
      );
    });

    test('rejects duplicate content already in store', () async {
      final store = MemoryDatasetStore();
      await store.add(entry(id: 'existing', input: 'same text'));
      final v = DuplicateValidator(store: store, checkContentFingerprint: true);
      expect(
        (await v.validate(entry(id: 'new', input: 'same text'))).isValid,
        isFalse,
      );
    });
  });

  group('query filters', () {
    late MemoryDatasetStore store;

    setUp(() async {
      store = MemoryDatasetStore();
      await store.addAll(
        Stream.fromIterable([
          entry(id: 'c1', input: 'canonical'),
          DatasetEntry(
            id: 'v1',
            dataset: 'd',
            type: DatasetEntryType.text,
            language: 'en',
            input: 'variation',
            variationGroup: 'g',
            variationIndex: 1,
            provenance: const DatasetProvenance(parentEntryId: 'c1'),
            createdAt: DateTime.utc(2024),
          ),
        ]),
      );
    });

    test('variationSelection and variations do not conflict', () async {
      final all = await store
          .query()
          .variationSelection(VariationSelection.canonicalOnly)
          .variations(true)
          .toList();
      expect(all, hasLength(2));

      final canonical = await store
          .query()
          .canonicalOnly(true)
          .variationSelection(VariationSelection.all)
          .toList();
      expect(canonical, hasLength(2));

      final onlyCanonical = await store.query().canonicalOnly(true).toList();
      expect(onlyCanonical, hasLength(1));
      expect(onlyCanonical.single.id, 'c1');
    });

    test('metadata uses deep equality', () async {
      await store.add(
        entry(
          id: 'm1',
          metadata: {
            'tags': ['a', 'b'],
          },
        ),
      );
      expect(
        await store.query().metadata('tags', ['a', 'b']).toList(),
        hasLength(1),
      );
    });

    test('sample preserves createdAt ordering', () async {
      final isolated = MemoryDatasetStore();
      await isolated.addAll(
        Stream.fromIterable([
          DatasetEntry(
            id: 'old',
            dataset: 'd',
            type: DatasetEntryType.text,
            language: 'en',
            input: 'x',
            variationGroup: 'g2',
            variationIndex: 0,
            createdAt: DateTime.utc(2024, 1, 1),
          ),
          DatasetEntry(
            id: 'new',
            dataset: 'd',
            type: DatasetEntryType.text,
            language: 'en',
            input: 'y',
            variationGroup: 'g3',
            variationIndex: 0,
            createdAt: DateTime.utc(2024, 6, 1),
          ),
        ]),
      );
      final sampled = await isolated
          .query()
          .orderByCreatedAt(ascending: false)
          .sample(2, seed: 1)
          .toList();
      expect(sampled.first.createdAt.isAfter(sampled.last.createdAt), isTrue);
    });
  });

  group('pipeline version guard', () {
    test('blocks repeated unversioned dataset runs', () async {
      final store = MemoryDatasetStore();
      final pipeline = DatasetPipeline(
        source: MemorySource([
          DatasetSourceDocument(id: 'a', content: 'hello world today'),
        ]),
        generator: TextGenerator(GeneratorConfig(dataset: 'general', seed: 1)),
        store: store,
        dataset: 'general',
        datasetVersion: null,
      );
      await pipeline.run();
      expect(
        () => pipeline.run(),
        throwsA(isA<DatasetVersionExistsException>()),
      );
    });
  });

  group('addAll atomicity', () {
    test('memory store rolls back on duplicate', () async {
      final store = MemoryDatasetStore();
      await store.add(entry(id: 'existing'));
      expect(
        () => store.addAll(
          Stream.fromIterable([
            entry(id: 'a'),
            entry(id: 'b'),
            entry(id: 'existing'),
          ]),
        ),
        throwsA(isA<DuplicateEntryException>()),
      );
      expect(store.length, 1);
    });

    test('sqlite store rolls back on duplicate', () async {
      final store = SqliteDatasetStore(':memory:');
      addTearDown(store.close);
      await store.add(entry(id: 'existing'));
      expect(
        () => store.addAll(
          Stream.fromIterable([
            entry(id: 'a'),
            entry(id: 'b'),
            entry(id: 'existing'),
          ]),
        ),
        throwsA(isA<DuplicateEntryException>()),
      );
      expect(await store.get('a'), isNull);
      expect(await store.get('b'), isNull);
    });
  });

  group('JSON and timestamps', () {
    test('variationIndex accepts numeric JSON', () {
      final restored = DatasetEntry.fromJson({
        'id': 'x',
        'dataset': 'd',
        'type': 'text',
        'language': 'en',
        'input': 'i',
        'variationGroup': 'g',
        'variationIndex': 1.0,
        'metadata': {},
        'createdAt': '2024-01-01T00:00:00.000Z',
      });
      expect(restored.variationIndex, 1);
    });

    test('seeded generators assign distinct createdAt per document', () async {
      final cfg = GeneratorConfig(dataset: 'd', seed: 123);
      final e1 = await TextGenerator(cfg)
          .generate(DatasetSourceDocument(id: 'doc-1', content: 'hello world'))
          .first;
      final e2 = await TextGenerator(cfg)
          .generate(DatasetSourceDocument(id: 'doc-2', content: 'hello world'))
          .first;
      expect(e1.createdAt, isNot(e2.createdAt));
    });
  });
}
