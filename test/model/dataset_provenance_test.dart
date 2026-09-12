import 'package:llm_dataset/llm_dataset.dart';
import 'package:test/test.dart';

void main() {
  group('DatasetProvenance', () {
    const provenance = DatasetProvenance(
      source: 'wiki',
      sourceId: 'doc-1',
      sourceUri: 'file:///a.txt',
      generator: 'TextGenerator',
      generatorVersion: '1.0',
      transformation: 'paraphrase',
      parentEntryId: 'parent-1',
      pipelineVersion: 'pipe-1',
    );

    test('json round trip preserves all fields', () {
      final decoded = DatasetProvenance.fromJson(provenance.toJson());
      expect(decoded, provenance);
    });

    test('copyWith clears optional fields', () {
      final cleared = provenance.copyWith(
        clearSource: true,
        clearSourceId: true,
        clearSourceUri: true,
        clearGenerator: true,
        clearGeneratorVersion: true,
        clearTransformation: true,
        clearParentEntryId: true,
        clearPipelineVersion: true,
      );
      expect(cleared.toJson(), isEmpty);
    });

    test('copyWith replaces selected fields', () {
      final updated = provenance.copyWith(
        generator: 'QAGenerator',
        pipelineVersion: 'pipe-2',
      );
      expect(updated.generator, 'QAGenerator');
      expect(updated.pipelineVersion, 'pipe-2');
      expect(updated.source, provenance.source);
    });

    test('toString includes serialized json', () {
      expect(provenance.toString(), contains('TextGenerator'));
      expect(provenance.toString(), contains('wiki'));
    });

    test('equality and hashCode use all fields', () {
      const other = DatasetProvenance(
        source: 'wiki',
        sourceId: 'doc-1',
        sourceUri: 'file:///a.txt',
        generator: 'TextGenerator',
        generatorVersion: '1.0',
        transformation: 'paraphrase',
        parentEntryId: 'parent-1',
        pipelineVersion: 'pipe-1',
      );
      expect(provenance, other);
      expect(provenance.hashCode, other.hashCode);
      expect(provenance, isNot(provenance.copyWith(source: 'other')));
    });
  });
}
