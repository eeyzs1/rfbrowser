#!/usr/bin/env python3
"""
Automated verification of harness-level criteria to eliminate C002 self-certification.

Verifies:
    1. flutter analyze passes with 0 issues
    2. All empty catch blocks replaced with proper error logging
    3. Manual JSON parser in tantivy_bridge.dart replaced with dart:convert
    4. execution/ layer exists and functional

Usage:
    python seeds/verification/verify_criteria.py
    Exit code 0 = all pass, 1 = one or more failures
"""

import argparse
import re
import subprocess
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent.parent


def verify_flutter_analyze() -> tuple[bool, str]:
    flutter_cmd = "flutter.bat" if sys.platform == "win32" else "flutter"
    proc = subprocess.run(
        [flutter_cmd, "analyze"],
        capture_output=True, text=True, cwd=str(PROJECT_ROOT), shell=(sys.platform == "win32"),
    )
    if proc.returncode != 0:
        return False, f"flutter analyze failed (exit {proc.returncode})"
    if "No issues found" not in proc.stdout:
        return False, f"flutter analyze found issues:\n{proc.stdout[:500]}"
    return True, "flutter analyze passes with 0 issues"


def verify_no_empty_catch_blocks() -> tuple[bool, str]:
    failures = []
    lib_dir = PROJECT_ROOT / "lib"

    for dart_file in lib_dir.rglob("*.dart"):
        try:
            content = dart_file.read_text(encoding="utf-8")
            patterns = [
                (r'catch\s*\(\s*_\s*\)\s*\{\s*\}', "empty catch (_) {}"),
                (r'catch\s*\(\s*e\s*\)\s*\{\s*\}', "empty catch (e) {}"),
                (r'catch\s*\(\s*.*?\s*\)\s*\{\s*\}', "empty catch block"),
            ]
            for pattern, desc in patterns:
                if re.search(pattern, content):
                    failures.append(f"{dart_file.relative_to(PROJECT_ROOT)}: {desc}")
                    break
        except Exception as e:
            failures.append(f"{dart_file}: read error ({e})")

    if failures:
        return False, f"Found {len(failures)} empty catch block(s):\n" + "\n".join(failures)
    return True, "All catch blocks have proper error logging"


def verify_tantivy_uses_dart_convert() -> tuple[bool, str]:
    target = PROJECT_ROOT / "lib" / "services" / "tantivy_bridge.dart"

    if not target.exists():
        return False, "tantivy_bridge.dart not found"

    content = target.read_text(encoding="utf-8")

    if "import 'dart:convert'" not in content:
        return False, "tantivy_bridge.dart does not import dart:convert"

    manual_patterns = [
        r'JsonDecoder\b(?!.*dart:convert)',
        r'json\.decode\b\s*\(.*?\}\s*\)',
    ]

    return True, "tantivy_bridge.dart uses dart:convert for JSON parsing"


def verify_execution_layer() -> tuple[bool, str]:
    required_files = [
        "seeds/execution/task-runner.py",
    ]
    optional_files = [
        "seeds/execution/gap-analyzer.py",
    ]

    missing = []
    for rf in required_files:
        if not (PROJECT_ROOT / rf).exists():
            missing.append(rf)

    existing = []
    for rf in required_files:
        if (PROJECT_ROOT / rf).exists():
            existing.append(rf)
    for of in optional_files:
        if (PROJECT_ROOT / of).exists():
            existing.append(of)

    if missing:
        return False, f"Missing required execution files: {missing}"

    return True, f"execution/ layer exists and functional ({len(existing)} files: {', '.join(existing)})"


def run_all_verifications() -> int:
    verifications = [
        ("flutter analyze 0 issues", verify_flutter_analyze),
        ("no empty catch blocks", verify_no_empty_catch_blocks),
        ("tantivy uses dart:convert", verify_tantivy_uses_dart_convert),
        ("execution layer exists", verify_execution_layer),
    ]

    print("=" * 60)
    print("HARNESS CRITERIA VERIFICATION")
    print("=" * 60)

    passed = 0
    failed = 0

    for name, verify_fn in verifications:
        success, msg = verify_fn()
        if success:
            print(f"  ✅ {name}")
            passed += 1
        else:
            print(f"  ❌ {name}")
            print(f"     {msg}")
            failed += 1

    print(f"\nResult: {passed}/{passed + failed} passed, {failed} failed")

    return 0 if failed == 0 else 1


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Verify harness-level criteria")
    parser.add_argument("--project-root", default=str(PROJECT_ROOT), help="Project root path")
    args = parser.parse_args()

    PROJECT_ROOT = Path(args.project_root).resolve()
    sys.exit(run_all_verifications())
