/// Example LLM-backed [DatasetVariationGenerator] adapter.
library;

import 'package:llm_dataset/llm_dataset.dart';

/// Generates paraphrases via a user-supplied [paraphrase] function.
class LlmParaphraseVariationGenerator implements DatasetVariationGenerator {
  /// Creates an adapter.
  LlmParaphraseVariationGenerator({
    required this.paraphrase,
    this.generatorVersion = 'llm-variation-1.0.0',
    this.instanceId = 'llm-paraphrase',
  });

  /// User-provided paraphrase call.
  final Future<String> Function(String text) paraphrase;

  /// Provenance version string.
  final String generatorVersion;

  /// Stable instance id included in variation entry ids.
  final String instanceId;

  @override
  Future<List<DatasetEntry>> generate(
    DatasetEntry entry, {
    VariationGenerateOptions options = defaultVariationGenerateOptions,
  }) async {
    final rewrittenInput = await paraphrase(entry.input);
    final rewrittenOutput = entry.output == null
        ? null
        : await paraphrase(entry.output!);

    final key = options.instanceId ?? instanceId;
    final id = '${entry.id}-$key-${options.startVariationIndex}';

    return [
      entry.copyWith(
        id: id,
        input: rewrittenInput,
        output: rewrittenOutput,
        variationIndex: options.startVariationIndex,
        metadata: {...entry.metadata, 'variationStrategy': 'llm-paraphrase'},
        provenance: DatasetProvenance(
          source: entry.provenance?.source,
          sourceId: entry.provenance?.sourceId,
          sourceUri: entry.provenance?.sourceUri,
          generator: 'LlmParaphraseVariationGenerator',
          generatorVersion: generatorVersion,
          transformation: 'llm-paraphrase',
          parentEntryId: entry.id,
          pipelineVersion: entry.provenance?.pipelineVersion,
        ),
      ),
    ];
  }
}

/// Deterministic offline paraphrase stub.
Future<String> mockParaphrase(String text) async => 'In other words: $text';
