import 'package:llm_dataset/llm_dataset.dart';
import 'package:llm_dataset/src/util/json_equals.dart';
import 'package:test/test.dart';

void main() {
  group('jsonDeepEquals', () {
    test('compares nested maps and lists', () {
      expect(
        jsonDeepEquals(
          {
            'a': [
              1,
              {'b': 2},
            ],
          },
          {
            'a': [
              1,
              {'b': 2},
            ],
          },
        ),
        isTrue,
      );
      expect(
        jsonDeepEquals(
          {
            'a': [
              1,
              {'b': 2},
            ],
          },
          {
            'a': [
              1,
              {'b': 3},
            ],
          },
        ),
        isFalse,
      );
    });
  });

  group('entryContentFingerprint', () {
    test('is stable for same entry content', () {
      final entry = DatasetEntry(
        id: '1',
        dataset: 'd',
        type: DatasetEntryType.text,
        language: 'en',
        input: 'hello',
        output: 'world',
        variationGroup: 'g',
        variationIndex: 0,
        createdAt: DateTime.utc(2026),
      );
      expect(entryContentFingerprint(entry), entryContentFingerprint(entry));
    });

    test('differs when input changes', () {
      DatasetEntry entry(String input) => DatasetEntry(
        id: '1',
        dataset: 'd',
        type: DatasetEntryType.text,
        language: 'en',
        input: input,
        variationGroup: 'g',
        variationIndex: 0,
        createdAt: DateTime.utc(2026),
      );
      expect(
        entryContentFingerprint(entry('a')),
        isNot(entryContentFingerprint(entry('b'))),
      );
    });
  });
}
