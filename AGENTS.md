# RFBrowser — AGENT OPERATING INSTRUCTIONS

## What This Project Is

RFBrowser is a **Flutter desktop application** — an AI-powered knowledge browser.
It is NOT a meta-harness generation pipeline. It IS the actual application.
Your job is to help build, debug, and improve this Flutter app.

## Project Context

RFBrowser = Web Browser + Markdown Note Editor + Knowledge Graph + AI Chat + Infinite Canvas.

Key technical facts:
- Flutter 3.27+ with Dart 3.11+
- State management: Riverpod (with code generation via riverpod_generator)
- WebView: flutter_inappwebview (Chromium-based on Windows/Android, WebKit on Linux)
- Database: SQLite (sqflite) for search index, Hive for cache
- File format: Pure Markdown (.md) with YAML frontmatter — compatible with Obsidian/Foam
- Sync: Git CLI + WebDAV

## First Principles

1. **Understand before acting.** Read the relevant source files before making changes.
2. **Chase root causes, never patch symptoms.** Every fix should answer "why".
3. **Follow existing conventions.** Match code style, patterns, and library usage of adjacent files.
4. **Write tests for new logic.** Test files go in `test/` mirroring the `lib/` structure.

## Automated Harness Execution (AI Agent MUST Follow)

The project has a self-evolving harness system at `seeds/`. As the AI agent, you MUST execute
these steps **automatically** — the user should never need to type these commands.

### Task Start Protocol (AUTOMATIC — before any code change)

1. Run `python seeds/orchestrator.py --status` to load current project state.
2. Run `python seeds/orchestrator.py --check-constraints` to scan for genome constraint violations.
3. If violations exist with severity=high, they MUST be the first thing fixed.
4. Read `seeds/evolution/genome.yaml` constraints relevant to the files you're about to touch.
5. Check `seeds/memory/session-state.yaml` for any in-progress criteria.

### During Task (AUTOMATIC — after each batch of file edits)

1. Run `flutter analyze` after every logical batch of changes.
2. If a change introduces a mistake, immediately add it to `seeds/memory/meta-mistakes.md`.
3. Cross-reference AGENTS.md rules (P-1 through UX-7) for every method you write.
4. Check `seeds/evolution/genome.yaml` constraint trigger_count — if you see a violation, increment it.

### Task Completion Protocol (AUTOMATIC — before declaring done)

1. Run `flutter analyze` — MUST pass with 0 issues.
2. Run `python seeds/orchestrator.py --verify` to run verification layer.
3. Update `seeds/memory/session-state.yaml`:
   - Mark completed criteria as complete
   - Update `completed` count
   - Set status to "solid" if all criteria met
4. Run `python seeds/orchestrator.py --status` to confirm 10/10 or explain why not.

### Key Files the Agent Must Reference

| File | When to Read |
|------|-------------|
| `seeds/evolution/genome.yaml` | Before touching any module — check constraints for that layer |
| `seeds/memory/session-state.yaml` | At task start and completion |
| `seeds/memory/meta-mistakes.md` | When you cause or discover an error |
| `seeds/evolution/domain-advancements.yaml` | When proposing new features |
| `task.yaml` | At task start — defines acceptance criteria |

## Architecture (Quick Reference)

```
UI (lib/ui/)        → pages (Browser, Editor, Graph, Canvas, Settings, AI Chat)
                       widgets (CommandBar, Backlinks, NoteSidebar, SplitPane, etc.)
Service (lib/services/) → ai_service, agent_service, browser_service, knowledge_service,
                          git_sync_service, webdav_sync_service, clipper_service, etc.
Core (lib/core/)       → graph algorithms, link extractor/resolver, context assembler,
                          markdown highlighter, editor controllers
Data (lib/data/)       → models (Note, Link, AgentTask, Skill, QuickMove, etc.)
                          stores (IndexStore, SyncStore, VaultStore, HNSW, Vector)
                          repositories (NoteRepository)
Platform (lib/platform/) → WebView managers (inline agent_webview, headless_manager)
Plugins (lib/plugins/) → Plugin host + API + builtin Dataview
```

## Absolute Rules

1. No execution without reading the relevant source first
2. No Flutter widget changes without testing on the platform they target
3. Follow the Riverpod pattern: Notifier + State + Provider
4. Null-check API responses defensively at every level
5. Destructive actions (delete, clear) MUST require confirmation
6. API keys MUST NOT be stored in observable state objects — use flutter_secure_storage
7. WebView MUST filter dangerous URL schemes (`file://`, `javascript:`, `data:`)
8. Always run `flutter analyze` before committing — 0 issues is the hard threshold
9. Before starting ANY task, run `python seeds/orchestrator.py --status` + `--check-constraints`
10. New features need at least one user-accessible trigger (button, menu, shortcut, or command)

## Learned Lessons (Evidence-Driven Evolution)

### Performance
- **P-1**: Never persist to disk on every frame (drag/resize). Use in-memory updates + debounced save (500ms) + explicit persist on end.
- **P-2**: `CustomPainter.shouldRepaint` must compare actual data, not just return `true`. Otherwise continuous 60fps repaints waste CPU.
- **P-3**: Cache `SharedPreferences.getInstance()` rather than calling it in every setter.

### Correctness
- **C-1**: API response parsing must be defensive — null-check every level of nested access.
- **C-2**: Concurrent state mutations must be guarded. Check `isLoading` before allowing new operations.
- **C-3**: When closing a tab/item from a list, calculate the new active index BEFORE removing the item.
- **C-4**: `copyWith` cannot set nullable fields to null using `?? this.field`. Use sentinel values or explicit clear flags.

### Security
- **S-1**: WebView must filter dangerous URL schemes in `shouldOverrideUrlLoading`.
- **S-2**: API keys should not be stored in observable state objects. Read from secure storage only when needed.
- **S-3**: Path sanitization with `replaceAll('..', '')` is insufficient. Use path normalization + validation.

### Architecture
- **A-1**: Every component should have at least one data flow path to another component. Isolated silos are a design smell.
- **A-2**: Shared utility functions belong on the model/enum as getters, not duplicated across UI files.
- **A-3**: Dialog code identical across pages should be extracted into a shared function or widget.
- **A-4**: Separate concerns in state management — UI theme and AI config change for different reasons.
- **A-5**: Canvas cards with noteId should render live note data, not static snapshots.
- **A-6**: Auto-discovered connections (wikilink) must be visually distinct from manual ones.
- **A-7**: Canvas persistence should use file system (.json in vault/.rf/) for Git traceability.

### UI
- **U-1**: Error dismiss buttons must actually clear the error state.
- **U-2**: Canvas clipping must happen BEFORE drawing (save → clip → draw → restore).
- **U-3**: Row overflow in constrained spaces must use `Flexible` + `TextOverflow.ellipsis`.

### Flutter-Specific
- **F-1**: `DropdownButtonFormField.value` deprecated in 3.41+. Use with ignore comment + `ValueKey`.
- **F-2**: `Matrix4.translate()`/`scale()` deprecated. Set matrix entries directly.
- **F-3**: `Offset.toVector3()` doesn't exist — use `Matrix4.inverted().entry(row, col)`.
- **F-4**: `flutter_markdown` `ExtensionSet` has no `copyWith` — create new instance manually.
- **F-5**: `MarkdownElementBuilder.visitElementAfterWithContext` takes 4 params, returns `Widget?`.
- **F-6**: `BoxDecoration.borderLeft` doesn't exist — use `Border(left: ...)`.
- **F-7**: Never assign `TextEditingController.text` inside `build()` unconditionally.
- **F-8**: `Markdown` widget doesn't accept `scrollController` — use `MarkdownBody`.

### Product UX
- **UX-1**: Every backend service must have at least one user-accessible trigger.
- **UX-2**: Empty states must guide the user toward the next action with a call-to-action.
- **UX-3**: Destructive actions require confirmation.
- **UX-4**: AI streaming output is a core UX expectation — users should see tokens in real-time.
- **UX-5**: Command bar is the primary navigation hub — it must search actual data, not hardcoded suggestions.
- **UX-6**: If LinkExtractor/LinkResolver exist but aren't called, graph and backlinks are empty.
- **UX-7**: Keyboard shortcuts must cover top 5 actions: search, new note, save, switch view, daily note.
