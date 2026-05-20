#!/usr/bin/env python3
"""
Self-Check Loop: Execute → Check → Reflect → Fix.

Runs flutter analyze and verify_criteria, uses error-capture for
structured analysis, applies retry strategy, and re-runs.
Maximum 3 iterations to prevent infinite loops.

Usage:
    python seeds/verification/self-check.py [--project-root <dir>] [--max-iterations 3]
"""

import argparse
import subprocess
import sys
from pathlib import Path

import yaml

SEEDS_DIR_NAME = "seeds"


def load_retry_config(project_root: Path) -> dict:
    retry_file = project_root / SEEDS_DIR_NAME / "feedback" / "retry-config.yaml"
    if not retry_file.exists():
        return {}
    with open(retry_file, "r", encoding="utf-8") as f:
        return yaml.safe_load(f) or {}


def run_error_capture(project_root: Path, error_output: str, source: str) -> list:
    error_capture = project_root / SEEDS_DIR_NAME / "feedback" / "error-capture.py"
    if not error_capture.exists():
        return []
    import tempfile
    with tempfile.NamedTemporaryFile(mode="w", suffix=".txt", delete=False, encoding="utf-8") as tmp:
        tmp.write(error_output)
        tmp_path = tmp.name
    try:
        proc = subprocess.run(
            [sys.executable, str(error_capture), "--error-output", tmp_path, "--source", source],
            capture_output=True, text=True,
        )
        if proc.returncode == 0 and proc.stdout.strip():
            data = yaml.safe_load(proc.stdout) or {}
            return data.get("errors", [])
    except Exception:
        pass
    finally:
        Path(tmp_path).unlink(missing_ok=True)
    return []


def run_verification(project_root: Path) -> dict:
    result = {"passed": True, "errors": []}

    verify_script = project_root / SEEDS_DIR_NAME / "verification" / "verify_criteria.py"
    if verify_script.exists():
        proc = subprocess.run(
            [sys.executable, str(verify_script), "--project-root", str(project_root)],
            capture_output=True, text=True,
        )
        if proc.returncode != 0:
            result["passed"] = False
            combined = proc.stdout + proc.stderr
            result["errors"].append({"source": "verify_criteria", "output": combined})

    flutter_cmd = "flutter.bat" if sys.platform == "win32" else "flutter"
    lint_result = subprocess.run(
        [flutter_cmd, "analyze"],
        capture_output=True, text=True, cwd=str(project_root), shell=(sys.platform == "win32"),
    )
    if lint_result.returncode != 0:
        output = lint_result.stdout
        has_real_issues = any(' - error - ' in l or ' - warning - ' in l for l in output.split('\n'))
        if has_real_issues:
            result["passed"] = False
            result["errors"].append({"source": "flutter-analyze", "output": output})
            captured = run_error_capture(project_root, output, "flutter-analyze")
            if captured:
                result["errors"][-1]["parsed_errors"] = captured

    return result


def reflect_on_errors(errors: list, retry_config: dict) -> list:
    fixes = []
    for error in errors:
        source = error.get("source", "unknown")
        output = error.get("output", "")
        parsed = error.get("parsed_errors", [])

        if parsed:
            for pe in parsed:
                error_type = pe.get("type", "unknown")
                fix_hint = pe.get("fix_hint", "")
                strategy = _get_retry_strategy(error_type, retry_config)
                fixes.append({"type": strategy, "action": fix_hint, "source": source, "error_type": error_type})
        elif "unused import" in output:
            fixes.append({"type": "auto_fix", "action": "remove_unused_imports", "source": source})
        elif "undefined name" in output:
            fixes.append({"type": "manual_fix", "action": "add_missing_import_or_definition", "source": source})
        else:
            fixes.append({"type": "manual_fix", "action": "investigate_and_fix", "source": source, "detail": output[:200]})

    return fixes


def _get_retry_strategy(error_type: str, retry_config: dict) -> str:
    strategies = retry_config.get("strategies", {})
    for strategy_name, strategy_data in strategies.items():
        if error_type in strategy_data.get("error_types", []):
            return strategy_data.get("strategy", "manual_fix")
    return "manual_fix"


def self_check_loop(project_root: Path, max_iterations: int) -> dict:
    history = []
    retry_config = load_retry_config(project_root)

    for iteration in range(1, max_iterations + 1):
        print(f"\n--- Self-Check Iteration {iteration}/{max_iterations} ---")
        result = run_verification(project_root)
        history.append({"iteration": iteration, "result": result})

        if result["passed"]:
            print(f"[PASS] All checks passed at iteration {iteration}")
            return {"passed": True, "iterations": iteration, "history": history}

        print(f"[FAIL] Checks failed. Errors: {len(result['errors'])}")
        fixes = reflect_on_errors(result["errors"], retry_config)
        print(f"   Proposed fixes: {len(fixes)}")
        for fix in fixes:
            print(f"   - [{fix['type']}] {fix['action']}")

    print(f"\n[WARN] Self-check loop exhausted ({max_iterations} iterations)")
    return {"passed": False, "iterations": max_iterations, "history": history}


def main():
    parser = argparse.ArgumentParser(description="Self-Check Loop")
    parser.add_argument("--project-root", default=".", help="Project root directory")
    parser.add_argument("--max-iterations", type=int, default=3, help="Maximum check iterations")
    args = parser.parse_args()

    project_root = Path(args.project_root).resolve()
    result = self_check_loop(project_root, args.max_iterations)

    if not result["passed"]:
        sys.exit(1)


if __name__ == "__main__":
    main()
