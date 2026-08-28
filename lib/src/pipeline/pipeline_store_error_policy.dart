/// How [DatasetPipeline] handles store failures while persisting entries.
enum PipelineStoreErrorPolicy {
  /// Abort the pipeline immediately when [DatasetStore.add] fails.
  abort,

  /// Record the store failure and continue with remaining entries.
  continueProcessing,
}
