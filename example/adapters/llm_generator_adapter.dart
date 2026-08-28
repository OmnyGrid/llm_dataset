/// Example LLM-backed [DatasetGenerator] adapter (no external SDK dependency).
///
/// Replace [mockLlmComplete] with calls to your own HTTP/gRPC/FFI client.
library;

import 'package:llm_dataset/llm_dataset.dart';

/// Minimal async text completion used by adapter examples.
typedef LlmComplete = Future<String> Function(String prompt);

/// Generates canonical Q/A entries by calling a user-supplied [complete] fn.
class LlmQuestionAnswerGenerator implements DatasetGenerator {
  /// Creates an adapter around [complete].
  LlmQuestionAnswerGenerator({
    required this.config,
    required this.complete,
    this.generatorVersion = 'llm-adapter-1.0.0',
  });

  /// Target dataset configuration.
  final GeneratorConfig config;

  /// User-provided model call (HTTP, local runtime, etc.).
  final LlmComplete complete;

  /// Recorded in provenance.
  final String generatorVersion;

  @override
  Stream<DatasetEntry> generate(DatasetSourceDocument document) async* {
    final prompt =
        'Read the document and write one concise question about it, '
        'then answer it.\n\nDocument:\n${document.content}';

    final modelOutput = await complete(prompt);
    final lines = modelOutput.split('\n').where((l) => l.trim().isNotEmpty);
    final question = lines.isEmpty ? modelOutput : lines.first;
    final answer = lines.length > 1 ? lines.elementAt(1) : modelOutput;

    yield DatasetEntry(
      id: '${document.id}-llm-qa',
      dataset: config.dataset,
      datasetVersion: config.datasetVersion,
      type: DatasetEntryType.text,
      language: document.language ?? config.language,
      input: question.trim(),
      output: answer.trim(),
      variationGroup: document.id,
      variationIndex: 0,
      metadata: {'sourceDocumentId': document.id, 'adapter': 'llm'},
      provenance: DatasetProvenance(
        source: 'document',
        sourceId: document.id,
        generator: 'LlmQuestionAnswerGenerator',
        generatorVersion: generatorVersion,
        pipelineVersion: config.pipelineVersion,
      ),
      createdAt: DateTime.now().toUtc(),
    );
  }
}

/// Deterministic stub for tests and offline demos.
Future<String> mockLlmComplete(String prompt) async {
  if (prompt.contains('France')) {
    return 'What is the capital of France?\nParis';
  }
  if (prompt.contains('Spain')) {
    return 'What is the capital of Spain?\nMadrid';
  }
  return 'Summarize the document.\nSee document text.';
}
