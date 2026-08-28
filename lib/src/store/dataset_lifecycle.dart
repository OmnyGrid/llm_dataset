import '../serialization/dataset_codec.dart';
import 'dataset_store.dart';
import 'memory_dataset_store.dart';
import 'sqlite_dataset_store.dart';

/// Dataset naming and version management over a [DatasetStore].
class DatasetLifecycle {
  /// Creates a lifecycle helper for [store].
  const DatasetLifecycle(this.store);

  /// Underlying store.
  final DatasetStore store;

  /// Lists distinct dataset names.
  Future<List<String>> listDatasets() async {
    if (store is SqliteDatasetStore) {
      return (store as SqliteDatasetStore).listDatasets();
    }
    final names = <String>{};
    await for (final entry in store.stream()) {
      names.add(entry.dataset);
    }
    final list = names.toList()..sort();
    return list;
  }

  /// Lists distinct version strings for [dataset] (`null` = unversioned).
  Future<List<String?>> listVersions(String dataset) async {
    if (store is SqliteDatasetStore) {
      return (store as SqliteDatasetStore).listVersions(dataset);
    }
    final versions = <String?>{};
    await for (final entry in store.stream()) {
      if (entry.dataset == dataset) {
        versions.add(entry.datasetVersion);
      }
    }
    final list = versions.toList()
      ..sort((a, b) {
        if (a == null) {
          return b == null ? 0 : -1;
        }
        if (b == null) {
          return 1;
        }
        return a.compareTo(b);
      });
    return list;
  }

  /// Deletes entries for [dataset], optionally restricted to [version].
  ///
  /// When [version] is omitted, deletes all versions. When [version] is the
  /// empty string, deletes only unversioned rows. Returns deleted row count.
  Future<int> deleteDataset(
    String dataset, {
    String? version,
    bool unversionedOnly = false,
  }) async {
    if (store is SqliteDatasetStore) {
      return (store as SqliteDatasetStore).deleteDataset(
        dataset,
        version: version,
        unversionedOnly: unversionedOnly,
      );
    }
    final toDelete = <String>[];
    await for (final entry in store.stream()) {
      if (entry.dataset != dataset) {
        continue;
      }
      if (unversionedOnly) {
        if (entry.datasetVersion == null) {
          toDelete.add(entry.id);
        }
      } else if (version == null || entry.datasetVersion == version) {
        toDelete.add(entry.id);
      }
    }
    return _deleteIds(toDelete);
  }

  /// Exports a dataset slice to JSONL at [filePath].
  Future<void> exportJsonl(
    String filePath, {
    required String dataset,
    String? version,
    bool unversionedOnly = false,
  }) async {
    var query = store.query().dataset(dataset);
    if (unversionedOnly) {
      query = query.unversionedDataset();
    } else if (version != null) {
      query = query.datasetVersion(version);
    }
    const exporter = DatasetExporter();
    await exporter.writeJsonlFile(query.stream(), filePath);
  }

  /// Counts entries in a dataset slice.
  Future<int> count({
    required String dataset,
    String? version,
    bool unversionedOnly = false,
  }) async {
    if (store is SqliteDatasetStore) {
      return (store as SqliteDatasetStore).countDataset(
        dataset,
        version: version,
        unversionedOnly: unversionedOnly,
      );
    }
    var query = store.query().dataset(dataset);
    if (unversionedOnly) {
      query = query.unversionedDataset();
    } else if (version != null) {
      query = query.datasetVersion(version);
    }
    var n = 0;
    await for (final _ in query.stream()) {
      n++;
    }
    return n;
  }

  Future<int> _deleteIds(List<String> ids) async {
    if (store is SqliteDatasetStore) {
      return (store as SqliteDatasetStore).deleteIds(ids);
    }
    if (store is MemoryDatasetStore) {
      return (store as MemoryDatasetStore).deleteIds(ids);
    }
    throw UnsupportedError(
      'deleteDataset requires MemoryDatasetStore or SqliteDatasetStore',
    );
  }
}
