import '../model/dataset_entry.dart';
import '../model/dataset_entry_type.dart';
import 'dataset_special_tokens.dart';

/// How an input/output pair is written out.
enum DatasetPairRendering {
  /// `input`, the output prefix, then `output` — one continuous completion.
  ///
  /// What a base language model trains on: there are no roles, and the model
  /// learns the answer as a continuation of the question.
  completion,

  /// A user turn and an assistant turn, using the same role prefixes and turn
  /// suffix as a stored conversation.
  ///
  /// Only for entries that are genuinely a pair — a non-empty `output` that
  /// differs from the `input`. Anything else falls back to [completion], which
  /// is what keeps plain-text entries out of it: the text generators emit the
  /// sentence as both `input` and `output` because there is nothing to answer,
  /// and rendering `The kitten.` as a user turn with an assistant echoing it
  /// back would teach the model that a user statement means "repeat it".
  chatTurns,
}

/// Renders [DatasetEntry] values into the flat text a trainer packs.
///
/// The missing half of dataset consumption. [Dataset] streams *entries* —
/// structured records with an input, an output and provenance — but a language
/// model trains on a stream of *text*, and turning one into the other means
/// deciding where an example ends and what marks the boundary. That decision
/// belongs to the model being trained, not to the stored data, which is why it
/// lives here and takes a [DatasetSpecialTokens] rather than being baked in at
/// generation time.
///
/// ```dart
/// final formatter = DatasetTextFormatter(
///   const DatasetSpecialTokens(eos: '<|endoftext|>'),
/// );
/// await for (final text in dataset.texts(formatter)) {
///   // "What is 2 + 3?\n5<|endoftext|>"
/// }
/// ```
///
/// ## What each entry type renders as
///
/// * [DatasetEntryType.chat], [DatasetEntryType.agent],
///   [DatasetEntryType.toolCall] — the `messages` turns in order, each with its
///   role prefix, when the entry carries them; otherwise the input/output form
///   below, since a chat-typed entry with no turns is still a prompt and a
///   reply.
/// * [DatasetEntryType.reasoning] — input, then the thinking trace wrapped in
///   its delimiters when both the trace and the delimiters are present, then
///   the output.
/// * everything else — input, then output when there is one.
///
/// An entry whose `output` equals its `input` renders once, not twice. The
/// plain-text generators emit the sentence as both fields because there is no
/// question to answer, and rendering that pair naively trains the model that
/// every sentence occurs in immediate succession with itself.
class DatasetTextFormatter {
  /// The target model's markers.
  final DatasetSpecialTokens tokens;

  /// Whether an input/output pair becomes a completion or a pair of chat turns.
  ///
  /// [DatasetPairRendering.chatTurns] renders a promoted pair through the same
  /// path as a stored conversation, so a dataset mixing generated Q&A with real
  /// multi-turn data is not distinguishable to the model by format — which it
  /// would be if the two were written out differently.
  final DatasetPairRendering pairRendering;

  /// The role a promoted `input` is attributed to.
  ///
  /// `'human'` for ShareGPT-style corpora, whose role names differ from the
  /// ChatML ones.
  final String inputRole;

  /// The role a promoted `output` is attributed to. `'gpt'` in ShareGPT.
  final String outputRole;

  const DatasetTextFormatter([
    this.tokens = const DatasetSpecialTokens(eos: '\n'),
  ]) : pairRendering = DatasetPairRendering.completion,
       inputRole = 'user',
       outputRole = 'assistant';

  /// A formatter that renders question/answer entries as chat turns.
  ///
  /// See [DatasetPairRendering.chatTurns] for which entries qualify. [inputRole]
  /// and [outputRole] name the two speakers — `'human'` / `'gpt'` for
  /// ShareGPT-style corpora.
  const DatasetTextFormatter.chatTurns(
    this.tokens, {
    this.inputRole = 'user',
    this.outputRole = 'assistant',
  }) : pairRendering = DatasetPairRendering.chatTurns;

  /// The constructor subclasses call, with every knob explicit.
  const DatasetTextFormatter.of({
    this.tokens = const DatasetSpecialTokens(eos: '\n'),
    this.pairRendering = DatasetPairRendering.completion,
    this.inputRole = 'user',
    this.outputRole = 'assistant',
  });

  /// Renders one entry, including its [DatasetSpecialTokens.bos] and
  /// [DatasetSpecialTokens.eos].
  ///
  /// The terminator is **skipped when the body already ends with it**, so a
  /// ChatML-style [DatasetSpecialTokens.turnSuffix] that is itself the
  /// terminator does not produce `…<|im_end|>\n<|im_end|>`. A terminator that
  /// genuinely differs from the turn suffix — `<|endoftext|>` after ChatML
  /// turns, say, to separate packed documents — is still appended.
  String format(DatasetEntry entry) {
    final body = _body(entry);
    final out = StringBuffer();
    final bos = tokens.bos;
    if (bos != null && !_startsWithMarker(body, bos)) out.write(bos);
    out.write(body);
    final eos = tokens.eos;
    if (eos != null && !_endsWithTerminator(body, eos)) out.write(eos);
    return out.toString();
  }

  /// Whether [body] already opens with [bos].
  ///
  /// The mirror of [_endsWithTerminator], and there for the same reason: a
  /// rendering whose first role prefix *is* the sequence marker should not get
  /// a second one in front of it. A doubled BOS is a token sequence that occurs
  /// nowhere in the corpus the model was pretrained on.
  static bool _startsWithMarker(String body, String bos) {
    final marker = bos.trimLeft();
    if (marker.isEmpty) return false;
    return body.trimLeft().startsWith(marker);
  }

  /// Whether [body] is already terminated by [eos].
  ///
  /// Compares against the trailing non-whitespace of both: a turn suffix of
  /// `'<|im_end|>\n'` terminates a body just as `'<|im_end|>'` does, and the
  /// newline between them should not decide it. A whitespace-only terminator
  /// never suppresses — the rule is about duplicated *markers*, and treating
  /// `'\n'` as one would silently swallow a caller's blank-line separator.
  static bool _endsWithTerminator(String body, String eos) {
    final marker = eos.trimRight();
    if (marker.isEmpty) return false;
    return body.trimRight().endsWith(marker);
  }

  /// Renders a stream of entries, one string each.
  ///
  /// Lazy: entries are rendered as they arrive, so a corpus larger than memory
  /// streams through rather than being materialized.
  Stream<String> formatAll(Stream<DatasetEntry> entries) => entries.map(format);

  String _body(DatasetEntry entry) {
    final messages = entry.messages;
    if (messages.isNotEmpty && _isConversational(entry.type)) {
      return _formatMessages(messages);
    }
    if (entry.type == DatasetEntryType.reasoning) {
      return _formatReasoning(entry);
    }
    return _formatPair(entry.input, entry.output);
  }

  bool _isConversational(DatasetEntryType type) =>
      type == DatasetEntryType.chat ||
      type == DatasetEntryType.agent ||
      type == DatasetEntryType.toolCall;

  String _formatMessages(List<Map<String, dynamic>> messages) {
    final out = StringBuffer();
    for (final message in messages) {
      final role = '${message['role'] ?? 'user'}';
      final content = message['content'];
      // A turn may legitimately have no content — an assistant turn that is
      // purely tool calls. Its role prefix still marks the turn, so the shape
      // of the conversation survives even when this renderer has nothing to
      // say about the calls themselves.
      out
        ..write(tokens.rolePrefixes[role] ?? '$role: ')
        ..write(content == null ? '' : '$content')
        ..write(tokens.turnSuffix);
    }
    return out.toString();
  }

  String _formatReasoning(DatasetEntry entry) {
    final thinking = entry.thinking;
    final open = tokens.thinkingOpen;
    final close = tokens.thinkingClose;
    if (thinking == null || thinking.isEmpty || open == null || close == null) {
      // No trace, or no delimiters to distinguish it from the answer. Dropping
      // it is the safe failure: a trace rendered without delimiters would be
      // trained as part of the answer, and the model would learn to think out
      // loud where it was supposed to reply.
      return _formatPair(entry.input, entry.output);
    }
    final answer = '$open$thinking$close${entry.output ?? ''}';
    if (pairRendering == DatasetPairRendering.chatTurns) {
      // The trace goes *inside* the assistant turn, not beside it: it is
      // something the assistant produced, and a turn structure that put it
      // outside would tell the model it belongs to neither speaker.
      return _asTurns(entry.input, answer);
    }
    final out = StringBuffer()
      ..write(tokens.inputPrefix)
      ..write(entry.input)
      ..write(tokens.outputPrefix)
      ..write(answer);
    return out.toString();
  }

  /// Whether [input] / [output] form a real question-and-answer pair.
  ///
  /// The one decision that governs both rendering modes: a pair gets an output
  /// prefix and, under [DatasetPairRendering.chatTurns], becomes two turns;
  /// anything else renders as the input alone.
  ///
  /// The default is deliberately conservative — a non-empty `output` that
  /// differs from the `input`. `output == input` for the plain-text kinds,
  /// which emit the sentence as both fields because there is nothing to answer.
  ///
  /// **Override it to teach the formatter about your own data.** A corpus whose
  /// generators mark unanswered entries some other way, or one where an echoed
  /// answer is meaningful, is a subclass rather than a fork:
  ///
  /// ```dart
  /// class MyFormatter extends DatasetTextFormatter {
  ///   const MyFormatter(DatasetSpecialTokens tokens)
  ///       : super.of(tokens: tokens, pairRendering: /* … */);
  ///
  ///   @override
  ///   bool isPair(String input, String? output) =>
  ///       super.isPair(input, output) && !output!.startsWith('TODO');
  /// }
  /// ```
  ///
  /// Called more than once per entry, so keep it cheap and free of side
  /// effects.
  bool isPair(String input, String? output) =>
      output != null && output.isNotEmpty && output != input;

  String _formatPair(String input, String? output) {
    final pair = isPair(input, output);
    if (pair && pairRendering == DatasetPairRendering.chatTurns) {
      return _asTurns(input, output!);
    }
    final out = StringBuffer()
      ..write(tokens.inputPrefix)
      ..write(input);
    if (pair) {
      out
        ..write(tokens.outputPrefix)
        ..write(output);
    }
    return out.toString();
  }

  /// A promoted pair, rendered through the stored-conversation path.
  String _asTurns(String input, String output) => _formatMessages([
    {'role': inputRole, 'content': input},
    {'role': outputRole, 'content': output},
  ]);
}
