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
  });
}
