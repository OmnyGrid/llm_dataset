import 'curriculum_manifest.dart';

/// Summary of building one curriculum stage.
class CurriculumStageBuildResult {
  /// Creates a stage build result.
  const CurriculumStageBuildResult({
    required this.stageId,
    required this.documentsSeen,
    required this.entriesGenerated,
    required this.entriesStored,
    required this.entriesRejected,
  });

  /// Stage that was built.
  final String stageId;

  /// Source documents consumed.
  final int documentsSeen;

  /// Entries produced before validation.
  final int entriesGenerated;

  /// Entries written to the store.
  final int entriesStored;

  /// Entries rejected by validators.
  final int entriesRejected;

  /// Total entries stored for convenience.
  int get entryCount => entriesStored;
}

/// Summary of a [CurriculumBuilder] invocation.
class CurriculumBuildResult {
  /// Creates a build result.
  const CurriculumBuildResult({
    required this.curriculumId,
    required this.stageResults,
  });

  /// Manifest id.
  final String curriculumId;

  /// Per-stage summaries keyed by stage id.
  final Map<String, CurriculumStageBuildResult> stageResults;

  /// Total entries stored across all stages.
  int get totalEntriesStored {
    var total = 0;
    for (final result in stageResults.values) {
      total += result.entriesStored;
    }
    return total;
  }

  /// Result for [stageId] or `null` if not built.
  CurriculumStageBuildResult? resultFor(String stageId) =>
      stageResults[stageId];

  /// Builds a [TrainingPhaseDescriptor] for [stage] using [entryCount].
  TrainingPhaseDescriptor phaseDescriptor(
    CurriculumStageDefinition stage, {
    required String exportPath,
    required int entryCount,
  }) {
    return TrainingPhaseDescriptor(
      stageId: stage.id,
      targetLayers: stage.layersWhenActive,
      exportPath: exportPath,
      mixing: stage.mixing,
      entryCount: entryCount,
    );
  }
}

/// Descriptor exported for external shallow-model trainers.
class TrainingPhaseDescriptor {
  /// Creates a phase descriptor.
  const TrainingPhaseDescriptor({
    required this.stageId,
    required this.targetLayers,
    required this.exportPath,
    required this.mixing,
    required this.entryCount,
  });

  /// Curriculum stage id.
  final String stageId;

  /// Suggested model depth for this phase.
  final int targetLayers;

  /// JSONL export path for this phase.
  final String exportPath;

  /// Mixing policy to apply when loading.
  final CurriculumMixingPolicy mixing;

  /// Number of entries available for this phase.
  final int entryCount;
}
