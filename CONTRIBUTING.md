# Contributing

## Setup

```sh
git clone https://github.com/OmnyGrid/llm_dataset.git
cd llm_dataset
dart pub get
```

## Before opening a PR

```sh
dart format lib test example
dart analyze --fatal-infos --fatal-warnings .
dart test
dart run dependency_validator
```

CI runs the same checks plus `dart doc --dry-run`, `dart pub publish --dry-run`, and coverage upload to Codecov.

## Conventions

- **Public API** — export new types from `lib/llm_dataset.dart` (or an existing barrel such as `curriculum_api.dart`).
- **Metadata keys** — add constants to `ExerciseMetadataKeys` or `TextExerciseMetadata`; document in `doc/ARCHITECTURE.md`.
- **Exercise modules** — implement `ExerciseCatalog<T>` and use `CatalogExerciseGenerator` for generators.
- **Tests** — mirror `lib/src/` layout; put shared JSON under `test/fixtures/`, not `example/`.
- **Examples** — one concern per file; index in `example/README.md`.

## Curriculum rebuilds

`CurriculumBuilder` defaults `failIfVersionExists: true` (same as `DatasetPipeline`). Pass `failIfVersionExists: false` when rebuilding into an existing store, or delete the target dataset version first.
