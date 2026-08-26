import 'dataset_source.dart';

/// [DatasetSource] that yields an in-memory collection of documents.
class MemorySource implements DatasetSource {
  /// Creates a source from [documents].
  MemorySource(Iterable<DatasetSourceDocument> documents)
    : _documents = List<DatasetSourceDocument>.unmodifiable(documents);

  final List<DatasetSourceDocument> _documents;

  @override
  Stream<DatasetSourceDocument> load() async* {
    for (final document in _documents) {
      yield document;
    }
  }
}
