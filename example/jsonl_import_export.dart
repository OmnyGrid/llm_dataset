/// Round-trip dataset entries through JSONL on disk.
library;

import 'dart:io';

import 'package:llm_dataset/llm_dataset.dart';

Future<void> main() async {
  final tempDir = await Directory.systemTemp.createTemp('llm_dataset_jsonl_');
  final jsonlPath = '${tempDir.path}/entries.jsonl';

  final store = MemoryDatasetStore();
  await store.addAll(
    Stream.fromIterable([
      DatasetEntry(
        id: 'e1',
        dataset: 'demo',
        datasetVersion: 'v1',
        type: DatasetEntryType.text,
        language: 'en',
        input: 'What is 2 + 2?',
        output: '4',
        variationGroup: 'math-1',
        variationIndex: 0,
        metadata: {'topic': 'math'},
        provenance: DatasetProvenance(source: 'manual', generator: 'example'),
        createdAt: DateTime.utc(2024, 6, 1),
      ),
      DatasetEntry(
        id: 'e2',
        dataset: 'demo',
        datasetVersion: 'v1',
        type: DatasetEntryType.text,
        language: 'en',
        input: 'In other words: What is 2 + 2?',
        output: '4',
        variationGroup: 'math-1',
        variationIndex: 1,
        provenance: DatasetProvenance(
          parentEntryId: 'e1',
          transformation: 'paraphrase',
        ),
        createdAt: DateTime.utc(2024, 6, 1, 1),
      ),
    ]),
  );

  print('== Export store → JSONL ==');
  final exporter = DatasetExporter();
  await exporter.writeJsonlFile(store.stream(), jsonlPath);
  print(await File(jsonlPath).readAsString());

  print('== Import JSONL → new store ==');
  final importer = DatasetImporter();
  final imported = MemoryDatasetStore();
  await imported.addAll(importer.readJsonlFile(jsonlPath));

  print('imported=${imported.length}');
  for (final entry in await imported.query().orderByCreatedAt().toList()) {
    print(
      '${entry.id} idx=${entry.variationIndex} '
      'parent=${entry.provenance?.parentEntryId}',
    );
  }

  await tempDir.delete(recursive: true);
}
