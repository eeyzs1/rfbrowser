# Meta-Mistake Log

## Purpose
Log mistakes in the META-HARNESS itself — not in generated projects.
When the meta-harness generates a bad harness, that's a meta-mistake.
Meta-mistakes improve the generation pipeline, not individual projects.

## Format
```
## Meta-Mistake [N]
- Date: [when]
- Trigger: [what intent caused the bad generation]
- What went wrong: [what the generated harness got wrong]
- Root cause: [WHY the meta-harness made this mistake]
- Fix: [what changed in meta/ or templates/]
- Status: Resolved / Recurring / BLOCKER
```

## Meta-Mistakes

### Meta-Mistake 1
- Date: 2026-04-14
- Trigger: Initial project setup
- What went wrong: Templates generated only markdown descriptions, not executable artifacts
- Root cause: Template format was "description framework" instead of "generation factory" — templates listed what should exist but didn't specify executable artifacts per layer
- Fix: Upgraded all 5 templates to "Generation Factory" format with explicit per-layer executable artifact lists; created seeds/ directory with concrete template files (Python scripts, YAML configs, JSON schemas)
- Status: Resolved

### Meta-Mistake 2
- Date: 2026-04-14
- Trigger: Initial project setup
- What went wrong: ADR-001 documented 5-layer architecture but actual design had evolved to 7+2
- Root cause: ADR was written before architecture evolved and never updated
- Fix: Updated ADR-001 to reflect 7 layers + 2 cross-cutting + self-evolution architecture
- Status: Resolved

### Meta-Mistake 3
- Date: 2026-04-14
- Trigger: Running scripts on Windows
- What went wrong: All utility scripts were bash-only, couldn't run on Windows
- Root cause: Original scripts written for Unix without cross-platform consideration
- Fix: Created Python equivalents (verify.py, pre-task.py, quality-score.py) that work on Windows/macOS/Linux
- Status: Resolved

### Meta-Mistake 4
- Date: 2026-05-04
- Trigger: Search feature testing — "no such column: T.content" error
- What went wrong: IndexStore FTS5 table generated with content-table mode (`content=notes`) but the `notes` table lacked a `content` column, causing every search query to fail
- Root cause: The index_store template didn't align the FTS5 virtual table schema with the main table schema. Generated code had mismatched columns.
- Fix: Remove content-table mode from FTS5 creation; make FTS5 standalone with its own column set. Add schema versioning (v1→v2) with onUpgrade handler. Update generation template to validate SQL schema alignment.
- Status: Resolved

### Meta-Mistake 5
- Date: 2026-05-04
- Trigger: Plugin API Bridge testing — services returning empty/hardcoded data
- What went wrong: PluginHost._handleApiCall returned hardcoded stubs for knowledge.getNote, knowledge.search, browser.getCurrentUrl instead of reading from real providers via Riverpod ref
- Root cause: The plugin host template treated API calls as stub implementations. It didn't wire `ref.read(provider)` to connect to real service layers.
- Fix: Rewrite _handleApiCall to use `ref.read(noteRepositoryProvider)`, `ref.read(indexStoreProvider)`, `ref.read(browserProvider)`. Update plugin_host template to use Riverpod provider integration for all API endpoints.
- Status: Resolved

### Meta-Mistake 6
- Date: 2026-05-04
- Trigger: Agent "Create note" step testing — no notes created on disk
- What went wrong: Agent._executeStep treated "Create note:" as a string transformation step only. Notes were never persisted via KnowledgeNotifier.
- Root cause: Agent template modeled steps as pure text/LLM operations without integration to service layer. The create/mutate steps were write-only to step output, not to data stores.
- Fix: Wire "Create note:" step to KnowledgeNotifier.createNote → updateActiveNoteContent → saveActiveNote. Update agent template to distinguish read steps from write steps, requiring service integration for write operations.
- Status: Resolved

### Meta-Mistake 7
- Date: 2026-05-04
- Trigger: Local embedding quality audit — toy character-code modulo
- What went wrong: EmbeddingService._embedLocally used `chars[i] % dimensions` which produces random-walk vectors with no semantic meaning. Related words had zero similarity, unrelated words could have high similarity.
- Root cause: The embedding template used a toy placeholder that was never intended for production. It treated character codes as semantics.
- Fix: Replace with character n-gram hashing (unigram + bigram + trigram) with length-agnostic text. Words now share dimensions based on shared substrings. Update embedding template to require semantic-aware fallback (char n-grams minimum, TF-IDF preferred).
- Status: Resolved

### Meta-Mistake 8
- Date: 2026-05-04
- Trigger: HybridSearch results only semantic — keyword search never executed
- What went wrong: hybridSearchProvider created HybridSearch without injecting ftsSearchFn. HybridSearch fell through to semantic-only path because no FTS function was provided.
- Root cause: The provider template wired HybridSearch to SemanticSearch but forgot to inject the keyword/FTS search function. This was a missing dependency connection in the provider wiring.
- Fix: Inject `ftsSearchFn: (query, {limit}) => indexStore.searchNotes(query, limit: limit)` into HybridSearch constructor. Update provider template to enforce all constructor dependencies are satisfied.
- Status: Resolved
