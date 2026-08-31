/// Multiply dataset variations via LM Studio translation (http://127.0.0.1:1234).
///
/// Prerequisites:
/// 1. LM Studio → Local Server → Start server (default port 1234)
/// 2. Load a chat-capable model in LM Studio
///
/// Run:
/// ```bash
/// dart run example/lm_studio_translation.dart
/// ```
///
/// Offline / CI:
/// ```bash
/// LLM_DATASET_USE_MOCK=1 dart run example/lm_studio_translation.dart
/// ```
///
/// Optional env:
/// - `LOCAL_LLM_MODEL` — model id (default: first model from `/v1/models`, else `local-model`)
/// - `LOCAL_LLM_MODEL=auto` — always pick first model from server
/// - `LOCAL_LLM_TARGET_LANG=es,fr,de,pt,it` — translation targets
/// - `LOCAL_LLM_TIMEOUT_SECONDS=600` — per-request timeout (default 300 for LM Studio)
library;

import 'package:llm_dataset/llm_dataset.dart';

import 'adapters/local_llm_client.dart';
import 'adapters/llm_translation_adapter.dart';
import 'adapters/progress_translation_client.dart';
import 'adapters/translation_client.dart';

Future<void> main() async {
  final stopwatch = Stopwatch()..start();
  final targetLanguages = normalizeTargetLanguages(
    targetLanguages: targetLanguagesFromEnvironment(
      'LOCAL_LLM_TARGET_LANG',
      defaults: const ['es', 'fr', 'de', 'pt'],
    ),
  );

  final baseClient = await resolveLmStudioTranslationClient();
  if (baseClient is MockTranslationClient) {
    print('LM Studio not reachable — using MockTranslationClient');
    print('Start LM Studio local server at http://127.0.0.1:1234 and retry.');
  } else if (baseClient is LocalLlmTranslationClient) {
    final cfg = baseClient.llm.config;
    print('LM Studio client: ${cfg.baseUrl} model=${cfg.model}');
  }

  final store = MemoryDatasetStore();
  final config = GeneratorConfig(
    dataset: 'lm-studio-i18n',
    datasetVersion: 'v1',
    language: 'en',
    pipelineVersion: 'lm-studio-translation',
    seed: 11,
  );

  final documents = [
    DatasetSourceDocument(
      id: 'mars',
      content:
          'Mars is the fourth planet from the Sun. '
          'It is often called the Red Planet.',
      title: 'Mars',
    ),
    DatasetSourceDocument(
      id: 'venus',
      content:
          'Venus is the second planet from the Sun. '
          'Its thick atmosphere traps heat.',
      title: 'Venus',
    ),
  ];

  // Q/A entries translate both question (input) and answer (output) per language.
  const fieldsPerTranslation = 2;
  final translateSteps =
      documents.length * targetLanguages.length * fieldsPerTranslation;

  print(
    '== ${documents.length} docs × ${targetLanguages.length} languages '
    '→ up to ${documents.length * (1 + targetLanguages.length)} entries '
    '($translateSteps LM calls) ==',
  );

  final client = ProgressTranslationClient(
    inner: baseClient,
    totalSteps: translateSteps,
    targetLanguages: targetLanguages,
    fieldsPerLanguage: fieldsPerTranslation,
  );

  final result = await DatasetPipeline(
    source: ProgressDocumentSource(documents),
    generator: QuestionAnswerGenerator(config),
    variations: [
      LlmTranslationVariationGenerator(
        targetLanguages: targetLanguages,
        client: client,
        instanceId: 'lm-studio',
        generatorVersion: 'lm-studio-example-1',
      ),
    ],
    validators: [EmptyContentValidator(), LengthValidator(minInputLength: 5)],
    store: store,
    dataset: 'lm-studio-i18n',
    datasetVersion: 'v1',
  ).run();

  print(
    '\n== finished in ${stopwatch.elapsed.inSeconds}s ==\n'
    'stored=${result.entriesStored} rejected=${result.entriesRejected} '
    'generated=${result.entriesGenerated}',
  );

  final byGroup = <String, List<DatasetEntry>>{};
  for (final entry in await store.query().toList()) {
    byGroup.putIfAbsent(entry.variationGroup, () => []).add(entry);
  }

  for (final group in byGroup.entries) {
    group.value.sort((a, b) => a.variationIndex.compareTo(b.variationIndex));
    print('\nvariationGroup=${group.key} (${group.value.length} entries)');
    for (final entry in group.value) {
      final kind = entry.isCanonical ? 'canonical' : 'translation';
      print('  [$kind] idx=${entry.variationIndex} lang=${entry.language}');
      print('    input:\n${_indent(entry.input, 6)}');
      if (entry.output != null && entry.output!.isNotEmpty) {
        print('    output:\n${_indent(entry.output!, 6)}');
      }
    }
  }

  print('\ndone');
}

String _indent(String text, int spaces) {
  final pad = ' ' * spaces;
  return text.split('\n').map((line) => '$pad$line').join('\n');
}
