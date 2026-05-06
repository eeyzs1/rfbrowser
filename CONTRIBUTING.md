# Contributing to RFBrowser

Thank you for your interest in contributing! This guide will help you get set up and understand our workflow.

---

## Code of Conduct

Please read our [Code of Conduct](CODE_OF_CONDUCT.md). Be respectful, constructive, and kind.

---

## Getting Started

### 1. Fork & Clone

```bash
git clone https://github.com/YOUR_USERNAME/rfbrowser.git
cd rfbrowser
git remote add upstream https://github.com/ORIGINAL_OWNER/rfbrowser.git
```

### 2. Set Up Development Environment

See the [Development section in README](README.md#development) for prerequisites and setup commands.

```bash
flutter pub get
flutter gen-l10n
dart run build_runner build
```

### 3. Create a Branch

Branch naming convention: `<type>/<short-description>`

```
feat/quick-move-variables     # New feature
fix/graph-crash-on-empty      # Bug fix
docs/api-reference            # Documentation
test/agent-service-coverage   # Tests
refactor/clipper-service      # Refactoring
```

---

## Development Workflow

### Before You Start Coding

1. **Find or create an issue** — Every PR should reference an issue.
2. **Discuss your approach** — Especially for larger changes, open the issue for discussion first.
3. **Look for existing patterns** — Follow the code style and architecture already in place.

### Architecture Guidelines

RFBrowser follows a layered architecture:

```
UI (pages/widgets) → Service → Core Engine → Data/Platform
```

- **UI layer** (`lib/ui/`): Pages and widgets. Should be thin — mostly composition.
- **Service layer** (`lib/services/`): Business logic. Where most new logic goes.
- **Core layer** (`lib/core/`): Pure Dart engines with NO Flutter dependency. Algorithms, parsers.
- **Data layer** (`lib/data/`): Models, stores, repositories. Data access.

**Rules of thumb:**
- UI widgets should NOT contain business logic — delegate to services.
- Core engines should be pure Dart (no BuildContext, no widgets) — easy to test.
- Models should be immutable with `copyWith`.
- State management uses Riverpod: `Notifier` + immutable `State` class + `Provider`.

### Writing Code

- **Follow Dart conventions**: `dart format lib/ test/` for formatting.
- **Write tests**: New core/service logic MUST have tests. UI widget tests strongly encouraged.
- **No warnings**: `flutter analyze` must pass with zero issues.
- **Commit messages**: Use conventional commits:
  ```
  feat(clipper): add full-page HTML to Markdown conversion
  fix(graph): handle empty vault gracefully
  test(agent): add step timeout test
  docs(readme): add Quick Start section
  ```

### Running Checks

```bash
# Format code
dart format lib/ test/

# Static analysis
flutter analyze

# Run tests
flutter test

# Run tests with coverage report
flutter test --coverage
```

---

## Pull Request Process

1. **Keep PRs focused** — One feature/fix per PR. Small PRs are reviewed faster.
2. **Update relevant docs** — If you change APIs or behavior, update `docs/` accordingly.
3. **Ensure CI passes** — The CI pipeline runs `dart format`, `flutter analyze`, and `flutter test`.
4. **Write a clear PR description**:

```
## What
Added full-page HTML clipping to the ClipperService.

## Why
Users wanted to save entire web pages as notes, not just selections.
Closes #42.

## How
- Added `clipFullPage()` to ClipperService
- Added basic HTML-to-Markdown converter
- Added tests for common HTML patterns

## Screenshots
(Optional — before/after screenshots)
```

5. **Request review** — Tag maintainers or relevant contributors.
6. **Address feedback** — Be responsive to review comments.

---

## Where to Contribute

### Beginner-Friendly Issues

Look for issues labeled [`good first issue`](../../labels/good%20first%20issue):
- Adding screenshots to README
- Improving documentation
- Fixing simple UI bugs
- Writing missing tests

### Feature Development

- Check the [Feature Request issues](../../labels/enhancement)
- Discuss your approach before implementing large features
- Consider creating a draft PR early for feedback

### Areas Needing Help

| Area | Priority | Description |
|------|----------|-------------|
| 📸 Screenshots | High | Take screenshots for the README |
| 🧪 Tests | High | Increase coverage on services, core engines |
| 🌐 Translations | Medium | Improve Chinese/English translations |
| 🎨 UI Polish | Medium | Fix visual inconsistencies, responsiveness |
| 📖 Plugin Docs | Medium | Document the plugin API for third-party developers |
| 🐧 Linux Testing | Medium | Test and report issues on Linux platform |

---

## Project Conventions

### File Naming

- Dart files: `snake_case.dart`
- Test files: `<source>_test.dart` (mirrors `lib/` structure)
- Assets: lowercase with underscores

### Model Conventions

```dart
class MyModel {
  final String id;
  final String title;
  final DateTime createdAt;

  const MyModel({
    required this.id,
    required this.title,
    required this.createdAt,
  });

  MyModel copyWith({
    String? id,
    String? title,
    DateTime? createdAt,
  }) {
    return MyModel(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
```

### Riverpod State Pattern

```dart
// 1. Immutable state class
class MyState {
  final List<Item> items;
  final bool isLoading;

  const MyState({this.items = const [], this.isLoading = false});

  MyState copyWith({List<Item>? items, bool? isLoading}) {
    return MyState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

// 2. Notifier
class MyNotifier extends Notifier<MyState> {
  @override
  MyState build() => const MyState();

  Future<void> load() async {
    state = state.copyWith(isLoading: true);
    try {
      final items = await fetchItems();
      state = state.copyWith(items: items, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }
}

// 3. Provider
final myProvider = NotifierProvider<MyNotifier, MyState>(MyNotifier.new);
```

---

## Questions?

- Open a [Discussion](../../discussions) (if enabled)
- Comment on the relevant issue
- Reach out to maintainers

Thank you for contributing to RFBrowser!
