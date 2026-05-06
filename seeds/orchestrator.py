#!/usr/bin/env python3
"""
Orchestrator: The execution engine of the generated harness.

Implements the core loop: EXECUTE → PROVE → JUDGE → LOOP
Coordinates all 7 layers + 2 cross-cutting systems.

This is the ENTRY POINT for the generated harness project.
AI agents should start here.

Usage:
    python orchestrator.py --task task.yaml
    python orchestrator.py --status
    python orchestrator.py --evolve
"""

import argparse
import json
import subprocess
import sys
from datetime import datetime
from pathlib import Path

import yaml

PROJECT_ROOT = Path(__file__).resolve().parent.parent


def run_script(script_path: Path, args: list = None) -> subprocess.CompletedProcess:
    cmd = [sys.executable, str(script_path)]
    if args:
        cmd.extend(args)
    return subprocess.run(cmd, capture_output=True, text=True, cwd=str(PROJECT_ROOT))


def load_task() -> dict:
    task_file = PROJECT_ROOT / "task.yaml"
    if not task_file.exists():
        print("ERROR: No task.yaml found. Create one first.")
        print("  See the Acceptance Criteria in AGENTS.md for guidance.")
        sys.exit(1)
    with open(task_file, "r", encoding="utf-8") as f:
        return yaml.safe_load(f) or {}


def load_session_state() -> dict:
    state_file = PROJECT_ROOT / "seeds" / "memory" / "session-state.yaml"
    if not state_file.exists():
        return {"status": "not_started", "progress": {"completed_criteria": [], "failed_criteria": []}}
    with open(state_file, "r", encoding="utf-8") as f:
        return yaml.safe_load(f) or {}


def save_session_state(state: dict) -> None:
    state_file = PROJECT_ROOT / "seeds" / "memory" / "session-state.yaml"
    state["updated_at"] = datetime.now().isoformat()
    with open(state_file, "w", encoding="utf-8") as f:
        yaml.dump(state, f, default_flow_style=False, allow_unicode=True)


def step_execute(task: dict) -> dict:
    print("\n" + "=" * 60)
    print("STEP: EXECUTE")
    print("=" * 60)

    state = load_session_state()
    criteria = task.get("acceptance_criteria", [])
    completed = state.get("progress", {}).get("completed_criteria", [])

    if not criteria:
        print("No acceptance criteria defined. Check task.yaml.")
        return {"status": "no_criteria"}

    pending = [c for c in criteria if c not in completed]
    print(f"Total criteria: {len(criteria)}")
    print(f"Completed: {len(completed)}")
    print(f"Pending: {len(pending)}")

    if not pending:
        print("All criteria already completed!")
        return {"status": "all_complete"}

    print(f"\nNext criterion to implement:")
    print(f"  → {pending[0]}")
    print(f"\nAction required: Implement this criterion in lib/")
    print(f"Follow the workflow in seeds/planning/flow-control.yaml")
    print(f"Respect constraints in seeds/constraints/architecture-rules.yaml")

    task_runner = PROJECT_ROOT / "seeds" / "execution" / "task-runner.py"
    if task_runner.exists():
        print(f"\n  Running: python {task_runner.relative_to(PROJECT_ROOT)} --analyze-only")
        proc = run_script(task_runner, ["--analyze-only"])
        if proc.returncode == 0:
            print("  ✅ flutter analyze passed")
        else:
            print("  ⚠️  flutter analyze found issues — check output above")

    return {"status": "pending", "next_criterion": pending[0], "pending": pending}


def step_prove(task: dict) -> dict:
    print("\n" + "=" * 60)
    print("STEP: PROVE")
    print("=" * 60)

    criteria = task.get("acceptance_criteria", [])
    state = load_session_state()
    completed = state.get("progress", {}).get("completed_criteria", [])
    evidence = []

    for criterion in criteria:
        if criterion in completed:
            evidence.append({"criterion": criterion, "verdict": "SATISFIED", "evidence": "Previously verified"})
            continue
        evidence.append({"criterion": criterion, "verdict": "NOT_SATISFIED", "evidence": "Not yet implemented"})

    satisfied_count = sum(1 for e in evidence if e["verdict"] == "SATISFIED")
    total_count = len(evidence)

    print(f"Evidence: {satisfied_count}/{total_count} criteria satisfied")
    for e in evidence:
        status = "✅" if e["verdict"] == "SATISFIED" else "❌"
        print(f"  {status} {e['criterion']}")

    return {"satisfied": satisfied_count, "total": total_count, "evidence": evidence}


def step_judge(prove_result: dict) -> dict:
    print("\n" + "=" * 60)
    print("STEP: JUDGE")
    print("=" * 60)

    satisfied = prove_result.get("satisfied", 0)
    total = prove_result.get("total", 1)

    if total == 0:
        verdict = "NO_CRITERIA"
    elif satisfied == total:
        verdict = "PROVEN"
    else:
        verdict = "NOT_PROVEN"

    print(f"Verdict: {verdict} ({satisfied}/{total})")

    if verdict == "NOT_PROVEN":
        unsatisfied = [e for e in prove_result.get("evidence", []) if e["verdict"] != "SATISFIED"]
        print(f"\nUnsatisfied criteria:")
        for e in unsatisfied:
            print(f"  ❌ {e['criterion']}")
        print(f"\nRoot cause analysis needed. Check:")
        print(f"  - Are the constraints in seeds/constraints/ being followed?")
        print(f"  - Is the workflow in seeds/planning/flow-control.yaml being followed?")
        print(f"  - Run: python seeds/feedback/error-capture.py to analyze errors")
        print(f"  - Run: python seeds/feedback/mistake-to-constraint.py to propose new constraints")

    return {"verdict": verdict, "satisfied": satisfied, "total": total}


def step_evolve() -> dict:
    print("\n" + "=" * 60)
    print("STEP: EVOLVE")
    print("=" * 60)

    evolve_script = PROJECT_ROOT / "scripts" / "evolve.py"
    if evolve_script.exists():
        proc = run_script(evolve_script, ["--project-root", str(PROJECT_ROOT)])
        if proc.returncode == 0:
            print("Evolution cycle completed.")
            return {"status": "evolved"}
        else:
            print(f"Evolution failed: {proc.stderr}")
            return {"status": "evolution_failed"}
    else:
        print("Evolution script not found in this project.")
        print("Run: python scripts/evolve.py --project-root .")
        return {"status": "no_evolve_script"}


def step_innovate() -> dict:
    print("\n" + "=" * 60)
    print("STEP: INNOVATE — 推陈出新")
    print("=" * 60)

    innovation_engine = PROJECT_ROOT / "seeds" / "evolution" / "innovation-engine.py"
    if innovation_engine.exists():
        proc = run_script(innovation_engine, ["--project-root", str(PROJECT_ROOT)])
        if proc.returncode == 0:
            print("Innovation cycle completed.")
            return {"status": "innovated"}
        else:
            print(f"Innovation analysis: {proc.stdout}")
            return {"status": "no_innovations"}
    else:
        print("Innovation engine not found.")
        return {"status": "no_innovation_engine"}


def run_verification() -> dict:
    print("\n--- Running Verification ---")
    self_check = PROJECT_ROOT / "seeds" / "verification" / "self-check.py"
    if self_check.exists():
        proc = run_script(self_check, ["--project-root", str(PROJECT_ROOT)])
        if proc.returncode == 0:
            print("✅ Verification passed")
            return {"passed": True}
        else:
            print("❌ Verification failed")
            print(proc.stdout)
            return {"passed": False}
    else:
        print("⚠️  self-check.py not found, skipping verification")
        return {"passed": None}


def run_loop(task: dict, max_iterations: int = 10) -> dict:
    print(f"\n{'#'*60}")
    print(f"# HARNESS ORCHESTRATION LOOP")
    print(f"# Task: {task.get('name', 'unknown')}")
    print(f"# Max iterations: {max_iterations}")
    print(f"{'#'*60}")

    for iteration in range(1, max_iterations + 1):
        print(f"\n{'='*60}")
        print(f"ITERATION {iteration}/{max_iterations}")
        print(f"{'='*60}")

        execute_result = step_execute(task)

        if execute_result.get("status") == "all_complete":
            print("\n✅ All criteria already completed!")
            break

        prove_result = step_prove(task)
        judge_result = step_judge(prove_result)

        if judge_result["verdict"] == "PROVEN":
            print(f"\n🎉 ALL CRITERIA PROVEN at iteration {iteration}!")
            run_verification()
            step_evolve()
            step_innovate()
            break

        print(f"\n⚠️  Not yet proven. Continue implementing...")

        if iteration == max_iterations:
            print(f"\n❌ Loop exhausted ({max_iterations} iterations). Manual intervention needed.")

    return load_session_state()


def load_genome() -> dict:
    genome_file = PROJECT_ROOT / "seeds" / "evolution" / "genome.yaml"
    if not genome_file.exists():
        return {}
    with open(genome_file, "r", encoding="utf-8") as f:
        return yaml.safe_load(f) or {}


def check_constraints_against_codebase() -> dict:
    genome = load_genome()
    constraints = genome.get("harness_genome", {}).get("constraints", [])
    active_constraints = [c for c in constraints if c.get("status") != "dormant"]
    dormant_count = len([c for c in constraints if c.get("status") == "dormant"])
    violations = []

    for c in active_constraints:
        rule = c.get("rule", "")
        cid = c.get("id", "")
        if c.get("trigger_count", 0) > 0:
            continue

        check = _check_single_constraint(cid, rule)
        if check.get("violated"):
            violations.append({"constraint_id": cid, "rule": rule, "evidence": check.get("evidence", ""), "severity": "high"})

    unmet = [c for c in active_constraints if c.get("trigger_count", 0) == 0 and not any(v["constraint_id"] == c["id"] for v in violations)]
    for c in unmet[:5]:
        violations.append({"constraint_id": c["id"], "rule": c["rule"], "evidence": "not yet verified in this codebase", "severity": "medium"})

    return {
        "total_constraints": len(constraints),
        "active_constraints": len(active_constraints),
        "dormant_constraints": dormant_count,
        "violations": violations,
        "violation_count": len(violations)
    }


def _check_single_constraint(cid: str, rule: str) -> dict:
    lib_dir = PROJECT_ROOT / "lib"
    evidence = ""

    if cid == "C004":
        for dart_file in lib_dir.rglob("*.dart"):
            try:
                content = dart_file.read_text(encoding="utf-8")
                if "bool shouldRepaint" in content and "return true;" in content.split("bool shouldRepaint")[-1][:100]:
                    evidence = f"Found shouldRepaint returning true in {dart_file.name}"
                    return {"violated": True, "evidence": evidence}
            except Exception:
                pass

    if cid == "C006":
        for dart_file in lib_dir.rglob("*.dart"):
            try:
                content = dart_file.read_text(encoding="utf-8")
                import re
                if re.search(r'catch\s*\(\s*_\s*\)\s*\{\s*\}', content):
                    evidence = f"Found empty catch block in {dart_file.name}"
                    return {"violated": True, "evidence": evidence}
            except Exception:
                pass

    if cid == "C015":
        for dart_file in lib_dir.rglob("*.dart"):
            try:
                content = dart_file.read_text(encoding="utf-8")
                if "webview" in dart_file.name.lower() or "web_view" in dart_file.name.lower():
                    if "shouldOverrideUrlLoading" not in content:
                        evidence = f"WebView file {dart_file.name} missing shouldOverrideUrlLoading"
                        return {"violated": True, "evidence": evidence}
            except Exception:
                pass

    if cid == "C033":
        for dart_file in lib_dir.rglob("*.dart"):
            try:
                content = dart_file.read_text(encoding="utf-8")
                if ("delete" in dart_file.name.lower() or "remove" in dart_file.name.lower()) and "confirm" not in content.lower() and "showDialog" not in content:
                    evidence = f"Destructive action in {dart_file.name} may lack confirmation"
                    return {"violated": True, "evidence": evidence}
            except Exception:
                pass

    return {"violated": False, "evidence": ""}


def generate_next_task() -> dict:
    check_result = check_constraints_against_codebase()
    violations = check_result.get("violations", [])
    high_severity = [v for v in violations if v["severity"] == "high"]

    genome = load_genome()
    innovations = []
    innovation_log = PROJECT_ROOT / "seeds" / "evolution" / "innovation-log.yaml"
    if innovation_log.exists():
        with open(innovation_log, "r", encoding="utf-8") as f:
            data = yaml.safe_load(f) or {}
        innovations = [p for p in data.get("proposals", []) if p.get("status") == "applied"]

    advancements = {}
    adv_file = PROJECT_ROOT / "seeds" / "evolution" / "domain-advancements.yaml"
    if adv_file.exists():
        with open(adv_file, "r", encoding="utf-8") as f:
            advancements = yaml.safe_load(f) or {}

    next_innovations = []
    stages = advancements.get("stages", [])
    current_idx = 0
    for i, s in enumerate(stages):
        if s.get("name") == "Solid":
            current_idx = i
            break
    if current_idx < len(stages):
        stage = stages[current_idx]
        next_innovations = [inv for inv in stage.get("innovations", []) if not any(
            i.get("name") == inv.get("name") and i.get("status") == "applied" for i in innovations
        )]

    task_card = {
        "generated_at": datetime.now().isoformat(),
        "priority_constraints_to_fix": high_severity[:3],
        "all_pending_constraints": violations[:5],
        "next_innovations": next_innovations[:3],
        "suggested_workflow": "bugfix" if high_severity else "feature",
        "pre_check_command": "python seeds/orchestrator.py --verify",
        "post_check_command": "python seeds/orchestrator.py --verify",
        "mandatory_rules": [
            "Run `flutter analyze` before and after every change",
            "Check genome.yaml constraints for the module being modified",
            "If a mistake is made, add it to seeds/memory/meta-mistakes.md",
            "After completion, run: python seeds/orchestrator.py --mark-complete \"<criterion>\"",
        ],
    }

    return task_card


def show_status() -> None:
    task = load_task()
    state = load_session_state()
    criteria = task.get("acceptance_criteria", [])
    completed = state.get("progress", {}).get("completed_criteria", [])
    genome = load_genome()
    constraints = genome.get("harness_genome", {}).get("constraints", [])
    active_count = len([c for c in constraints if c.get("status") == "active"])
    dormant_count = len([c for c in constraints if c.get("status") == "dormant"])
    verified_needed_count = len([c for c in constraints if c.get("status") == "verified-needed"])

    print(f"\n{'='*60}")
    print(f"PROJECT STATUS")
    print(f"{'='*60}")
    print(f"Task: {task.get('name', 'unknown')}")
    print(f"Goal: {task.get('goal', 'N/A')}")
    print(f"Status: {state.get('status', 'unknown')}")
    print(f"\nAcceptance Criteria: {len(completed)}/{len(criteria)} satisfied")
    for c in criteria:
        status = "✅" if c in completed else "❌"
        print(f"  {status} {c}")

    print(f"\nGenome Constraints: {len(constraints)} total")
    print(f"  active: {active_count} | dormant: {dormant_count} | verified-needed: {verified_needed_count}")

    print(f"\nNext steps:")
    pending = [c for c in criteria if c not in completed]
    if pending:
        print(f"  1. Implement: {pending[0]}")
        print(f"  2. Run: python orchestrator.py --verify")
        print(f"  3. Mark complete in memory/session-state.yaml")
    else:
        print(f"  All criteria satisfied! Run: python orchestrator.py --evolve")


def main():
    parser = argparse.ArgumentParser(description="Harness Orchestrator — Entry Point")
    parser.add_argument("--task", default=None, help="Path to task definition (default: task.yaml)")
    parser.add_argument("--status", action="store_true", help="Show current project status")
    parser.add_argument("--verify", action="store_true", help="Run verification only")
    parser.add_argument("--evolve", action="store_true", help="Run evolution cycle only")
    parser.add_argument("--innovate", action="store_true", help="Run innovation cycle (推陈出新)")
    parser.add_argument("--check-constraints", action="store_true", help="Check genome constraints against codebase")
    parser.add_argument("--next-task", action="store_true", help="Generate next actionable task card")
    parser.add_argument("--max-iterations", type=int, default=10, help="Max loop iterations")
    parser.add_argument("--mark-complete", default=None, help="Mark a criterion as complete")
    args = parser.parse_args()

    if args.status:
        show_status()
        return

    if args.verify:
        run_verification()
        return

    if args.evolve:
        step_evolve()
        return

    if args.innovate:
        step_innovate()
        return

    if args.check_constraints:
        result = check_constraints_against_codebase()
        print(yaml.dump(result, default_flow_style=False, allow_unicode=True))
        return

    if args.next_task:
        task_card = generate_next_task()
        print(yaml.dump(task_card, default_flow_style=False, allow_unicode=True))
        return

    if args.mark_complete:
        state = load_session_state()
        completed = state.get("progress", {}).get("completed_criteria", [])
        if args.mark_complete not in completed:
            completed.append(args.mark_complete)
            state.setdefault("progress", {})["completed_criteria"] = completed
            state["status"] = "in_progress"
            save_session_state(state)
            print(f"✅ Marked as complete: {args.mark_complete}")
        else:
            print(f"Already completed: {args.mark_complete}")
        return

    task = load_task()
    run_loop(task, args.max_iterations)


if __name__ == "__main__":
    main()
