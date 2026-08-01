#!/usr/bin/env python3
"""Tek komutluk kalite kapısı koşucusu — `tester` ajanının motoru.

    python scripts/test_all.py            # T0+T1+T2 (varsayilan tur)
    python scripts/test_all.py --fast     # T0+T1 (dakika alti, kod yazarken)
    python scripts/test_all.py --full     # + golden + Windows entegrasyon
    python scripts/test_all.py --only contract,analyze

Tasarim kararlari:

* **Ucuz kapi once.** Sozlesme/l10n denetimi saniyeler surer ve Flutter
  kurulumu istemez; Flutter test paketi dakikalar surer. Ucuz olan once kosar
  ki kirmizi cevap ilk 10 saniyede gelsin.
* **Ayni tier icinde paralel.** Birbirinin dosyasina yazmayan kapilar ayni anda
  kosar. `flutter test` ile `flutter test --tags=golden` ayni `app/` agacini ve
  ayni build cache'ini kullanir, bu yuzden ayri tier'dadir.
* **Atlanan kapi YESIL DEGILDIR.** Deno kurulu degilse veya Docker kalkmiyorsa
  sonuc `ATLANDI` olarak, sebebiyle birlikte raporlanir. Bu repoda "yesil
  sanilan ama hic kosmayan kapi" uc kez pahaliya mal oldu
  (`docs/TEST-SISTEMI.md` §0) — sessiz atlama yok.
* **Cikis kodu tek gercek.** `0` = her kapi kostu ve gecti. `1` = en az bir
  kapi kirmizi. `3` = kirmizi yok ama en az bir kapi kosmadi. Ayri kod olmasi
  bilincli: "yesil" ile "olculmedi" ayni sey degildir.
"""

from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
import time
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass, field
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
APP = ROOT / "app"

PASS = "GECTI"
FAIL = "KIRMIZI"
SKIP = "ATLANDI"


@dataclass
class Gate:
    key: str
    title: str
    tier: int
    argv: list[str]
    cwd: Path = ROOT
    #: Kosmadan once dogrulanacak on kosul; (ok, sebep) doner.
    precondition: object | None = None
    #: True ise kirmizi cikis kodu turu dusurmez (bilgi amacli olcum).
    advisory: bool = False


@dataclass
class Result:
    gate: Gate
    status: str
    seconds: float
    output: str = ""
    reason: str = ""
    tail: list[str] = field(default_factory=list)


# ── on kosullar ────────────────────────────────────────────────────────────


def _needs(binary: str):
    def check() -> tuple[bool, str]:
        if shutil.which(binary) is None:
            return False, f"`{binary}` bu makinede kurulu degil (CI'da kosar)"
        return True, ""

    return check


def _needs_env_json() -> tuple[bool, str]:
    if not (APP / "env.json").exists():
        return False, "app/env.json yok — `docs/recovery/ENVIRONMENT-MATRIX.md`"
    return True, ""


def _needs_docker() -> tuple[bool, str]:
    if shutil.which("docker") is None:
        return False, "Docker kurulu degil — pgTAP yalniz CI'da kosar"
    probe = subprocess.run(
        ["docker", "info"], capture_output=True, text=True, timeout=60
    )
    if probe.returncode != 0:
        return False, "Docker motoru kalkmiyor — pgTAP yalniz CI'da kosar"
    return True, ""


# ── kapi listesi ───────────────────────────────────────────────────────────

PWSH = shutil.which("pwsh") or shutil.which("powershell") or "powershell"


def _exe(name: str) -> str:
    """`flutter` Windows'ta `flutter.bat`tir; `shutil.which` uzantiyi bulur.

    `subprocess` shell=False ile calistigi icin PATH cozumlemesini uzantisiz
    adla yapamaz ve kapi "komut bulunamadi" diye ATLANDI'ya duserdi.
    """
    return shutil.which(name) or name


def build_gates() -> list[Gate]:
    py = sys.executable
    flutter = _exe("flutter")
    deno = _exe("deno")
    gradlew = APP / "android" / ("gradlew.bat" if os.name == "nt" else "gradlew")
    return [
        # T0 — saniyeler. Flutter/Deno kurulumu istemez.
        Gate("contract", "Dart/Edge ↔ SQL sozlesmesi", 0,
             [py, "scripts/backend_contract_audit.py"]),
        Gate("contract-self", "Sozlesme kapisi kendini sinar", 0,
             [py, "scripts/backend_contract_audit.py", "--self-test"]),
        Gate("l10n", "l10n katalog esligi", 0,
             [py, "scripts/l10n_audit.py"]),
        Gate("l10n-android", "Android kaynak metin denetimi", 0,
             [py, "scripts/l10n_android_audit.py"]),
        Gate("migration-head", "Migration head uc yerde pinli", 0,
             [py, "scripts/test_all.py", "--internal-migration-head"]),

        # T1 — bagimsiz araclar; birbirinin dosyasina dokunmaz.
        Gate("analyze", "flutter analyze", 1,
             [flutter, "analyze"], cwd=APP,
             precondition=_needs("flutter")),
        Gate("deno-check", "Edge Function tip denetimi", 1,
             [py, "scripts/test_all.py", "--internal-deno-check"],
             precondition=_needs("deno")),
        Gate("deno-test", "Edge Function davranis testleri", 1,
             [deno, "test", "--no-lock", "--allow-env", "supabase/functions/"],
             precondition=_needs("deno")),
        Gate("guard", "Supabase deploy guard testleri", 1,
             [PWSH, "-NoProfile", "-NonInteractive", "-File",
              "tooling/supabase/guard.tests.ps1"]),
        Gate("preflight", "Release preflight testleri", 1,
             [PWSH, "-NoProfile", "-NonInteractive", "-File",
              "tooling/release/release-preflight.tests.ps1"]),

        # T2 — asil test paketi; tek basina kosar (build cache paylasimi).
        Gate("test", "Flutter test paketi (+ kapsam)", 2,
             [flutter, "test", "--exclude-tags=golden", "--coverage",
              "--dart-define-from-file=env.json"],
             cwd=APP, precondition=_needs_env_json),
        # Native timer/widget kodu Flutter test runner'ina girmez. Flutter APK
        # derlemesini ve environment validation'i burada bilerek dislariz: bu
        # kapi Kotlin kaynaklarini derler ve JVM unit testlerini cihazsiz kosar.
        Gate("android-unit", "Android native JVM testleri", 2,
             [str(gradlew), ":app:testLocalDebugUnitTest", "--no-daemon",
              "-x", ":app:compileFlutterBuildLocalDebug",
              "-x", ":app:validateLocalEnvironment"],
             cwd=APP / "android",
             precondition=lambda: (
                 gradlew.exists(),
                 "Android Gradle wrapper bulunamadi",
             )),
        Gate("coverage", "Kapsam ratchet", 2,
             [py, "scripts/coverage_audit.py"]),

        # T3 — yalniz --full. Dakikalar surer.
        Gate("golden", "Golden testleri", 3,
             [flutter, "test", "--tags=golden",
              "--dart-define-from-file=env.json", "--concurrency=1"],
             cwd=APP, precondition=_needs_env_json),
        Gate("integration", "Windows entegrasyon (kritik akislar)", 3,
             [flutter, "test", "-d", "windows",
              "integration_test/v8_critical_flows_test.dart",
              "--dart-define-from-file=env.json"],
             cwd=APP, precondition=_needs_env_json),
        Gate("pgtap", "pgTAP yerel replay", 3,
             [PWSH, "-NoProfile", "-NonInteractive", "-File",
              "tooling/supabase/local.ps1", "-Action", "baseline"],
             precondition=_needs_docker),
    ]


# ── kapi ici yardimcilar (alt surec olarak cagrilir) ───────────────────────


def internal_deno_check() -> int:
    """Her Edge Function'i ayri ayri `deno check`ten gecir."""
    failed = []
    for entry in sorted((ROOT / "supabase" / "functions").glob("*/index.ts")):
        rel = entry.relative_to(ROOT).as_posix()
        run = subprocess.run(
            ["deno", "check", "--no-lock", rel], cwd=ROOT,
            capture_output=True, text=True,
        )
        print(f"--- {rel}")
        print((run.stdout + run.stderr).strip())
        if run.returncode != 0:
            failed.append(rel)
    if failed:
        print("KIRMIZI tip denetimi: " + ", ".join(failed))
        return 1
    return 0


def internal_migration_head() -> int:
    """Migration zincirini ve head pinlerini dogrula.

    🔴 Bu kapinin sebebi: head birden fazla yerde pinlidir ve iki turda ust uste
    biri guncellenmeden commit atildi; CI ayni yerden kirmizi dustu. Yeni bir
    migration eklendiginde hangi pinin kimin pesinden gitmesi GEREKTIGI burada
    yazilidir:

    * `local_migration_head` **her zaman** dizindeki son dosyayi gosterir,
    * `staging`/`production` head'leri o ortama gercekten APPLY edilince ilerler
      (yeni bir dosya eklemek onlari ilerletmez) — bu yuzden yalniz
      `production <= staging <= local` monotonlugu aranir,
    * `guard.tests.ps1` icindeki staging head literali kontratla ayni olmalidir;
      bu cift iki kez birbirinden ayri dustu.

    Ayrica AGENTS.md §2 "Migration Baslik Kurali": ilk satir tam olarak
    `-- <dosya adi>` olmalidir.
    """
    import json
    import re

    migrations = sorted((ROOT / "supabase" / "migrations").glob("[0-9]*.sql"))
    if not migrations:
        print("Migration dosyasi bulunamadi.")
        return 1

    problems: list[str] = []

    numbers = [int(path.name[:4]) for path in migrations]
    for previous, current in zip(numbers, numbers[1:]):
        if current != previous + 1:
            problems.append(
                f"zincirde bosluk/tekrar: {previous:04d} -> {current:04d}"
            )
    head = f"{numbers[-1]:04d}"

    # AGENTS.md §2: "Daha once uygulanmis tarihsel migration'lari sirf bicim
    # icin topluca degistirme." 0001-0045 araligi eski bicimlerde yazilmis
    # (`=====` banner, `--0038_...`, `-- 0045: ...`) ve uc ortama da
    # uygulanmis durumda. Kural 0046'dan itibaren gecerlidir; o esikten
    # sonraki HER dosya uyar ve yeni dosya bu esigi gevsetemez.
    header_rule_from = 46
    for path in migrations:
        if int(path.name[:4]) < header_rule_from:
            continue
        lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
        first_line = lines[0].strip() if lines else ""
        if first_line != f"-- {path.name}":
            problems.append(
                f"{path.name}: ilk satir `-- {path.name}` degil ({first_line!r})"
            )

    contract_path = ROOT / "tooling" / "release" / "deploy-contract.json"
    try:
        contract = json.loads(contract_path.read_text(encoding="utf-8-sig"))
    except (OSError, json.JSONDecodeError) as err:
        print(f"deploy-contract.json okunamadi/bozuk: {err}")
        return 1

    local_pin = str(contract.get("local_migration_head", ""))
    staging_pin = str(contract.get("staging", {}).get("migration_head", ""))
    production_pin = str(contract.get("production", {}).get("migration_head", ""))

    if local_pin != head:
        problems.append(
            f"deploy-contract.local_migration_head={local_pin} ama dizin head={head}"
        )
    if not (production_pin <= staging_pin <= local_pin):
        problems.append(
            "head monotonlugu bozuk: "
            f"production={production_pin} staging={staging_pin} local={local_pin}"
        )

    guard = (ROOT / "tooling" / "supabase" / "guard.tests.ps1").read_text(
        encoding="utf-8", errors="replace"
    )
    match = re.search(
        r"\$contract\.staging\.migration_head\s+'(\d{4})'", guard
    )
    if match is None:
        problems.append(
            "guard.tests.ps1 icinde staging head iddiasi bulunamadi "
            "(kapi sessizce etkisizlesmis olabilir)"
        )
    elif match.group(1) != staging_pin:
        problems.append(
            f"guard.tests.ps1 staging head literali {match.group(1)} ama "
            f"kontrat {staging_pin}"
        )

    if problems:
        for line in problems:
            print(f"  - {line}")
        return 1
    print(
        f"OK: {len(migrations)} migration kesintisiz, head {head}; "
        f"pinler local={local_pin} staging={staging_pin} "
        f"production={production_pin}"
    )
    return 0


# ── kosum ──────────────────────────────────────────────────────────────────


def run_gate(gate: Gate) -> Result:
    if gate.precondition is not None:
        ok, reason = gate.precondition()
        if not ok:
            return Result(gate, SKIP, 0.0, reason=reason)

    started = time.monotonic()
    env = dict(os.environ, PYTHONIOENCODING="utf-8")
    try:
        run = subprocess.run(
            gate.argv, cwd=gate.cwd, capture_output=True, text=True,
            encoding="utf-8", errors="replace", env=env, shell=False,
        )
    except FileNotFoundError as err:
        return Result(gate, SKIP, time.monotonic() - started,
                      reason=f"komut bulunamadi: {err}")
    elapsed = time.monotonic() - started
    output = (run.stdout or "") + (run.stderr or "")
    status = PASS if run.returncode == 0 else FAIL
    tail = [line for line in output.splitlines() if line.strip()][-25:]
    return Result(gate, status, elapsed, output=output, tail=tail)


def main() -> int:
    # Windows konsolu cp1254; kapi ciktisinda Turkce/ok karakteri gecerse
    # UnicodeEncodeError ile duserdi ve "kapi kirmizi" gibi gorunurdu.
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(encoding="utf-8", errors="replace")
        except (AttributeError, ValueError):
            pass

    parser = argparse.ArgumentParser(description="Tum kalite kapilarini kostur.")
    parser.add_argument("--fast", action="store_true",
                        help="yalniz T0+T1 (dakika alti)")
    parser.add_argument("--full", action="store_true",
                        help="golden + Windows entegrasyon + pgTAP dahil")
    parser.add_argument("--only", default="",
                        help="virgulle ayrilmis kapi anahtarlari")
    parser.add_argument("--list", action="store_true", help="kapilari listele")
    parser.add_argument("--internal-deno-check", action="store_true",
                        help=argparse.SUPPRESS)
    parser.add_argument("--internal-migration-head", action="store_true",
                        help=argparse.SUPPRESS)
    args = parser.parse_args()

    if args.internal_deno_check:
        return internal_deno_check()
    if args.internal_migration_head:
        return internal_migration_head()

    gates = build_gates()
    if args.list:
        for gate in gates:
            print(f"T{gate.tier}  {gate.key:<16} {gate.title}")
        return 0

    if args.only:
        wanted = {k.strip() for k in args.only.split(",") if k.strip()}
        unknown = wanted - {g.key for g in gates}
        if unknown:
            print(f"Bilinmeyen kapi: {', '.join(sorted(unknown))}")
            return 2
        gates = [g for g in gates if g.key in wanted]
    else:
        max_tier = 1 if args.fast else (3 if args.full else 2)
        gates = [g for g in gates if g.tier <= max_tier]

    results: list[Result] = []
    started = time.monotonic()

    for tier in sorted({g.tier for g in gates}):
        batch = [g for g in gates if g.tier == tier]
        # `coverage` lcov'u `test`in urettigi dosyadan okur — ayni tier'da ama
        # sirali kosmalidir. Ayni sey pgTAP/golden/integration icin de gecerli:
        # ucu de tek makine kaynagini (DB / GPU / Windows kabuk) tuketir.
        sequential = tier >= 2
        print(f"\n=== T{tier} ({len(batch)} kapi, "
              f"{'sirali' if sequential else 'paralel'}) ===", flush=True)
        if sequential:
            for gate in batch:
                res = run_gate(gate)
                results.append(res)
                print(f"  {res.status:<8} {gate.title} "
                      f"({res.seconds:.0f}s){' — ' + res.reason if res.reason else ''}",
                      flush=True)
        else:
            with ThreadPoolExecutor(max_workers=len(batch)) as pool:
                for res in pool.map(run_gate, batch):
                    results.append(res)
                    print(f"  {res.status:<8} {res.gate.title} "
                          f"({res.seconds:.0f}s)"
                          f"{' — ' + res.reason if res.reason else ''}",
                          flush=True)

    total = time.monotonic() - started
    failures = [r for r in results if r.status == FAIL and not r.gate.advisory]
    skipped = [r for r in results if r.status == SKIP]

    print("\n" + "=" * 72)
    print(f"{'KAPI':<40} {'SONUC':<9} SURE")
    print("-" * 72)
    for res in results:
        print(f"{res.gate.title:<40} {res.status:<9} {res.seconds:6.0f}s")
    print("=" * 72)
    print(f"Toplam {total:.0f}s · {len(results)} kapi · "
          f"{len(failures)} kirmizi · {len(skipped)} atlandi")

    if skipped:
        print("\nATLANAN KAPILAR — bunlar yesil DEGILDIR:")
        for res in skipped:
            print(f"  - {res.gate.title}: {res.reason}")

    for res in failures:
        print(f"\n--- KIRMIZI: {res.gate.title} "
              f"({' '.join(res.gate.argv[:3])}...) ---")
        for line in res.tail:
            print(f"  {line}")

    if failures:
        return 1
    if skipped:
        # 0 dondurmek "hepsi olculdu ve gecti" demek olurdu; olculmeyen kapi
        # varken bu yalan olur. Ayri kod cagirana gercegi soyler.
        return 3
    return 0


if __name__ == "__main__":
    sys.exit(main())
