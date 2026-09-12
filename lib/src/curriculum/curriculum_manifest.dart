import 'dart:convert';
import 'dart:io';

import 'curriculum_exception.dart';

/// Mixing policy for a curriculum stage at training time.
class CurriculumMixingPolicy {
  /// Creates a mixing policy.
  const CurriculumMixingPolicy({
    required this.mode,
    this.reviewStages = const [],
    this.reviewRatio = 0.0,
  });

  /// Parses mixing config from JSON.
  factory CurriculumMixingPolicy.fromJson(Map<String, dynamic> json) {
    final mode = json['mode'];
    if (mode is! String || mode.isEmpty) {
      throw CurriculumException(
        'mixing.mode must be a non-empty string',
        field: 'mixing.mode',
      );
    }
    if (mode != 'exclusive' && mode != 'mixed') {
      throw CurriculumException(
        'mixing.mode must be "exclusive" or "mixed", got "$mode"',
        field: 'mixing.mode',
      );
    }

    final reviewStages = _readStringList(
      json['reviewStages'],
      field: 'mixing.reviewStages',
      required: mode == 'mixed',
    );

    final reviewRatioRaw = json['reviewRatio'];
    final reviewRatio = reviewRatioRaw == null
        ? 0.0
        : _readDouble(reviewRatioRaw, field: 'mixing.reviewRatio');

    if (reviewRatio < 0.0 || reviewRatio > 1.0) {
      throw CurriculumException(
        'mixing.reviewRatio must be between 0.0 and 1.0',
        field: 'mixing.reviewRatio',
      );
    }

    if (mode == 'mixed' && reviewStages.isEmpty) {
      throw CurriculumException(
        'mixing.reviewStages must be non-empty when mode is "mixed"',
        field: 'mixing.reviewStages',
      );
    }

    return CurriculumMixingPolicy(
      mode: mode,
      reviewStages: reviewStages,
      reviewRatio: reviewRatio,
    );
  }

  /// `exclusive` or `mixed`.
  final String mode;

  /// Stage ids sampled for review when [mode] is `mixed`.
  final List<String> reviewStages;

  /// Fraction of each batch drawn from [reviewStages] (0.0–1.0).
  final double reviewRatio;

  /// Whether only the primary stage is used.
  bool get isExclusive => mode == 'exclusive';

  /// Whether primary and review stages are interleaved.
  bool get isMixed => mode == 'mixed';

  /// Serializes this policy to JSON.
  Map<String, dynamic> toJson() {
    return {
      'mode': mode,
      if (reviewStages.isNotEmpty) 'reviewStages': reviewStages,
      if (reviewRatio > 0) 'reviewRatio': reviewRatio,
    };
  }
}

/// Declarative input for a stage builder.
class CurriculumSourceDefinition {
  /// Creates a source definition.
  const CurriculumSourceDefinition({
    required this.kind,
    this.locale,
    this.profile,
    this.storePath,
    this.combinatorial = false,
    this.variationsPerEntry,
    this.extra = const {},
  });

  /// Parses a source from JSON.
  factory CurriculumSourceDefinition.fromJson(Map<String, dynamic> json) {
    final kind = json['kind'];
    if (kind is! String || kind.isEmpty) {
      throw CurriculumException(
        'source.kind must be a non-empty string',
        field: 'sources[].kind',
      );
    }

    final extra = Map<String, dynamic>.from(json)
      ..remove('kind')
      ..remove('locale')
      ..remove('profile')
      ..remove('storePath')
      ..remove('combinatorial')
      ..remove('variationsPerEntry');

    return CurriculumSourceDefinition(
      kind: kind,
      locale: json['locale'] as String?,
      profile: json['profile'] as String?,
      storePath: json['storePath'] as String?,
      combinatorial: json['combinatorial'] as bool? ?? false,
      variationsPerEntry: _readOptionalPositiveInt(
        json['variationsPerEntry'],
        field: 'sources[].variationsPerEntry',
      ),
      extra: extra,
    );
  }

  /// Builder dispatch key (`language_basics`, `phrase_templates`, …).
  final String kind;

  /// Locale hint (`en`, `pt`, …).
  final String? locale;

  /// Profile or catalog variant name.
  final String? profile;

  /// Filesystem path for external stores (phrase templates).
  final String? storePath;

  /// When true, use combinatorial phrase expansion.
  final bool combinatorial;

  /// Meaning-preserving variations per canonical entry for this source.
  final int? variationsPerEntry;

  /// Additional builder-specific parameters.
  final Map<String, dynamic> extra;

  /// Serializes this source to JSON.
  Map<String, dynamic> toJson() {
    return {
      'kind': kind,
      if (locale != null) 'locale': locale,
      if (profile != null) 'profile': profile,
      if (storePath != null) 'storePath': storePath,
      if (combinatorial) 'combinatorial': combinatorial,
      if (variationsPerEntry != null) 'variationsPerEntry': variationsPerEntry,
      ...extra,
    };
  }
}

/// One curriculum training phase.
class CurriculumStageDefinition {
  /// Creates a stage definition.
  const CurriculumStageDefinition({
    required this.id,
    required this.order,
    required this.layersWhenActive,
    required this.dataset,
    required this.datasetVersion,
    required this.mixing,
    required this.sources,
    this.variationsPerEntry,
  });

  /// Parses a stage from JSON.
  factory CurriculumStageDefinition.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    if (id is! String || id.isEmpty) {
      throw CurriculumException(
        'stage.id must be a non-empty string',
        field: 'stages[].id',
      );
    }

    final order = json['order'];
    if (order is! int) {
      throw CurriculumException(
        'stage.order must be an int',
        field: 'stages[].order',
      );
    }

    final layersWhenActive = json['layersWhenActive'];
    if (layersWhenActive is! int || layersWhenActive <= 0) {
      throw CurriculumException(
        'stage.layersWhenActive must be a positive int',
        field: 'stages[].layersWhenActive',
      );
    }

    final dataset = json['dataset'];
    if (dataset is! String || dataset.isEmpty) {
      throw CurriculumException(
        'stage.dataset must be a non-empty string',
        field: 'stages[].dataset',
      );
    }

    final datasetVersion = json['datasetVersion'];
    if (datasetVersion is! String || datasetVersion.isEmpty) {
      throw CurriculumException(
        'stage.datasetVersion must be a non-empty string',
        field: 'stages[].datasetVersion',
      );
    }

    final mixingJson = json['mixing'];
    if (mixingJson is! Map<String, dynamic>) {
      throw CurriculumException(
        'stage.mixing must be an object',
        field: 'stages[].mixing',
      );
    }

    final sourcesJson = json['sources'];
    if (sourcesJson is! List || sourcesJson.isEmpty) {
      throw CurriculumException(
        'stage.sources must be a non-empty array',
        field: 'stages[].sources',
      );
    }

    final sources = sourcesJson.map((item) {
      if (item is! Map<String, dynamic>) {
        throw CurriculumException(
          'Each source must be an object',
          field: 'stages[].sources[]',
        );
      }
      return CurriculumSourceDefinition.fromJson(item);
    }).toList();

    return CurriculumStageDefinition(
      id: id,
      order: order,
      layersWhenActive: layersWhenActive,
      dataset: dataset,
      datasetVersion: datasetVersion,
      mixing: CurriculumMixingPolicy.fromJson(mixingJson),
      sources: sources,
      variationsPerEntry: _readOptionalPositiveInt(
        json['variationsPerEntry'],
        field: 'stages[].variationsPerEntry',
      ),
    );
  }

  /// Stable stage key stored on entries.
  final String id;

  /// Curriculum sequence index.
  final int order;

  /// Hint for external trainers: model depth for this phase.
  final int layersWhenActive;

  /// Dataset name passed to [GeneratorConfig].
  final String dataset;

  /// Dataset version passed to [GeneratorConfig].
  final String datasetVersion;

  /// Training-time mixing policy.
  final CurriculumMixingPolicy mixing;

  /// Builder inputs for this stage.
  final List<CurriculumSourceDefinition> sources;

  /// Default variations per canonical entry for sources in this stage.
  final int? variationsPerEntry;

  /// Serializes this stage to JSON.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order': order,
      'layersWhenActive': layersWhenActive,
      'dataset': dataset,
      'datasetVersion': datasetVersion,
      'mixing': mixing.toJson(),
      if (variationsPerEntry != null) 'variationsPerEntry': variationsPerEntry,
      'sources': sources.map((s) => s.toJson()).toList(),
    };
  }
}

/// Top-level curriculum manifest loaded from JSON.
class CurriculumManifest {
  /// Creates a manifest.
  const CurriculumManifest({
    required this.id,
    required this.initialLayers,
    required this.stages,
  });

  /// Parses [json] from a curriculum manifest file.
  factory CurriculumManifest.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    if (id is! String || id.isEmpty) {
      throw CurriculumException('id must be a non-empty string', field: 'id');
    }

    final initialLayers = json['initialLayers'];
    if (initialLayers is! int || initialLayers <= 0) {
      throw CurriculumException(
        'initialLayers must be a positive int',
        field: 'initialLayers',
      );
    }

    final stagesJson = json['stages'];
    if (stagesJson is! List || stagesJson.isEmpty) {
      throw CurriculumException(
        'stages must be a non-empty array',
        field: 'stages',
      );
    }

    final stages = stagesJson.map((item) {
      if (item is! Map<String, dynamic>) {
        throw CurriculumException(
          'Each stage must be an object',
          field: 'stages[]',
        );
      }
      return CurriculumStageDefinition.fromJson(item);
    }).toList();

    final ids = <String>{};
    for (final stage in stages) {
      if (!ids.add(stage.id)) {
        throw CurriculumException(
          'Duplicate stage id "${stage.id}"',
          field: 'stages[].id',
        );
      }
    }

    stages.sort((a, b) => a.order.compareTo(b.order));

    return CurriculumManifest(
      id: id,
      initialLayers: initialLayers,
      stages: stages,
    );
  }

  /// Loads a manifest from [filePath].
  static Future<CurriculumManifest> loadFile(String filePath) async {
    final file = File(filePath);
    if (!file.existsSync()) {
      throw CurriculumException('Manifest file not found: $filePath');
    }

    late final Map<String, dynamic> json;
    try {
      json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    } on FormatException catch (error) {
      throw CurriculumException('Invalid JSON in manifest', cause: error);
    }

    return CurriculumManifest.fromJson(json);
  }

  /// Manifest id.
  final String id;

  /// Starting layer count hint for trainers.
  final int initialLayers;

  /// Ordered stage definitions.
  final List<CurriculumStageDefinition> stages;

  /// Returns the stage with [stageId] or throws.
  CurriculumStageDefinition stage(String stageId) {
    for (final stage in stages) {
      if (stage.id == stageId) {
        return stage;
      }
    }
    throw CurriculumException('Unknown stage id "$stageId"');
  }

  /// Serializes this manifest to JSON.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'initialLayers': initialLayers,
      'stages': stages.map((s) => s.toJson()).toList(),
    };
  }
}

List<String> _readStringList(
  Object? value, {
  required String field,
  required bool required,
}) {
  if (value == null) {
    if (required) {
      throw CurriculumException('Expected JSON array for $field', field: field);
    }
    return const [];
  }
  if (value is! List) {
    throw CurriculumException('Expected JSON array for $field', field: field);
  }
  return value.map((item) {
    if (item is! String || item.isEmpty) {
      throw CurriculumException(
        'Expected non-empty strings in $field',
        field: field,
      );
    }
    return item;
  }).toList();
}

double _readDouble(Object value, {required String field}) {
  if (value is num) {
    return value.toDouble();
  }
  throw CurriculumException('Expected number for $field', field: field);
}

int? _readOptionalPositiveInt(Object? value, {required String field}) {
  if (value == null) {
    return null;
  }
  if (value is! int || value < 0) {
    throw CurriculumException(
      '$field must be a non-negative int',
      field: field,
    );
  }
  return value == 0 ? null : value;
}
