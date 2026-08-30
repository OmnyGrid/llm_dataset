/// Example LLM-backed translation [DatasetVariationGenerator] adapter.
library;

import 'package:llm_dataset/llm_dataset.dart';

/// Generates one translation variation via [CallbackTranslationVariationGenerator].
final class LlmTranslationVariationGenerator
    extends CallbackTranslationVariationGenerator {
  /// Creates an adapter around [translate].
  LlmTranslationVariationGenerator({
    required super.targetLanguage,
    required super.translate,
    super.generatorVersion = 'llm-translation-1.0.0',
    super.instanceId = 'llm-translation',
  }) : super(generatorName: 'LlmTranslationVariationGenerator');
}

/// Deterministic offline translation stub.
Future<String> mockTranslate(
  String text, {
  required String sourceLanguage,
  required String targetLanguage,
}) async {
  return '[$targetLanguage] $text';
}
