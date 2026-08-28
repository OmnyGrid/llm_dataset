/// Options passed by [DatasetPipeline] when invoking variation generators.
class VariationGenerateOptions {
  /// Creates generation options for a variation generator invocation.
  const VariationGenerateOptions({
    this.startVariationIndex = 1,
    this.instanceId,
  });

  /// First [DatasetEntry.variationIndex] to assign in this batch.
  final int startVariationIndex;

  /// Distinguishes multiple generator instances in one pipeline.
  final String? instanceId;
}

/// Default options when callers invoke generators directly.
const VariationGenerateOptions defaultVariationGenerateOptions =
    VariationGenerateOptions();
