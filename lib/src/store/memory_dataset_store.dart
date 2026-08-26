import '../model/dataset_entry.dart';
import '../query/dataset_query.dart';
import 'dataset_store.dart';

/// Thrown when inserting an entry whose id already exists in the store.
class DuplicateEntryException implements Exception {
  /// Creates an exception for [id].
  DuplicateEntryException(this.id);

  /// Conflicting entry id.
  final String id;

  @override
  String toString() => 'DuplicateEntryException: entry id "$id" already exists';
}

/// In-memory [DatasetStore] suitable for tests and small datasets.
///
/// Entries are keyed by [DatasetEntry.id]. [stream] yields entries sorted by
/// id for deterministic ordering.
class MemoryDatasetStore implements DatasetStore {
  final Map<String, DatasetEntry> _entries = <String, DatasetEntry>{};

  /// Number of stored entries.
  int get length => _entries.length;

  @override
  Future<void> add(DatasetEntry entry) async {
    if (_entries.containsKey(entry.id)) {
      throw DuplicateEntryException(entry.id);
    }
    _entries[entry.id] = entry;
  }

  @override
  Future<void> addAll(Stream<DatasetEntry> entries) async {
    await for (final entry in entries) {
      await add(entry);
    }
  }

  @override
  Future<DatasetEntry?> get(String id) async => _entries[id];

  @override
  Stream<DatasetEntry> stream() async* {
    final ids = _entries.keys.toList()..sort();
    for (final id in ids) {
      yield _entries[id]!;
    }
  }

  @override
  DatasetQuery query() => DatasetQuery(this);
}
