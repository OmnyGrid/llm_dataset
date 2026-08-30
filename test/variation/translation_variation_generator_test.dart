import 'package:llm_dataset/llm_dataset.dart';
import 'package:test/test.dart';

DatasetEntry _parent({String language = 'en'}) => DatasetEntry(
  id: 'parent',
  dataset: 'general',
  type: DatasetEntryType.text,
  language: language,
  input: 'What is the capital of France?',
  output: 'Paris',
  thinking: 'Recall European capitals.',
  variationGroup: 'group-1',
  variationIndex: 0,
  metadata: {'topic': 'geo'},
  provenance: const DatasetProvenance(source: 'manual', generator: 'author'),
  createdAt: DateTime.utc(2024, 1, 1),
);

void main() {
  group('TranslationVariationGenerator', () {
    test(
      'CallbackTranslationVariationGenerator preserves group and parent',
      () async {
        final generator = CallbackTranslationVariationGenerator(
          targetLanguage: 'es',
          translate:
              (text, {required sourceLanguage, required targetLanguage}) async {
                expect(sourceLanguage, 'en');
                expect(targetLanguage, 'es');
                return 'ES: $text';
              },
        );

        final variations = await generator.generate(_parent());
        expect(variations, hasLength(1));

        final variation = variations.single;
        expect(variation.variationGroup, 'group-1');
        expect(variation.variationIndex, 1);
        expect(variation.language, 'es');
        expect(variation.type, DatasetEntryType.translation);
        expect(variation.input, 'ES: What is the capital of France?');
        expect(variation.output, 'ES: Paris');
        expect(variation.thinking, 'ES: Recall European capitals.');
        expect(variation.provenance?.parentEntryId, 'parent');
        expect(variation.provenance?.transformation, 'translation');
        expect(variation.metadata['sourceLanguage'], 'en');
        expect(variation.metadata['targetLanguage'], 'es');
        expect(variation.metadata['topic'], 'geo');
      },
    );

    test('skips when entry language already matches target', () async {
      final generator = CallbackTranslationVariationGenerator(
        targetLanguage: 'en',
        translate:
            (_, {required sourceLanguage, required targetLanguage}) async {
              throw StateError('should not translate');
            },
      );

      expect(await generator.generate(_parent()), isEmpty);
    });

    test(
      'RuleBasedTranslationVariationGenerator prefixes target language',
      () async {
        final variations = await RuleBasedTranslationVariationGenerator(
          targetLanguage: 'fr',
        ).generate(_parent());

        expect(variations.single.input, startsWith('[fr]'));
      },
    );

    test('emits one variation per configured target language', () async {
      final generator = CallbackTranslationVariationGenerator(
        targetLanguages: ['es', 'fr', 'de'],
        translate:
            (text, {required sourceLanguage, required targetLanguage}) async {
              return '$targetLanguage:$text';
            },
      );

      final variations = await generator.generate(_parent());
      expect(variations, hasLength(3));
      expect(variations.map((v) => v.variationIndex), [1, 2, 3]);
      expect(variations.map((v) => v.language), ['es', 'fr', 'de']);
      expect(variations.map((v) => v.metadata['targetLanguage']), [
        'es',
        'fr',
        'de',
      ]);
      for (final variation in variations) {
        expect(variation.provenance?.parentEntryId, 'parent');
        expect(variation.variationGroup, 'group-1');
      }
    });

    test('skips targets that match the entry language', () async {
      final generator = RuleBasedTranslationVariationGenerator(
        targetLanguages: ['en', 'es'],
      );

      final variations = await generator.generate(_parent());
      expect(variations, hasLength(1));
      expect(variations.single.language, 'es');
      expect(variations.single.variationIndex, 1);
    });

    test('normalizeTargetLanguages accepts single or many targets', () {
      expect(normalizeTargetLanguages(targetLanguage: 'es'), ['es']);
      expect(normalizeTargetLanguages(targetLanguages: ['es', 'fr']), [
        'es',
        'fr',
      ]);
      expect(
        () => normalizeTargetLanguages(
          targetLanguage: 'es',
          targetLanguages: ['fr'],
        ),
        throwsArgumentError,
      );
    });

    test('works in pipeline alongside other variation generators', () async {
      final store = MemoryDatasetStore();
      final config = GeneratorConfig(dataset: 'i18n', seed: 1);

      final result = await DatasetPipeline(
        source: MemorySource([
          DatasetSourceDocument(id: 'doc', content: 'Hello world.'),
        ]),
        generator: TextGenerator(config),
        variations: [
          RuleBasedTranslationVariationGenerator(targetLanguage: 'es'),
          RuleBasedVariationGenerator(
            strategies: [VariationStrategy.formal],
            instanceId: 'formal',
          ),
        ],
        store: store,
        dataset: 'i18n',
      ).run();

      expect(result.entriesStored, 3);
      final entries = await store.query().toList()
        ..sort((a, b) => a.variationIndex.compareTo(b.variationIndex));
      expect(entries.map((e) => e.variationIndex), [0, 1, 2]);
      expect(entries[1].language, 'es');
      expect(entries[2].metadata['variationStrategy'], 'formal');
    });
  });
}
