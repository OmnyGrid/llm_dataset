import '../model/dataset_entry.dart';

/// Outcome of validating a single [DatasetEntry].
class DatasetValidationResult {
  /// Creates a validation result.
  const DatasetValidationResult({
    required this.isValid,
    this.messages = const [],
    this.validatorName,
    this.entryId,
  });

  /// Convenience constructor for a successful validation.
  const DatasetValidationResult.valid({this.validatorName, this.entryId})
    : isValid = true,
      messages = const [];

  /// Convenience constructor for a failed validation.
  DatasetValidationResult.invalid(
    String message, {
    this.validatorName,
    this.entryId,
    List<String>? messages,
  }) : isValid = false,
       messages = messages ?? [message];

  /// Whether the entry passed validation.
  final bool isValid;

  /// Human-readable diagnostic messages.
  final List<String> messages;

  /// Name of the validator that produced this result, when known.
  final String? validatorName;

  /// Id of the entry under validation, when known.
  final String? entryId;

  /// Merges multiple results; invalid if any input is invalid.
  factory DatasetValidationResult.merge(
    Iterable<DatasetValidationResult> parts,
  ) {
    final list = parts.toList();
    if (list.isEmpty) {
      return const DatasetValidationResult.valid();
    }
    final messages = <String>[for (final part in list) ...part.messages];
    final valid = list.every((r) => r.isValid);
    return DatasetValidationResult(
      isValid: valid,
      messages: messages,
      validatorName: 'CompositeValidator',
      entryId: list.first.entryId,
    );
  }

  @override
  String toString() =>
      'DatasetValidationResult(isValid: $isValid, messages: $messages)';
}

/// Validates a [DatasetEntry] before persistence.
abstract interface class DatasetValidator {
  /// Validates [entry] and returns a structured result.
  Future<DatasetValidationResult> validate(DatasetEntry entry);
}

/// Runs multiple validators and merges their results.
class CompositeValidator implements DatasetValidator {
  /// Creates a composite over [validators].
  CompositeValidator(this.validators);

  /// Validators executed in order.
  final List<DatasetValidator> validators;

  @override
  Future<DatasetValidationResult> validate(DatasetEntry entry) async {
    final results = <DatasetValidationResult>[];
    for (final validator in validators) {
      results.add(await validator.validate(entry));
    }
    return DatasetValidationResult.merge(results);
  }
}
