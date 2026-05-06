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
