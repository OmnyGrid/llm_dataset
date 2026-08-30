/// Provider-agnostic translation client contract for LLM adapter examples.
library;

import 'package:llm_dataset/llm_dataset.dart';

/// Translates text between language codes.
///
/// Implement or extend this interface for each provider (local LLM, cloud API,
/// mock). Pass the client to [LlmTranslationVariationGenerator].
abstract interface class TranslationClient {
  /// Whether the provider is reachable and ready.
  Future<bool> isAvailable();

  /// Translates [text] from [sourceLanguage] to [targetLanguage].
  Future<String> translate(
    String text, {
    required String sourceLanguage,
    required String targetLanguage,
  });
}

/// Builds a translation prompt for chat-style LLM clients.
String buildTranslationPrompt(
  String text, {
  required String sourceLanguage,
  required String targetLanguage,
}) {
  return 'Translate the following text from $sourceLanguage to $targetLanguage.\n'
      'Return only the translated text, with no quotes or commentary.\n\n'
      'Text:\n$text';
}

/// Wraps an existing [TranslateTextFn] as a [TranslationClient].
final class CallbackTranslationClient implements TranslationClient {
  /// Creates a client around [translateFn].
  const CallbackTranslationClient(this.translateFn, {this.available = true});

  /// Underlying translate callback.
  final TranslateTextFn translateFn;

  /// Reported availability for [isAvailable].
  final bool available;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<String> translate(
    String text, {
    required String sourceLanguage,
    required String targetLanguage,
  }) {
    return translateFn(
      text,
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
    );
  }
}

/// Deterministic offline translation client for tests and demos.
final class MockTranslationClient implements TranslationClient {
  /// Creates a mock client.
  const MockTranslationClient();

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<String> translate(
    String text, {
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    return '[$targetLanguage] $text';
  }
}

/// Offline translate function backed by [MockTranslationClient].
Future<String> mockTranslate(
  String text, {
  required String sourceLanguage,
  required String targetLanguage,
}) {
  return const MockTranslationClient().translate(
    text,
    sourceLanguage: sourceLanguage,
    targetLanguage: targetLanguage,
  );
}

/// Resolves the first available client from [candidates], else [fallback].
Future<TranslationClient> firstAvailableTranslationClient(
  Iterable<TranslationClient> candidates, {
  TranslationClient fallback = const MockTranslationClient(),
}) async {
  for (final client in candidates) {
    if (await client.isAvailable()) {
      return client;
    }
  }
  return fallback;
}
