import '../serialization/json_maps.dart';

/// Origin and transformation history for a [DatasetEntry].
///
/// Generated or transformed entries should retain provenance whenever an
/// origin exists. Variation entries reference their parent via [parentEntryId].
class DatasetProvenance {
  /// Creates provenance metadata for a dataset entry.
  const DatasetProvenance({
    this.source,
    this.sourceId,
    this.sourceUri,
    this.generator,
    this.generatorVersion,
    this.transformation,
    this.parentEntryId,
    this.pipelineVersion,
  });

  /// Human-readable or logical source name (e.g. corpus id).
  final String? source;

  /// Identifier of the record within [source].
  final String? sourceId;

  /// URI or path of the originating document, when available.
  final String? sourceUri;

  /// Name of the generator that created this entry.
  final String? generator;

  /// Version of [generator].
  final String? generatorVersion;

  /// Description of a transformation applied to a parent entry.
  final String? transformation;

  /// Id of the parent [DatasetEntry], when this entry was derived.
  final String? parentEntryId;

  /// Version of the pipeline that produced this entry.
  final String? pipelineVersion;

  /// Returns a copy with selected fields replaced.
  DatasetProvenance copyWith({
    String? source,
    String? sourceId,
    String? sourceUri,
    String? generator,
    String? generatorVersion,
    String? transformation,
    String? parentEntryId,
    String? pipelineVersion,
    bool clearSource = false,
    bool clearSourceId = false,
    bool clearSourceUri = false,
    bool clearGenerator = false,
    bool clearGeneratorVersion = false,
    bool clearTransformation = false,
    bool clearParentEntryId = false,
    bool clearPipelineVersion = false,
  }) {
    return DatasetProvenance(
      source: clearSource ? null : (source ?? this.source),
      sourceId: clearSourceId ? null : (sourceId ?? this.sourceId),
      sourceUri: clearSourceUri ? null : (sourceUri ?? this.sourceUri),
      generator: clearGenerator ? null : (generator ?? this.generator),
      generatorVersion: clearGeneratorVersion
          ? null
          : (generatorVersion ?? this.generatorVersion),
      transformation: clearTransformation
          ? null
          : (transformation ?? this.transformation),
      parentEntryId: clearParentEntryId
          ? null
          : (parentEntryId ?? this.parentEntryId),
      pipelineVersion: clearPipelineVersion
          ? null
          : (pipelineVersion ?? this.pipelineVersion),
    );
  }

  /// Serializes to a JSON-compatible map, omitting null fields.
  Map<String, dynamic> toJson() {
    return orderedJsonMap({
      if (source != null) 'source': source,
      if (sourceId != null) 'sourceId': sourceId,
      if (sourceUri != null) 'sourceUri': sourceUri,
      if (generator != null) 'generator': generator,
      if (generatorVersion != null) 'generatorVersion': generatorVersion,
      if (transformation != null) 'transformation': transformation,
      if (parentEntryId != null) 'parentEntryId': parentEntryId,
      if (pipelineVersion != null) 'pipelineVersion': pipelineVersion,
    });
  }

  /// Deserializes from a JSON-compatible map.
  factory DatasetProvenance.fromJson(Map<String, dynamic> json) {
    return DatasetProvenance(
      source: json['source'] as String?,
      sourceId: json['sourceId'] as String?,
      sourceUri: json['sourceUri'] as String?,
      generator: json['generator'] as String?,
      generatorVersion: json['generatorVersion'] as String?,
      transformation: json['transformation'] as String?,
      parentEntryId: json['parentEntryId'] as String?,
      pipelineVersion: json['pipelineVersion'] as String?,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is DatasetProvenance &&
        other.source == source &&
        other.sourceId == sourceId &&
        other.sourceUri == sourceUri &&
        other.generator == generator &&
        other.generatorVersion == generatorVersion &&
        other.transformation == transformation &&
        other.parentEntryId == parentEntryId &&
        other.pipelineVersion == pipelineVersion;
  }

  @override
  int get hashCode => Object.hash(
    source,
    sourceId,
    sourceUri,
    generator,
    generatorVersion,
    transformation,
    parentEntryId,
    pipelineVersion,
  );

  @override
  String toString() => 'DatasetProvenance(${toJson()})';
}
