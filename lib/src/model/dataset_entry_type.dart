/// Semantic category of a [DatasetEntry].
enum DatasetEntryType {
  /// Plain text completion or continuation.
  text,

  /// Multi-turn chat / dialogue.
  chat,

  /// Chain-of-thought or explicit reasoning traces.
  reasoning,

  /// Tool / function calling examples.
  toolCall,

  /// Source → target language translation.
  translation,

  /// Document or passage summarization.
  summarization,

  /// Label / category assignment.
  classification,

  /// Structured extraction from unstructured input.
  extraction,

  /// Code generation, repair, or explanation.
  coding,

  /// Retrieval-augmented generation examples.
  rag,

  /// Agent / multi-step tool workflows.
  agent,
}

/// Parses a stable wire name into [DatasetEntryType].
DatasetEntryType datasetEntryTypeFromName(String name) {
  for (final value in DatasetEntryType.values) {
    if (value.name == name) {
      return value;
    }
  }
  throw ArgumentError.value(name, 'name', 'Unknown DatasetEntryType');
}
