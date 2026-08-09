#!/usr/bin/env python3
"""Kapsam kapısı: satır kapsamı ölçer ve **düşmesini** engeller (ratchet).

Usage (repo root):
  cd app && flutter test --exclude-tags=golden --coverage --dart-define-from-file=env.json
  cd .. && python scripts/coverage_audit.py            # rapor + kapı
  python scripts/coverage_audit.py --update-baseline   # eşiği yükselt
  python scripts/coverage_audit.py --top 30            # en riskli dosyalar

🔴 Varlık sebebi: bu repoda **hiçbir kapsam ölçümü yoktu**. 232 test dosyası
ve 1399 test yeşil koşuyordu ama hangi kodun hiç çalıştırılmadığı
bilinmiyordu. Sekiz ajanın paralel çalıştığı turlarda kod 94k satıra
çıkarken kapsamın sessizce düşüp düşmediğini gösteren tek bir sayı yoktu.

Kapı iki şey yapar:

1. **Ratchet** — genel kapsam `coverage-baseline.json` içindeki değerin
   `TOLERANCE` puanından fazla altına düşerse kırmızı. Yani yeni kod
   testsiz eklenemez; eşik yalnız `--update-baseline` ile ve bilerek
   yükselir. Sabit bir hedef (%80 gibi) yerine ratchet seçildi: mevcut
   gerçeği cezalandırmadan geriye gidişi engeller.

2. **Kritik yol listesi** — `CRITICAL_PATHS` altındaki dosyalar için ayrı ve
   daha sert eşik. Buradaki kod sahada para/veri/güvenlik etkisi taşır;
   "genel ortalama iyi" diye bunların testsiz kalması kabul edilmez.

Not: `flutter test --coverage` yalnız **testin import ettiği** dosyaları
enstrümante eder. Hiç import edilmemiş dosya lcov'da HİÇ görünmez — bu
yüzden rapor `app/lib` ağacını ayrıca tarar ve lcov'da olmayanları
"hiç dokunulmamış" olarak sayar. Bu ayrım olmadan kapsam yüzdesi
olduğundan yüksek görünür.
"""

from __future__ import annotations

import json
import sys
from collections import defaultdict
from pathlib import Path

for _stream in (sys.stdout, sys.stderr):
    if hasattr(_stream, "reconfigure"):
        _stream.reconfigure(encoding="utf-8", errors="replace")

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "app"
LCOV = APP / "coverage" / "lcov.info"
BASELINE = ROOT / "tooling" / "quality" / "coverage-baseline.json"

# Genel kapsamda kabul edilen gürültü payı (puan).
TOLERANCE = 0.5

# Sahada para/veri/güvenlik etkisi olan yollar. Bunlar için eşik ayrı tutulur.
#
# 🔴 WP-614: liste bir **denetim bulgusuyla** genişledi. Masaüstü kabuğu ve
# updater buraya hiç girmemişti; oysa Windows dağıtımının tamamı bu iki ağaçtan
# geçiyor (kanal seçimi, sideload güncelleme, pencere kurulumu). "Genel ortalama
# iyi" diye testsiz kalmaları kabul edilemez — kritik yol tanımı "para/veri"
# değil "sahada kullanıcıyı bozan yol"dur.
CRITICAL_PATHS = (
    "lib/core/stats/",
    "lib/core/tasks/",
    "lib/core/time_engine/",
    "lib/data/repositories/supabase/",
    "lib/data/providers/",
    "lib/core/desktop/",
    "lib/features/desktop/",
    "lib/features/updater/",
)

# 🔴 Yukarıdaki listenin **sözleşme** kısmı. Bilerek ikinci kez yazıldı: bir
# yol listeden sessizce silinirse `--self-test` kırmızıya düşer. Tek liste
# olsaydı silme işlemi hiçbir kapıyı kızdırmadan geçerdi — bu deponun
# tekrarlayan hatası (kapı vardı, ölçtüğü şey yoktu).
REQUIRED_CRITICAL_PATHS = (
    "lib/core/desktop/",
    "lib/features/desktop/",
    "lib/features/updater/",
)

# Kapsam ölçümü anlamsız olan üretilmiş/platform yüzeyleri.
EXCLUDED = (
    "lib/l10n/generated/",
    ".g.dart",
    ".freezed.dart",
)


def _excluded(rel: str) -> bool:
    return any(token in rel for token in EXCLUDED)


def parse_lcov() -> dict[str, tuple[int, int]]:
    """dosya -> (ölçülebilir satır, çalıştırılan satır)."""
    if not LCOV.is_file():
        raise SystemExit(
            f"lcov bulunamadı: {LCOV}\n"
            "Önce: cd app && flutter test --exclude-tags=golden --coverage "
            "--dart-define-from-file=env.json"
        )
    files: dict[str, list[int]] = defaultdict(lambda: [0, 0])
    current = None
    for raw in LCOV.read_text(encoding="utf-8", errors="replace").splitlines():
        line = raw.strip()
        if line.startswith("SF:"):
            path = line[3:].replace("\\", "/")
            marker = "lib/"
            index = path.find(marker)
            current = path[index:] if index != -1 else path
        elif line.startswith("DA:") and current:
            _, payload = line.split(":", 1)
            _, count = payload.split(",")[:2]
            files[current][0] += 1
            if int(count) > 0:
                files[current][1] += 1
    return {k: (v[0], v[1]) for k, v in files.items()}


def collect() -> dict[str, tuple[int, int]]:
    """lcov + hiç import edilmemiş dosyalar (0 kapsam olarak)."""
    measured = parse_lcov()
    for path in (APP / "lib").rglob("*.dart"):
        rel = path.relative_to(APP).as_posix()
        if _excluded(rel) or rel in measured:
            continue
        # Hiç import edilmemiş -> lcov'da yok. Kaba bir ölçülebilir-satır
        # tahmini: boş olmayan, yorum olmayan satırlar.
        body = path.read_text(encoding="utf-8", errors="replace").splitlines()
        countable = sum(
            1
            for line in body
            if line.strip() and not line.strip().startswith(("//", "///", "*", "/*"))
        )
        if countable:
            measured[rel] = (countable, 0)
    return {k: v for k, v in measured.items() if not _excluded(k)}


def percentage(hit: int, total: int) -> float:
    return 100.0 * hit / total if total else 100.0


def summarise(files: dict[str, tuple[int, int]]):
    total = sum(t for t, _ in files.values())
    hit = sum(h for _, h in files.values())
    critical_total = critical_hit = 0
    for rel, (t, h) in files.items():
        if any(rel.startswith(prefix) for prefix in CRITICAL_PATHS):
            critical_total += t
            critical_hit += h
    return {
        "overall": round(percentage(hit, total), 2),
        "critical": round(percentage(critical_hit, critical_total), 2),
        "lines_total": total,
        "lines_hit": hit,
        "files": len(files),
        "untouched_files": sum(1 for t, h in files.values() if h == 0),
    }


def evaluate(summary: dict, baseline: dict | None) -> list[str]:
    """Ratchet kararı — saf fonksiyon, `--self-test` bunu doğrudan sınar.

    🔴 WP-614: bu karar eskiden `main` içindeydi ve **kendi kendini
    iyileştiriyordu**. Baseline dosyası yoksa kapı onu o anki ölçümle yeniden
    yazıp `0` dönüyordu; yani eşiği silmek kapıyı sessizce geçmenin yoluydu.
    Aynı şekilde baseline içinden bir anahtar silinirse `continue` deniyor,
    yani o eşik hiç ölçülmüyordu. İkisi de artık KIRMIZI.
    """
    if baseline is None:
        return [
            f"baseline dosyası yok: {BASELINE.relative_to(ROOT).as_posix()}. "
            "Kapı eşiksiz ölçüm yapamaz ve eşiği kendi kendine yazmaz — "
            "dosyayı geri getirin veya kapsamı BİLEREK yükselten bir WP'de "
            "`--update-baseline` çalıştırın."
        ]

    errors = []
    for key, label in (("overall", "genel"), ("critical", "kritik yollar")):
        floor = baseline.get(key)
        if floor is None:
            errors.append(
                f"baseline içinde `{key}` eşiği yok: {label} kapsamı "
                "ölçülmüyor. Eksik eşik = kapı değil."
            )
            continue
        if summary[key] < floor - TOLERANCE:
            errors.append(
                f"{label} kapsamı düştü: %{summary[key]:.2f} < "
                f"%{floor:.2f} (tolerans {TOLERANCE} puan)"
            )
    return errors


def self_test() -> int:
    """Kapıyı KASTEN bozuk girdiyle sına: kırmızıya düşmüyorsa kapı değildir.

    Ucuz (lcov istemez), bu yüzden `test_all.py` T0'da koşar — kapsam kapısının
    kendisi bozulursa dakikalar değil saniyeler içinde bilinir.
    """
    failures: list[str] = []

    def check(name: str, ok: bool, detail: str = "") -> None:
        print(f"  {'OK  ' if ok else 'FAIL'} {name}")
        if not ok:
            failures.append(f"{name}{(' — ' + detail) if detail else ''}")

    good = {"overall": 70.0, "critical": 60.0}
    floor = {"overall": 70.0, "critical": 60.0}

    check(
        "eşiğin üstündeki ölçüm geçer",
        evaluate(good, floor) == [],
    )
    check(
        "tolerans içi dalgalanma geçer",
        evaluate({"overall": 69.6, "critical": 59.6}, floor) == [],
    )
    check(
        "genel kapsam düşünce KIRMIZI",
        len(evaluate({"overall": 60.0, "critical": 60.0}, floor)) == 1,
    )
    check(
        "genel iyiyken bile kritik yol düşüşü KIRMIZI",
        len(evaluate({"overall": 99.0, "critical": 40.0}, floor)) == 1,
    )
    check(
        "baseline dosyası SİLİNİRSE kapı geçmez (fail-closed)",
        evaluate(good, None) != [],
        "baseline yoksa kapı kendi eşiğini yazıp geçiyordu",
    )
    check(
        "baseline'dan anahtar silinirse KIRMIZI",
        evaluate(good, {"overall": 70.0}) != [],
        "eksik eşik sessizce atlanıyordu",
    )

    missing = [p for p in REQUIRED_CRITICAL_PATHS if p not in CRITICAL_PATHS]
    check(
        "kritik yol listesi masaüstü/updater ağaçlarını kapsıyor",
        not missing,
        f"eksik: {missing}",
    )

    real = load_baseline()
    check(
        "gerçek baseline dosyası var ve iki eşiği de taşıyor",
        isinstance(real, dict)
        and real.get("overall") is not None
        and real.get("critical") is not None,
        f"{BASELINE.relative_to(ROOT).as_posix()}",
    )

    if failures:
        print(f"\nFAIL ({len(failures)}): kapsam kapısı kendini savunamıyor")
        for failure in failures:
            print(f"  - {failure}")
        return 1
    print("\nOK: kapsam kapısı bozuk girdide kırmızıya düşüyor.")
    return 0


def load_baseline() -> dict | None:
    if BASELINE.is_file():
        return json.loads(BASELINE.read_text(encoding="utf-8"))
    return None


def write_baseline(summary: dict) -> None:
    BASELINE.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "_comment": (
            "Kapsam ratchet eşiği. Yalnız `python scripts/coverage_audit.py "
            "--update-baseline` ile ve kapsamı BİLEREK yükselten bir WP "
            "kapsamında güncellenir. Elle düşürmek kapıyı etkisiz kılar."
        ),
        "overall": summary["overall"],
        "critical": summary["critical"],
        "lines_total": summary["lines_total"],
        "files": summary["files"],
    }
    BASELINE.write_text(
        json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )


def main(argv: list[str]) -> int:
    # `--self-test` lcov istemez; `collect()` çağrılmadan ÖNCE ele alınır.
    if "--self-test" in argv:
        return self_test()

    files = collect()
    summary = summarise(files)

    if "--top" in argv:
        index = argv.index("--top")
        limit = int(argv[index + 1]) if index + 1 < len(argv) else 25
        ranked = sorted(
            files.items(),
            key=lambda kv: (kv[1][0] - kv[1][1]),
            reverse=True,
        )
        print(f"En çok kapsanmamış satır taşıyan {limit} dosya:\n")
        print(f"  {'kapsanmamış':>11}  {'%':>6}  dosya")
        for rel, (total, hit) in ranked[:limit]:
            print(f"  {total - hit:>11}  {percentage(hit, total):>5.1f}%  {rel}")
        print()

    print(
        "Kapsam: genel %.2f%%  ·  kritik yollar %.2f%%  "
        "(%d/%d satır, %d dosya, %d dosyaya hiç dokunulmamış)"
        % (
            summary["overall"],
            summary["critical"],
            summary["lines_hit"],
            summary["lines_total"],
            summary["files"],
            summary["untouched_files"],
        )
    )

    if "--update-baseline" in argv:
        write_baseline(summary)
        print(f"OK: baseline güncellendi -> {BASELINE.relative_to(ROOT).as_posix()}")
        return 0

    baseline = load_baseline()
    errors = evaluate(summary, baseline)

    if errors:
        print(f"\nFAIL ({len(errors)}):")
        for error in errors:
            print(f"  - {error}")
        print(
            "\nYeni kodu testle örtün. Eşiği düşürmek çözüm değildir; "
            "kapsamı bilerek yükselten bir WP'de --update-baseline kullanın."
        )
        return 1

    print(
        "OK: kapsam ratchet'i korundu "
        f"(eşik genel %{baseline['overall']:.2f} / kritik %{baseline['critical']:.2f})."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
