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

# Windows konsolu cp1254; bulgu metni Türkçe karakter ve `→` içeriyor.
# Bu satır olmadan rapor yazdırılırken UnicodeEncodeError ile düşüyordu (WP-294).
for _stream in (sys.stdout, sys.stderr):
    if hasattr(_stream, "reconfigure"):
        _stream.reconfigure(encoding="utf-8", errors="replace")

ROOT = Path(__file__).resolve().parents[1]
ANDROID_MAIN = ROOT / "app/android/app/src/main"
VALUES_EN = ANDROID_MAIN / "res/values/strings.xml"
VALUES_TR = ANDROID_MAIN / "res/values-tr/strings.xml"
LOCALES_CONFIG = ANDROID_MAIN / "res/xml/locales_config.xml"
MANIFEST = ANDROID_MAIN / "AndroidManifest.xml"
MAIN_ACTIVITY = (
    ANDROID_MAIN / "kotlin/com/manilmax/online_study_room/MainActivity.kt"
)
APP_LOCALE_DART = ROOT / "app/lib/core/l10n/app_locale.dart"
LOCALE_TAG_RE = re.compile(r'<locale\s+android:name="([^"]+)"')

KEY_RE = re.compile(r'<string\s+name="([^"]+)"')
VALUE_RE = re.compile(r'<string\s+name="([^"]+)">(.*?)</string>', re.S)
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


def values(path: Path) -> dict[str, str]:
    return dict(VALUE_RE.findall(path.read_text(encoding="utf-8")))


def per_app_locale_errors() -> list[str]:
    """WP-559: uygulama dili native yuzeye gercekten iletiliyor mu?

    Olculdu (bagimsiz denetim): bildirim/widget/alarm metinleri
    `getString(R.string...)` ile cozuluyordu; o cagri `Configuration.locale`e,
    yani per-app override yoksa CIHAZ diline bakar. Telefon TR + uygulamada EN
    secili kullanici arayuzu Ingilizce, bildirimi Turkce goruyordu. WP-526 ayni
    hatayi yalniz Dart tarafinda kapatmisti.

    Zincirin DORT halkasi da olculur; biri kopunca ozellik sessizce olur:
      1. `res/xml/locales_config.xml` var ve yalniz yayinlanan dilleri sayiyor,
      2. manifest `<application>` etiketi onu `android:localeConfig` ile bildiriyor,
      3. Dart tarafi dil degisiminde native'e `setApplicationLocales` gonderiyor
         ve `system` icin BOS liste yolluyor (override temizlenmezse kullanici
         sistem diline donemez),
      4. native taraf o cagriyi `LocaleManager` ile karsiliyor.
    """
    errors: list[str] = []

    # 1. locales_config.xml
    if not LOCALES_CONFIG.is_file():
        errors.append(
            "res/xml/locales_config.xml yok -> Android 13+ per-app locale "
            "override'i kabul etmez, native metinler cihaz dilinde kalir"
        )
        declared: list[str] = []
    else:
        config_text = LOCALES_CONFIG.read_text(encoding="utf-8")
        declared = sorted(LOCALE_TAG_RE.findall(config_text))
        # Yayinlanan diller = lib/l10n altindaki .arb dosyalari.
        published = sorted(
            path.stem.removeprefix("app_")
            for path in (ROOT / "app/lib/l10n").glob("app_*.arb")
        )
        if declared != published:
            errors.append(
                f"locales_config.xml dilleri {declared}, yayinlanan .arb "
                f"dilleri {published} ile ayni olmali (l10n_dormant/ yayin "
                "girdisi degildir)"
            )

    # 2. manifest bildirimi
    if not MANIFEST.is_file():
        errors.append("AndroidManifest.xml yok")
    else:
        manifest_text = MANIFEST.read_text(encoding="utf-8")
        manifest_code = re.sub(r"<!--.*?-->", "", manifest_text, flags=re.S)
        application = re.search(r"<application\b[^>]*>", manifest_code, re.S)
        if application is None:
            errors.append("AndroidManifest.xml icinde <application> bulunamadi")
        elif 'android:localeConfig="@xml/locales_config"' not in application.group(0):
            errors.append(
                "manifest <application> etiketinde "
                'android:localeConfig="@xml/locales_config" yok -> '
                "setApplicationLocales sessizce etkisiz kalir"
            )

    # 3. Dart -> native cagrisi
    if not APP_LOCALE_DART.is_file():
        errors.append("app/lib/core/l10n/app_locale.dart yok")
    else:
        dart_text = APP_LOCALE_DART.read_text(encoding="utf-8")
        dart_code = re.sub(r"^\s*///.*?$", "", dart_text, flags=re.M)
        dart_code = re.sub(r"//.*?$", "", dart_code, flags=re.M)
        if "'setApplicationLocales'" not in dart_code:
            errors.append(
                "app_locale.dart dil degisimini native'e iletmiyor "
                "('setApplicationLocales' cagrisi yok) -> bildirim/widget/alarm "
                "cihaz dilinde kalir"
            )
        if "AppLanguage.system => const <String>[]" not in dart_code:
            errors.append(
                "app_locale.dart `system` tercihinde per-app override'i "
                "temizlemiyor (bos etiket listesi yok) -> kullanici sistem "
                "diline donemez"
            )

    # 4. native karsilayici
    if not MAIN_ACTIVITY.is_file():
        errors.append("MainActivity.kt yok")
    else:
        kt_code = re.sub(
            r"//.*?$", "", MAIN_ACTIVITY.read_text(encoding="utf-8"), flags=re.M
        )
        if '"setApplicationLocales"' not in kt_code:
            errors.append(
                "MainActivity.kt `setApplicationLocales` metodunu karsilamiyor"
            )
        if "LocaleManager" not in kt_code or "applicationLocales" not in kt_code:
            errors.append(
                "MainActivity.kt per-app locale'i LocaleManager ile "
                "uygulamiyor -> Dart cagrisi bosa gider"
            )

    return errors


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

    locale_dirs = sorted(
        path.parent.name
        for path in (ANDROID_MAIN / "res").glob("values-*/strings.xml")
    )
    if locale_dirs != ["values-tr"]:
        errors.append(
            "native locale resource dirs must be exactly ['values-tr']; "
            f"found {locale_dirs}"
        )

    errors.extend(per_app_locale_errors())

    en_values = values(VALUES_EN)
    expected_en_fallbacks = {
        "timer_ready": "Ready to focus",
        "timer_channel_name": "Study timer",
        "widget_daily_goal": "Daily goal",
    }
    for key, expected in expected_en_fallbacks.items():
        if en_values.get(key) != expected:
            errors.append(
                f"default native fallback {key!r} must be English {expected!r}"
            )

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

    print(
        f"OK: {len(en)} string keys EN=TR parity; default native fallback is "
        "English; no hardcoded TR user strings in kt/layout; per-app locale "
        "(locales_config + manifest + Dart->native setApplicationLocales) wired."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
