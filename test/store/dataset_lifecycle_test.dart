import 'dart:io';

import 'package:llm_dataset/llm_dataset.dart';
import 'package:test/test.dart';

void main() {
  group('DatasetLifecycle', () {
    test('lists datasets versions export and delete on memory store', () async {
      final store = MemoryDatasetStore();
      await store.add(
        DatasetEntry(
          id: '1',
          dataset: 'geo',
          datasetVersion: 'v1',
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
        ),
      );
      await store.add(
        DatasetEntry(
          id: '2',
          dataset: 'geo',
          datasetVersion: 'v2',
          type: DatasetEntryType.text,
          language: 'en',
          input: 'in2',
          output: 'out2',
          metadata: const {},
          provenance: const DatasetProvenance(
            sourceId: 's',
            generator: 'g',
            generatorVersion: '1',
            pipelineVersion: 'p',
          ),
          variationGroup: 'g2',
          variationIndex: 0,
          createdAt: DateTime.utc(2026),
        ),
      );

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
  });
}
