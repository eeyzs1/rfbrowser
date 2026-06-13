# RFBrowser — AI Operating Instructions

This project uses **Meta-Harness** framework as a git submodule at `meta-harness/`.

## Bootstrap (ALWAYS — 4 steps)

1. **Self-update check** — run the platform-appropriate version check script. If an update is available, run the update script immediately, then restart the pipeline.
   - Linux/Mac: `bash meta-harness/scripts/check-version.sh` → if `UPDATE_AVAILABLE=true`, run `bash meta-harness/scripts/update-harness.sh`
   - Windows: `powershell meta-harness/scripts/check-version.ps1` → if `UPDATE_AVAILABLE=true`, run `powershell meta-harness/scripts/update-harness.ps1`
2. **Read `meta-harness/meta/interpreter.md`** — extract measurable acceptance criteria
3. **Read `meta-harness/meta/phase-loader.md`** — load ONLY the files needed for the current phase
4. **Follow the pipeline:** INTERPRET → GENERATE → FACTORY → PROVE → JUDGE → EVOLVE

## About This Project

RFBrowser is a **Flutter desktop application** — an AI-powered knowledge browser.
It is NOT a meta-harness generation pipeline. It IS the actual application.

Key technical facts:
- Flutter 3.27+ with Dart 3.11+
- State management: Riverpod
- WebView: flutter_inappwebview
- Database: SQLite (sqflite)
- File format: Pure Markdown (.md) with YAML frontmatter
- Sync: Git CLI + WebDAV

## Phase-Specific Files (LOAD ON DEMAND)

| Phase | Load |
|-------|------|
| INTERPRET | `meta-harness/meta/interpreter.md` + `meta-harness/meta/phase-loader.md` |
| GENERATE | `meta-harness/meta/harness-generator.md` + `meta-harness/seeds/planning/project-yaml-template.yaml` |
| FACTORY | `meta-harness/meta/agent-factory.md` |
| PROVE | `meta-harness/scripts/verify-generation.py` + `meta-harness/seeds/verification/auditor-engine.md` |
| JUDGE | `meta-harness/seeds/guard.py` + `meta-harness/seeds/planning/orchestrator.py` |
| EVOLVE | `meta-harness/evolution/framework.md` + `meta-harness/scripts/evolve.py` |

## Configuration

Edit `.meta-harness/project.yaml` for project-specific settings.

## Framework Update

```bash
# Linux/Mac
bash meta-harness/scripts/update-harness.sh

# Windows
powershell meta-harness/scripts/update-harness.ps1
```

Full rules live at `meta-harness/meta/rules/` — load only when needed.