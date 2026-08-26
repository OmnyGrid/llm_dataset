import '../generator/dataset_generator.dart';
import '../model/dataset_entry.dart';
import '../source/dataset_source.dart';
import '../store/dataset_store.dart';
import '../validation/dataset_validator.dart';
import '../variation/dataset_variation_generator.dart';

/// Summary of a [DatasetPipeline.run] invocation.
class DatasetPipelineResult {
  /// Creates a pipeline result.
  const DatasetPipelineResult({
    required this.documentsSeen,
    required this.entriesGenerated,
    required this.entriesStored,
    required this.entriesRejected,
    required this.rejections,
  });

  /// Number of source documents consumed.
  final int documentsSeen;

  /// Canonical + variation entries produced before validation.
  final int entriesGenerated;

  /// Entries successfully written to the store.
  final int entriesStored;

  /// Entries rejected by validators (processing continued).
  final int entriesRejected;

  /// Validation failures collected during the run.
  final List<DatasetValidationResult> rejections;
}

/// Thrown when a pipeline refuses to overwrite an existing dataset version.
class DatasetVersionExistsException implements Exception {
  /// Creates an exception for [dataset] / [datasetVersion].
  DatasetVersionExistsException(this.dataset, this.datasetVersion);

  /// Dataset name.
  final String dataset;

  /// Dataset version that already exists.
  final String datasetVersion;

  @override
  String toString() =>
      'DatasetVersionExistsException: dataset "$dataset" version '
      '"$datasetVersion" already has entries';
}

/// Incremental pipeline: source → generator → variations → validators → store.
///
/// Operates with streams and never requires the complete dataset in memory.
/// Invalid entries are skipped after recording a rejection; infrastructure
/// failures (e.g. store errors) propagate to the caller.
class DatasetPipeline {
  /// Creates a dataset pipeline.
  DatasetPipeline({
    required this.source,
    required this.generator,
    required this.store,
    this.variations = const [],
    this.validators = const [],
    this.dataset,
    this.datasetVersion,
    this.failIfVersionExists = true,
  });

  /// Document source.
  final DatasetSource source;

  /// Canonical entry generator.
  final DatasetGenerator generator;

  /// Zero or more variation generators applied to each canonical entry.
  final List<DatasetVariationGenerator> variations;

  /// Zero or more validators; all must pass for an entry to be stored.
  final List<DatasetValidator> validators;

  /// Destination store.
  final DatasetStore store;

  /// Optional dataset name used for version isolation checks.
  final String? dataset;

  /// Optional dataset version used for version isolation checks.
  final String? datasetVersion;

  /// When true, refuses to run if [dataset]/[datasetVersion] already has rows.
  final bool failIfVersionExists;

  /// Runs the pipeline to completion.
  Future<DatasetPipelineResult> run() async {
    if (failIfVersionExists &&
        dataset != null &&
        datasetVersion != null &&
        await _versionExists(dataset!, datasetVersion!)) {
      throw DatasetVersionExistsException(dataset!, datasetVersion!);
    }

    var documentsSeen = 0;
    var entriesGenerated = 0;
    var entriesStored = 0;
    var entriesRejected = 0;
    final rejections = <DatasetValidationResult>[];

    await for (final document in source.load()) {
      documentsSeen++;
      await for (final canonical in generator.generate(document)) {
        final batch = <DatasetEntry>[canonical];
        for (final variationGenerator in variations) {
          batch.addAll(await variationGenerator.generate(canonical));
        }

        for (final entry in batch) {
          entriesGenerated++;
          final validation = await _validate(entry);
          if (!validation.isValid) {
            entriesRejected++;
            rejections.add(validation);
            continue;
          }
          await store.add(entry);
          entriesStored++;
        }
      }
    }

    return DatasetPipelineResult(
      documentsSeen: documentsSeen,
      entriesGenerated: entriesGenerated,
      entriesStored: entriesStored,
      entriesRejected: entriesRejected,
      rejections: rejections,
    );
  }

  Future<DatasetValidationResult> _validate(DatasetEntry entry) async {
    if (validators.isEmpty) {
      return DatasetValidationResult.valid(entryId: entry.id);
    }
    final results = <DatasetValidationResult>[];
    for (final validator in validators) {
      results.add(await validator.validate(entry));
    }
    return DatasetValidationResult.merge(results);
  }

  Future<bool> _versionExists(String datasetName, String version) async {
    final found = await store
        .query()
        .dataset(datasetName)
        .datasetVersion(version)
        .limit(1)
        .toList();
    return found.isNotEmpty;
  }
}
