# Architecture

## Module layout

```text
lib/
├── llm_dataset.dart              # public barrel
└── src/
    ├── model/                    # DatasetEntry, metadata keys, provenance
    ├── source/                   # document sources
    ├── generator/                # DatasetGenerator + built-ins
    ├── variation/                # surface-form and translation variations
    ├── validation/               # composable validators
    ├── pipeline/                 # DatasetPipeline orchestration
    ├── store/                    # Memory + SQLite stores, lifecycle, capabilities
    ├── query/                    # fluent DatasetQuery
    ├── serialization/            # JSON / JSONL codec
    ├── training/                 # Dataset batch streaming
    ├── exercise/                 # shared catalog + generator mixins
    ├── text_exercise/            # phrases, paragraphs, template store
    ├── curriculum/               # manifest, builder, mixing, lifecycle
    ├── language_basics/          # simplest phrase drills (stage 0)
    ├── math_exercise/
    ├── logic_exercise/
    └── coding_exercise/
```

## Data flow

```text
DatasetSource → DatasetPipeline → DatasetStore → Dataset / CurriculumDataset
                      ↑
              CurriculumBuilder (tags + per-stage sources)
```

## Phrase data tiers

Three complementary phrase sources serve different purposes:

| Tier | Location | Use |
|------|----------|-----|
| **Language basics** | `language_basics/` | Smallest patterns for curriculum stage 0 (`textKind: language_basics`) |
| **Hardcoded library** | `phrase_template_library.dart` | Built-in EN/PT templates for examples and tests without JSON files |
| **JSON template store** | `PhraseTemplateStore` + on-disk manifest | Large combinatorial corpora (`example/phrase_templates/`, `test/fixtures/phrase_templates/`) |

Language basics intentionally stays separate from the full phrase pipeline so early training stages stay small and fast to build.

## Metadata schema

| Key | Constant | Used by |
|-----|----------|---------|
| `curriculumId` | `CurriculumMetadataKeys.curriculumId` | Curriculum tagging |
| `curriculumStage` | `CurriculumMetadataKeys.curriculumStage` | Curriculum tagging |
| `curriculumStageOrder` | `CurriculumMetadataKeys.curriculumStageOrder` | Curriculum tagging |
| `complexityTier` | `ExerciseMetadataKeys.complexityTier` | All exercise modules |
| `exerciseKind` | `ExerciseMetadataKeys.exerciseKind` | Math, logic, coding |
| `patternId` | `ExerciseMetadataKeys.patternId` | All exercise modules |
| `textKind` | `TextExerciseMetadata.textKind` | Phrase / paragraph / language basics |

## Curriculum consumption

- `CurriculumDataset.exclusive(stage)` — entries tagged for one stage only.
- `CurriculumDataset.mixed(stage)` — returns [CurriculumPhaseDataset] which interleaves review stages in `stream()` / `batches()` when the manifest mixing mode is `mixed`.
- `CurriculumDataset.streamPhase` / `batchesPhase` — same mixing semantics without wrapping [Dataset].

Plateau detection and layer freezing remain outside this package (in your trainer).

## Test fixtures

Integration and curriculum tests load manifests and phrase templates from `test/fixtures/`. Examples under `example/` remain user-facing demos and may reference `example/phrase_templates/`.
