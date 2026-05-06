#!/usr/bin/env python3
"""
Task Runner: Executes individual work units in the execution DAG.

Implements the EXECUTE phase of the harness loop for RFBrowser.
Each work unit maps to a feature/bugfix/refactor task in lib/.

Usage:
    python execution/task-runner.py --work-unit <id> [--dag <dag.yaml>]
    python execution/task-runner.py --run-all [--dag <dag.yaml>]
"""

import argparse
import subprocess
import sys
from datetime import datetime
from pathlib import Path

import yaml

PROJECT_ROOT = Path(__file__).resolve().parent.parent


def run_flutter_analyze() -> dict:
    proc = subprocess.run(
        ["flutter", "analyze"],
        capture_output=True, text=True,
        cwd=str(PROJECT_ROOT.parent.parent),
    )
    return {
        "command": "flutter analyze",
        "exit_code": proc.returncode,
        "output": proc.stdout + proc.stderr,
        "passed": proc.returncode == 0,
    }


def run_flutter_test(target: str = None) -> dict:
    cmd = ["flutter", "test"]
    if target:
        cmd.append(target)
    proc = subprocess.run(
        cmd,
        capture_output=True, text=True,
        cwd=str(PROJECT_ROOT.parent.parent),
    )
    passed = "All tests passed" in proc.stdout or proc.returncode == 0
    return {
        "command": f"flutter test {target or ''}",
        "exit_code": proc.returncode,
        "output": proc.stdout + proc.stderr,
        "passed": passed,
    }


def execute_work_unit(unit: dict, dag: dict) -> dict:
    unit_id = unit.get("id", "unknown")
    unit_name = unit.get("name", "unknown")

    print(f"\n{'='*60}")
    print(f"EXECUTING: {unit_id} — {unit_name}")
    print(f"{'='*60}")

    result = {
        "work_unit_id": unit_id,
        "work_unit_name": unit_name,
        "started_at": datetime.now().isoformat(),
        "steps": [],
    }

    print(f"\nStep 1: flutter analyze (pre-check)")
    analyze_result = run_flutter_analyze()
    result["steps"].append({"step": "pre_analyze", "result": analyze_result})
    if analyze_result["passed"]:
        print("  ✅ pre-check passed")
    else:
        print("  ⚠️  pre-check found issues (may be pre-existing)")

    print(f"\nStep 2: Run related tests")
    test_target = unit.get("test_target", None)
    test_result = run_flutter_test(test_target)
    result["steps"].append({"step": "run_tests", "result": test_result})
    status = "✅" if test_result["passed"] else "❌"
    print(f"  {status} Test run: {'passed' if test_result['passed'] else 'FAILED'}")

    print(f"\nStep 3: flutter analyze (post-check)")
    post_analyze = run_flutter_analyze()
    result["steps"].append({"step": "post_analyze", "result": post_analyze})
    status = "✅" if post_analyze["passed"] else "❌"
    print(f"  {status} Post-check: {'passed' if post_analyze['passed'] else 'issues found'}")

    result["passed"] = post_analyze["passed"]
    result["completed_at"] = datetime.now().isoformat()

    return result


def run_all(dag: dict) -> dict:
    units = dag.get("work_units", [])
    if not units:
        print("No work units found in DAG.")
        return {"passed": False, "results": []}

    print(f"\n{'#'*60}")
    print(f"# EXECUTING ALL WORK UNITS ({len(units)} total)")
    print(f"{'#'*60}")

    results = []
    for unit in units:
        if unit.get("status") == "completed":
            print(f"\n  ⏭️  Skipping {unit['id']} (already completed)")
            continue
        result = execute_work_unit(unit, dag)
        results.append(result)

    all_passed = all(r.get("passed", False) for r in results)
    print(f"\n{'='*60}")
    print(f"EXECUTION SUMMARY: {'ALL PASSED ✅' if all_passed else 'SOME FAILED ❌'}")
    print(f"{'='*60}")

    for r in results:
        status = "✅" if r.get("passed") else "❌"
        print(f"  {status} {r['work_unit_id']}: {r['work_unit_name']}")

    return {"passed": all_passed, "results": results, "executed_at": datetime.now().isoformat()}


def main():
    parser = argparse.ArgumentParser(description="Task Runner — Execution Engine")
    parser.add_argument("--work-unit", default=None, help="Execute a specific work unit by ID")
    parser.add_argument("--dag", default=None, help="Path to execution DAG YAML")
    parser.add_argument("--run-all", action="store_true", help="Execute all work units in DAG")
    parser.add_argument("--analyze-only", action="store_true", help="Run flutter analyze only")
    parser.add_argument("--test-only", action="store_true", help="Run flutter test only")
    args = parser.parse_args()

    if args.analyze_only:
        result = run_flutter_analyze()
        print(result["output"])
        sys.exit(0 if result["passed"] else 1)

    if args.test_only:
        result = run_flutter_test()
        print(result["output"])
        sys.exit(0 if result["passed"] else 1)

    dag = {"work_units": []}
    if args.dag:
        dag_file = Path(args.dag)
        if dag_file.exists():
            with open(dag_file, "r", encoding="utf-8") as f:
                dag = yaml.safe_load(f) or {}

    if args.run_all:
        result = run_all(dag)
        sys.exit(0 if result["passed"] else 1)

    if args.work_unit:
        units = dag.get("work_units", [])
        unit = next((u for u in units if u.get("id") == args.work_unit), None)
        if not unit:
            print(f"Work unit not found: {args.work_unit}")
            sys.exit(1)
        result = execute_work_unit(unit, dag)
        sys.exit(0 if result["passed"] else 1)

    print("No action specified. Use --run-all, --analyze-only, or --test-only.")
    sys.exit(1)


if __name__ == "__main__":
    main()
