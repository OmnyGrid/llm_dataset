import 'package:llm_dataset/llm_dataset.dart';
import 'package:test/test.dart';

import '../test_paths.dart';

void main() {
  group('CurriculumLifecycle stageStats', () {
    test('returns counts for every manifest stage', () async {
      final manifest = await CurriculumManifest.loadFile(
        TestPaths.curriculumManifest,
      );
      final store = MemoryDatasetStore();
      await CurriculumBuilder(
        manifest: manifest,
        store: store,
        registry: CurriculumStageBuilderRegistry(
          phraseTemplateRootResolver: (path) => path,
        ),
      ).buildAll();

      final lifecycle = CurriculumLifecycle(store: store, manifest: manifest);
      final stats = await lifecycle.stageStats();

      for (final stage in manifest.stages) {
        expect(stats[stage.id], greaterThan(0));
      }
      expect(stats.keys, manifest.stages.map((s) => s.id).toSet());
    });
  });
}
