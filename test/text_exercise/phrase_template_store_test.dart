import 'dart:io';

import 'package:llm_dataset/llm_dataset.dart';
import 'package:test/test.dart';

void main() {
  late Directory localeDir;

  setUp(() {
    localeDir = Directory(
      '${Directory.current.path}/test/fixtures/phrase_templates/en',
    );
  });

  group('PhraseTemplateStoreLoader', () {
    test('loads english locale from example files', () async {
      final store = await PhraseTemplateStoreLoader(localeDirectory: localeDir)
          .load();

      expect(store.manifest.language, 'en');
      expect(store.manifest.wordSetPaths, hasLength(13));
      expect(store.manifest.templateGroupPaths, hasLength(5));
      expect(store.wordBank.categoryNames, contains('actor'));
      expect(store.library.templates, hasLength(31));
      expect(store.lexicon.synonyms, containsPair('developer', isNotEmpty));
      expect(store.categoryCount, 13);
      expect(store.templateCount, 31);
      expect(store.lemmaSlotCount, 68);
      expect(store.uniqueLemmaCount, 68);
    });

    test('builds phrases from loaded store', () async {
      final store = await PhraseTemplateStoreLoader(localeDirectory: localeDir)
          .load();

      final template = store.library.templates.firstWhere(
        (t) => t.id == 'ext-action-object',
      );
      final slots = template.toPatternConfig().resolveSlots(
        store.lexicon,
        categories: store.wordBank,
        pickIndex: 1,
      );

      expect(buildFromTemplate(template.template, slots), isNotEmpty);
    });

    test('combination stats and averageStructureCount', () async {
      final store = await PhraseTemplateStoreLoader(localeDirectory: localeDir)
          .load();

      expect(store.combinationCount, greaterThan(store.lemmaCombinationCount));
      expect(store.averageStructureCount, greaterThan(1));
      expect(
        store.rootDirectory,
        endsWith('test/fixtures/phrase_templates/en'),
      );
    });

    test('createVariationGenerator and combinatorial generator', () async {
      final store = await PhraseTemplateStoreLoader(localeDirectory: localeDir)
          .load();
      final doc = store.library.documents().first;

      final variationGen = store.createVariationGenerator(
        variationsPerEntry: 1,
        seed: 2,
        instanceId: 'test',
      );
      final canonical = await store
          .createPhraseGenerator(
            config: const GeneratorConfig(
              dataset: 'd',
              language: 'en',
              seed: 1,
            ),
          )
          .generate(doc)
          .first;
      final variations = await variationGen.generate(canonical);
      expect(variations, hasLength(1));

      final combo = await store
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
      expect(combo, hasLength(3));
      expect(combo.first.isCanonical, isTrue);
    });

    test('createPhraseGenerator produces entries', () async {
      final store = await PhraseTemplateStoreLoader(localeDirectory: localeDir)
          .load();

      final doc = store.library.documents().first;
      final entry = await store
          .createPhraseGenerator(
            config: const GeneratorConfig(
              dataset: 'd',
              language: 'en',
              seed: 1,
            ),
          )
          .generate(doc)
          .first;

      expect(entry.input, isNotEmpty);
    });

    test('loads structural variants from template groups', () async {
      final store = await PhraseTemplateStoreLoader(localeDirectory: localeDir)
          .load();

      final template = store.library.templates.firstWhere(
        (t) => t.id == 'ext-action-object',
      );

      expect(template.structureCount, 3);
      expect(template.structureVariants, hasLength(2));
    });

    test('rejects unknown category references', () async {
      final temp = await Directory.systemTemp.createTemp('phrase_store_test_');
      addTearDown(() => temp.deleteSync(recursive: true));

      await _writeMinimalStore(temp, templateSlotCategory: 'missing_category');

      expect(
        () => PhraseTemplateStoreLoader(localeDirectory: temp).load(),
        throwsA(isA<PhraseTemplateStoreException>()),
      );
    });

    test('rejects duplicate template ids', () async {
      final temp = await Directory.systemTemp.createTemp('phrase_store_test_');
      addTearDown(() => temp.deleteSync(recursive: true));

      await _writeMinimalStore(temp, duplicateTemplateId: true);

      expect(
        () => PhraseTemplateStoreLoader(localeDirectory: temp).load(),
        throwsA(isA<PhraseTemplateStoreException>()),
      );
    });

    test('rejects placeholder and slot mismatches', () {
      expect(
        () => PhraseTemplateStoreCodec.assemble(
          manifest: const PhraseTemplateLocaleManifest(
            language: 'en',
            version: 'test',
            description: '',
            wordSetPaths: ['words/actor.json'],
            templateGroupPaths: ['templates/a.json'],
          ),
          wordSetsByPath: {
            'words/actor.json': {
              'category': 'actor',
              'words': {
                'developer': ['developer'],
              },
            },
          },
          templateGroupsByPath: {
            'templates/a.json': {
              'group': 'a',
              'templates': [
                {
                  'id': 't1',
                  'template': 'The {subject} codes.',
                  'slotCategories': {'subject': 'actor', 'extra': 'actor'},
                },
              ],
            },
          },
        ),
        throwsA(isA<PhraseTemplateStoreException>()),
      );
    });

    test('fromPath factory loads store', () async {
      final store = await PhraseTemplateStoreLoader.fromPath(localeDir.path)
          .load();
      expect(store.templateCount, greaterThan(0));
    });

    test('loader errors for missing and invalid manifest', () async {
      final temp = await Directory.systemTemp.createTemp('phrase_loader_');
      addTearDown(() => temp.deleteSync(recursive: true));

      expect(
        () => PhraseTemplateStoreLoader(localeDirectory: temp).load(),
        throwsA(isA<PhraseTemplateStoreException>()),
      );

      await File('${temp.path}/manifest.json').writeAsString('{ invalid json');
      expect(
        () => PhraseTemplateStoreLoader(localeDirectory: temp).load(),
        throwsA(isA<PhraseTemplateStoreException>()),
      );
    });

    test('loader errors for missing referenced file', () async {
      final temp = await Directory.systemTemp.createTemp('phrase_loader_');
      addTearDown(() => temp.deleteSync(recursive: true));

      await File('${temp.path}/manifest.json').writeAsString('''
{
  "language": "en",
  "wordSets": ["words/missing.json"],
  "templateGroups": []
}
''');

      expect(
        () => PhraseTemplateStoreLoader(localeDirectory: temp).load(),
        throwsA(isA<PhraseTemplateStoreException>()),
      );
    });

    test('rejects unsafe manifest paths', () {
      expect(
        () => PhraseTemplateLocaleManifest.fromJson({
          'language': 'en',
          'wordSets': ['../secrets.json'],
          'templateGroups': <String>[],
        }),
        throwsA(isA<PhraseTemplateStoreException>()),
      );
    });
  });

  group('PhraseTemplateStore empty library', () {
    test('averageStructureCount is zero without templates', () {
      final store = PhraseTemplateStore(
        rootDirectory: null,
        manifest: const PhraseTemplateLocaleManifest(
          language: 'en',
          version: 'test',
          description: '',
          wordSetPaths: [],
          templateGroupPaths: [],
        ),
        lexicon: englishTextLexicon,
        wordBank: englishWordCategoryBank,
        library: PhraseTemplateLibrary(
          language: 'en',
          templates: const [],
          wordBank: englishWordCategoryBank,
        ),
      );

      expect(store.templateCount, 0);
      expect(store.averageStructureCount, 0);
      expect(store.combinationCount, 0);
    });

    test('assemble rejects empty template groups', () {
      expect(
        () => PhraseTemplateStoreCodec.assemble(
          manifest: const PhraseTemplateLocaleManifest(
            language: 'en',
            version: 'test',
            description: '',
            wordSetPaths: ['words/actor.json'],
            templateGroupPaths: [],
          ),
          wordSetsByPath: {
            'words/actor.json': {
              'category': 'actor',
              'words': {
                'developer': ['developer'],
              },
            },
          },
          templateGroupsByPath: const {},
        ),
        throwsA(isA<PhraseTemplateStoreException>()),
      );
    });
  });

  group('WordCategoryBank stats', () {
    test('counts lemma slots and unique lemmas', () {
      const bank = WordCategoryBank(
        categories: {
          'actor': ['developer', 'team'],
          'role': ['developer', 'manager'],
        },
      );

      expect(bank.lemmaSlotCount, 4);
      expect(bank.uniqueLemmaCount, 3);
    });
  });
}

Future<void> _writeMinimalStore(
  Directory root, {
  String templateSlotCategory = 'actor',
  bool duplicateTemplateId = false,
}) async {
  await Directory('${root.path}/words').create(recursive: true);
  await Directory('${root.path}/templates').create(recursive: true);

  await File('${root.path}/manifest.json').writeAsString('''
{
  "language": "en",
  "version": "test",
  "wordSets": ["words/actor.json"],
  "templateGroups": ["templates/a.json", "templates/b.json"]
}
''');

  await File('${root.path}/words/actor.json').writeAsString('''
{
  "category": "actor",
  "words": {
    "developer": ["developer", "engineer"]
  }
}
''');

  await File('${root.path}/templates/a.json').writeAsString('''
{
  "group": "a",
  "templates": [
    {
      "id": "t1",
      "template": "The {subject} codes.",
      "slotCategories": { "subject": "$templateSlotCategory" }
    }
  ]
}
''');

  await File('${root.path}/templates/b.json').writeAsString('''
{
  "group": "b",
  "templates": [
    {
      "id": "${duplicateTemplateId ? 't1' : 't2'}",
      "template": "Another {subject}.",
      "slotCategories": { "subject": "actor" }
    }
  ]
}
''');
}
