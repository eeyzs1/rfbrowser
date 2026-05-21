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
- Database: SQLite (sqflite) for search index (in vault/.rfbrowser/index.db)
- File format: Pure Markdown (.md) with YAML frontmatter — compatible with Obsidian/Foam
- Sync: Git CLI + WebDAV
- App config: JSON files in ApplicationSupport directory (not SharedPreferences)
- Vault data: All vault-specific data stored in <vault>/.rfbrowser/ directory

## First Principles

1. **Understand before acting.** Read the relevant source files before making changes.
2. **Chase root causes, never patch symptoms.** Every fix should answer "why".
3. **Follow existing conventions.** Match code style, patterns, and library usage of adjacent files.
4. **Write tests for new logic.** Test files go in `test/` mirroring the `lib/` structure.

## Automated Harness Execution (AI Agent MUST Follow)

The project has a lightweight harness system at `seeds/`. As the AI agent, you MUST execute
these steps **automatically** — the user should never need to type these commands.

### Task Start Protocol (AUTOMATIC — before any code change)

1. Run `python seeds/orchestrator.py --status` to load current project state.
2. Run `python seeds/orchestrator.py --check-constraints` to scan for genome constraint violations.
3. If violations exist with severity=high, they MUST be the first thing fixed.
4. Check `seeds/memory/session-state.yaml` for any in-progress criteria.

### During Task (AUTOMATIC — after each batch of file edits)

1. Run `flutter analyze` after every logical batch of changes.
2. If a change introduces a mistake, immediately add it to `seeds/memory/meta-mistakes.md`.
3. Cross-reference AGENTS.md rules (P-1 through UX-15) for every method you write.

### Task Completion Protocol (AUTOMATIC — before declaring done)

1. Run `flutter analyze` — MUST pass with 0 issues.
2. Run `python seeds/orchestrator.py --verify` to run verification layer.
3. Update `seeds/memory/session-state.yaml`:
   - Mark completed criteria as complete
   - Update `completed` count
   - Set status to "solid" if all criteria met
4. Run `python seeds/orchestrator.py --status` to confirm completion or explain why not.

### Key Files the Agent Must Reference

| File | When to Read |
|------|-------------|
| `seeds/evolution/genome.yaml` | Before touching any module — check constraints for that layer |
| `seeds/memory/session-state.yaml` | At task start and completion |
| `seeds/memory/meta-mistakes.md` | When you cause or discover an error |
| `seeds/evolution/domain-advancements.yaml` | When proposing new features |
| `task.yaml` | At task start — defines acceptance criteria |

### Harness Structure (Simplified)

```
seeds/
├── orchestrator.py              ← Main entry point (status, verify, check-constraints, evolve)
├── evolution/
│   ├── genome.yaml              ← Active constraints (project-specific, not duplicating AGENTS.md)
│   ├── domain-advancements.yaml ← Innovation roadmap (Basic → Solid → Advanced → Production)
│   ├── innovation-engine.py     ← Proposes innovations based on advancement stages
│   ├── innovation-log.yaml      ← Tracks proposed and applied innovations
│   ├── product-analyzer.py      ← Scans project state for innovation engine
│   ├── alexander-six-epics.yaml ← Architecture epic tracking
│   ├── framework.md             ← Evolution framework documentation
│   └── log.yaml                 ← Mutation history log
├── execution/
│   └── task-runner.py           ← Runs flutter analyze/test
├── feedback/
│   ├── error-capture.py         ← Structured error parser
│   ├── mistake-to-constraint.py ← Converts mistakes to new constraints
│   ├── human-interface.yaml     ← Human intervention config
│   └── retry-config.yaml        ← Retry strategies per error type
├── memory/
│   ├── session-state.yaml       ← Progress tracking (criteria, checkpoints, metrics)
│   ├── meta-mistakes.md         ← Mistake log with constraint cross-references
│   └── snapshot.py              ← Git-based checkpoint/rollback
├── tools/
│   └── audit_services.py        ← Service layer audit (dead service detection)
└── verification/
    ├── self-check.py            ← Self-check loop (verify → reflect → fix)
    └── verify_criteria.py       ← Specific criteria verification
```

## Architecture (Quick Reference)

```
UI (lib/ui/)        → pages (Browser, Editor, Graph, Canvas, Settings, AI Chat)
                       widgets (CommandBar, Backlinks, NoteSidebar, SplitPane, etc.)
Service (lib/services/) → ai_service, agent_service, browser_service, knowledge_service,
                          git_sync_service, webdav_sync_service, clipper_service, webhook_server, etc.
                          agent/ → AgentTool, AgentToolRegistry, BuiltinTools, PlanGenerator
Core (lib/core/)       → graph algorithms, link extractor/resolver, context assembler,
                          markdown highlighter, editor controllers
Data (lib/data/)       → models (Note, Link, AgentTask, Skill, QuickMove, Bookmark, BookmarkFolder, etc.)
                          stores (IndexStore, SyncStore, VaultStore, AppConfigStore, HNSW, Vector)
                          repositories (NoteRepository)
Platform (lib/platform/) → WebView managers (inline agent_webview, headless_manager)
Plugins (lib/plugins/) → Plugin host + API + builtin Dataview
```

### Storage Architecture

```
<ApplicationSupport>/              ← App data directory (cross-platform)
├── vaults.json                    ← Vault list + current vault (replaces SharedPreferences)
├── rfbrowser_config.json          ← App-wide config (UI theme, AI config, shortcuts, etc.)
└── ...

<vault>/.rfbrowser/                ← Vault-specific data
├── index.db                       ← SQLite full-text index
├── bookmarks.json                 ← Bookmark folders + bookmarks
├── cache/                         ← Index cache
├── plugins/                       ← Plugin data
└── ...

<vault>/                           ← User data
├── *.md                           ← Markdown notes
├── daily-notes/                   ← Daily notes
├── clippings/                     ← Web clippings
├── attachments/                   ← Attachments
└── <user folders>/                ← User-created folders
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
- **P-4**: Use `Stack` + `Visibility` for WebView tabs instead of `ValueKey` swap — avoids dealloc/realloc on every tab switch.
- **P-5**: After `moveNote` or any file-system mutation, call `loadAllNotes()` to refresh the in-memory state. Never assume state auto-syncs.

### Correctness
- **C-1**: API response parsing must be defensive — null-check every level of nested access.
- **C-2**: Concurrent state mutations must be guarded. Check `isLoading` before allowing new operations.
- **C-3**: When closing a tab/item from a list, calculate the new active index BEFORE removing the item.
- **C-4**: `copyWith` cannot set nullable fields to null using `?? this.field`. Use sentinel values or explicit clear flags.
- **C-5**: On Windows, `path.relative()` returns backslash separators. Always `replaceAll('\\', '/')` before splitting by `/` for cross-platform path handling.
- **C-6**: Tree structures with `parentId` must prevent self-referencing (e.g., root node's `parentId` must be empty, not its own `id`). Always add cycle detection in recursive traversals.
- **C-7**: After mutating state in a Notifier, ensure the UI rebuilds by using `ref.watch` on the correct provider. `ref.read` won't trigger rebuilds.

### Security
- **S-1**: WebView must filter dangerous URL schemes in `shouldOverrideUrlLoading`.
- **S-2**: API keys should not be stored in observable state objects. Read from secure storage only when needed.
- **S-3**: Path sanitization with `replaceAll('..', '')` is insufficient. Use path normalization + validation.
- **S-4**: Bookmark and vault data must be persisted to disk (JSON in vault/.rfbrowser/), not kept only in memory.

### Architecture
- **A-1**: Every component should have at least one data flow path to another component. Isolated silos are a design smell.
- **A-2**: Shared utility functions belong on the model/enum as getters, not duplicated across UI files.
- **A-3**: Dialog code identical across pages should be extracted into a shared function or widget.
- **A-4**: Separate concerns in state management — UI theme and AI config change for different reasons.
- **A-5**: Canvas cards with noteId should render live note data, not static snapshots.
- **A-6**: Auto-discovered connections (wikilink) must be visually distinct from manual ones.
- **A-7**: Canvas persistence should use file system (.json in vault/.rf/) for Git traceability.
- **A-8**: Vault-specific data (bookmarks, index) must live in `<vault>/.rfbrowser/`, not in app-wide config. App config (theme, AI keys) goes in `<ApplicationSupport>/`.
- **A-9**: Disk folder scanning must filter hidden directories (`.rfbrowser`, `.rf`) and system directories (`attachments`) to avoid polluting the note tree.
- **A-10**: Theme colors must be independently configurable — scaffold background, surface (cards/panels), and accent color serve different purposes. Never derive one from another automatically.
- **A-11**: `isDarkMode` should be a computed property from background/surface luminance, not a stored toggle. This eliminates the need for a separate dark/light mode switch.

### UI
- **U-1**: Error dismiss buttons must actually clear the error state.
- **U-2**: Canvas clipping must happen BEFORE drawing (save → clip → draw → restore).
- **U-3**: Row overflow in constrained spaces must use `Flexible` + `TextOverflow.ellipsis`.
- **U-4**: Font sizes in sidebars must follow user settings (e.g., `editorFontSize * 0.75`), not hardcoded values.
- **U-5**: AI panels must always have a "back/reset" button visible after generating content, not just a close button.
- **U-6**: Bookmark clicks must actually navigate the WebView — use `createTab(url:)` or `loadUrl()`, not just `updateTabUrl()`.
- **U-7**: `TextField` with `expands: true` must set `textAlignVertical: TextAlignVertical.top` — otherwise text starts centered vertically.
- **U-8**: `InputDecoration` from theme may set `filled: true` + `borderRadius` — always explicitly override for full-bleed editors (`filled: false` or `fillColor: bgColor` + all borders `InputBorder.none`).
- **U-9**: Color preset grids must use `LayoutBuilder` to compute equal-width items per row — fixed-width `Wrap` causes misalignment on different screen sizes.
- **U-10**: All user-visible strings must use l10n keys, never hardcoded text — even in early development. Retrofitting is expensive.

### Flutter-Specific
- **F-1**: `DropdownButtonFormField.value` deprecated in 3.41+. Use with ignore comment + `ValueKey`.
- **F-2**: `Matrix4.translate()`/`scale()` deprecated. Set matrix entries directly.
- **F-3**: `Offset.toVector3()` doesn't exist — use `Matrix4.inverted().entry(row, col)`.
- **F-4**: `flutter_markdown` `ExtensionSet` has no `copyWith` — create new instance manually.
- **F-5**: `MarkdownElementBuilder.visitElementAfterWithContext` takes 4 params, returns `Widget?`.
- **F-6**: `BoxDecoration.borderLeft` doesn't exist — use `Border(left: ...)`.
- **F-7**: Never assign `TextEditingController.text` inside `build()` unconditionally.
- **F-8**: `Markdown` widget doesn't accept `scrollController` — use `MarkdownBody`.
- **F-9**: `SegmentedButton.segments` cannot be `const` when labels use runtime l10n values — remove `const` keyword.
- **F-10**: `AppLocalizations` is only available inside `build()` — pass it as parameter to helper methods that need localized strings.
- **F-11**: Never use `const` constructor when parameters include `DateTime.now()` or other runtime values.
- **F-12**: Use `Color.withValues(alpha:)` instead of deprecated `Color.withOpacity()` for Flutter 3.27+.
- **F-13**: When referencing Riverpod providers from other service files, always add the corresponding import to avoid undefined identifier errors.

### Product UX
- **UX-1**: Every backend service must have at least one user-accessible trigger.
- **UX-2**: Empty states must guide the user toward the next action with a call-to-action.
- **UX-3**: Destructive actions require confirmation.
- **UX-4**: AI streaming output is a core UX expectation — users should see tokens in real-time.
- **UX-5**: Command bar is the primary navigation hub — it must search actual data, not hardcoded suggestions.
- **UX-6**: If LinkExtractor/LinkResolver exist but aren't called, graph and backlinks are empty.
- **UX-7**: Keyboard shortcuts must cover top 5 actions: search, new note, save, switch view, daily note.
- **UX-8**: Vault switching must be accessible from the main layout (not just welcome page). Use a dropdown in the title bar.
- **UX-9**: AI summary should support both web pages and notes, with a toggle to switch between them.
- **UX-10**: AI-generated content (summaries) should have a "save as note" action button.
- **UX-11**: Editor must have a formatting toolbar — raw Markdown syntax is not user-friendly. Provide quick-insert buttons for headings, bold, italic, lists, links, etc.
- **UX-12**: Editor must show a status bar with character/word count and save status — users need feedback on their work.
- **UX-13**: View mode switching (edit/preview/split) must use a `SegmentedButton` or similar explicit selector — cycling through modes with a single button is confusing.
- **UX-14**: Save feedback must be explicit — a brief "已保存" indicator that appears and fades, not just a disappearing dot.
- **UX-15**: Color presets must have clear visual distinction — avoid presets that differ by < 5% luminance. Use different hues, not just slightly different grays.
