import 'package:llm_dataset/llm_dataset.dart';
import 'package:test/test.dart';

DatasetEntry entry({
  String id = 'e1',
  String input = 'hello world',
  String? output = 'ok',
  String language = 'en',
  Map<String, dynamic> metadata = const {},
}) {
  return DatasetEntry(
    id: id,
    dataset: 'd',
    type: DatasetEntryType.text,
    language: language,
    input: input,
    output: output,
    variationGroup: 'g',
    variationIndex: 0,
    metadata: metadata,
    createdAt: DateTime.utc(2024),
  );
}

void main() {
  test('EmptyContentValidator', () async {
    final v = EmptyContentValidator(requireOutput: true);
    expect((await v.validate(entry(input: '  '))).isValid, isFalse);
    expect((await v.validate(entry(output: ''))).isValid, isFalse);
    expect((await v.validate(entry())).isValid, isTrue);
  });

  test('DuplicateValidator stream and store', () async {
    final store = MemoryDatasetStore();
    await store.add(entry(id: 'existing'));
    final v = DuplicateValidator(store: store, checkContentFingerprint: true);

    expect((await v.validate(entry(id: 'existing'))).isValid, isFalse);
    expect((await v.validate(entry(id: 'new'))).isValid, isTrue);
    expect(
      (await v.validate(entry(id: 'new2'))).isValid,
      isFalse,
    ); // fingerprint
  });

  test('MetadataValidator', () async {
    final v = MetadataValidator(
      requiredKeys: ['topic'],
      forbiddenKeys: ['secret'],
    );
    expect((await v.validate(entry())).isValid, isFalse);
    expect(
      (await v.validate(entry(metadata: {'topic': 'a', 'secret': true})))
          .isValid,
      isFalse,
    );
    expect((await v.validate(entry(metadata: {'topic': 'a'}))).isValid, isTrue);
  });

  test('LanguageValidator', () async {
    final v = LanguageValidator({'en', 'fr'});
    expect((await v.validate(entry(language: 'de'))).isValid, isFalse);
    expect((await v.validate(entry(language: 'en'))).isValid, isTrue);
  });

  test('LengthValidator', () async {
    final v = LengthValidator(minInputLength: 5, maxOutputLength: 2);
    expect((await v.validate(entry(input: 'hi'))).isValid, isFalse);
    expect((await v.validate(entry(output: 'toolong'))).isValid, isFalse);
  });

  test('TokenCountValidator', () async {
    final v = TokenCountValidator(minInputTokens: 3, maxOutputTokens: 1);
    expect((await v.validate(entry(input: 'one two'))).isValid, isFalse);
    expect(
      (await v.validate(entry(input: 'a b c', output: 'x y'))).isValid,
      isFalse,
    );
  });

  test('CompositeValidator merges', () async {
    final v = CompositeValidator([
      EmptyContentValidator(),
      LanguageValidator({'en'}),
    ]);
    final bad = await v.validate(entry(language: 'es', input: ''));
    expect(bad.isValid, isFalse);
    expect(bad.messages.length, greaterThanOrEqualTo(2));
  });
}
