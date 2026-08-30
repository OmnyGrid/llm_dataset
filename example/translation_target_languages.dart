/// Merging and de-duplicating translation target languages.
///
/// Demonstrates [normalizeTargetLanguages] and using both `targetLanguage` and
/// `targetLanguages` on [TranslationVariationGenerator] subclasses.
library;

import 'package:llm_dataset/llm_dataset.dart';

Future<void> main() async {
  print('== normalizeTargetLanguages ==');
  print('single: ${normalizeTargetLanguages(targetLanguage: 'es')}');
  print(
    'many: ${normalizeTargetLanguages(targetLanguages: ['es', 'fr', 'de'])}',
  );
  print(
    'merge + uniquify: ${normalizeTargetLanguages(targetLanguage: 'es', targetLanguages: [' fr ', 'es', 'de', 'fr', 'it', 'de'])}',
  );

  print('== generator merges both parameters ==');
  final generator = RuleBasedTranslationVariationGenerator(
    targetLanguage: 'es',
    targetLanguages: ['fr', 'es', 'de', ' fr '],
    instanceId: 'merge-demo',
  );
  print('generator.targetLanguages=${generator.targetLanguages}');

  print('== pipeline: one translator, multiple targets ==');
  final store = MemoryDatasetStore();
  final config = GeneratorConfig(
    dataset: 'i18n-targets',
    datasetVersion: 'v1',
    language: 'en',
    pipelineVersion: 'target-lang-merge',
    seed: 2,
  );

  final result = await DatasetPipeline(
    source: MemorySource([
      DatasetSourceDocument(id: 'phrase', content: 'Good morning!'),
    ]),
    generator: TextGenerator(config),
    variations: [
      CallbackTranslationVariationGenerator(
        targetLanguage: 'es',
        targetLanguages: ['fr', 'es', 'de', 'it'],
        instanceId: 'callback-merge',
        translate:
            (text, {required sourceLanguage, required targetLanguage}) async {
              return '$targetLanguage:${text.toUpperCase()}';
            },
      ),
    ],
    store: store,
    dataset: 'i18n-targets',
    datasetVersion: 'v1',
  ).run();

  print('stored=${result.entriesStored}');
  final entries = await store.query().toList()
    ..sort((a, b) => a.variationIndex.compareTo(b.variationIndex));

  for (final entry in entries) {
    print(
      'idx=${entry.variationIndex} lang=${entry.language} '
      'targets=${entry.metadata['targetLanguages']}',
    );
    print('  in: ${entry.input}');
  }

  print('== direct generate (no pipeline) ==');
  final parent = entries.firstWhere((e) => e.isCanonical);
  final direct = await generator.generate(parent);
  print('languages=${direct.map((e) => e.language).join(', ')}');
}
