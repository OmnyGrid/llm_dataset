// Facade over hardcoded phrase template library patterns and paragraph configs.
// For JSON-backed corpora use PhraseTemplateStore. See doc/ARCHITECTURE.md.
import '../source/dataset_source.dart';
import '../source/memory_source.dart';
import 'phrase_template_library.dart';
import 'text_build.dart';

/// English phrase patterns (category-driven templates).
List<PhrasePatternConfig> get englishPhrasePatterns =>
    englishPhraseTemplateLibrary.templates
        .map((template) => template.toPatternConfig())
        .toList(growable: false);

/// English phrase template library with word categories.
const englishPhraseLibrary = englishPhraseTemplateLibrary;

/// English paragraph patterns for text exercises.
const englishParagraphPatterns = [
  ParagraphPatternConfig(
    id: 'en-paragraph-morning',
    joiner: ' ',
    sentences: [
      SentencePatternConfig(
        template: 'Every {morning}, the {subject} drinks {coffee}.',
        semanticSlots: {
          'morning': 'morning',
          'subject': 'developer',
          'coffee': 'coffee',
        },
      ),
      SentencePatternConfig(
        template: 'Then the {subject} {adverb} {verb} {english} {paragraph}.',
        semanticSlots: {
          'subject': 'developer',
          'verb': 'read',
          'english': 'english',
          'paragraph': 'paragraph',
        },
        adverbKey: 'carefully',
      ),
      SentencePatternConfig(
        template: 'This {exercise} improves {english} {work}.',
        semanticSlots: {
          'exercise': 'exercise',
          'english': 'english',
          'work': 'work',
        },
      ),
    ],
  ),
  ParagraphPatternConfig(
    id: 'en-paragraph-dev',
    joiner: ' ',
    sentences: [
      SentencePatternConfig(
        template: 'The {subject} {verb} clean {code}.',
        semanticSlots: {'subject': 'team', 'verb': 'write', 'code': 'code'},
      ),
      SentencePatternConfig(
        template: 'The {subject} {adverb} {verb} each {object}.',
        semanticSlots: {'subject': 'team', 'verb': 'test', 'object': 'feature'},
        adverbKey: 'quickly',
      ),
      SentencePatternConfig(
        template: 'The {subject} {verb} the {object} before release.',
        semanticSlots: {'subject': 'team', 'verb': 'ship', 'object': 'feature'},
      ),
    ],
  ),
];

/// Portuguese phrase patterns (category-driven templates).
List<PhrasePatternConfig> get portuguesePhrasePatterns =>
    portuguesePhraseTemplateLibrary.templates
        .map((template) => template.toPatternConfig())
        .toList(growable: false);

/// Portuguese phrase template library with word categories.
const portuguesePhraseLibrary = portuguesePhraseTemplateLibrary;

/// Portuguese paragraph patterns for text exercises.
const portugueseParagraphPatterns = [
  ParagraphPatternConfig(
    id: 'pt-paragraph-morning',
    joiner: ' ',
    sentences: [
      SentencePatternConfig(
        template: 'Toda {morning}, o {subject} toma {coffee}.',
        semanticSlots: {
          'morning': 'morning',
          'subject': 'developer',
          'coffee': 'coffee',
        },
      ),
      SentencePatternConfig(
        template: 'Depois o {subject} {adverb} {verb} {english} {paragraph}.',
        semanticSlots: {
          'subject': 'developer',
          'verb': 'read',
          'english': 'english',
          'paragraph': 'paragraph',
        },
        adverbKey: 'carefully',
      ),
      SentencePatternConfig(
        template: 'Este {exercise} melhora o {work} em {english}.',
        semanticSlots: {
          'exercise': 'exercise',
          'english': 'english',
          'work': 'work',
        },
      ),
    ],
  ),
  ParagraphPatternConfig(
    id: 'pt-paragraph-dev',
    joiner: ' ',
    sentences: [
      SentencePatternConfig(
        template: 'A {subject} {verb} {code} limpo.',
        semanticSlots: {'subject': 'team', 'verb': 'write', 'code': 'code'},
      ),
      SentencePatternConfig(
        template: 'A {subject} {adverb} {verb} cada {object}.',
        semanticSlots: {'subject': 'team', 'verb': 'test', 'object': 'feature'},
        adverbKey: 'quickly',
      ),
      SentencePatternConfig(
        template: 'A {subject} {verb} a {object} antes do lançamento.',
        semanticSlots: {'subject': 'team', 'verb': 'ship', 'object': 'feature'},
      ),
    ],
  ),
];

/// Source documents for English phrase patterns.
List<DatasetSourceDocument> englishPhraseDocuments() {
  return englishPhraseTemplateLibrary.documents();
}

/// Source documents for English paragraph patterns.
List<DatasetSourceDocument> englishParagraphDocuments() {
  return [
    for (final pattern in englishParagraphPatterns)
      DatasetSourceDocument(
        id: pattern.id,
        content: '${pattern.sentences.length} sentences',
        title: pattern.id,
        language: 'en',
        metadata: {'textKind': 'paragraph', 'patternId': pattern.id},
      ),
  ];
}

/// Source documents for Portuguese phrase patterns.
List<DatasetSourceDocument> portuguesePhraseDocuments() {
  return portuguesePhraseTemplateLibrary.documents();
}

/// Source documents for Portuguese paragraph patterns.
List<DatasetSourceDocument> portugueseParagraphDocuments() {
  return [
    for (final pattern in portugueseParagraphPatterns)
      DatasetSourceDocument(
        id: pattern.id,
        content: '${pattern.sentences.length} sentences',
        title: pattern.id,
        language: 'pt',
        metadata: {'textKind': 'paragraph', 'patternId': pattern.id},
      ),
  ];
}

/// Map of English phrase patterns by id.
Map<String, PhrasePatternConfig> englishPhrasePatternMap() {
  return englishPhraseTemplateLibrary.patternMap();
}

/// Map of English paragraph patterns by id.
Map<String, ParagraphPatternConfig> englishParagraphPatternMap() {
  return {for (final p in englishParagraphPatterns) p.id: p};
}

/// Map of Portuguese phrase patterns by id.
Map<String, PhrasePatternConfig> portuguesePhrasePatternMap() {
  return portuguesePhraseTemplateLibrary.patternMap();
}

/// Map of Portuguese paragraph patterns by id.
Map<String, ParagraphPatternConfig> portugueseParagraphPatternMap() {
  return {for (final p in portugueseParagraphPatterns) p.id: p};
}

/// Runs phrase then paragraph pipelines for English and Portuguese.
MemorySource allTextExerciseDocuments() {
  return MemorySource([
    ...englishPhraseDocuments(),
    ...englishParagraphDocuments(),
    ...portuguesePhraseDocuments(),
    ...portugueseParagraphDocuments(),
  ]);
}
