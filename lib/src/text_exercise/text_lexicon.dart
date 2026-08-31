/// Lexicon of interchangeable words for meaning-preserving text variations.
class TextLexicon {
  /// Creates a lexicon for [language].
  const TextLexicon({required this.language, required this.synonyms});

  /// Language code (`en`, `pt`, …).
  final String language;

  /// Lemma/key → surface forms (first entry is the canonical default).
  final Map<String, List<String>> synonyms;

  /// Default surface form for [key].
  String canonical(String key) {
    final forms = synonyms[key];
    if (forms == null || forms.isEmpty) {
      return key;
    }
    return forms.first;
  }

  /// All surface forms for [key], or `[key]` when unknown.
  List<String> forms(String key) {
    final list = synonyms[key];
    if (list == null || list.isEmpty) {
      return [key];
    }
    return List<String>.from(list);
  }

  /// Picks a non-[avoid] form when possible; otherwise returns [avoid].
  String alternate(String key, int index, {String? avoid}) {
    final options = forms(key);
    if (options.length == 1) {
      return options.first;
    }
    for (var i = 0; i < options.length; i++) {
      final candidate = options[(index + i) % options.length];
      if (candidate != avoid) {
        return candidate;
      }
    }
    return options[index % options.length];
  }
}

/// English lexicon for phrase/paragraph exercises.
const englishTextLexicon = TextLexicon(
  language: 'en',
  synonyms: {
    'developer': ['developer', 'engineer', 'programmer'],
    'team': ['team', 'group', 'crew'],
    'student': ['student', 'learner', 'pupil'],
    'write': ['writes', 'authors', 'drafts'],
    'read': ['reads', 'studies', 'reviews'],
    'build': ['builds', 'creates', 'constructs'],
    'ship': ['ships', 'delivers', 'releases'],
    'test': ['tests', 'checks', 'validates'],
    'code': ['code', 'software', 'program'],
    'feature': ['feature', 'capability', 'function'],
    'bug': ['bug', 'defect', 'issue'],
    'document': ['document', 'file', 'record'],
    'carefully': ['carefully', 'thoroughly', 'attentively'],
    'quickly': ['quickly', 'rapidly', 'swiftly'],
    'daily': ['daily', 'every day', 'each day'],
    'morning': ['morning', 'early hours', 'start of the day'],
    'coffee': ['coffee', 'a hot drink', 'espresso'],
    'breakfast': ['breakfast', 'the first meal', 'morning meal'],
    'work': ['work', 'job', 'tasks'],
    'exercise': ['exercise', 'training', 'practice'],
    'english': ['English', 'the English language', 'English text'],
    'sentence': ['sentence', 'line', 'phrase'],
    'paragraph': ['paragraph', 'passage', 'text block'],
  },
);

/// Portuguese lexicon for phrase/paragraph exercises.
const portugueseTextLexicon = TextLexicon(
  language: 'pt',
  synonyms: {
    'developer': ['desenvolvedor', 'engenheiro', 'programador'],
    'team': ['equipe', 'time', 'grupo'],
    'student': ['estudante', 'aluno', 'aprendiz'],
    'write': ['escreve', 'redige', 'elabora'],
    'read': ['lê', 'estuda', 'revê'],
    'build': ['constrói', 'cria', 'monta'],
    'ship': ['entrega', 'publica', 'libera'],
    'test': ['testa', 'verifica', 'valida'],
    'code': ['código', 'software', 'programa'],
    'feature': ['funcionalidade', 'recurso', 'capacidade'],
    'bug': ['bug', 'defeito', 'falha'],
    'document': ['documento', 'arquivo', 'registro'],
    'carefully': ['cuidadosamente', 'com atenção', 'detalhadamente'],
    'quickly': ['rapidamente', 'depressa', 'com agilidade'],
    'daily': ['diariamente', 'todo dia', 'cada dia'],
    'morning': ['manhã', 'início do dia', 'cedo'],
    'coffee': ['café', 'uma bebida quente', 'expresso'],
    'breakfast': ['café da manhã', 'primeira refeição', 'desjejum'],
    'work': ['trabalho', 'tarefas', 'serviço'],
    'exercise': ['exercício', 'treino', 'prática'],
    'english': ['inglês', 'língua inglesa', 'texto em inglês'],
    'sentence': ['frase', 'linha', 'enunciado'],
    'paragraph': ['parágrafo', 'passagem', 'bloco de texto'],
  },
);

/// Returns the built-in lexicon for [language], or `null` if unsupported.
TextLexicon? textLexiconForLanguage(String language) {
  switch (language) {
    case 'en':
      return englishTextLexicon;
    case 'pt':
      return portugueseTextLexicon;
    default:
      return null;
  }
}
