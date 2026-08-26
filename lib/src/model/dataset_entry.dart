import '../serialization/json_maps.dart';
import 'dataset_entry_type.dart';
import 'dataset_provenance.dart';
import 'dataset_tool_call.dart';

/// Well-known metadata key for ordered chat / tool / agent message turns.
///
/// Each element is a map with at least a `role` (`user`, `assistant`, `tool`)
/// and typically `content`. Assistant turns may include `tool_calls` (a list of
/// [DatasetToolCall]-shaped maps). Tool turns may include `tool_call_id`.
const String datasetMessagesMetadataKey = 'messages';

/// A single training example in an LLM dataset.
///
/// Semantic paraphrases of the same example share a [variationGroup]. The
/// canonical (original) entry has [variationIndex] `0` and no
/// [DatasetProvenance.parentEntryId]. Generated variations use indexes `> 0`
/// and set [DatasetProvenance.parentEntryId] to the parent entry id.
///
/// Chat, tool-call, and agent multi-turn data may be stored under
/// [metadata] using [datasetMessagesMetadataKey] without requiring a separate
/// entry subclass per training format.
class DatasetEntry {
  /// Creates an immutable dataset entry.
  DatasetEntry({
    required this.id,
    required this.dataset,
    this.datasetVersion,
    required this.type,
    required this.language,
    required this.input,
    this.output,
    this.thinking,
    required this.variationGroup,
    required this.variationIndex,
    Map<String, dynamic> metadata = const <String, dynamic>{},
    this.provenance,
    required this.createdAt,
  }) : metadata = freezeMetadata(metadata);

  /// Unique identifier within the store.
  final String id;

  /// Logical dataset name this entry belongs to.
  final String dataset;

  /// Optional dataset version string (e.g. `v1`, `2024-01`).
  final String? datasetVersion;

  /// Semantic entry type.
  final DatasetEntryType type;

  /// BCP-47 / short language code for the primary content (e.g. `en`).
  final String language;

  /// Primary input / prompt / source text.
  final String input;

  /// Expected output / completion, when applicable.
  final String? output;

  /// Optional explicit reasoning / chain-of-thought text.
  final String? thinking;

  /// Links all variations of the same semantic example.
  final String variationGroup;

  /// Index within [variationGroup]. `0` denotes the canonical entry.
  final int variationIndex;

  /// Extensible key-value metadata (includes optional message sequences).
  final Map<String, dynamic> metadata;

  /// Origin and transformation history, when known.
  final DatasetProvenance? provenance;

  /// Creation timestamp (prefer UTC).
  final DateTime createdAt;

  /// Whether this entry is the canonical member of its variation group.
  ///
  /// Derived from [variationIndex] `== 0` and a null parent id in [provenance].
  bool get isCanonical =>
      variationIndex == 0 && provenance?.parentEntryId == null;

  /// Ordered message turns from [metadata], or an empty list when absent.
  List<Map<String, dynamic>> get messages {
    final raw = metadata[datasetMessagesMetadataKey];
    if (raw is! List) {
      return const <Map<String, dynamic>>[];
    }
    return [
      for (final item in raw)
        if (item is Map) Map<String, dynamic>.from(item),
    ];
  }

  /// Collects [DatasetToolCall]s embedded in [messages] assistant turns.
  List<DatasetToolCall> get toolCalls {
    final calls = <DatasetToolCall>[];
    for (final message in messages) {
      final rawCalls = message['tool_calls'];
      if (rawCalls is! List) {
        continue;
      }
      for (final call in rawCalls) {
        if (call is Map) {
          calls.add(DatasetToolCall.fromJson(Map<String, dynamic>.from(call)));
        }
      }
    }
    return calls;
  }

  /// Returns a copy with selected fields replaced.
  DatasetEntry copyWith({
    String? id,
    String? dataset,
    String? datasetVersion,
    DatasetEntryType? type,
    String? language,
    String? input,
    String? output,
    String? thinking,
    String? variationGroup,
    int? variationIndex,
    Map<String, dynamic>? metadata,
    DatasetProvenance? provenance,
    DateTime? createdAt,
    bool clearDatasetVersion = false,
    bool clearOutput = false,
    bool clearThinking = false,
    bool clearProvenance = false,
  }) {
    return DatasetEntry(
      id: id ?? this.id,
      dataset: dataset ?? this.dataset,
      datasetVersion: clearDatasetVersion
          ? null
          : (datasetVersion ?? this.datasetVersion),
      type: type ?? this.type,
      language: language ?? this.language,
      input: input ?? this.input,
      output: clearOutput ? null : (output ?? this.output),
      thinking: clearThinking ? null : (thinking ?? this.thinking),
      variationGroup: variationGroup ?? this.variationGroup,
      variationIndex: variationIndex ?? this.variationIndex,
      metadata: metadata ?? this.metadata,
      provenance: clearProvenance ? null : (provenance ?? this.provenance),
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Serializes to a JSON-compatible map with deterministic key order.
  Map<String, dynamic> toJson() {
    return orderedJsonMap({
      'id': id,
      'dataset': dataset,
      if (datasetVersion != null) 'datasetVersion': datasetVersion,
      'type': type.name,
      'language': language,
      'input': input,
      if (output != null) 'output': output,
      if (thinking != null) 'thinking': thinking,
      'variationGroup': variationGroup,
      'variationIndex': variationIndex,
      'metadata': orderedJsonMap(Map<String, dynamic>.from(metadata)),
      if (provenance != null) 'provenance': provenance!.toJson(),
      'createdAt': createdAt.toUtc().toIso8601String(),
    });
  }

  /// Deserializes from a JSON-compatible map.
  factory DatasetEntry.fromJson(Map<String, dynamic> json) {
    final rawMetadata = json['metadata'];
    final rawProvenance = json['provenance'];
    return DatasetEntry(
      id: json['id'] as String,
      dataset: json['dataset'] as String,
      datasetVersion: json['datasetVersion'] as String?,
      type: datasetEntryTypeFromName(json['type'] as String),
      language: json['language'] as String,
      input: json['input'] as String,
      output: json['output'] as String?,
      thinking: json['thinking'] as String?,
      variationGroup: json['variationGroup'] as String,
      variationIndex: json['variationIndex'] as int,
      metadata: rawMetadata is Map
          ? Map<String, dynamic>.from(rawMetadata)
          : const <String, dynamic>{},
      provenance: rawProvenance is Map
          ? DatasetProvenance.fromJson(Map<String, dynamic>.from(rawProvenance))
          : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  @override
  bool operator ==(Object other) => other is DatasetEntry && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'DatasetEntry(id: $id, dataset: $dataset, type: ${type.name})';
}
