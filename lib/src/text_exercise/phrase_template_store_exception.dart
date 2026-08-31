/// Error while loading or validating a phrase template file store.
class PhraseTemplateStoreException implements Exception {
  /// Creates a store exception.
  const PhraseTemplateStoreException(
    this.message, {
    this.path,
    this.field,
    this.cause,
  });

  /// Human-readable error description.
  final String message;

  /// File path related to the error, when applicable.
  final String? path;

  /// JSON field related to the error, when applicable.
  final String? field;

  /// Underlying exception, when applicable.
  final Object? cause;

  @override
  String toString() {
    final buffer = StringBuffer('PhraseTemplateStoreException: $message');
    if (path != null) {
      buffer.write(' (path: $path)');
    }
    if (field != null) {
      buffer.write(' (field: $field)');
    }
    if (cause != null) {
      buffer.write(' (cause: $cause)');
    }
    return buffer.toString();
  }
}
