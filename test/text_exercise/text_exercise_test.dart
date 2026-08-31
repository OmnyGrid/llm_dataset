import 'package:llm_dataset/llm_dataset.dart';
import 'package:test/test.dart';

void main() {
  group('WordCategoryBank', () {
    test('picks lemmas by category with wrap-around index', () {
      const bank = WordCategoryBank(
        categories: {
          'actor': ['developer', 'team', 'student'],
        },
      );

      expect(bank.pick('actor', 0), 'developer');
      expect(bank.pick('actor', 1), 'team');
      expect(bank.pick('actor', 3), 'developer');
    });

    test('throws for unknown category', () {
      const bank = WordCategoryBank(categories: {});
      expect(() => bank.pick('missing', 0), throwsArgumentError);
    });
  });

  group('PhraseTemplateLibrary', () {
    test('resolves slots from categories and lexicon', () {
      const template = PhraseTemplate(
        id: 't1',
        template: 'The {subject} {verb} the {object}.',
        slotCategories: {
          'subject': 'actor',
          'verb': 'action',
          'object': 'thing',
        },
      );

      final pattern = template.toPatternConfig();
      final pickIndex = 100;
      final slots = pattern.resolveSlots(
        englishTextLexicon,
        categories: englishWordCategoryBank,
        pickIndex: pickIndex,
      );
      final semanticKeys = pattern.resolveSemanticKeys(
        categories: englishWordCategoryBank,
        pickIndex: pickIndex,
      );

      for (final entry in template.slotCategories.entries) {
        expect(
          semanticKeys[entry.key],
          englishWordCategoryBank.pick(
            entry.value,
            pickIndex + entry.key.hashCode,
          ),
        );
      }

      expect(buildFromTemplate(template.template, slots), isNotEmpty);
    });

    test('english library has expanded template set', () {
      expect(englishPhraseTemplateLibrary.templates.length, 12);
      expect(englishPhraseTemplateLibrary.documents().length, 12);
    });
  });

  group('PhraseGenerator', () {
    test('builds English phrase from category pattern', () async {
      final doc = englishPhraseDocuments().first;
      final entry = await PhraseGenerator(
        config: const GeneratorConfig(dataset: 'd', language: 'en', seed: 1),
        patterns: englishPhrasePatternMap(),
        lexicon: englishTextLexicon,
        categoryBank: englishWordCategoryBank,
      ).generate(doc).first;

      expect(entry.language, 'en');
      expect(entry.isCanonical, isTrue);
      expect(entry.input, isNotEmpty);
      expect(entry.metadata['textKind'], 'phrase');
      expect(entry.metadata['textSlotCategories'], isNotNull);
    });

    test('builds Portuguese phrase from category pattern', () async {
      final doc = portuguesePhraseDocuments().first;
      final entry = await PhraseGenerator(
        config: const GeneratorConfig(dataset: 'd', language: 'pt', seed: 1),
        patterns: portuguesePhrasePatternMap(),
        lexicon: portugueseTextLexicon,
        categoryBank: portugueseWordCategoryBank,
      ).generate(doc).first;

      expect(entry.language, 'pt');
      expect(entry.input, isNotEmpty);
    });

    test('requires categoryBank when pattern uses categories', () async {
      final doc = englishPhraseDocuments().first;
      await expectLater(
        PhraseGenerator(
          config: const GeneratorConfig(dataset: 'd', language: 'en'),
          patterns: englishPhrasePatternMap(),
          lexicon: englishTextLexicon,
        ).generate(doc).first,
        throwsArgumentError,
      );
    });

    test('still supports fixed semanticSlots without categoryBank', () async {
      const pattern = PhrasePatternConfig(
        id: 'fixed',
        template: 'The {subject} {verb}.',
        semanticSlots: {'subject': 'developer', 'verb': 'write'},
      );
      final doc = DatasetSourceDocument(
        id: 'fixed',
        content: pattern.template,
        language: 'en',
      );

      final entry = await PhraseGenerator(
        config: const GeneratorConfig(dataset: 'd', language: 'en'),
        patterns: {'fixed': pattern},
        lexicon: englishTextLexicon,
      ).generate(doc).first;

      expect(entry.input, 'The developer writes.');
    });
  });

  group('ParagraphGenerator', () {
    test('builds English paragraph with multiple sentences', () async {
      final doc = englishParagraphDocuments().first;
      final entry = await ParagraphGenerator(
        config: const GeneratorConfig(dataset: 'd', language: 'en', seed: 2),
        patterns: englishParagraphPatternMap(),
        lexicon: englishTextLexicon,
      ).generate(doc).first;

      expect(entry.input.split('.').length, greaterThan(2));
      expect(entry.metadata['textKind'], 'paragraph');
    });
  });

  group('MeaningPreservingVariationGenerator', () {
    test('produces different surface forms with same semantic slots', () async {
      final doc = englishPhraseDocuments().first;
      final canonical = await PhraseGenerator(
        config: const GeneratorConfig(dataset: 'd', language: 'en', seed: 1),
        patterns: englishPhrasePatternMap(),
        lexicon: englishTextLexicon,
        categoryBank: englishWordCategoryBank,
      ).generate(doc).first;

      final variations = await MeaningPreservingVariationGenerator(
        lexicon: englishTextLexicon,
        variationsPerEntry: 2,
        seed: 7,
      ).generate(canonical);

      expect(variations, isNotEmpty);
      expect(variations.every((v) => v.input != canonical.input), isTrue);
      expect(
        variations.every((v) => v.provenance?.parentEntryId == canonical.id),
        isTrue,
      );
      expect(variations.map((v) => v.variationGroup).toSet(), {
        canonical.variationGroup,
      });
    });

    test('pipeline stores canonical and variations for EN and PT', () async {
      Future<int> runPipeline({
        required DatasetGenerator generator,
        required List<DatasetSourceDocument> docs,
        required TextLexicon lexicon,
        required String dataset,
      }) async {
        final store = MemoryDatasetStore();
        await DatasetPipeline(
          source: MemorySource(docs),
          generator: generator,
          variations: [
            MeaningPreservingVariationGenerator(
              lexicon: lexicon,
              variationsPerEntry: 2,
              seed: 99,
            ),
          ],
          store: store,
          dataset: dataset,
          failIfVersionExists: false,
        ).run();
        return store.length;
      }

      final enCount = await runPipeline(
        generator: PhraseGenerator(
          config: const GeneratorConfig(dataset: 'en', language: 'en'),
          patterns: englishPhrasePatternMap(),
          lexicon: englishTextLexicon,
          categoryBank: englishWordCategoryBank,
        ),
        docs: englishPhraseDocuments(),
        lexicon: englishTextLexicon,
        dataset: 'en',
      );
      expect(enCount, englishPhraseDocuments().length * 3);

      final ptCount = await runPipeline(
        generator: PhraseGenerator(
          config: const GeneratorConfig(dataset: 'pt', language: 'pt'),
          patterns: portuguesePhrasePatternMap(),
          lexicon: portugueseTextLexicon,
          categoryBank: portugueseWordCategoryBank,
        ),
        docs: portuguesePhraseDocuments(),
        lexicon: portugueseTextLexicon,
        dataset: 'pt',
      );
      expect(ptCount, portuguesePhraseDocuments().length * 3);
    });
  });
}
