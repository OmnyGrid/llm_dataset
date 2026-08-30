/// Fluent queries: filters, canonical-only, one-per-group, sampling, ordering.
library;

import 'package:llm_dataset/llm_dataset.dart';

Future<void> main() async {
  final store = MemoryDatasetStore();
  await store.addAll(
    Stream.fromIterable([
      for (var g = 0; g < 4; g++) ...[
        DatasetEntry(
          id: 'c$g',
          dataset: 'qa',
          datasetVersion: 'v1',
          type: DatasetEntryType.text,
          language: g.isEven ? 'en' : 'fr',
          input: 'question $g',
          output: 'answer $g',
          variationGroup: 'group-$g',
          variationIndex: 0,
          metadata: {'difficulty': g % 2 == 0 ? 'easy' : 'hard'},
          createdAt: DateTime.utc(2024, 1, g + 1),
        ),
        DatasetEntry(
          id: 'v$g',
          dataset: 'qa',
          datasetVersion: 'v1',
          type: DatasetEntryType.text,
          language: g.isEven ? 'en' : 'fr',
          input: 'alt question $g',
          output: 'answer $g',
          variationGroup: 'group-$g',
          variationIndex: 1,
          provenance: DatasetProvenance(parentEntryId: 'c$g'),
          metadata: {'difficulty': g % 2 == 0 ? 'easy' : 'hard'},
          createdAt: DateTime.utc(2024, 1, g + 1, 12),
        ),
      ],
    ]),
  );

  print('== Canonical English entries ==');
  final canonicalEn = await store
      .query()
      .dataset('qa')
      .language('en')
      .canonicalOnly()
      .orderByCreatedAt()
      .toList();
  print(canonicalEn.map((e) => e.id).join(', '));

  print('== Metadata filter (easy) ==');
  final easy = await store.query().metadata('difficulty', 'easy').toList();
  print(
    'count=${easy.length} groups=${easy.map((e) => e.variationGroup).toSet()}',
  );

  print('== One variation per group ==');
  final onePerGroup = await store.query().onePerVariationGroup().toList();
  print(onePerGroup.map((e) => '${e.variationGroup}:${e.id}').join('\n'));

  print('== Seeded sample of 3 ==');
  final sample = await store.query().sample(3, seed: 7).toList();
  final again = await store.query().sample(3, seed: 7).toList();
  print('sample=${sample.map((e) => e.id).join(', ')}');
  print('repeat=${again.map((e) => e.id).join(', ')}');

  print('== Training stream: shuffle + limit ==');
  final dataset = Dataset(
    store: store,
    query: store.query().language('en'),
    variationSelection: VariationSelection.onePerGroup,
  );
  await for (final entry in dataset.stream(shuffle: true, seed: 42, limit: 2)) {
    print('train: ${entry.id}');
  }
}
