/// Category-driven phrase templates loaded from JSON files via the package API.
///
/// Expands **every** template across **all** category word picks and **all**
/// lexicon synonym surfaces using [PhraseCombinatorialGenerator].
///
/// Prints **every** generated entry (input/output) with global and per-template
/// progress counters, then stores results in SQLite via batched commits.
///
/// Run:
/// ```bash
/// dart run example/phrase_template_categories.dart
/// ```
library;

import 'dart:io';

import 'package:llm_dataset/llm_dataset.dart';

import 'adapters/progress_phrase_stream.dart';

Future<void> main() async {
  final store = await _loadExampleStore();

  _printStoreSummary(store);
  _printCombinationPlan(store);
  await _generateAllCombinations(store);
  print('\ndone');
}

Directory examplePhraseTemplateLocaleDir({String locale = 'en'}) {
  final script = Platform.script.toFilePath();
  return Directory('${File(script).parent.path}/phrase_templates/$locale');
}

Future<PhraseTemplateStore> _loadExampleStore() {
  return PhraseTemplateStoreLoader(
    localeDirectory: examplePhraseTemplateLocaleDir(),
  ).load();
}

void _printStoreSummary(PhraseTemplateStore store) {
  print('== Phrase template store ==');
  print('locale: ${store.rootDirectory}');
  print('templates: ${store.templateCount}');
  print('categories: ${store.categoryCount}');
  print('unique lemmas: ${store.uniqueLemmaCount}');
  print(
    'structures per template (avg): '
    '${store.averageStructureCount.toStringAsFixed(1)}',
  );
}

void _printCombinationPlan(PhraseTemplateStore store) {
  print('\n== Combinatorial expansion plan ==');
  print('total combinations (all templates × words × synonyms): '
      '${store.combinationCount}');
  print('canonical lemma groups: ${store.lemmaCombinationCount}');
  print(
    'synonym variations: ${store.combinationCount - store.lemmaCombinationCount}',
  );

  final rows = <(String, int)>[
    for (final template in store.library.templates)
      (
        template.id,
        PhraseCombinationExpander.countTemplate(
          template: template,
          lexicon: store.lexicon,
          wordBank: store.wordBank,
        ),
      ),
  ]..sort((a, b) => b.$2.compareTo(a.$2));

  print('\nper template:');
  for (final row in rows) {
    print('  ${row.$1}: ${row.$2}');
  }
}

Future<void> _generateAllCombinations(PhraseTemplateStore store) async {
  print('\n== Generating all combinations ==');
  print('storage: SQLite (batched commits, ~10k rows each)');
  print('logging: every entry printed with progress counters');

  final tempDir = await Directory.systemTemp.createTemp('phrase_combinatorial_');
  final dbPath = '${tempDir.path}/all_phrase_combinations.db';
  final phrasesPath = '${tempDir.path}/all_phrases.txt';
  final phrasesSink = File(phrasesPath).openWrite();
  final sqliteStore = SqliteDatasetStore(dbPath)
    ..configureForBulkInsert();
  final lifecycle = DatasetLifecycle(sqliteStore);

  final config = GeneratorConfig(
    dataset: 'phrase-combinatorial',
    datasetVersion: store.manifest.version,
    language: store.manifest.language,
    seed: 1,
  );

  final generator = store.createCombinatorialGenerator(config: config);
  final documents = store.library.documents();
  final totalExpected = store.combinationCount;
  final runStarted = Stopwatch()..start();
  var entriesBeforeTemplate = 0;

  try {
    for (var i = 0; i < documents.length; i++) {
      final document = documents[i];
      final template = store.library.templates.firstWhere(
        (t) => t.id == document.id,
      );
      final expected = PhraseCombinationExpander.countTemplate(
        template: template,
        lexicon: store.lexicon,
        wordBank: store.wordBank,
      );

      print(
        '\n[template ${i + 1}/${documents.length}] ${document.id} '
        '($expected combinations)',
      );

      final templateStarted = Stopwatch()..start();
      await sqliteStore.addAllBatched(
        logCombinatorialProgress(
          entries: generator.generate(document).map((entry) {
            phrasesSink.writeln(entry.input);
            return entry;
          }),
          totalExpected: totalExpected,
          templateExpected: expected,
          templateId: document.id,
          templateIndex: i,
          templateCount: documents.length,
          entriesBeforeTemplate: entriesBeforeTemplate,
        ),
        batchSize: 10000,
      );
      templateStarted.stop();
      entriesBeforeTemplate += expected;

      final storedSoFar = await lifecycle.count(
        dataset: config.dataset,
        version: config.datasetVersion,
      );
      final elapsedSeconds = (runStarted.elapsed.inMilliseconds / 1000)
          .clamp(0.001, double.infinity);
      final rate = storedSoFar / elapsedSeconds;
      print(
        '\n  template done in ${templateStarted.elapsed.inSeconds}s '
        '(running total: $storedSoFar / $totalExpected, '
        '~${rate.round()} entries/s)',
      );
    }

    final stored = await lifecycle.count(
      dataset: config.dataset,
      version: config.datasetVersion,
    );
    print(
      '\ncomplete: stored=$stored (expected $totalExpected) '
      'in ${runStarted.elapsed.inMinutes}m ${runStarted.elapsed.inSeconds % 60}s',
    );

    print('canonical lemma groups: ${store.lemmaCombinationCount}');
    print(
      'synonym variations: '
      '${store.combinationCount - store.lemmaCombinationCount}',
    );

    await _printOutputPaths(tempDir, dbPath, phrasesPath);
  } finally {
    await phrasesSink.close();
    sqliteStore.close();
  }
}

Future<void> _printOutputPaths(
  Directory tempDir,
  String dbPath,
  String phrasesPath,
) async {
  final dbBytes = await File(dbPath).length();
  final phrasesBytes = await File(phrasesPath).length();
  print('\n== Output ==');
  print('directory: ${tempDir.path}');
  print('sqlite db: $dbPath (${(dbBytes / (1024 * 1024)).toStringAsFixed(2)} MB)');
  print(
    'all phrases: $phrasesPath '
    '(${(phrasesBytes / (1024 * 1024)).toStringAsFixed(2)} MB)',
  );
}
