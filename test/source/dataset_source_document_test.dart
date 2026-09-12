import 'package:llm_dataset/llm_dataset.dart';
import 'package:test/test.dart';

void main() {
  group('DatasetSourceDocument', () {
    final doc = DatasetSourceDocument(
      id: 'doc-1',
      content: 'Hello world.',
      title: 'Greeting',
      language: 'en',
      metadata: {'topic': 'demo'},
    );

    test('copyWith clears optional fields', () {
      final cleared = doc.copyWith(clearTitle: true, clearLanguage: true);
      expect(cleared.title, isNull);
      expect(cleared.language, isNull);
      expect(cleared.id, doc.id);
    });

    test('json round trip preserves fields', () {
      final decoded = DatasetSourceDocument.fromJson(doc.toJson());
      expect(decoded.id, doc.id);
      expect(decoded.content, doc.content);
      expect(decoded.title, doc.title);
      expect(decoded.language, doc.language);
      expect(decoded.metadata, doc.metadata);
    });

    test('equality ignores metadata', () {
      final other = DatasetSourceDocument(
        id: 'doc-1',
        content: 'Hello world.',
        title: 'Greeting',
        language: 'en',
        metadata: {'topic': 'other'},
      );
      expect(doc, equals(other));
    });

    test('toString includes id', () {
      expect(doc.toString(), contains('doc-1'));
    });
  });
}
