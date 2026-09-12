import 'package:llm_dataset/llm_dataset.dart';
import 'package:test/test.dart';

void main() {
  group('CurriculumMixing', () {
    DatasetEntry entry(String stage, String id) {
      return DatasetEntry(
        id: id,
        dataset: 'curriculum',
        type: DatasetEntryType.text,
        language: 'en',
        input: '$stage-$id',
        variationGroup: id,
        variationIndex: 0,
        metadata: {CurriculumMetadataKeys.curriculumStage: stage},
        createdAt: DateTime.utc(2026, 1, 1),
      );
    }

    test('stageQuery filters by curriculumStage metadata', () async {
      final store = MemoryDatasetStore();
      await store.addAll(
        Stream.fromIterable([
          entry('alpha', 'a1'),
          entry('beta', 'b1'),
          entry('alpha', 'a2'),
        ]),
      );

      final alpha = await CurriculumMixing.stageQuery(store, 'alpha').toList();
      expect(alpha, hasLength(2));
      expect(
        alpha.every((e) => e.metadata['curriculumStage'] == 'alpha'),
        isTrue,
      );
    });

    test('mixedStream with reviewRatio 0 yields primary only', () async {
      final primary = Stream.fromIterable([entry('p', '1'), entry('p', '2')]);
      final review = Stream.fromIterable([entry('r', '3')]);

      final result = await CurriculumMixing.mixedStream(
        primary: primary,
        review: review,
        reviewRatio: 0,
        batchSize: 2,
      ).toList();

      expect(result, hasLength(2));
      expect(result.every((e) => e.metadata['curriculumStage'] == 'p'), isTrue);
    });

    test('mixedStream with reviewRatio 1 yields review only', () async {
      final primary = Stream.fromIterable([entry('p', '1')]);
      final review = Stream.fromIterable([entry('r', '2'), entry('r', '3')]);

      final result = await CurriculumMixing.mixedStream(
        primary: primary,
        review: review,
        reviewRatio: 1,
        batchSize: 2,
      ).toList();

      expect(result, hasLength(2));
      expect(result.every((e) => e.metadata['curriculumStage'] == 'r'), isTrue);
    });

    test('mixedBatches respects limit', () async {
      final primary = Stream.fromIterable(
        List.generate(20, (i) => entry('p', 'p$i')),
      );
      final review = Stream.fromIterable(
        List.generate(20, (i) => entry('r', 'r$i')),
      );

      final batches = await CurriculumMixing.mixedBatches(
        primary: primary,
        review: review,
        reviewRatio: 0.2,
        batchSize: 10,
        seed: 1,
        limit: 15,
      ).toList();

      final total = batches.fold<int>(0, (sum, b) => sum + b.length);
      expect(total, 15);
    });

    test('mergedReviewStream concatenates review stage queries', () async {
      final store = MemoryDatasetStore();
      await store.addAll(
        Stream.fromIterable([entry('review_a', '1'), entry('review_b', '2')]),
      );

      final stream = CurriculumMixing.mergedReviewStream([
        CurriculumMixing.stageQuery(store, 'review_a'),
        CurriculumMixing.stageQuery(store, 'review_b'),
      ]);

      expect(await stream.toList(), hasLength(2));
    });
  });
}
