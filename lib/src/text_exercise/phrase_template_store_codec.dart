import 'phrase_template_library.dart';
import 'phrase_template_locale_manifest.dart';
import 'phrase_template_store.dart';
import 'phrase_template_store_exception.dart';
import 'text_lexicon.dart';
import 'word_category_bank.dart';

/// Parses and validates phrase template store JSON documents.
abstract final class PhraseTemplateStoreCodec {
  /// Assembles a [PhraseTemplateStore] from parsed JSON maps.
  static PhraseTemplateStore assemble({
    required PhraseTemplateLocaleManifest manifest,
    required Map<String, Map<String, dynamic>> wordSetsByPath,
    required Map<String, Map<String, dynamic>> templateGroupsByPath,
    String? rootDirectory,
  }) {
    final synonyms = <String, List<String>>{};
    final categories = <String, List<String>>{};
    final templates = <PhraseTemplate>[];
    final templateIds = <String>{};

    for (final path in manifest.wordSetPaths) {
      final json = wordSetsByPath[path];
      if (json == null) {
        throw PhraseTemplateStoreException(
          'Missing word set JSON for manifest entry',
          path: path,
        );
      }
      _mergeWordSet(
        json,
        sourcePath: path,
        synonyms: synonyms,
        categories: categories,
      );
    }

    for (final path in manifest.templateGroupPaths) {
      final json = templateGroupsByPath[path];
      if (json == null) {
        throw PhraseTemplateStoreException(
          'Missing template group JSON for manifest entry',
          path: path,
        );
      }
      _mergeTemplateGroup(
        json,
        sourcePath: path,
        knownCategories: categories.keys.toSet(),
        templates: templates,
        templateIds: templateIds,
      );
    }

    if (templates.isEmpty) {
      throw PhraseTemplateStoreException(
        'No templates loaded',
        path: rootDirectory,
      );
    }

    final lexicon = TextLexicon(
      language: manifest.language,
      synonyms: synonyms,
    );
    final wordBank = WordCategoryBank(categories: categories);
    final library = PhraseTemplateLibrary(
      language: manifest.language,
      wordBank: wordBank,
      templates: templates,
    );

    return PhraseTemplateStore(
      rootDirectory: rootDirectory,
      manifest: manifest,
      lexicon: lexicon,
      wordBank: wordBank,
      library: library,
    );
  }

  static void _mergeWordSet(
    Map<String, dynamic> json, {
    required String sourcePath,
    required Map<String, List<String>> synonyms,
    required Map<String, List<String>> categories,
  }) {
    final category = json['category'];
    if (category is! String || category.isEmpty) {
      throw PhraseTemplateStoreException(
        'Word set missing non-empty category',
        path: sourcePath,
        field: 'category',
      );
    }

    final rawWords = json['words'];
    if (rawWords is! Map) {
      throw PhraseTemplateStoreException(
        'Word set missing words map',
        path: sourcePath,
        field: 'words',
      );
    }

    if (categories.containsKey(category)) {
      throw PhraseTemplateStoreException(
        'Duplicate word category "$category"',
        path: sourcePath,
        field: 'category',
      );
    }

    final lemmas = <String>[];
    for (final entry in rawWords.entries) {
      final lemma = entry.key.toString();
      final forms = _stringList(
        entry.value,
        field: 'words.$lemma',
        path: sourcePath,
      );
      if (forms.isEmpty) {
        throw PhraseTemplateStoreException(
          'Lemma "$lemma" must have at least one surface form',
          path: sourcePath,
          field: 'words.$lemma',
        );
      }

      lemmas.add(lemma);
      final existing = synonyms[lemma];
      if (existing != null && !_sameStringList(existing, forms)) {
        throw PhraseTemplateStoreException(
          'Conflicting synonym lists for lemma "$lemma"',
          path: sourcePath,
          field: 'words.$lemma',
        );
      }
      synonyms[lemma] = forms;
    }

    if (lemmas.isEmpty) {
      throw PhraseTemplateStoreException(
        'Word set category "$category" has no words',
        path: sourcePath,
        field: 'words',
      );
    }

    categories[category] = lemmas;
  }

  static void _mergeTemplateGroup(
    Map<String, dynamic> json, {
    required String sourcePath,
    required Set<String> knownCategories,
    required List<PhraseTemplate> templates,
    required Set<String> templateIds,
  }) {
    final rawTemplates = json['templates'];
    if (rawTemplates is! List) {
      throw PhraseTemplateStoreException(
        'Template group missing templates array',
        path: sourcePath,
        field: 'templates',
      );
    }

    for (final raw in rawTemplates) {
      if (raw is! Map) {
        throw PhraseTemplateStoreException(
          'Invalid template entry',
          path: sourcePath,
          field: 'templates',
        );
      }

      final map = Map<String, dynamic>.from(raw);
      final id = map['id'];
      final template = map['template'];
      final slotCategoriesRaw = map['slotCategories'];

      if (id is! String || id.isEmpty) {
        throw PhraseTemplateStoreException(
          'Template missing non-empty id',
          path: sourcePath,
          field: 'templates.id',
        );
      }
      if (template is! String || template.isEmpty) {
        throw PhraseTemplateStoreException(
          'Template "$id" missing non-empty template string',
          path: sourcePath,
          field: 'templates.template',
        );
      }
      if (slotCategoriesRaw is! Map) {
        throw PhraseTemplateStoreException(
          'Template "$id" missing slotCategories map',
          path: sourcePath,
          field: 'templates.slotCategories',
        );
      }

      if (!templateIds.add(id)) {
        throw PhraseTemplateStoreException(
          'Duplicate template id "$id"',
          path: sourcePath,
          field: 'templates.id',
        );
      }

      final slotCategories = slotCategoriesRaw.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      );

      if (slotCategories.isEmpty) {
        throw PhraseTemplateStoreException(
          'Template "$id" must declare at least one slot category',
          path: sourcePath,
          field: 'templates.slotCategories',
        );
      }

      for (final entry in slotCategories.entries) {
        if (!knownCategories.contains(entry.value)) {
          throw PhraseTemplateStoreException(
            'Template "$id" references unknown category "${entry.value}"',
            path: sourcePath,
            field: 'templates.slotCategories.${entry.key}',
          );
        }
      }

      _validateTemplatePlaceholders(
        template: template,
        templateId: id,
        slotCategories: slotCategories,
        sourcePath: sourcePath,
      );

      final structureVariants = _parseStructureVariants(
        map['structureVariants'],
        templateId: id,
        slotCategories: slotCategories,
        sourcePath: sourcePath,
      );

      for (final variant in structureVariants) {
        _validateTemplatePlaceholders(
          template: variant,
          templateId: id,
          slotCategories: slotCategories,
          sourcePath: sourcePath,
          field: 'templates.structureVariants',
        );
      }

      templates.add(
        PhraseTemplate(
          id: id,
          template: template,
          slotCategories: slotCategories,
          structureVariants: structureVariants,
        ),
      );
    }
  }

  static List<String> _parseStructureVariants(
    Object? raw, {
    required String templateId,
    required Map<String, String> slotCategories,
    required String sourcePath,
  }) {
    if (raw == null) {
      return const [];
    }
    if (raw is! List) {
      throw PhraseTemplateStoreException(
        'Template "$templateId" structureVariants must be a JSON array',
        path: sourcePath,
        field: 'templates.structureVariants',
      );
    }

    final variants = <String>[];
    for (final item in raw) {
      if (item is! String || item.isEmpty) {
        throw PhraseTemplateStoreException(
          'Template "$templateId" structureVariants must contain non-empty strings',
          path: sourcePath,
          field: 'templates.structureVariants',
        );
      }
      variants.add(item);
    }
    return variants;
  }

  static void _validateTemplatePlaceholders({
    required String template,
    required String templateId,
    required Map<String, String> slotCategories,
    required String sourcePath,
    String field = 'templates.template',
  }) {
    final placeholders = _extractPlaceholders(template);
    final slots = slotCategories.keys.map((key) => key.toString()).toSet();

    final missing = slots.difference(placeholders);
    final extra = placeholders.difference(slots);
    if (missing.isNotEmpty || extra.isNotEmpty) {
      final details = <String>[];
      if (missing.isNotEmpty) {
        details.add('missing placeholders: ${missing.join(', ')}');
      }
      if (extra.isNotEmpty) {
        details.add('extra placeholders: ${extra.join(', ')}');
      }
      throw PhraseTemplateStoreException(
        'Template "$templateId" slotCategories do not match template '
        'placeholders (${details.join('; ')})',
        path: sourcePath,
        field: field,
      );
    }
  }

  static Set<String> _extractPlaceholders(String template) {
    final pattern = RegExp(r'\{([a-zA-Z_][a-zA-Z0-9_]*)\}');
    return pattern.allMatches(template).map((match) => match.group(1)!).toSet();
  }

  static List<String> _stringList(
    Object? value, {
    required String field,
    required String path,
  }) {
    if (value is! List) {
      throw PhraseTemplateStoreException(
        'Expected JSON array for $field',
        path: path,
        field: field,
      );
    }
    return value.map((item) => item.toString()).toList();
  }

  static bool _sameStringList(List<String> a, List<String> b) {
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }
}
