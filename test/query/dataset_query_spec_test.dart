import 'package:llm_dataset/llm_dataset.dart';
import 'package:test/test.dart';

DatasetEntry _entry({
  String id = '1',
  String? datasetVersion = 'v1',
  bool canonical = true,
  Map<String, dynamic> metadata = const {},
}) {
  return DatasetEntry(
    id: id,
    dataset: 'd',
    datasetVersion: datasetVersion,
    type: DatasetEntryType.text,
    language: 'en',
    input: 'in',
    variationGroup: 'g',
    variationIndex: canonical ? 0 : 1,
    metadata: metadata,
    provenance: canonical ? null : const DatasetProvenance(parentEntryId: 'p'),
    createdAt: DateTime.utc(2026),
  );
}

void main() {
  group('DatasetQuerySpec', () {
    test('matchesFilters respects metadata deep equality', () {
      const spec = DatasetQuerySpec(
        metadataKey: 'tags',
        metadataValue: ['a', 'b'],
      );
      expect(
        spec.matchesFilters(
          _entry(
            metadata: {
              'tags': ['a', 'b'],
            },
          ),
        ),
        isTrue,
      );
      expect(
        spec.matchesFilters(
          _entry(
            metadata: {
              'tags': ['b', 'a'],
            },
          ),
        ),
        isFalse,
      );
    });

    test('matchNullDatasetVersion filters unversioned rows', () {
      const spec = DatasetQuerySpec(matchNullDatasetVersion: true);
      expect(spec.matchesFilters(_entry(datasetVersion: null)), isTrue);
      expect(spec.matchesFilters(_entry()), isFalse);
    });

    test('requiresFullMaterialization for sample and complex metadata', () {
      expect(
        const DatasetQuerySpec(sampleCount: 1).requiresFullMaterialization,
        isTrue,
      );
      expect(
        const DatasetQuerySpec(
          metadataKey: 'tags',
          metadataValue: ['a'],
        ).requiresFullMaterialization,
        isTrue,
      );
      expect(
        const DatasetQuerySpec(
          metadataKey: 'stage',
          metadataValue: 'math',
        ).requiresFullMaterialization,
        isFalse,
      );
    });

    test('copyWith clears sample and dataset version', () {
      const spec = DatasetQuerySpec(
        datasetVersion: 'v1',
        sampleCount: 5,
        sampleSeed: 1,
      );
      final cleared = spec.copyWith(
        clearSample: true,
        clearDatasetVersion: true,
      );
      expect(cleared.sampleCount, isNull);
      expect(cleared.datasetVersion, isNull);
    });
  });
}
