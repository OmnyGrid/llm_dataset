import 'package:test/test.dart';

import '../../example/adapters/local_llm_client.dart';

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

  test('localLlmTranslateFn delegates to client.chat', () async {
    final calls = <String>[];
    final client = _FakeLocalLlmClient((prompt) async {
      calls.add(prompt);
      return 'Hola';
    });

    final translate = localLlmTranslateFn(client);
    final result = await translate(
      'Hello',
      sourceLanguage: 'en',
      targetLanguage: 'es',
    );

    expect(result, 'Hola');
    expect(calls, hasLength(1));
    expect(calls.single, contains('Hello'));
  });
}

class _FakeLocalLlmClient extends LocalLlmClient {
  _FakeLocalLlmClient(this._chat)
    : super(const LocalLlmConfig(baseUrl: 'http://fake'));

  final Future<String> Function(String prompt) _chat;

  @override
  Future<String> chat(String prompt) => _chat(prompt);
}
