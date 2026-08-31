/// Progress logging for combinatorial phrase generation examples.
library;

import 'package:llm_dataset/llm_dataset.dart';

/// Wraps [entries] and prints each generated phrase with global/template progress.
Stream<DatasetEntry> logCombinatorialProgress({
  required Stream<DatasetEntry> entries,
  required int totalExpected,
  required int templateExpected,
  required String templateId,
  required int templateIndex,
  required int templateCount,
  required int entriesBeforeTemplate,
  int summaryEvery = 10000,
}) async* {
  var templateLocal = 0;
  var lastSummaryAt = 0;
  final templateStarted = Stopwatch()..start();

  await for (final entry in entries) {
    templateLocal++;
    final global = entriesBeforeTemplate + templateLocal;
    final label = entry.isCanonical
        ? 'canonical'
        : entry.provenance?.transformation == 'structure_preserving'
        ? 'structure'
        : 'variation';

    stdoutWrite(
      '\n[$global/$totalExpected] '
      '[template ${templateIndex + 1}/$templateCount '
      '$templateId $templateLocal/$templateExpected] '
      '[$label]',
    );
    stdoutWrite('\n  input:  ${entry.input}');
    if (entry.output != null && entry.output != entry.input) {
      stdoutWrite('\n  output: ${entry.output}');
    }

    if (summaryEvery > 0 &&
        global - lastSummaryAt >= summaryEvery &&
        global < totalExpected) {
      final elapsedSeconds = (templateStarted.elapsed.inMilliseconds / 1000)
          .clamp(0.001, double.infinity);
      final rate = templateLocal / elapsedSeconds;
      stdoutWrite(
        '\n  … template throughput ~${rate.round()} entries/s '
        '(${templateStarted.elapsed.inSeconds}s elapsed)',
      );
      lastSummaryAt = global;
    }

    yield entry;
  }
}

/// Avoid importing `dart:io` when `stdout` is unavailable (e.g. some embedders).
void stdoutWrite(String message) {
  // ignore: avoid_print
  print(message);
}
