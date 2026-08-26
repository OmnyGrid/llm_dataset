import 'package:llm_dataset/llm_dataset.dart';
import 'package:test/test.dart';

void main() {
  DatasetEntry parent() => DatasetEntry(
    id: 'parent',
    dataset: 'general',
    type: DatasetEntryType.text,
    language: 'en',
    input: 'What is the capital of France?',
    output: 'Paris',
    variationGroup: 'abc123',
    variationIndex: 0,
    metadata: {'topic': 'geo'},
    provenance: const DatasetProvenance(
      source: 'manual',
      generator: 'author',
      generatorVersion: '1',
    ),
    createdAt: DateTime.utc(2024, 1, 1),
  );

  test('preserves group, indexes, parent, metadata', () async {
    final variations = await RuleBasedVariationGenerator(
      strategies: [VariationStrategy.paraphrase, VariationStrategy.formal],
    ).generate(parent());

    expect(variations, hasLength(2));
    expect(variations.map((v) => v.variationIndex), [1, 2]);
    for (final v in variations) {
      expect(v.variationGroup, 'abc123');
      expect(v.provenance?.parentEntryId, 'parent');
      expect(v.metadata['topic'], 'geo');
      expect(v.dataset, 'general');
      expect(v.type, DatasetEntryType.text);
      expect(v.language, 'en');
      expect(v.isCanonical, isFalse);
    }
  });

  test('deterministic seed shuffles strategies stably', () async {
    final gen = RuleBasedVariationGenerator(
      strategies: VariationStrategy.values,
      seed: 7,
    );
    final a = await gen.generate(parent());
    final b = await gen.generate(parent());
    expect(
      a.map((e) => e.metadata['variationStrategy']),
      b.map((e) => e.metadata['variationStrategy']),
    );
    expect(a.map((e) => e.id), b.map((e) => e.id));
  });

  test('supports all strategies', () async {
    final variations = await RuleBasedVariationGenerator(
      strategies: VariationStrategy.values,
    ).generate(parent());
    expect(variations, hasLength(VariationStrategy.values.length));
  });
}
