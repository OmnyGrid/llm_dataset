import 'dataset_store.dart';
import 'sqlite_dataset_store.dart';

/// Optional store capabilities beyond the core [DatasetStore] interface.
extension DatasetStoreCapabilities on DatasetStore {
  /// Whether this store supports SQLite bulk-insert tuning.
  bool get supportsBulkInsert => this is SqliteDatasetStore;

  /// Calls [SqliteDatasetStore.configureForBulkInsert] when supported.
  void configureBulkInsertIfSupported({int cacheSizeKiB = 65536}) {
    final sqlite = _asSqlite();
    if (sqlite != null) {
      sqlite.configureForBulkInsert(cacheSizeKiB: cacheSizeKiB);
    }
  }

  /// Lists distinct string values for a top-level metadata key.
  ///
  /// Uses an indexed SQLite query when available; otherwise scans all entries.
  Future<List<String>> listDistinctMetadataValues(String key) async {
    final sqlite = _asSqlite();
    if (sqlite != null) {
      return sqlite.listDistinctMetadataValues(key);
    }

    final values = <String>{};
    await for (final entry in stream()) {
      final value = entry.metadata[key];
      if (value is String && value.isNotEmpty) {
        values.add(value);
      }
    }
    final list = values.toList()..sort();
    return list;
  }

  SqliteDatasetStore? _asSqlite() =>
      this is SqliteDatasetStore ? this as SqliteDatasetStore : null;
}
