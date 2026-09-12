import '../generator/dataset_generator.dart';
import 'meaning_variation_generator.dart';
import 'phrase_combinatorial_generator.dart';
import 'phrase_generator.dart';
import 'phrase_template_library.dart';
import 'phrase_template_locale_manifest.dart';
import 'text_lexicon.dart';
import 'word_category_bank.dart';

/// Loaded phrase-template dataset assembled from JSON files.
class PhraseTemplateStore {
  /// Creates a loaded store snapshot.
  const PhraseTemplateStore({
    required this.rootDirectory,
    required this.manifest,
    required this.lexicon,
    required this.wordBank,
    required this.library,
  });

  /// Locale root directory that was loaded, when loaded from disk.
  final String? rootDirectory;

  /// Locale manifest metadata.
  final PhraseTemplateLocaleManifest manifest;

  /// Merged lexicon from all word-set files.
  final TextLexicon lexicon;

  /// Merged category bank from all word-set files.
  final WordCategoryBank wordBank;

  /// Template library built from all template-group files.
  final PhraseTemplateLibrary library;

  /// Number of word categories loaded.
  int get categoryCount => wordBank.categoryNames.length;

  /// Number of phrase templates loaded.
  int get templateCount => library.templates.length;

  /// Total lemma slots across categories (includes repeats across categories).
  int get lemmaSlotCount => wordBank.lemmaSlotCount;

  /// Unique lemma keys across all categories.
  int get uniqueLemmaCount => wordBank.uniqueLemmaCount;

  /// Total phrase combinations when expanding all templates, words, and synonyms.
  int get combinationCount => PhraseCombinationExpander.countLibrary(
    library: library,
    lexicon: lexicon,
  );

  /// Canonical (lemma-assignment) groups across all templates.
  int get lemmaCombinationCount =>
      PhraseCombinationExpander.countLibraryLemmaCombinations(library: library);

  /// Average structural templates per phrase pattern (including primary).
  double get averageStructureCount => library.templates.isEmpty
      ? 0
      : library.templates
                .map((template) => template.structureCount)
                .fold<int>(0, (sum, count) => sum + count) /
            library.templates.length;

  /// Creates a [PhraseGenerator] configured for this store.
  PhraseGenerator createPhraseGenerator({required GeneratorConfig config}) {
    return PhraseGenerator(
      config: config,
      patterns: library.patternMap(),
      lexicon: lexicon,
      categoryBank: wordBank,
    );
  }

  /// Creates a [MeaningPreservingVariationGenerator] for this store's lexicon.
  MeaningPreservingVariationGenerator createVariationGenerator({
    int variationsPerEntry = 3,
    int? seed,
    String? instanceId,
  }) {
    return MeaningPreservingVariationGenerator(
      lexicon: lexicon,
      variationsPerEntry: variationsPerEntry,
      seed: seed,
      instanceId: instanceId,
    );
  }

  /// Creates a [PhraseCombinatorialGenerator] that emits all word/synonym combos.
  PhraseCombinatorialGenerator createCombinatorialGenerator({
    required GeneratorConfig config,
  }) {
    return PhraseCombinatorialGenerator(
      config: config,
      templates: {for (final t in library.templates) t.id: t},
      lexicon: lexicon,
      categoryBank: wordBank,
    );
  }
}
