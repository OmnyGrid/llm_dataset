/// Minimal HTTP client for OpenAI-compatible local LLM servers (Ollama, LM Studio).
library;

import 'dart:convert';
import 'dart:io';

import 'package:llm_dataset/llm_dataset.dart';

/// Configuration for a local OpenAI-compatible chat API.
class LocalLlmConfig {
  /// Creates client configuration.
  const LocalLlmConfig({
    this.baseUrl = 'http://localhost:11434/v1',
    this.model = 'llama3.2',
    this.apiKey,
    this.timeout = const Duration(seconds: 120),
  });

  /// OpenAI-compatible base URL (no trailing slash required).
  final String baseUrl;

  /// Model name passed to `/chat/completions`.
  final String model;

  /// Optional bearer token (`Authorization: Bearer …`).
  final String? apiKey;

  /// Request timeout for chat and health checks.
  final Duration timeout;

  /// Reads config from environment variables.
  ///
  /// - `LOCAL_LLM_BASE_URL` (default `http://localhost:11434/v1`)
  /// - `LOCAL_LLM_MODEL` (default `llama3.2`)
  /// - `LOCAL_LLM_API_KEY` (optional)
  factory LocalLlmConfig.fromEnvironment() {
    return LocalLlmConfig(
      baseUrl:
          Platform.environment['LOCAL_LLM_BASE_URL'] ??
          'http://localhost:11434/v1',
      model: Platform.environment['LOCAL_LLM_MODEL'] ?? 'llama3.2',
      apiKey: Platform.environment['LOCAL_LLM_API_KEY'],
    );
  }
}

/// Lightweight client for `/v1/chat/completions`.
class LocalLlmClient {
  /// Creates a client with [config].
  LocalLlmClient(this.config);

  /// Connection settings.
  final LocalLlmConfig config;

  /// Whether the server responds on `/models`.
  Future<bool> isAvailable() async {
    final uri = Uri.parse('${config.baseUrl}/models');
    final client = HttpClient();
    client.connectionTimeout = config.timeout;
    try {
      final request = await client.getUrl(uri);
      if (config.apiKey != null) {
        request.headers.set('Authorization', 'Bearer ${config.apiKey}');
      }
      final response = await request.close().timeout(config.timeout);
      await response.drain<void>();
      return response.statusCode >= 200 && response.statusCode < 300;
    } on Object {
      return false;
    } finally {
      client.close(force: true);
    }
  }

  /// Sends a single user message and returns assistant text.
  Future<String> chat(String prompt) async {
    final uri = Uri.parse('${config.baseUrl}/chat/completions');
    final client = HttpClient();
    client.connectionTimeout = config.timeout;
    try {
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;
      if (config.apiKey != null) {
        request.headers.set('Authorization', 'Bearer ${config.apiKey}');
      }
      request.write(
        jsonEncode({
          'model': config.model,
          'stream': false,
          'messages': [
            {'role': 'user', 'content': prompt},
          ],
        }),
      );

      final response = await request.close().timeout(config.timeout);
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'Local LLM chat failed (${response.statusCode}): $body',
          uri: uri,
        );
      }

      final decoded = jsonDecode(body);
      if (decoded is! Map) {
        throw FormatException('Expected JSON object from local LLM', body);
      }
      final choices = decoded['choices'];
      if (choices is! List || choices.isEmpty) {
        throw FormatException('Missing choices in local LLM response', body);
      }
      final first = choices.first;
      if (first is! Map) {
        throw FormatException('Invalid choice object', body);
      }
      final message = first['message'];
      if (message is! Map) {
        throw FormatException('Missing message in local LLM response', body);
      }
      final content = message['content'];
      if (content is! String || content.trim().isEmpty) {
        throw FormatException('Empty content in local LLM response', body);
      }
      return content.trim();
    } finally {
      client.close(force: true);
    }
  }
}

/// Builds a translation prompt for local chat models.
String buildTranslationPrompt(
  String text, {
  required String sourceLanguage,
  required String targetLanguage,
}) {
  return 'Translate the following text from $sourceLanguage to $targetLanguage.\n'
      'Return only the translated text, with no quotes or commentary.\n\n'
      'Text:\n$text';
}

/// Returns a [TranslateTextFn] backed by [client].
TranslateTextFn localLlmTranslateFn(LocalLlmClient client) {
  return (
    String text, {
    required String sourceLanguage,
    required targetLanguage,
  }) {
    final prompt = buildTranslationPrompt(
      text,
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
    );
    return client.chat(prompt);
  };
}

/// Whether examples should skip HTTP and use deterministic stubs.
bool useMockFromEnvironment() =>
    Platform.environment['LLM_DATASET_USE_MOCK'] == '1';

/// Parses comma-separated language codes from an environment variable.
List<String> targetLanguagesFromEnvironment(
  String name, {
  List<String> defaults = const ['es'],
}) {
  final raw = Platform.environment[name];
  if (raw == null || raw.trim().isEmpty) {
    return defaults;
  }
  return [
    for (final part in raw.split(','))
      if (part.trim().isNotEmpty) part.trim(),
  ];
}
