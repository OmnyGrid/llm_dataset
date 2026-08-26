import 'package:llm_dataset/llm_dataset.dart';
import 'package:test/test.dart';

void main() {
  final doc = DatasetSourceDocument(
    id: 'doc-1',
    content: 'Paris is the capital of France. It is historic.',
    title: 'France',
    language: 'en',
    metadata: {'label': 'geo'},
  );

  final config = GeneratorConfig(
    dataset: 'general',
    datasetVersion: 'v1',
    language: 'en',
    pipelineVersion: 'p1',
    seed: 99,
  );

  Future<DatasetEntry> first(DatasetGenerator g) => g.generate(doc).first;

  test('TextGenerator emits canonical text entry', () async {
    final entry = await first(TextGenerator(config));
    expect(entry.isCanonical, isTrue);
    expect(entry.type, DatasetEntryType.text);
    expect(entry.input, doc.content);
    expect(entry.provenance?.generator, 'TextGenerator');
    expect(entry.provenance?.pipelineVersion, 'p1');
    expect(entry.variationIndex, 0);
  });

  test('QuestionAnswerGenerator produces Q/A', () async {
    final entry = await first(QuestionAnswerGenerator(config));
    expect(entry.input, contains('France'));
    expect(entry.output, isNotNull);
    expect(entry.isCanonical, isTrue);
  });

  test('SummarizationGenerator', () async {
    final entry = await first(SummarizationGenerator(config));
    expect(entry.type, DatasetEntryType.summarization);
    expect(entry.output, contains('Paris'));
  });

  test('TranslationGenerator', () async {
    final entry = await first(
      TranslationGenerator(config, targetLanguage: 'es'),
    );
    expect(entry.type, DatasetEntryType.translation);
    expect(entry.metadata['targetLanguage'], 'es');
  });

  test('ClassificationGenerator uses label metadata', () async {
    final entry = await first(ClassificationGenerator(config));
    expect(entry.type, DatasetEntryType.classification);
    expect(entry.output, 'geo');
  });

  test('ExtractionGenerator', () async {
    final entry = await first(ExtractionGenerator(config));
    expect(entry.type, DatasetEntryType.extraction);
    expect(entry.output, contains('title'));
  });

  test('ToolCallGenerator embeds tool calls', () async {
    final entry = await first(ToolCallGenerator(config));
    expect(entry.type, DatasetEntryType.toolCall);
    expect(entry.toolCalls, isNotEmpty);
    expect(entry.messages.length, greaterThanOrEqualTo(3));
  });

  test('seeded generators are deterministic', () async {
    final a = await first(TextGenerator(config));
    final b = await first(TextGenerator(config));
    expect(a.id, b.id);
    expect(a.variationGroup, b.variationGroup);
    expect(a.createdAt, b.createdAt);
  });
}
