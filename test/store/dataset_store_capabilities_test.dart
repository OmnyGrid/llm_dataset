import 'dart:io';

import 'package:llm_dataset/llm_dataset.dart';
import 'package:test/test.dart';

void main() {
  group('DatasetStoreCapabilities', () {
    test('memory store scans metadata values', () async {
      final store = MemoryDatasetStore();
      await store.addAll(
        Stream.fromIterable([
          DatasetEntry(
            id: 'a',
            dataset: 'd',
            type: DatasetEntryType.text,
            language: 'en',
            input: 'a',
            variationGroup: 'g',
            variationIndex: 0,
            metadata: {CurriculumMetadataKeys.curriculumStage: 'alpha'},
            createdAt: DateTime.utc(2026),
          ),
          DatasetEntry(
            id: 'b',
            dataset: 'd',
            type: DatasetEntryType.text,
            language: 'en',
            input: 'b',
            variationGroup: 'g2',
            variationIndex: 0,
            metadata: {CurriculumMetadataKeys.curriculumStage: 'beta'},
            createdAt: DateTime.utc(2026),
          ),
        ]),
      );

      expect(store.supportsBulkInsert, isFalse);
      expect(
        await store.listDistinctMetadataValues(
          CurriculumMetadataKeys.curriculumStage,
        ),
        ['alpha', 'beta'],
      );
    });

    test('sqlite store uses indexed metadata lookup and bulk insert', () async {
      final dbFile = File(
        '${Directory.systemTemp.path}/capabilities_${DateTime.now().microsecondsSinceEpoch}.db',
      );
      final store = SqliteDatasetStore(dbFile.path);
      addTearDown(() {
        store.close();
        if (dbFile.existsSync()) {
          dbFile.deleteSync();
        }
      });

      expect(store.supportsBulkInsert, isTrue);
      store.configureBulkInsertIfSupported(cacheSizeKiB: 2048);

      await store.add(
        DatasetEntry(
          id: '1',
          dataset: 'd',
          type: DatasetEntryType.text,
          language: 'en',
          input: 'x',
          variationGroup: 'g',
          variationIndex: 0,
          metadata: {CurriculumMetadataKeys.curriculumStage: 'math'},
          createdAt: DateTime.utc(2026),
        ),
      );

      expect(
        await store.listDistinctMetadataValues(
          CurriculumMetadataKeys.curriculumStage,
        ),
        ['math'],
      );
    });

    test('configureBulkInsertIfSupported is no-op on memory store', () {
      final store = MemoryDatasetStore();
      expect(() => store.configureBulkInsertIfSupported(), returnsNormally);
    });
  });
}
