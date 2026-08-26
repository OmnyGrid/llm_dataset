import 'package:llm_dataset/llm_dataset.dart';
import 'package:test/test.dart';

void main() {
  group('DatasetEntry', () {
    final createdAt = DateTime.utc(2024, 6, 1, 12);

    DatasetEntry canonical() => DatasetEntry(
      id: 'e1',
      dataset: 'general',
      datasetVersion: 'v1',
      type: DatasetEntryType.text,
      language: 'en',
      input: 'What is the capital of France?',
      output: 'Paris',
      thinking: 'Recall European geography.',
      variationGroup: 'abc123',
      variationIndex: 0,
      metadata: const {'topic': 'geography'},
      provenance: const DatasetProvenance(
        source: 'manual',
        sourceId: 'doc-1',
        generator: 'author',
        generatorVersion: '1.0.0',
      ),
      createdAt: createdAt,
    );

    test('creates entry with expected fields', () {
      final entry = canonical();
      expect(entry.id, 'e1');
      expect(entry.dataset, 'general');
      expect(entry.datasetVersion, 'v1');
      expect(entry.type, DatasetEntryType.text);
      expect(entry.language, 'en');
      expect(entry.input, contains('France'));
      expect(entry.output, 'Paris');
      expect(entry.thinking, isNotNull);
      expect(entry.variationGroup, 'abc123');
      expect(entry.variationIndex, 0);
      expect(entry.metadata['topic'], 'geography');
      expect(entry.provenance?.source, 'manual');
      expect(entry.createdAt, createdAt);
    });

    test('isCanonical when index 0 and no parent', () {
      expect(canonical().isCanonical, isTrue);
    });

    test('isCanonical false for variations with parent', () {
      final variation = canonical().copyWith(
        id: 'e1-v1',
        variationIndex: 1,
        provenance: const DatasetProvenance(
          parentEntryId: 'e1',
          transformation: 'paraphrase',
        ),
      );
      expect(variation.isCanonical, isFalse);
      expect(variation.provenance?.parentEntryId, 'e1');
    });

    test('isCanonical false when parent set even if index 0', () {
      final entry = canonical().copyWith(
        provenance: const DatasetProvenance(parentEntryId: 'other'),
      );
      expect(entry.isCanonical, isFalse);
    });

    test('equality and hashCode use id', () {
      final a = canonical();
      final b = canonical().copyWith(input: 'Different text');
      final c = canonical().copyWith(id: 'other');
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(c)));
    });

    test('metadata is unmodifiable', () {
      final entry = canonical();
      expect(() => entry.metadata['x'] = 'y', throwsUnsupportedError);
    });

    test('copyWith replaces and clears fields', () {
      final entry = canonical().copyWith(
        output: 'Lyon',
        clearThinking: true,
        clearDatasetVersion: true,
      );
      expect(entry.output, 'Lyon');
      expect(entry.thinking, isNull);
      expect(entry.datasetVersion, isNull);
      expect(entry.id, 'e1');
    });

    test('messages and toolCalls helpers', () {
      final entry = DatasetEntry(
        id: 'tool-1',
        dataset: 'tools',
        type: DatasetEntryType.toolCall,
        language: 'en',
        input: 'What is the weather in Paris?',
        variationGroup: 'g1',
        variationIndex: 0,
        metadata: {
          datasetMessagesMetadataKey: [
            {'role': 'user', 'content': 'What is the weather in Paris?'},
            {
              'role': 'assistant',
              'content': null,
              'tool_calls': [
                {
                  'name': 'get_weather',
                  'arguments': {'city': 'Paris'},
                },
              ],
            },
            {
              'role': 'tool',
              'tool_call_id': 'call_1',
              'content': '{"temp": 20}',
            },
            {'role': 'assistant', 'content': 'It is 20C in Paris.'},
          ],
        },
        createdAt: createdAt,
      );

      expect(entry.messages, hasLength(4));
      expect(entry.toolCalls, hasLength(1));
      expect(entry.toolCalls.first.name, 'get_weather');
      expect(entry.toolCalls.first.arguments['city'], 'Paris');
    });
  });

  group('DatasetProvenance', () {
    test('equality by fields', () {
      const a = DatasetProvenance(source: 's', parentEntryId: 'p');
      const b = DatasetProvenance(source: 's', parentEntryId: 'p');
      const c = DatasetProvenance(source: 'other');
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('copyWith clear flags', () {
      const original = DatasetProvenance(
        source: 's',
        generator: 'g',
        parentEntryId: 'p',
      );
      final cleared = original.copyWith(clearParentEntryId: true);
      expect(cleared.parentEntryId, isNull);
      expect(cleared.source, 's');
    });
  });

  group('DatasetToolCall', () {
    test('equality compares name and arguments', () {
      const a = DatasetToolCall(name: 'f', arguments: {'x': 1});
      const b = DatasetToolCall(name: 'f', arguments: {'x': 1});
      const c = DatasetToolCall(name: 'f', arguments: {'x': 2});
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });

  group('DatasetEntryType', () {
    test('round-trips via name', () {
      for (final type in DatasetEntryType.values) {
        expect(datasetEntryTypeFromName(type.name), type);
      }
    });

    test('unknown name throws', () {
      expect(() => datasetEntryTypeFromName('nope'), throwsArgumentError);
    });
  });
}
