import 'dart:io';

import 'package:llm_dataset/llm_dataset.dart';
import 'package:test/test.dart';

DatasetEntry _entry(String id, {String datasetVersion = 'v1'}) {
  return DatasetEntry(
    id: id,
    dataset: 'geo',
    datasetVersion: datasetVersion,
    type: DatasetEntryType.text,
    language: 'en',
    input: 'in',
    output: 'out',
    metadata: const {},
    provenance: const DatasetProvenance(
      sourceId: 's',
      generator: 'g',
      generatorVersion: '1',
      pipelineVersion: 'p',
    ),
    variationGroup: 'g1',
    variationIndex: 0,
    createdAt: DateTime.utc(2026),
  );
}

void main() {
  group('DatasetLifecycle', () {
    test('lists datasets versions export and delete on memory store', () async {
      final store = MemoryDatasetStore();
      await store.add(_entry('1'));
      await store.add(_entry('2', datasetVersion: 'v2'));

      final lifecycle = DatasetLifecycle(store);
      expect(await lifecycle.listDatasets(), ['geo']);
      expect(await lifecycle.listVersions('geo'), ['v1', 'v2']);

      final exportPath =
          '${Directory.systemTemp.path}/lifecycle_export_${DateTime.now().microsecondsSinceEpoch}.jsonl';
      await lifecycle.exportJsonl(exportPath, dataset: 'geo', version: 'v1');
      final lines = await File(exportPath).readAsLines();
      expect(lines, hasLength(1));
      await File(exportPath).delete();

      final deleted = await lifecycle.deleteDataset('geo', version: 'v1');
      expect(deleted, 1);
      expect(await store.query().dataset('geo').toList(), hasLength(1));
    });

    test('deleteDataset on sqlite removes targeted version', () async {
      final dbFile = File(
        '${Directory.systemTemp.path}/lifecycle_sqlite_${DateTime.now().microsecondsSinceEpoch}.db',
      );
      final store = SqliteDatasetStore(dbFile.path);
      addTearDown(() {
        store.close();
        if (dbFile.existsSync()) {
          dbFile.deleteSync();
        }
      });

      await store.add(_entry('1'));
      await store.add(_entry('2', datasetVersion: 'v2'));

      final lifecycle = DatasetLifecycle(store);
      expect(await lifecycle.listDatasets(), ['geo']);

      final deleted = await lifecycle.deleteDataset('geo', version: 'v1');
      expect(deleted, 1);
      expect(await store.query().datasetVersion('v2').toList(), hasLength(1));
    });

    test('count and export respect version filters on memory store', () async {
      final store = MemoryDatasetStore();
      await store.add(_entry('1'));
      await store.add(_entry('2', datasetVersion: 'v2'));
      await store.add(
        _entry(
          '3',
          datasetVersion: 'v2',
        ).copyWith(clearDatasetVersion: true, id: '3', variationGroup: 'g3'),
      );

      final lifecycle = DatasetLifecycle(store);
      expect(await lifecycle.count(dataset: 'geo'), 3);
      expect(await lifecycle.count(dataset: 'geo', version: 'v1'), 1);
      expect(await lifecycle.count(dataset: 'geo', unversionedOnly: true), 1);

      final exportPath =
          '${Directory.systemTemp.path}/lifecycle_count_${DateTime.now().microsecondsSinceEpoch}.jsonl';
      await lifecycle.exportJsonl(
        exportPath,
        dataset: 'geo',
        unversionedOnly: true,
      );
      expect(await File(exportPath).readAsLines(), hasLength(1));
      await File(exportPath).delete();
    });

    test('deleteDataset removes all versions when version omitted', () async {
      final store = MemoryDatasetStore();
      await store.add(_entry('1'));
      await store.add(_entry('2', datasetVersion: 'v2'));

      final lifecycle = DatasetLifecycle(store);
      expect(await lifecycle.deleteDataset('geo'), 2);
      expect(store.length, 0);
    });

    test('sqlite count matches memory semantics', () async {
      final dbFile = File(
        '${Directory.systemTemp.path}/lifecycle_count_sqlite_${DateTime.now().microsecondsSinceEpoch}.db',
      );
      final store = SqliteDatasetStore(dbFile.path);
      addTearDown(() {
        store.close();
        if (dbFile.existsSync()) dbFile.deleteSync();
      });

      await store.add(_entry('1'));
      await store.add(_entry('2', datasetVersion: 'v2'));

      final lifecycle = DatasetLifecycle(store);
      expect(await lifecycle.count(dataset: 'geo', version: 'v2'), 1);
      expect(await lifecycle.listVersions('geo'), ['v1', 'v2']);
    });
  });
}
