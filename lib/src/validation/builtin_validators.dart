import '../model/dataset_entry.dart';
import '../store/dataset_store.dart';
import '../util/ids.dart';
import 'dataset_validator.dart';

/// Rejects entries with empty [DatasetEntry.input] (and empty output when
/// [requireOutput] is true).
class EmptyContentValidator implements DatasetValidator {
  /// Creates an empty-content validator.
  const EmptyContentValidator({this.requireOutput = false});

  /// When true, [DatasetEntry.output] must be non-null and non-empty.
  final bool requireOutput;

  @override
  Future<DatasetValidationResult> validate(DatasetEntry entry) async {
    final messages = <String>[];
    if (entry.input.trim().isEmpty) {
      messages.add('input is empty');
    }
    if (requireOutput &&
        (entry.output == null || entry.output!.trim().isEmpty)) {
      messages.add('output is empty');
    }
    if (messages.isEmpty) {
      return DatasetValidationResult.valid(
        validatorName: 'EmptyContentValidator',
        entryId: entry.id,
      );
    }
    return DatasetValidationResult(
      isValid: false,
      messages: messages,
      validatorName: 'EmptyContentValidator',
      entryId: entry.id,
    );
  }
}

/// Detects duplicate ids and optional content fingerprints without requiring
/// the full dataset in memory when a [DatasetStore] is provided.
class DuplicateValidator implements DatasetValidator {
  /// Creates a duplicate detector.
  ///
  /// When [store] is set, existing ids are checked via [DatasetStore.get].
  /// An in-memory set tracks ids seen in the current streaming pass.
  DuplicateValidator({this.store, this.checkContentFingerprint = false});

  /// Optional persistent store for id lookups.
  final DatasetStore? store;

  /// When true, also rejects duplicate input fingerprints within the stream.
  final bool checkContentFingerprint;

  final Set<String> _seenIds = <String>{};
  final Set<String> _seenFingerprints = <String>{};

  @override
  Future<DatasetValidationResult> validate(DatasetEntry entry) async {
    if (_seenIds.contains(entry.id)) {
      return DatasetValidationResult.invalid(
        'duplicate id in stream: ${entry.id}',
        validatorName: 'DuplicateValidator',
        entryId: entry.id,
      );
    }
    if (store != null) {
      final existing = await store!.get(entry.id);
      if (existing != null) {
        return DatasetValidationResult.invalid(
          'duplicate id in store: ${entry.id}',
          validatorName: 'DuplicateValidator',
          entryId: entry.id,
        );
      }
    }
    _seenIds.add(entry.id);

    if (checkContentFingerprint) {
      final fp = stableDatasetId([
        entry.dataset,
        entry.input,
        entry.output,
        entry.variationGroup,
        entry.variationIndex,
      ]);
      if (_seenFingerprints.contains(fp)) {
        return DatasetValidationResult.invalid(
          'duplicate content fingerprint',
          validatorName: 'DuplicateValidator',
          entryId: entry.id,
        );
      }
      _seenFingerprints.add(fp);
    }

    return DatasetValidationResult.valid(
      validatorName: 'DuplicateValidator',
      entryId: entry.id,
    );
  }

  /// Clears stream-local seen sets (does not affect [store]).
  void reset() {
    _seenIds.clear();
    _seenFingerprints.clear();
  }
}

/// Requires specific metadata keys (and optionally non-null values).
class MetadataValidator implements DatasetValidator {
  /// Creates a metadata validator.
  const MetadataValidator({
    this.requiredKeys = const [],
    this.forbiddenKeys = const [],
  });

  /// Keys that must be present.
  final List<String> requiredKeys;

  /// Keys that must not be present.
  final List<String> forbiddenKeys;

  @override
  Future<DatasetValidationResult> validate(DatasetEntry entry) async {
    final messages = <String>[];
    for (final key in requiredKeys) {
      if (!entry.metadata.containsKey(key)) {
        messages.add('missing required metadata key: $key');
      }
    }
    for (final key in forbiddenKeys) {
      if (entry.metadata.containsKey(key)) {
        messages.add('forbidden metadata key present: $key');
      }
    }
    if (messages.isEmpty) {
      return DatasetValidationResult.valid(
        validatorName: 'MetadataValidator',
        entryId: entry.id,
      );
    }
    return DatasetValidationResult(
      isValid: false,
      messages: messages,
      validatorName: 'MetadataValidator',
      entryId: entry.id,
    );
  }
}

/// Restricts [DatasetEntry.language] to an allow-list.
class LanguageValidator implements DatasetValidator {
  /// Creates a language validator.
  const LanguageValidator(this.allowedLanguages);

  /// Allowed language codes.
  final Set<String> allowedLanguages;

  @override
  Future<DatasetValidationResult> validate(DatasetEntry entry) async {
    if (allowedLanguages.contains(entry.language)) {
      return DatasetValidationResult.valid(
        validatorName: 'LanguageValidator',
        entryId: entry.id,
      );
    }
    return DatasetValidationResult.invalid(
      'language "${entry.language}" not in $allowedLanguages',
      validatorName: 'LanguageValidator',
      entryId: entry.id,
    );
  }
}

/// Configurable min/max character lengths for input/output.
class LengthValidator implements DatasetValidator {
  /// Creates a length validator.
  const LengthValidator({
    this.minInputLength = 1,
    this.maxInputLength,
    this.minOutputLength,
    this.maxOutputLength,
  });

  /// Minimum input length (inclusive).
  final int minInputLength;

  /// Maximum input length (inclusive), or null for unlimited.
  final int? maxInputLength;

  /// Minimum output length when output is non-null.
  final int? minOutputLength;

  /// Maximum output length when output is non-null.
  final int? maxOutputLength;

  @override
  Future<DatasetValidationResult> validate(DatasetEntry entry) async {
    final messages = <String>[];
    final inputLen = entry.input.length;
    if (inputLen < minInputLength) {
      messages.add('input length $inputLen < $minInputLength');
    }
    if (maxInputLength != null && inputLen > maxInputLength!) {
      messages.add('input length $inputLen > $maxInputLength');
    }
    final output = entry.output;
    if (output != null) {
      final outLen = output.length;
      if (minOutputLength != null && outLen < minOutputLength!) {
        messages.add('output length $outLen < $minOutputLength');
      }
      if (maxOutputLength != null && outLen > maxOutputLength!) {
        messages.add('output length $outLen > $maxOutputLength');
      }
    }
    if (messages.isEmpty) {
      return DatasetValidationResult.valid(
        validatorName: 'LengthValidator',
        entryId: entry.id,
      );
    }
    return DatasetValidationResult(
      isValid: false,
      messages: messages,
      validatorName: 'LengthValidator',
      entryId: entry.id,
    );
  }
}

/// Configurable approximate token-count bounds (whitespace tokenization).
class TokenCountValidator implements DatasetValidator {
  /// Creates a token-count validator.
  const TokenCountValidator({
    this.minInputTokens = 1,
    this.maxInputTokens,
    this.minOutputTokens,
    this.maxOutputTokens,
  });

  /// Minimum input tokens.
  final int minInputTokens;

  /// Maximum input tokens.
  final int? maxInputTokens;

  /// Minimum output tokens when output is present.
  final int? minOutputTokens;

  /// Maximum output tokens when output is present.
  final int? maxOutputTokens;

  @override
  Future<DatasetValidationResult> validate(DatasetEntry entry) async {
    final messages = <String>[];
    final inputTokens = approximateTokenCount(entry.input);
    if (inputTokens < minInputTokens) {
      messages.add('input tokens $inputTokens < $minInputTokens');
    }
    if (maxInputTokens != null && inputTokens > maxInputTokens!) {
      messages.add('input tokens $inputTokens > $maxInputTokens');
    }
    if (entry.output != null) {
      final outTokens = approximateTokenCount(entry.output!);
      if (minOutputTokens != null && outTokens < minOutputTokens!) {
        messages.add('output tokens $outTokens < $minOutputTokens');
      }
      if (maxOutputTokens != null && outTokens > maxOutputTokens!) {
        messages.add('output tokens $outTokens > $maxOutputTokens');
      }
    }
    if (messages.isEmpty) {
      return DatasetValidationResult.valid(
        validatorName: 'TokenCountValidator',
        entryId: entry.id,
      );
    }
    return DatasetValidationResult(
      isValid: false,
      messages: messages,
      validatorName: 'TokenCountValidator',
      entryId: entry.id,
    );
  }
}
