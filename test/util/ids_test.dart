import 'package:llm_dataset/src/util/ids.dart';
import 'package:test/test.dart';

void main() {
  group('stableDatasetId', () {
    test('returns 16-char lowercase unsigned hex', () {
      const hexPattern = '^[0-9a-f]{16}\$';
      final samples = [
        stableDatasetId(['a']),
        stableDatasetId([42, 'en-phrase-action-object', 0]),
        stableDatasetId([-1, 'custom-greeting', 99]),
        stableDatasetId([0xFFFFFFFFFFFFFFFF]),
      ];

      for (final id in samples) {
        expect(id, matches(RegExp(hexPattern)));
        expect(() => int.parse(id.substring(0, 8), radix: 16), returnsNormally);
      }
    });

    test('is stable for the same inputs', () {
      expect(
        stableDatasetId(['dataset', 'v1', 'doc-1', 'PhraseGenerator']),
        stableDatasetId(['dataset', 'v1', 'doc-1', 'PhraseGenerator']),
      );
    });
  });
}
