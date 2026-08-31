import 'dart:convert';

/// Builds a stable, filesystem-safe id from [parts].
String stableDatasetId(List<Object?> parts) {
  final material = parts.map((p) => p?.toString() ?? '').join('\u{1f}');
  final bytes = utf8.encode(material);
  // FNV-1a 64-bit
  var hash = 0xcbf29ce484222325;
  for (final b in bytes) {
    hash ^= b;
    hash = (hash * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
  }
  return BigInt.from(hash).toUnsigned(64).toRadixString(16).padLeft(16, '0');
}

/// Approximate token count using whitespace splitting.
int approximateTokenCount(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) {
    return 0;
  }
  return trimmed.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).length;
}

/// Deterministic shuffle of [items] using a simple LCG seeded by [seed].
List<T> seededShuffle<T>(List<T> items, int seed) {
  final copy = List<T>.from(items);
  var state = seed & 0x7fffffff;
  if (state == 0) {
    state = 1;
  }
  int next() {
    state = (1103515245 * state + 12345) & 0x7fffffff;
    return state;
  }

  for (var i = copy.length - 1; i > 0; i--) {
    final j = next() % (i + 1);
    final tmp = copy[i];
    copy[i] = copy[j];
    copy[j] = tmp;
  }
  return copy;
}

/// Deterministic sample of up to [count] items.
List<T> seededSample<T>(List<T> items, int count, int seed) {
  if (count <= 0) {
    return <T>[];
  }
  if (count >= items.length) {
    return seededShuffle(items, seed);
  }
  return seededShuffle(items, seed).take(count).toList();
}
