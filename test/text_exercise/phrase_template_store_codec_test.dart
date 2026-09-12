import 'package:llm_dataset/llm_dataset.dart';
import 'package:test/test.dart';

const _manifest = PhraseTemplateLocaleManifest(
  language: 'en',
  version: 'test',
  description: 'codec tests',
  wordSetPaths: ['words/actor.json'],
  templateGroupPaths: ['templates/a.json'],
);

Map<String, dynamic> _validWordSet({String category = 'actor'}) => {
  'category': category,
  'words': {
    'developer': ['developer', 'engineer'],
  },
};

Map<String, dynamic> _validTemplateGroup({
  String id = 't1',
  String template = 'The {subject} codes.',
  Map<String, String>? slotCategories,
  List<String>? structureVariants,
}) => {
  'group': 'a',
  'templates': [
    {
      'id': id,
      'template': template,
      'slotCategories': slotCategories ?? {'subject': 'actor'},
      'structureVariants': ?structureVariants,
    },
  ],
};

PhraseTemplateStore _assemble({
  Map<String, Map<String, dynamic>>? wordSets,
  Map<String, Map<String, dynamic>>? templateGroups,
  PhraseTemplateLocaleManifest? manifest,
}) {
  return PhraseTemplateStoreCodec.assemble(
    manifest: manifest ?? _manifest,
    wordSetsByPath: wordSets ?? {'words/actor.json': _validWordSet()},
    templateGroupsByPath:
        templateGroups ?? {'templates/a.json': _validTemplateGroup()},
    rootDirectory: '/tmp/store',
  );
}

void main() {
  group('PhraseTemplateStoreCodec.assemble success', () {
    test('builds store with structure variants', () {
      final store = _assemble(
        templateGroups: {
          'templates/a.json': _validTemplateGroup(
            structureVariants: ['Quickly, the {subject} codes.'],
          ),
        },
      );

      expect(store.rootDirectory, '/tmp/store');
      expect(store.library.templates.single.structureCount, 2);
      expect(store.lexicon.forms('developer'), ['developer', 'engineer']);
    });

    test(
      'merges identical synonym lists from duplicate lemmas across word sets',
      () {
        final manifest = PhraseTemplateLocaleManifest(
          language: 'en',
          version: 'test',
          description: '',
          wordSetPaths: ['words/a.json', 'words/b.json'],
          templateGroupPaths: ['templates/a.json'],
        );
        final store = PhraseTemplateStoreCodec.assemble(
          manifest: manifest,
          wordSetsByPath: {
            'words/a.json': {
              'category': 'actor',
              'words': {
                'developer': ['developer', 'engineer'],
              },
            },
            'words/b.json': {
              'category': 'role',
              'words': {
                'developer': ['developer', 'engineer'],
              },
            },
          },
          templateGroupsByPath: {
            'templates/a.json': _validTemplateGroup(
              slotCategories: {'subject': 'actor'},
            ),
          },
        );

        expect(store.wordBank.categoryNames, containsAll(['actor', 'role']));
        expect(store.lexicon.synonyms['developer'], ['developer', 'engineer']);
      },
    );
  });

  group('PhraseTemplateStoreCodec.assemble manifest file errors', () {
    test('missing word set path in map', () {
      expect(
        () => PhraseTemplateStoreCodec.assemble(
          manifest: _manifest,
          wordSetsByPath: {},
          templateGroupsByPath: {'templates/a.json': _validTemplateGroup()},
        ),
        throwsA(isA<PhraseTemplateStoreException>()),
      );
    });

    test('missing template group path in map', () {
      expect(
        () => PhraseTemplateStoreCodec.assemble(
          manifest: _manifest,
          wordSetsByPath: {'words/actor.json': _validWordSet()},
          templateGroupsByPath: {},
        ),
        throwsA(isA<PhraseTemplateStoreException>()),
      );
    });
  });

  group('PhraseTemplateStoreCodec word set validation', () {
    test('rejects missing category', () {
      expect(
        () => _assemble(
          wordSets: {
            'words/actor.json': {
              'words': {
                'developer': ['developer'],
              },
            },
          },
        ),
        throwsA(isA<PhraseTemplateStoreException>()),
      );
    });

    test('rejects missing words map', () {
      expect(
        () => _assemble(
          wordSets: {
            'words/actor.json': {'category': 'actor'},
          },
        ),
        throwsA(isA<PhraseTemplateStoreException>()),
      );
    });

    test('rejects duplicate category name', () {
      final manifest = PhraseTemplateLocaleManifest(
        language: 'en',
        version: 'test',
        description: '',
        wordSetPaths: ['words/a.json', 'words/b.json'],
        templateGroupPaths: ['templates/a.json'],
      );
      expect(
        () => PhraseTemplateStoreCodec.assemble(
          manifest: manifest,
          wordSetsByPath: {
            'words/a.json': _validWordSet(),
            'words/b.json': _validWordSet(),
          },
          templateGroupsByPath: {'templates/a.json': _validTemplateGroup()},
        ),
        throwsA(isA<PhraseTemplateStoreException>()),
      );
    });

    test('rejects empty lemma forms', () {
      expect(
        () => _assemble(
          wordSets: {
            'words/actor.json': {
              'category': 'actor',
              'words': {'developer': <String>[]},
            },
          },
        ),
        throwsA(isA<PhraseTemplateStoreException>()),
      );
    });

    test('rejects conflicting synonym lists for same lemma', () {
      final manifest = PhraseTemplateLocaleManifest(
        language: 'en',
        version: 'test',
        description: '',
        wordSetPaths: ['words/a.json', 'words/b.json'],
        templateGroupPaths: ['templates/a.json'],
      );
      expect(
        () => PhraseTemplateStoreCodec.assemble(
          manifest: manifest,
          wordSetsByPath: {
            'words/a.json': {
              'category': 'actor',
              'words': {
                'developer': ['developer', 'engineer'],
              },
            },
            'words/b.json': {
              'category': 'role',
              'words': {
                'developer': ['developer', 'coder'],
              },
            },
          },
          templateGroupsByPath: {'templates/a.json': _validTemplateGroup()},
        ),
        throwsA(isA<PhraseTemplateStoreException>()),
      );
    });

    test('rejects empty words map', () {
      expect(
        () => _assemble(
          wordSets: {
            'words/actor.json': {
              'category': 'actor',
              'words': <String, dynamic>{},
            },
          },
        ),
        throwsA(isA<PhraseTemplateStoreException>()),
      );
    });

    test('rejects non-array lemma forms', () {
      expect(
        () => _assemble(
          wordSets: {
            'words/actor.json': {
              'category': 'actor',
              'words': {'developer': 'not-a-list'},
            },
          },
        ),
        throwsA(isA<PhraseTemplateStoreException>()),
      );
    });
  });

  group('PhraseTemplateStoreCodec template group validation', () {
    test('rejects missing templates array', () {
      expect(
        () => _assemble(
          templateGroups: {
            'templates/a.json': {'group': 'a'},
          },
        ),
        throwsA(isA<PhraseTemplateStoreException>()),
      );
    });

    test('rejects non-map template entry', () {
      expect(
        () => _assemble(
          templateGroups: {
            'templates/a.json': {
              'templates': ['bad'],
            },
          },
        ),
        throwsA(isA<PhraseTemplateStoreException>()),
      );
    });

    test('rejects missing template id', () {
      expect(
        () => _assemble(
          templateGroups: {
            'templates/a.json': {
              'templates': [
                {
                  'template': 'The {subject} codes.',
                  'slotCategories': {'subject': 'actor'},
                },
              ],
            },
          },
        ),
        throwsA(isA<PhraseTemplateStoreException>()),
      );
    });

    test('rejects empty template string', () {
      expect(
        () => _assemble(
          templateGroups: {
            'templates/a.json': _validTemplateGroup(template: ''),
          },
        ),
        throwsA(isA<PhraseTemplateStoreException>()),
      );
    });

    test('rejects missing slotCategories', () {
      expect(
        () => _assemble(
          templateGroups: {
            'templates/a.json': {
              'templates': [
                {'id': 't1', 'template': 'The {subject} codes.'},
              ],
            },
          },
        ),
        throwsA(isA<PhraseTemplateStoreException>()),
      );
    });

    test('rejects empty slotCategories map', () {
      expect(
        () => _assemble(
          templateGroups: {
            'templates/a.json': _validTemplateGroup(slotCategories: {}),
          },
        ),
        throwsA(isA<PhraseTemplateStoreException>()),
      );
    });

    test('rejects unknown slot category reference', () {
      expect(
        () => _assemble(
          templateGroups: {
            'templates/a.json': _validTemplateGroup(
              slotCategories: {'subject': 'missing_category'},
            ),
          },
        ),
        throwsA(isA<PhraseTemplateStoreException>()),
      );
    });

    test('rejects placeholder mismatch', () {
      expect(
        () => _assemble(
          templateGroups: {
            'templates/a.json': _validTemplateGroup(
              template: 'The {subject} codes with {tool}.',
              slotCategories: {'subject': 'actor'},
            ),
          },
        ),
        throwsA(isA<PhraseTemplateStoreException>()),
      );
    });

    test('rejects extra placeholders without slots', () {
      expect(
        () => _assemble(
          templateGroups: {
            'templates/a.json': _validTemplateGroup(
              template: 'Codes.',
              slotCategories: {'subject': 'actor'},
            ),
          },
        ),
        throwsA(isA<PhraseTemplateStoreException>()),
      );
    });

    test('rejects invalid structureVariants type', () {
      expect(
        () => _assemble(
          templateGroups: {
            'templates/a.json': {
              'templates': [
                {
                  'id': 't1',
                  'template': 'The {subject} codes.',
                  'slotCategories': {'subject': 'actor'},
                  'structureVariants': 'bad',
                },
              ],
            },
          },
        ),
        throwsA(isA<PhraseTemplateStoreException>()),
      );
    });

    test('rejects empty structureVariants strings', () {
      expect(
        () => _assemble(
          templateGroups: {
            'templates/a.json': _validTemplateGroup(structureVariants: ['']),
          },
        ),
        throwsA(isA<PhraseTemplateStoreException>()),
      );
    });

    test('rejects structureVariants with placeholder mismatch', () {
      expect(
        () => _assemble(
          templateGroups: {
            'templates/a.json': _validTemplateGroup(
              structureVariants: ['Codes without slots.'],
            ),
          },
        ),
        throwsA(isA<PhraseTemplateStoreException>()),
      );
    });
  });
}
