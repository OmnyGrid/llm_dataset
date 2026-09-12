# Progressive curriculum training

This example demonstrates building and consuming a **multi-stage curriculum**
for shallow progressive layer training. Training logic (plateau detection,
freezing layers) stays in your trainer; this package builds, tags, queries,
and exports phase slices.

## Manifest

[`curriculum.json`](curriculum.json) defines six stages:

| Stage | Layers (hint) | Content |
|-------|---------------|---------|
| `language_basics` | 2 | Simple noun/verb templates |
| `phrases` | 4 | Phrase templates (non-combinatorial by default) |
| `paragraphs` | 6 | Multi-sentence paragraphs |
| `math` | 8 | Arithmetic, word problems, step solutions |
| `logic` | 10 | Syllogisms, sequences, classification |
| `coding` | 12 | Python coding exercises |

Each stage sets `mixing.mode`:

- **exclusive** — only that stage's entries (initial phase).
- **mixed** — interleave primary stage with `reviewStages` at `reviewRatio`.

Every entry is tagged with metadata keys: `curriculumId`, `curriculumStage`,
`curriculumStageOrder`, and `complexityTier`.

### Variations

Enable meaning-preserving lexicon variations for text exercise sources
(`language_basics`, `phrase_templates`, `paragraph_catalog`) via builder options,
stage defaults, or per-source manifest fields:

```json
"variationsPerEntry": 2
```

Priority: source → stage → `CurriculumBuilder.variationOptions`. Combinatorial
phrase expansion skips variations automatically.

## Build

From the repository root:

```bash
dart run example/curriculum/build_curriculum.dart curriculum.db
```

Set `"combinatorial": true` on the phrases source in the manifest for full
cross-product expansion (can produce tens of millions of entries).

## Train a phase

```bash
dart run example/curriculum/train_phase.dart phrases curriculum.db
```

This streams mixed batches for the `phrases` phase (85% phrases, 15%
`language_basics` review by default).

## Trainer integration

1. `CurriculumBuilder.buildAll()` — populate SQLite once.
2. On plateau, read `manifest.stages[next].layersWhenActive`.
3. `CurriculumLifecycle.exportStageJsonl(stageId, path)` — export JSONL.
4. Train new layers only in your trainer.

Use `TrainingPhaseDescriptor` from `CurriculumBuildResult.phaseDescriptor()`
for a structured export contract.
