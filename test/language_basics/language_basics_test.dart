import 'package:llm_dataset/llm_dataset.dart';
import 'package:test/test.dart';

void main() {
  group('LanguageBasicsCatalog', () {
    test('generic english profile exposes four patterns', () {
      final catalog = languageBasicsCatalogFor(
        locale: 'en',
        profile: 'generic',
      );

      expect(catalog.patterns, hasLength(4));
      expect(catalog.documents(), hasLength(4));
      expect(catalog.patternMap().keys, catalog.patterns.map((p) => p.id));
    });

    test('rejects unsupported locale and profile', () {
      expect(
        () => languageBasicsCatalogFor(locale: 'pt', profile: 'generic'),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => languageBasicsCatalogFor(locale: 'en', profile: 'advanced'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('LanguageBasicsGenerator', () {
    test('generates simple phrases with phrase metadata', () async {
      final catalog = languageBasicsCatalogFor(
        locale: 'en',
        profile: 'generic',
      );
      final generator = LanguageBasicsGenerator(
        config: const GeneratorConfig(
          dataset: 'curriculum',
          datasetVersion: 'language_basics-v1',
          language: 'en',
        ),
        patterns: catalog.patternMap(),
        lexicon: catalog.lexicon,
      );

      final entries = <DatasetEntry>[];
      for (final doc in catalog.documents()) {
        await for (final entry in generator.generate(doc)) {
          entries.add(entry);
        }
      }

      expect(entries, hasLength(4));
      expect(entries.first.input, 'The cat.');
      expect(entries.first.metadata['textKind'], 'language_basics');
      expect(entries.first.metadata['complexityTier'], 0);
      expect(
        entries.first.metadata[TextExerciseMetadata.semanticKeys],
        isA<Map>(),
      );
    });

    test('unknown pattern id throws', () {
      final catalog = languageBasicsCatalogFor(
        locale: 'en',
        profile: 'generic',
      );
      final generator = LanguageBasicsGenerator(
        config: const GeneratorConfig(
          dataset: 'curriculum',
          datasetVersion: 'language_basics-v1',
          language: 'en',
        ),
        patterns: catalog.patternMap(),
        lexicon: catalog.lexicon,
      );

      expect(
        generator.generate(DatasetSourceDocument(id: 'missing', content: 'x')),
        emitsError(isA<ArgumentError>()),
      );
    });

    test('pipeline with curriculum builder tags entries', () async {
      final manifest = CurriculumManifest.fromJson({
        'id': 'lb-only',
        'initialLayers': 2,
        'stages': [
          {
            'id': 'language_basics',
            'order': 0,
            'layersWhenActive': 2,
            'dataset': 'curriculum',
            'datasetVersion': 'lb-v1',
            'mixing': {'mode': 'exclusive'},
            'sources': [
              {'kind': 'language_basics', 'locale': 'en', 'profile': 'generic'},
            ],
          },
        ],
      });

      final store = MemoryDatasetStore();
      await CurriculumBuilder(manifest: manifest, store: store).buildAll();

      final entry = await store.stream().first;
      expect(entry.metadata[CurriculumMetadataKeys.curriculumId], 'lb-only');
      expect(entry.metadata[CurriculumMetadataKeys.curriculumStageOrder], 0);
    });
  });
}
