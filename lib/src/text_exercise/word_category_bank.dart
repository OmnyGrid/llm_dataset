/// Groups lexicon lemma keys into semantic categories for template filling.
///
/// Templates declare `{slot}` placeholders mapped to a category name.
/// At generation time one lemma is picked from that category (deterministically
/// via [pick]) and resolved to a surface form through [TextLexicon].
class WordCategoryBank {
  /// Creates a bank of category → lemma keys.
  const WordCategoryBank({required this.categories});

  /// Category name → ordered lemma keys (first is the default pick at index 0).
  final Map<String, List<String>> categories;

  /// Lemma keys registered under [category].
  List<String> words(String category) {
    final list = categories[category];
    if (list == null || list.isEmpty) {
      return const [];
    }
    return List<String>.unmodifiable(list);
  }

  /// Picks a lemma key from [category] using [index] (wraps modulo list size).
  String pick(String category, int index) {
    final list = categories[category];
    if (list == null || list.isEmpty) {
      throw ArgumentError.value(
        category,
        'category',
        'Unknown or empty word category',
      );
    }
    return list[index.abs() % list.length];
  }

  /// All category names in this bank.
  Iterable<String> get categoryNames => categories.keys;

  /// Total lemma slots across all categories.
  int get lemmaSlotCount {
    return categories.values.fold<int>(0, (sum, list) => sum + list.length);
  }

  /// Unique lemma keys across all categories.
  Set<String> get uniqueLemmas {
    return categories.values.expand((list) => list).toSet();
  }

  /// Number of unique lemma keys across all categories.
  int get uniqueLemmaCount => uniqueLemmas.length;
}

/// English word categories for phrase templates.
const englishWordCategoryBank = WordCategoryBank(
  categories: {
    'actor': ['developer', 'team', 'student'],
    'action': ['write', 'read', 'build', 'ship', 'test'],
    'thing': ['code', 'feature', 'bug', 'document'],
    'manner': ['carefully', 'quickly'],
    'time': ['morning'],
    'drink': ['coffee'],
    'meal': ['breakfast'],
    'language': ['english'],
    'text_part': ['sentence', 'paragraph'],
    'activity': ['exercise', 'work'],
  },
);

/// Portuguese word categories for phrase templates.
const portugueseWordCategoryBank = WordCategoryBank(
  categories: {
    'actor': ['developer', 'team', 'student'],
    'action': ['write', 'read', 'build', 'ship', 'test'],
    'thing': ['code', 'feature', 'bug', 'document'],
    'manner': ['carefully', 'quickly'],
    'time': ['morning'],
    'drink': ['coffee'],
    'meal': ['breakfast'],
    'language': ['english'],
    'text_part': ['sentence', 'paragraph'],
    'activity': ['exercise', 'work'],
  },
);

/// Returns the built-in category bank for [language], or `null` if unsupported.
WordCategoryBank? wordCategoryBankForLanguage(String language) {
  switch (language) {
    case 'en':
      return englishWordCategoryBank;
    case 'pt':
      return portugueseWordCategoryBank;
    default:
      return null;
  }
}
