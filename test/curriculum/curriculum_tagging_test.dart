import 'package:llm_dataset/llm_dataset.dart';
import 'package:test/test.dart';

void main() {
  group('CurriculumTaggingGenerator', () {
    test('stamps curriculum metadata on generated entries', () async {
      final inner = LanguageBasicsGenerator(
        config: const GeneratorConfig(
          dataset: 'curriculum',
          datasetVersion: 'lb-v1',
          language: 'en',
        ),
        patterns: languageBasicsCatalogFor(
          locale: 'en',
          profile: 'generic',
        ).patternMap(),
        lexicon: languageBasicsCatalogFor(
          locale: 'en',
          profile: 'generic',
        ).lexicon,
      );

      final tagging = CurriculumTaggingGenerator(
        inner: inner,
        curriculumId: 'test-curriculum',
        stageId: 'language_basics',
        stageOrder: 0,
      );

      final doc = languageBasicsCatalogFor(
        locale: 'en',
        profile: 'generic',
      ).documents().first;

      final entry = await tagging.generate(doc).first;
      expect(
        entry.metadata[CurriculumMetadataKeys.curriculumId],
        'test-curriculum',
      );
      expect(
        entry.metadata[CurriculumMetadataKeys.curriculumStage],
        'language_basics',
      );
      expect(entry.metadata[CurriculumMetadataKeys.curriculumStageOrder], 0);
      expect(entry.metadata[ExerciseMetadataKeys.complexityTier], 0);
    });

    test('preserves complexityTier from entry metadata', () async {
      final inner = _TieredStubGenerator(tier: 2);
      final tagging = CurriculumTaggingGenerator(
        inner: inner,
        curriculumId: 'c',
        stageId: 'math',
        stageOrder: 3,
      );

      final entry = await tagging
          .generate(DatasetSourceDocument(id: 'x', content: 'x'))
          .first;

      expect(entry.metadata[ExerciseMetadataKeys.complexityTier], 2);
    });
  });
}

class _TieredStubGenerator implements DatasetGenerator {
  _TieredStubGenerator({required this.tier});

  final int tier;

  @override
  Stream<DatasetEntry> generate(DatasetSourceDocument document) async* {
    yield DatasetEntry(
      id: 'stub',
      dataset: 'curriculum',
      type: DatasetEntryType.text,
      language: 'en',
      input: 'q',
      output: 'a',
      variationGroup: 'g',
      variationIndex: 0,
      metadata: {'complexityTier': tier},
      createdAt: DateTime.utc(2026),
    );
  }
}
