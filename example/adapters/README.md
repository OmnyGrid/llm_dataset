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

[`llm_translation_adapter.dart`](llm_translation_adapter.dart) defines:

- `LlmTranslationVariationGenerator` — extends [`TranslationVariationGenerator`](../../lib/src/variation/translation_variation_generator.dart)
- `mockTranslate` — offline stub

Built-in (no LLM):

- `TranslationVariationGenerator` — abstract base for translation variations
- `CallbackTranslationVariationGenerator` — supply your own `TranslateTextFn`
- `RuleBasedTranslationVariationGenerator` — deterministic `[lang]` prefix stub

```dart
variations: [
  CallbackTranslationVariationGenerator(
    targetLanguages: ['es', 'fr', 'de'],
    translate: myTranslateFn,
  ),
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

## Local LLM translation

[`local_llm_client.dart`](local_llm_client.dart) — OpenAI-compatible HTTP client for
Ollama / LM Studio (`/v1/chat/completions`).

[`../local_llm_translation.dart`](../local_llm_translation.dart) — full pipeline
example using `LlmTranslationVariationGenerator` + local API.

```bash
# Ollama (default http://localhost:11434/v1)
ollama pull llama3.2
dart run example/local_llm_translation.dart

# Offline / CI
LLM_DATASET_USE_MOCK=1 dart run example/local_llm_translation.dart

# LM Studio or custom endpoint
LOCAL_LLM_BASE_URL=http://localhost:1234/v1 LOCAL_LLM_MODEL=my-model \
  LOCAL_LLM_TARGET_LANG=fr dart run example/local_llm_translation.dart

# Multiple targets in one generator
LOCAL_LLM_TARGET_LANG=es,fr,de dart run example/local_llm_translation.dart
```

Environment variables:

| Variable | Default | Purpose |
|----------|---------|---------|
| `LOCAL_LLM_BASE_URL` | `http://localhost:11434/v1` | OpenAI-compatible base URL |
| `LOCAL_LLM_MODEL` | `llama3.2` | Model id for chat completions |
| `LOCAL_LLM_TARGET_LANG` | `es` | Comma-separated target language codes (`es,fr,de`) |
| `LOCAL_LLM_PRIMARY_LANG` | _(none)_ | Optional primary target merged before `LOCAL_LLM_TARGET_LANG` |
| `LOCAL_LLM_API_KEY` | _(none)_ | Optional bearer token |
| `LLM_DATASET_USE_MOCK` | _(unset)_ | Set to `1` to skip HTTP |
