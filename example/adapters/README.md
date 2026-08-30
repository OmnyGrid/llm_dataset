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

## Translation client + variation generator

[`translation_client.dart`](translation_client.dart) defines the provider contract:

- `TranslationClient` — implement for each provider (`translate`, `isAvailable`)
- `MockTranslationClient` — offline stub
- `CallbackTranslationClient` — wrap legacy `TranslateTextFn` callbacks
- `firstAvailableTranslationClient` — pick the first reachable provider

[`llm_translation_adapter.dart`](llm_translation_adapter.dart):

- `LlmTranslationVariationGenerator(client: …)` — configure a client, swap providers
- `LlmTranslationVariationGenerator.withTranslate(…)` — legacy callback constructor

[`local_llm_client.dart`](local_llm_client.dart):

- `LocalLlmTranslationClient` — Ollama / LM Studio via OpenAI-compatible HTTP
- `resolveExampleTranslationClient()` — local LLM with mock fallback

```dart
variations: [
  LlmTranslationVariationGenerator(
    targetLanguages: ['es', 'fr'],
    client: LocalLlmTranslationClient.fromEnvironment(),
  ),
],
```

### Extend with your provider

```dart
final class AcmeTranslationClient implements TranslationClient {
  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<String> translate(String text, {
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    return await acmeApi.translate(text, from: sourceLanguage, to: targetLanguage);
  }
}
```

See [`../translation_client_providers.dart`](../translation_client_providers.dart).

## Paraphrase variation adapter

[`llm_variation_adapter.dart`](llm_variation_adapter.dart) defines:

- `LlmParaphraseVariationGenerator` — one paraphrase per canonical entry
- `mockParaphrase` — offline stub

Built-in (no LLM):

- `TranslationVariationGenerator` — abstract base for translation variations
- `CallbackTranslationVariationGenerator` — supply your own `TranslateTextFn`
- `RuleBasedTranslationVariationGenerator` — deterministic `[lang]` prefix stub

The pipeline assigns unique `variationIndex` values and `instanceId`s across
multiple variation generators automatically.

## Local LLM translation example

[`../local_llm_translation.dart`](../local_llm_translation.dart) — generic local OpenAI-compatible server.

[`../lm_studio_translation.dart`](../lm_studio_translation.dart) — **LM Studio** at
`http://127.0.0.1:1234/v1`, expands each canonical Q/A into multiple translated
variations (default targets: `es,fr,de,pt`).

```bash
# LM Studio: start local server on port 1234, load a model, then:
dart run example/lm_studio_translation.dart

# More target languages → more variations per document
LOCAL_LLM_TARGET_LANG=es,fr,de,pt,it,ja dart run example/lm_studio_translation.dart

# Auto-pick the loaded model from /v1/models
LOCAL_LLM_MODEL=auto dart run example/lm_studio_translation.dart
```

[`../local_llm_translation.dart`](../local_llm_translation.dart) — Ollama / custom URL via env.

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

Keep retries, rate limits, and auth inside your [TranslationClient] implementation.
