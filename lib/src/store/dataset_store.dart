import '../model/dataset_entry.dart';
import '../query/dataset_query.dart';

/// Persistent or in-memory storage for [DatasetEntry] values.
///
/// Implementations must support streaming large datasets without requiring the
/// complete collection in memory when reading or writing via streams.
abstract interface class DatasetStore {
  /// Inserts [entry].
  ///
  /// Must fail explicitly when an entry with the same id already exists.
  Future<void> add(DatasetEntry entry);

  /// Inserts all [entries] from the stream incrementally.
  Future<void> addAll(Stream<DatasetEntry> entries);

  /// Returns the entry with [id], or `null` if absent.
  Future<DatasetEntry?> get(String id);

  /// Streams all entries in a deterministic order defined by the store.
  Stream<DatasetEntry> stream();

  /// Starts a fluent query against this store.
  DatasetQuery query();
}
