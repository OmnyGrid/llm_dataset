import 'package:llm_dataset/llm_dataset.dart';
import 'package:test/test.dart';

void main() {
  late MemoryDatasetStore store;

  setUp(() async {
    store = MemoryDatasetStore();
    await store.addAll(
      Stream.fromIterable([
        for (var g = 0; g < 5; g++) ...[
          DatasetEntry(
            id: 'c$g',
            dataset: 'd',
            type: DatasetEntryType.text,
            language: 'en',
            input: 'q$g',
            output: 'a$g',
            variationGroup: 'group-$g',
            variationIndex: 0,
            createdAt: DateTime.utc(2024, 1, g + 1),
          ),
          DatasetEntry(
            id: 'v$g',
            dataset: 'd',
            type: DatasetEntryType.text,
            language: 'en',
            input: 'q$g?',
            output: 'a$g',
            variationGroup: 'group-$g',
            variationIndex: 1,
            provenance: DatasetProvenance(parentEntryId: 'c$g'),
            createdAt: DateTime.utc(2024, 1, g + 1, 1),
          ),
        ],
      ]),
    );
  });

  test('streams one per group', () async {
    final dataset = Dataset(
      store: store,
      variationSelection: VariationSelection.onePerGroup,
    );
    final entries = await dataset.stream().toList();
    expect(entries, hasLength(5));
    expect(entries.map((e) => e.variationGroup).toSet(), hasLength(5));
  });

  test('canonical only and batches', () async {
    final dataset = Dataset(
      store: store,
      variationSelection: VariationSelection.canonicalOnly,
    );
    final batches = await dataset.batches(2).toList();
    expect(batches.map((b) => b.length).reduce((a, b) => a + b), 5);
    expect(batches.first, hasLength(2));
  });

  test('deterministic shuffle/sample', () async {
    final dataset = Dataset(store: store);
    final a = await dataset
        .stream(shuffle: true, seed: 9)
        .map((e) => e.id)
        .toList();
    final b = await dataset
        .stream(shuffle: true, seed: 9)
        .map((e) => e.id)
        .toList();
    expect(a, b);

    final s1 = await dataset
        .stream(sample: 3, seed: 2)
        .map((e) => e.id)
        .toList();
    final s2 = await dataset
        .stream(sample: 3, seed: 2)
        .map((e) => e.id)
        .toList();
    expect(s1, s2);
    expect(s1, hasLength(3));
  });
}
