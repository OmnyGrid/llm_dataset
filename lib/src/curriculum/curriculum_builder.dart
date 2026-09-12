import '../generator/dataset_generator.dart';
import '../pipeline/dataset_pipeline.dart';
import '../store/dataset_store.dart';
import 'curriculum_build_result.dart';
import 'curriculum_manifest.dart';
import 'curriculum_stage_builder_registry.dart';
import 'curriculum_variation_options.dart';
import 'curriculum_tagging_generator.dart';

/// Builds curriculum stages into a shared [DatasetStore].
class CurriculumBuilder {
  /// Creates a builder for [manifest] writing to [store].
  CurriculumBuilder({
    required this.manifest,
    required this.store,
    this.registry,
    this.seed,
    this.variationOptions,
    this.failIfVersionExists = false,
    this.configureBulkInsert = true,
  });

  /// Curriculum manifest.
  final CurriculumManifest manifest;

  /// Target store for all stage entries.
  final DatasetStore store;

  /// Stage builder registry (defaults to built-in kinds).
  final CurriculumStageBuilderRegistry? registry;

  /// Optional generator seed.
  final int? seed;

  /// When set, enables meaning-preserving variations for text exercise sources.
  final CurriculumVariationOptions? variationOptions;

  /// When true, refuse to overwrite existing dataset versions.
  final bool failIfVersionExists;

  /// When true, call [SqliteDatasetStore.configureForBulkInsert] before large
  /// stages (no-op for other store types).
  final bool configureBulkInsert;

  CurriculumStageBuilderRegistry get _registry =>
      registry ?? CurriculumStageBuilderRegistry();

  /// Builds a single stage by [stageId].
  Future<CurriculumBuildResult> buildStage(String stageId) async {
    final stage = manifest.stage(stageId);
    final result = await _buildStage(stage);
    return CurriculumBuildResult(
      curriculumId: manifest.id,
      stageResults: {stageId: result},
    );
  }

  /// Builds every stage in manifest order.
  Future<CurriculumBuildResult> buildAll() async {
    final results = <String, CurriculumStageBuildResult>{};
    for (final stage in manifest.stages) {
      results[stage.id] = await _buildStage(stage);
    }
    return CurriculumBuildResult(
      curriculumId: manifest.id,
      stageResults: results,
    );
  }

  Future<CurriculumStageBuildResult> _buildStage(
    CurriculumStageDefinition stage,
  ) async {
    if (configureBulkInsert) {
      _maybeConfigureBulkInsert();
    }

    final baseConfig = GeneratorConfig(
      dataset: stage.dataset,
      datasetVersion: stage.datasetVersion,
      language: stage.sources.first.locale ?? 'en',
      seed: seed,
    );

    var documentsSeen = 0;
    var entriesGenerated = 0;
    var entriesStored = 0;
    var entriesRejected = 0;

    for (final source in stage.sources) {
      final plan = await _registry.resolve(
        stage: stage,
        source: source,
        baseConfig: baseConfig,
        variationOptions: variationOptions,
      );

      final taggedGenerator = CurriculumTaggingGenerator(
        inner: plan.generator,
        curriculumId: manifest.id,
        stageId: stage.id,
        stageOrder: stage.order,
      );

      final pipeline = DatasetPipeline(
        source: plan.source,
        generator: taggedGenerator,
        variations: plan.variations,
        store: store,
        dataset: plan.dataset,
        datasetVersion: plan.datasetVersion,
        failIfVersionExists: failIfVersionExists,
      );

      final result = await pipeline.run();
      documentsSeen += result.documentsSeen;
      entriesGenerated += result.entriesGenerated;
      entriesStored += result.entriesStored;
      entriesRejected += result.entriesRejected;
    }

    return CurriculumStageBuildResult(
      stageId: stage.id,
      documentsSeen: documentsSeen,
      entriesGenerated: entriesGenerated,
      entriesStored: entriesStored,
      entriesRejected: entriesRejected,
    );
  }

  void _maybeConfigureBulkInsert() {
    final dynamic maybeSqlite = store;
    try {
      maybeSqlite.configureForBulkInsert();
    } on NoSuchMethodError {
      // Not a SqliteDatasetStore.
    }
  }
}
