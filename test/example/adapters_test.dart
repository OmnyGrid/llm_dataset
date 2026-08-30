import 'package:llm_dataset/llm_dataset.dart';
import 'package:test/test.dart';

// Adapter examples are validated here without importing example/ paths directly.
import '../../example/adapters/llm_generator_adapter.dart';
import '../../example/adapters/llm_translation_adapter.dart';
import '../../example/adapters/llm_variation_adapter.dart';
import '../../example/adapters/translation_client.dart';

void main() {
  test('LlmQuestionAnswerGenerator produces canonical entries', () async {
    final entry =
        await LlmQuestionAnswerGenerator(
              config: const GeneratorConfig(dataset: 'd', language: 'en'),
              complete: mockLlmComplete,
            )
            .generate(
              DatasetSourceDocument(
                id: 'fr',
                content: 'Paris is the capital of France.',
              ),
            )
            .first;

    expect(entry.isCanonical, isTrue);
    expect(entry.input, contains('France'));
    expect(entry.output, 'Paris');
    expect(entry.provenance?.generator, 'LlmQuestionAnswerGenerator');
  });

  test('LlmParaphraseVariationGenerator links parent', () async {
    final parent = DatasetEntry(
      id: 'p1',
      dataset: 'd',
      type: DatasetEntryType.text,
      language: 'en',
      input: 'Question?',
      output: 'Answer',
      variationGroup: 'g',
      variationIndex: 0,
      createdAt: DateTime.utc(2024),
    );

    final variations = await LlmParaphraseVariationGenerator(
      paraphrase: mockParaphrase,
    ).generate(parent);

    expect(variations, hasLength(1));
    expect(variations.single.provenance?.parentEntryId, 'p1');
    expect(variations.single.input, startsWith('In other words:'));
  });

  test(
    'LlmTranslationVariationGenerator translates and links parent',
    () async {
      final parent = DatasetEntry(
        id: 'p1',
        dataset: 'd',
        type: DatasetEntryType.text,
        language: 'en',
        input: 'Question?',
        output: 'Answer',
        variationGroup: 'g',
        variationIndex: 0,
        createdAt: DateTime.utc(2024),
      );

      final variations = await LlmTranslationVariationGenerator(
        targetLanguage: 'es',
        client: const MockTranslationClient(),
      ).generate(parent);

      expect(variations, hasLength(1));
      expect(variations.single.provenance?.parentEntryId, 'p1');
      expect(variations.single.language, 'es');
      expect(variations.single.input, startsWith('[es]'));
    },
  );

  test(
    'LlmTranslationVariationGenerator.withTranslate supports callbacks',
    () async {
      final parent = DatasetEntry(
        id: 'p1',
        dataset: 'd',
        type: DatasetEntryType.text,
        language: 'en',
        input: 'Hi',
        variationGroup: 'g',
        variationIndex: 0,
        createdAt: DateTime.utc(2024),
      );

      final variations = await LlmTranslationVariationGenerator.withTranslate(
        targetLanguage: 'fr',
        translate: mockTranslate,
      ).generate(parent);

      expect(variations.single.language, 'fr');
    },
  );
}
