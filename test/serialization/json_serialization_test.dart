import 'dart:convert';

import 'package:llm_dataset/llm_dataset.dart';
import 'package:test/test.dart';

void main() {
  group('JSON serialization', () {
    final createdAt = DateTime.utc(2024, 6, 1, 12, 30, 0);

    test('DatasetEntry round trip preserves fields', () {
      final original = DatasetEntry(
        id: 'e1',
        dataset: 'general',
        datasetVersion: 'v1',
        type: DatasetEntryType.reasoning,
        language: 'en',
        input: 'Q?',
        output: 'A',
        thinking: 'Because',
        variationGroup: 'g',
        variationIndex: 0,
        metadata: {
          'topic': 'math',
          datasetMessagesMetadataKey: [
            {'role': 'user', 'content': 'Q?'},
          ],
        },
        provenance: const DatasetProvenance(
          source: 'wiki',
          sourceId: '1',
          sourceUri: 'https://example.com',
          generator: 'gen',
          generatorVersion: '2',
          transformation: null,
          parentEntryId: null,
          pipelineVersion: 'p1',
        ),
        createdAt: createdAt,
      );

      final json = original.toJson();
      final restored = DatasetEntry.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.dataset, original.dataset);
      expect(restored.datasetVersion, original.datasetVersion);
      expect(restored.type, original.type);
      expect(restored.language, original.language);
      expect(restored.input, original.input);
      expect(restored.output, original.output);
      expect(restored.thinking, original.thinking);
      expect(restored.variationGroup, original.variationGroup);
      expect(restored.variationIndex, original.variationIndex);
      expect(restored.metadata['topic'], 'math');
      expect(restored.messages, hasLength(1));
      expect(restored.provenance, original.provenance);
      expect(restored.createdAt.isUtc, isTrue);
      expect(restored.createdAt, original.createdAt);
    });

    test('omits null optional fields', () {
      final entry = DatasetEntry(
        id: 'e2',
        dataset: 'd',
        type: DatasetEntryType.text,
        language: 'en',
        input: 'hi',
        variationGroup: 'g',
        variationIndex: 0,
        createdAt: createdAt,
      );
      final json = entry.toJson();
      expect(json.containsKey('output'), isFalse);
      expect(json.containsKey('thinking'), isFalse);
      expect(json.containsKey('datasetVersion'), isFalse);
      expect(json.containsKey('provenance'), isFalse);
      expect(json['metadata'], isEmpty);
    });

    test('timestamps serialize as UTC ISO-8601', () {
      final localish = DateTime.utc(2024, 1, 2, 3, 4, 5, 6);
      final entry = DatasetEntry(
        id: 'e3',
        dataset: 'd',
        type: DatasetEntryType.text,
        language: 'en',
        input: 'x',
        variationGroup: 'g',
        variationIndex: 0,
        createdAt: localish,
      );
      expect(entry.toJson()['createdAt'], '2024-01-02T03:04:05.006Z');
    });

    test('DatasetToolCall round trip', () {
      const call = DatasetToolCall(
        name: 'search',
        arguments: {'q': 'dart', 'n': 3},
      );
      expect(DatasetToolCall.fromJson(call.toJson()), call);
    });

    test('DatasetProvenance round trip omits nulls', () {
      const provenance = DatasetProvenance(source: 's', parentEntryId: 'p');
      final json = provenance.toJson();
      expect(json.keys, ['parentEntryId', 'source']);
      expect(DatasetProvenance.fromJson(json), provenance);
    });

    test('top-level entry keys are ordered', () {
      final entry = DatasetEntry(
        id: 'z',
        dataset: 'a',
        type: DatasetEntryType.chat,
        language: 'en',
        input: 'i',
        output: 'o',
        variationGroup: 'g',
        variationIndex: 0,
        createdAt: createdAt,
      );
      final encoded = jsonEncode(entry.toJson());
      final keys = (jsonDecode(encoded) as Map<String, dynamic>).keys.toList();
      final sorted = [...keys]..sort();
      expect(keys, sorted);
    });

    test('messages with tool calls survive JSON round trip', () {
      final entry = DatasetEntry(
        id: 't1',
        dataset: 'tools',
        type: DatasetEntryType.toolCall,
        language: 'en',
        input: 'weather?',
        variationGroup: 'g',
        variationIndex: 0,
        metadata: {
          datasetMessagesMetadataKey: [
            {
              'role': 'assistant',
              'tool_calls': [
                {
                  'name': 'get_weather',
                  'arguments': {'city': 'Paris'},
                },
              ],
            },
          ],
        },
        createdAt: createdAt,
      );
      final restored = DatasetEntry.fromJson(entry.toJson());
      expect(restored.toolCalls.single.name, 'get_weather');
      expect(restored.toolCalls.single.arguments['city'], 'Paris');
    });
  });
}
