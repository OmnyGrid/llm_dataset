import 'package:llm_dataset/llm_dataset.dart';
import 'package:test/test.dart';

void main() {
  group('ParagraphGenerator', () {
    test('builds multi-sentence English paragraph', () async {
      final doc = englishParagraphDocuments().first;
      final entry = await ParagraphGenerator(
        config: const GeneratorConfig(dataset: 'd', language: 'en', seed: 1),
        patterns: englishParagraphPatternMap(),
        lexicon: englishTextLexicon,
      ).generate(doc).first;

      expect(entry.metadata[TextExerciseMetadata.textKind], 'paragraph');
      expect(entry.input.split(' ').length, greaterThan(5));
      expect(entry.input, entry.output);
    });

    test('builds Portuguese paragraph from catalog', () async {
      final doc = portugueseParagraphDocuments().first;
      final entry = await ParagraphGenerator(
        config: const GeneratorConfig(dataset: 'd', language: 'pt', seed: 1),
        patterns: portugueseParagraphPatternMap(),
        lexicon: portugueseTextLexicon,
      ).generate(doc).first;

      expect(entry.language, 'pt');
      expect(entry.metadata[TextExerciseMetadata.textKind], 'paragraph');
    });

    test('unknown pattern id throws', () {
      final generator = ParagraphGenerator(
        config: const GeneratorConfig(dataset: 'd', language: 'en'),
        patterns: englishParagraphPatternMap(),
        lexicon: englishTextLexicon,
      );
      expect(
        generator.generate(DatasetSourceDocument(id: 'missing', content: 'x')),
        emitsError(isA<ArgumentError>()),
      );
    });
  });
}
