# Examples

Runnable demos for `llm_dataset`. From the repo root:

```bash
dart run example/<file>.dart
```

| Example | What it shows |
|---------|----------------|
| [`llm_dataset_example.dart`](llm_dataset_example.dart) | Minimal memory pipeline + training stream |
| [`end_to_end.dart`](end_to_end.dart) | JSONL source → SQLite → lifecycle → export → batches |
| [`jsonl_import_export.dart`](jsonl_import_export.dart) | `DatasetExporter` / `DatasetImporter` round-trip |
| [`query_and_sampling.dart`](query_and_sampling.dart) | Filters, canonical-only, one-per-group, sample, shuffle |
| [`directory_source.dart`](directory_source.dart) | `DirectorySource` with extension filter |
| [`tool_call_chat.dart`](tool_call_chat.dart) | `ToolCallGenerator` and `metadata['messages']` |
| [`custom_generator.dart`](custom_generator.dart) | Custom `DatasetGenerator` implementation |
| [`builtin_generators.dart`](builtin_generators.dart) | All built-in generators on one document |
| [`validation_and_rejections.dart`](validation_and_rejections.dart) | `CompositeValidator`, rejections, version guard |
| [`translation_variation.dart`](translation_variation.dart) | `TranslationVariationGenerator` and callbacks |
| [`local_llm_translation.dart`](local_llm_translation.dart) | Translation via local LLM API (Ollama / LM Studio) |
| [`pipeline_store_errors.dart`](pipeline_store_errors.dart) | `PipelineStoreErrorPolicy.continueProcessing` |
| [`adapters/`](adapters/) | LLM-backed generator and variation adapters |
