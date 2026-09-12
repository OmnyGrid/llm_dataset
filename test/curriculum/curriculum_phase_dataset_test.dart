import 'package:llm_dataset/llm_dataset.dart';
import 'package:test/test.dart';

import '../test_paths.dart';

void main() {
  group('CurriculumPhaseDataset', () {
    late CurriculumManifest manifest;
    late MemoryDatasetStore store;

    setUp(() async {
      manifest = await CurriculumManifest.loadFile(
        TestPaths.curriculumManifest,
      );
      store = MemoryDatasetStore();
      await CurriculumBuilder(
        manifest: manifest,
        store: store,
        registry: CurriculumStageBuilderRegistry(
          phraseTemplateRootResolver: (path) => path,
        ),
      ).buildAll();
    });

    test('mixed() interleaves review stage entries', () async {
      final curriculum = CurriculumDataset(store: store, manifest: manifest);
      final mixedDataset = curriculum.mixed('phrases', seed: 7);
      expect(mixedDataset, isA<CurriculumPhaseDataset>());

      final entries = await mixedDataset.stream(limit: 40).toList();
      expect(entries, isNotEmpty);
      expect(
        entries.any(
          (e) =>
              e.metadata[CurriculumMetadataKeys.curriculumStage] ==
              'language_basics',
        ),
        isTrue,
      );
      expect(
        entries.any(
          (e) =>
              e.metadata[CurriculumMetadataKeys.curriculumStage] == 'phrases',
        ),
        isTrue,
      );
    });

    test('mixed() rejects shuffle for non-exclusive phases', () {
      final curriculum = CurriculumDataset(store: store, manifest: manifest);
      final mixedDataset = curriculum.mixed('phrases');
      expect(
        () => mixedDataset.stream(shuffle: true).listen((_) {}),
        throwsArgumentError,
      );
    });

    test('mixed batches interleave review entries', () async {
      final curriculum = CurriculumDataset(store: store, manifest: manifest);
      final mixedDataset = curriculum.mixed('phrases', seed: 11);

      final batches = await mixedDataset.batches(16, limit: 32).toList();
      final entries = batches.expand((b) => b).toList();
      expect(entries, isNotEmpty);
      expect(
        entries.any(
          (e) =>
              e.metadata[CurriculumMetadataKeys.curriculumStage] ==
              'language_basics',
        ),
        isTrue,
      );
    });

    test('mixed batches rejects sample on non-exclusive phase', () {
      final curriculum = CurriculumDataset(store: store, manifest: manifest);
      final mixedDataset = curriculum.mixed('phrases');
      expect(
        () => mixedDataset.batches(8, sample: 4).listen((_) {}),
        throwsArgumentError,
      );
    });

    test('exclusive mixed() behaves like exclusive()', () async {
      final curriculum = CurriculumDataset(store: store, manifest: manifest);
      final viaMixed = await curriculum
          .mixed('language_basics')
          .stream()
          .toList();
      final viaExclusive = await curriculum
          .exclusive('language_basics')
          .stream()
          .toList();
      expect(
        viaMixed.map((e) => e.id).toList(),
        viaExclusive.map((e) => e.id).toList(),
      );
    });
  });
}
