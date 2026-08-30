/// Custom [TranslationClient] provider example.
library;

import 'package:llm_dataset/llm_dataset.dart';

import 'adapters/llm_translation_adapter.dart';
import 'adapters/translation_client.dart';

/// Example cloud/provider client — replace the body with your HTTP SDK call.
final class PrefixTranslationClient implements TranslationClient {
  PrefixTranslationClient(this.providerName);

  final String providerName;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<String> translate(
    String text, {
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    return '$providerName[$targetLanguage]: $text';
  }
}

Future<void> main() async {
  final store = MemoryDatasetStore();
  final config = GeneratorConfig(
    dataset: 'providers',
    datasetVersion: 'v1',
    language: 'en',
    pipelineVersion: 'translation-client-providers',
    seed: 3,
  );

  final result = await DatasetPipeline(
    source: MemorySource([
      DatasetSourceDocument(id: 'doc', content: 'Good evening.'),
    ]),
    generator: TextGenerator(config),
    variations: [
      LlmTranslationVariationGenerator(
        targetLanguages: ['es', 'fr'],
        client: PrefixTranslationClient('AcmeMT'),
        instanceId: 'acme',
      ),
      LlmTranslationVariationGenerator(
        targetLanguage: 'de',
        client: const MockTranslationClient(),
        instanceId: 'mock',
      ),
    ],
    store: store,
    dataset: 'providers',
    datasetVersion: 'v1',
  ).run();

  print('stored=${result.entriesStored}');
  for (final entry in await store.query().toList()) {
    if (entry.isCanonical) {
      continue;
    }
    print('${entry.language} ← ${entry.input}');
  }
}
