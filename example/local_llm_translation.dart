/// Translation variations through a local OpenAI-compatible LLM API (Ollama, LM Studio).
///
/// Requires a running server by default. Force offline mode with:
/// `LLM_DATASET_USE_MOCK=1 dart run example/local_llm_translation.dart`
library;

import 'dart:io';

import 'package:llm_dataset/llm_dataset.dart';

import 'adapters/local_llm_client.dart';
import 'adapters/llm_translation_adapter.dart';
import 'adapters/translation_client.dart';

Future<void> main() async {
  final envTargets = targetLanguagesFromEnvironment(
    'LOCAL_LLM_TARGET_LANG',
    defaults: const ['es'],
  );
  final targetLanguages = normalizeTargetLanguages(
    targetLanguage: Platform.environment['LOCAL_LLM_PRIMARY_LANG'],
    targetLanguages: envTargets,
  );

  final client = await resolveExampleTranslationClient();
  if (client is MockTranslationClient) {
    print('Using MockTranslationClient');
  } else if (client is LocalLlmTranslationClient) {
    print(
      'Using LocalLlmTranslationClient '
      '(${client.llm.config.baseUrl}, model=${client.llm.config.model})',
    );
  } else {
    print('Using ${client.runtimeType}');
  }

  final store = MemoryDatasetStore();
  final config = GeneratorConfig(
    dataset: 'local-i18n',
    datasetVersion: 'v1',
    language: 'en',
    pipelineVersion: 'local-llm-translation',
    seed: 4,
  );

  print(
    '== Pipeline: canonical entries + local LLM translation '
    '(${targetLanguages.join(', ')}) ==',
  );
  final result = await DatasetPipeline(
    source: MemorySource([
      DatasetSourceDocument(
        id: 'welcome',
        content: 'Hello! Welcome to the dataset package.',
        title: 'Welcome',
      ),
      DatasetSourceDocument(
        id: 'help',
        content:
            'This example translates training entries through a local LLM API.',
        title: 'Help',
      ),
    ]),
    generator: TextGenerator(config),
    variations: [
      LlmTranslationVariationGenerator(
        targetLanguages: targetLanguages,
        client: client,
        instanceId: 'local-llm',
        generatorVersion: 'local-llm-example-1',
      ),
    ],
    validators: [EmptyContentValidator(), LengthValidator(minInputLength: 3)],
    store: store,
    dataset: 'local-i18n',
    datasetVersion: 'v1',
  ).run();

  print(
    'stored=${result.entriesStored} rejected=${result.entriesRejected} '
    'docs=${result.documentsSeen}',
  );

  final groups = await store.query().orderByCreatedAt().toList();
  for (final entry in groups) {
    final label = entry.isCanonical ? 'canonical' : 'translation';
    print('[$label] lang=${entry.language} idx=${entry.variationIndex}');
    print('  in: ${entry.input}');
    if (entry.output != null && entry.output!.isNotEmpty) {
      print('  out: ${entry.output}');
    }
  }

  print('done');
}
