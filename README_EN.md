# RFBrowser — AI-powered Knowledge Browser

<div align="center">

![Flutter](https://img.shields.io/badge/Flutter-3.27+-blue?logo=flutter)
![Dart](https://img.shields.io/badge/Dart-3.11+-blue?logo=dart)
![License](https://img.shields.io/badge/license-MIT-green)
![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20Linux%20%7C%20Android-lightgrey)

</div>

> **Browse, Think, Connect, Automate.** A local-first, AI-augmented knowledge workbench — one app to bridge web research, note-taking, knowledge graphs, and AI automation.

[中文版](README.md)

---

## What is RFBrowser?

RFBrowser merges the **browser** with a **knowledge management system**. You can:

- 🌐 **Browse the web** with multiple tabs (Chromium-based WebView)
- ✍️ **Write notes** in pure Markdown with `[[wiki-links]]`
- 🕸️ **Visualize connections** with an interactive knowledge graph
- 🤖 **Chat with AI** while referencing your notes and web pages
- 🎨 **Brainstorm freely** on an infinite canvas
- ⚡ **Automate** repetitive tasks with AI Agents and Quick Moves
- 🔄 **Sync across devices** via Git or WebDAV — no vendor lock-in

**Think of it as: Obsidian + ChatGPT + a Web Browser + Canvas — all in one app.**

> ⚠️ **Note**: Currently only **Windows** has been thoroughly tested. Linux and Android builds are supported but have not undergone full testing — unknown issues may exist.

---

## Features

### Core Panels — Mix and Match

| Panel | What it does | Why you'd use it |
|-------|-------------|------------------|
| 🌐 **Browser** | Multi-tab WebView (Chromium engine) | Research articles, docs, anything on the web |
| ✍️ **Editor** | Markdown editor with split preview + `[[links]]` | Write notes, daily journals, documentation |
| 🕸️ **Graph** | Force-directed / circular layout of your links | Discover connections between your notes |
| 🤖 **AI Chat** | Streaming chat with OpenAI-compatible APIs | Summarize, translate, brainstorm, code review |
| 🎨 **Canvas** | Infinite space for cards and connections | Mind maps, project planning, visual thinking |
| 📋 **Notes** | Note list sidebar with search | Navigate and organize your vault |
| 🔗 **Links** | Backlinks / outlinks panel | See what references what |

### Power Tools

- 🔍 **Command Bar** (`Ctrl+K`): Search notes, run commands, trigger Quick Moves
- ⚡ **Quick Moves**: Define custom slash-commands that send context (page content, selection, note) to AI
- 🧠 **AI Agents**: Multi-step task automation with headless browser, step tracking, time limits
- 📎 **Web Clipper**: Save full pages, selections, or bookmarks as notes in one click
- 🔌 **Plugin System**: Write Dart plugins via `BuiltinPlugin` interface, running in isolated sandboxes
- 🎯 **Skills**: Define AI prompt templates in YAML files — zero-code AI extensibility
- 📅 **Daily Notes**: One-click daily journal entries

### Extensibility

RFBrowser offers two extension mechanisms — choose the one that fits your needs:

#### Plugins (Code-level Extensions)

Plugins extend the app's core functionality — register commands, render UI panels, call Knowledge/Browser/AI APIs. Each plugin runs in an isolated Dart Isolate sandbox with automatic crash recovery.

| Capability | Description |
|------|------|
| **Commands** | Register commands discoverable via the Command Bar (`Ctrl+K`) |
| **UI Panels** | Render custom panel widgets |
| **API Calls** | Call Knowledge, Browser, and AI services through the sandbox |
| **Skill Declaration** | Plugins can bundle Skills for use in AI Chat |
| **Permissions** | 5 permission types (knowledge read/write, browser, ai, ui), checked at runtime |

> Built-in example: [HelloWorld Plugin](lib/plugins/builtin/hello_world/hello_world_plugin.dart) demonstrates the full plugin lifecycle.

Plugin authoring:
```dart
// 1. Extend BuiltinPlugin
class MyPlugin extends BuiltinPlugin {
  // 2. Declare manifest (permissions, metadata)
  PluginManifest get manifest => PluginManifest(
    id: 'my-plugin', name: 'My Plugin',
    permissions: [Permission.knowledgeRead, Permission.uiPanel],
  );
  // 3. Register commands
  List<PluginCommand> get commands => [
    PluginCommand(id: 'my.do', label: 'Do Something', pluginId: 'my-plugin'),
  ];
  // 4. Optional: declare Skills for AI use
  List<Skill> get skills => [
    Skill(id: 'my.skill', name: 'My Skill', prompt: '...', pluginId: 'my-plugin'),
  ];
  // 5. Register in PluginRegistry
}
// 6. Add to PluginRegistry._builtinPlugins: MyPlugin(),
```

#### Skills (Zero-code Extensions)

Skills are AI prompt templates — no coding required. Just drop a YAML file to add new capabilities to AI Chat. Created Skills automatically appear in the AI Chat Panel's Skill Picker.

Location: `<your-vault>/.rfbrowser/skills/<skill-name>.yaml`

```yaml
# Example: a translation Skill
id: my-translate
name: Translate Note
description: Translate the current note to another language
prompt: |
  Translate the following note to {{target_language}}:
  @note[current]
```

| Skill Source | Description |
|------------|------|
| **Built-in Skills** | 7 ready-to-use (summarize, research, outline, auto-tag, etc.) |
| **Plugin Skills** | Bundled with plugins, loaded automatically |
| **Custom Skills** | YAML files placed in `.rfbrowser/skills/` directory |

---
     
### Sync & Portability

- 💾 **Local-first**: All notes stored as plain `.md` files in a folder you control (a *Vault*)
- 🔄 **Git Sync**: Version history + push/pull with any Git remote
- ☁️ **WebDAV Sync**: Auto-sync (configurable interval) to your own server
- 🌍 **No Lock-in**: Compatible with Obsidian, Foam, VS Code — open any Vault folder
- 🌐 **i18n**: English & Chinese UI, switchable at runtime

### Security

- API keys stored in platform-level secure storage (not in state objects)
- WebView URL scheme filtering (`file://`, `javascript:`, `data://` blocked)
- Path traversal protection
- Destructive actions require confirmation

---

## Screenshots

<!-- Add your screenshots here! Suggested: -->
<!-- - Main layout with Browser + Editor + AI Chat split -->
<!-- - Knowledge Graph view -->
<!-- - Infinite Canvas -->
<!-- - Command Bar in action -->

*(Screenshots coming soon — contributions welcome!)*

---

## Quick Start (Users)

### Download

| Platform | Download | Test Status |
|----------|----------|-------------|
| 🪟 **Windows** | [Latest Release](../../releases) → `rfbrowser-windows.zip` | ✅ Tested |
| 🐧 **Linux** | [Latest Release](../../releases) → `rfbrowser-linux.tar.gz` | ⚠️ Not fully tested |
| 🤖 **Android** | [Latest Release](../../releases) → `rfbrowser-android.apk` | ⚠️ Not fully tested |

### First Launch

1. **Open or Create a Vault** — Pick any folder on your computer (or create a new one). This is where your Markdown notes live.
2. **Start browsing** — Open a web page in the Browser panel.
3. **Clip content** — Right-click to save pages or selections as notes.
4. **Link your notes** — Use `[[note-title]]` syntax. Links appear in the Graph automatically.
5. **Chat with AI** — Configure an API key in Settings → AI, then send messages. The AI can see your notes and current page content via context references.

---

## Development

### Prerequisites

- **Flutter SDK** `>= 3.27.0` ([install guide](https://flutter.dev/docs/get-started/install))
- **Dart** `>= 3.11.0` (bundled with Flutter)
- Platform-specific:
  - **Windows**: Visual Studio 2022 with "Desktop development with C++"
  - **Linux**: `clang`, `cmake`, `ninja`, `pkg-config`, `libgtk-3-dev`, `libsecret-1-dev`
  - **Android**: Android Studio + Android SDK

### Clone & Run

```bash
# Clone the repository
git clone https://github.com/YOUR_USERNAME/rfbrowser.git
cd rfbrowser

# Install dependencies
flutter pub get

# Generate localization files
flutter gen-l10n

# Run on your platform
flutter run -d windows    # Windows (recommended, thoroughly tested)
flutter run -d linux      # Linux (not fully tested)
flutter run -d android    # Android (not fully tested)
```

### Project Structure

```
rfbrowser/
├── lib/
│   ├── main.dart                    # App entry point
│   ├── app.dart                     # MaterialApp + theme + vault init
│   ├── core/                        # Pure Dart engines (no Flutter dependency)
│   │   ├── context/                 #   Context assembly for AI prompts
│   │   ├── editor/                  #   Markdown highlighter, sync scroll
│   │   ├── graph/                   #   Force-directed layout, filters
│   │   ├── link/                    #   Wiki-link extractor, resolver
│   │   └── model/                   #   AI model/router configuration
│   ├── data/                        # Data layer (models, repos, stores)
│   │   ├── models/                  #   Note, Link, AgentTask, Skill, etc.
│   │   ├── repositories/            #   Note persistence (Markdown ↔ DB)
│   │   └── stores/                  #   Index, cache, sync state
│   ├── services/                    # Business logic services
│   │   ├── ai_service.dart          #   Chat messages, streaming, providers
│   │   ├── agent_service.dart       #   Multi-step agent execution
│   │   ├── browser_service.dart     #   Tab management, WebView state
│   │   ├── knowledge_service.dart   #   Notes CRUD, linking, indexing
│   │   ├── git_sync_service.dart    #   Git push/pull/init
│   │   └── webdav_sync_service.dart #   WebDAV upload/download
│   ├── ui/                          # Presentation layer
│   │   ├── layout/main_layout.dart  #   Split pane, panels, shortcuts
│   │   ├── pages/                   #   Browser, Editor, Graph, Canvas, Settings
│   │   └── widgets/                 #   CommandBar, Backlinks, NoteSidebar, etc.
│   ├── plugins/                     # Plugin system
│   ├── platform/                    # WebView managers (inline + headless)
│   └── l10n/                        # English & Chinese ARB files
├── test/                            # Unit & widget tests
├── docs/                            # Architecture & design docs
├── .github/
│   ├── workflows/ci.yml             # CI/CD pipeline (analyze, test, build)
│   └── ISSUE_TEMPLATE/              # Bug report & feature request templates
└── pubspec.yaml
```

For a deeper architecture dive, see [`docs/design/02-architecture.md`](docs/design/02-architecture.md).

### Common Commands

```bash
# Code generation (Riverpod providers)
dart run build_runner build

# Run all tests
flutter test

# Run tests with coverage
flutter test --coverage

# Code formatting
dart format lib/ test/

# Static analysis
flutter analyze
```

---

## Tech Stack

| Layer | Technology | Purpose |
|-------|-----------|---------|
| **Framework** | Flutter 3.x | Cross-platform UI |
| **Language** | Dart 3.x | Application logic |
| **WebView** | `flutter_inappwebview` | Embedded Chromium browser |
| **Markdown** | `markdown` + `flutter_markdown` | Parsing & rendering |
| **Database** | SQLite (`sqflite`) | Full-text search & link index |
| **Cache** | Hive | Local key-value cache |
| **HTTP** | Dio | REST API calls to AI providers |
| **State Mgmt** | Riverpod | Reactive state with code-gen |
| **Routing** | go_router | Declarative navigation |
| **Sync** | Git CLI + WebDAV (Dio) | Multi-device sync |
| **Secure Store** | `flutter_secure_storage` | API key encryption |
| **Graph** | CustomPainter + Canvas | Force-directed graph rendering |

### AI Providers Supported

Any OpenAI-compatible API — including:
- OpenAI (GPT-4o, GPT-4, etc.)
- Anthropic (Claude via compatible proxy)
- Google Gemini (via compatible endpoint)
- Ollama (local models)
- LM Studio, LocalAI, vLLM, etc.

---

## Contributing

We welcome contributions of all kinds! Here's how to get started:

1. **Read** [`CONTRIBUTING.md`](CONTRIBUTING.md) for guidelines
2. **Find an issue** — Look for `good first issue` labels
3. **Fork & branch** — Create a feature branch off `main`
4. **Code & test** — Ensure `flutter test` and `flutter analyze` pass
5. **Open a PR** — Describe your changes and link any relevant issues

### Good places to start contributing

- 🖼️ **Screenshots** — Take some screenshots and add them to the README
- 📝 **Documentation** — Improve docs, add code comments
- 🧪 **Tests** — Increase test coverage on untested modules
- 🎨 **UI Polish** — Fix minor visual inconsistencies
- 🐛 **Bug fixes** — Check the issues page

---

## Community

- 📖 [Architecture Docs](docs/design/)
- 🐛 [Report a Bug](../../issues/new?template=bug_report.md)
- 💡 [Request a Feature](../../issues/new?template=feature_request.md)
- 💬 Discussions — Coming soon!

---

## License

[MIT](LICENSE) © 2024-2026 RFBrowser Contributors

---

<p align="center">
  <sub>Built with Flutter. Data stays local. Knowledge grows with you.</sub>
</p>