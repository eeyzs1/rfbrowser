# Task Patterns

## Purpose
Catalog patterns of tasks that the meta-harness has seen.
When a new task arrives, the interpreter can match it to known patterns
and generate a better harness faster.

## Format
```
### Pattern: [Name]
- Domain: [primary domain]
- Signals: [keywords/phrases that indicate this pattern]
- Template: [which template to use]
- Typical topology: [agent topology pattern]
- Common pitfalls: [what usually goes wrong with this type of task]
- Success rate: [historical success rate, if available]
```

## Known Patterns

### Pattern: CRUD Application
- Domain: software_development
- Signals: "manage", "track", "list", "add/edit/delete", "dashboard"
- Template: web-app
- Typical topology: planner-executor
- Common pitfalls: over-engineering, premature optimization, missing validation

### Pattern: Data Sync/ETL
- Domain: data_processing
- Signals: "sync", "import", "export", "migrate", "transform", "ETL"
- Template: data-pipeline
- Typical topology: pipeline
- Common pitfalls: data loss, schema drift, missing error handling

### Pattern: Monitoring/Alerting
- Domain: automation
- Signals: "monitor", "alert", "notify", "watch", "detect"
- Template: automation
- Typical topology: planner-executor
- Common pitfalls: alert fatigue, missing edge cases, no manual override

### Pattern: Content Generation
- Domain: content_generation
- Signals: "write", "generate", "create content", "blog", "report"
- Template: content-system
- Typical topology: three-agent (researcher/writer/editor)
- Common pitfalls: hallucination, style inconsistency, missing fact-check

### Pattern: Desktop UI Performance / Gesture
- Domain: software_development
- Signals: "卡顿", "lag", "slow", "freeze", "crash on scroll", "VSCode-like", "tab", "scroll", "drag", "middle-click", "AXTree", "Lost connection to device"
- Template: bugfix (no new generation — apply to existing Flutter desktop project)
- Typical topology: single-agent (investigate → fix → verify)
- Common pitfalls:
  - Nested Scrollable (ReorderableListView+shrinkWrap in parent ListView) → Windows AXTree crash
  - TextField(maxLines:null, expands:true) on large content → UI freeze
  - Synchronous regex in buildTextSpan → keystroke lag
  - Horizontal ListView without PointerScrollEvent → wheel doesn't work on Windows
  - onSecondaryTapUp used for middle-click (actually right-click)
- Required checks: flutter analyze + real-device smoke test (scroll settings, open >20KB note, switch view modes, split, gestures)
- Success rate: N/A (new pattern, first seen 2026-06-25)
- Key files: lib/ui/widgets/split_pane*.dart, lib/core/editor/highlighted_text_editing_controller.dart, lib/ui/widgets/note_pane_view.dart, lib/ui/pages/settings/*
