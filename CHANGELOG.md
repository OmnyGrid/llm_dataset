## 1.1.0

### Added
- `DatasetLifecycle` for listing datasets/versions, counting, deleting, and exporting JSONL slices
- `PipelineStoreErrorPolicy` (`abort` vs `continueProcessing`) for store failures during pipeline runs
- SQLite batched query streaming via `executeQueryStream`
- SQLite scalar metadata filtering with `json_extract`
- End-to-end example: `example/end_to_end.dart`
- LLM adapter examples under `example/adapters/` (generator + variation, no SDK dependency)
- Hardening and adapter tests

### Fixed
- Variation ID collisions when multiple generators share strategy/seed
- `DuplicateValidator` recording IDs before fingerprint checks; store fingerprint dedup
- Conflicting query filters (`canonicalOnly` vs `variationSelection`)
- `failIfVersionExists` for unversioned datasets
- Atomic `addAll` rollback (memory + SQLite transaction)
- `orderByCreatedAt` preserved after `sample()`
- Per-document deterministic `createdAt` when generator `seed` is set
- Metadata query deep equality; `variationIndex` JSON numeric coercion

## 1.0.0

- Initial `llm_dataset` package: models, sources, generators, variations,
  validation, pipeline, memory + SQLite stores, query/sampling, training
  consumption API, and JSON/JSONL import/export.
