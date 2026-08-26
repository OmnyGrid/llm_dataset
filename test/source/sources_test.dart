import 'dart:io';

import 'package:llm_dataset/llm_dataset.dart';
import 'package:test/test.dart';

void main() {
  group('MemorySource', () {
    test('yields documents in order', () async {
      final docs = [
        DatasetSourceDocument(id: 'a', content: 'A'),
        DatasetSourceDocument(id: 'b', content: 'B', title: 'Bee'),
      ];
      final loaded = await MemorySource(docs).load().toList();
      expect(loaded.map((d) => d.id), ['a', 'b']);
      expect(loaded[1].title, 'Bee');
    });
  });

  group('DirectorySource', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('llm_dataset_dir_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('streams files without requiring preload of all contents', () async {
      await File('${tempDir.path}/one.txt').writeAsString('first');
      await File('${tempDir.path}/two.txt').writeAsString('second');
      await File('${tempDir.path}/skip.md').writeAsString('markdown');

      final source = DirectorySource(tempDir.path, extensions: {'.txt'});
      final docs = await source.load().toList();
      expect(docs, hasLength(2));
      expect(docs.map((d) => d.title).toSet(), {'one.txt', 'two.txt'});
      expect(docs.map((d) => d.content).toSet(), {'first', 'second'});
      expect(docs.first.metadata.containsKey('path'), isTrue);
    });

    test('recursive lists nested files', () async {
      final nested = Directory('${tempDir.path}/sub')..createSync();
      await File('${nested.path}/nested.txt').writeAsString('nested');
      await File('${tempDir.path}/root.txt').writeAsString('root');

      final docs = await DirectorySource(
        tempDir.path,
        recursive: true,
      ).load().toList();
      expect(docs, hasLength(2));
      expect(docs.map((d) => d.id).toSet(), contains('sub/nested.txt'));
    });

    test('missing directory throws', () async {
      final missing = '${tempDir.path}/does-not-exist';
      expect(
        () => DirectorySource(missing).load().toList(),
        throwsA(isA<FileSystemException>()),
      );
    });
  });

  group('JsonlSource', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('llm_dataset_jsonl_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('parses lines incrementally', () async {
      final file = File('${tempDir.path}/docs.jsonl');
      await file.writeAsString(
        [
          '{"id":"1","content":"hello","title":"T","language":"en","tag":"x"}',
          '',
          '{"id":"2","text":"world","metadata":{"k":1}}',
        ].join('\n'),
      );

      final docs = await JsonlSource(file.path).load().toList();
      expect(docs, hasLength(2));
      expect(docs[0].id, '1');
      expect(docs[0].content, 'hello');
      expect(docs[0].title, 'T');
      expect(docs[0].language, 'en');
      expect(docs[0].metadata['tag'], 'x');
      expect(docs[1].content, 'world');
      expect(docs[1].metadata['k'], 1);
    });

    test(
      'streams many lines without reading whole file as one string',
      () async {
        final file = File('${tempDir.path}/large.jsonl');
        final sink = file.openWrite();
        for (var i = 0; i < 500; i++) {
          sink.writeln('{"id":"$i","content":"doc-$i"}');
        }
        await sink.close();

        var count = 0;
        await for (final doc in JsonlSource(file.path).load()) {
          expect(doc.id, '$count');
          count++;
        }
        expect(count, 500);
      },
    );

    test('malformed JSON fails explicitly', () async {
      final file = File('${tempDir.path}/bad.jsonl');
      await file.writeAsString('{"id":"1","content":"ok"}\n{not-json}\n');
      expect(
        () => JsonlSource(file.path).load().toList(),
        throwsA(isA<FormatException>()),
      );
    });

    test('missing id fails explicitly', () async {
      final file = File('${tempDir.path}/noid.jsonl');
      await file.writeAsString('{"content":"x"}\n');
      expect(
        () => JsonlSource(file.path).load().toList(),
        throwsA(isA<FormatException>()),
      );
    });

    test('missing file throws', () {
      expect(
        () => JsonlSource('${tempDir.path}/missing.jsonl').load().toList(),
        throwsA(isA<FileSystemException>()),
      );
    });
  });
}
