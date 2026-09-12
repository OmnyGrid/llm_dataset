/// Well-known metadata keys for curriculum-tagged entries.
abstract final class CurriculumMetadataKeys {
  /// Manifest id stamped on every curriculum entry.
  static const curriculumId = 'curriculumId';

  /// Stage id (`language_basics`, `phrases`, …).
  static const curriculumStage = 'curriculumStage';

  /// Stage order within the manifest.
  static const curriculumStageOrder = 'curriculumStageOrder';

  /// Within-stage difficulty tier (0 = simplest).
  static const complexityTier = 'complexityTier';
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
    CurriculumMetadataKeys.complexityTier: complexityTier,
  };
}
