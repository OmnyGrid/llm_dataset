import '../model/dataset_entry.dart';
import '../model/dataset_entry_type.dart';
import '../model/dataset_provenance.dart';
import '../util/ids.dart';
import 'dataset_variation_generator.dart';
import 'variation_generate_options.dart';

/// Translates text from a source language into a [targetLanguage].
typedef TranslateTextFn = Future<String> Function(
  String text, {
  required String sourceLanguage,
  required String targetLanguage,
});

/// Base class for translation [DatasetVariationGenerator] implementations.
///
/// Translates [DatasetEntry.input], [DatasetEntry.output], and
/// [DatasetEntry.thinking] while preserving [DatasetEntry.variationGroup],
/// assigning [DatasetEntry.variationIndex], and linking
/// [DatasetProvenance.parentEntryId].
abstract base class TranslationVariationGenerator
    implements DatasetVariationGenerator {
  /// Creates a translation variation generator for [targetLanguage].
  const TranslationVariationGenerator({
    required this.targetLanguage,
    this.generatorVersion = '1.0.0',
    this.instanceId,
    this.transformation = 'translation',
    this.skipWhenSameLanguage = true,
    this.generatorName,
  });

  /// Language code written on variation entries (BCP-47 / short code).
  final String targetLanguage;

  /// Version recorded in provenance.
  final String generatorVersion;

  /// Stable id distinguishing multiple generator instances in one pipeline.
  final String? instanceId;

  /// Provenance / metadata strategy label.
  final String transformation;

  /// When true, returns no variations if [DatasetEntry.language] already equals
  /// [targetLanguage].
  final bool skipWhenSameLanguage;

  /// Provenance generator name; defaults to the runtime type name.
  final String? generatorName;

  /// Translates [text] from [sourceLanguage] to [targetLanguage].
  Future<String> translateText(
    String text, {
    required String sourceLanguage,
    required String targetLanguage,
  });

  @override
  Future<List<DatasetEntry>> generate(
    DatasetEntry entry, {
    VariationGenerateOptions options = defaultVariationGenerateOptions,
  }) async {
    if (skipWhenSameLanguage && entry.language == targetLanguage) {
      return const [];
    }

    final sourceLanguage = entry.language;
    final translatedInput = await translateText(
      entry.input,
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
    );
    final translatedOutput = entry.output == null
        ? null
        : await translateText(
            entry.output!,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage,
          );
    final translatedThinking = entry.thinking == null
        ? null
        : await translateText(
            entry.thinking!,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage,
          );

    return [
      buildTranslationVariation(
        entry,
        options: options,
        translatedInput: translatedInput,
        translatedOutput: translatedOutput,
        translatedThinking: translatedThinking,
      ),
    ];
  }

  /// Builds the variation entry after text fields are translated.
  ///
  /// Subclasses may override to adjust metadata, type, or provenance.
  DatasetEntry buildTranslationVariation(
    DatasetEntry entry, {
    required VariationGenerateOptions options,
    required String translatedInput,
    required String? translatedOutput,
    required String? translatedThinking,
  }) {
    final variationIndex = options.startVariationIndex;
    final generatorKey = options.instanceId ?? instanceId ?? generatorVersion;
    final id = stableDatasetId([
      entry.variationGroup,
      variationIndex,
      transformation,
      targetLanguage,
      generatorKey,
    ]);

    return entry.copyWith(
      id: id,
      type: _variationType(entry.type),
      language: targetLanguage,
      input: translatedInput,
      output: translatedOutput,
      thinking: translatedThinking,
      variationIndex: variationIndex,
      metadata: {
        ...entry.metadata,
        'variationStrategy': transformation,
        'sourceLanguage': entry.language,
        'targetLanguage': targetLanguage,
      },
      provenance: DatasetProvenance(
        source: entry.provenance?.source,
        sourceId: entry.provenance?.sourceId,
        sourceUri: entry.provenance?.sourceUri,
        generator: generatorName ?? runtimeType.toString(),
        generatorVersion: generatorVersion,
        transformation: transformation,
        parentEntryId: entry.id,
        pipelineVersion: entry.provenance?.pipelineVersion,
      ),
    );
  }

  DatasetEntryType _variationType(DatasetEntryType parentType) {
    if (parentType == DatasetEntryType.text ||
        parentType == DatasetEntryType.translation) {
      return DatasetEntryType.translation;
    }
    return parentType;
  }
}

/// Translation variations backed by a user-supplied [translate] callback.
base class CallbackTranslationVariationGenerator
    extends TranslationVariationGenerator {
  /// Creates a callback-based translator.
  CallbackTranslationVariationGenerator({
    required this.translate,
    required super.targetLanguage,
    super.generatorVersion,
    super.instanceId,
    super.transformation,
    super.skipWhenSameLanguage,
    super.generatorName = 'CallbackTranslationVariationGenerator',
  });

  /// User-provided translation function (HTTP, local MT, LLM, etc.).
  final TranslateTextFn translate;

  @override
  Future<String> translateText(
    String text, {
    required String sourceLanguage,
    required String targetLanguage,
  }) {
    return translate(
      text,
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
    );
  }
}

/// Deterministic stub translator for tests and offline demos.
final class RuleBasedTranslationVariationGenerator
    extends TranslationVariationGenerator {
  /// Creates a prefix-based stub translator.
  const RuleBasedTranslationVariationGenerator({
    required super.targetLanguage,
    super.generatorVersion,
    super.instanceId,
    super.skipWhenSameLanguage,
  }) : super(generatorName: 'RuleBasedTranslationVariationGenerator');

  @override
  Future<String> translateText(
    String text, {
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    return '[$targetLanguage] $text';
  }
}
