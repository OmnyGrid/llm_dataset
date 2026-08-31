import 'package:llm_dataset/llm_dataset.dart';
import 'package:test/test.dart';

import '../../example/adapters/progress_phrase_stream.dart';

void main() {
  test('logCombinatorialProgress prints and forwards every entry', () async {
    final entries = [
      DatasetEntry(
        id: 'c1',
        dataset: 'd',
        type: DatasetEntryType.text,
        language: 'en',
        input: 'The developer writes code.',
        output: 'The developer writes code.',
        variationGroup: 'g1',
        variationIndex: 0,
        createdAt: DateTime.utc(2024),
      ),
      DatasetEntry(
        id: 'v1',
        dataset: 'd',
        type: DatasetEntryType.text,
        language: 'en',
        input: 'The engineer writes code.',
        output: 'The engineer writes code.',
        variationGroup: 'g1',
        variationIndex: 1,
        provenance: const DatasetProvenance(parentEntryId: 'c1'),
        createdAt: DateTime.utc(2024),
      ),
    ];

    final forwarded = await logCombinatorialProgress(
      entries: Stream.fromIterable(entries),
      totalExpected: 2,
      templateExpected: 2,
      templateId: 'demo',
      templateIndex: 0,
      templateCount: 1,
      entriesBeforeTemplate: 0,
      summaryEvery: 0,
    ).toList();

    expect(forwarded, entries);
  });
}
