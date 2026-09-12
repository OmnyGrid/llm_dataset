import 'dart:io';

/// Repo-root relative paths for shared test fixtures.
abstract final class TestPaths {
  static String get repoRoot => Directory.current.path;

  static String get curriculumManifest =>
      '$repoRoot/test/fixtures/curriculum/curriculum.json';

  static String get phraseTemplatesEn =>
      '$repoRoot/test/fixtures/phrase_templates/en';
}
