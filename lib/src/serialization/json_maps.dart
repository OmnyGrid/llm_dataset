/// Builds a [Map] with keys sorted lexicographically for deterministic JSON.
///
/// Nested maps are ordered recursively. Lists are preserved in order; map
/// elements inside lists are ordered when they are maps.
Map<String, dynamic> orderedJsonMap(Map<String, dynamic> input) {
  final keys = input.keys.toList()..sort();
  final result = <String, dynamic>{};
  for (final key in keys) {
    result[key] = _orderValue(input[key]);
  }
  return result;
}

dynamic _orderValue(dynamic value) {
  if (value is Map) {
    return orderedJsonMap(Map<String, dynamic>.from(value));
  }
  if (value is List) {
    return value.map(_orderValue).toList(growable: false);
  }
  return value;
}

/// Deep-copies [metadata] into an unmodifiable map with unmodifiable nested
/// maps/lists where practical for top-level safety.
Map<String, dynamic> freezeMetadata(Map<String, dynamic> metadata) {
  return Map<String, dynamic>.unmodifiable(
    metadata.map((key, value) => MapEntry(key, _freezeValue(value))),
  );
}

dynamic _freezeValue(dynamic value) {
  if (value is Map) {
    return Map<String, dynamic>.unmodifiable(
      Map<String, dynamic>.from(value)
          .map((key, nested) => MapEntry(key, _freezeValue(nested))),
    );
  }
  if (value is List) {
    return List<dynamic>.unmodifiable(value.map(_freezeValue));
  }
  return value;
}
