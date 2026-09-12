import '../generator/dataset_generator.dart';
import '../generator/generator_helpers.dart';
import '../model/dataset_entry.dart';
import '../model/dataset_entry_type.dart';
import '../source/dataset_source.dart';
import '../util/ids.dart';
import 'text_build.dart';
import 'text_lexicon.dart';
import 'word_category_bank.dart';

/// Builds canonical **phrase** entries from [PhrasePatternConfig] definitions.
///
/// Each source document id must match a pattern [PhrasePatternConfig.id].
/// The generated [DatasetEntry.input] is the composed phrase; metadata retains
/// template + slots so [MeaningPreservingVariationGenerator] can rebuild
/// meaning-equivalent surface forms.
///
/// When patterns use [PhrasePatternConfig.slotCategories], provide
/// [categoryBank] so slots are filled from category word lists.
class PhraseGenerator implements DatasetGenerator {
  /// Creates a phrase generator.
  PhraseGenerator({
    required this.config,
    required this.patterns,
    required this.lexicon,
    this.categoryBank,
    this.generatorVersion = '1.0.0',
  });

  /// Shared generator configuration ([GeneratorConfig.language] should match
  /// [lexicon.language]).
  final GeneratorConfig config;

  /// Phrase patterns keyed by [PhrasePatternConfig.id].
  final Map<String, PhrasePatternConfig> patterns;

  /// Lexicon used to resolve canonical slot values.
  final TextLexicon lexicon;

  /// Category word bank for [PhrasePatternConfig.slotCategories] patterns.
  final WordCategoryBank? categoryBank;

  /// Provenance version string.
  final String generatorVersion;

  @override
  Stream<DatasetEntry> generate(DatasetSourceDocument document) async* {
    final pattern = patterns[document.id];
    if (pattern == null) {
      throw ArgumentError(
        'Unknown phrase pattern "${document.id}". '
        'Known: ${patterns.keys.join(', ')}',
      );
    }

    if (pattern.usesCategories && categoryBank == null) {
      throw ArgumentError(
        'Pattern "${pattern.id}" uses slot categories but PhraseGenerator '
        'was created without categoryBank',
      );
    }

    final pickIndex = _pickIndex(document.id);
    final semanticKeys = pattern.semanticKeyMap(
      categories: categoryBank,
      pickIndex: pickIndex,
    );
    final slots = pattern.resolveSlots(
      lexicon,
      categories: categoryBank,
      pickIndex: pickIndex,
    );

    final variationGroup = stableDatasetId([
      config.dataset,
      config.datasetVersion,
      document.id,
      'PhraseGenerator',
    ]);
    final canonicalId = stableDatasetId([variationGroup, 0, 0]);

    for (
      var structureIndex = 0;
      structureIndex < pattern.structureCount;
      structureIndex++
    ) {
      final structureTemplate = pattern.allStructureTemplates[structureIndex];
      final text = buildFromTemplate(structureTemplate, slots);

      yield buildCanonicalEntry(
        config: config,
        document: document,
        generatorName: 'PhraseGenerator',
        type: DatasetEntryType.text,
        input: text,
        output: text,
        variationIndex: structureIndex,
        parentEntryId: structureIndex == 0 ? null : canonicalId,
        transformation: structureIndex == 0 ? null : 'structure_preserving',
        extraMetadata: {
          ...phraseExerciseMetadata(
            patternId: pattern.id,
            template: pattern.template,
            slots: slots,
            semanticKeys: semanticKeys,
          ),
          TextExerciseMetadata.structureIndex: structureIndex,
          TextExerciseMetadata.structureTemplate: structureTemplate,
          if (pattern.usesCategories) ...{
            'textSlotCategories': pattern.slotCategories,
            'textPickIndex': pickIndex,
          },
        },
      );
    }
  }

  int _pickIndex(String patternId) {
    final seed = config.seed ?? 0;
    return (patternId.hashCode + seed).abs();
  }
}
