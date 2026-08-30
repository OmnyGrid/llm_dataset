/// Minimal HTTP client for OpenAI-compatible local LLM servers (Ollama, LM Studio).
library;

import 'dart:convert';
import 'dart:io';

import 'translation_client.dart';

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

  /// LM Studio defaults (`http://127.0.0.1:1234/v1`).
  ///
  /// Set [model] explicitly, or pass `LOCAL_LLM_MODEL=auto` to pick the first
  /// model reported by the server's `/models` endpoint.
  factory LocalLlmConfig.lmStudio({String? model, String? apiKey}) {
    final timeoutSeconds = int.tryParse(
      Platform.environment['LOCAL_LLM_TIMEOUT_SECONDS'] ?? '',
    );
    return LocalLlmConfig(
      baseUrl: 'http://127.0.0.1:1234/v1',
      model: model ?? Platform.environment['LOCAL_LLM_MODEL'] ?? 'local-model',
      apiKey: apiKey ?? Platform.environment['LOCAL_LLM_API_KEY'],
      timeout: Duration(seconds: timeoutSeconds ?? 300),
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

  /// Returns the first model id from `/models`, if any.
  Future<String?> firstModelId() async {
    final uri = Uri.parse('${config.baseUrl}/models');
    final client = HttpClient();
    client.connectionTimeout = config.timeout;
    try {
      final request = await client.getUrl(uri);
      if (config.apiKey != null) {
        request.headers.set('Authorization', 'Bearer ${config.apiKey}');
      }
      final response = await request.close().timeout(config.timeout);
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      final decoded = jsonDecode(body);
      if (decoded is! Map) {
        return null;
      }
      final data = decoded['data'];
      if (data is! List || data.isEmpty) {
        return null;
      }
      final first = data.first;
      if (first is! Map) {
        return null;
      }
      final id = first['id'];
      return id is String && id.isNotEmpty ? id : null;
    } on Object {
      return null;
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

/// [TranslationClient] backed by [LocalLlmClient] chat completions.
final class LocalLlmTranslationClient implements TranslationClient {
  /// Creates a translation client around [llm].
  LocalLlmTranslationClient(this.llm);

  /// Underlying OpenAI-compatible HTTP client.
  final LocalLlmClient llm;

  /// Creates from [config].
  factory LocalLlmTranslationClient.fromConfig(LocalLlmConfig config) {
    return LocalLlmTranslationClient(LocalLlmClient(config));
  }

  /// Creates from environment variables.
  factory LocalLlmTranslationClient.fromEnvironment() {
    return LocalLlmTranslationClient.fromConfig(
      LocalLlmConfig.fromEnvironment(),
    );
  }

  @override
  Future<bool> isAvailable() => llm.isAvailable();

  @override
  Future<String> translate(
    String text, {
    required String sourceLanguage,
    required String targetLanguage,
  }) {
    final prompt = buildTranslationPrompt(
      text,
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
    );
    return llm.chat(prompt);
  }
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

/// Resolves a translation client for examples (local LLM or mock fallback).
Future<TranslationClient> resolveExampleTranslationClient() {
  if (useMockFromEnvironment()) {
    return Future.value(const MockTranslationClient());
  }

  final local = LocalLlmTranslationClient.fromEnvironment();
  return firstAvailableTranslationClient([
    local,
  ], fallback: const MockTranslationClient());
}

/// Resolves LM Studio config, optionally auto-selecting the loaded model.
Future<LocalLlmConfig> resolveLmStudioConfig() async {
  final envModel = Platform.environment['LOCAL_LLM_MODEL'];
  if (envModel != null && envModel.isNotEmpty && envModel != 'auto') {
    return LocalLlmConfig.lmStudio(model: envModel);
  }

  var config = LocalLlmConfig.lmStudio();
  final probe = LocalLlmClient(config);
  if (await probe.isAvailable()) {
    final modelId = await probe.firstModelId();
    if (modelId != null) {
      config = LocalLlmConfig(
        baseUrl: config.baseUrl,
        model: modelId,
        apiKey: config.apiKey,
        timeout: config.timeout,
      );
    }
  }

  return config;
}

/// Connects to LM Studio at `http://127.0.0.1:1234/v1` (mock fallback offline).
Future<TranslationClient> resolveLmStudioTranslationClient() async {
  if (useMockFromEnvironment()) {
    return const MockTranslationClient();
  }

  final config = await resolveLmStudioConfig();
  final client = LocalLlmTranslationClient.fromConfig(config);
  return firstAvailableTranslationClient([
    client,
  ], fallback: const MockTranslationClient());
}
