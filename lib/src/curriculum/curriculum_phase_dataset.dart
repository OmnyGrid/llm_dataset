import '../model/dataset_entry.dart';
import '../query/dataset_query.dart';
import '../training/dataset.dart';
import 'curriculum_manifest.dart';
import 'curriculum_mixing.dart';

/// A [Dataset] view for one curriculum stage, including mixed review interleaving.
///
/// Returned by [CurriculumDataset.mixed]. For mixed stages, [stream] and
/// [batches] honor the manifest mixing policy (primary + review ratio). Use
/// [CurriculumDataset.streamPhase] / [batchesPhase] when you do not need a
/// [Dataset] wrapper.
class CurriculumPhaseDataset extends Dataset {
  /// Creates a phase dataset view.
  CurriculumPhaseDataset({
    required super.store,
    required this.manifest,
    required this.stageId,
    this.mixingSeed,
    super.variationSelection,
  }) : super(query: CurriculumMixing.stageQuery(store, stageId));

  /// Curriculum manifest.
  final CurriculumManifest manifest;

  /// Stage id for this view.
  final String stageId;

  /// Default seed for mixed interleaving when [stream] / [batches] omit [seed].
  final int? mixingSeed;

  bool get _isMixed => manifest.stage(stageId).mixing.isMixed;

  @override
  Stream<DatasetEntry> stream({
    VariationSelection? variationSelection,
    bool shuffle = false,
    int? seed,
    int? sample,
    int? limit,
  }) {
    if (!_isMixed) {
      return super.stream(
        variationSelection: variationSelection,
        shuffle: shuffle,
        seed: seed,
        sample: sample,
        limit: limit,
      );
    }
    if (shuffle || sample != null) {
      throw ArgumentError(
        'shuffle and sample are not supported for mixed curriculum phases; '
        'use exclusive() or streamPhase() instead.',
      );
    }

    final resolved = CurriculumMixing.resolveQueries(
      store: store,
      manifest: manifest,
      stageId: stageId,
    );

    return CurriculumMixing.mixedStream(
      primary: resolved.primary.stream(),
      review: CurriculumMixing.mergedReviewStream(resolved.reviewQueries),
      reviewRatio: resolved.mixing.reviewRatio,
      seed: seed ?? mixingSeed,
      limit: limit,
    );
  }

  @override
  Stream<List<DatasetEntry>> batches(
    int size, {
    VariationSelection? variationSelection,
    bool shuffle = false,
    int? seed,
    int? sample,
    int? limit,
  }) {
    if (!_isMixed) {
      return super.batches(
        size,
        variationSelection: variationSelection,
        shuffle: shuffle,
        seed: seed,
        sample: sample,
        limit: limit,
      );
    }
    if (shuffle || sample != null) {
      throw ArgumentError(
        'shuffle and sample are not supported for mixed curriculum phases; '
        'use exclusive() or batchesPhase() instead.',
      );
    }

    final resolved = CurriculumMixing.resolveQueries(
      store: store,
      manifest: manifest,
      stageId: stageId,
    );

    return CurriculumMixing.mixedBatches(
      primary: resolved.primary.stream(),
      review: CurriculumMixing.mergedReviewStream(resolved.reviewQueries),
      reviewRatio: resolved.mixing.reviewRatio,
      batchSize: size,
      seed: seed ?? mixingSeed,
      limit: limit,
    );
  }
}
