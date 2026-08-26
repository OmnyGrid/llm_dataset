import 'package:llm_dataset/llm_dataset.dart';
import 'package:test/test.dart';

DatasetEntry _entry(
  String id, {
  String dataset = 'general',
  String? datasetVersion = 'v1',
  DatasetEntryType type = DatasetEntryType.text,
  String language = 'en',
  String variationGroup = 'g1',
  int variationIndex = 0,
  String? parentEntryId,
  String? source,
  Map<String, dynamic> metadata = const {},
  DateTime? createdAt,
}) {
  return DatasetEntry(
    id: id,
    dataset: dataset,
    datasetVersion: datasetVersion,
    type: type,
    language: language,
    input: 'input-$id',
    output: 'output-$id',
    variationGroup: variationGroup,
    variationIndex: variationIndex,
    metadata: metadata,
    provenance: DatasetProvenance(source: source, parentEntryId: parentEntryId),
    createdAt: createdAt ?? DateTime.utc(2024, 1, 1),
  );
}

void main() {
  group('MemoryDatasetStore', () {
    test('add get and stream by id order', () async {
      final store = MemoryDatasetStore();
      await store.add(_entry('b'));
      await store.add(_entry('a'));
      expect(await store.get('a'), isNotNull);
      expect(await store.get('missing'), isNull);
      expect(store.length, 2);
      expect(await store.stream().map((e) => e.id).toList(), ['a', 'b']);
    });

    test('rejects duplicate ids', () async {
      final store = MemoryDatasetStore();
      await store.add(_entry('a'));
      expect(
        () => store.add(_entry('a')),
        throwsA(isA<DuplicateEntryException>()),
      );
    });

    test('addAll consumes stream incrementally', () async {
      final store = MemoryDatasetStore();
      Stream<DatasetEntry> generate() async* {
        for (var i = 0; i < 100; i++) {
          yield _entry('id-$i');
        }
      }

      await store.addAll(generate());
      expect(store.length, 100);
      expect(await store.get('id-50'), isNotNull);
    });
  });

  group('DatasetQuery', () {
    late MemoryDatasetStore store;

    setUp(() async {
      store = MemoryDatasetStore();
      await store.addAll(
        Stream.fromIterable([
          _entry(
            'c1',
            language: 'en',
            type: DatasetEntryType.text,
            source: 'wiki',
            metadata: {'topic': 'geo'},
            createdAt: DateTime.utc(2024, 1, 1),
          ),
          _entry(
            'c2',
            language: 'fr',
            type: DatasetEntryType.chat,
            dataset: 'other',
            datasetVersion: 'v2',
            variationGroup: 'g2',
            source: 'books',
            metadata: {'topic': 'lit'},
            createdAt: DateTime.utc(2024, 1, 3),
          ),
          _entry(
            'v1',
            variationIndex: 1,
            parentEntryId: 'c1',
            source: 'wiki',
            createdAt: DateTime.utc(2024, 1, 2),
          ),
        ]),
      );
    });

    test('filters by dataset', () async {
      final ids = await store
          .query()
          .dataset('other')
          .stream()
          .map((e) => e.id)
          .toList();
      expect(ids, ['c2']);
    });

    test('filters by datasetVersion', () async {
      expect(await store.query().datasetVersion('v2').toList(), hasLength(1));
    });

    test('filters by language', () async {
      expect(await store.query().language('fr').toList(), hasLength(1));
    });

    test('filters by type', () async {
      expect(
        await store.query().type(DatasetEntryType.chat).toList(),
        hasLength(1),
      );
    });

    test('filters by variationGroup', () async {
      expect(await store.query().variationGroup('g1').toList(), hasLength(2));
    });

    test('filters by source', () async {
      expect(await store.query().source('books').toList(), hasLength(1));
    });

    test('filters by parentEntry', () async {
      expect(await store.query().parentEntry('c1').toList(), hasLength(1));
    });

    test('filters by metadata', () async {
      expect(
        await store.query().metadata('topic', 'geo').toList(),
        hasLength(1),
      );
    });

    test('canonicalOnly and variations(false)', () async {
      expect(await store.query().canonicalOnly().toList(), hasLength(2));
      expect(await store.query().variations(false).toList(), hasLength(2));
      expect(await store.query().canonicalOnly(false).toList(), hasLength(1));
    });

    test('combines filters with limit and offset', () async {
      final result = await store
          .query()
          .dataset('general')
          .language('en')
          .orderByCreatedAt(ascending: true)
          .offset(1)
          .limit(1)
          .toList();
      expect(result, hasLength(1));
      expect(result.single.id, 'v1');
    });

    test('orderByCreatedAt descending', () async {
      final ids = await store
          .query()
          .orderByCreatedAt(ascending: false)
          .stream()
          .map((e) => e.id)
          .toList();
      expect(ids, ['c2', 'v1', 'c1']);
    });

    test('onePerVariationGroup and sample', () async {
      final one = await store.query().onePerVariationGroup().toList();
      expect(one.map((e) => e.variationGroup).toSet(), hasLength(2));
      expect(one, hasLength(2));

      final sampled = await store.query().sample(2, seed: 4).toList();
      final again = await store.query().sample(2, seed: 4).toList();
      expect(sampled.map((e) => e.id), again.map((e) => e.id));
    });
  });
}
