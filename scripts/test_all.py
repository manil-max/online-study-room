#!/usr/bin/env python3
"""Tek komutluk kalite kapısı koşucusu — `tester` ajanının motoru.

    python scripts/test_all.py            # T0+T1+T2 (varsayilan tur)
    python scripts/test_all.py --fast     # T0+T1 (dakika alti, kod yazarken)
    python scripts/test_all.py --full     # + golden + Windows/Android entegrasyon
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


def _adb() -> str | None:
    r"""`adb` yolunu cozer; PATH'te olmasi sart degil.

    🔴 Neden gerekli: WP-516'nin kapisi `shutil.which("adb")` ile bakiyordu ve
    bu makinede adb PATH'te DEGIL (SDK `C:\Android\Sdk`, `local.properties`
    icindeki `sdk.dir` gosteriyor). Sonuc: calisan bir SDK ve bootlanmis bir
    emulator varken kapi yine "adb kurulu degil" diyip ATLANDI donuyordu —
    yani kapi yerelde asla kosmuyordu. Atlanan kapi yesil degildir ama hep
    atlanan bir kapi da kapi degildir.
    """
    found = shutil.which("adb")
    if found:
        return found

    roots: list[Path] = []
    local_props = APP / "android" / "local.properties"
    if local_props.exists():
        for line in local_props.read_text(encoding="utf-8").splitlines():
            if line.strip().startswith("sdk.dir="):
                roots.append(Path(line.split("=", 1)[1].strip().replace("\\\\", "\\")))
    for env_name in ("ANDROID_SDK_ROOT", "ANDROID_HOME"):
        value = os.environ.get(env_name)
        if value:
            roots.append(Path(value))

    for root in roots:
        candidate = root / "platform-tools" / ("adb.exe" if os.name == "nt" else "adb")
        if candidate.exists():
            return str(candidate)
    return None


def _needs_android_device() -> tuple[bool, str]:
    """Emulator/cihaz smoke'u yalniz gercek bir Android hedefi varken kosar.

    ATLANDI yesil DEGILDIR: bu kapi kosmadiginda tur `3` ile biter ve ozet
    tablosunda sebebiyle listelenir. Kapinin asil evi CI'daki `android-emulator`
    isidir (matris API 30 + 33).
    """
    adb = _adb()
    if adb is None:
        return False, "`adb` bulunamadi (PATH, local.properties sdk.dir, ANDROID_SDK_ROOT)"
    probe = subprocess.run(
        [adb, "devices"], capture_output=True, text=True, timeout=60
    )
    if probe.returncode != 0:
        return False, "`adb devices` calismadi — Android SDK platform-tools eksik"
    booted = [
        line.split("\t")[0]
        for line in probe.stdout.splitlines()[1:]
        if line.strip().endswith("\tdevice")
    ]
    if not booted:
        return False, "Acik Android cihaz/emulator yok (CI'da emulator job'i kosar)"
    ok, reason = _needs_env_json()
    if not ok:
        return ok, reason
    # APK derlemesi `validateLocalEnvironment` Gradle kapisindan gecer; beta/
    # staging sekilli bir env.json ile `--flavor local` derlemesi kapiyi
    # anlamsiz bir Gradle hatasiyla kirmiziya dusururdu.
    import json
    try:
        env = json.loads((APP / "env.json").read_text(encoding="utf-8-sig"))
    except (OSError, json.JSONDecodeError) as err:
        return False, f"app/env.json okunamadi: {err}"
    if env.get("CHANNEL") != "local" or env.get("APP_ENVIRONMENT") != "local":
        return False, (
            "app/env.json `local` flavor'a ait degil "
            "(`cp env.local.example.json env.json`)"
        )
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
        # WP-500: kapinin kendisi de sinanir. Onceki prob yalniz duz bir
        # `Text('...')` deniyordu; degiskenle baslayan gomulu cumle (asil kor
        # nokta) hic sinanmiyordu ve uretime cikti.
        Gate("l10n-self", "l10n kapisi kendini sinar", 0,
             [py, "scripts/l10n_audit.py", "--self-test"]),
        Gate("l10n-android", "Android kaynak metin denetimi", 0,
             [py, "scripts/l10n_android_audit.py"]),
        Gate("migration-head", "Migration head uc yerde pinli", 0,
             [py, "scripts/test_all.py", "--internal-migration-head"]),
        # WP-525: uygulama yasal sayfa adresini KOD ICINDE kuruyor. Site o
        # dosyayi uretmezse kullanici 404 gorur ve hicbir derleme hatasi
        # bunu yakalamaz -- kapi yollari koddan tarayip karsilastirir.
        Gate("legal-site", "Yasal site sozlesmesi", 0,
             [py, "scripts/build_legal_site.py", "--check"]),
        # WP-533: `play` flavor'i WP-527'ye kadar hic derlenmemisti; eksik
        # google-services.json v61 yayin turunu
        # processPlayReleaseGoogleServices adiminda dusurdu. Bu kapi ayni
        # eksigi derlemeden once, saniyeler icinde olcer.
        Gate("play-firebase", "Play flavor Firebase/ikon kaynagi", 0,
             [py, "scripts/test_all.py", "--internal-play-firebase"]),
        # WP-537: `open_filex` eklentisi dort genis medya iznini Play
        # surumune tasiyordu; karsiligi olan kod Play'de hic calismiyor.
        Gate("play-manifest", "Play manifest izin sozlesmesi", 0,
             [py, "scripts/test_all.py", "--internal-play-manifest"]),
        # WP-505: pin alti workflow adiminda duruyor; biri kayarsa goldenlar
        # kod degismeden kirmiziya duser.
        Gate("flutter-pin", "Flutter surumu her workflow'da ayni", 0,
             [py, "scripts/test_all.py", "--internal-flutter-pin"]),

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
        # 🔴 WP-516: v58'de geri sayim + pomodoro Android'de aciliste
        # cokuyordu (Dart `setInt` -> `putLong`, native `getInt` ->
        # ClassCastException) ve 18 kapinin hicbiri kirmizi donmedi. Bu kapi
        # sayaci GERCEK bir Android surecinde baslatip durduran tek kapidir.
        Gate("android-smoke", "Android emulator sayac smoke", 3,
             [py, "scripts/test_all.py", "--internal-android-smoke"],
             precondition=_needs_android_device),
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


def internal_android_smoke() -> int:
    """Sayac smoke'unu acik emulator/cihazda kostur, sonra crash tamponunu tara.

    🔴 `flutter test` tek basina yetmez: native taraf sureci oldururse kosum
    yalniz "Lost connection to device" der, kok neden **yalniz** logcat crash
    tamponunda durur. CI'daki `android-emulator` isi de ayni iki adimi yapar;
    yerel ile CI ayni seyi olcsun diye mantik burada tek yerde.
    """
    adb = _adb()
    if adb is None:
        print("adb bulunamadi.")
        return 1
    devices = subprocess.run(
        [adb, "devices"], capture_output=True, text=True, timeout=60
    )
    booted = [
        line.split("\t")[0]
        for line in devices.stdout.splitlines()[1:]
        if line.strip().endswith("\tdevice")
    ]
    if not booted:
        print("Acik Android cihaz/emulator yok.")
        return 1
    device = booted[0]
    print(f"Cihaz: {device}")

    subprocess.run([adb, "-s", device, "logcat", "-c"], timeout=60)

    # 🔴 APK once derlenir ve `install -g` ile TUM runtime izinleri verilerek
    # kurulur. Sebebi olculdu (API 33): ilk `Baslat` POST_NOTIFICATIONS
    # diyalogunu acar, diyalog ekranda kalir ve ikinci `Baslat`
    # `PlatformException(permissionRequestInProgress)` firlatir — kapi sayacla
    # ilgisi olmayan bir sebeple kirmizi duserdi. `flutter test` ayni APK'yi
    # yeniden kurar; `-r` verilmis izinleri korur.
    apk = APP / "build" / "app" / "outputs" / "flutter-apk" / "app-local-debug.apk"
    steps: list[list[str]] = [
        [_exe("flutter"), "build", "apk", "--debug", "--flavor", "local",
         "--dart-define-from-file=env.json"],
        [adb, "-s", device, "install", "-r", "-t", "-g", str(apk)],
        [_exe("flutter"), "test", "-d", device, "--flavor", "local",
         "integration_test/android_timer_smoke_test.dart",
         "--dart-define-from-file=env.json"],
    ]
    status = 0
    for argv in steps:
        status = subprocess.run(argv, cwd=APP).returncode
        if status != 0:
            break

    crash = subprocess.run(
        [adb, "-s", device, "logcat", "-b", "crash", "-d"],
        capture_output=True, text=True, errors="replace", timeout=120,
    ).stdout
    if "ClassCastException" in crash:
        print("KIRMIZI: logcat crash tamponunda ClassCastException var — "
              "v58 sinifi Dart<->native prefs tip kaymasi.")
        status = 1
    if "com.manilmax.online_study_room" in crash:
        print("KIRMIZI: uygulama sureci logcat crash tamponuna dustu.")
        status = 1
    if status != 0:
        print(crash[-4000:])
    return status


def internal_flutter_pin() -> int:
    """Her workflow ayni Flutter surumune pinli mi?

    🔴 Bu kapinin sebebi olculdu (WP-498/WP-505): workflow'lar `channel: stable`
    diyordu, surum pinlemiyordu. Yerel surum 3.44.2 iken runner o gunku
    stable'i kuruyor ve alt-piksel yerlesim farki goldenlari **kod hic
    degismeden** kirmiziya dusuruyordu:
      * cerceve Card  -> `image sizes do not match`, 288x225 vs 288x224
      * cerceve ekran -> %4.61 / 13278 px raster farki (payin 9 kati)
    WP-498'in goldeni bu yuzden silinmek zorunda kaldi.

    ⚠️ Pin **alti ayri yerde** duruyor. Migration head'in ucu bir yerde
    unutulup CI'i iki kez kirmizi dusurmustu (AGENTS.md dersi); ayni hata
    burada alti kat daha olasi. Tek kaynak repo kokundeki `.flutter-version`;
    bu kapi her workflow'un onunla ayni degeri tasidigini dogrular.

    Yukseltme yordami: `.flutter-version`i degistir, bu kapiyi kosur, soyledigi
    yerleri guncelle, sonra goldenlari **tek commit'te** yenile.
    """
    import re

    pin_file = ROOT / ".flutter-version"
    if not pin_file.exists():
        print("FAIL: .flutter-version yok — pinin tek kaynagi bu dosyadir.")
        return 1
    expected = pin_file.read_text(encoding="utf-8").strip()
    if not re.fullmatch(r"\d+\.\d+\.\d+", expected):
        print(f"FAIL: .flutter-version okunamadi: {expected!r}")
        return 1

    problems: list[str] = []
    checked = 0
    for path in sorted((ROOT / ".github" / "workflows").glob("*.yml")):
        text = path.read_text(encoding="utf-8")
        rel = path.relative_to(ROOT).as_posix()
        uses = text.count("subosito/flutter-action")
        if not uses:
            continue
        pins = re.findall(r"flutter-version:\s*(\S+)", text)
        checked += uses
        if len(pins) != uses:
            problems.append(
                f"{rel}: {uses} flutter-action adimi var ama {len(pins)} "
                "`flutter-version` pini — pinsiz adim runner'in o gunku "
                "stable'ini kurar"
            )
        for pin in pins:
            if pin != expected:
                problems.append(
                    f"{rel}: pin {pin} != .flutter-version {expected}"
                )

    if not checked:
        print("FAIL: hicbir workflow'da flutter-action bulunamadi.")
        return 1
    if problems:
        print(f"FAIL ({len(problems)}):")
        for problem in problems:
            print(f"  - {problem}")
        return 1
    print(
        f"OK: {checked} flutter-action adimi da {expected} surumune pinli "
        "(.flutter-version)."
    )
    return 0


def internal_play_manifest() -> int:
    r"""WP-537: Play surumu, Play'de HIC CALISMAYAN bir ozellik icin genis
    medya izinleri istiyordu.

    Olculdu (v61 turu): `playRelease` birlestirilmis manifestinde
    READ_MEDIA_IMAGES, READ_MEDIA_VIDEO, READ_MEDIA_AUDIO ve
    READ_EXTERNAL_STORAGE vardi. Hicbiri bizim manifestimizde yazili degil --
    `open_filex` eklentisi kendi manifestinde bildiriyor ve manifest
    birlestirme uygulamaya tasiyor. O eklentinin tek kullanim yeri sideload
    updater'i, o da Play surumunde kapali.

    Play tarafinda bedeli somut: READ_MEDIA_IMAGES/VIDEO "Photo and Video
    Permissions" beyanini, READ_MEDIA_AUDIO ise "Music and audio files"
    kisitli izin beyanini tetikler.

    WP-544: ayni listeye `USE_EXACT_ALARM` eklendi. Bu izin bizim kendi
    manifestimizde yaziliydi (eklenti sizintisi degil). Play Console "Tam
    alarmlar" beyani yalnizca "Calar saat" / "Takvim" secenegi sunuyor ve
    ikisi de degilsen izni kaldirmani sart kosuyor. Olculdu: v61 gonderiminde
    bu hata surum yayinlamayi bloke etti. `SCHEDULE_EXACT_ALARM` kalir ve
    kullanicidan istenir.

    Kapi iki katmanli olcer:
      1. Kaynak: `src/play/AndroidManifest.xml` her birini `tools:node=remove`
         ile dusuruyor mu? (Her zaman olculur.)
      2. Cikti: birlestirilmis playRelease manifesti diskteyse, izinlerin
         gercekten dusdugu dogrulanir. (Gradle kosmadiysa ATLANIR -- ve bu
         durum ciktida acikca yazilir, sessizce yesil sayilmaz.)
    """
    import re

    android = APP / "android" / "app"
    play_manifest = android / "src" / "play" / "AndroidManifest.xml"
    problems: list[str] = []

    banned = [
        # WP-544: Play "Tam alarmlar" beyani yalnizca calar saat / takvim
        # uygulamalarini kabul ediyor; biz ikisi de degiliz. Izin geri
        # sizarsa surum yayinlama yeniden bloke olur.
        "android.permission.USE_EXACT_ALARM",
        "android.permission.READ_MEDIA_IMAGES",
        "android.permission.READ_MEDIA_VIDEO",
        "android.permission.READ_MEDIA_AUDIO",
        "android.permission.READ_EXTERNAL_STORAGE",
    ]

    if not play_manifest.exists():
        print(f"FAIL: {play_manifest.relative_to(ROOT)} yok.")
        return 1

    source = play_manifest.read_text(encoding="utf-8")
    # Yorumlar atilir: yorum icindeki izin adi kapiyi yaniltmamali.
    stripped = re.sub(r"<!--.*?-->", "", source, flags=re.S)

    if "xmlns:tools" not in stripped:
        problems.append(
            "src/play/AndroidManifest.xml `xmlns:tools` bildirmiyor; "
            "`tools:node` calismaz"
        )

    for permission in banned:
        pattern = re.compile(
            r'<uses-permission[^>]*android:name\s*=\s*"' + re.escape(permission)
            + r'"[^>]*tools:node\s*=\s*"remove"',
            re.S,
        )
        if not pattern.search(stripped):
            problems.append(
                f"play manifesti {permission} iznini dusurmuyor "
                "(tools:node=remove yok) -> Play beyan formu tetiklenir"
            )

    # WP-546: Android varsayilani `allowBackup=true`. Supabase oturumu
    # (refresh token dahil) `shared_prefs/*.xml` icinde duruyor -- olculdu:
    # `Supabase.initialize` authOptions vermiyor, dolayisiyla varsayilan
    # `SharedPreferencesLocalStorage(persistSessionKey: "sb-<ref>-auth-token")`
    # devreye giriyor. Yedek acikken bu anahtar Google Drive yedegine ve
    # cihaz-cihaz transferine giriyor. Kapatildi; kapi geri acilmasini engeller.
    main_manifest = android / "src" / "main" / "AndroidManifest.xml"
    if not main_manifest.exists():
        problems.append("src/main/AndroidManifest.xml yok")
    else:
        main_source = re.sub(
            r"<!--.*?-->", "", main_manifest.read_text(encoding="utf-8"), flags=re.S
        )
        if 'android:allowBackup="false"' not in main_source:
            problems.append(
                'src/main/AndroidManifest.xml `android:allowBackup="false"` '
                "bildirmiyor -> Supabase refresh token'i cihaz yedegine girer"
            )

    merged = sorted(
        (APP / "build").glob(
            "app/intermediates/merged_manifest*/playRelease/**/AndroidManifest.xml"
        )
    )
    if not merged:
        print(
            "NOT: birlestirilmis playRelease manifesti diskte yok, cikti "
            "katmani olculmedi (gradle :app:processPlayReleaseManifest)."
        )
    else:
        for path in merged:
            body = path.read_text(encoding="utf-8", errors="replace")
            for permission in banned:
                if permission in body:
                    problems.append(
                        f"{path.name} ({path.parent.name}) hala {permission} "
                        "tasiyor"
                    )
            if 'android:allowBackup="false"' not in body:
                problems.append(
                    f"{path.name} ({path.parent.name}) birlestirilmis manifesti "
                    'android:allowBackup="false" tasimiyor'
                )

    if problems:
        print(f"FAIL ({len(problems)}):")
        for problem in problems:
            print(f"    - {problem}")
        return 1

    measured = "kaynak + birlestirilmis cikti" if merged else "yalniz kaynak"
    print(f"Play manifest izin sozlesmesi tamam ({measured}).")
    return 0


def internal_play_firebase() -> int:
    """`play` flavor'inin Firebase yapilandirmasi ve ikon kaynagi gercekten var mi?

    Kapinin sebebi olculdu (WP-533, v61 yayin kosumu 31263777781):

        Execution failed for task ':app:processPlayReleaseGoogleServices'.
        > File google-services.json is missing.
          Searched: .../src/play/release/, .../src/release/play/, .../src/play/,
                    .../src/release/, .../src/playRelease/, .../app/

    `play` flavor'i WP-527'ye kadar HIC derlenmemisti; eksik dosya bu yuzden
    aylarca gorunmedi ve ilk kosumda yayin turunu dusurdu. Derlenmeyen sey
    olculmez, olculmeyen sey yayinda patlar -- bu kapi olcumu derlemeden ayirir
    (saniyeler surer, Gradle/Flutter kurulumu istemez).

    Hata metnindeki arama listesi onemli: google-services eklentisi dosyayi
    SABIT `src/<flavor>/` yollarinda arar, Gradle `sourceSets` tanimlarina
    bakmaz. Yani play'e Firebase yapilandirmasini sourceSets ile veremeyiz;
    `src/play/google-services.json` ayri bir dosya olmak zorunda. Ayri dosya =
    zamanla ayrisma riski, o yuzden burada stable ile BIREBIR ayni oldugu
    (byte duzeyinde) dogrulanir.

    Ayrica launcher ikonu olculur: `src/main/AndroidManifest.xml` her varyantta
    `@mipmap/ic_launcher` ister ama mipmap kaynaklari yalniz flavor res
    dizinlerinde durur. `src/play/res` hic yoktu; google-services duzeltilseydi
    bile bir sonraki adim kaynak baglamada duserdi.
    """
    import json
    import re

    android = APP / "android" / "app"
    gradle_path = android / "build.gradle.kts"
    gradle_raw = gradle_path.read_text(encoding="utf-8", errors="replace")
    # 🔴 Yorum satirlari ATILIR. Kirik girdi olcumunde yakalandi: `res.srcDir`
    # satirini SILMEK kapiyi kirmizi dusuruyordu ama basina `//` koymak
    # dusurmuyordu -- oysa bir satiri devre disi birakmanin en yaygin yolu
    # yorum yapmaktir. Yorumdaki metin Gradle icin yok hukmundedir; kapi da
    # oyle gormelidir.
    gradle = re.sub(r"(?m)//.*$", "", gradle_raw)
    problems: list[str] = []

    app_id_match = re.search(r'applicationId\s*=\s*"([^"]+)"', gradle)
    if app_id_match is None:
        print("FAIL: build.gradle.kts icinde applicationId bulunamadi.")
        return 1
    base_id = app_id_match.group(1)

    # Yalniz `productFlavors { ... }` blogu taranir. Tum dosyaya acilan bir
    # tarama `signingConfigs { create("release") }` satirini da yakalar ve
    # `release` sahte bir flavor olarak olculurdu (bu kapi yazilirken oldu).
    opened = gradle.find("productFlavors")
    flavor_block = ""
    if opened >= 0:
        depth = 0
        for index in range(gradle.index("{", opened), len(gradle)):
            if gradle[index] == "{":
                depth += 1
            elif gradle[index] == "}":
                depth -= 1
                if depth == 0:
                    flavor_block = gradle[opened:index]
                    break
    starts = [
        (m.group(1), m.end())
        for m in re.finditer(r'create\("(\w+)"\)', flavor_block)
    ]
    if not starts:
        print('FAIL: productFlavors icinde create("...") blogu bulunamadi.')
        return 1
    flavors: dict[str, str] = {}
    for index, (name, offset) in enumerate(starts):
        end = starts[index + 1][1] if index + 1 < len(starts) else len(flavor_block)
        block = flavor_block[offset:end]
        suffix = re.search(r'applicationIdSuffix\s*=\s*"([^"]+)"', block)
        flavors[name] = base_id + (suffix.group(1) if suffix else "")

    # google-services islemesi bilerek kapatilan flavor'lar (ornek: local).
    exempt = set(re.findall(r'flavorName\s*==\s*"(\w+)"', gradle))

    # sourceSets ile odunc alinan res dizinleri.
    borrowed: dict[str, list[str]] = {}
    for name, path in re.findall(
        r'sourceSets\.getByName\("(\w+)"\)\.res\.srcDir\("([^"]+)"\)', gradle
    ):
        borrowed.setdefault(name, []).append(path)

    project_ids: dict[str, str] = {}
    for flavor in sorted(flavors):
        expected = flavors[flavor]
        config = android / "src" / flavor / "google-services.json"
        if flavor in exempt:
            if config.exists():
                problems.append(
                    f"{flavor}: google-services islemesi kapali ama "
                    f"{config.relative_to(ROOT).as_posix()} yine de duruyor"
                )
            continue
        if not config.exists():
            problems.append(
                f"{flavor}: {config.relative_to(ROOT).as_posix()} YOK "
                "(eklenti yalniz sabit src/<flavor>/ yollarina bakar; "
                "sourceSets bu dosyayi tasiyamaz)"
            )
            continue
        try:
            data = json.loads(config.read_text(encoding="utf-8-sig"))
        except (OSError, json.JSONDecodeError) as err:
            problems.append(f"{flavor}: google-services.json okunamadi/bozuk: {err}")
            continue
        packages = [
            client.get("client_info", {})
            .get("android_client_info", {})
            .get("package_name")
            for client in data.get("client", [])
        ]
        if expected not in packages:
            problems.append(
                f"{flavor}: applicationId {expected} google-services.json client "
                f"listesinde yok ({packages}) -> derleme "
                "process<Flavor>ReleaseGoogleServices adiminda duser"
            )
        project_ids[flavor] = str(data.get("project_info", {}).get("project_id", ""))

    if len(set(project_ids.values())) > 1:
        problems.append(
            f"flavor'lar farkli Firebase projelerine bakiyor: {project_ids}"
        )

    # play <-> stable ayrisma kapisi: ayni applicationId ise dosya da ayni olmali.
    if "play" in flavors and flavors.get("play") == flavors.get("stable"):
        play_file = android / "src" / "play" / "google-services.json"
        stable_file = android / "src" / "stable" / "google-services.json"
        if play_file.exists() and stable_file.exists():
            if play_file.read_bytes() != stable_file.read_bytes():
                problems.append(
                    "play ve stable ayni applicationId'yi kullaniyor ama "
                    "google-services.json dosyalari ayrismis (byte farki) -- "
                    "kopya guncel degil"
                )
    elif "play" in flavors:
        problems.append(
            f"play applicationId {flavors.get('play')} artik stable "
            f"{flavors.get('stable')} ile ayni degil; play icin ayri bir Firebase "
            "kaydi gerekir (sahip karari)"
        )

    # Launcher ikonu: main manifest her varyantta @mipmap/ic_launcher ister.
    manifest = (android / "src" / "main" / "AndroidManifest.xml").read_text(
        encoding="utf-8", errors="replace"
    )
    icon = re.search(r'android:icon="@mipmap/(\w+)"', manifest)
    if icon is not None:
        for flavor in sorted(flavors):
            roots = [android / "src" / flavor / "res"]
            roots += [android / path for path in borrowed.get(flavor, [])]
            found = any(
                any(root.glob(f"mipmap-*/{icon.group(1)}.*"))
                for root in roots
                if root.is_dir()
            )
            if not found:
                shown = [r.relative_to(ROOT).as_posix() for r in roots]
                problems.append(
                    f"{flavor}: @mipmap/{icon.group(1)} hicbir res kaynaginda yok "
                    f"({shown}) -> kaynak baglama adiminda duser"
                )

    if problems:
        print(f"FAIL ({len(problems)}):")
        for problem in problems:
            print(f"  - {problem}")
        return 1
    measured = sorted(set(flavors) - exempt)
    print(
        f"OK: {', '.join(measured)} flavor'larinin google-services.json'u var ve "
        f"applicationId'siyle esliyor (proje {sorted(set(project_ids.values()))}); "
        "play == stable birebir; tum flavor'larda launcher ikonu cozuluyor."
    )
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
                        help="golden + Windows/Android entegrasyon + pgTAP dahil")
    parser.add_argument("--only", default="",
                        help="virgulle ayrilmis kapi anahtarlari")
    parser.add_argument("--list", action="store_true", help="kapilari listele")
    parser.add_argument("--internal-deno-check", action="store_true",
                        help=argparse.SUPPRESS)
    parser.add_argument("--internal-migration-head", action="store_true",
                        help=argparse.SUPPRESS)
    parser.add_argument("--internal-flutter-pin", action="store_true",
                        help=argparse.SUPPRESS)
    parser.add_argument("--internal-play-firebase", action="store_true",
                        help=argparse.SUPPRESS)
    parser.add_argument("--internal-play-manifest", action="store_true",
                        help=argparse.SUPPRESS)
    parser.add_argument("--internal-android-smoke", action="store_true",
                        help=argparse.SUPPRESS)
    args = parser.parse_args()

    if args.internal_deno_check:
        return internal_deno_check()
    if args.internal_migration_head:
        return internal_migration_head()
    if args.internal_flutter_pin:
        return internal_flutter_pin()
    if args.internal_play_firebase:
        return internal_play_firebase()
    if args.internal_play_manifest:
        return internal_play_manifest()
    if args.internal_android_smoke:
        return internal_android_smoke()

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
