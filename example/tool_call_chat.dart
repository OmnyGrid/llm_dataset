/// Tool-calling chat entries with `metadata['messages']` for trainer consumption.
library;

import 'package:llm_dataset/llm_dataset.dart';

Future<void> main() async {
  final store = MemoryDatasetStore();
  final config = GeneratorConfig(
    dataset: 'tools',
    datasetVersion: 'v1',
    language: 'en',
    pipelineVersion: 'tool-example',
  );

  final result = await DatasetPipeline(
    source: MemorySource([
      DatasetSourceDocument(
        id: 'weather-doc',
        content:
            'The weather in Paris today is sunny with a high of 22°C. '
            'Rain is expected tomorrow.',
        title: 'Paris weather',
      ),
    ]),
    generator: ToolCallGenerator(config, toolName: 'get_weather'),
    store: store,
    dataset: 'tools',
    datasetVersion: 'v1',
  ).run();

  print('stored=${result.entriesStored}');
  final entry = (await store.query().toList()).single;

  print('type=${entry.type.name} input=${entry.input}');
  print('messages:');
  final messages = entry.metadata['messages'] as List<dynamic>;
  for (final raw in messages) {
    final message = Map<String, dynamic>.from(raw as Map);
    final role = message['role'];
    if (message.containsKey('tool_calls')) {
      final calls = message['tool_calls'] as List<dynamic>;
      final call = Map<String, dynamic>.from(calls.first as Map);
      print('  $role → tool ${call['name']} args=${call['arguments']}');
    } else {
      print('  $role → ${message['content']}');
    }
  }

  // Round-trip through JSONL preserves messages and tool call structure.
  final json = const DatasetExporter().entryToJsonString(entry);
  final restored = const DatasetImporter().entryFromJsonString(json);
  print('round-trip messages=${restored.metadata['messages']?.length}');
}
