import '../model/dataset_entry.dart';
import '../store/dataset_store.dart';
import '../training/dataset.dart';
import 'curriculum_manifest.dart';
import 'curriculum_mixing.dart';

/// Training consumption API for curriculum-tagged dataset slices.
class CurriculumDataset {
  /// Creates a curriculum dataset view.
  CurriculumDataset({required this.store, required this.manifest});

  /// Underlying entry store.
  final DatasetStore store;

  /// Curriculum manifest describing stages and mixing.
  final CurriculumManifest manifest;

  /// Entries tagged exclusively for [stageId].
  Dataset exclusive(String stageId) {
    _assertKnownStage(stageId);
    return Dataset(
      store: store,
      query: CurriculumMixing.stageQuery(store, stageId),
    );
  }

  /// Entries for [stageId] mixed with configured review stages.
  ///
  /// When the stage mixing mode is `exclusive`, behaves like [exclusive].
  Dataset mixed(String stageId, {int? seed}) {
    final stage = manifest.stage(stageId);
    if (stage.mixing.isExclusive) {
      return exclusive(stageId);
    }
    return Dataset(
      store: store,
      query: CurriculumMixing.stageQuery(store, stageId),
    );
  }

  /// Streams entries for a training phase honoring mixing policy.
  Stream<DatasetEntry> streamPhase(String stageId, {int? seed, int? limit}) {
    final stage = manifest.stage(stageId);
    if (stage.mixing.isExclusive) {
      var query = CurriculumMixing.stageQuery(store, stageId);
      if (limit != null) {
        query = query.limit(limit);
      }
      return query.stream();
    }

    final resolved = CurriculumMixing.resolveQueries(
      store: store,
      manifest: manifest,
      stageId: stageId,
    );

    final primaryStream = resolved.primary.stream();
    final reviewStream = CurriculumMixing.mergedReviewStream(
      resolved.reviewQueries,
    );

    return CurriculumMixing.mixedStream(
      primary: primaryStream,
      review: reviewStream,
      reviewRatio: resolved.mixing.reviewRatio,
      seed: seed,
      limit: limit,
    );
  }

  /// Streams fixed-size batches for a training phase.
  Stream<List<DatasetEntry>> batchesPhase(
    String stageId,
    int batchSize, {
    int? seed,
    int? limit,
  }) async* {
    if (batchSize <= 0) {
      throw ArgumentError.value(batchSize, 'batchSize', 'must be > 0');
    }

    final stage = manifest.stage(stageId);
    if (stage.mixing.isExclusive) {
      yield* exclusive(stageId).batches(batchSize, seed: seed, limit: limit);
      return;
    }

    final resolved = CurriculumMixing.resolveQueries(
      store: store,
      manifest: manifest,
      stageId: stageId,
    );

    yield* CurriculumMixing.mixedBatches(
      primary: resolved.primary.stream(),
      review: CurriculumMixing.mergedReviewStream(resolved.reviewQueries),
      reviewRatio: resolved.mixing.reviewRatio,
      batchSize: batchSize,
      seed: seed,
      limit: limit,
    );
  }

  void _assertKnownStage(String stageId) {
    manifest.stage(stageId);
  }
}
