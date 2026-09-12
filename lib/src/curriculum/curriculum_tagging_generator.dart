import '../generator/dataset_generator.dart';
import '../model/dataset_entry.dart';
import '../source/dataset_source.dart';
import 'curriculum_metadata.dart';

/// Wraps a [DatasetGenerator] and stamps curriculum metadata on each entry.
class CurriculumTaggingGenerator implements DatasetGenerator {
  /// Creates a tagging wrapper.
  CurriculumTaggingGenerator({
    required this.inner,
    required this.curriculumId,
    required this.stageId,
    required this.stageOrder,
    this.defaultComplexityTier = 0,
  });

  /// Underlying generator.
  final DatasetGenerator inner;

  /// Manifest id.
  final String curriculumId;

  /// Stage id.
  final String stageId;

  /// Stage order.
  final int stageOrder;

  /// Default complexity tier when entry metadata lacks one.
  final int defaultComplexityTier;

  @override
  Stream<DatasetEntry> generate(DatasetSourceDocument document) async* {
    await for (final entry in inner.generate(document)) {
      final tier =
          entry.metadata[ExerciseMetadataKeys.complexityTier] as int? ??
          defaultComplexityTier;
      yield entry.copyWith(
        metadata: {
          ...entry.metadata,
          ...curriculumExerciseMetadata(
            curriculumId: curriculumId,
            stageId: stageId,
            stageOrder: stageOrder,
            complexityTier: tier,
          ),
        },
      );
    }
  }
}
