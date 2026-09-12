import '../model/dataset_entry.dart';
import '../serialization/dataset_codec.dart';
import '../store/dataset_store.dart';
import '../store/sqlite_dataset_store.dart';
import 'curriculum_dataset.dart';
import 'curriculum_manifest.dart';
import 'curriculum_metadata.dart';
import 'curriculum_mixing.dart';

/// Curriculum-aware lifecycle helpers over a [DatasetStore].
class CurriculumLifecycle {
  /// Creates lifecycle helpers for [store] and [manifest].
  CurriculumLifecycle({required this.store, required this.manifest});

  /// Underlying store.
  final DatasetStore store;

  /// Curriculum manifest.
  final CurriculumManifest manifest;

  /// Lists distinct curriculum stage ids present in the store.
  Future<List<String>> listStages() async {
    if (store is SqliteDatasetStore) {
      return (store as SqliteDatasetStore).listDistinctMetadataValues(
        CurriculumMetadataKeys.curriculumStage,
      );
    }

    final stages = <String>{};
    await for (final entry in store.stream()) {
      final stage = entry.metadata[CurriculumMetadataKeys.curriculumStage];
      if (stage is String && stage.isNotEmpty) {
        stages.add(stage);
      }
    }
    final list = stages.toList()..sort();
    return list;
  }

  /// Counts entries tagged with [stageId].
  Future<int> countStage(String stageId) async {
    var count = 0;
    await for (final _ in CurriculumMixing.stageQuery(
      store,
      stageId,
    ).stream()) {
      count++;
    }
    return count;
  }

  /// Exports a curriculum stage slice to JSONL at [path].
  ///
  /// When [mixing] is provided, uses [CurriculumDataset.streamPhase] semantics.
  /// Otherwise exports exclusive entries for [stageId].
  Future<void> exportStageJsonl(
    String stageId,
    String path, {
    CurriculumMixingPolicy? mixing,
    int? seed,
    int? limit,
  }) async {
    manifest.stage(stageId);

    late final Stream<DatasetEntry> stream;
    final stageDef = manifest.stage(stageId);
    final useMixed =
        (mixing ?? stageDef.mixing).isMixed &&
        (mixing?.isMixed ?? stageDef.mixing.isMixed);

    if (useMixed) {
      final effectiveManifest = mixing != null
          ? CurriculumManifest(
              id: manifest.id,
              initialLayers: manifest.initialLayers,
              stages: [
                for (final s in manifest.stages)
                  if (s.id == stageId) s.copyWith(mixing: mixing) else s,
              ],
            )
          : manifest;
      stream = CurriculumDataset(
        store: store,
        manifest: effectiveManifest,
      ).streamPhase(stageId, seed: seed, limit: limit);
    } else {
      var query = CurriculumMixing.stageQuery(store, stageId);
      if (limit != null) {
        query = query.limit(limit);
      }
      stream = query.stream();
    }

    const exporter = DatasetExporter();
    await exporter.writeJsonlFile(stream, path);
  }
}

/// Extension helpers for stage definition copies (testing / export overrides).
extension CurriculumStageDefinitionCopy on CurriculumStageDefinition {
  /// Returns a copy with an overridden [mixing] policy.
  CurriculumStageDefinition copyWith({CurriculumMixingPolicy? mixing}) {
    return CurriculumStageDefinition(
      id: id,
      order: order,
      layersWhenActive: layersWhenActive,
      dataset: dataset,
      datasetVersion: datasetVersion,
      mixing: mixing ?? this.mixing,
      sources: sources,
    );
  }
}
