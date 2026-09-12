# Phrase template file store

JSON dataset for category-driven phrase templates. Loaded by
[`PhraseTemplateStoreLoader`](../../lib/src/text_exercise/phrase_template_store_loader.dart)
from the `llm_dataset` package API.

## Layout

```
phrase_templates/
└── en/
    ├── manifest.json          # index of word sets + template groups
    ├── words/                 # one file per word category
    │   ├── actor.json
    │   ├── action.json
    │   └── ...
    └── templates/             # one file per template type
        ├── development.json
        ├── learning.json
        └── ...
```

## Word set file (`words/*.json`)

Each file defines one **category** with lemma keys and synonym surface forms.
The first form is the canonical default used by [PhraseGenerator].

```json
{
  "category": "actor",
  "description": "People who perform actions",
  "words": {
    "developer": ["developer", "engineer", "programmer"],
    "team": ["team", "group", "crew"]
  }
}
```

## Template group file (`templates/*.json`)

Each file defines one **template type** (theme) with many phrase patterns.

```json
{
  "group": "development",
  "description": "Software development phrases",
  "templates": [
    {
      "id": "ext-action-object",
      "template": "The {subject} {adverb} {verb} the {object}.",
      "structureVariants": [
        "{adverb}, the {subject} {verb} the {object}.",
        "The {object} is {adverb} {verb} by the {subject}."
      ],
      "slotCategories": {
        "subject": "actor",
        "adverb": "manner",
        "verb": "action",
        "object": "thing"
      }
    }
  ]
}
```

## Adding content

1. Add or edit a file under `words/` or `templates/`.
2. Register the path in `en/manifest.json`.
3. Run `dart run example/phrase_template_categories.dart`.

The loader validates:

- every `slotCategories` value references an existing word category
- template ids are globally unique
- lemma synonym lists do not conflict across files
- every structural variant uses the same `{slot}` placeholders as `slotCategories`

## Run

```bash
dart run example/phrase_template_categories.dart
```
