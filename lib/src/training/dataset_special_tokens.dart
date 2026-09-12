/// The target model's special tokens, as plain strings.
///
/// This package never tokenizes — it has no tokenizer and no opinion about one
/// — so these are the literal markers your model's vocabulary uses, and any
/// tokenizer's markers work. A GPT-2-family model passes `'<|endoftext|>'`, a
/// Llama-family one `'</s>'`, a byte-level toy vocabulary whatever it reserved.
/// The strings are written into the rendered text and tokenized by whoever is
/// training, not here.
///
/// Applied at **read** time by [DatasetTextFormatter], never at generation:
/// stored entries keep neutral `input` / `output`, so one dataset renders for a
/// ChatML model and a plain base model without being regenerated. A store whose
/// entries already carried `<|im_end|>` would be a store that could only ever
/// train one family of model.
class DatasetSpecialTokens {
  /// Prepended to every rendered example, or null for none.
  ///
  /// Llama-family corpora wrap each document as `<s>…</s>`, and a model trained
  /// that way expects a BOS at inference too — prompt it without one and it is
  /// in a state it never saw. Set this to match whatever the target model's
  /// vocabulary reserves, and prompt with the same marker.
  ///
  /// Null for models that use only a terminator, GPT-2-style. The one thing not
  /// to do is set it here *and* let your tokenizer add its own: a doubled BOS is
  /// a token sequence that occurs nowhere in the corpus the model was
  /// pretrained on. [DatasetTextFormatter] guards against the half of that it
  /// can see — it does not prepend when the body already starts with the marker
  /// — but a tokenizer's `addBos` flag is beyond its reach.
  final String? bos;

  /// Appended to every rendered example — **the terminator**.
  ///
  /// The one field most callers set. It is what gives the model somewhere to
  /// stop: without it, examples run together in the packed stream, generation
  /// has no learnable end, and a sampler runs until it hits its token budget.
  final String? eos;

  /// Written before [DatasetEntry.input].
  final String inputPrefix;

  /// Written between the input and [DatasetEntry.output].
  ///
  /// Defaults to a newline, which is the minimum structure that lets a model
  /// tell a question from its answer.
  final String outputPrefix;

  /// Wraps [DatasetEntry.thinking] when present, for reasoning entries.
  ///
  /// Both must be set for thinking to be rendered; a trace with no delimiters
  /// would be indistinguishable from the answer.
  final String? thinkingOpen;

  /// Closes [thinkingOpen]. See its documentation.
  final String? thinkingClose;

  /// Written before each chat turn's content, keyed by role.
  ///
  /// Roles are the ones [datasetMessagesMetadataKey] uses — `user`,
  /// `assistant`, `tool`. A role with no entry here falls back to
  /// `'<role>: '`, so an unfamiliar role degrades to something readable rather
  /// than vanishing.
  final Map<String, String> rolePrefixes;

  /// Written after each chat turn's content.
  final String turnSuffix;

  const DatasetSpecialTokens({
    this.bos,
    this.eos,
    this.inputPrefix = '',
    this.outputPrefix = '\n',
    this.thinkingOpen,
    this.thinkingClose,
    this.rolePrefixes = const {},
    this.turnSuffix = '\n',
  });

  /// No special tokens at all: examples separated by a blank line.
  ///
  /// The honest fallback for a model whose vocabulary has no reserved markers.
  /// A blank line is weaker than a real terminator — it occurs inside ordinary
  /// prose too, so the model cannot rely on it — but it is visible, it is
  /// learnable, and it does not require inventing a token the tokenizer would
  /// then split into pieces.
  factory DatasetSpecialTokens.plain() => const DatasetSpecialTokens(eos: '\n');

  /// The ChatML markers used by Qwen, and by OpenAI-style chat fine-tunes.
  ///
  /// The turn machinery lives in [rolePrefixes] and [turnSuffix] only;
  /// [inputPrefix] and [outputPrefix] stay neutral. Pair up with
  /// `DatasetPairRendering.chatTurns` to render generated question/answer
  /// entries as turns — putting `'<|im_start|>user\n'` in [inputPrefix]
  /// instead would emit a turn opener with no matching close for every entry
  /// that is not a pair.
  factory DatasetSpecialTokens.chatMl() => const DatasetSpecialTokens(
    eos: '<|im_end|>',
    rolePrefixes: {
      'user': '<|im_start|>user\n',
      'assistant': '<|im_start|>assistant\n',
      'system': '<|im_start|>system\n',
      'tool': '<|im_start|>tool\n',
    },
    turnSuffix: '<|im_end|>\n',
  );

  /// Returns a copy with selected fields replaced.
  DatasetSpecialTokens copyWith({
    String? bos,
    String? eos,
    String? inputPrefix,
    String? outputPrefix,
    String? thinkingOpen,
    String? thinkingClose,
    Map<String, String>? rolePrefixes,
    String? turnSuffix,
    bool clearBos = false,
    bool clearEos = false,
  }) => DatasetSpecialTokens(
    bos: clearBos ? null : (bos ?? this.bos),
    eos: clearEos ? null : (eos ?? this.eos),
    inputPrefix: inputPrefix ?? this.inputPrefix,
    outputPrefix: outputPrefix ?? this.outputPrefix,
    thinkingOpen: thinkingOpen ?? this.thinkingOpen,
    thinkingClose: thinkingClose ?? this.thinkingClose,
    rolePrefixes: rolePrefixes ?? this.rolePrefixes,
    turnSuffix: turnSuffix ?? this.turnSuffix,
  );

  @override
  String toString() =>
      'DatasetSpecialTokens(bos: ${_q(bos)}, eos: ${_q(eos)}, '
      'inputPrefix: ${_q(inputPrefix)}, outputPrefix: ${_q(outputPrefix)})';

  static String _q(String? s) => s == null
      ? 'null'
      : '"${s.replaceAll('\n', '\\n').replaceAll('\t', '\\t')}"';
}
