/// Infrastructure for generating, storing, querying, and consuming LLM
/// training datasets.
///
/// This package is dataset infrastructure, not an LLM training engine. It is
/// provider-independent and stream-oriented for large corpora.
library;

export 'src/exercise/catalog_exercise_generator.dart';
export 'src/exercise/exercise_catalog.dart';
export 'src/generator/builtin_generators.dart';
export 'src/generator/dataset_generator.dart';
export 'src/model/dataset_entry.dart';
export 'src/model/dataset_entry_type.dart';
export 'src/model/dataset_provenance.dart';
export 'src/model/dataset_tool_call.dart';
export 'src/model/exercise_metadata.dart';
export 'src/pipeline/dataset_pipeline.dart';
export 'src/pipeline/pipeline_store_error_policy.dart';
export 'src/query/dataset_query.dart';
export 'src/serialization/dataset_codec.dart';
export 'src/source/dataset_source.dart';
export 'src/source/directory_source.dart';
export 'src/source/jsonl_source.dart';
export 'src/source/memory_source.dart';
export 'src/store/dataset_lifecycle.dart';
export 'src/store/dataset_store.dart';
export 'src/store/dataset_store_capabilities.dart';
export 'src/store/memory_dataset_store.dart';
export 'src/store/sqlite_dataset_store.dart';
export 'src/curriculum/curriculum_api.dart';
export 'src/text_exercise/meaning_variation_generator.dart';
export 'src/text_exercise/paragraph_generator.dart';
export 'src/text_exercise/phrase_generator.dart';
export 'src/text_exercise/text_build.dart';
export 'src/text_exercise/phrase_template_library.dart';
export 'src/text_exercise/phrase_template_store_api.dart';
export 'src/text_exercise/text_exercise_catalog.dart';
export 'src/text_exercise/text_lexicon.dart';
export 'src/text_exercise/word_category_bank.dart';
export 'src/training/dataset.dart';
export 'src/validation/builtin_validators.dart';
export 'src/validation/dataset_validator.dart';
export 'src/variation/dataset_variation_generator.dart';
export 'src/variation/rule_based_variation_generator.dart';
export 'src/variation/translation_variation_generator.dart';
export 'src/variation/variation_generate_options.dart';
