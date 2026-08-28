import '../model/dataset_entry.dart';
import '../model/dataset_entry_type.dart';
import '../model/dataset_provenance.dart';
import '../source/dataset_source.dart';
import '../util/ids.dart';
import 'dataset_generator.dart';

/// Shared helpers for built-in canonical generators.
DatasetEntry buildCanonicalEntry({
  required GeneratorConfig config,
  required DatasetSourceDocument document,
  required String generatorName,
  required DatasetEntryType type,
  required String input,
  String? output,
  String? thinking,
  Map<String, dynamic>? extraMetadata,
  int index = 0,
}) {
  final language = document.language ?? config.language;
  final variationGroup = stableDatasetId([
    config.dataset,
    config.datasetVersion,
    document.id,
    generatorName,
  ]);
  final id = stableDatasetId([variationGroup, index, 'canonical']);

  final createdAt = config.seed == null
      ? DateTime.now().toUtc()
      : _deterministicCreatedAt(config.seed!, document.id, index);

  return DatasetEntry(
    id: id,
    dataset: config.dataset,
    datasetVersion: config.datasetVersion,
    type: type,
    language: language,
    input: input,
    output: output,
    thinking: thinking,
    variationGroup: variationGroup,
    variationIndex: 0,
    metadata: {
      'sourceDocumentId': document.id,
      if (document.title != null) 'sourceTitle': document.title,
      ...document.metadata,
      ...?extraMetadata,
    },
    provenance: DatasetProvenance(
      source: 'document',
      sourceId: document.id,
      sourceUri: document.metadata['path'] as String?,
      generator: generatorName,
      generatorVersion: config.generatorVersion,
      pipelineVersion: config.pipelineVersion,
    ),
    createdAt: createdAt,
  );
}

DateTime _deterministicCreatedAt(int seed, String documentId, int index) {
  final offset = int.parse(
    stableDatasetId([seed, documentId, index]).substring(0, 8),
    radix: 16,
  );
  return DateTime.fromMillisecondsSinceEpoch(
    seed + (offset % 86400000),
    isUtc: true,
  );
}

String firstSentence(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) {
    return trimmed;
  }
  final match = RegExp(r'(.+?[.!?])(\s|$)', dotAll: true).firstMatch(trimmed);
  if (match != null) {
    return match.group(1)!.trim();
  }
  final line = trimmed.split('\n').first.trim();
  if (line.length <= 160) {
    return line;
  }
  return '${line.substring(0, 157)}...';
}

String clip(String text, int maxChars) {
  final trimmed = text.trim();
  if (trimmed.length <= maxChars) {
    return trimmed;
  }
  return '${trimmed.substring(0, maxChars - 3)}...';
}
