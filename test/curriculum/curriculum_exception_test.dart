import 'package:llm_dataset/llm_dataset.dart';
import 'package:test/test.dart';

void main() {
  group('CurriculumException', () {
    test('wraps manifest validation failures', () {
      expect(
        () => CurriculumManifest.fromJson({
          'id': 'x',
          'initialLayers': 1,
          'stages': [
            {
              'id': 'a',
              'order': 0,
              'layersWhenActive': 1,
              'dataset': 'd',
              'datasetVersion': 'v1',
              'mixing': {'mode': 'mixed', 'reviewRatio': 2.0},
              'sources': [
                {'kind': 'math_catalog', 'locale': 'en'},
              ],
            },
          ],
        }),
        throwsA(isA<CurriculumException>()),
      );
    });

    test('rejects duplicate stage ids', () {
      expect(
        () => CurriculumManifest.fromJson({
          'id': 'dup',
          'initialLayers': 1,
          'stages': [
            {
              'id': 'same',
              'order': 0,
              'layersWhenActive': 1,
              'dataset': 'd',
              'datasetVersion': 'v1',
              'mixing': {'mode': 'exclusive'},
              'sources': [
                {'kind': 'math_catalog', 'locale': 'en'},
              ],
            },
            {
              'id': 'same',
              'order': 1,
              'layersWhenActive': 2,
              'dataset': 'd',
              'datasetVersion': 'v2',
              'mixing': {'mode': 'exclusive'},
              'sources': [
                {'kind': 'math_catalog', 'locale': 'en'},
              ],
            },
          ],
        }),
        throwsA(isA<CurriculumException>()),
      );
    });
  });
}
