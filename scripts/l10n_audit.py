#!/usr/bin/env python3
"""WP-89: EN/TR catalog and visible-Flutter-literal audit.

Usage (repo root):
  python scripts/l10n_audit.py

The audit deliberately excludes generated l10n output, comments, tests, and
repository exception taxonomy. Repository strings are internal error-classifier
input; user-facing widgets must map them through AppLocalizations instead.
"""

from __future__ import annotations

import json
import re
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "app"
ARB_EN = APP / "lib/l10n/app_en.arb"
ARB_TR = APP / "lib/l10n/app_tr.arb"
DART_ROOT = APP / "lib"
NATIVE_AUDIT = ROOT / "scripts/l10n_android_audit.py"

TURKISH_CHAR_RE = re.compile(r"[ÇĞİÖŞÜçğıöşü]")
LINE_COMMENT_RE = re.compile(r"//.*?$", re.MULTILINE)
BLOCK_COMMENT_RE = re.compile(r"/\*.*?\*/", re.DOTALL)
STRING_RE = re.compile(
    r"'(?:\\.|[^'\\])*'|\"(?:\\.|[^\"\\])*\"", re.DOTALL
)

# These paths carry non-UI exception taxonomy. They are intentionally not
# translated at the repository boundary: presentation code maps the category to
# the active AppLocalizations catalog and never displays the raw message.
INTERNAL_PREFIXES = (
    "app/lib/data/repositories/",
)
INTERNAL_LITERAL_FILES = {
    "app/lib/core/observability/observability_service.dart",
    "app/lib/core/prefs/app_prefs.dart",
    "app/lib/features/auth/auth_screen.dart",
}


def catalog(path: Path) -> dict[str, object]:
    return json.loads(path.read_text(encoding="utf-8"))


def source_keys(data: dict[str, object]) -> set[str]:
    return {key for key in data if not key.startswith("@")}


def strip_comments(source: str) -> str:
    return LINE_COMMENT_RE.sub("", BLOCK_COMMENT_RE.sub("", source))


def flutter_literal_violations() -> list[str]:
    violations: list[str] = []
    for path in DART_ROOT.rglob("*.dart"):
        relative = path.relative_to(ROOT).as_posix()
        if (
            relative.startswith("app/lib/l10n/")
            or relative.startswith(INTERNAL_PREFIXES)
            or relative in INTERNAL_LITERAL_FILES
        ):
            continue
        source = strip_comments(path.read_text(encoding="utf-8"))
        for match in STRING_RE.finditer(source):
            literal = match.group(0)[1:-1]
            if TURKISH_CHAR_RE.search(literal):
                line = source.count("\n", 0, match.start()) + 1
                violations.append(f"{relative}:{line}: {literal!r}")
    return violations


def main() -> int:
    errors: list[str] = []
    en = catalog(ARB_EN)
    tr = catalog(ARB_TR)
    en_keys = source_keys(en)
    tr_keys = source_keys(tr)

    if only_en := sorted(en_keys - tr_keys):
        errors.append(f"ARB keys only in EN: {only_en}")
    if only_tr := sorted(tr_keys - en_keys):
        errors.append(f"ARB keys only in TR: {only_tr}")

    for key in sorted(en_keys & tr_keys):
        metadata = en.get(f"@{key}")
        if not isinstance(metadata, dict):
            errors.append(f"missing template metadata for {key}")
            continue
        placeholders = metadata.get("placeholders", {})
        if not isinstance(placeholders, dict):
            errors.append(f"invalid template placeholder metadata for {key}")
            continue
        localized = tr[key]
        for placeholder in placeholders:
            if not isinstance(localized, str) or f"{{{placeholder}" not in localized:
                errors.append(f"TR value for {key} does not reference {{{placeholder}}}")

    for violation in flutter_literal_violations():
        errors.append(f"visible Flutter TR literal: {violation}")

    native = subprocess.run(
        [sys.executable, str(NATIVE_AUDIT)],
        cwd=ROOT,
        check=False,
        text=True,
        capture_output=True,
    )
    if native.returncode:
        errors.append("native Android audit failed:\n" + native.stdout + native.stderr)

    if errors:
        print(f"FAIL ({len(errors)}):")
        for error in errors:
            print(f"  - {error}")
        return 1

    print(
        f"OK: {len(en_keys)} Flutter EN/TR keys with matching placeholders; "
        "no visible Flutter Turkish literal; "
        + native.stdout.strip()
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
