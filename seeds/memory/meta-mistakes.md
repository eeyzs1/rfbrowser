# Meta-Mistakes — RFBrowser

Lessons learned from building and operating the codebase. Each mistake produces a new or strengthened constraint.

## Meta-Mistake 001: shouldRepaint always returned true
Status: Resolved
Root Cause: Performance rule P-2 not enforced at code level
Lesson: CustomPainter.shouldRepaint must compare actual data, not just return true
Constraint Added: C004 — "All CustomPainter subclasses must implement shouldRepaint with data comparison"

## Meta-Mistake 002: SharedPreferences not cached
Status: Resolved
Root Cause: Performance rule P-3 not enforced — easy to call getInstance() in every method
Lesson: Cache SharedPreferences.getInstance() as lazy singleton in every class that uses it
Constraint Added: C005 — "Every class using SharedPreferences must cache the instance"

## Meta-Mistake 003: Empty catch blocks silently swallowing errors
Status: Resolved
Root Cause: Convenience — empty catch blocks are easy to write but make debugging impossible
Lesson: Every catch block must at minimum log the error with context
Constraint Added: C006 — "No empty catch blocks — every catch must log or rethrow"

## Meta-Mistake 004: Manual JSON parser in production code
Status: Resolved
Root Cause: Generated code used a hand-written parser instead of dart:convert
Lesson: Never write custom parsers when standard library parsers exist
Constraint Added: C007 — "Use dart:convert for JSON — never write manual parsers"

## Meta-Mistake 005: Duplicate connection-side logic
Status: Resolved
Root Cause: Copy-paste between UI and service layer without extraction
Lesson: Shared logic between layers belongs on the model as a static method
Constraint Added: C008 — "No duplicate business logic between UI and service layers"

## Meta-Mistake 006: Harness paths referenced generic template structure
Status: Resolved
Root Cause: Meta-harness generates for generic projects, doesn't adapt to domain
Lesson: After harness generation, adapt all paths to project-specific structure
Constraint Added: C009 — "After harness generation, run domain-adaptation pass"

## Meta-Mistake 007: Windows path separators broke note folder tree
Status: Resolved
Root Cause: On Windows, `path.relative()` returns backslash separators (e.g., `eeee\1.md`), but Trie tree splits by `/`, resulting in single-element paths that place all notes in root
Lesson: Always normalize path separators to forward slashes before splitting. Cross-platform path handling requires explicit normalization.
Constraint Added: C037 — "Windows path.relative() returns backslash — always replaceAll('\\', '/') before splitting by '/'"
Evidence: Notes in `eeee/` and `tttt/` folders displayed in root directory on Windows

## Meta-Mistake 008: BookmarkFolder self-reference caused Stack Overflow
Status: Resolved
Root Cause: Default `bookmarks-bar` folder had `parentId = 'bookmarks-bar'` (pointing to itself), causing `_countBookmarksInFolder` to recurse infinitely
Lesson: Tree structures with parentId must prevent self-referencing. Root nodes must have empty parentId. Always add cycle detection (visited set) in recursive tree traversals.
Constraint Added: C038 — "Tree structures with parentId must prevent self-referencing — add cycle detection in recursive traversals"
Evidence: StackOverflowError at `_countBookmarksInFolder` line 522, 8000+ recursive calls

## Meta-Mistake 009: Bookmark data lost on app restart
Status: Resolved
Root Cause: `BrowserNotifier` was pure in-memory state — no persistence mechanism. Bookmarks and folders disappeared on every restart.
Lesson: All user data must be persisted to disk. Vault-specific data goes in `<vault>/.rfbrowser/`, not in SharedPreferences or memory-only state.
Constraint Added: C040 — "Bookmark and vault data must be persisted to disk (JSON in vault/.rfbrowser/)"
Evidence: Every app restart showed empty bookmarks list

## Meta-Mistake 010: moveNote updated memory but UI didn't refresh
Status: Resolved
Root Cause: `KnowledgeNotifier.moveNote` only updated `state.notes` reference without calling `loadAllNotes()`, so the Trie tree in sidebar still showed old folder structure
Lesson: After any file-system mutation (move, rename, delete), must call `loadAllNotes()` to fully refresh the in-memory state and trigger UI rebuild.
Constraint Added: C039 — "After moveNote or file-system mutation, call loadAllNotes() to refresh in-memory state"

## Meta-Mistake 011: Bookmark clicks didn't navigate WebView
Status: Resolved
Root Cause: `onBookmarkOpened` callback used `updateTabUrl()` which only updates the in-memory URL string, but doesn't call `controller.loadUrl()` to actually navigate the WebView
Lesson: URL changes in browser state must be accompanied by actual WebView navigation. Use `createTab(url:)` for new tabs or `controller.loadUrl()` for existing tabs.
Constraint Added: C045 — "Bookmark clicks must actually navigate the WebView — use createTab(url:) or loadUrl()"

## Meta-Mistake 012: Hidden directories appeared in note folder tree
Status: Resolved
Root Cause: `_collectFolders` scanned all directories including `.rfbrowser`, `.rf`, and `attachments`, polluting the note tree with system directories
Lesson: Disk scanning must filter hidden directories (starting with `.`) and known system directories (`attachments`) to show only user-relevant folders.
Constraint Added: C042 — "Disk folder scanning must filter hidden directories and system directories"

## Meta-Mistake 013: TextField with expands:true centered text vertically
Status: Resolved
Root Cause: `TextField(expands: true)` defaults to vertical center alignment, making the cursor start in the middle of the editor area
Lesson: Always set `textAlignVertical: TextAlignVertical.top` when using `expands: true` on TextField. This matches VS Code / GitHub editor behavior where text starts from top-left.
Constraint Added: U-7 — "TextField with expands: true must set textAlignVertical: TextAlignVertical.top"
Evidence: Editor cursor appeared in the vertical center of the editing area

## Meta-Mistake 014: Theme InputDecoration overrode editor background
Status: Resolved
Root Cause: `app_theme.dart` set `inputDecorationTheme.filled: true` with `borderRadius`, causing the editor TextField to show rounded corners and a surface-colored background instead of the custom background color
Lesson: When a TextField needs full-bleed rendering (no border, custom background), explicitly override all InputDecoration properties: `filled: true/false`, `fillColor`, and all border states to `InputBorder.none`.
Constraint Added: U-8 — "InputDecoration from theme may override editor appearance — always explicitly override for full-bleed editors"
Evidence: Editor showed rounded corners and wrong background color despite setting ColoredBox wrapper

## Meta-Mistake 015: Hardcoded Chinese strings in bilingual app
Status: Resolved
Root Cause: Added UI features with hardcoded Chinese strings (toolbar tooltips, status bar labels, section headers) instead of using the existing l10n system
Lesson: In a bilingual app, ALL user-visible strings must use l10n keys from the start. Retrofitting 30+ strings across multiple files is error-prone and time-consuming. The l10n pattern requires: ARB files → abstract getters → implementation classes → usage via `AppLocalizations.of(context)!`.
Constraint Added: U-10 — "All user-visible strings must use l10n keys, never hardcoded text"
Evidence: 30+ hardcoded Chinese strings found in editor_page.dart and theme_settings_section.dart

## Meta-Mistake 016: Color presets too similar to distinguish
Status: Resolved
Root Cause: Background presets used 5 near-identical dark colors (luminance difference < 5%) and 3 near-white colors. Surface presets used 5 near-identical dark grays. Users couldn't tell them apart visually.
Lesson: Color presets must span different hues AND luminance ranges. For dark presets, use distinct color temperatures (blue-black, green-black, brown-black, purple-black). For light presets, use medium-brightness colors (70-85% luminance), not near-white (>95%).
Constraint Added: UX-15 — "Color presets must have clear visual distinction — avoid presets that differ by < 5% luminance"
Evidence: Midnight (#0F172A), Charcoal (#18181B), Navy (#0C1929) all appeared identical on screen

## Meta-Mistake 017: isDarkMode as stored toggle caused theme/surface mismatch
Status: Resolved
Root Cause: `isDarkMode` was a stored boolean toggle independent of background/surface colors. Changing background color didn't affect whether the app used dark or light theme, causing white text on light backgrounds or dark text on dark backgrounds.
Lesson: `isDarkMode` should be a computed getter derived from the surface/background color luminance, not an independent stored value. This ensures text contrast automatically adapts to color changes.
Constraint Added: A-11 — "isDarkMode should be a computed property from luminance, not a stored toggle"
Evidence: After changing background to a light color, text remained white (unreadable) because isDarkMode was still true

## Meta-Mistake 018: FocusNode disposed while still focused
Status: Resolved
Root Cause: `_startInlineEditing` unconditionally disposed `_inlineTitleFocus` and `_inlineContentFocus` even when they still had focus, causing "disposed FocusNode" errors on subsequent interactions
Lesson: Before disposing a FocusNode, check `hasFocus`. If the node is still focused, skip disposal — it will be cleaned up when focus transfers naturally. Alternatively, only dispose when creating new nodes for a different card.
Constraint Added: C049 — "FocusNode must not be disposed while hasFocus is true — check before disposing"
Evidence: "A FocusNode was disposed while it still had focus" runtime error in canvas inline editing

## Meta-Mistake 019: Canvas setState on every pan/zoom frame
Status: Resolved
Root Cause: `_onScaleUpdate` called `setState()` on every camera movement (pan/zoom), causing the entire canvas widget tree to rebuild at 60fps during drag. This wasted CPU on rebuilding toolbar, sidebar, and other non-camera-dependent widgets.
Lesson: Camera state (position, scale) should be managed by a separate ChangeNotifier, not by widget setState. Wrap camera-dependent widgets (CustomPaint, minimap, zoom controls) with ListenableBuilder to isolate rebuilds.
Constraint Added: C050 — "Never call setState on every frame for camera/scroll state — use ChangeNotifier + ListenableBuilder to isolate rebuilds"
Evidence: CPU usage spiked during canvas panning because entire widget tree rebuilt on every frame

## Meta-Mistake 020: Connection line unselectable due to missing hit test in gesture start
Status: Resolved
Root Cause: `_onScaleStart` had no `_hitTestConnectionLine` check. When clicking a connection line, no hit target was found, so `_draggingCardId` was set to null, triggering canvas pan in `_onScaleUpdate`. The ScaleGestureRecognizer won the gesture arena, preventing `_onTapUp` from firing, making connection lines permanently unselectable.
Lesson: Every clickable element must be hit-tested in the gesture start handler, not just in the tap handler. If a gesture recognizer claims the pointer before tap fires, the tap handler never executes. Add a flag-based approach: detect the hit in start, set a flag to prevent conflicting gestures, and select in end/tap.
Constraint Added: C051 — "Every clickable element must be hit-tested in onScaleStart — tap-only hit testing fails when ScaleGestureRecognizer claims the pointer"
Evidence: Connection lines between two cards could not be selected by clicking — only waypoints worked
