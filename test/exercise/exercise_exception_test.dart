import 'package:llm_dataset/llm_dataset.dart';
import 'package:test/test.dart';

void main() {
  group('Exercise exceptions', () {
    test('CurriculumException toString includes field and cause', () {
      const error = CurriculumException(
        'bad ratio',
        field: 'mixing.reviewRatio',
        cause: 'out of range',
      );
      expect(error.toString(), contains('mixing.reviewRatio'));
      expect(error.toString(), contains('bad ratio'));
      expect(error.toString(), contains('out of range'));
    });

    test('PhraseTemplateStoreException toString includes path and field', () {
      const error = PhraseTemplateStoreException(
        'invalid template',
        path: '/tmp/templates/a.json',
        field: 'template',
        cause: 'missing slot',
      );
      expect(error.toString(), contains('invalid template'));
      expect(error.toString(), contains('/tmp/templates/a.json'));
      expect(error.toString(), contains('template'));
      expect(error.toString(), contains('missing slot'));
    });
  });
}
