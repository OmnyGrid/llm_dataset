## 1.5.0

### Added
- `DatasetSpecialTokens` — the target model's markers (terminator, BOS,
  input/output prefixes, thinking delimiters, chat role prefixes) as plain
  strings, with `.plain()` and `.chatMl()` presets. The package still never
  tokenizes; these are written into the rendered text and tokenized by whoever
  is training, so any tokenizer's markers work.
- `DatasetTextFormatter` — renders a `DatasetEntry` into the flat text a
  trainer packs, handling the text, chat/agent/tool-call and reasoning entry
  types.
- `Dataset.texts()` and `CurriculumDataset.textsPhase()` — the same streams as
  `stream()` / `streamPhase()`, rendered through a formatter.
- `DatasetPairRendering` and `DatasetTextFormatter.chatTurns(...)` — optionally
  render a generated question/answer entry as a user turn and an assistant
  turn, through the same path a stored conversation takes, so a corpus mixing
  generated Q&A with real multi-turn data is not distinguishable to the model
  by format. `inputRole` / `outputRole` cover ShareGPT-style `human` / `gpt`.
  A reasoning entry puts its trace *inside* the assistant turn.
- `DatasetTextFormatter.isPair()` — the promotion rule, exposed as a subclass
  hook. The default is conservative (non-empty `output` that differs from
  `input`); a corpus that marks unanswered entries its own way overrides it
  rather than forking the formatter.

Promotion is conditional inside the opt-in: an entry that is not a pair stays a
completion. The plain-text generators emit the sentence as both `input` and
`output` because there is nothing to answer, and rendering `The kitten.` as a
user turn with an assistant echoing it back would teach the model that a user
statement means "repeat it".

`DatasetSpecialTokens.bos` wraps each rendered example at the front, the way
Llama-family corpora use `<s>…</s>`, so a model pretrained to expect a sequence
marker gets one on every example rather than only at the head of the stream.
Prompt with the same marker: a model trained on text that always began with one
and then prompted without it starts in a state the corpus never contains.

Applied at **read** time, deliberately: stored entries keep neutral
`input` / `output`, so one dataset renders for a ChatML model and for a plain
base model without being regenerated. A store whose entries already carried
`<|im_end|>` could only ever train one family of model.

This closes a gap a consumer hit in practice. Without a terminator, a trainer
packing entries into one token stream produces
`The kitten.The kitten.kid reads` — examples run together, the model never
learns where one ends, and generation has no stop condition, so a sampler runs
until it exhausts its token budget.

Two smaller behaviours worth naming, both chosen so a naive render does not
quietly corrupt training data:
- an `output` equal to its `input` renders once, not twice (the plain-text
  generators emit the sentence as both fields because there is nothing to
  answer)
- a `thinking` trace with no delimiters configured is dropped rather than
  concatenated into the answer

### Fixed

All three were introduced by the rendering work above and never shipped, so
nothing downstream depended on them.

- A BOS is not prepended when the rendered body already starts with it — the
  mirror of the terminator rule below, and for the same reason. A doubled BOS is
  a token sequence that occurs nowhere in the corpus the model was pretrained
  on.
- The terminator is no longer appended when the rendered body already ends with
  it, so ChatML turns stop producing `…hello<|im_end|>\n<|im_end|>` — a marker
  sequence that never occurs in real ChatML. A terminator that genuinely
  differs from the turn suffix (`<|endoftext|>` separating packed documents) is
  still appended.
- `DatasetSpecialTokens.chatMl()` no longer puts `'<|im_start|>user\n'` in
  `inputPrefix`. The turn machinery belongs to `rolePrefixes` / `turnSuffix`;
  in `inputPrefix` it emitted a turn opener with no matching close for every
  entry that is not a pair.

## 1.4.0

### Added
- `CurriculumPhaseDataset` — `CurriculumDataset.mixed()` now interleaves review
  entries via `Dataset.stream` / `batches`
- `ExerciseMetadataKeys`, `ExerciseCatalog`, `CatalogExerciseGenerator` shared
  exercise abstractions
- `DatasetStoreCapabilities` extension (`configureBulkInsertIfSupported`,
  `listDistinctMetadataValues`)
- `CurriculumLifecycle.stageStats()` for per-stage entry counts
- `doc/ARCHITECTURE.md`, `CONTRIBUTING.md`, `test/fixtures/` for CI/tests
- Query, lifecycle, mixed-phase, exception, and codec validation tests (305
  tests, ~94% line coverage)

### Changed
- `CurriculumBuilder.failIfVersionExists` defaults to `true` (aligned with
  `DatasetPipeline`)
- Public exports deduplicated in `lib/llm_dataset.dart` (exercise modules via
  `curriculum_api.dart` only)
- Metadata keys consolidated under `ExerciseMetadataKeys` / `TextExerciseMetadata`
- Tests load curriculum and phrase templates from `test/fixtures/`

### Fixed
- `CurriculumDataset.mixed()` no longer ignores manifest review mixing policy

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
