/// Phrase and paragraph text exercises in English and Portuguese.
///
/// Demonstrates [PhraseGenerator], [ParagraphGenerator], and
/// [MeaningPreservingVariationGenerator]: configurable templates produce
/// canonical text; lexicon synonyms produce meaning-equivalent variations.
///
/// Run:
/// ```bash
/// dart run example/text_exercise.dart
/// ```
library;

import 'dart:io';

import 'package:llm_dataset/llm_dataset.dart';

Future<void> main() async {
  await _customEnglishPhraseExample();
  await _builtInCatalogExample();
  print('\ndone');
}

/// Shows how to define phrase templates with category-based slot filling.
Future<void> _customEnglishPhraseExample() async {
  print('== Custom category-driven phrase template ==');

  const customLibrary = PhraseTemplateLibrary(
    language: 'en',
    wordBank: englishWordCategoryBank,
    templates: [
      PhraseTemplate(
        id: 'custom-greeting',
        template: 'Good {time}, the {subject} {verb} {language} {text_unit}.',
        slotCategories: {
          'time': 'time',
          'subject': 'actor',
          'verb': 'action',
          'language': 'language',
          'text_unit': 'text_part',
        },
      ),
    ],
  );

  final store = MemoryDatasetStore();
  final result = await DatasetPipeline(
    source: MemorySource(customLibrary.documents()),
    generator: PhraseGenerator(
      config: const GeneratorConfig(
        dataset: 'custom-en',
        datasetVersion: 'v1',
        language: 'en',
        pipelineVersion: 'text-exercise-demo',
        seed: 42,
      ),
      patterns: customLibrary.patternMap(),
      lexicon: englishTextLexicon,
      categoryBank: customLibrary.wordBank,
    ),
    variations: [
      MeaningPreservingVariationGenerator(
        lexicon: englishTextLexicon,
        variationsPerEntry: 3,
        seed: 42,
        instanceId: 'custom',
      ),
    ],
    store: store,
    dataset: 'custom-en',
    datasetVersion: 'v1',
  ).run();

  print(
    'templates=${customLibrary.templates.length} stored=${result.entriesStored}',
  );
  print('categories: ${customLibrary.wordBank.categoryNames.join(', ')}');
  for (final entry in await store.query().orderByCreatedAt().toList()) {
    final tag = entry.isCanonical ? 'canonical' : 'variation';
    print('  [$tag] ${entry.input}');
  }
}

/// Runs preset English/Portuguese phrase and paragraph patterns from the catalog.
Future<void> _builtInCatalogExample() async {
  final tempDir = await Directory.systemTemp.createTemp('llm_text_exercise_');
  final exportPath = '${tempDir.path}/text_exercise.jsonl';

  final sections = [
    (
      title: 'English phrases',
      generator: PhraseGenerator(
        config: const GeneratorConfig(
          dataset: 'en-phrases',
          datasetVersion: 'v1',
          language: 'en',
          seed: 1,
        ),
        patterns: englishPhrasePatternMap(),
        lexicon: englishTextLexicon,
        categoryBank: englishWordCategoryBank,
      ),
      documents: englishPhraseDocuments(),
      lexicon: englishTextLexicon,
      dataset: 'en-phrases',
      seed: 1,
    ),
    (
      title: 'English paragraphs',
      generator: ParagraphGenerator(
        config: const GeneratorConfig(
          dataset: 'en-paragraphs',
          datasetVersion: 'v1',
          language: 'en',
          seed: 2,
        ),
        patterns: englishParagraphPatternMap(),
        lexicon: englishTextLexicon,
      ),
      documents: englishParagraphDocuments(),
      lexicon: englishTextLexicon,
      dataset: 'en-paragraphs',
      seed: 2,
    ),
    (
      title: 'Portuguese phrases',
      generator: PhraseGenerator(
        config: const GeneratorConfig(
          dataset: 'pt-phrases',
          datasetVersion: 'v1',
          language: 'pt',
          seed: 3,
        ),
        patterns: portuguesePhrasePatternMap(),
        lexicon: portugueseTextLexicon,
        categoryBank: portugueseWordCategoryBank,
      ),
      documents: portuguesePhraseDocuments(),
      lexicon: portugueseTextLexicon,
      dataset: 'pt-phrases',
      seed: 3,
    ),
    (
      title: 'Portuguese paragraphs',
      generator: ParagraphGenerator(
        config: const GeneratorConfig(
          dataset: 'pt-paragraphs',
          datasetVersion: 'v1',
          language: 'pt',
          seed: 4,
        ),
        patterns: portugueseParagraphPatternMap(),
        lexicon: portugueseTextLexicon,
      ),
      documents: portugueseParagraphDocuments(),
      lexicon: portugueseTextLexicon,
      dataset: 'pt-paragraphs',
      seed: 4,
    ),
  ];

  final allStores = <MemoryDatasetStore>[];

  for (final section in sections) {
    print('\n== ${section.title} ==');
    final store = MemoryDatasetStore();
    allStores.add(store);

    final result = await DatasetPipeline(
      source: MemorySource(section.documents),
      generator: section.generator,
      variations: [
        MeaningPreservingVariationGenerator(
          lexicon: section.lexicon,
          variationsPerEntry: 2,
          seed: section.seed,
          instanceId: section.title,
        ),
      ],
      store: store,
      dataset: section.dataset,
      datasetVersion: 'v1',
      failIfVersionExists: false,
    ).run();

    print(
      'patterns=${section.documents.length} stored=${result.entriesStored} '
      '(canonical + meaning variations)',
    );

    for (final doc in section.documents) {
      final entries =
          await store.query().metadata('textPatternId', doc.id).toList()
            ..sort((a, b) => a.variationIndex.compareTo(b.variationIndex));

      if (entries.isEmpty) {
        continue;
      }

      final kind = doc.metadata['textKind'] ?? 'text';
      print('\n  [$kind] ${doc.id}');
      for (final entry in entries) {
        final label = entry.isCanonical ? 'canonical' : 'variation';
        print('    [$label] ${entry.input}');
      }
    }
  }

  print('\n== Export combined JSONL ==');
  final combined = MemoryDatasetStore();
  for (final store in allStores) {
    await combined.addAll(store.stream());
  }
  await const DatasetExporter().writeJsonlFile(combined.stream(), exportPath);
  print('exported ${combined.length} entries → $exportPath');
  await tempDir.delete(recursive: true);
}
