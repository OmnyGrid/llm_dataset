/// LLM-backed translation variation generator wired through [TranslationClient].
library;

import 'package:llm_dataset/llm_dataset.dart';

import 'translation_client.dart';

/// Generates translation variations using a configurable [TranslationClient].
///
/// Swap [client] to support different providers without changing pipeline code.
final class LlmTranslationVariationGenerator
    extends TranslationVariationGenerator {
  /// Creates a generator backed by [client].
  LlmTranslationVariationGenerator({
    required this.client,
    super.targetLanguage,
    super.targetLanguages,
    super.generatorVersion = 'llm-translation-1.0.0',
    super.instanceId = 'llm-translation',
  }) : super(generatorName: 'LlmTranslationVariationGenerator');

  /// Provider client that performs translation requests.
  final TranslationClient client;

  /// Convenience constructor for legacy [TranslateTextFn] callbacks.
  LlmTranslationVariationGenerator.withTranslate({
    required TranslateTextFn translate,
    super.targetLanguage,
    super.targetLanguages,
    super.generatorVersion = 'llm-translation-1.0.0',
    super.instanceId = 'llm-translation',
  }) : client = CallbackTranslationClient(translate);

  @override
  Future<String> translateText(
    String text, {
    required String sourceLanguage,
    required String targetLanguage,
  }) {
    return client.translate(
      text,
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
    );
  }
}
