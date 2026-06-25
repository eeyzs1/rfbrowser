# RFBrowser — AI Operating Instructions

This project uses **Meta-Harness v2.5** framework as a git submodule at `meta-harness/`.

## PRE-FLIGHT (RUN FIRST — before ANY other work, every turn)

**This is the SINGLE entry point. There is no other bootstrap path.**

1. **Read `meta-harness/.meta-harness/PHASE_BRIEF.md`** — this file tells you exactly:
   - Which phase you're in and whether it's "in_progress", "blocked", or "complete"
   - What the original acceptance criteria are (locked during INTERPRET)
   - What to do next
2. **If PHASE_BRIEF.md does not exist** (fresh start):
   - Run self-update: `powershell meta-harness/scripts/check-version.ps1` (Windows) or `bash meta-harness/scripts/check-version.sh` (Linux/Mac)
   - If `UPDATE_AVAILABLE=true`, run the update script, then restart
   - Run `python meta-harness/meta/meta-orchestrator.py --status` to initialize
3. **If PHASE_BRIEF.md says "status: complete"** → stop. Pipeline is done.
4. **If PHASE_BRIEF.md says "status: blocked"** → diagnose and fix errors, then run `python meta-harness/meta/meta-orchestrator.py --unblock`
5. **Resume from the phase indicated.** Do NOT re-execute completed phases.
6. **Before ANY major action**, check the acceptance criteria. If your action does NOT trace to a criterion, STOP — you are experiencing task drift.

## Pipeline: INTERPRET → GENERATE → FACTORY → PROVE → JUDGE → EVOLVE

The pipeline is driven by `meta-harness/meta/meta-orchestrator.py`. Key commands:

| Command | Purpose |
|---------|---------|
| `--status` | Check current pipeline state |
| `--interpret-intent "<intent>"` | Scripted INTERPRET entry — runs interpret.py, writes task.yaml, locks criteria |
| `--advance` | Mark current phase complete, auto-advance to next (auto-runs next phase script) |
| `--advance --no-auto-run` | Advance without auto-running next phase script |
| `--save-acceptance-criteria "<criteria>"` | Lock acceptance criteria (prevents task drift) |
| `--verify-criterion N` | Mark criterion N as verified with evidence |
| `--reset` | Reset pipeline to fresh state |
| `--force-phase <PHASE>` | Force jump to a specific phase |

## About This Project

RFBrowser is a **Flutter desktop application** — an AI-powered knowledge browser.
The harness pipeline governs all development work on this project.

Key technical facts:
- Flutter 3.27+ with Dart 3.11+
- State management: Riverpod
- WebView: flutter_inappwebview
- Database: SQLite (sqflite)
- File format: Pure Markdown (.md) with YAML frontmatter
- Sync: Git CLI + WebDAV

## Non-Negotiable (these 5 rules ALWAYS apply)

1. **NO mocking real integrations** — use real APIs or explain why you can't
2. **NO completion without evidence** — every claim must be verifiable
3. **NO prototype shortcuts** — engineering-grade or explicit acknowledgment of scope
4. **NO passive waiting** — auto-advance through pipeline without being asked
5. **NO tool path dependency** — evaluate alternatives before reuse

## Phase-Specific Files (LOAD ON DEMAND)

| Phase | Load |
|-------|------|
| INTERPRET | `meta-harness/meta/interpreter.md` + `meta-harness/meta/phase-loader.md` + `meta-harness/seeds/planning/planner-engine.md` |
| GENERATE | `meta-harness/meta/harness-generator.md` + `meta-harness/seeds/planning/project-yaml-template.yaml` |
| FACTORY | `meta-harness/meta/agent-factory.md` |
| PROVE | `meta-harness/scripts/verify-generation.py` + `meta-harness/seeds/verification/auditor-engine.md` |
| JUDGE | `meta-harness/seeds/guard.py` + `meta-harness/seeds/orchestrator.py` |
| EVOLVE | `meta-harness/evolution/framework.md` + `meta-harness/scripts/evolve.py` |

## Rule Files (LOAD ON DEMAND)

All rules are unified in `meta-harness/meta/rules/absolute-rules.md`. Load the relevant appendix:

| Trigger | Load |
|---------|------|
| Mock/fake/stub patterns detected | `absolute-rules.md` Appendix A |
| Code generation phase | `absolute-rules.md` Appendix B |
| Introducing new dependencies | `absolute-rules.md` Appendix C |
| Self-check (suspect heuristic trap) | `absolute-rules.md` Appendix D |
| Any rule conflict or uncertainty | `absolute-rules.md` full text |

## Configuration

Edit `.meta-harness/project.yaml` for project-specific settings.

## Framework Update

```bash
# Linux/Mac
bash meta-harness/scripts/update-harness.sh

# Windows
powershell meta-harness/scripts/update-harness.ps1
```