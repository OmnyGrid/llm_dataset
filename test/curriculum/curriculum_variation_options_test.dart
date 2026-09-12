import 'package:llm_dataset/llm_dataset.dart';
import 'package:test/test.dart';

void main() {
  group('resolveCurriculumVariationsPerEntry', () {
    const builderOptions = CurriculumVariationOptions(variationsPerEntry: 1);

    test('source overrides stage and builder', () {
      expect(
        resolveCurriculumVariationsPerEntry(
          builderOptions: builderOptions,
          stageVariationsPerEntry: 2,
          sourceVariationsPerEntry: 3,
          combinatorial: false,
        ),
        3,
      );
    });

    test('stage overrides builder when source unset', () {
      expect(
        resolveCurriculumVariationsPerEntry(
          builderOptions: builderOptions,
          stageVariationsPerEntry: 2,
          sourceVariationsPerEntry: null,
          combinatorial: false,
        ),
        2,
      );
    });

    test('builder default applies when stage and source unset', () {
      expect(
        resolveCurriculumVariationsPerEntry(
          builderOptions: builderOptions,
          stageVariationsPerEntry: null,
          sourceVariationsPerEntry: null,
          combinatorial: false,
        ),
        1,
      );
    });

    test('combinatorial sources skip variations', () {
      expect(
        resolveCurriculumVariationsPerEntry(
          builderOptions: builderOptions,
          stageVariationsPerEntry: 2,
          sourceVariationsPerEntry: 3,
          combinatorial: true,
        ),
        isNull,
      );
    });

    test('zero variationsPerEntry treated as disabled', () {
      expect(
        resolveCurriculumVariationsPerEntry(
          builderOptions: const CurriculumVariationOptions(
            variationsPerEntry: 0,
          ),
          stageVariationsPerEntry: null,
          sourceVariationsPerEntry: null,
          combinatorial: false,
        ),
        isNull,
      );
    });
  });
}
