/// Thrown when curriculum manifest or build configuration is invalid.
class CurriculumException implements Exception {
  /// Creates an exception with [message].
  const CurriculumException(this.message, {this.field, this.cause});

  /// Human-readable error description.
  final String message;

  /// JSON field path when applicable.
  final String? field;

  /// Underlying error.
  final Object? cause;

  @override
  String toString() {
    final fieldLabel = field == null ? '' : ' ($field)';
    final causeLabel = cause == null ? '' : ': $cause';
    return 'CurriculumException$fieldLabel: $message$causeLabel';
  }
}
