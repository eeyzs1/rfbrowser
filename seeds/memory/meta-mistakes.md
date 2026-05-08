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
