import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';

import '../model/dataset_entry.dart';
import '../model/dataset_entry_type.dart';
import '../model/dataset_provenance.dart';
import '../query/dataset_query.dart';
import 'dataset_store.dart';
import 'memory_dataset_store.dart';

/// SQLite-backed [DatasetStore] for datasets larger than available RAM.
///
/// Metadata and provenance are stored as JSON text columns. Provenance
/// [DatasetProvenance.source] and parent id are also denormalized for indexes.
class SqliteDatasetStore implements DatasetStore {
  /// Opens or creates a database at [path] (`:memory:` allowed).
  SqliteDatasetStore(String path) : _db = sqlite3.open(path) {
    _configure();
    _migrate();
  }

  /// Wraps an existing [Database].
  SqliteDatasetStore.fromDatabase(this._db) {
    _configure();
    _migrate();
  }

  final Database _db;
  bool _closed = false;

  /// Underlying database handle.
  Database get database => _db;

  void _configure() {
    _db.execute('PRAGMA foreign_keys = ON;');
  }

  void _migrate() {
    _db.execute('''
      CREATE TABLE IF NOT EXISTS dataset_entries (
        id TEXT PRIMARY KEY NOT NULL,
        dataset TEXT NOT NULL,
        dataset_version TEXT,
        type TEXT NOT NULL,
        language TEXT NOT NULL,
        input TEXT NOT NULL,
        output TEXT,
        thinking TEXT,
        variation_group TEXT NOT NULL,
        variation_index INTEGER NOT NULL,
        metadata_json TEXT NOT NULL,
        provenance_json TEXT,
        source TEXT,
        parent_entry_id TEXT,
        created_at TEXT NOT NULL,
        is_canonical INTEGER NOT NULL
      );
    ''');
    _db.execute(
      'CREATE INDEX IF NOT EXISTS idx_entries_dataset ON dataset_entries(dataset);',
    );
    _db.execute(
      'CREATE INDEX IF NOT EXISTS idx_entries_dataset_version '
      'ON dataset_entries(dataset, dataset_version);',
    );
    _db.execute(
      'CREATE INDEX IF NOT EXISTS idx_entries_type ON dataset_entries(type);',
    );
    _db.execute(
      'CREATE INDEX IF NOT EXISTS idx_entries_language ON dataset_entries(language);',
    );
    _db.execute(
      'CREATE INDEX IF NOT EXISTS idx_entries_variation_group '
      'ON dataset_entries(variation_group);',
    );
    _db.execute(
      'CREATE INDEX IF NOT EXISTS idx_entries_source ON dataset_entries(source);',
    );
    _db.execute(
      'CREATE INDEX IF NOT EXISTS idx_entries_created_at '
      'ON dataset_entries(created_at);',
    );
    _db.execute(
      'CREATE INDEX IF NOT EXISTS idx_entries_parent '
      'ON dataset_entries(parent_entry_id);',
    );
    _db.execute(
      'CREATE INDEX IF NOT EXISTS idx_entries_canonical '
      'ON dataset_entries(is_canonical);',
    );
  }

  /// Closes the database.
  void close() {
    if (!_closed) {
      _db.close();
      _closed = true;
    }
  }

  @override
  Future<void> add(DatasetEntry entry) async {
    _ensureOpen();
    final existing = _db.select(
      'SELECT 1 FROM dataset_entries WHERE id = ? LIMIT 1',
      [entry.id],
    );
    if (existing.isNotEmpty) {
      throw DuplicateEntryException(entry.id);
    }
    _db.execute(_insertSql, _rowValues(entry));
  }

  @override
  Future<void> addAll(Stream<DatasetEntry> entries) async {
    _ensureOpen();
    final stmt = _db.prepare(_insertSql);
    try {
      await for (final entry in entries) {
        final existing = _db.select(
          'SELECT 1 FROM dataset_entries WHERE id = ? LIMIT 1',
          [entry.id],
        );
        if (existing.isNotEmpty) {
          throw DuplicateEntryException(entry.id);
        }
        stmt.execute(_rowValues(entry));
      }
    } finally {
      stmt.close();
    }
  }

  @override
  Future<DatasetEntry?> get(String id) async {
    _ensureOpen();
    final rows = _db.select('SELECT * FROM dataset_entries WHERE id = ?', [id]);
    if (rows.isEmpty) {
      return null;
    }
    return _fromRow(rows.first);
  }

  @override
  Stream<DatasetEntry> stream() async* {
    _ensureOpen();
    final rows = _db.select('SELECT * FROM dataset_entries ORDER BY id ASC');
    for (final row in rows) {
      yield _fromRow(row);
    }
  }

  @override
  DatasetQuery query() => DatasetQuery(this, executor: executeQuery);

  /// Executes [spec] with SQL pushdown where practical.
  Future<List<DatasetEntry>> executeQuery(DatasetQuerySpec spec) async {
    _ensureOpen();

    // Metadata equality, random sampling, and seeded one-per-group need Dart.
    final needsDart =
        spec.metadataKey != null ||
        spec.sampleCount != null ||
        (spec.variationSelection == VariationSelection.onePerGroup &&
            spec.sampleSeed != null);

    if (needsDart) {
      final built = _buildSelect(spec, applyLimitOffset: false);
      final rows = _db.select(built.sql, built.params);
      final entries = rows.map(_fromRow).where(spec.matchesFilters).toList();
      return applyQueryPostProcessing(entries, spec);
    }

    if (spec.variationSelection == VariationSelection.onePerGroup) {
      return _onePerGroupSql(spec);
    }

    final built = _buildSelect(spec, applyLimitOffset: true);
    final rows = _db.select(built.sql, built.params);
    return rows.map(_fromRow).toList();
  }

  List<DatasetEntry> _onePerGroupSql(DatasetQuerySpec spec) {
    final filters = _buildFilters(spec);
    final whereSql = filters.clauses.isEmpty
        ? ''
        : 'WHERE ${filters.clauses.join(' AND ')}';
    final sql =
        '''
SELECT e.* FROM dataset_entries e
INNER JOIN (
  SELECT variation_group AS vg,
         MIN(variation_index) AS min_idx,
         MIN(id) AS min_id
  FROM dataset_entries
  $whereSql
  GROUP BY variation_group
) g
  ON e.variation_group = g.vg
 AND e.variation_index = g.min_idx
 AND e.id = g.min_id
${_orderSql(spec)}
${_limitOffsetSql(spec)}
''';
    final rows = _db.select(sql, filters.params);
    return rows.map(_fromRow).toList();
  }

  _SqlParts _buildSelect(
    DatasetQuerySpec spec, {
    required bool applyLimitOffset,
  }) {
    final filters = _buildFilters(spec);
    final whereSql = filters.clauses.isEmpty
        ? ''
        : 'WHERE ${filters.clauses.join(' AND ')}';
    final sql = StringBuffer('SELECT * FROM dataset_entries $whereSql')
      ..write(' ${_orderSql(spec)}');
    if (applyLimitOffset) {
      sql.write(' ${_limitOffsetSql(spec)}');
    }
    return _SqlParts(sql.toString(), filters.params);
  }

  _FilterParts _buildFilters(DatasetQuerySpec spec) {
    final clauses = <String>[];
    final params = <Object?>[];
    if (spec.dataset != null) {
      clauses.add('dataset = ?');
      params.add(spec.dataset);
    }
    if (spec.datasetVersion != null) {
      clauses.add('dataset_version = ?');
      params.add(spec.datasetVersion);
    }
    if (spec.language != null) {
      clauses.add('language = ?');
      params.add(spec.language);
    }
    if (spec.type != null) {
      clauses.add('type = ?');
      params.add(spec.type!.name);
    }
    if (spec.variationGroup != null) {
      clauses.add('variation_group = ?');
      params.add(spec.variationGroup);
    }
    if (spec.source != null) {
      clauses.add('source = ?');
      params.add(spec.source);
    }
    if (spec.parentEntryId != null) {
      clauses.add('parent_entry_id = ?');
      params.add(spec.parentEntryId);
    }
    if (spec.canonicalOnly != null) {
      clauses.add('is_canonical = ?');
      params.add(spec.canonicalOnly! ? 1 : 0);
    } else if (spec.variationSelection == VariationSelection.canonicalOnly) {
      clauses.add('is_canonical = 1');
    }
    return _FilterParts(clauses, params);
  }

  String _orderSql(DatasetQuerySpec spec) {
    if (spec.orderByCreatedAtAscending != null) {
      final dir = spec.orderByCreatedAtAscending! ? 'ASC' : 'DESC';
      return 'ORDER BY created_at $dir, id ASC';
    }
    return 'ORDER BY id ASC';
  }

  String _limitOffsetSql(DatasetQuerySpec spec) {
    final parts = <String>[];
    if (spec.limit != null) {
      parts.add('LIMIT ${spec.limit}');
    }
    if (spec.offset != null && spec.offset! > 0) {
      if (spec.limit == null) {
        parts.add('LIMIT -1');
      }
      parts.add('OFFSET ${spec.offset}');
    }
    return parts.join(' ');
  }

  static const _insertSql = '''
INSERT INTO dataset_entries (
  id, dataset, dataset_version, type, language, input, output, thinking,
  variation_group, variation_index, metadata_json, provenance_json,
  source, parent_entry_id, created_at, is_canonical
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
''';

  List<Object?> _rowValues(DatasetEntry entry) => [
    entry.id,
    entry.dataset,
    entry.datasetVersion,
    entry.type.name,
    entry.language,
    entry.input,
    entry.output,
    entry.thinking,
    entry.variationGroup,
    entry.variationIndex,
    jsonEncode(entry.metadata),
    entry.provenance == null ? null : jsonEncode(entry.provenance!.toJson()),
    entry.provenance?.source,
    entry.provenance?.parentEntryId,
    entry.createdAt.toUtc().toIso8601String(),
    entry.isCanonical ? 1 : 0,
  ];

  DatasetEntry _fromRow(Row row) {
    final metadataRaw = row['metadata_json'] as String;
    final provenanceRaw = row['provenance_json'] as String?;
    return DatasetEntry(
      id: row['id'] as String,
      dataset: row['dataset'] as String,
      datasetVersion: row['dataset_version'] as String?,
      type: datasetEntryTypeFromName(row['type'] as String),
      language: row['language'] as String,
      input: row['input'] as String,
      output: row['output'] as String?,
      thinking: row['thinking'] as String?,
      variationGroup: row['variation_group'] as String,
      variationIndex: row['variation_index'] as int,
      metadata: Map<String, dynamic>.from(jsonDecode(metadataRaw) as Map),
      provenance: provenanceRaw == null
          ? null
          : DatasetProvenance.fromJson(
              Map<String, dynamic>.from(jsonDecode(provenanceRaw) as Map),
            ),
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  void _ensureOpen() {
    if (_closed) {
      throw StateError('SqliteDatasetStore is closed');
    }
  }
}

class _SqlParts {
  _SqlParts(this.sql, this.params);
  final String sql;
  final List<Object?> params;
}

class _FilterParts {
  _FilterParts(this.clauses, this.params);
  final List<String> clauses;
  final List<Object?> params;
}
