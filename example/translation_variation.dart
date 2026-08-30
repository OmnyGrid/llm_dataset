/// Translation variations via [CallbackTranslationVariationGenerator].
library;

import 'package:llm_dataset/llm_dataset.dart';

Future<void> main() async {
  final store = MemoryDatasetStore();
  final config = GeneratorConfig(
    dataset: 'i18n',
    datasetVersion: 'v1',
    language: 'en',
    pipelineVersion: 'translation-variation',
    seed: 1,
  );

  final result = await DatasetPipeline(
    source: MemorySource([
      DatasetSourceDocument(
        id: 'greeting',
        content: 'Hello! Welcome to the dataset package.',
      ),
    ]),
    generator: TextGenerator(config),
    variations: [
      RuleBasedTranslationVariationGenerator(
        targetLanguage: 'es',
        targetLanguages: ['fr', 'de', 'es'],
        instanceId: 'multi-lang',
      ),
      CallbackTranslationVariationGenerator(
        targetLanguage: 'it',
        targetLanguages: ['pt', ' it '],
        instanceId: 'it-pt-callback',
        translate:
            (text, {required sourceLanguage, required targetLanguage}) async {
              return '$targetLanguage($sourceLanguage→$targetLanguage): $text';
            },
      ),
    ],
    store: store,
    dataset: 'i18n',
    datasetVersion: 'v1',
  ).run();

  print('stored=${result.entriesStored}');
  for (final entry in await store.query().orderByCreatedAt().toList()) {
    print(
      'idx=${entry.variationIndex} lang=${entry.language} '
      'type=${entry.type.name}',
    );
    print('  in: ${entry.input}');
  }
}
