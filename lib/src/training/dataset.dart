import '../model/dataset_entry.dart';
import '../query/dataset_query.dart';
import '../store/dataset_store.dart';
import '../util/ids.dart';

/// Dataset consumption API for training packages.
///
/// Provides streaming, batching, shuffling, sampling, and variation-aware
/// selection. Contains no model-training logic.
class Dataset {
  /// Creates a consumption view over [store].
  Dataset({
    required this.store,
    this.variationSelection = VariationSelection.all,
    this.query,
  });

  /// Underlying entry store.
  final DatasetStore store;

  /// Default variation selection for [stream] / [batches].
  final VariationSelection variationSelection;

  /// Optional base query filters applied before streaming.
  final DatasetQuery? query;

  /// Streams entries for training.
  Stream<DatasetEntry> stream({
    VariationSelection? variationSelection,
    bool shuffle = false,
    int? seed,
    int? sample,
    int? limit,
  }) async* {
    var q = (query ?? store.query()).variationSelection(
      variationSelection ?? this.variationSelection,
    );
    if (sample != null) {
      q = q.sample(sample, seed: seed);
    }
    if (limit != null) {
      q = q.limit(limit);
    }

    var entries = await q.toList();
    if (shuffle) {
      entries = seededShuffle(entries, seed ?? 0);
    }
    for (final entry in entries) {
      yield entry;
    }
  }

  /// Streams fixed-size batches without materializing the full dataset beyond
  /// the active query result set required for shuffle/sample.
  Stream<List<DatasetEntry>> batches(
    int size, {
    VariationSelection? variationSelection,
    bool shuffle = false,
    int? seed,
    int? sample,
    int? limit,
  }) async* {
    if (size <= 0) {
      throw ArgumentError.value(size, 'size', 'must be > 0');
    }
    final buffer = <DatasetEntry>[];
    await for (final entry in stream(
      variationSelection: variationSelection,
      shuffle: shuffle,
      seed: seed,
      sample: sample,
      limit: limit,
    )) {
      buffer.add(entry);
      if (buffer.length >= size) {
        yield List<DatasetEntry>.from(buffer);
        buffer.clear();
      }
    }
    if (buffer.isNotEmpty) {
      yield List<DatasetEntry>.from(buffer);
    }
  }
}
