import '../serialization/json_maps.dart';

/// A raw document loaded from a [DatasetSource] before generation.
class DatasetSourceDocument {
  /// Creates an immutable source document.
  DatasetSourceDocument({
    required this.id,
    required this.content,
    this.title,
    this.language,
    Map<String, dynamic> metadata = const <String, dynamic>{},
  }) : metadata = freezeMetadata(metadata);

  /// Stable document identifier (e.g. path or JSON `id`).
  final String id;

  /// Full document text.
  final String content;

  /// Optional human-readable title.
  final String? title;

  /// Optional language code.
  final String? language;

  /// Extensible metadata from the source.
  final Map<String, dynamic> metadata;

  /// Returns a copy with selected fields replaced.
  DatasetSourceDocument copyWith({
    String? id,
    String? content,
    String? title,
    String? language,
    Map<String, dynamic>? metadata,
    bool clearTitle = false,
    bool clearLanguage = false,
  }) {
    return DatasetSourceDocument(
      id: id ?? this.id,
      content: content ?? this.content,
      title: clearTitle ? null : (title ?? this.title),
      language: clearLanguage ? null : (language ?? this.language),
      metadata: metadata ?? this.metadata,
    );
  }

  /// Serializes to a JSON-compatible map.
  Map<String, dynamic> toJson() {
    return orderedJsonMap({
      'id': id,
      'content': content,
      if (title != null) 'title': title,
      if (language != null) 'language': language,
      'metadata': orderedJsonMap(Map<String, dynamic>.from(metadata)),
    });
  }

  /// Deserializes from a JSON-compatible map.
  factory DatasetSourceDocument.fromJson(Map<String, dynamic> json) {
    final rawMetadata = json['metadata'];
    return DatasetSourceDocument(
      id: json['id'] as String,
      content: json['content'] as String,
      title: json['title'] as String?,
      language: json['language'] as String?,
      metadata: rawMetadata is Map
          ? Map<String, dynamic>.from(rawMetadata)
          : const <String, dynamic>{},
    );
  }

  @override
  bool operator ==(Object other) {
    return other is DatasetSourceDocument &&
        other.id == id &&
        other.content == content &&
        other.title == title &&
        other.language == language;
  }

  @override
  int get hashCode => Object.hash(id, content, title, language);

  @override
  String toString() => 'DatasetSourceDocument(id: $id)';
}

/// Stream-based producer of [DatasetSourceDocument] values.
///
/// Implementations must not require loading an entire corpus into memory.
abstract interface class DatasetSource {
  /// Loads documents incrementally.
  Stream<DatasetSourceDocument> load();
}
