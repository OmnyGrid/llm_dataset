/// Unified metadata keys used across exercise generators and curriculum tagging.
///
/// See [TextExerciseMetadata] for phrase/paragraph-specific keys.
abstract final class ExerciseMetadataKeys {
  /// Discriminator for drill modules (`arithmetic`, `sequence`, `python_var`, …).
  static const exerciseKind = 'exerciseKind';

  /// Pattern id within a catalog (`lb-en-the-noun`, `add-2-3`, …).
  static const patternId = 'patternId';

  /// Within-pattern difficulty tier (0 = simplest).
  static const complexityTier = 'complexityTier';
}

/// Curriculum-specific metadata keys stamped during progressive training builds.
abstract final class CurriculumMetadataKeys {
  /// Manifest id stamped on every curriculum entry.
  static const curriculumId = 'curriculumId';

  /// Stage id (`language_basics`, `phrases`, …).
  static const curriculumStage = 'curriculumStage';

  /// Stage order within the manifest.
  static const curriculumStageOrder = 'curriculumStageOrder';
}

/// Builds curriculum metadata to merge into [DatasetEntry.metadata].
Map<String, dynamic> curriculumExerciseMetadata({
  required String curriculumId,
  required String stageId,
  required int stageOrder,
  int complexityTier = 0,
}) {
  return {
    CurriculumMetadataKeys.curriculumId: curriculumId,
    CurriculumMetadataKeys.curriculumStage: stageId,
    CurriculumMetadataKeys.curriculumStageOrder: stageOrder,
    ExerciseMetadataKeys.complexityTier: complexityTier,
  };
}
