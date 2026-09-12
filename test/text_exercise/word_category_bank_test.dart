import 'package:llm_dataset/llm_dataset.dart';
import 'package:test/test.dart';

void main() {
  group('WordCategoryBank', () {
    const bank = WordCategoryBank(
      categories: {
        'actor': ['developer', 'team'],
        'empty': <String>[],
      },
    );

    test('words returns unmodifiable list or empty for missing/empty', () {
      expect(bank.words('actor'), ['developer', 'team']);
      expect(bank.words('missing'), isEmpty);
      expect(bank.words('empty'), isEmpty);
    });

    test('pick wraps index and throws for unknown or empty category', () {
      expect(bank.pick('actor', 0), 'developer');
      expect(bank.pick('actor', 3), 'team');
      expect(() => bank.pick('missing', 0), throwsA(isA<ArgumentError>()));
      expect(() => bank.pick('empty', 0), throwsA(isA<ArgumentError>()));
    });

    test('aggregates category and lemma counts', () {
      expect(bank.categoryNames, containsAll(['actor', 'empty']));
      expect(bank.lemmaSlotCount, 2);
      expect(bank.uniqueLemmas, {'developer', 'team'});
      expect(bank.uniqueLemmaCount, 2);
    });

    test('wordCategoryBankForLanguage resolves built-in locales', () {
      expect(wordCategoryBankForLanguage('en'), englishWordCategoryBank);
      expect(wordCategoryBankForLanguage('pt'), portugueseWordCategoryBank);
      expect(wordCategoryBankForLanguage('fr'), isNull);
    });
  });
}
