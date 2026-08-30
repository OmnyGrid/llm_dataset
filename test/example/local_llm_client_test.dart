import 'package:test/test.dart';

import '../../example/adapters/local_llm_client.dart';
import '../../example/adapters/translation_client.dart';

void main() {
  test('buildTranslationPrompt includes languages and source text', () {
    final prompt = buildTranslationPrompt(
      'Hello world',
      sourceLanguage: 'en',
      targetLanguage: 'es',
    );

    expect(prompt, contains('from en to es'));
    expect(prompt, contains('Hello world'));
    expect(prompt, contains('Return only the translated text'));
  });

  test('LocalLlmTranslationClient delegates to chat', () async {
    final calls = <String>[];
    final llm = _FakeLocalLlmClient((prompt) async {
      calls.add(prompt);
      return 'Hola';
    });
    final client = LocalLlmTranslationClient(llm);

    final result = await client.translate(
      'Hello',
      sourceLanguage: 'en',
      targetLanguage: 'es',
    );

    expect(result, 'Hola');
    expect(calls, hasLength(1));
    expect(calls.single, contains('Hello'));
  });

  test(
    'firstAvailableTranslationClient picks first reachable client',
    () async {
      final chosen = await firstAvailableTranslationClient([
        _UnavailableClient(),
        const MockTranslationClient(),
      ]);
      expect(chosen, isA<MockTranslationClient>());
    },
  );
}

class _FakeLocalLlmClient extends LocalLlmClient {
  _FakeLocalLlmClient(this._chat)
    : super(const LocalLlmConfig(baseUrl: 'http://fake'));

  final Future<String> Function(String prompt) _chat;

  @override
  Future<String> chat(String prompt) => _chat(prompt);
}

class _UnavailableClient implements TranslationClient {
  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<String> translate(
    String text, {
    required String sourceLanguage,
    required String targetLanguage,
  }) {
    throw UnsupportedError('unavailable');
  }
}
