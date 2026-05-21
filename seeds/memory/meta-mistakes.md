# Meta-Mistakes — RFBrowser (Compressed)

All 23 meta-mistakes are Resolved. Detailed evidence is in git history.
Each mistake produced a constraint tracked in genome.yaml.

| ID | Lesson | Constraint |
|----|--------|-----------|
| MM-001 | CustomPainter.shouldRepaint must compare actual data, not return true | C004 |
| MM-002 | Cache SharedPreferences.getInstance() as lazy singleton | C005 |
| MM-003 | No empty catch blocks — every catch must log or rethrow | C006 |
| MM-004 | Use dart:convert for JSON — never write manual parsers | C007 |
| MM-005 | No duplicate business logic between UI and service layers | C008 |
| MM-006 | After harness generation, adapt all paths to project-specific structure | C009 |
| MM-007 | Always normalize path separators to forward slashes before splitting (Windows) | C037 |
| MM-008 | Tree structures with parentId must prevent self-referencing — add cycle detection | C038 |
| MM-009 | All user data must be persisted to disk, not kept only in memory | C040 |
| MM-010 | After file-system mutation, call loadAllNotes() to refresh in-memory state | C039 |
| MM-011 | Bookmark clicks must navigate WebView via createTab/loadUrl, not just updateTabUrl | C045 |
| MM-012 | Disk scanning must filter hidden and system directories | C042 |
| MM-013 | TextField with expands:true must set textAlignVertical: TextAlignVertical.top | U-7 |
| MM-014 | Full-bleed editors must explicitly override all InputDecoration properties | U-8 |
| MM-015 | All user-visible strings must use l10n keys from the start | U-10 |
| MM-016 | Color presets must span different hues AND luminance ranges | UX-15 |
| MM-017 | isDarkMode should be computed from luminance, not a stored toggle | A-11 |
| MM-018 | FocusNode must not be disposed while hasFocus is true | C049 |
| MM-019 | Camera state should use ChangeNotifier + ListenableBuilder, not setState per frame | C050 |
| MM-020 | Every clickable element must be hit-tested in onScaleStart, not just in onTap | C051 |
| MM-021 | Never use const constructor when parameters include DateTime.now() or other runtime values | C052 |
| MM-022 | When referencing providers from other services, always add the corresponding import — missing imports cause undefined identifier errors | C053 |
| MM-023 | Use Color.withValues(alpha:) instead of deprecated Color.withOpacity() for Flutter 3.27+ | C054 |
