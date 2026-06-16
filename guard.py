#!/usr/bin/env python3
"""
PRE-ACTION GUARD: Validates planned actions against project constraints.

This script is THE enforcement mechanism. Before writing ANY code, the AI agent
MUST run this guard. It checks the planned action against architecture rules,
domain constraints, and workflow requirements.

The guard BLOCKS actions that violate constraints and explains exactly why.
No guard pass = NO code changes allowed.

Usage:
    python guard.py --check "I plan to add a new API endpoint for user login"
    python guard.py --status           Check if guard system is active
    python guard.py --report           Generate compliance report
"""

import argparse
import re
import sys
from datetime import datetime
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent

# RFBrowser-specific architecture rules
RFBROWSER_RULES = {
    "no_direct_db_from_ui": {
        "patterns": [
            r"(?:sqflite|Database|db\.)\s*(?:open|execute|insert|query|delete|update)",
        ],
        "target_dirs": ["lib/ui", "lib/pages", "lib/widgets"],
        "message": "Direct database access from UI layer is FORBIDDEN. Use Riverpod providers via service/repository layers.",
        "severity": "BLOCKED",
    },
    "no_business_logic_in_providers": {
        "patterns": [
            r"(?:class\s+\w+Notifier\s+extends)",
        ],
        "check_hint": "Notifiers should delegate to services, not contain business logic directly.",
        "message": "Business logic in Riverpod Notifiers should be minimal. Delegate to service layer.",
        "severity": "WARNING",
    },
    "mock_external_service": {
        "patterns": [
            r"\b(?:mock|fake|stub|dummy|simulated)\s+(?:AI|LLM|api|service|client|integration|provider|response)",
            r"(?:return|yield)\s+(?:mock|fake|simulated|dummy|placeholder|hardcoded)\s+(?:data|response|result|output)",
            r"class\s+(?:Mock|Fake|Stub|Dummy|Simulated)",
        ],
        "message": "MOCK DETECTED: Your plan involves simulating/mocking an external service. If the user asked for real integration, you MUST use the actual service API/SDK. Mock is FORBIDDEN in production code.",
        "severity": "BLOCKED",
    },
    "oversimplification": {
        "patterns": [
            r"(?:just|simply|quickly)\s+(?:hardcode|fake|mock|stub|skip|ignore)",
            r"(?:skip|omit|ignore)\s+(?:error handling|validation|testing|edge cases|logging)",
            r"(?:add|write|implement)\s+(?:later|afterwards|in the future)",
            r"TODO.*(?:error handling|validation|tests|logging|docs)",
        ],
        "message": "OVERSIMPLIFICATION DETECTED: Your plan takes shortcuts that compromise engineering quality. Do NOT defer error handling, validation, testing, or logging.",
        "severity": "BLOCKED",
    },
    "passive_waiting": {
        "patterns": [
            r"(?:let me know|tell me|what should I|what do you want|how would you like|shall I) (?:do|proceed|continue|next|start)",
            r"Ready to (?:proceed|continue|start|go)",
            r"Let me know if (?:you|I) (?:should|need to|want)",
        ],
        "message": "PASSIVE WAITING DETECTED: Do NOT wait for the user to tell you the next step. Proactively advance.",
        "severity": "WARNING",
    },
    "multiple_criteria_at_once": {
        "patterns": [],
        "check_hint": "Are you implementing more than one acceptance criterion?",
        "message": "Implementing multiple criteria at once is FORBIDDEN. Focus on ONE criterion at a time.",
        "severity": "BLOCKED",
    },
}


def analyze_plan(plan_description: str) -> list:
    violations = []
    plan_lower = plan_description.lower()

    has_mock = any(kw in plan_lower for kw in ["mock", "fake", "stub", "dummy", "simulated", "simulate", "placeholder", "hardcoded response"])
    has_real_integration = any(kw in plan_lower for kw in ["integrate", "connect to", "real api", "actual api", "openai", "claude", "gpt", "llm", "webdav", "ollama"])
    has_simplification = any(kw in plan_lower for kw in ["skip", "ignore", "defer", "later", "hardcode", "todo", "fixme"])
    has_error_handling = any(kw in plan_lower for kw in ["error handling", "validation", "edge case", "retry", "exception"])
    has_passive = any(kw in plan_lower for kw in ["let me know", "tell me what", "should i", "shall i", "ready to proceed"])
    has_multiple = len(re.findall(r"(?:and also|additionally|furthermore|second,|third,|also)", plan_lower)) > 0

    if has_mock and has_real_integration:
        violations.append({
            "rule": "MOCK_REAL_INTEGRATION",
            "severity": "BLOCKED",
            "message": "MOCK + REAL INTEGRATION conflict: Your plan mentions both mocking AND real integration. If the user asked for real integration, mocking is FORBIDDEN. Use the real API/SDK.",
        })

    if has_simplification and not has_error_handling:
        if "skip" in plan_lower or "ignore" in plan_lower or "later" in plan_lower:
            violations.append({
                "rule": "OVERSIMPLIFICATION",
                "severity": "BLOCKED",
                "message": "Your plan appears to skip/defer error handling or validation. Engineering-grade code MUST include proper error handling and validation.",
            })

    if has_passive:
        violations.append({
            "rule": "PASSIVE_WAITING",
            "severity": "WARNING",
            "message": "Your response shows passive waiting patterns. Proactively advance through the pipeline.",
        })

    if has_multiple:
        violations.append({
            "rule": "ONE_CRITERION_AT_A_TIME",
            "severity": "WARNING",
            "message": "Your plan seems to cover multiple concerns. Implement ONE acceptance criterion at a time.",
        })

    return violations


def run_guard(plan_description: str) -> dict:
    result = {
        "timestamp": datetime.now().isoformat(),
        "plan": plan_description,
        "checks": [],
        "verdict": "PASS",
        "blockers": [],
        "warnings": [],
    }

    violations = analyze_plan(plan_description)
    for v in violations:
        check_result = {"check": v["rule"], "passed": v["severity"] != "BLOCKED", "message": v["message"]}
        result["checks"].append(check_result)
        if v["severity"] == "BLOCKED":
            result["verdict"] = "BLOCKED"
            result["blockers"].append(v["message"])
        else:
            result["warnings"].append(v["message"])

    return result


def print_guard_result(result: dict) -> None:
    print("\n" + "=" * 70)
    print("GUARD CHECK RESULT")
    print("=" * 70)
    print(f"Plan: {result['plan'][:100]}...")
    print(f"Verdict: {result['verdict']}")
    print(f"Timestamp: {result['timestamp']}")

    print(f"\n--- Checks ({len(result['checks'])}) ---")
    for check in result["checks"]:
        status = "PASS" if check["passed"] else "FAIL"
        print(f"  [{status}] {check['check']}: {check['message']}")

    if result["warnings"]:
        print(f"\n--- Warnings ({len(result['warnings'])}) ---")
        for w in result["warnings"]:
            print(f"  [WARN] {w}")

    if result["blockers"]:
        print(f"\n--- BLOCKERS ({len(result['blockers'])}) ---")
        for b in result["blockers"]:
            print(f"  [BLOCKED] {b}")

    print("\n" + "=" * 70)
    if result["verdict"] == "PASS":
        print("GUARD PASSED - You may proceed.")
    else:
        print("GUARD BLOCKED - Fix the blockers above before writing any code.")
    print("=" * 70)


def main():
    parser = argparse.ArgumentParser(description="Pre-Action Guard for RFBrowser")
    parser.add_argument("--check", default=None, help="Description of what you plan to do")
    parser.add_argument("--status", action="store_true", help="Check if guard system is active")
    args = parser.parse_args()

    if args.status:
        print("Guard system: ACTIVE")
        print(f"Project: RFBrowser (Flutter/Dart)")
        print(f"Quality gates: flutter analyze, flutter test, flutter build windows --debug")
        return

    if not args.check:
        print("ERROR: Must provide --check with a description of your planned action.")
        print('Example: python guard.py --check "I plan to add a new Riverpod provider for search"')
        sys.exit(1)

    result = run_guard(args.check)
    print_guard_result(result)

    if result["verdict"] == "BLOCKED":
        sys.exit(1)


if __name__ == "__main__":
    main()