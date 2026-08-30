/// Built-in generators from one source document (no LLM required).
library;

import 'package:llm_dataset/llm_dataset.dart';

Future<void> main() async {
  final document = DatasetSourceDocument(
    id: 'mars',
    content:
        'Mars is the fourth planet from the Sun. '
        'It is often called the Red Planet because of iron oxide on its surface.',
    title: 'Mars',
    language: 'en',
  );

  final config = GeneratorConfig(
    dataset: 'planets',
    datasetVersion: 'v1',
    language: 'en',
    pipelineVersion: 'builtin-demo',
    seed: 42,
  );

  Future<void> runGenerator(String name, DatasetGenerator generator) async {
    final entries = await generator.generate(document).toList();
    print('== $name (${entries.length}) ==');
    for (final entry in entries) {
      print('  type=${entry.type.name}');
      print('  in:  ${entry.input}');
      if (entry.output != null) {
        print('  out: ${entry.output}');
      }
      if (entry.metadata.containsKey('messages')) {
        print(
          '  messages: ${(entry.metadata['messages'] as List).length} turns',
        );
      }
    }
    print('');
  }

  await runGenerator('TextGenerator', TextGenerator(config));
  await runGenerator(
    'QuestionAnswerGenerator',
    QuestionAnswerGenerator(config),
  );
  await runGenerator('SummarizationGenerator', SummarizationGenerator(config));
  await runGenerator(
    'TranslationGenerator',
    TranslationGenerator(config, targetLanguage: 'es'),
  );
  await runGenerator(
    'ClassificationGenerator',
    ClassificationGenerator(config),
  );
  await runGenerator('ExtractionGenerator', ExtractionGenerator(config));
  await runGenerator('ToolCallGenerator', ToolCallGenerator(config));
}
