# llm_dataset

[![pub package](https://img.shields.io/pub/v/llm_dataset.svg?logo=dart&logoColor=00b9fc)](https://pub.dev/packages/llm_dataset)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Dart CI](https://github.com/OmnyGrid/llm_dataset/actions/workflows/dart.yml/badge.svg?branch=main)](https://github.com/OmnyGrid/llm_dataset/actions/workflows/dart.yml)
[![Codecov](https://codecov.io/gh/OmnyGrid/llm_dataset/branch/main/graph/badge.svg)](https://codecov.io/gh/OmnyGrid/llm_dataset)
[![GitHub Tag](https://img.shields.io/github/v/tag/OmnyGrid/llm_dataset?logo=git&logoColor=white)](https://github.com/OmnyGrid/llm_dataset/releases)
[![New Commits](https://img.shields.io/github/commits-since/OmnyGrid/llm_dataset/latest?logo=git&logoColor=white)](https://github.com/OmnyGrid/llm_dataset/network)
[![Last Commits](https://img.shields.io/github/last-commit/OmnyGrid/llm_dataset?logo=git&logoColor=white)](https://github.com/OmnyGrid/llm_dataset/commits/main)
[![Pull Requests](https://img.shields.io/github/issues-pr/OmnyGrid/llm_dataset?logo=github&logoColor=white)](https://github.com/OmnyGrid/llm_dataset/pulls)
[![Code size](https://img.shields.io/github/languages/code-size/OmnyGrid/llm_dataset?logo=github&logoColor=white)](https://github.com/OmnyGrid/llm_dataset)
[![License](https://img.shields.io/github/license/OmnyGrid/llm_dataset?logo=open-source-initiative&logoColor=green)](https://github.com/OmnyGrid/llm_dataset/blob/main/LICENSE)

A **stream-oriented Dart package** for building, storing, querying, and consuming
**LLM training datasets**. Provider-independent infrastructure — not a training
engine. You own the sources, generators, validators, and trainer; this package
wires the pipeline and keeps every entry versioned, queryable, and reproducible.

```text
source → generate → create variations → validate → store → query → stream into trainer
```

```dart
import 'package:llm_dataset/llm_dataset.dart';

Future<void> main() async {
  final store = MemoryDatasetStore();
  final config = GeneratorConfig(
    dataset: 'general',
    datasetVersion: 'v1',
    language: 'en',
    pipelineVersion: 'pipe-1',
    seed: 42,
  );

  final pipeline = DatasetPipeline(
    source: MemorySource([
      DatasetSourceDocument(
        id: 'france',
        content: 'Paris is the capital of France.',
        title: 'France',
        language: 'en',
      ),
    ]),
    generator: QuestionAnswerGenerator(config),
    variations: [
      RuleBasedVariationGenerator(
        strategies: [
          VariationStrategy.paraphrase,
          VariationStrategy.formal,
          VariationStrategy.casual,
        ],
        seed: 42,
      ),
    ],
    validators: [
      EmptyContentValidator(),
      LengthValidator(minInputLength: 3),
      DuplicateValidator(store: store),
    ],
    store: store,
    dataset: 'general',
    datasetVersion: 'v1',
  );

  final result = await pipeline.run();
  print('stored=${result.entriesStored} rejected=${result.entriesRejected}');

  final dataset = Dataset(
    store: store,
    variationSelection: VariationSelection.onePerGroup,
  );
  await for (final batch in dataset.batches(8, shuffle: true, seed: 7)) {
    // trainer.train(batch);
    print('batch ${batch.length}');
  }
}
```

`DatasetEntry` is the unit of training data. Variations of the same semantic
example share a `variationGroup`; canonical rows use `variationIndex: 0` with no
`provenance.parentEntryId`. Tool-calling / chat turns live under
`metadata['messages']` with `DatasetToolCall` objects embedded in assistant
turns.

## API Documentation

Generate docs locally with `dart doc`, then open `doc/api/index.html`. The public
surface is exported from [`lib/llm_dataset.dart`](lib/llm_dataset.dart).

## Features

- **Pipeline-first.** `DatasetPipeline` streams source documents through a
  generator, variation generators, validators, and into a store — rejecting bad
  rows without stopping the run.
- **Variation groups.** Canonical entries plus indexed surface-form variations
  share `variationGroup`; provenance links variations back to their parent.
- **Built-in generators.** Rule-based `TextGenerator`, `QuestionAnswerGenerator`,
  `SummarizationGenerator`, `TranslationGenerator`, `ClassificationGenerator`,
  `ExtractionGenerator`, and `ToolCallGenerator` — no LLM SDK required.
- **Translation variations.** `TranslationVariationGenerator` with callback or
  rule-based backends; merge and uniquify multiple target languages in one pass.
- **Text exercises.** EN/PT phrase and paragraph generators, JSON-backed phrase
  template stores, combinatorial expansion, and meaning-preserving variations.
- **Progressive curriculum.** Multi-stage manifests, per-stage builders, mixed
  batch sampling with configurable review ratio, and stage-scoped JSONL export.
- **Exercise modules.** Built-in catalogs and generators for language basics,
  math, logic, and coding drills — wired into the curriculum registry.
- **Queryable storage.** `MemoryDatasetStore` for tests; `SqliteDatasetStore`
  for large persistent corpora with indexed filters and batched bulk insert.
- **Training streams.** `Dataset` and `CurriculumDataset` yield batches without
  loading the full corpus into memory.
- **Reproducibility.** Dataset + version, pipeline version, generator versions,
  and seeds; optional `failIfVersionExists` guard against silent overwrites.
- **JSONL interchange.** `DatasetExporter` / `DatasetImporter` preserve metadata,
  provenance, variation fields, and timestamps.
- **Tested.** Unit, integration, and curriculum end-to-end coverage over memory
  and SQLite stores.

## Architecture

```text
           Sources (Memory / Directory / JSONL)
                          │
                    DatasetPipeline
              generate → vary → validate
                          │
                    DatasetStore
                 (Memory / SQLite)
                          │
              Query ──► Dataset / CurriculumDataset
                          │
                    trainer batches
```

```text
lib/
├── llm_dataset.dart              # public barrel export
└── src/
    ├── model/                    # DatasetEntry, provenance, tool calls
    ├── source/                   # MemorySource, DirectorySource, JsonlSource
    ├── generator/                # DatasetGenerator + built-ins
    ├── variation/                # rule-based + translation variations
    ├── validation/               # composable validators
    ├── pipeline/                 # DatasetPipeline orchestration
    ├── store/                    # Memory + SQLite stores, lifecycle
    ├── query/                    # fluent DatasetQuery filters
    ├── serialization/            # JSON / JSONL codec
    ├── training/                 # Dataset batch streaming
    ├── text_exercise/            # phrases, paragraphs, template store
    ├── curriculum/               # manifest, builder, mixing, lifecycle
    ├── language_basics/          # vocabulary / grammar drills
    ├── math_exercise/            # arithmetic drills
    ├── logic_exercise/           # logic pattern drills
    └── coding_exercise/          # code pattern drills
```

## Getting started

```yaml
dependencies:
  llm_dataset:
    git:
      url: https://github.com/OmnyGrid/llm_dataset.git
```

Requires Dart **^3.13**. The package uses `dart:io` and `sqlite3` for persistent
storage; run on VM targets (not web).

## Usage

### Pipeline quick start

The snippet at the top builds a memory-backed dataset from one source document,
applies rule-based variations, validates, stores, and streams training batches.
Swap `MemoryDatasetStore` for `SqliteDatasetStore('corpus.db')` for persistence.

Inspect variation groups after the run:

```dart
final group = await store.query().limit(1).toList();
final variations = await store
    .query()
    .variationGroup(group.single.variationGroup)
    .toList();
for (final entry in variations) {
  print('${entry.variationIndex}: ${entry.input}');
}
```

### Sources

- `MemorySource` — in-process documents
- `DirectorySource` — stream files from disk (optional extension filter)
- `JsonlSource` — line-by-line source documents (`id` + `content`/`text`)

### Generators

Built-ins produce **canonical** entries and do not depend on an LLM SDK. Supply
your own `DatasetGenerator` to call an external model. See
[`example/custom_generator.dart`](example/custom_generator.dart) and
[`example/builtin_generators.dart`](example/builtin_generators.dart).

### Variations

`RuleBasedVariationGenerator` applies paraphrase / formal / casual / translation
/ difficulty / format transforms, preserves `variationGroup`, assigns indexes,
and sets `provenance.parentEntryId`. Pass `seed` for deterministic strategy
ordering.

For **real translation variations**, use `TranslationVariationGenerator`:

```dart
variations: [
  CallbackTranslationVariationGenerator(
    targetLanguage: 'es',
    targetLanguages: ['fr', 'de', 'es'], // merged + uniquified → es, fr, de
    translate: (text, {required sourceLanguage, required targetLanguage}) async {
      return await myMtClient.translate(text, from: sourceLanguage, to: targetLanguage);
    },
  ),
],
```

See [`example/translation_target_languages.dart`](example/translation_target_languages.dart)
for `normalizeTargetLanguages` usage (exported from the public API).

### Validation

Composable validators: empty content, duplicates (stream + store), metadata,
language allow-list, length, approximate token count. The pipeline rejects
invalid entries and continues; store failures propagate. See
[`example/validation_and_rejections.dart`](example/validation_and_rejections.dart).

### Storage & query

```dart
final entries = await store
    .query()
    .dataset('general')
    .language('en')
    .variationSelection(VariationSelection.canonicalOnly)
    .sample(100, seed: 1)
    .toList();
```

`SqliteDatasetStore` indexes by dataset, version, type, language, variation
group, source, created time, and parent. Use `configureForBulkInsert()` and
`addAllBatched()` when streaming millions of rows.

### JSON / JSONL

`DatasetExporter` / `DatasetImporter` stream entry JSONL with metadata,
provenance, variation fields, and timestamps preserved. See
[`example/jsonl_import_export.dart`](example/jsonl_import_export.dart).

### Dataset lifecycle

```dart
final lifecycle = DatasetLifecycle(store);
final datasets = await lifecycle.listDatasets();
final versions = await lifecycle.listVersions('geography');
await lifecycle.exportJsonl('out.jsonl', dataset: 'geography', version: 'v1');
await lifecycle.deleteDataset('geography', version: 'v0');
```

Record `dataset` + `datasetVersion`, `pipelineVersion`, generator versions, and
seeds alongside every export. Both `DatasetPipeline` and `CurriculumBuilder`
refuse to silently overwrite an existing dataset version when
`failIfVersionExists` is true (default). Pass `failIfVersionExists: false` to
rebuild into the same version.

### Progressive curriculum training

Build multi-stage datasets for shallow progressive layer training (e.g. language
basics → phrases → paragraphs → math → logic → coding). Plateau detection and
layer freezing stay in your trainer; this package tags, builds, queries, and
exports phase slices.

```dart
final manifest = await CurriculumManifest.loadFile('example/curriculum/curriculum.json');
final store = SqliteDatasetStore('curriculum.db');
await CurriculumBuilder(manifest: manifest, store: store).buildAll();

final curriculum = CurriculumDataset(store: store, manifest: manifest);
await for (final batch in curriculum.batchesPhase('phrases', 32, seed: 42)) {
  // trainer.train(batch);
}

await CurriculumLifecycle(store: store, manifest: manifest)
    .exportStageJsonl('phrases', 'phrases.jsonl');
```

Each entry is tagged with `curriculumStage` and related metadata. Mixed stages
interleave review entries at `reviewRatio` per batch. Pass
`variationOptions: CurriculumVariationOptions(variationsPerEntry: 2)` to
`CurriculumBuilder` to emit meaning-preserving variations for text sources.
See [`example/curriculum/README.md`](example/curriculum/README.md).

### Text exercises & phrase templates

Phrase and paragraph generators, JSON-backed template stores, and full
combinatorial expansion across category words, lexicon synonyms, and structural
variants. See [`example/text_exercise.dart`](example/text_exercise.dart) and
[`example/phrase_template_categories.dart`](example/phrase_template_categories.dart).

### LLM adapters (no SDK in this package)

See [`example/adapters/README.md`](example/adapters/README.md) for generator and
variation adapters that call **your** model via async callbacks. Local LLM
examples: [`example/local_llm_translation.dart`](example/local_llm_translation.dart),
[`example/lm_studio_translation.dart`](example/lm_studio_translation.dart).

## Examples

Runnable demos live under [`example/`](example/). From the repo root:

```sh
dart run example/<file>.dart
```

| Example | What it shows |
|---------|----------------|
| [`llm_dataset_example.dart`](example/llm_dataset_example.dart) | Minimal memory pipeline + training stream |
| [`end_to_end.dart`](example/end_to_end.dart) | JSONL source → SQLite → lifecycle → export → batches |
| [`jsonl_import_export.dart`](example/jsonl_import_export.dart) | `DatasetExporter` / `DatasetImporter` round-trip |
| [`query_and_sampling.dart`](example/query_and_sampling.dart) | Filters, canonical-only, one-per-group, sample, shuffle |
| [`directory_source.dart`](example/directory_source.dart) | `DirectorySource` with extension filter |
| [`tool_call_chat.dart`](example/tool_call_chat.dart) | `ToolCallGenerator` and `metadata['messages']` |
| [`custom_generator.dart`](example/custom_generator.dart) | Custom `DatasetGenerator` implementation |
| [`builtin_generators.dart`](example/builtin_generators.dart) | All built-in generators on one document |
| [`validation_and_rejections.dart`](example/validation_and_rejections.dart) | `CompositeValidator`, rejections, version guard |
| [`translation_variation.dart`](example/translation_variation.dart) | `TranslationVariationGenerator` and callbacks |
| [`translation_target_languages.dart`](example/translation_target_languages.dart) | Merge + uniquify `targetLanguage` / `targetLanguages` |
| [`translation_client_providers.dart`](example/translation_client_providers.dart) | Custom `TranslationClient` provider implementations |
| [`local_llm_translation.dart`](example/local_llm_translation.dart) | Translation via local LLM API (Ollama / LM Studio) |
| [`lm_studio_translation.dart`](example/lm_studio_translation.dart) | LM Studio at `127.0.0.1:1234` — multi-language variation expansion |
| [`text_exercise.dart`](example/text_exercise.dart) | EN/PT phrases & paragraphs with meaning-preserving variations |
| [`curriculum_training.dart`](example/curriculum_training.dart) | Self-contained curriculum build, mixed batches, and JSONL export |
| [`phrase_template_categories.dart`](example/phrase_template_categories.dart) | Full combinatorial expansion with per-entry progress logging |
| [`curriculum/`](example/curriculum/) | Progressive curriculum manifest, build, and mixed-phase training demo |
| [`pipeline_store_errors.dart`](example/pipeline_store_errors.dart) | `PipelineStoreErrorPolicy.continueProcessing` |
| [`adapters/`](example/adapters/) | LLM-backed generator and variation adapters |

Quick picks:

```sh
dart run example/query_and_sampling.dart
dart run example/jsonl_import_export.dart
dart run example/end_to_end.dart
dart run example/curriculum_training.dart
```

## Running the example and tests

```sh
dart pub get
dart format lib test example
dart analyze --fatal-infos --fatal-warnings .
dart test
```

GitHub Actions runs format, analyze, dependency validation, doc dry-run, publish
dry-run, and VM tests with coverage uploaded to [Codecov][codecov]. For private
repos, add a `CODECOV_TOKEN` repository secret (from the Codecov project settings).

[codecov]: https://codecov.io/gh/OmnyGrid/llm_dataset

# Author

Graciliano M. Passos: [gmpassos@GitHub][github].

[github]: https://github.com/gmpassos

## License

[Apache License - Version 2.0][apache_license]

[apache_license]: https://www.apache.org/licenses/LICENSE-2.0.txt
