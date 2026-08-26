import '../model/dataset_entry.dart';
import '../model/dataset_entry_type.dart';
import '../store/dataset_store.dart';
import '../util/ids.dart';

/// How variation groups are selected in a query or training stream.
enum VariationSelection {
  /// Return every matching entry, including all variations.
  all,

  /// Return only canonical entries (`variationIndex == 0`, no parent).
  canonicalOnly,

  /// Return at most one entry per [DatasetEntry.variationGroup].
  onePerGroup,
}

/// Immutable filter / sampling specification for [DatasetQuery].
class DatasetQuerySpec {
  /// Creates a query specification.
  const DatasetQuerySpec({
    this.dataset,
    this.datasetVersion,
    this.language,
    this.type,
    this.variationGroup,
    this.source,
    this.parentEntryId,
    this.metadataKey,
    this.metadataValue,
    this.canonicalOnly,
    this.variationSelection = VariationSelection.all,
    this.limit,
    this.offset,
    this.orderByCreatedAtAscending,
    this.sampleCount,
    this.sampleSeed,
  });

  /// Dataset name filter.
  final String? dataset;

  /// Dataset version filter.
  final String? datasetVersion;

  /// Language filter.
  final String? language;

  /// Entry type filter.
  final DatasetEntryType? type;

  /// Variation group filter.
  final String? variationGroup;

  /// Provenance source filter.
  final String? source;

  /// Parent entry id filter.
  final String? parentEntryId;

  /// Metadata key that must exist.
  final String? metadataKey;

  /// Expected metadata value for [metadataKey].
  final Object? metadataValue;

  /// When non-null, restrict to canonical / non-canonical entries.
  final bool? canonicalOnly;

  /// Variation-aware selection mode.
  final VariationSelection variationSelection;

  /// Maximum rows after filtering / sampling.
  final int? limit;

  /// Rows to skip after ordering, before limit.
  final int? offset;

  /// When non-null, order by createdAt (then id).
  final bool? orderByCreatedAtAscending;

  /// When set, randomly sample this many entries (deterministic with seed).
  final int? sampleCount;

  /// Seed for [sampleCount] / one-per-group tie breaks.
  final int? sampleSeed;

  /// Whether [entry] matches field filters (ignores limit/offset/sample).
  bool matchesFilters(DatasetEntry entry) {
    if (dataset != null && entry.dataset != dataset) {
      return false;
    }
    if (datasetVersion != null && entry.datasetVersion != datasetVersion) {
      return false;
    }
    if (language != null && entry.language != language) {
      return false;
    }
    if (type != null && entry.type != type) {
      return false;
    }
    if (variationGroup != null && entry.variationGroup != variationGroup) {
      return false;
    }
    if (source != null && entry.provenance?.source != source) {
      return false;
    }
    if (parentEntryId != null &&
        entry.provenance?.parentEntryId != parentEntryId) {
      return false;
    }
    if (metadataKey != null) {
      if (!entry.metadata.containsKey(metadataKey) ||
          entry.metadata[metadataKey] != metadataValue) {
        return false;
      }
    }
    if (canonicalOnly != null && entry.isCanonical != canonicalOnly) {
      return false;
    }
    if (variationSelection == VariationSelection.canonicalOnly &&
        !entry.isCanonical) {
      return false;
    }
    return true;
  }

  /// Returns a copy with selected fields replaced.
  DatasetQuerySpec copyWith({
    String? dataset,
    String? datasetVersion,
    String? language,
    DatasetEntryType? type,
    String? variationGroup,
    String? source,
    String? parentEntryId,
    String? metadataKey,
    Object? metadataValue,
    bool? canonicalOnly,
    VariationSelection? variationSelection,
    int? limit,
    int? offset,
    bool? orderByCreatedAtAscending,
    int? sampleCount,
    int? sampleSeed,
    bool clearCanonicalOnly = false,
    bool clearSample = false,
  }) {
    return DatasetQuerySpec(
      dataset: dataset ?? this.dataset,
      datasetVersion: datasetVersion ?? this.datasetVersion,
      language: language ?? this.language,
      type: type ?? this.type,
      variationGroup: variationGroup ?? this.variationGroup,
      source: source ?? this.source,
      parentEntryId: parentEntryId ?? this.parentEntryId,
      metadataKey: metadataKey ?? this.metadataKey,
      metadataValue: metadataValue ?? this.metadataValue,
      canonicalOnly: clearCanonicalOnly
          ? null
          : (canonicalOnly ?? this.canonicalOnly),
      variationSelection: variationSelection ?? this.variationSelection,
      limit: limit ?? this.limit,
      offset: offset ?? this.offset,
      orderByCreatedAtAscending:
          orderByCreatedAtAscending ?? this.orderByCreatedAtAscending,
      sampleCount: clearSample ? null : (sampleCount ?? this.sampleCount),
      sampleSeed: clearSample ? null : (sampleSeed ?? this.sampleSeed),
    );
  }
}

/// Applies ordering, variation selection, sampling, offset, and limit in Dart.
List<DatasetEntry> applyQueryPostProcessing(
  List<DatasetEntry> filtered,
  DatasetQuerySpec spec,
) {
  var entries = List<DatasetEntry>.from(filtered);

  final orderAsc = spec.orderByCreatedAtAscending;
  if (orderAsc != null) {
    entries.sort((a, b) {
      final cmp = a.createdAt.compareTo(b.createdAt);
      if (cmp != 0) {
        return orderAsc ? cmp : -cmp;
      }
      return a.id.compareTo(b.id);
    });
  } else {
    entries.sort((a, b) => a.id.compareTo(b.id));
  }

  if (spec.variationSelection == VariationSelection.onePerGroup) {
    entries = _onePerGroup(entries, spec.sampleSeed);
  }

  if (spec.sampleCount != null) {
    final seed = spec.sampleSeed ?? 0;
    entries = seededSample(entries, spec.sampleCount!, seed);
    entries.sort((a, b) => a.id.compareTo(b.id));
  }

  final offset = spec.offset ?? 0;
  if (offset > 0) {
    entries = offset >= entries.length
        ? <DatasetEntry>[]
        : entries.sublist(offset);
  }

  final limit = spec.limit;
  if (limit != null && entries.length > limit) {
    entries = entries.sublist(0, limit);
  }

  return entries;
}

List<DatasetEntry> _onePerGroup(List<DatasetEntry> entries, int? seed) {
  final byGroup = <String, List<DatasetEntry>>{};
  for (final entry in entries) {
    byGroup
        .putIfAbsent(entry.variationGroup, () => <DatasetEntry>[])
        .add(entry);
  }
  final selected = <DatasetEntry>[];
  var groupIndex = 0;
  final groupKeys = byGroup.keys.toList()..sort();
  for (final key in groupKeys) {
    final group = byGroup[key]!;
    if (group.length == 1) {
      selected.add(group.first);
    } else if (seed != null) {
      selected.add(seededShuffle(group, seed + groupIndex).first);
    } else {
      group.sort((a, b) {
        final byIndex = a.variationIndex.compareTo(b.variationIndex);
        if (byIndex != 0) {
          return byIndex;
        }
        return a.id.compareTo(b.id);
      });
      selected.add(group.first);
    }
    groupIndex++;
  }
  selected.sort((a, b) => a.id.compareTo(b.id));
  return selected;
}

/// Function that executes a [DatasetQuerySpec] against a store backend.
typedef DatasetQueryExecutor = Future<List<DatasetEntry>> Function(
  DatasetQuerySpec spec,
);

/// Fluent, immutable query builder over a [DatasetStore].
class DatasetQuery {
  /// Creates a query bound to [store].
  ///
  /// When [executor] is omitted, entries are loaded from [DatasetStore.stream]
  /// and filtered in Dart.
  DatasetQuery(
    DatasetStore store, {
    DatasetQueryExecutor? executor,
    DatasetQuerySpec? spec,
  }) : this._(store, executor, spec ?? const DatasetQuerySpec());

  DatasetQuery._(this._store, this._executor, this._spec);

  final DatasetStore _store;
  final DatasetQueryExecutor? _executor;
  final DatasetQuerySpec _spec;

  /// Current immutable query specification.
  DatasetQuerySpec get spec => _spec;

  /// Restricts to entries whose [DatasetEntry.dataset] equals [name].
  DatasetQuery dataset(String name) => _copy(_spec.copyWith(dataset: name));

  /// Restricts to [DatasetEntry.datasetVersion].
  DatasetQuery datasetVersion(String version) =>
      _copy(_spec.copyWith(datasetVersion: version));

  /// Restricts to [language].
  DatasetQuery language(String language) =>
      _copy(_spec.copyWith(language: language));

  /// Restricts to [type].
  DatasetQuery type(DatasetEntryType type) => _copy(_spec.copyWith(type: type));

  /// Restricts to [variationGroup].
  DatasetQuery variationGroup(String group) =>
      _copy(_spec.copyWith(variationGroup: group));

  /// Restricts to provenance source.
  DatasetQuery source(String source) => _copy(_spec.copyWith(source: source));

  /// Restricts to parent entry id.
  DatasetQuery parentEntry(String parentEntryId) =>
      _copy(_spec.copyWith(parentEntryId: parentEntryId));

  /// Requires metadata [key] equal to [value].
  DatasetQuery metadata(String key, Object? value) =>
      _copy(_spec.copyWith(metadataKey: key, metadataValue: value));

  /// Restricts to canonical or non-canonical entries.
  DatasetQuery canonicalOnly([bool only = true]) =>
      _copy(_spec.copyWith(canonicalOnly: only));

  /// When [include] is false, only canonical entries are returned.
  DatasetQuery variations([bool include = true]) => include
      ? _copy(_spec.copyWith(clearCanonicalOnly: true))
      : canonicalOnly(true);

  /// Sets variation-aware selection mode.
  DatasetQuery variationSelection(VariationSelection selection) =>
      _copy(_spec.copyWith(variationSelection: selection));

  /// Convenience for [VariationSelection.onePerGroup].
  DatasetQuery onePerVariationGroup() =>
      variationSelection(VariationSelection.onePerGroup);

  /// Randomly samples up to [count] entries.
  ///
  /// When [seed] is provided, sampling is deterministic.
  DatasetQuery sample(int count, {int? seed}) {
    if (count < 0) {
      throw ArgumentError.value(count, 'count', 'must be >= 0');
    }
    return _copy(_spec.copyWith(sampleCount: count, sampleSeed: seed));
  }

  /// Limits the number of returned entries.
  DatasetQuery limit(int count) {
    if (count < 0) {
      throw ArgumentError.value(count, 'count', 'must be >= 0');
    }
    return _copy(_spec.copyWith(limit: count));
  }

  /// Skips the first [count] matching entries after ordering.
  DatasetQuery offset(int count) {
    if (count < 0) {
      throw ArgumentError.value(count, 'count', 'must be >= 0');
    }
    return _copy(_spec.copyWith(offset: count));
  }

  /// Orders by [DatasetEntry.createdAt].
  DatasetQuery orderByCreatedAt({bool ascending = true}) =>
      _copy(_spec.copyWith(orderByCreatedAtAscending: ascending));

  /// Streams matching entries.
  Stream<DatasetEntry> stream() async* {
    for (final entry in await toList()) {
      yield entry;
    }
  }

  /// Collects matching entries.
  Future<List<DatasetEntry>> toList() async {
    if (_executor != null) {
      return _executor(_spec);
    }
    final all = await _store.stream().toList();
    final filtered = all.where(_spec.matchesFilters).toList();
    return applyQueryPostProcessing(filtered, _spec);
  }

  DatasetQuery _copy(DatasetQuerySpec spec) =>
      DatasetQuery._(_store, _executor, spec);
}
