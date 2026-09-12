import '../language_basics/language_basics_catalog.dart';
import '../language_basics/language_basics_generator.dart';
import '../coding_exercise/coding_exercise_catalog.dart';
import '../coding_exercise/coding_exercise_generator.dart';
import '../generator/dataset_generator.dart';
import '../logic_exercise/logic_exercise_catalog.dart';
import '../logic_exercise/logic_exercise_generator.dart';
import '../math_exercise/math_exercise_catalog.dart';
import '../math_exercise/math_exercise_generator.dart';
import '../source/dataset_source.dart';
import '../source/memory_source.dart';
import '../text_exercise/meaning_variation_generator.dart';
import '../text_exercise/paragraph_generator.dart';
import '../text_exercise/phrase_template_store.dart';
import '../text_exercise/phrase_template_store_loader.dart';
import '../text_exercise/text_exercise_catalog.dart';
import '../text_exercise/text_lexicon.dart';
import '../variation/dataset_variation_generator.dart';
import 'curriculum_exception.dart';
import 'curriculum_manifest.dart';
import 'curriculum_variation_options.dart';

/// Resolved source + generator for one curriculum stage source entry.
class CurriculumStageBuildPlan {
  /// Creates a build plan.
  const CurriculumStageBuildPlan({
    required this.source,
    required this.generator,
    required this.dataset,
    required this.datasetVersion,
    this.variations = const [],
  });

  /// Documents to feed the pipeline.
  final DatasetSource source;

  /// Generator with curriculum tagging applied externally.
  final DatasetGenerator generator;

  /// Dataset name for this source slice.
  final String dataset;

  /// Dataset version for this source slice.
  final String datasetVersion;

  /// Variation generators applied to each canonical entry.
  final List<DatasetVariationGenerator> variations;
}

/// Registry that resolves [CurriculumSourceDefinition] into build plans.
class CurriculumStageBuilderRegistry {
  /// Creates a registry with optional overrides for tests.
  CurriculumStageBuilderRegistry({this.phraseTemplateRootResolver});

  /// Resolves phrase template store paths relative to a project root.
  final String Function(String storePath)? phraseTemplateRootResolver;

  /// Resolves [source] into a build plan for [stage].
  Future<CurriculumStageBuildPlan> resolve({
    required CurriculumStageDefinition stage,
    required CurriculumSourceDefinition source,
    required GeneratorConfig baseConfig,
    CurriculumVariationOptions? variationOptions,
  }) async {
    final locale = source.locale ?? 'en';
    final config = GeneratorConfig(
      dataset: stage.dataset,
      datasetVersion: stage.datasetVersion,
      language: locale,
      seed: baseConfig.seed,
    );

    PhraseTemplateStore? phraseStore;
    final plan = switch (source.kind) {
      'language_basics' => _languageBasics(stage, source, config),
      'phrase_templates' => await _phraseTemplates(
        stage,
        source,
        config,
        onStoreLoaded: (store) => phraseStore = store,
      ),
      'paragraph_catalog' => _paragraphCatalog(stage, source, config),
      'math_catalog' => _mathCatalog(stage, source, config),
      'logic_catalog' => _logicCatalog(stage, source, config),
      'coding_catalog' => _codingCatalog(stage, source, config),
      _ => throw CurriculumException(
        'Unknown source kind "${source.kind}"',
        field: 'sources[].kind',
      ),
    };

    final variationsPerEntry = resolveCurriculumVariationsPerEntry(
      builderOptions: variationOptions,
      stageVariationsPerEntry: stage.variationsPerEntry,
      sourceVariationsPerEntry: source.variationsPerEntry,
      combinatorial: source.combinatorial,
    );

    final variations =
        variationOptions?.generators ??
        _resolveVariations(
          source: source,
          variationsPerEntry: variationsPerEntry,
          config: config,
          phraseStore: phraseStore,
        );

    return CurriculumStageBuildPlan(
      source: plan.source,
      generator: plan.generator,
      dataset: plan.dataset,
      datasetVersion: plan.datasetVersion,
      variations: variations,
    );
  }

  List<DatasetVariationGenerator> _resolveVariations({
    required CurriculumSourceDefinition source,
    required int? variationsPerEntry,
    required GeneratorConfig config,
    required PhraseTemplateStore? phraseStore,
  }) {
    if (variationsPerEntry == null || variationsPerEntry <= 0) {
      return const [];
    }

    switch (source.kind) {
      case 'language_basics':
        final catalog = languageBasicsCatalogFor(
          locale: config.language,
          profile: source.profile ?? 'generic',
        );
        return [
          MeaningPreservingVariationGenerator(
            lexicon: catalog.lexicon,
            variationsPerEntry: variationsPerEntry,
            seed: config.seed,
          ),
        ];
      case 'phrase_templates':
        if (phraseStore == null || source.combinatorial) {
          return const [];
        }
        return [
          phraseStore!.createVariationGenerator(
            variationsPerEntry: variationsPerEntry,
            seed: config.seed,
          ),
        ];
      case 'paragraph_catalog':
        final lexicon = config.language == 'pt'
            ? portugueseTextLexicon
            : englishTextLexicon;
        return [
          MeaningPreservingVariationGenerator(
            lexicon: lexicon,
            variationsPerEntry: variationsPerEntry,
            seed: config.seed,
          ),
        ];
      default:
        return const [];
    }
  }

  CurriculumStageBuildPlan _languageBasics(
    CurriculumStageDefinition stage,
    CurriculumSourceDefinition source,
    GeneratorConfig config,
  ) {
    final profile = source.profile ?? 'generic';
    final catalog = languageBasicsCatalogFor(
      locale: config.language,
      profile: profile,
    );
    return CurriculumStageBuildPlan(
      source: MemorySource(catalog.documents()),
      generator: LanguageBasicsGenerator(
        config: config,
        patterns: catalog.patternMap(),
        lexicon: catalog.lexicon,
      ),
      dataset: stage.dataset,
      datasetVersion: stage.datasetVersion,
    );
  }

  Future<CurriculumStageBuildPlan> _phraseTemplates(
    CurriculumStageDefinition stage,
    CurriculumSourceDefinition source,
    GeneratorConfig config, {
    void Function(PhraseTemplateStore store)? onStoreLoaded,
  }) async {
    final storePath = source.storePath;
    if (storePath == null || storePath.isEmpty) {
      throw CurriculumException(
        'phrase_templates source requires storePath',
        field: 'sources[].storePath',
      );
    }

    final resolvedPath =
        phraseTemplateRootResolver?.call(storePath) ?? storePath;
    final store = await PhraseTemplateStoreLoader.fromPath(resolvedPath).load();
    onStoreLoaded?.call(store);

    final documents = store.library.documents();
    final generator = source.combinatorial
        ? store.createCombinatorialGenerator(config: config)
        : store.createPhraseGenerator(config: config);

    return CurriculumStageBuildPlan(
      source: MemorySource(documents),
      generator: generator,
      dataset: stage.dataset,
      datasetVersion: stage.datasetVersion,
    );
  }

  CurriculumStageBuildPlan _paragraphCatalog(
    CurriculumStageDefinition stage,
    CurriculumSourceDefinition source,
    GeneratorConfig config,
  ) {
    final locale = config.language;
    final documents = locale == 'pt'
        ? portugueseParagraphDocuments()
        : englishParagraphDocuments();
    final patterns = locale == 'pt'
        ? portugueseParagraphPatternMap()
        : englishParagraphPatternMap();
    final lexicon = locale == 'pt' ? portugueseTextLexicon : englishTextLexicon;

    return CurriculumStageBuildPlan(
      source: MemorySource(documents),
      generator: ParagraphGenerator(
        config: config,
        patterns: patterns,
        lexicon: lexicon,
      ),
      dataset: stage.dataset,
      datasetVersion: stage.datasetVersion,
    );
  }

  CurriculumStageBuildPlan _mathCatalog(
    CurriculumStageDefinition stage,
    CurriculumSourceDefinition source,
    GeneratorConfig config,
  ) {
    final catalog = mathExerciseCatalogFor(locale: config.language);
    return CurriculumStageBuildPlan(
      source: MemorySource(catalog.documents()),
      generator: MathExerciseGenerator(
        config: config,
        patterns: catalog.patternMap(),
      ),
      dataset: stage.dataset,
      datasetVersion: stage.datasetVersion,
    );
  }

  CurriculumStageBuildPlan _logicCatalog(
    CurriculumStageDefinition stage,
    CurriculumSourceDefinition source,
    GeneratorConfig config,
  ) {
    final catalog = logicExerciseCatalogFor(locale: config.language);
    return CurriculumStageBuildPlan(
      source: MemorySource(catalog.documents()),
      generator: LogicExerciseGenerator(
        config: config,
        patterns: catalog.patternMap(),
        seed: config.seed ?? stage.order,
      ),
      dataset: stage.dataset,
      datasetVersion: stage.datasetVersion,
    );
  }

  CurriculumStageBuildPlan _codingCatalog(
    CurriculumStageDefinition stage,
    CurriculumSourceDefinition source,
    GeneratorConfig config,
  ) {
    final language = source.extra['language'] as String? ?? 'python';
    final catalog = codingExerciseCatalogFor(language: language);
    return CurriculumStageBuildPlan(
      source: MemorySource(catalog.documents()),
      generator: CodingExerciseGenerator(
        config: config,
        patterns: catalog.patternMap(),
      ),
      dataset: stage.dataset,
      datasetVersion: stage.datasetVersion,
    );
  }
}
