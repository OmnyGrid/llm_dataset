import '../generator/dataset_generator.dart';
import '../generator/generator_helpers.dart';
import '../model/dataset_entry.dart';
import '../model/dataset_entry_type.dart';
import '../source/dataset_source.dart';
import 'text_build.dart';
import 'text_lexicon.dart';

/// Builds canonical **paragraph** entries from [ParagraphPatternConfig].
class ParagraphGenerator implements DatasetGenerator {
  /// Creates a paragraph generator.
  ParagraphGenerator({
    required this.config,
    required this.patterns,
    required this.lexicon,
    this.generatorVersion = '1.0.0',
  });

  /// Shared generator configuration.
  final GeneratorConfig config;

  /// Paragraph patterns keyed by [ParagraphPatternConfig.id].
  final Map<String, ParagraphPatternConfig> patterns;

  /// Lexicon for canonical slot resolution.
  final TextLexicon lexicon;

  /// Provenance version string.
  final String generatorVersion;

  @override
  Stream<DatasetEntry> generate(DatasetSourceDocument document) async* {
    final pattern = patterns[document.id];
    if (pattern == null) {
      throw ArgumentError(
        'Unknown paragraph pattern "${document.id}". '
        'Known: ${patterns.keys.join(', ')}',
      );
    }

    final sentenceSpecs = buildParagraphSentenceSpecs(pattern, lexicon);
    final text = rebuildExerciseText(
      paragraphExerciseMetadata(
        patternId: pattern.id,
        sentenceSpecs: sentenceSpecs,
        joiner: pattern.joiner,
      ),
    );

    yield buildCanonicalEntry(
      config: config,
      document: document,
      generatorName: 'ParagraphGenerator',
      type: DatasetEntryType.text,
      input: text,
      output: text,
      extraMetadata: paragraphExerciseMetadata(
        patternId: pattern.id,
        sentenceSpecs: sentenceSpecs,
        joiner: pattern.joiner,
      ),
    );
  }
}
