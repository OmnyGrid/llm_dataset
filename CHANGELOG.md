## 1.3.0

### Added
- **Curriculum dataset system** for progressive layer training:
  `CurriculumManifest`, `CurriculumBuilder`, `CurriculumDataset`,
  `CurriculumLifecycle`, and `TrainingPhaseDescriptor`
- Stage metadata keys: `curriculumId`, `curriculumStage`, `curriculumStageOrder`,
  `complexityTier`
- Per-batch mixed sampling with configurable `reviewRatio` and `reviewStages`
- Exercise modules: `language_basics`, `math_exercise`, `logic_exercise`,
  `coding_exercise` with built-in catalogs and generators
- Curriculum builder registry wiring for phrase templates, paragraphs, and new modules
- Examples: `example/curriculum/` (manifest, build script, train-phase demo)
- Curriculum, language-basics, math, logic, and coding tests

## 1.2.0

### Added
- Text exercise generators: `PhraseGenerator`, `ParagraphGenerator`, and
  `MeaningPreservingVariationGenerator` for EN/PT phrase and paragraph drills
- `PhraseTemplateStoreLoader` and JSON-backed phrase template store API
  (`PhraseTemplateStore`, codec, locale manifest)
- `PhraseCombinatorialGenerator` for full cross-product expansion of category
  words, lexicon synonyms, and structural template variants
- Optional `structureVariants` per template (same slots, alternate phrasing)
- SQLite bulk insert helpers: `configureForBulkInsert()` and `addAllBatched()`
- Examples: `example/text_exercise.dart`, `example/phrase_template_categories.dart`,
  and `example/phrase_templates/en/` JSON dataset (31 templates, 13 word categories)
- Progress logging adapters for LM Studio translation and combinatorial phrase runs
- Text exercise and phrase template store tests

### Changed
- `buildCanonicalEntry` supports `variationIndex`, `parentEntryId`, and
  `transformation` (used for structural template variants)
- `PhraseGenerator` emits all structural variants for a resolved slot assignment
- LM Studio example prints per-step translation progress and full input/output text

### Fixed
- `stableDatasetId` now emits unsigned 64-bit hex (fixes combinatorial ID parsing)

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
