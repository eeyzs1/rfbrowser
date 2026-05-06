# RFBrowser — CLAUDE AGENT INSTRUCTIONS

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
8. Always run `flutter analyze` before committing
9. New features need at least one user-accessible trigger (button, menu, shortcut, or command)

## Common Commands

```bash
# Code generation
dart run build_runner build

# Run tests
flutter test
flutter test --coverage

# Code formatting
dart format lib/ test/

# Static analysis
flutter analyze

# Localization generation
flutter gen-l10n
```

## File Conventions

- Dart files: `snake_case.dart`
- Test files: `<source>_test.dart` mirroring `lib/` structure
- Models: Immutable with `copyWith()`, `const` constructor
- State: Riverpod Notifier + immutable State class + Provider
