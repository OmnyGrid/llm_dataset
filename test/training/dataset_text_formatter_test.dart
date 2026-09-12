import 'package:llm_dataset/llm_dataset.dart';
import 'package:test/test.dart';

/// A formatter whose corpus uses `TODO` to mean "not answered yet".
class _NoPlaceholders extends DatasetTextFormatter {
  const _NoPlaceholders(DatasetSpecialTokens tokens)
    : super.of(tokens: tokens, pairRendering: DatasetPairRendering.chatTurns);

  @override
  bool isPair(String input, String? output) =>
      super.isPair(input, output) && output != 'TODO';
}

/// A formatter for a corpus where an echoed answer is meaningful.
class _EchoIsAPair extends DatasetTextFormatter {
  const _EchoIsAPair(DatasetSpecialTokens tokens)
    : super.of(tokens: tokens, pairRendering: DatasetPairRendering.chatTurns);

  @override
  bool isPair(String input, String? output) =>
      output != null && output.isNotEmpty;
}

/// Rendering entries into the text a trainer packs.
///
/// The property that matters is that the stored entry is untouched: the same
/// records render for a plain base model and for a ChatML one, because the
/// special tokens are supplied at read time rather than baked in at generation.
void main() {
  DatasetEntry entry({
    DatasetEntryType type = DatasetEntryType.text,
    String input = 'What is 2 + 3?',
    String? output = '5',
    String? thinking,
    Map<String, dynamic> metadata = const {},
  }) => DatasetEntry(
    id: 'e1',
    dataset: 'd',
    type: type,
    language: 'en',
    input: input,
    output: output,
    thinking: thinking,
    metadata: metadata,
    variationGroup: 'g',
    variationIndex: 0,
    createdAt: DateTime.utc(2024, 1, 1),
  );

  group('the terminator', () {
    test('is appended to every example', () {
      final f = DatasetTextFormatter(
        const DatasetSpecialTokens(eos: '<|endoftext|>'),
      );
      expect(f.format(entry()), 'What is 2 + 3?\n5<|endoftext|>');
    });

    test('is the only thing separating packed examples', () {
      // The defect this whole API exists for: without a terminator, examples
      // run together and the model has no learnable end.
      const none = DatasetSpecialTokens(inputPrefix: '', outputPrefix: '\n');
      final packed = [
        DatasetTextFormatter(none).format(entry(input: 'a', output: null)),
        DatasetTextFormatter(none).format(entry(input: 'b', output: null)),
      ].join();
      expect(packed, 'ab');

      const withEos = DatasetSpecialTokens(eos: '<|end|>');
      final terminated = [
        DatasetTextFormatter(withEos).format(entry(input: 'a', output: null)),
        DatasetTextFormatter(withEos).format(entry(input: 'b', output: null)),
      ].join();
      expect(terminated, 'a<|end|>b<|end|>');
    });

    test('a bos is prepended when set', () {
      final f = DatasetTextFormatter(
        const DatasetSpecialTokens(bos: '<s>', eos: '</s>'),
      );
      expect(f.format(entry(input: 'x', output: null)), '<s>x</s>');
    });

    test('every example in a packed stream carries its own bos', () {
      // Llama-style `<s>…</s>` per document. The model is trained to expect a
      // BOS, so it has to be on every example, not just the first.
      const wrapped = DatasetSpecialTokens(bos: '<s>', eos: '</s>');
      final packed = [
        DatasetTextFormatter(wrapped).format(entry(input: 'a', output: null)),
        DatasetTextFormatter(wrapped).format(entry(input: 'b', output: null)),
      ].join();
      expect(packed, '<s>a</s><s>b</s>');
    });

    test('a bos is not doubled when the body already opens with it', () {
      // The mirror of the terminator rule: a doubled BOS is a token sequence
      // that occurs nowhere in the corpus the model was pretrained on.
      final f = DatasetTextFormatter(
        const DatasetSpecialTokens(bos: '<s>', eos: '</s>', inputPrefix: '<s>'),
      );
      expect(f.format(entry(input: 'x', output: null)), '<s>x</s>');
    });

    test('bos and eos can both be set on chat turns', () {
      final f = DatasetTextFormatter.chatTurns(
        DatasetSpecialTokens.chatMl().copyWith(bos: '<s>'),
      );
      final text = f.format(entry(input: 'q', output: 'a'));
      expect(text, startsWith('<s><|im_start|>user\n'));
      expect(text, endsWith('<|im_end|>\n'));
    });
  });

  group('input and output', () {
    test('are joined by the output prefix', () {
      // No `eos` here, so nothing is appended: the terminator is opt-in, and a
      // caller that does not name one gets exactly the text of the entry.
      final f = DatasetTextFormatter(
        const DatasetSpecialTokens(outputPrefix: ' -> '),
      );
      expect(f.format(entry()), 'What is 2 + 3? -> 5');
    });

    test('an absent output renders the input alone', () {
      final f = DatasetTextFormatter(const DatasetSpecialTokens(eos: '|'));
      expect(
        f.format(entry(input: 'The kitten.', output: null)),
        'The kitten.|',
      );
    });

    test('an output equal to the input is not repeated', () {
      // The plain-text generators emit the sentence as both fields because
      // there is nothing to answer. Rendering the pair naively would train the
      // model that every sentence immediately follows itself.
      final f = DatasetTextFormatter(const DatasetSpecialTokens(eos: '|'));
      expect(
        f.format(entry(input: 'The kitten.', output: 'The kitten.')),
        'The kitten.|',
      );
    });

    test('an empty output is treated as absent', () {
      final f = DatasetTextFormatter(const DatasetSpecialTokens(eos: '|'));
      expect(f.format(entry(input: 'x', output: '')), 'x|');
    });
  });

  group('chat entries', () {
    final messages = [
      {'role': 'user', 'content': 'hi'},
      {'role': 'assistant', 'content': 'hello'},
    ];

    test('render their turns with role prefixes', () {
      final f = DatasetTextFormatter(DatasetSpecialTokens.chatMl());
      final text = f.format(
        entry(
          type: DatasetEntryType.chat,
          metadata: {datasetMessagesMetadataKey: messages},
        ),
      );
      // No trailing `<|im_end|>` beyond the last turn's own: in ChatML the turn
      // suffix *is* the terminator, and appending eos on top of it would put a
      // marker in the corpus that never occurs in real ChatML.
      expect(
        text,
        '<|im_start|>user\nhi<|im_end|>\n'
        '<|im_start|>assistant\nhello<|im_end|>\n',
      );
    });

    test(
      'a terminator that differs from the turn suffix is still appended',
      () {
        // The packing case: ChatML turns inside a document, documents separated
        // by <|endoftext|>. Only an exact duplicate is suppressed.
        final f = DatasetTextFormatter(
          DatasetSpecialTokens.chatMl().copyWith(eos: '<|endoftext|>'),
        );
        final text = f.format(
          entry(
            type: DatasetEntryType.chat,
            metadata: {datasetMessagesMetadataKey: messages},
          ),
        );
        expect(text, endsWith('<|im_end|>\n<|endoftext|>'));
      },
    );

    test('an unknown role falls back to a readable prefix', () {
      final f = DatasetTextFormatter(
        const DatasetSpecialTokens(turnSuffix: ''),
      );
      final text = f.format(
        entry(
          type: DatasetEntryType.chat,
          metadata: {
            datasetMessagesMetadataKey: [
              {'role': 'critic', 'content': 'no'},
            ],
          },
        ),
      );
      expect(text, 'critic: no');
    });

    test('a turn with no content still marks its role', () {
      // An assistant turn that is purely tool calls. The shape of the
      // conversation has to survive even though this renderer says nothing
      // about the calls themselves.
      final f = DatasetTextFormatter(
        const DatasetSpecialTokens(turnSuffix: ''),
      );
      final text = f.format(
        entry(
          type: DatasetEntryType.toolCall,
          metadata: {
            datasetMessagesMetadataKey: [
              {'role': 'assistant'},
            ],
          },
        ),
      );
      expect(text, 'assistant: ');
    });

    test('a chat entry with no turns falls back to input/output', () {
      final f = DatasetTextFormatter(const DatasetSpecialTokens(eos: '|'));
      expect(
        f.format(entry(type: DatasetEntryType.chat, input: 'q', output: 'a')),
        'q\na|',
      );
    });

    test('turns are ignored for a non-conversational type', () {
      // `messages` is a metadata convention, not a type. A text entry that
      // happens to carry turns is still a text entry.
      final f = DatasetTextFormatter(const DatasetSpecialTokens(eos: '|'));
      expect(
        f.format(entry(metadata: {datasetMessagesMetadataKey: messages})),
        'What is 2 + 3?\n5|',
      );
    });
  });

  group('pairs rendered as chat turns', () {
    DatasetTextFormatter chatTurns([DatasetSpecialTokens? tokens]) =>
        DatasetTextFormatter.chatTurns(tokens ?? DatasetSpecialTokens.chatMl());

    test('a question and answer become a user turn and an assistant turn', () {
      expect(
        chatTurns().format(entry()),
        '<|im_start|>user\nWhat is 2 + 3?<|im_end|>\n'
        '<|im_start|>assistant\n5<|im_end|>\n',
      );
    });

    test(
      'a promoted pair is byte-identical to the same stored conversation',
      () {
        // The property that matters: a corpus mixing generated Q&A with real
        // multi-turn data must not be distinguishable to the model by format.
        final promoted = chatTurns().format(
          entry(input: 'hi', output: 'hello'),
        );
        final stored = chatTurns().format(
          entry(
            type: DatasetEntryType.chat,
            metadata: {
              datasetMessagesMetadataKey: [
                {'role': 'user', 'content': 'hi'},
                {'role': 'assistant', 'content': 'hello'},
              ],
            },
          ),
        );
        expect(promoted, stored);
      },
    );

    test('an entry that is not a pair stays a completion', () {
      // `output == input`: there is no question, so there is no turn to make.
      // Promoting it would train the model that a user statement means the
      // assistant repeats it back.
      expect(
        chatTurns().format(entry(input: 'The kitten.', output: 'The kitten.')),
        'The kitten.<|im_end|>',
      );
    });

    test('an entry with no output at all stays a completion', () {
      expect(
        chatTurns().format(entry(input: 'The kitten.', output: null)),
        'The kitten.<|im_end|>',
      );
    });

    test('completion is the default, so existing callers are unchanged', () {
      final f = DatasetTextFormatter(DatasetSpecialTokens.chatMl());
      expect(f.format(entry()), isNot(contains('<|im_start|>')));
    });

    test('roles are configurable for ShareGPT-style corpora', () {
      const f = DatasetTextFormatter.chatTurns(
        DatasetSpecialTokens(turnSuffix: '\n'),
        inputRole: 'human',
        outputRole: 'gpt',
      );
      expect(f.format(entry(input: 'q', output: 'a')), 'human: q\ngpt: a\n');
    });

    test('a stored conversation is unaffected by the pair setting', () {
      final messages = [
        {'role': 'user', 'content': 'hi'},
      ];
      final chatEntry = entry(
        type: DatasetEntryType.chat,
        metadata: {datasetMessagesMetadataKey: messages},
      );
      expect(
        chatTurns().format(chatEntry),
        DatasetTextFormatter(DatasetSpecialTokens.chatMl()).format(chatEntry),
      );
    });
  });

  group('isPair is a subclass hook', () {
    test('narrowing it demotes an entry to a completion', () {
      // A corpus where a placeholder answer means "not answered yet". The
      // default cannot know that; a subclass can.
      const f = _NoPlaceholders(DatasetSpecialTokens(turnSuffix: '\n'));
      expect(f.format(entry(input: 'q', output: 'TODO')), 'q');
      expect(
        f.format(entry(input: 'q', output: 'a')),
        'user: q\nassistant: a\n',
      );
    });

    test('widening it promotes one the default would skip', () {
      const f = _EchoIsAPair(DatasetSpecialTokens(turnSuffix: '\n'));
      expect(
        f.format(entry(input: 'same', output: 'same')),
        'user: same\nassistant: same\n',
      );
    });
  });

  group('reasoning entries', () {
    test('wrap the trace in its delimiters', () {
      final f = DatasetTextFormatter(
        const DatasetSpecialTokens(
          eos: '|',
          thinkingOpen: '<think>',
          thinkingClose: '</think>',
        ),
      );
      final text = f.format(
        entry(
          type: DatasetEntryType.reasoning,
          input: 'q',
          output: 'a',
          thinking: 'because',
        ),
      );
      expect(text, 'q\n<think>because</think>a|');
    });

    test('drop the trace when there are no delimiters for it', () {
      // Rendering it undelimited would train the model to think out loud where
      // it was supposed to answer.
      final f = DatasetTextFormatter(const DatasetSpecialTokens(eos: '|'));
      final text = f.format(
        entry(
          type: DatasetEntryType.reasoning,
          input: 'q',
          output: 'a',
          thinking: 'because',
        ),
      );
      expect(text, 'q\na|');
    });

    test('the trace goes inside the assistant turn under chatTurns', () {
      // Beside the turns rather than inside them would tell the model the trace
      // belongs to neither speaker.
      final f = DatasetTextFormatter.chatTurns(
        DatasetSpecialTokens.chatMl().copyWith(
          thinkingOpen: '<think>',
          thinkingClose: '</think>',
        ),
      );
      expect(
        f.format(
          entry(
            type: DatasetEntryType.reasoning,
            input: 'q',
            output: 'a',
            thinking: 'because',
          ),
        ),
        '<|im_start|>user\nq<|im_end|>\n'
        '<|im_start|>assistant\n<think>because</think>a<|im_end|>\n',
      );
    });

    test('a reasoning entry with no trace is just input/output', () {
      final f = DatasetTextFormatter(
        const DatasetSpecialTokens(
          eos: '|',
          thinkingOpen: '<think>',
          thinkingClose: '</think>',
        ),
      );
      expect(
        f.format(
          entry(type: DatasetEntryType.reasoning, input: 'q', output: 'a'),
        ),
        'q\na|',
      );
    });
  });

  group('presets', () {
    test('plain separates with a newline and adds no markers', () {
      final f = DatasetTextFormatter(DatasetSpecialTokens.plain());
      expect(f.format(entry()), 'What is 2 + 3?\n5\n');
    });

    test('the default formatter is the plain one', () {
      expect(
        const DatasetTextFormatter().format(entry()),
        DatasetTextFormatter(DatasetSpecialTokens.plain()).format(entry()),
      );
    });

    test('copyWith replaces a field and clears on request', () {
      const base = DatasetSpecialTokens(bos: '<s>', eos: '</s>');
      expect(base.copyWith(eos: '|').eos, '|');
      expect(base.copyWith(clearBos: true).bos, isNull);
      expect(base.copyWith(clearBos: true).eos, '</s>');
    });

    test('toString escapes newlines so it is readable in a log', () {
      expect(
        const DatasetSpecialTokens(eos: '\n').toString(),
        contains(r'eos: "\n"'),
      );
    });
  });

  group('streaming', () {
    test('formatAll renders a stream lazily, in order', () async {
      final f = DatasetTextFormatter(const DatasetSpecialTokens(eos: '|'));
      final texts = await f
          .formatAll(
            Stream.fromIterable([
              entry(input: 'a', output: null),
              entry(input: 'b', output: null),
            ]),
          )
          .toList();
      expect(texts, ['a|', 'b|']);
    });

    test('Dataset.texts applies the formatter over the query', () async {
      final store = MemoryDatasetStore();
      await store.addAll(
        Stream.fromIterable([
          entry(input: 'a', output: null),
          DatasetEntry(
            id: 'e2',
            dataset: 'd',
            type: DatasetEntryType.text,
            language: 'en',
            input: 'b',
            variationGroup: 'g2',
            variationIndex: 0,
            createdAt: DateTime.utc(2024, 1, 2),
          ),
        ]),
      );

      final texts = await Dataset(store: store)
          .texts(DatasetTextFormatter(const DatasetSpecialTokens(eos: '|')))
          .toList();
      expect(texts, ['a|', 'b|']);
    });

    test('Dataset.texts honors limit', () async {
      final store = MemoryDatasetStore();
      await store.addAll(
        Stream.fromIterable([
          for (var i = 0; i < 5; i++)
            DatasetEntry(
              id: 'e$i',
              dataset: 'd',
              type: DatasetEntryType.text,
              language: 'en',
              input: 'x$i',
              variationGroup: 'g$i',
              variationIndex: 0,
              createdAt: DateTime.utc(2024, 1, i + 1),
            ),
        ]),
      );

      final texts = await Dataset(store: store)
          .texts(
            DatasetTextFormatter(const DatasetSpecialTokens(eos: '|')),
            limit: 2,
          )
          .toList();
      expect(texts, hasLength(2));
    });
  });
}
