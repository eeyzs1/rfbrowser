#!/usr/bin/env python3
"""
RFBrowser Post-Task Verification Script.

Runs: flutter analyze, flutter test, flutter build, and secret scanning.

Usage:
    python scripts/verify.py [--skip-build]
"""

import argparse
import re
import subprocess
import sys
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parent.parent


def run_command(cmd: list, cwd: Path = None) -> tuple:
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, cwd=cwd or PROJECT_ROOT)
        return result.returncode, result.stdout, result.stderr
    except FileNotFoundError:
        return -1, "", f"Command not found: {cmd[0]}"


def check_flutter_analyze() -> list:
    errors = []
    rc, out, err = run_command(["flutter", "analyze"])
    if rc != 0:
        errors.append(f"FAIL: flutter analyze found issues (exit code {rc})")
        if out:
            for line in out.strip().split("\n")[-5:]:
                errors.append(f"  {line}")
    return errors


def check_flutter_test() -> list:
    errors = []
    rc, out, err = run_command(["flutter", "test"])
    if rc != 0:
        errors.append(f"FAIL: flutter test failed (exit code {rc})")
        if out:
            for line in out.strip().split("\n")[-10:]:
                if "FAIL" in line or "Error" in line or "failed" in line:
                    errors.append(f"  {line}")
    return errors


def check_flutter_build() -> list:
    errors = []
    rc, out, err = run_command(["flutter", "build", "windows", "--debug"])
    if rc != 0:
        errors.append(f"FAIL: flutter build failed (exit code {rc})")
        if err:
            for line in err.strip().split("\n")[-5:]:
                errors.append(f"  {line}")
    return errors


def scan_secrets() -> list:
    errors = []
    secret_patterns = [
        (r"password\s*=\s*['\"][^'\"]{4,}['\"]", "hardcoded password"),
        (r"api_key\s*=\s*['\"][^'\"]{4,}['\"]", "hardcoded API key"),
        (r"secret\s*=\s*['\"][^'\"]{4,}['\"]", "hardcoded secret"),
        (r"token\s*=\s*['\"][^'\"]{8,}['\"]", "hardcoded token (min 8 chars)"),
        (r"-----BEGIN\s+(RSA|EC|DSA|OPENSSH)?\s*PRIVATE KEY", "private key"),
    ]

    scan_extensions = {".dart", ".yaml", ".yml", ".json", ".env"}
    skip_dirs = {"build", ".dart_tool", ".git", "node_modules", "__pycache__"}

    for f in PROJECT_ROOT.rglob("*"):
        if not f.is_file():
            continue
        if any(skip in f.parts for skip in skip_dirs):
            continue
        if f.suffix not in scan_extensions:
            continue

        try:
            content = f.read_text(encoding="utf-8", errors="ignore")
            for pattern, name in secret_patterns:
                if re.search(pattern, content, re.IGNORECASE):
                    errors.append(f"FAIL: Potential secret in {f.relative_to(PROJECT_ROOT)}: {name}")
        except Exception:
            pass

    return errors


def main():
    parser = argparse.ArgumentParser(description="RFBrowser Post-Task Verification")
    parser.add_argument("--skip-build", action="store_true", help="Skip flutter build (faster)")
    args = parser.parse_args()

    errors = []
    print("=" * 60)
    print("RFBrowser Verification")
    print("=" * 60)

    print("\n[1/3] flutter analyze...")
    analyze_errors = check_flutter_analyze()
    errors.extend(analyze_errors)
    print("  PASS" if not analyze_errors else f"  FAIL ({len(analyze_errors)} issues)")

    print("\n[2/3] flutter test...")
    test_errors = check_flutter_test()
    errors.extend(test_errors)
    print("  PASS" if not test_errors else f"  FAIL ({len(test_errors)} issues)")

    if not args.skip_build:
        print("\n[3/4] flutter build windows --debug...")
        build_errors = check_flutter_build()
        errors.extend(build_errors)
        print("  PASS" if not build_errors else f"  FAIL ({len(build_errors)} issues)")
    else:
        print("\n[3/4] flutter build -- SKIPPED")

    print("\n[4/4] Secret scan...")
    secret_errors = scan_secrets()
    errors.extend(secret_errors)
    print("  PASS" if not secret_errors else f"  FAIL ({len(secret_errors)} issues)")

    print("\n" + "=" * 60)
    if not errors:
        print("ALL CHECKS PASSED")
        sys.exit(0)
    else:
        print(f"VERIFICATION FAILED ({len(errors)} issues):")
        for err in errors:
            print(f"  {err}")
        sys.exit(1)


if __name__ == "__main__":
    main()