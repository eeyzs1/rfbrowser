# Meta-Harness-Generator: Task → Executable Harness Project

## Purpose
Generate a COMPLETE, RUNNABLE, SELF-EVOLVING harness engineering project.
Not documents. Not descriptions. An executable system with all seven layers.

## What Gets Generated
A full project in `generated/[project-name]/` that includes:

### Layer 1: Context Engineering
- AGENTS.md / CLAUDE.md — project-specific context files
- Dynamic context loader — script that assembles relevant context per task
- Knowledge index — maps which files contain what knowledge

### Layer 2: Tool Integration
- Tool schema definitions (OpenAPI/function-call format)
- Sandbox config (Docker/container config if applicable)
- Permission manifests (what each agent role can access)
- MCP server configs (if applicable)

### Layer 3: Memory & State
- Session state files (progress, checkpoints)
- Long-term memory structure (vector DB config or file-based index)
- Snapshot/rollback mechanism (git-based)
- Memory compression rules (what to keep, what to summarize, what to forget)

### Layer 4: Planning & Orchestration
- Task decomposition engine (DAG builder script)
- Execution flow controller (sequential, parallel, conditional, retry)
- Sub-agent dispatcher (role routing config)
- Reasoning budget config (step limits, time limits, token limits)

### Layer 5: Verification & Guardrails
- Output format validators (JSON/XML schema files)
- Logic consistency checks (test configs, linter rules)
- Security guardrails (sensitive data filters, dangerous operation blockers)
- Self-verification loop script (execute → check → reflect → fix)

### Layer 6: Feedback & Self-Healing
- Error capture and parser (structured error format)
- Auto-retry with backoff strategy config
- Error→constraint optimization loop (mistakes.md → constraints/)
- Human intervention interface (approval queue, escalation config)

### Layer 7: Constraints & Entropy Management
- Architecture constraint rules (dependency direction, layer rules)
- Code enforcement configs (custom linter rules, pre-commit hooks)
- Entropy reduction schedule (cleanup scripts, consistency checks)
- Resource/cost constraints (budget config, rate limits, circuit breakers)

### Cross-Cutting: Security & Isolation
- Environment isolation config (sandbox, network rules)
- Data security rules (encryption, masking, access control)
- Audit log config (traceability, immutability)

### Cross-Cutting: Observability & Governance
- Tracing config (call chains, timing, token consumption)
- Metrics dashboard config (success rate, error rate, latency, cost)
- Session replay config (conversation reconstruction, issue reproduction)
- Version & config management (harness versioning, reproducibility)

### Self-Evolution System
- evolution/framework.md — evidence-driven evolution algorithm
- evolution/genome.md — current evolvable state
- evolution/log.md — evolution history
- Evolution triggers: periodic, reactive, emergency, adaptive

## Generation Steps

1. **Read task definition** from interpreter output
2. **Select base template** from `templates/` as reference (NOT as starting point)
3. **For each layer**: analyze what the task requires, generate ONLY what's needed
4. **Wire layers together**: ensure each layer references the others correctly
5. **Generate entry points**: AGENTS.md, CLAUDE.md, main execution scripts
6. **Generate evolution system**: adapted to the task's specific metrics
7. **Verify completeness**: every layer has at least one concrete artifact

## Output Structure
```
generated/[project-name]/
├── AGENTS.md              ← Project context (auto-loaded by AI IDEs)
├── CLAUDE.md              ← Project context (Claude Code)
├── context/               ← Layer 1: Context Engineering
├── tools/                 ← Layer 2: Tool Integration
├── memory/                ← Layer 3: Memory & State
├── planning/              ← Layer 4: Planning & Orchestration
├── verification/          ← Layer 5: Verification & Guardrails
├── feedback/              ← Layer 6: Feedback & Self-Healing
├── constraints/           ← Layer 7: Constraints & Entropy
├── security/              ← Cross-cutting: Security & Isolation
├── observability/         ← Cross-cutting: Observability & Governance
├── evolution/             ← Self-Evolution System
└── scripts/               ← Executable scripts
```

## Anti-Patterns
- Do NOT generate documentation-only layers — every layer must have executable artifacts
- Do NOT generate boilerplate — only what the specific task requires
- Do NOT skip layers — even minimal implementations are required
- Do NOT generate without evidence traceability — every artifact traces to a requirement

## Post-Generation Verification Checklist

### Component Connectivity Audit
After generating all components, verify that NO component is an isolated silo:
1. Map every component's incoming data flows (what it reads from others)
2. Map every component's outgoing data flows (what it writes/sends to others)
3. If any component has ZERO incoming or ZERO outgoing flows → it's a silo → connect it
4. The minimum viable product must form a connected graph, not a forest of isolated nodes

### Performance Audit
1. Drag/resize handlers must NOT persist to disk on every frame
2. `CustomPainter.shouldRepaint` must compare data, not return `true`
3. SharedPreferences instances must be cached, not re-created per call

### Security Audit
1. WebView must filter `file://`, `javascript:`, `data:` URL schemes
2. API keys must use secure storage, not be stored in observable state
3. Path sanitization must use normalization, not string replacement

### Correctness Audit
1. API response parsing must be defensive (null-check every nested level)
2. Concurrent state mutations must be guarded (check isLoading)
3. List item removal must calculate new active index BEFORE removing
4. `copyWith` must support setting nullable fields to null

### Product UX Audit
1. Every backend service MUST have a UI entry point — no dead features
2. Empty states MUST guide the user toward the next action, not just say "nothing"
3. Destructive actions MUST require confirmation (delete, clear, reset)
4. AI output MUST use streaming when available — show tokens in real-time
5. Search/command bar MUST search actual data, not just hardcoded suggestions
6. Link systems MUST be integrated — LinkExtractor/LinkResolver must be called
7. Keyboard shortcuts MUST cover top 5 user actions
8. TextEditingController.text MUST NOT be assigned unconditionally in build()

### Flutter API Audit
1. `flutter_markdown` ExtensionSet has no `copyWith` — use constructor with spread
2. `MarkdownElementBuilder.visitElementAfterWithContext` returns `Widget?` with 4 params
3. `BoxDecoration` has no `borderLeft` — use nested Container or `Border(left: ...)`
4. `Markdown` widget doesn't accept `scrollController`
5. `DropdownButtonFormField.value` is deprecated — use with ignore annotation + ValueKey
