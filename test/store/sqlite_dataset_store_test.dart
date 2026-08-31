import 'dart:io';

import 'package:llm_dataset/llm_dataset.dart';
import 'package:test/test.dart';

DatasetEntry e(
  String id, {
  String dataset = 'general',
  String? datasetVersion = 'v1',
  String language = 'en',
  DatasetEntryType type = DatasetEntryType.text,
  String group = 'g1',
  int index = 0,
  String? parent,
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
    input: 'in-$id',
    output: 'out-$id',
    variationGroup: group,
    variationIndex: index,
    metadata: metadata,
    provenance: DatasetProvenance(source: source, parentEntryId: parent),
    createdAt: createdAt ?? DateTime.utc(2024, 1, 1),
  );
}

void main() {
  late Directory tempDir;
  late SqliteDatasetStore store;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('llm_dataset_sqlite_');
    store = SqliteDatasetStore('${tempDir.path}/test.db');
  });

  tearDown(() async {
    store.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('persists and reloads entries with provenance/metadata', () async {
    await store.add(e('a', source: 'wiki', metadata: {'k': 'v'}, parent: null));
    final loaded = await store.get('a');
    expect(loaded?.metadata['k'], 'v');
    expect(loaded?.provenance?.source, 'wiki');

    final reopened = SqliteDatasetStore('${tempDir.path}/test.db');
    addTearDown(reopened.close);
    expect(await reopened.get('a'), isNotNull);
  });

  test('indexes support filtered queries', () async {
    await store.addAll(
      Stream.fromIterable([
        e('c1', source: 'wiki', createdAt: DateTime.utc(2024, 1, 1)),
        e(
          'v1',
          index: 1,
          parent: 'c1',
          source: 'wiki',
          createdAt: DateTime.utc(2024, 1, 2),
        ),
        e(
          'c2',
          group: 'g2',
          language: 'fr',
          type: DatasetEntryType.chat,
          datasetVersion: 'v2',
          source: 'books',
          metadata: {'topic': 'lit'},
          createdAt: DateTime.utc(2024, 1, 3),
        ),
      ]),
    );

    expect(await store.query().dataset('general').toList(), hasLength(3));
    expect(await store.query().datasetVersion('v2').toList(), hasLength(1));
    expect(await store.query().language('fr').toList(), hasLength(1));
    expect(
      await store.query().type(DatasetEntryType.chat).toList(),
      hasLength(1),
    );
    expect(await store.query().variationGroup('g1').toList(), hasLength(2));
    expect(await store.query().source('books').toList(), hasLength(1));
    expect(await store.query().parentEntry('c1').toList(), hasLength(1));
    expect(await store.query().metadata('topic', 'lit').toList(), hasLength(1));
    expect(await store.query().canonicalOnly().toList(), hasLength(2));
    expect(await store.query().onePerVariationGroup().toList(), hasLength(2));
  });

  test('rejects duplicate ids', () async {
    await store.add(e('dup'));
    expect(() => store.add(e('dup')), throwsA(isA<DuplicateEntryException>()));
  });

  test('deterministic sample', () async {
    await store.addAll(
      Stream.fromIterable([
        for (var i = 0; i < 20; i++) e('id-$i', group: 'g-$i'),
      ]),
    );
    final a = await store.query().sample(5, seed: 3).toList();
    final b = await store.query().sample(5, seed: 3).toList();
    expect(a.map((e) => e.id), b.map((e) => e.id));
    expect(a, hasLength(5));
  });

  test('addAllBatched commits in chunks without duplicate probes', () async {
    store.configureForBulkInsert(cacheSizeKiB: 2048);
    await store.addAllBatched(
      Stream.fromIterable([for (var i = 0; i < 25; i++) e('batch-$i')]),
      batchSize: 10,
    );
    expect(await store.get('batch-0'), isNotNull);
    expect(await store.get('batch-24'), isNotNull);
  });

  test('addAllBatched can enforce duplicate ids when requested', () async {
    await store.add(e('dup-batch'));
    expect(
      () => store.addAllBatched(
        Stream.fromIterable([e('dup-batch'), e('unique-batch')]),
        checkDuplicates: true,
      ),
      throwsA(isA<DuplicateEntryException>()),
    );
    expect(await store.get('unique-batch'), isNull);
  });
}
