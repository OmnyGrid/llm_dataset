import '../serialization/json_maps.dart';

/// A single tool / function invocation within a training example.
///
/// Multi-turn tool sequences (user → assistant tool call → tool result →
/// assistant) are stored on [DatasetEntry.metadata] under the `messages` key.
/// Each assistant turn may embed one or more [DatasetToolCall] objects.
class DatasetToolCall {
  /// Creates a tool call with [name] and [arguments].
  const DatasetToolCall({
    required this.name,
    this.arguments = const <String, dynamic>{},
  });

  /// Tool / function name.
  final String name;

  /// Structured arguments passed to the tool.
  final Map<String, dynamic> arguments;

  /// Returns a copy with selected fields replaced.
  DatasetToolCall copyWith({String? name, Map<String, dynamic>? arguments}) {
    return DatasetToolCall(
      name: name ?? this.name,
      arguments: arguments ?? this.arguments,
    );
  }

  /// Serializes to a JSON-compatible map.
  Map<String, dynamic> toJson() {
    return orderedJsonMap({
      'name': name,
      'arguments': orderedJsonMap(Map<String, dynamic>.from(arguments)),
    });
  }

  /// Deserializes from a JSON-compatible map.
  factory DatasetToolCall.fromJson(Map<String, dynamic> json) {
    final rawArgs = json['arguments'];
    return DatasetToolCall(
      name: json['name'] as String,
      arguments: rawArgs is Map
          ? Map<String, dynamic>.from(rawArgs)
          : const <String, dynamic>{},
    );
  }

  @override
  bool operator ==(Object other) {
    return other is DatasetToolCall &&
        other.name == name &&
        _mapEquals(other.arguments, arguments);
  }

  @override
  int get hashCode => Object.hash(name, Object.hashAll(arguments.entries));

  @override
  String toString() => 'DatasetToolCall(${toJson()})';
}

bool _mapEquals(Map<String, dynamic> a, Map<String, dynamic> b) {
  if (identical(a, b)) {
    return true;
  }
  if (a.length != b.length) {
    return false;
  }
  for (final entry in a.entries) {
    if (!b.containsKey(entry.key) || b[entry.key] != entry.value) {
      return false;
    }
  }
  return true;
}
