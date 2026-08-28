import '../model/dataset_entry.dart';
import 'ids.dart';

/// Deep equality for JSON-like values (maps, lists, primitives).
bool jsonDeepEquals(Object? a, Object? b) {
  if (identical(a, b)) {
    return true;
  }
  if (a is Map && b is Map) {
    if (a.length != b.length) {
      return false;
    }
    for (final key in a.keys) {
      if (!b.containsKey(key) || !jsonDeepEquals(a[key], b[key])) {
        return false;
      }
    }
    return true;
  }
  if (a is List && b is List) {
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if (!jsonDeepEquals(a[i], b[i])) {
        return false;
      }
    }
    return true;
  }
  return a == b;
}

/// Stable content fingerprint for duplicate detection.
String entryContentFingerprint(DatasetEntry entry) {
  return stableDatasetId([
    entry.dataset,
    entry.input,
    entry.output,
    entry.variationGroup,
    entry.variationIndex,
  ]);
}
