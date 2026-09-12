import 'package:llm_dataset/llm_dataset.dart';
import 'package:test/test.dart';

void main() {
  group('TextLexicon', () {
    const lexicon = TextLexicon(
      language: 'en',
      synonyms: {
        'developer': ['developer', 'engineer', 'programmer'],
        'solo': ['solo'],
      },
    );

    test('canonical returns first synonym or key fallback', () {
      expect(lexicon.canonical('developer'), 'developer');
      expect(lexicon.canonical('missing'), 'missing');
      expect(lexicon.canonical('solo'), 'solo');
    });

    test('forms returns synonym list or key fallback', () {
      expect(lexicon.forms('developer'), hasLength(3));
      expect(lexicon.forms('unknown'), ['unknown']);
    });

    test('alternate skips avoid when possible', () {
      expect(
        lexicon.alternate('developer', 0, avoid: 'developer'),
        isNot('developer'),
      );
      expect(lexicon.alternate('solo', 0, avoid: 'solo'), 'solo');
    });

    test('textLexiconForLanguage resolves built-in locales', () {
      expect(textLexiconForLanguage('en'), englishTextLexicon);
      expect(textLexiconForLanguage('pt'), portugueseTextLexicon);
      expect(textLexiconForLanguage('fr'), isNull);
    });
  });
}
