# llm_dataset

Stream-oriented Dart package for building, storing, querying, and consuming LLM
training datasets. Provider-independent infrastructure — not a training engine.

## Workflow

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

  // Same semantic entry, multiple surface forms:
  final group = await store.query().limit(1).toList();
  final variations = await store
      .query()
      .variationGroup(group.single.variationGroup)
      .toList();
  for (final entry in variations) {
    print('${entry.variationIndex}: ${entry.input}');
  }

  // Train without loading everything at once:
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

## Core model

`DatasetEntry` is the unit of training data. Variations of the same semantic
example share `variationGroup`. Canonical entries use `variationIndex: 0` and
no `provenance.parentEntryId`.

Tool-calling / chat turns live under `metadata['messages']` with
`DatasetToolCall` objects embedded in assistant turns.

## Sources

- `MemorySource` — in-process documents
- `DirectorySource` — stream files from disk (optional extension filter)
- `JsonlSource` — line-by-line source documents (`id` + `content`/`text`)

## Generators

Built-ins (`TextGenerator`, `QuestionAnswerGenerator`, `SummarizationGenerator`,
`TranslationGenerator`, `ClassificationGenerator`, `ExtractionGenerator`,
`ToolCallGenerator`) produce **canonical** entries and do not depend on an LLM
SDK. Supply your own `DatasetGenerator` to call an external model.

## Variations

`RuleBasedVariationGenerator` applies paraphrase / formal / casual / translation
/ difficulty / format transforms, preserves `variationGroup`, assigns indexes,
and sets `provenance.parentEntryId`. Pass `seed` for deterministic strategy
ordering.

For **real translation variations**, use `TranslationVariationGenerator`
(`CallbackTranslationVariationGenerator`, `RuleBasedTranslationVariationGenerator`):

```dart
variations: [
  CallbackTranslationVariationGenerator(
    targetLanguage: 'es',
    translate: (text, {required sourceLanguage, required targetLanguage}) async {
      return await myMtClient.translate(text, from: sourceLanguage, to: targetLanguage);
    },
  ),
],
```

## Validation

Composable validators: empty content, duplicates (stream + store), metadata,
language allow-list, length, approximate token count. The pipeline rejects
invalid entries and continues; store failures propagate.

## Storage & query

- `MemoryDatasetStore` for tests / small sets
- `SqliteDatasetStore` for large persistent corpora (indexed by dataset,
  version, type, language, variation group, source, created time, parent)

```dart
final entries = await store
    .query()
    .dataset('general')
    .language('en')
    .variationSelection(VariationSelection.canonicalOnly)
    .sample(100, seed: 1)
    .toList();
```

## JSON / JSONL

`DatasetExporter` / `DatasetImporter` stream entry JSONL with metadata,
provenance, variation fields, and timestamps preserved.

## Reproducibility

Record `dataset` + `datasetVersion`, `pipelineVersion`, generator versions, and
seeds. The pipeline refuses to silently overwrite an existing dataset version
when `failIfVersionExists` is true (default).

## Dataset lifecycle

```dart
final lifecycle = DatasetLifecycle(store);
final datasets = await lifecycle.listDatasets();
final versions = await lifecycle.listVersions('geography');
await lifecycle.exportJsonl('out.jsonl', dataset: 'geography', version: 'v1');
await lifecycle.deleteDataset('geography', version: 'v0');
```

## Examples

See [`example/README.md`](example/README.md) for runnable demos:

```bash
dart run example/query_and_sampling.dart
dart run example/jsonl_import_export.dart
dart run example/builtin_generators.dart
```

## End-to-end example

Run the SQLite workflow demo:

```bash
dart run example/end_to_end.dart
```

## LLM adapters (no SDK in this package)

See [`example/adapters/README.md`](example/adapters/README.md) for generator and
variation adapters that call **your** model via async callbacks.

## CI & coverage

GitHub Actions runs format, analyze, tests, and uploads coverage to Codecov.
Add a `CODECOV_TOKEN` repository secret for upload enforcement.
