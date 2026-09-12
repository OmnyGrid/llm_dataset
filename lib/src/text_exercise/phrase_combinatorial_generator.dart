import '../generator/dataset_generator.dart';
import '../model/dataset_entry.dart';
import '../model/dataset_entry_type.dart';
import '../model/dataset_provenance.dart';
import '../source/dataset_source.dart';
import '../util/ids.dart';
import 'phrase_template_library.dart';
import 'text_build.dart';
import 'text_lexicon.dart';
import 'word_category_bank.dart';

/// One fully resolved phrase from a template, lemma assignment, and surface forms.
class PhraseCombination {
  /// Creates a phrase combination.
  const PhraseCombination({
    required this.templateId,
    required this.semanticKeys,
    required this.slots,
    required this.text,
    required this.lemmaCombinationIndex,
    required this.surfaceIndex,
    required this.structureIndex,
    required this.structureTemplate,
  });

  /// Source template id.
  final String templateId;

  /// Slot name → lexicon lemma key.
  final Map<String, String> semanticKeys;

  /// Slot name → resolved surface form.
  final Map<String, String> slots;

  /// Composed phrase text.
  final String text;

  /// Index of the lemma assignment within the template (stable iteration order).
  final int lemmaCombinationIndex;

  /// Index of the surface form within the lemma assignment (0 = canonical).
  final int surfaceIndex;

  /// Index of the structural template (0 = primary [PhraseTemplate.template]).
  final int structureIndex;

  /// Structural template string used to compose [text].
  final String structureTemplate;
}

/// Expands phrase templates across all category word and synonym combinations.
abstract final class PhraseCombinationExpander {
  /// Expands [template] across every lemma pick and synonym surface per slot.
  static Iterable<PhraseCombination> expandTemplate({
    required PhraseTemplate template,
    required TextLexicon lexicon,
    required WordCategoryBank wordBank,
  }) sync* {
    final slotNames = _orderedSlotNames(template);
    final lemmaLists = [
      for (final slot in slotNames)
        wordBank.words(template.slotCategories[slot]!),
    ];

    var lemmaCombinationIndex = 0;
    final structures = template.allStructureTemplates;
    for (final lemmaValues in _cartesianProduct(lemmaLists)) {
      final semanticKeys = {
        for (var i = 0; i < slotNames.length; i++) slotNames[i]: lemmaValues[i],
      };

      final surfaceLists = [
        for (final slot in slotNames) lexicon.forms(semanticKeys[slot]!),
      ];

      var surfaceIndex = 0;
      for (final surfaceValues in _orderedSurfaceCombinations(surfaceLists)) {
        final slots = {
          for (var i = 0; i < slotNames.length; i++)
            slotNames[i]: surfaceValues[i],
        };

        for (
          var structureIndex = 0;
          structureIndex < structures.length;
          structureIndex++
        ) {
          final structureTemplate = structures[structureIndex];
          yield PhraseCombination(
            templateId: template.id,
            semanticKeys: semanticKeys,
            slots: slots,
            text: buildFromTemplate(structureTemplate, slots),
            lemmaCombinationIndex: lemmaCombinationIndex,
            surfaceIndex: surfaceIndex,
            structureIndex: structureIndex,
            structureTemplate: structureTemplate,
          );
        }
        surfaceIndex++;
      }
      lemmaCombinationIndex++;
    }
  }

  /// Counts expanded combinations for [template] without materializing text.
  static int countTemplate({
    required PhraseTemplate template,
    required TextLexicon lexicon,
    required WordCategoryBank wordBank,
  }) {
    final slotNames = _orderedSlotNames(template);
    final lemmaLists = [
      for (final slot in slotNames)
        wordBank.words(template.slotCategories[slot]!),
    ];

    var total = 0;
    final structureCount = template.structureCount;
    for (final lemmaValues in _cartesianProduct(lemmaLists)) {
      var surfaceProduct = 1;
      for (var i = 0; i < slotNames.length; i++) {
        surfaceProduct *= lexicon.forms(lemmaValues[i]).length;
      }
      total += surfaceProduct * structureCount;
    }
    return total;
  }

  /// Counts lemma assignments (canonical entries) for [template].
  static int countLemmaCombinations({
    required PhraseTemplate template,
    required WordCategoryBank wordBank,
  }) {
    final slotNames = _orderedSlotNames(template);
    var product = 1;
    for (final slot in slotNames) {
      product *= wordBank.words(template.slotCategories[slot]!).length;
    }
    return product;
  }

  /// Counts lemma assignments across all templates in [library].
  static int countLibraryLemmaCombinations({
    required PhraseTemplateLibrary library,
  }) {
    return library.templates.fold<int>(
      0,
      (sum, template) =>
          sum +
          countLemmaCombinations(
            template: template,
            wordBank: library.wordBank,
          ),
    );
  }

  /// Counts expanded combinations across all templates in [library].
  static int countLibrary({
    required PhraseTemplateLibrary library,
    required TextLexicon lexicon,
  }) {
    return library.templates.fold<int>(
      0,
      (sum, template) =>
          sum +
          countTemplate(
            template: template,
            lexicon: lexicon,
            wordBank: library.wordBank,
          ),
    );
  }

  static List<String> _orderedSlotNames(PhraseTemplate template) {
    final pattern = RegExp(r'\{([a-zA-Z_][a-zA-Z0-9_]*)\}');
    final seen = <String>{};
    final ordered = <String>[];

    for (final structure in template.allStructureTemplates) {
      for (final match in pattern.allMatches(structure)) {
        final name = match.group(1)!;
        if (template.slotCategories.containsKey(name) && seen.add(name)) {
          ordered.add(name);
        }
      }
    }

    for (final name in template.slotCategories.keys) {
      if (seen.add(name)) {
        ordered.add(name);
      }
    }

    return ordered;
  }

  /// Canonical surface first, then single-slot synonym swaps, then the rest.
  static Iterable<List<String>> _orderedSurfaceCombinations(
    List<List<String>> surfaceLists,
  ) sync* {
    if (surfaceLists.isEmpty) {
      yield const [];
      return;
    }
    if (surfaceLists.any((list) => list.isEmpty)) {
      return;
    }

    final canonical = [for (final forms in surfaceLists) forms.first];
    final seen = <String>{_surfaceKey(canonical)};

    yield canonical;

    for (var slot = 0; slot < surfaceLists.length; slot++) {
      for (var alt = 1; alt < surfaceLists[slot].length; alt++) {
        final combo = List<String>.from(canonical);
        combo[slot] = surfaceLists[slot][alt];
        final key = _surfaceKey(combo);
        if (seen.add(key)) {
          yield combo;
        }
      }
    }

    for (final combo in _cartesianProduct(surfaceLists)) {
      final key = _surfaceKey(combo);
      if (seen.add(key)) {
        yield combo;
      }
    }
  }

  static String _surfaceKey(List<String> surfaces) => surfaces.join('\u{1f}');

  static Iterable<List<T>> _cartesianProduct<T>(List<List<T>> lists) sync* {
    if (lists.isEmpty) {
      yield const [];
      return;
    }
    if (lists.any((list) => list.isEmpty)) {
      return;
    }

    yield* _cartesianRecursive(lists, 0, <T>[]);
  }

  static Iterable<List<T>> _cartesianRecursive<T>(
    List<List<T>> lists,
    int depth,
    List<T> prefix,
  ) sync* {
    if (depth == lists.length) {
      yield List<T>.from(prefix);
      return;
    }

    for (final value in lists[depth]) {
      prefix.add(value);
      yield* _cartesianRecursive(lists, depth + 1, prefix);
      prefix.removeLast();
    }
  }
}

/// Generates every phrase combination for each template document.
///
/// Unlike [PhraseGenerator], which picks one word per category, this generator
/// emits the full cross-product of category lemmas and lexicon synonym surfaces
/// for each template.
class PhraseCombinatorialGenerator implements DatasetGenerator {
  /// Creates a combinatorial phrase generator.
  PhraseCombinatorialGenerator({
    required this.config,
    required this.lexicon,
    required this.categoryBank,
    Map<String, PhraseTemplate>? templates,
    Map<String, PhrasePatternConfig>? patterns,
    this.generatorVersion = '1.0.0',
  }) : templates = templates ?? const {},
       patterns = patterns ?? const {} {
    if (this.templates.isEmpty && this.patterns.isEmpty) {
      throw ArgumentError(
        'PhraseCombinatorialGenerator requires templates or patterns',
      );
    }
  }

  /// Shared generator configuration.
  final GeneratorConfig config;

  /// Phrase templates keyed by template id (preferred; includes structure variants).
  final Map<String, PhraseTemplate> templates;

  /// Phrase patterns keyed by template id (fallback when templates omitted).
  final Map<String, PhrasePatternConfig> patterns;

  /// Lexicon for surface forms.
  final TextLexicon lexicon;

  /// Category word bank.
  final WordCategoryBank categoryBank;

  /// Provenance version string.
  final String generatorVersion;

  @override
  Stream<DatasetEntry> generate(DatasetSourceDocument document) async* {
    final template = _resolveTemplate(document.id);
    final pattern = template.toPatternConfig();

    for (final combination in PhraseCombinationExpander.expandTemplate(
      template: template,
      lexicon: lexicon,
      wordBank: categoryBank,
    )) {
      yield _buildEntry(
        config: config,
        document: document,
        pattern: pattern,
        combination: combination,
        structureCount: template.structureCount,
      );
    }
  }

  PhraseTemplate _resolveTemplate(String templateId) {
    final template = templates[templateId];
    if (template != null) {
      return template;
    }

    final pattern = patterns[templateId];
    if (pattern == null) {
      throw ArgumentError(
        'Unknown phrase template "$templateId". '
        'Known: ${_knownTemplateIds().join(', ')}',
      );
    }

    return PhraseTemplate(
      id: pattern.id,
      template: pattern.template,
      slotCategories: pattern.slotCategories,
      structureVariants: pattern.structureVariants,
    );
  }

  Iterable<String> _knownTemplateIds() sync* {
    yield* templates.keys;
    yield* patterns.keys;
  }

  static DatasetEntry _buildEntry({
    required GeneratorConfig config,
    required DatasetSourceDocument document,
    required PhrasePatternConfig pattern,
    required PhraseCombination combination,
    required int structureCount,
  }) {
    final variationGroup = stableDatasetId([
      config.dataset,
      config.datasetVersion,
      pattern.id,
      combination.lemmaCombinationIndex,
    ]);
    final variationIndex = _combinedVariationIndex(
      surfaceIndex: combination.surfaceIndex,
      structureIndex: combination.structureIndex,
      structureCount: structureCount,
    );
    final id = stableDatasetId([variationGroup, variationIndex]);

    final canonicalId = stableDatasetId([variationGroup, 0]);

    final createdAt = config.seed == null
        ? DateTime.now().toUtc()
        : _deterministicCreatedAt(
            config.seed!,
            pattern.id,
            combination.lemmaCombinationIndex,
            variationIndex,
          );

    final parentId = variationIndex == 0 ? null : canonicalId;

    return DatasetEntry(
      id: id,
      dataset: config.dataset,
      datasetVersion: config.datasetVersion,
      type: DatasetEntryType.text,
      language: document.language ?? config.language,
      input: combination.text,
      output: combination.text,
      variationGroup: variationGroup,
      variationIndex: variationIndex,
      metadata: {
        TextExerciseMetadata.patternId: pattern.id,
        TextExerciseMetadata.template: pattern.template,
        TextExerciseMetadata.slots: combination.slots,
        TextExerciseMetadata.semanticKeys: combination.semanticKeys,
        TextExerciseMetadata.structureIndex: combination.structureIndex,
        TextExerciseMetadata.structureTemplate: combination.structureTemplate,
        'textLemmaCombinationIndex': combination.lemmaCombinationIndex,
        'textSurfaceIndex': combination.surfaceIndex,
        'generationMode': 'combinatorial',
      },
      provenance: DatasetProvenance(
        source: 'document',
        sourceId: document.id,
        sourceUri: document.metadata['path'] as String?,
        generator: 'PhraseCombinatorialGenerator',
        generatorVersion: config.generatorVersion,
        pipelineVersion: config.pipelineVersion,
        parentEntryId: parentId,
        transformation: variationIndex == 0
            ? null
            : combination.structureIndex == 0
            ? 'meaning_preserving'
            : 'structure_preserving',
      ),
      createdAt: createdAt,
    );
  }

  static int _combinedVariationIndex({
    required int surfaceIndex,
    required int structureIndex,
    required int structureCount,
  }) {
    return surfaceIndex * structureCount + structureIndex;
  }

  static DateTime _deterministicCreatedAt(
    int seed,
    String patternId,
    int lemmaIndex,
    int surfaceIndex,
  ) {
    final offset = int.parse(
      stableDatasetId([seed, patternId, lemmaIndex, surfaceIndex])
          .substring(0, 8),
      radix: 16,
    );
    return DateTime.fromMillisecondsSinceEpoch(
      seed + (offset % 86400000),
      isUtc: true,
    );
  }
}

/// Counts expanded combinations for a loaded phrase template store.
int phraseTemplateStoreCombinationCount({
  required PhraseTemplateLibrary library,
  required TextLexicon lexicon,
}) {
  return PhraseCombinationExpander.countLibrary(
    library: library,
    lexicon: lexicon,
  );
}
