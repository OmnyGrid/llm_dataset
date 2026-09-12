import 'package:llm_dataset/llm_dataset.dart';
import 'package:test/test.dart';

void main() {
  group('DatasetToolCall', () {
    const call = DatasetToolCall(
      name: 'search',
      arguments: {'query': 'dart', 'limit': 3},
    );

    test('json round trip', () {
      final decoded = DatasetToolCall.fromJson(call.toJson());
      expect(decoded, call);
    });

    test('copyWith replaces fields', () {
      final copy = call.copyWith(name: 'fetch', arguments: {'id': '1'});
      expect(copy.name, 'fetch');
      expect(copy.arguments, {'id': '1'});
    });

    test('equality compares argument maps', () {
      const same = DatasetToolCall(
        name: 'search',
        arguments: {'query': 'dart', 'limit': 3},
      );
      const different = DatasetToolCall(
        name: 'search',
        arguments: {'query': 'rust', 'limit': 3},
      );
      expect(call, same);
      expect(call == different, isFalse);
    });

    test('toString includes serialized payload', () {
      expect(call.toString(), contains('search'));
      expect(call.toString(), contains('query'));
    });
  });
}
