import '../model/dataset_entry.dart';
import '../model/dataset_entry_type.dart';
import '../source/dataset_source.dart';
import 'dataset_generator.dart';
import 'generator_helpers.dart';

/// Emits a plain-text completion entry from the document content.
class TextGenerator implements DatasetGenerator {
  /// Creates a text generator.
  TextGenerator(this.config);

  /// Shared generator configuration.
  final GeneratorConfig config;

  @override
  Stream<DatasetEntry> generate(DatasetSourceDocument document) async* {
    yield buildCanonicalEntry(
      config: config,
      document: document,
      generatorName: 'TextGenerator',
      type: DatasetEntryType.text,
      input: document.content,
      output: null,
    );
  }
}

/// Emits a simple question/answer pair derived from the document.
class QuestionAnswerGenerator implements DatasetGenerator {
  /// Creates a Q&A generator.
  QuestionAnswerGenerator(this.config);

  /// Shared generator configuration.
  final GeneratorConfig config;

  @override
  Stream<DatasetEntry> generate(DatasetSourceDocument document) async* {
    final sentence = firstSentence(document.content);
    final title = document.title;
    final question = title == null || title.isEmpty
        ? 'What does the following text discuss?\n\n$sentence'
        : 'What is "$title" about based on this text?\n\n$sentence';
    yield buildCanonicalEntry(
      config: config,
      document: document,
      generatorName: 'QuestionAnswerGenerator',
      type: DatasetEntryType.text,
      input: question,
      output: clip(document.content, 500),
    );
  }
}

/// Emits a summarization example from the document.
class SummarizationGenerator implements DatasetGenerator {
  /// Creates a summarization generator.
  SummarizationGenerator(this.config);

  /// Shared generator configuration.
  final GeneratorConfig config;

  @override
  Stream<DatasetEntry> generate(DatasetSourceDocument document) async* {
    yield buildCanonicalEntry(
      config: config,
      document: document,
      generatorName: 'SummarizationGenerator',
      type: DatasetEntryType.summarization,
      input: 'Summarize the following text:\n\n${document.content}',
      output: firstSentence(document.content),
    );
  }
}

/// Emits a translation-style example (source language → target label).
class TranslationGenerator implements DatasetGenerator {
  /// Creates a translation generator.
  ///
  /// [targetLanguage] is recorded on the entry language field and prompt; the
  /// built-in implementation does not call a translation model.
  TranslationGenerator(this.config, {this.targetLanguage = 'en'});

  /// Shared generator configuration.
  final GeneratorConfig config;

  /// Target language code for the synthetic prompt.
  final String targetLanguage;

  @override
  Stream<DatasetEntry> generate(DatasetSourceDocument document) async* {
    final sourceLang = document.language ?? config.language;
    yield buildCanonicalEntry(
      config: config,
      document: document,
      generatorName: 'TranslationGenerator',
      type: DatasetEntryType.translation,
      input:
          'Translate the following text from $sourceLang to $targetLanguage:\n\n'
          '${document.content}',
      output: document.content,
      extraMetadata: {
        'sourceLanguage': sourceLang,
        'targetLanguage': targetLanguage,
      },
    );
  }
}

/// Emits a classification example with an optional label from metadata.
class ClassificationGenerator implements DatasetGenerator {
  /// Creates a classification generator.
  ClassificationGenerator(
    this.config, {
    this.labelMetadataKey = 'label',
    this.defaultLabel = 'unlabeled',
  });

  /// Shared generator configuration.
  final GeneratorConfig config;

  /// Metadata key read from the document for the label.
  final String labelMetadataKey;

  /// Fallback label when metadata is missing.
  final String defaultLabel;

  @override
  Stream<DatasetEntry> generate(DatasetSourceDocument document) async* {
    final label =
        document.metadata[labelMetadataKey]?.toString() ?? defaultLabel;
    yield buildCanonicalEntry(
      config: config,
      document: document,
      generatorName: 'ClassificationGenerator',
      type: DatasetEntryType.classification,
      input: 'Classify the following text:\n\n${document.content}',
      output: label,
      extraMetadata: {'label': label},
    );
  }
}

/// Emits an extraction example targeting structured fields.
class ExtractionGenerator implements DatasetGenerator {
  /// Creates an extraction generator.
  ExtractionGenerator(
    this.config, {
    this.fields = const ['title', 'key_points'],
  });

  /// Shared generator configuration.
  final GeneratorConfig config;

  /// Field names requested in the extraction prompt.
  final List<String> fields;

  @override
  Stream<DatasetEntry> generate(DatasetSourceDocument document) async* {
    final fieldList = fields.join(', ');
    final title = document.title ?? firstSentence(document.content);
    yield buildCanonicalEntry(
      config: config,
      document: document,
      generatorName: 'ExtractionGenerator',
      type: DatasetEntryType.extraction,
      input:
          'Extract the following fields ($fieldList) from the text:\n\n'
          '${document.content}',
      output: '{"title":${_jsonString(title)},"key_points":[]}',
      extraMetadata: {'fields': fields},
    );
  }
}

String _jsonString(String value) => '"${value.replaceAll('"', r'\"')}"';

/// Emits a tool-calling dialogue skeleton from the document.
class ToolCallGenerator implements DatasetGenerator {
  /// Creates a tool-call generator.
  ToolCallGenerator(this.config, {this.toolName = 'lookup'});

  /// Shared generator configuration.
  final GeneratorConfig config;

  /// Synthetic tool name embedded in the messages metadata.
  final String toolName;

  @override
  Stream<DatasetEntry> generate(DatasetSourceDocument document) async* {
    final query = firstSentence(document.content);
    yield buildCanonicalEntry(
      config: config,
      document: document,
      generatorName: 'ToolCallGenerator',
      type: DatasetEntryType.toolCall,
      input: query,
      output: clip(document.content, 240),
      extraMetadata: {
        'messages': [
          {'role': 'user', 'content': query},
          {
            'role': 'assistant',
            'content': null,
            'tool_calls': [
              {
                'name': toolName,
                'arguments': {'q': query},
              },
            ],
          },
          {
            'role': 'tool',
            'tool_call_id': 'call_1',
            'content': clip(document.content, 240),
          },
          {'role': 'assistant', 'content': clip(document.content, 240)},
        ],
      },
    );
  }
}
