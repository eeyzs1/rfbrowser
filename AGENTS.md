# Meta-Harness — AGENT OPERATING INSTRUCTIONS

## ⚠️ MANDATORY: Read This Before Taking Any Action

This project is a META-HARNESS — it does NOT do the work itself.
It GENERATES a complete, runnable, self-evolving harness engineering project
that THEN does the work. Your job is to run the generation pipeline.

## First Principles (Override Everything Else)

1. **Do not assume the user knows what they want.** When unclear, STOP and discuss.
2. **If the goal is clear but the path isn't optimal, say so.** Suggest the better way.
3. **Chase root causes, never patch symptoms.** Every decision must answer "why".
4. **Output only what changes decisions.** Cut everything else.

## The Core Loop

```
┌─→ INTERPRET: What does the user actually need? (first principles)
│       ↓
│   GENERATE: Create a COMPLETE harness project (7 layers + 2 cross-cutting + evolution)
│       ↓
│   PROVE:   Does the generated project cover all 7 layers? Can it run? Can it evolve?
│       ↓
│   JUDGE:   Is the generated project sufficient? ──→ NO → root cause → loop back
│       ↓
│   YES
│       ↓
└── EVOLVE:  What did we learn about generation? Improve the meta-harness.
```

## Step-by-Step Protocol

### Step 1: Interpret (First Principles)
Read `meta/interpreter.md`. Understand the REAL need.
Do NOT start from templates. Start from the problem.

### Step 2: Generate Complete Harness Project
Read `meta/harness-generator.md`. Generate ALL seven layers:
1. Context Engineering (AGENTS.md, context loader, knowledge index)
2. Tool Integration (schemas, sandbox, permissions, MCP)
3. Memory & State (session state, long-term memory, snapshots, compression)
4. Planning & Orchestration (DAG, flow control, sub-agents, budgets)
5. Verification & Guardrails (format validators, consistency, security, self-check)
6. Feedback & Self-Healing (error capture, retry, optimization loop, human interface)
7. Constraints & Entropy (architecture rules, enforcement, entropy reduction, cost)

Plus two cross-cutting systems:
- Security & Isolation (sandbox, encryption, audit)
- Observability & Governance (tracing, metrics, replay, versioning)

Plus self-evolution system (evidence-driven).

### Step 3: Generate Agent Topology
Read `meta/agent-factory.md`. Generate topology from task analysis.

### Step 4: Prove Completeness
For each of the 7 layers + 2 cross-cutting systems:
- Verify at least one concrete artifact was generated
- Verify artifacts are executable, not just documentation
- Verify evidence traceability exists

### Step 5: Judge
Can the generated project actually run and self-evolve?
If NO → diagnose root cause, loop back.

### Step 6: Evolve Meta-Harness
What did we learn about the generation process? Improve `meta/` and `templates/`.

## Absolute Rules

1. No execution without interpretation
2. No agent without a harness
3. No constraint without a reason
4. No completion without EVIDENCE
5. No single-pass execution — loop until proven
6. No patching symptoms — chase root causes
7. Generate EXECUTABLE systems, not just documents
8. Every generated layer must have concrete artifacts
9. Evolution never removes verification or itself
10. All mutations reversible

## Learned Lessons (Evidence-Driven Evolution)

### Performance
- **P-1**: Never persist to disk on every frame (drag/resize). Use in-memory updates + debounced save (500ms) + explicit persist on end.
- **P-2**: `CustomPainter.shouldRepaint` must compare actual data, not just return `true`. Otherwise continuous 60fps repaints waste CPU.
- **P-3**: Cache `SharedPreferences.getInstance()` rather than calling it in every setter.

### Correctness
- **C-1**: API response parsing must be defensive — null-check every level of nested access (`data?['choices']?[0]?['message']?['content']`). Never assume API responses match the expected schema.
- **C-2**: Concurrent state mutations must be guarded. Check `isLoading` before allowing new operations.
- **C-3**: When closing a tab/item from a list, calculate the new active index BEFORE removing the item, not after.
- **C-4**: `copyWith` cannot set nullable fields to null using `?? this.field`. Use sentinel values or explicit clear flags.

### Security
- **S-1**: WebView must filter dangerous URL schemes (`file://`, `javascript:`, `data:`) in `shouldOverrideUrlLoading`.
- **S-2**: API keys should not be stored in observable state objects. Read from secure storage only when needed for requests.
- **S-3**: Path sanitization with `replaceAll('..', '')` is insufficient. Use path normalization + validation instead.

### Architecture
- **A-1**: Components must not be isolated silos. Every component should have at least one data flow path to another component. If a component has no incoming/outgoing connections, it's a design smell.
- **A-2**: Shared utility functions (like protocol icons) belong on the model/enum as getters, not duplicated across UI files.
- **A-3**: Dialog code that's identical across multiple pages should be extracted into a shared function or widget.
- **A-4**: Separate concerns in state management — UI theme settings and AI configuration change for different reasons and should be in different notifiers.

### UI
- **U-1**: Error dismiss buttons must actually clear the error state, not be no-ops.
- **U-2**: Canvas clipping must happen BEFORE drawing, not after (save → clip → draw → restore).
- **U-3**: Row overflow in constrained spaces must use `Flexible` + `TextOverflow.ellipsis`.

### Flutter-Specific
- **F-1**: `DropdownButtonFormField.value` is deprecated in Flutter 3.41+. Use with `// ignore: deprecated_member_use` and `ValueKey` for proper rebuild in `StatefulBuilder`.
- **F-2**: `Matrix4.translate()` and `Matrix4.scale()` are deprecated. Set matrix entries directly: `matrix[0]=scale, matrix[5]=scale, matrix[12]=tx, matrix[13]=ty`.
- **F-3**: `Offset.toVector3()` doesn't exist. Use `Matrix4.inverted().entry(row, col)` for manual coordinate transforms.
- **F-4**: `flutter_markdown` `ExtensionSet` has no `copyWith`. Create new `ExtensionSet(base.blockSyntaxes, [...base.inlineSyntaxes, newSyntax])` instead.
- **F-5**: `MarkdownElementBuilder.visitElementAfterWithContext` returns `Widget?` (not `Widget`) and takes 4 params (context, element, preferredStyle, parentStyle), not 7.
- **F-6**: `BoxDecoration.borderLeft` doesn't exist. Use nested `Container` with `Border(left: ...)` or `Container(decoration: BoxDecoration(border: Border(left: ...)))`.
- **F-7**: Never assign `TextEditingController.text` inside `build()` unconditionally — it resets cursor on every rebuild. Use a note ID check (`_lastLoadedNoteId != note.id`) instead.
- **F-8**: `Markdown` widget doesn't accept `scrollController`. Use `MarkdownBody` for inline or let `Markdown` manage its own scrolling.

### Product UX
- **UX-1**: A service without a UI entry point is a dead feature. Every backend service must have at least one user-accessible trigger (button, menu, shortcut, or command).
- **UX-2**: Empty states must guide the user toward the next action, not just say "nothing here". Show a call-to-action (e.g., "Create notes with [[links]] to see connections").
- **UX-3**: Destructive actions (delete, clear) must require confirmation. One-click delete is a data loss risk.
- **UX-4**: AI streaming output is a core UX expectation. Users should see tokens appear in real-time, not wait for the full response. Show a streaming indicator while in progress.
- **UX-5**: The command bar / search bar is the primary navigation hub. It must search actual data (notes, commands), not just show hardcoded suggestions.
- **UX-6**: Knowledge tools live or die by their link system. If LinkExtractor/LinkResolver exist but aren't called, the graph and backlinks are empty shells. Integration is not optional.
- **UX-7**: Keyboard shortcuts must cover the top 5 user actions. At minimum: search, new note, save, switch view, daily note.
