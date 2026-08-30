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

/// Normalizes [targetLanguage] / [targetLanguages] into a non-empty language list.
List<String> normalizeTargetLanguages({
  String? targetLanguage,
  Iterable<String>? targetLanguages,
}) {
  if (targetLanguage != null && targetLanguages != null) {
    throw ArgumentError(
      'Pass either targetLanguage or targetLanguages, not both.',
    );
  }
  if (targetLanguage != null) {
    return [targetLanguage];
  }
  if (targetLanguages != null) {
    final languages = [
      for (final language in targetLanguages)
        if (language.trim().isNotEmpty) language.trim(),
    ];
    if (languages.isEmpty) {
      throw ArgumentError('targetLanguages must not be empty.');
    }
    return languages;
  }
  throw ArgumentError('Either targetLanguage or targetLanguages is required.');
}

/// Base class for translation [DatasetVariationGenerator] implementations.
///
/// Translates [DatasetEntry.input], [DatasetEntry.output], and
/// [DatasetEntry.thinking] while preserving [DatasetEntry.variationGroup],
/// assigning consecutive [DatasetEntry.variationIndex] values, and linking
/// [DatasetProvenance.parentEntryId].
///
/// Configure one or many targets via [targetLanguage] or [targetLanguages].
abstract base class TranslationVariationGenerator
    implements DatasetVariationGenerator {
  /// Creates a translation variation generator.
  ///
  /// Pass [targetLanguage] for a single target, or [targetLanguages] for
  /// several (one variation entry per language).
  TranslationVariationGenerator({
    String? targetLanguage,
    Iterable<String>? targetLanguages,
    this.generatorVersion = '1.0.0',
    this.instanceId,
    this.transformation = 'translation',
    this.skipWhenSameLanguage = true,
    this.generatorName,
  }) : targetLanguages = _targetLanguagesFrom(
         targetLanguage: targetLanguage,
         targetLanguages: targetLanguages,
       );

  static List<String> _targetLanguagesFrom({
    String? targetLanguage,
    Iterable<String>? targetLanguages,
  }) {
    return normalizeTargetLanguages(
      targetLanguage: targetLanguage,
      targetLanguages: targetLanguages,
    );
  }

  /// Target language codes written on variation entries (BCP-47 / short codes).
  final List<String> targetLanguages;

  /// Version recorded in provenance.
  final String generatorVersion;

  /// Stable id distinguishing multiple generator instances in one pipeline.
  final String? instanceId;

  /// Provenance / metadata strategy label.
  final String transformation;

  /// When true, skips a target when [DatasetEntry.language] already equals it.
  final bool skipWhenSameLanguage;

  /// Provenance generator name; defaults to the runtime type name.
  final String? generatorName;

  /// First configured target when exactly one language is set.
  String? get targetLanguage =>
      targetLanguages.length == 1 ? targetLanguages.single : null;

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
    final sourceLanguage = entry.language;
    final results = <DatasetEntry>[];
    var variationIndex = options.startVariationIndex;

    for (final target in targetLanguages) {
      if (skipWhenSameLanguage && sourceLanguage == target) {
        continue;
      }

      final translatedInput = await translateText(
        entry.input,
        sourceLanguage: sourceLanguage,
        targetLanguage: target,
      );
      final translatedOutput = entry.output == null
          ? null
          : await translateText(
              entry.output!,
              sourceLanguage: sourceLanguage,
              targetLanguage: target,
            );
      final translatedThinking = entry.thinking == null
          ? null
          : await translateText(
              entry.thinking!,
              sourceLanguage: sourceLanguage,
              targetLanguage: target,
            );

      results.add(
        buildTranslationVariation(
          entry,
          targetLanguage: target,
          options: options,
          variationIndex: variationIndex,
          translatedInput: translatedInput,
          translatedOutput: translatedOutput,
          translatedThinking: translatedThinking,
        ),
      );
      variationIndex++;
    }

    return results;
  }

  /// Builds the variation entry after text fields are translated.
  ///
  /// Subclasses may override to adjust metadata, type, or provenance.
  DatasetEntry buildTranslationVariation(
    DatasetEntry entry, {
    required String targetLanguage,
    required VariationGenerateOptions options,
    required int variationIndex,
    required String translatedInput,
    required String? translatedOutput,
    required String? translatedThinking,
  }) {
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
        if (targetLanguages.length > 1) 'targetLanguages': targetLanguages,
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
    super.targetLanguage,
    super.targetLanguages,
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
  RuleBasedTranslationVariationGenerator({
    super.targetLanguage,
    super.targetLanguages,
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
