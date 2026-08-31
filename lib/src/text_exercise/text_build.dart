import 'text_lexicon.dart';
import 'word_category_bank.dart';

/// Configuration for building one phrase from a template and semantic slots.
class PhrasePatternConfig {
  /// Creates a phrase pattern.
  ///
  /// Provide [semanticSlots] for fixed lemma keys, [slotCategories] for
  /// category-driven filling, or both (explicit slots override categories).
  const PhrasePatternConfig({
    required this.id,
    required this.template,
    Map<String, String>? semanticSlots,
    Map<String, String>? slotCategories,
    this.adverbKey,
    this.structureVariants = const [],
  }) : semanticSlots = semanticSlots ?? const {},
       slotCategories = slotCategories ?? const {};

  /// Stable pattern id (used in source document ids).
  final String id;

  /// Template with `{slot}` placeholders, e.g. `{subject} {verb} {object}.`
  final String template;

  /// Slot name → lexicon lemma key (fixed words).
  final Map<String, String> semanticSlots;

  /// Slot name → [WordCategoryBank] category (filled at generation time).
  final Map<String, String> slotCategories;

  /// Optional adverb lemma inserted as `{adverb}` when set.
  final String? adverbKey;

  /// Alternate templates with the same slots and meaning.
  final List<String> structureVariants;

  /// Primary template followed by [structureVariants].
  List<String> get allStructureTemplates => [template, ...structureVariants];

  /// Number of structural templates including the primary [template].
  int get structureCount => allStructureTemplates.length;

  /// Whether this pattern uses category-driven slots.
  bool get usesCategories => slotCategories.isNotEmpty;

  /// Builds surface slot values from [lexicon] (canonical forms).
  ///
  /// When [categories] is provided, each [slotCategories] entry picks a lemma
  /// with [pickIndex] (typically derived from pattern id + generator seed).
  Map<String, String> resolveSlots(
    TextLexicon lexicon, {
    WordCategoryBank? categories,
    int pickIndex = 0,
  }) {
    final slots = <String, String>{};
    final semanticKeys = resolveSemanticKeys(
      categories: categories,
      pickIndex: pickIndex,
    );

    for (final entry in semanticKeys.entries) {
      slots[entry.key] = lexicon.canonical(entry.value);
    }

    if (adverbKey != null && !slots.containsKey('adverb')) {
      slots['adverb'] = lexicon.canonical(adverbKey!);
    }
    return slots;
  }

  /// Lemma key per slot (explicit or category-picked).
  Map<String, String> resolveSemanticKeys({
    WordCategoryBank? categories,
    int pickIndex = 0,
  }) {
    final keys = Map<String, String>.from(semanticSlots);

    for (final entry in slotCategories.entries) {
      if (keys.containsKey(entry.key)) {
        continue;
      }
      if (categories == null) {
        throw ArgumentError(
          'Pattern "$id" slot "${entry.key}" uses category "${entry.value}" '
          'but no WordCategoryBank was provided',
        );
      }
      keys[entry.key] = categories.pick(
        entry.value,
        pickIndex + entry.key.hashCode,
      );
    }

    if (adverbKey != null) {
      keys.putIfAbsent('adverb', () => adverbKey!);
    }
    return keys;
  }

  /// Semantic keys including optional adverb.
  Map<String, String> semanticKeyMap({
    WordCategoryBank? categories,
    int pickIndex = 0,
  }) {
    return resolveSemanticKeys(categories: categories, pickIndex: pickIndex);
  }
}

/// One sentence inside a paragraph pattern.
class SentencePatternConfig {
  /// Creates a sentence pattern.
  const SentencePatternConfig({
    required this.template,
    required this.semanticSlots,
    this.adverbKey,
  });

  /// Sentence template with `{slot}` placeholders.
  final String template;

  /// Slot name → lexicon lemma key.
  final Map<String, String> semanticSlots;

  /// Optional adverb lemma for `{adverb}`.
  final String? adverbKey;

  /// Builds surface slot values from [lexicon].
  Map<String, String> resolveSlots(TextLexicon lexicon) {
    final slots = <String, String>{};
    for (final entry in semanticSlots.entries) {
      slots[entry.key] = lexicon.canonical(entry.value);
    }
    if (adverbKey != null) {
      slots['adverb'] = lexicon.canonical(adverbKey!);
    }
    return slots;
  }

  Map<String, String> semanticKeyMap() {
    final keys = Map<String, String>.from(semanticSlots);
    if (adverbKey != null) {
      keys['adverb'] = adverbKey!;
    }
    return keys;
  }
}

/// Configuration for a multi-sentence paragraph.
class ParagraphPatternConfig {
  /// Creates a paragraph pattern.
  const ParagraphPatternConfig({
    required this.id,
    required this.sentences,
    this.joiner = ' ',
  });

  /// Stable pattern id.
  final String id;

  /// Ordered sentence patterns.
  final List<SentencePatternConfig> sentences;

  /// String inserted between sentences.
  final String joiner;
}

/// Fills `{slot}` placeholders in [template] with [slots].
String buildFromTemplate(String template, Map<String, String> slots) {
  var text = template;
  for (final entry in slots.entries) {
    text = text.replaceAll('{${entry.key}}', entry.value);
  }
  return text.trim();
}

/// Metadata keys stored on generated text entries for variation rebuild.
abstract final class TextExerciseMetadata {
  static const textKind = 'textKind';
  static const template = 'textTemplate';
  static const slots = 'textSlots';
  static const semanticKeys = 'textSemanticKeys';
  static const paragraphSentences = 'textParagraphSentences';
  static const paragraphJoiner = 'textParagraphJoiner';
  static const patternId = 'textPatternId';
  static const structureIndex = 'textStructureIndex';
  static const structureTemplate = 'textStructureTemplate';
}

Map<String, dynamic> phraseExerciseMetadata({
  required String patternId,
  required String template,
  required Map<String, String> slots,
  required Map<String, String> semanticKeys,
}) {
  return {
    TextExerciseMetadata.textKind: 'phrase',
    TextExerciseMetadata.patternId: patternId,
    TextExerciseMetadata.template: template,
    TextExerciseMetadata.slots: slots,
    TextExerciseMetadata.semanticKeys: semanticKeys,
  };
}

Map<String, dynamic> paragraphExerciseMetadata({
  required String patternId,
  required List<Map<String, dynamic>> sentenceSpecs,
  required String joiner,
}) {
  return {
    TextExerciseMetadata.textKind: 'paragraph',
    TextExerciseMetadata.patternId: patternId,
    TextExerciseMetadata.paragraphSentences: sentenceSpecs,
    TextExerciseMetadata.paragraphJoiner: joiner,
  };
}

/// Rebuilds phrase/paragraph text from exercise metadata and slot overrides.
///
/// For paragraphs, [slotOverrides] keys are `"{sentenceIndex}.{slotName}"`.
String rebuildExerciseText(
  Map<String, dynamic> metadata, {
  Map<String, String>? slotOverrides,
}) {
  final kind = metadata[TextExerciseMetadata.textKind];
  if (kind == 'paragraph') {
    final rawSentences = metadata[TextExerciseMetadata.paragraphSentences];
    final joiner =
        metadata[TextExerciseMetadata.paragraphJoiner] as String? ?? ' ';
    if (rawSentences is! List) {
      throw FormatException('Missing paragraph sentence specs');
    }
    final parts = <String>[];
    for (var i = 0; i < rawSentences.length; i++) {
      final raw = rawSentences[i];
      if (raw is! Map) {
        continue;
      }
      final spec = Map<String, dynamic>.from(raw);
      final template = spec['template'] as String;
      final baseSlots = Map<String, String>.from(
        (spec['slots'] as Map).cast<String, String>(),
      );
      final slots = Map<String, String>.from(baseSlots);
      if (slotOverrides != null) {
        for (final entry in baseSlots.entries) {
          final key = '$i.${entry.key}';
          if (slotOverrides.containsKey(key)) {
            slots[entry.key] = slotOverrides[key]!;
          }
        }
      }
      parts.add(buildFromTemplate(template, slots));
    }
    return parts.join(joiner).trim();
  }

  final template = metadata[TextExerciseMetadata.template] as String?;
  if (template == null) {
    throw FormatException('Missing text template metadata');
  }
  final baseSlots = Map<String, String>.from(
    (metadata[TextExerciseMetadata.slots] as Map).cast<String, String>(),
  );
  final slots = slotOverrides == null
      ? baseSlots
      : {...baseSlots, ...slotOverrides};
  return buildFromTemplate(template, slots);
}

/// Flattens paragraph sentence specs into prefixed slot / semantic-key maps.
({Map<String, String> slots, Map<String, String> semanticKeys})
flattenParagraphSpecs(List<Map<String, dynamic>> sentenceSpecs) {
  final slots = <String, String>{};
  final semanticKeys = <String, String>{};
  for (var i = 0; i < sentenceSpecs.length; i++) {
    final spec = sentenceSpecs[i];
    final sentenceSlots = Map<String, String>.from(
      (spec['slots'] as Map).cast<String, String>(),
    );
    final sentenceSemantic = Map<String, String>.from(
      (spec['semanticKeys'] as Map).cast<String, String>(),
    );
    for (final entry in sentenceSlots.entries) {
      final key = '$i.${entry.key}';
      slots[key] = entry.value;
      semanticKeys[key] = sentenceSemantic[entry.key] ?? entry.key;
    }
  }
  return (slots: slots, semanticKeys: semanticKeys);
}

/// Sentence specs with resolved slots for storage in entry metadata.
List<Map<String, dynamic>> buildParagraphSentenceSpecs(
  ParagraphPatternConfig pattern,
  TextLexicon lexicon,
) {
  return [
    for (final sentence in pattern.sentences)
      {
        'template': sentence.template,
        'slots': sentence.resolveSlots(lexicon),
        'semanticKeys': sentence.semanticKeyMap(),
      },
  ];
}
