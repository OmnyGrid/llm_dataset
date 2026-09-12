import 'dart:async';
import 'dart:math';

import '../model/dataset_entry.dart';
import '../query/dataset_query.dart';
import '../store/dataset_store.dart';
import 'curriculum_manifest.dart';
import 'curriculum_metadata.dart';

/// Interleaves primary and review stage entry streams per mixing policy.
abstract final class CurriculumMixing {
  /// Default batch size when constructing mixed streams without an explicit size.
  static const defaultBatchSize = 32;

  /// Builds a query for entries tagged with [stageId].
  static DatasetQuery stageQuery(DatasetStore store, String stageId) {
    return store.query().metadata(
      CurriculumMetadataKeys.curriculumStage,
      stageId,
    );
  }

  /// Yields mixed batches of [batchSize] where roughly [reviewRatio] entries
  /// come from [review] and the rest from [primary].
  static Stream<List<DatasetEntry>> mixedBatches({
    required Stream<DatasetEntry> primary,
    required Stream<DatasetEntry> review,
    required double reviewRatio,
    required int batchSize,
    int? seed,
    int? limit,
  }) async* {
    if (batchSize <= 0) {
      throw ArgumentError.value(batchSize, 'batchSize', 'must be > 0');
    }
    if (reviewRatio <= 0) {
      yield* _singleStreamBatches(primary, batchSize, limit: limit);
      return;
    }
    if (reviewRatio >= 1) {
      yield* _singleStreamBatches(review, batchSize, limit: limit);
      return;
    }

    final primaryIter = StreamIterator(primary);
    final reviewIter = StreamIterator(review);
    var primaryReady = await primaryIter.moveNext();
    var reviewReady = await reviewIter.moveNext();
    var emitted = 0;
    var batchIndex = 0;

    while ((primaryReady || reviewReady) &&
        (limit == null || emitted < limit)) {
      final reviewTarget = min(
        (batchSize * reviewRatio).round(),
        limit == null ? batchSize : limit - emitted,
      );
      var primaryTarget = min(
        batchSize - reviewTarget,
        limit == null ? batchSize : limit - emitted - reviewTarget,
      );
      if (primaryTarget < 0) {
        primaryTarget = 0;
      }

      final batch = <DatasetEntry>[];
      for (var i = 0; i < reviewTarget && reviewReady; i++) {
        batch.add(reviewIter.current);
        reviewReady = await reviewIter.moveNext();
      }
      for (var i = 0; i < primaryTarget && primaryReady; i++) {
        batch.add(primaryIter.current);
        primaryReady = await primaryIter.moveNext();
      }

      if (batch.isEmpty) {
        break;
      }

      final random = Random((seed ?? 0) + batchIndex);
      batch.shuffle(random);
      batchIndex++;

      if (limit != null && emitted + batch.length > limit) {
        yield batch.take(limit - emitted).toList();
        break;
      }

      yield batch;
      emitted += batch.length;
    }
  }

  /// Flattens [mixedBatches] into a single entry stream.
  static Stream<DatasetEntry> mixedStream({
    required Stream<DatasetEntry> primary,
    required Stream<DatasetEntry> review,
    required double reviewRatio,
    int batchSize = defaultBatchSize,
    int? seed,
    int? limit,
  }) async* {
    await for (final batch in mixedBatches(
      primary: primary,
      review: review,
      reviewRatio: reviewRatio,
      batchSize: batchSize,
      seed: seed,
      limit: limit,
    )) {
      for (final entry in batch) {
        yield entry;
      }
    }
  }

  /// Resolves primary and review queries from [stage] in [manifest].
  static ({
    DatasetQuery primary,
    List<DatasetQuery> reviewQueries,
    CurriculumMixingPolicy mixing,
  })
  resolveQueries({
    required DatasetStore store,
    required CurriculumManifest manifest,
    required String stageId,
  }) {
    final stage = manifest.stage(stageId);
    final primary = stageQuery(store, stageId);
    final reviewQueries = [
      for (final reviewStage in stage.mixing.reviewStages)
        stageQuery(store, reviewStage),
    ];
    return (
      primary: primary,
      reviewQueries: reviewQueries,
      mixing: stage.mixing,
    );
  }

  /// Merged review stream from multiple review stage queries.
  static Stream<DatasetEntry> mergedReviewStream(
    List<DatasetQuery> reviewQueries,
  ) async* {
    for (final query in reviewQueries) {
      yield* query.stream();
    }
  }

  static Stream<List<DatasetEntry>> _singleStreamBatches(
    Stream<DatasetEntry> stream,
    int batchSize, {
    int? limit,
  }) async* {
    final buffer = <DatasetEntry>[];
    var emitted = 0;
    await for (final entry in stream) {
      if (limit != null && emitted >= limit) {
        break;
      }
      buffer.add(entry);
      emitted++;
      if (buffer.length >= batchSize) {
        yield List<DatasetEntry>.from(buffer);
        buffer.clear();
      }
    }
    if (buffer.isNotEmpty && (limit == null || emitted <= (limit))) {
      yield buffer;
    }
  }
}
