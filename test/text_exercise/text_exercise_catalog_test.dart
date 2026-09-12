import 'package:llm_dataset/llm_dataset.dart';
import 'package:test/test.dart';

void main() {
  group('text_exercise_catalog', () {
    test('english and portuguese phrase documents are non-empty', () {
      expect(englishPhraseDocuments(), isNotEmpty);
      expect(portuguesePhraseDocuments(), isNotEmpty);
      expect(englishPhraseDocuments().every((d) => d.language == 'en'), isTrue);
      expect(
        portuguesePhraseDocuments().every((d) => d.language == 'pt'),
        isTrue,
      );
    });

    test('paragraph documents tag textKind and patternId', () {
      final en = englishParagraphDocuments().first;
      expect(en.metadata['textKind'], 'paragraph');
      expect(en.metadata['patternId'], isNotNull);

      final pt = portugueseParagraphDocuments().first;
      expect(pt.language, 'pt');
      expect(pt.metadata['textKind'], 'paragraph');
    });

    test('pattern maps cover all documents', () {
      for (final doc in englishPhraseDocuments()) {
        expect(englishPhrasePatternMap(), containsPair(doc.id, isNotNull));
      }
      for (final doc in englishParagraphDocuments()) {
        expect(englishParagraphPatternMap(), containsPair(doc.id, isNotNull));
      }
    });

    test('allTextExerciseDocuments merges every locale slice', () async {
      final source = allTextExerciseDocuments();
      final docs = await source.load().toList();
      expect(
        docs.length,
        englishPhraseDocuments().length +
            englishParagraphDocuments().length +
            portuguesePhraseDocuments().length +
            portugueseParagraphDocuments().length,
      );
    });
  });
}
