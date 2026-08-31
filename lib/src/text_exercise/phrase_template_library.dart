import '../source/dataset_source.dart';
import 'text_build.dart';
import 'word_category_bank.dart';

/// Declarative phrase template: `{slot}` placeholders filled from categories.
class PhraseTemplate {
  /// Creates a category-driven phrase template.
  const PhraseTemplate({
    required this.id,
    required this.template,
    required this.slotCategories,
    this.structureVariants = const [],
  });

  /// Stable template id (becomes source document id).
  final String id;

  /// Primary surface template with `{slot}` placeholders.
  final String template;

  /// Alternate templates with the same `{slot}` placeholders and meaning.
  final List<String> structureVariants;

  /// Slot name → [WordCategoryBank] category name.
  final Map<String, String> slotCategories;

  /// Primary template followed by [structureVariants].
  List<String> get allStructureTemplates => [template, ...structureVariants];

  /// Number of structural templates including the primary [template].
  int get structureCount => allStructureTemplates.length;

  /// Converts to a [PhrasePatternConfig] for [PhraseGenerator].
  PhrasePatternConfig toPatternConfig() {
    return PhrasePatternConfig(
      id: id,
      template: template,
      slotCategories: slotCategories,
      structureVariants: structureVariants,
    );
  }
}

/// A language-specific collection of phrase templates and a word category bank.
class PhraseTemplateLibrary {
  /// Creates a template library.
  const PhraseTemplateLibrary({
    required this.language,
    required this.templates,
    required this.wordBank,
  });

  /// Language code (`en`, `pt`, …).
  final String language;

  /// Phrase templates in this library.
  final List<PhraseTemplate> templates;

  /// Words grouped by category for filling template slots.
  final WordCategoryBank wordBank;

  /// Pattern configs keyed by template id.
  Map<String, PhrasePatternConfig> patternMap() {
    return {for (final t in templates) t.id: t.toPatternConfig()};
  }

  /// Source documents for pipeline ingestion (one per template).
  List<DatasetSourceDocument> documents() {
    return [
      for (final template in templates)
        DatasetSourceDocument(
          id: template.id,
          content: template.template,
          title: template.id,
          language: language,
          metadata: {
            'textKind': 'phrase',
            'patternId': template.id,
            'slotCategories': template.slotCategories,
          },
        ),
    ];
  }
}

/// English phrase templates filled from [englishWordCategoryBank].
const englishPhraseTemplateLibrary = PhraseTemplateLibrary(
  language: 'en',
  wordBank: englishWordCategoryBank,
  templates: [
    PhraseTemplate(
      id: 'en-phrase-action-object',
      template: 'The {subject} {adverb} {verb} the {object}.',
      slotCategories: {
        'subject': 'actor',
        'adverb': 'manner',
        'verb': 'action',
        'object': 'thing',
      },
    ),
    PhraseTemplate(
      id: 'en-phrase-ship-feature',
      template: 'The {subject} {verb} a new {object}.',
      slotCategories: {'subject': 'actor', 'verb': 'action', 'object': 'thing'},
    ),
    PhraseTemplate(
      id: 'en-phrase-daily-study',
      template: 'The {subject} {verb} {language} {text_unit} every day.',
      slotCategories: {
        'subject': 'actor',
        'verb': 'action',
        'language': 'language',
        'text_unit': 'text_part',
      },
    ),
    PhraseTemplate(
      id: 'en-phrase-morning-drink',
      template: 'Every {time}, the {subject} drinks {drink}.',
      slotCategories: {'time': 'time', 'subject': 'actor', 'drink': 'drink'},
    ),
    PhraseTemplate(
      id: 'en-phrase-clean-code',
      template: 'The {subject} {verb} clean {object}.',
      slotCategories: {'subject': 'actor', 'verb': 'action', 'object': 'thing'},
    ),
    PhraseTemplate(
      id: 'en-phrase-test-each',
      template: 'The {subject} {adverb} {verb} each {object}.',
      slotCategories: {
        'subject': 'actor',
        'adverb': 'manner',
        'verb': 'action',
        'object': 'thing',
      },
    ),
    PhraseTemplate(
      id: 'en-phrase-before-release',
      template: 'Before release, the {subject} {verb} the {object}.',
      slotCategories: {'subject': 'actor', 'verb': 'action', 'object': 'thing'},
    ),
    PhraseTemplate(
      id: 'en-phrase-improves-work',
      template: 'This {activity} improves {language} {work}.',
      slotCategories: {
        'activity': 'activity',
        'language': 'language',
        'work': 'activity',
      },
    ),
    PhraseTemplate(
      id: 'en-phrase-after-meal',
      template: 'After {meal}, the {subject} {verb} {language} {text_unit}.',
      slotCategories: {
        'meal': 'meal',
        'subject': 'actor',
        'verb': 'action',
        'language': 'language',
        'text_unit': 'text_part',
      },
    ),
    PhraseTemplate(
      id: 'en-phrase-starts-activity',
      template: 'The {subject} starts {activity} at {time}.',
      slotCategories: {
        'subject': 'actor',
        'activity': 'activity',
        'time': 'time',
      },
    ),
    PhraseTemplate(
      id: 'en-phrase-found-bug',
      template: 'The {subject} found a {object} in the {artifact}.',
      slotCategories: {
        'subject': 'actor',
        'object': 'thing',
        'artifact': 'thing',
      },
    ),
    PhraseTemplate(
      id: 'en-phrase-must-test',
      template: 'The {subject} must {verb} every {object} before shipping.',
      slotCategories: {'subject': 'actor', 'verb': 'action', 'object': 'thing'},
    ),
  ],
);

/// Portuguese phrase templates filled from [portugueseWordCategoryBank].
const portuguesePhraseTemplateLibrary = PhraseTemplateLibrary(
  language: 'pt',
  wordBank: portugueseWordCategoryBank,
  templates: [
    PhraseTemplate(
      id: 'pt-phrase-action-object',
      template: 'O {subject} {adverb} {verb} o {object}.',
      slotCategories: {
        'subject': 'actor',
        'adverb': 'manner',
        'verb': 'action',
        'object': 'thing',
      },
    ),
    PhraseTemplate(
      id: 'pt-phrase-ship-feature',
      template: 'A {subject} {verb} uma nova {object}.',
      slotCategories: {'subject': 'actor', 'verb': 'action', 'object': 'thing'},
    ),
    PhraseTemplate(
      id: 'pt-phrase-daily-study',
      template: 'O {subject} {verb} {language} {text_unit} todos os dias.',
      slotCategories: {
        'subject': 'actor',
        'verb': 'action',
        'language': 'language',
        'text_unit': 'text_part',
      },
    ),
    PhraseTemplate(
      id: 'pt-phrase-morning-drink',
      template: 'Toda {time}, o {subject} toma {drink}.',
      slotCategories: {'time': 'time', 'subject': 'actor', 'drink': 'drink'},
    ),
    PhraseTemplate(
      id: 'pt-phrase-clean-code',
      template: 'O {subject} {verb} {object} limpo.',
      slotCategories: {'subject': 'actor', 'verb': 'action', 'object': 'thing'},
    ),
    PhraseTemplate(
      id: 'pt-phrase-test-each',
      template: 'A {subject} {adverb} {verb} cada {object}.',
      slotCategories: {
        'subject': 'actor',
        'adverb': 'manner',
        'verb': 'action',
        'object': 'thing',
      },
    ),
    PhraseTemplate(
      id: 'pt-phrase-before-release',
      template: 'Antes do lançamento, a {subject} {verb} a {object}.',
      slotCategories: {'subject': 'actor', 'verb': 'action', 'object': 'thing'},
    ),
    PhraseTemplate(
      id: 'pt-phrase-improves-work',
      template: 'Este {activity} melhora o {work} em {language}.',
      slotCategories: {
        'activity': 'activity',
        'work': 'activity',
        'language': 'language',
      },
    ),
    PhraseTemplate(
      id: 'pt-phrase-after-meal',
      template: 'Depois do {meal}, o {subject} {verb} {language} {text_unit}.',
      slotCategories: {
        'meal': 'meal',
        'subject': 'actor',
        'verb': 'action',
        'language': 'language',
        'text_unit': 'text_part',
      },
    ),
    PhraseTemplate(
      id: 'pt-phrase-starts-activity',
      template: 'O {subject} começa {activity} de {time}.',
      slotCategories: {
        'subject': 'actor',
        'activity': 'activity',
        'time': 'time',
      },
    ),
    PhraseTemplate(
      id: 'pt-phrase-found-bug',
      template: 'O {subject} encontrou um {object} no {artifact}.',
      slotCategories: {
        'subject': 'actor',
        'object': 'thing',
        'artifact': 'thing',
      },
    ),
    PhraseTemplate(
      id: 'pt-phrase-must-test',
      template: 'O {subject} deve {verb} cada {object} antes de publicar.',
      slotCategories: {'subject': 'actor', 'verb': 'action', 'object': 'thing'},
    ),
  ],
);
