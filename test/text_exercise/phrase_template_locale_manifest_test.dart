import 'package:llm_dataset/llm_dataset.dart';
import 'package:test/test.dart';

void main() {
  group('PhraseTemplateLocaleManifest', () {
    test('fromJson and toJson round trip', () {
      final manifest = PhraseTemplateLocaleManifest.fromJson({
        'language': 'en',
        'version': '2.0.0',
        'description': 'demo',
        'wordSets': ['words/a.json'],
        'templateGroups': ['templates/a.json'],
      });

      expect(manifest.language, 'en');
      expect(manifest.version, '2.0.0');
      expect(manifest.description, 'demo');
      expect(manifest.toJson()['wordSets'], ['words/a.json']);
    });

    test('defaults version and description when omitted', () {
      final manifest = PhraseTemplateLocaleManifest.fromJson({
        'language': 'pt',
        'wordSets': <String>[],
        'templateGroups': <String>[],
      });
      expect(manifest.version, '1.0.0');
      expect(manifest.description, isEmpty);
    });

    test('assertSafeRelativePath rejects absolute and parent paths', () {
      expect(
        () =>
            PhraseTemplateLocaleManifest.assertSafeRelativePath('/etc/passwd'),
        throwsA(isA<PhraseTemplateStoreException>()),
      );
      expect(
        () => PhraseTemplateLocaleManifest.assertSafeRelativePath('../secret'),
        throwsA(isA<PhraseTemplateStoreException>()),
      );
    });

    test('rejects invalid language and path list types', () {
      expect(
        () => PhraseTemplateLocaleManifest.fromJson({
          'language': '',
          'wordSets': [],
          'templateGroups': [],
        }),
        throwsA(isA<PhraseTemplateStoreException>()),
      );
      expect(
        () => PhraseTemplateLocaleManifest.fromJson({
          'language': 'en',
          'wordSets': 'not-a-list',
          'templateGroups': [],
        }),
        throwsA(isA<PhraseTemplateStoreException>()),
      );
      expect(
        () => PhraseTemplateLocaleManifest.fromJson({
          'language': 'en',
          'wordSets': [''],
          'templateGroups': [],
        }),
        throwsA(isA<PhraseTemplateStoreException>()),
      );
    });
  });
}
