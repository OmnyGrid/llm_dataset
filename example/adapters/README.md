# LLM adapter examples

These files show how to plug an external model into `llm_dataset` **without**
adding an LLM SDK to the package itself.

## Generator adapter

[`llm_generator_adapter.dart`](llm_generator_adapter.dart) defines:

- `LlmComplete` — async `(prompt) → text` callback you implement
- `LlmQuestionAnswerGenerator` — canonical Q/A entries with provenance
- `mockLlmComplete` — deterministic stub for offline tests

```dart
final pipeline = DatasetPipeline(
  source: JsonlSource('docs.jsonl'),
  generator: LlmQuestionAnswerGenerator(
    config: GeneratorConfig(dataset: 'myset', datasetVersion: 'v1'),
    complete: myHttpLlmCall,
  ),
  store: SqliteDatasetStore('data.db'),
);
```

## Variation adapter

[`llm_variation_adapter.dart`](llm_variation_adapter.dart) defines:

- `LlmParaphraseVariationGenerator` — one paraphrase per canonical entry
- `mockParaphrase` — offline stub

```dart
variations: [
  LlmParaphraseVariationGenerator(paraphrase: myParaphraseFn),
],
```

The pipeline assigns unique `variationIndex` values and `instanceId`s across
multiple variation generators automatically.

## Wiring your client

Replace the callback bodies with your provider of choice:

1. Build a prompt string from `DatasetSourceDocument` / `DatasetEntry`
2. Await your model response
3. Map the response into `input` / `output` (and optional `metadata['messages']`)
4. Return — provenance is already set on the adapter examples

Keep retries, rate limits, and auth **outside** this package in your adapter.
