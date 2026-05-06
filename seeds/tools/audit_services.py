#!/usr/bin/env python3
"""Service layer audit — counts files, checks for dead (unimported) services."""

import os
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
SERVICES_DIR = ROOT / "lib" / "services"
LIB_DIR = ROOT / "lib"


def find_dart_files(directory: Path) -> list[Path]:
    return sorted(directory.glob("*.dart"))


def find_imports_of_service(service_file: Path, search_dir: Path) -> int:
    stem = service_file.stem
    count = 0
    for dart_file in search_dir.rglob("*.dart"):
        if dart_file.resolve() == service_file.resolve():
            continue
        content = dart_file.read_text(encoding="utf-8", errors="ignore")
        if stem in content:
            count += 1
    return count


def main():
    dart_files = find_dart_files(SERVICES_DIR)
    non_stub_files = [f for f in dart_files if "_stub" not in f.name]

    print(f"\n{'='*60}")
    print("SERVICE LAYER AUDIT")
    print(f"{'='*60}")
    print(f"Total .dart files in lib/services/: {len(dart_files)}")
    print(f"Non-stub files: {len(non_stub_files)}")
    print()

    dead_services = []
    for svc in non_stub_files:
        import_count = find_imports_of_service(svc, LIB_DIR)
        status = "OK" if import_count > 0 else "DEAD"
        if import_count == 0:
            dead_services.append(svc.name)
        print(f"  {status:5s}  {svc.name:40s}  ({import_count} imports)")

    print(f"\nDead services (0 imports in lib/): {len(dead_services)}")
    for ds in dead_services:
        print(f"  - {ds}")

    print(f"\nResult: {len(non_stub_files)} non-stub services, {len(dead_services)} dead")
    print(f"Target: <= 20 non-stub services ({'PASS' if len(non_stub_files) <= 20 else 'FAIL'})")
    print(f"Target: 0 dead services ({'PASS' if len(dead_services) == 0 else 'FAIL'})")

    if len(non_stub_files) <= 20 and len(dead_services) == 0:
        print("\n✅ All audit targets met!")
        return 0
    else:
        print("\n❌ Audit targets NOT met!")
        return 1


if __name__ == "__main__":
    sys.exit(main())
