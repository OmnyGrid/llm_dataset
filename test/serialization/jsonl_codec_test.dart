import 'dart:io';

import 'package:llm_dataset/llm_dataset.dart';
import 'package:test/test.dart';

void main() {
  test('JSONL round trip preserves fields', () async {
    final dir = await Directory.systemTemp.createTemp('llm_dataset_codec_');
    addTearDown(() async {
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    });

    final path = '${dir.path}/out.jsonl';
    final entries = [
      DatasetEntry(
        id: '1',
        dataset: 'd',
        datasetVersion: 'v1',
        type: DatasetEntryType.toolCall,
        language: 'en',
        input: 'weather?',
        output: '20C',
        thinking: 'call tool',
        variationGroup: 'g',
        variationIndex: 0,
        metadata: {
          datasetMessagesMetadataKey: [
            {
              'role': 'assistant',
              'tool_calls': [
                {
                  'name': 'get_weather',
                  'arguments': {'city': 'Paris'},
                },
              ],
            },
          ],
        },
        provenance: const DatasetProvenance(
          source: 's',
          generator: 'g',
          pipelineVersion: 'p',
        ),
        createdAt: DateTime.utc(2024, 2, 3, 4, 5, 6),
      ),
      DatasetEntry(
        id: '2',
        dataset: 'd',
        type: DatasetEntryType.text,
        language: 'fr',
        input: 'bonjour',
        variationGroup: 'g',
        variationIndex: 1,
        provenance: const DatasetProvenance(parentEntryId: '1'),
        createdAt: DateTime.utc(2024, 2, 3, 4, 5, 7),
      ),
    ];

    const exporter = DatasetExporter();
    const importer = DatasetImporter();
    await exporter.writeJsonlFile(Stream.fromIterable(entries), path);

    final restored = await importer.readJsonlFile(path).toList();
    expect(restored, hasLength(2));
    expect(restored[0].toolCalls.single.name, 'get_weather');
    expect(restored[0].provenance?.pipelineVersion, 'p');
    expect(restored[1].variationIndex, 1);
    expect(restored[1].provenance?.parentEntryId, '1');

    final json = await exporter.toJson(Stream.fromIterable(entries));
    expect(importer.fromJson(json), hasLength(2));
  });

  test('large JSONL streams line by line', () async {
    final dir = await Directory.systemTemp.createTemp('llm_dataset_codec_big_');
    addTearDown(() async {
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    });
    final path = '${dir.path}/big.jsonl';
    final sink = File(path).openWrite();
    const exporter = DatasetExporter();
    for (var i = 0; i < 300; i++) {
      sink.writeln(
        exporter.entryToJsonString(
          DatasetEntry(
            id: '$i',
            dataset: 'd',
            type: DatasetEntryType.text,
            language: 'en',
            input: 'x$i',
            variationGroup: 'g$i',
            variationIndex: 0,
            createdAt: DateTime.utc(2024),
          ),
        ),
      );
    }
    await sink.close();

    var count = 0;
    await for (final _ in const DatasetImporter().readJsonlFile(path)) {
      count++;
    }
    expect(count, 300);
  });
}
