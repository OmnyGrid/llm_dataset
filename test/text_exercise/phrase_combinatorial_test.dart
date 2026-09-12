import 'dart:io';

import 'package:llm_dataset/llm_dataset.dart';
import 'package:test/test.dart';

void main() {
  group('PhraseCombinationExpander', () {
    test('counts lemma and synonym combinations', () {
      const template = PhraseTemplate(
        id: 't1',
        template: 'The {subject} {verb} the {object}.',
        slotCategories: {
          'subject': 'actor',
          'verb': 'action',
          'object': 'thing',
        },
      );

      const bank = WordCategoryBank(
        categories: {
          'actor': ['developer', 'team'],
          'action': ['write', 'read'],
          'thing': ['code', 'feature'],
        },
      );

      const lexicon = TextLexicon(
        language: 'en',
        synonyms: {
          'developer': ['developer', 'engineer'],
          'team': ['team', 'group'],
          'write': ['writes', 'drafts'],
          'read': ['reads', 'studies'],
          'code': ['code', 'software'],
          'feature': ['feature', 'capability'],
        },
      );

      expect(
        PhraseCombinationExpander.countTemplate(
          template: template,
          lexicon: lexicon,
          wordBank: bank,
        ),
        64,
      );

      final combinations = PhraseCombinationExpander.expandTemplate(
        template: template,
        lexicon: lexicon,
        wordBank: bank,
      ).toList();

      expect(combinations, hasLength(64));
      expect(combinations.map((c) => c.text).toSet(), hasLength(64));
      expect(
        PhraseCombinationExpander.countLemmaCombinations(
          template: template,
          wordBank: bank,
        ),
        8,
      );
    });

    test('emits canonical then direct variations before next phrase', () {
      const template = PhraseTemplate(
        id: 'order',
        template: '{subject} {verb}.',
        slotCategories: {'subject': 'actor', 'verb': 'action'},
      );

      const bank = WordCategoryBank(
        categories: {
          'actor': ['developer'],
          'action': ['write', 'read'],
        },
      );

      const lexicon = TextLexicon(
        language: 'en',
        synonyms: {
          'developer': ['developer', 'engineer'],
          'write': ['writes', 'drafts'],
          'read': ['reads', 'studies'],
        },
      );

      final phrases = PhraseCombinationExpander.expandTemplate(
        template: template,
        lexicon: lexicon,
        wordBank: bank,
      ).map((combination) => combination.text).toList();

      expect(phrases, [
        'developer writes.',
        'engineer writes.',
        'developer drafts.',
        'engineer drafts.',
        'developer reads.',
        'engineer reads.',
        'developer studies.',
        'engineer studies.',
      ]);
    });

    test('iterates lemma slots in template appearance order', () {
      const template = PhraseTemplate(
        id: 'lemma-order',
        template: '{subject} {verb} the {object}.',
        slotCategories: {
          'subject': 'actor',
          'verb': 'action',
          'object': 'thing',
        },
      );

      const bank = WordCategoryBank(
        categories: {
          'actor': ['developer', 'team'],
          'action': ['write'],
          'thing': ['code', 'feature'],
        },
      );

      const lexicon = TextLexicon(
        language: 'en',
        synonyms: {
          'developer': ['developer'],
          'team': ['team'],
          'write': ['writes'],
          'code': ['code'],
          'feature': ['feature'],
        },
      );

      final lemmaKeys = PhraseCombinationExpander.expandTemplate(
        template: template,
        lexicon: lexicon,
        wordBank: bank,
      ).map((combination) => combination.semanticKeys).toList();

      expect(lemmaKeys, [
        {'subject': 'developer', 'verb': 'write', 'object': 'code'},
        {'subject': 'developer', 'verb': 'write', 'object': 'feature'},
        {'subject': 'team', 'verb': 'write', 'object': 'code'},
        {'subject': 'team', 'verb': 'write', 'object': 'feature'},
      ]);
    });

    test('emits structural variants after each surface form', () {
      const template = PhraseTemplate(
        id: 'structure',
        template: '{subject} {verb} {object}.',
        structureVariants: ['{adverb}, {subject} {verb} {object}.'],
        slotCategories: {
          'subject': 'actor',
          'verb': 'action',
          'object': 'thing',
          'adverb': 'manner',
        },
      );

      const bank = WordCategoryBank(
        categories: {
          'actor': ['developer'],
          'action': ['write'],
          'thing': ['code'],
          'manner': ['carefully'],
        },
      );

      const lexicon = TextLexicon(
        language: 'en',
        synonyms: {
          'developer': ['developer'],
          'write': ['writes'],
          'code': ['code'],
          'carefully': ['carefully'],
        },
      );

      final phrases = PhraseCombinationExpander.expandTemplate(
        template: template,
        lexicon: lexicon,
        wordBank: bank,
      ).map((combination) => combination.text).toList();

      expect(phrases, [
        'developer writes code.',
        'carefully, developer writes code.',
      ]);
    });
  });

  group('PhraseCombinatorialGenerator', () {
    test('yields all combinations for one template document', () async {
      const template = PhraseTemplate(
        id: 'combo',
        template: '{subject} {verb}.',
        slotCategories: {'subject': 'actor', 'verb': 'action'},
      );

      const bank = WordCategoryBank(
        categories: {
          'actor': ['developer'],
          'action': ['write', 'read'],
        },
      );

      const lexicon = TextLexicon(
        language: 'en',
        synonyms: {
          'developer': ['developer', 'engineer'],
          'write': ['writes', 'drafts'],
          'read': ['reads', 'studies'],
        },
      );

      const library = PhraseTemplateLibrary(
        language: 'en',
        wordBank: bank,
        templates: [template],
      );

      final doc = library.documents().single;
      final entries = await PhraseCombinatorialGenerator(
        config: const GeneratorConfig(dataset: 'd', language: 'en', seed: 1),
        templates: {template.id: template},
        lexicon: lexicon,
        categoryBank: bank,
      ).generate(doc).toList();

      expect(entries, hasLength(8));
      expect(entries.map((entry) => entry.input).toList(), [
        'developer writes.',
        'engineer writes.',
        'developer drafts.',
        'engineer drafts.',
        'developer reads.',
        'engineer reads.',
        'developer studies.',
        'engineer studies.',
      ]);
      expect(entries[0].isCanonical, isTrue);
      expect(entries[4].isCanonical, isTrue);
      expect(entries[1].provenance?.transformation, 'meaning_preserving');
      expect(entries[1].variationGroup, entries[0].variationGroup);
      expect(entries[4].variationGroup, isNot(entries[0].variationGroup));
    });

    test('uses structure variants from loaded store templates', () async {
      final localeDir = Directory(
        '${Directory.current.path}/example/phrase_templates/en',
      );
      final store = await PhraseTemplateStoreLoader(localeDirectory: localeDir)
          .load();
      final template = store.library.templates.firstWhere(
        (t) => t.id == 'ext-action-object',
      );
      final doc = store.library.documents().firstWhere(
        (d) => d.id == 'ext-action-object',
      );

      final entries = await store
          .createCombinatorialGenerator(
            config: const GeneratorConfig(
              dataset: 'd',
              language: 'en',
              seed: 1,
            ),
          )
          .generate(doc)
          .take(3)
          .toList();

      expect(entries, hasLength(3));
      expect(
        entries.map((e) => e.metadata[TextExerciseMetadata.structureIndex]),
        [0, 1, 2],
      );
      expect(entries[0].input, startsWith('The '));
      expect(entries[1].input, isNot(entries[0].input));
      expect(entries[2].input, isNot(entries[0].input));
      expect(template.structureCount, 3);
    });
  });
}
