/// Translation client decorator that prints step progress for long-running examples.
library;

import 'package:llm_dataset/llm_dataset.dart';

import 'translation_client.dart';

/// Wraps [inner] and reports each [translate] call.
final class ProgressTranslationClient implements TranslationClient {
  /// Creates a progress-reporting wrapper.
  ProgressTranslationClient({
    required this.inner,
    required this.totalSteps,
    this.targetLanguages = const [],
    this.fieldsPerLanguage = 2,
    this.label = 'translate',
  });

  /// Underlying provider.
  final TranslationClient inner;

  /// Expected number of [translate] invocations (for `[n/total]` display).
  final int totalSteps;

  /// Target languages (used to label input/output steps).
  final List<String> targetLanguages;

  /// Translated fields per language (e.g. 2 = input + output).
  final int fieldsPerLanguage;

  /// Short label printed before each step.
  final String label;

  var _step = 0;

  static const _fieldNames = ['input', 'output', 'thinking'];

  @override
  Future<bool> isAvailable() => inner.isAvailable();

  @override
  Future<String> translate(
    String text, {
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    _step++;
    final fieldLabel = _stepFieldLabel();
    stdoutWrite(
      '\n[$_step/$totalSteps] $label $sourceLanguage → $targetLanguage '
      '($fieldLabel)',
    );
    stdoutWrite('\n  from: ${_preview(text)}');
    final stopwatch = Stopwatch()..start();
    try {
      final result = await inner.translate(
        text,
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
      );
      stdoutWrite('\n  to:   ${_preview(result)}');
      stdoutWrite('\n  done ${stopwatch.elapsed.inSeconds}s');
      return result;
    } catch (error) {
      stdoutWrite('\n  failed ${stopwatch.elapsed.inSeconds}s: $error');
      rethrow;
    }
  }

  String _stepFieldLabel() {
    if (targetLanguages.isEmpty) {
      final field = (_step - 1) % fieldsPerLanguage;
      return _fieldNames[field.clamp(0, _fieldNames.length - 1)];
    }
    final perDoc = targetLanguages.length * fieldsPerLanguage;
    final inDoc = (_step - 1) % perDoc;
    final lang = targetLanguages[inDoc ~/ fieldsPerLanguage];
    final field =
        _fieldNames[(inDoc % fieldsPerLanguage).clamp(
          0,
          _fieldNames.length - 1,
        )];
    return '$lang $field';
  }

  String _preview(String text) {
    final normalized = text.split('\n').map((line) => line.trim()).join('\n');
    if (normalized.length <= 120) {
      return normalized;
    }
    return '${normalized.substring(0, 120)}…';
  }
}

/// Prints document-level pipeline progress before each yielded document.
final class ProgressDocumentSource implements DatasetSource {
  /// Creates a source over [documents].
  ProgressDocumentSource(this.documents);

  /// Documents to emit.
  final List<DatasetSourceDocument> documents;

  @override
  Stream<DatasetSourceDocument> load() async* {
    for (var i = 0; i < documents.length; i++) {
      final document = documents[i];
      stdoutWrite(
        '\n[doc ${i + 1}/${documents.length}] ${document.id}'
        '${document.title == null ? '' : ' (${document.title})'}',
      );
      stdoutWrite('\n  generating canonical entry…');
      yield document;
    }
  }
}

/// Avoid importing `dart:io` when `stdout` is unavailable (e.g. some embedders).
void stdoutWrite(String message) {
  // ignore: avoid_print
  print(message);
}
