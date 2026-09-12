import '../exercise/catalog_exercise_generator.dart';
import '../generator/dataset_generator.dart';
import '../model/exercise_metadata.dart';
import '../generator/generator_helpers.dart';
import '../model/dataset_entry.dart';
import '../model/dataset_entry_type.dart';
import '../source/dataset_source.dart';
import '../text_exercise/text_build.dart';
import '../text_exercise/text_lexicon.dart';

/// Builds simplest phrase entries for early curriculum stages.
class LanguageBasicsGenerator
    with CatalogExerciseGenerator<PhrasePatternConfig>
    implements DatasetGenerator {
  /// Creates a language-basics generator.
  LanguageBasicsGenerator({
    required this.config,
    required this.patterns,
    required this.lexicon,
    this.generatorVersion = '1.0.0',
  });

  /// Shared generator configuration.
  final GeneratorConfig config;

  /// Patterns keyed by id.
  final Map<String, PhrasePatternConfig> patterns;

  /// Lexicon for canonical slot resolution.
  final TextLexicon lexicon;

  /// Provenance version string.
  final String generatorVersion;

  @override
  Map<String, PhrasePatternConfig> get patternMap => patterns;

  @override
  Stream<DatasetEntry> generate(DatasetSourceDocument document) async* {
    final pattern = requirePattern(document);

    final slots = pattern.resolveSlots(lexicon);
    final semanticKeys = pattern.resolveSemanticKeys();
    final text = buildFromTemplate(pattern.template, slots);

    yield buildCanonicalEntry(
      config: config,
      document: document,
      generatorName: 'LanguageBasicsGenerator',
      type: DatasetEntryType.text,
      input: text,
      output: text,
      extraMetadata: {
        ...phraseExerciseMetadata(
          patternId: pattern.id,
          template: pattern.template,
          slots: slots,
          semanticKeys: semanticKeys,
        ),
        TextExerciseMetadata.textKind: TextExerciseMetadata.languageBasics,
        ExerciseMetadataKeys.complexityTier: 0,
      },
    );
  }
}
