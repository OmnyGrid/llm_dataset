import '../source/dataset_source.dart';
import '../text_exercise/text_build.dart';
import '../text_exercise/text_lexicon.dart';

/// Catalog of simple language-basics patterns for initial curriculum stages.
class LanguageBasicsCatalog {
  /// Creates a catalog.
  const LanguageBasicsCatalog({
    required this.profile,
    required this.patterns,
    required this.lexicon,
  });

  /// Profile name (`generic`, …).
  final String profile;

  /// Pattern definitions.
  final List<PhrasePatternConfig> patterns;

  /// Lexicon for slot resolution.
  final TextLexicon lexicon;

  /// Source documents for pipeline consumption.
  List<DatasetSourceDocument> documents() {
    return [
      for (final pattern in patterns)
        DatasetSourceDocument(
          id: pattern.id,
          content: pattern.template,
          title: pattern.id,
          language: lexicon.language,
          metadata: {
            'textKind': 'language_basics',
            'patternId': pattern.id,
            'complexityTier': 0,
          },
        ),
    ];
  }

  /// Patterns keyed by id.
  Map<String, PhrasePatternConfig> patternMap() {
    return {for (final pattern in patterns) pattern.id: pattern};
  }
}

const _genericEnglishPatterns = [
  PhrasePatternConfig(
    id: 'lb-en-the-noun',
    template: 'The {noun}.',
    semanticSlots: {'noun': 'cat'},
  ),
  PhrasePatternConfig(
    id: 'lb-en-subject-verb',
    template: '{subject} {verb}.',
    semanticSlots: {'subject': 'dog', 'verb': 'run'},
  ),
  PhrasePatternConfig(
    id: 'lb-en-article-noun-verb',
    template: 'The {noun} {verb}.',
    semanticSlots: {'noun': 'bird', 'verb': 'fly'},
  ),
  PhrasePatternConfig(
    id: 'lb-en-subject-verb-object',
    template: '{subject} {verb} the {object}.',
    semanticSlots: {'subject': 'child', 'verb': 'read', 'object': 'book'},
  ),
];

const _genericEnglishLexicon = TextLexicon(
  language: 'en',
  synonyms: {
    'cat': ['cat', 'kitten'],
    'dog': ['dog', 'puppy'],
    'bird': ['bird', 'sparrow'],
    'child': ['child', 'kid'],
    'book': ['book', 'story'],
    'run': ['runs', 'jogs'],
    'fly': ['flies', 'soars'],
    'read': ['reads', 'studies'],
  },
);

/// Returns the language-basics catalog for [locale] and [profile].
LanguageBasicsCatalog languageBasicsCatalogFor({
  required String locale,
  required String profile,
}) {
  if (locale != 'en') {
    throw ArgumentError('language_basics currently supports locale "en" only');
  }
  if (profile != 'generic') {
    throw ArgumentError('Unknown language_basics profile "$profile"');
  }
  return const LanguageBasicsCatalog(
    profile: 'generic',
    patterns: _genericEnglishPatterns,
    lexicon: _genericEnglishLexicon,
  );
}
