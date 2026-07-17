#!/usr/bin/env python3
"""WP-88: static audit — EN/TR Android string keys match; no hardcode TR in kt/layout.

Usage (repo root):
  python3 scripts/l10n_android_audit.py
Exit 0 if clean, 1 otherwise.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ANDROID_MAIN = ROOT / "app/android/app/src/main"
VALUES_EN = ANDROID_MAIN / "res/values/strings.xml"
VALUES_TR = ANDROID_MAIN / "res/values-tr/strings.xml"

KEY_RE = re.compile(r'<string\s+name="([^"]+)"')
# User-facing Turkish hardcodes outside string resources (comments ignored loosely).
TR_LITERAL = re.compile(
    r'(?:setText|setContentTitle|setContentText|setSubText|hint\s*=|Toast\.makeText|'
    r'NotificationChannel\(|description\s*=|android:text=|android:label=|'
    r'android:contentDescription=)\s*(?:\([^)]*\)\s*)?["\']([^"\']*[ğüşıöçĞÜŞİÖÇ][^"\']*)["\']'
)
TR_WORD_LITERAL = re.compile(
    r'["\']('
    r'Başlat|Durdur|Kapat|Ertele|Mola|Odaklanıyorsun|Çalışmaya hazır|'
    r'Günlük hedef|Grup hedefi|Kamp sıralaması|Henüz kayıt yok|'
    r'Bir gruba katıl|Alarm yok|Sıradaki alarm|Zamanlayıcı bitti|'
    r'Kritik alarmlar|Çalışma sayacı|Önizleme'
    r')["\']'
)


def keys(path: Path) -> set[str]:
    return set(KEY_RE.findall(path.read_text(encoding="utf-8")))


def main() -> int:
    errors: list[str] = []
    if not VALUES_EN.is_file() or not VALUES_TR.is_file():
        print("FAIL: values/strings.xml or values-tr/strings.xml missing")
        return 1

    en, tr = keys(VALUES_EN), keys(VALUES_TR)
    only_en = sorted(en - tr)
    only_tr = sorted(tr - en)
    if only_en:
        errors.append(f"keys only in EN: {only_en}")
    if only_tr:
        errors.append(f"keys only in TR: {only_tr}")

    skip_parts = {"values", "values-tr", "values-night", "values-v31"}
    for path in list(ANDROID_MAIN.rglob("*.kt")) + list(ANDROID_MAIN.rglob("*.xml")):
        if any(p in skip_parts for p in path.parts):
            continue
        if path.name == "strings.xml":
            continue
        text = path.read_text(encoding="utf-8")
        # Strip // and <!-- comments for a lighter false-positive rate
        stripped = re.sub(r"//.*?$", "", text, flags=re.M)
        stripped = re.sub(r"/\*.*?\*/", "", stripped, flags=re.S)
        stripped = re.sub(r"<!--.*?-->", "", stripped, flags=re.S)
        for m in TR_LITERAL.finditer(stripped):
            errors.append(f"{path.relative_to(ROOT)}: TR literal → {m.group(1)!r}")
        for m in TR_WORD_LITERAL.finditer(stripped):
            errors.append(f"{path.relative_to(ROOT)}: TR word literal → {m.group(1)!r}")

    if errors:
        print(f"FAIL ({len(errors)}):")
        for e in errors:
            print(f"  - {e}")
        return 1

    print(f"OK: {len(en)} string keys EN=TR parity; no hardcoded TR user strings in kt/layout.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
