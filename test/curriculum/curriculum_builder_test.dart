import 'package:llm_dataset/llm_dataset.dart';
import 'package:test/test.dart';

void main() {
  group('CurriculumBuilder failIfVersionExists', () {
    final manifest = CurriculumManifest.fromJson({
      'id': 'guard-v1',
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

    test('defaults to true and blocks rebuilding same version', () async {
      final store = MemoryDatasetStore();
      final builder = CurriculumBuilder(manifest: manifest, store: store);
      await builder.buildAll();

      expect(
        () => builder.buildAll(),
        throwsA(isA<DatasetVersionExistsException>()),
      );
    });

    test('skips version guard when failIfVersionExists is false', () async {
      final store = MemoryDatasetStore();
      final builder = CurriculumBuilder(
        manifest: manifest,
        store: store,
        failIfVersionExists: false,
      );
      await builder.buildAll();

      // Version guard is off, but duplicate entry ids still fail during store.
      expect(
        () => builder.buildAll(),
        throwsA(isA<DuplicateEntryException>()),
      );
    });
  });
}
