#!/usr/bin/env python3
"""WP-457: l10n kapısı — release EN/TR katalogları + gömülü metin + native yüzeyler.

Usage (repo root):
  python scripts/l10n_audit.py

Tarih: WP-89'da katalog denetimi olarak doğdu. WP-294 gömülü kullanıcı metni
ve native yüzey denetimini ekledi. WP-457 release runtime'ını yeniden EN/TR ile
sınırladı; DE/AR kaynakları generator dışındaki dormant arşivde korunuyor.

1. **Release katalogları** (`en`, `tr`) — anahtar + placeholder eşliği iki dilde
   denetlenir. Şablon `en`.
2. **Gömülü prose metin** — Türkçe karakter içermeyen Türkçe cümleler (`Boyut …
   dokun ve ayarla`) ve gömülü İngilizce cümleler de yakalanır. Tarama
   **kullanıcıya görünen widget yuvalarıyla** sınırlı (`Text(`, `title:`,
   `tooltip:` …); aksi hâlde yanlış pozitif oranı denetimi kullanılamaz kılıyor.
3. **UTF-8 çıktı** — Windows `cp1254` konsolunda bulguları yazdırırken çöküyordu
   (`UnicodeEncodeError`), yani denetim raporunu **hiç göstermeden** düşüyordu.

Denetim bilinçli olarak üretilen l10n çıktısını, yorumları ve testleri dışlar.
Muafiyetler `INTERNAL_PREFIXES` / `LITERAL_EXEMPTIONS` / `UI_PROSE_EXEMPTIONS`
altında **gerekçesiyle** durur; gerekçesiz muafiyet eklenmez.
"""

from __future__ import annotations

import json
import os
import re
import subprocess
import sys
from pathlib import Path


# Windows konsolu cp1254; bulgular Türkçe/Almanca/Arapça metin içeriyor.
# Bu satır olmadan denetim raporu yazdırırken çöküyordu (WP-294 bulgu (a)).
for stream in (sys.stdout, sys.stderr):
    if hasattr(stream, "reconfigure"):
        stream.reconfigure(encoding="utf-8", errors="replace")

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "app"
DART_ROOT = APP / "lib"
NATIVE_AUDIT = ROOT / "scripts/l10n_android_audit.py"

# Şablon dil `en`; diğerleri ona göre denetlenir.
TEMPLATE_LOCALE = "en"
LOCALES = ("en", "tr")


def arb_path(locale: str) -> Path:
    return APP / f"lib/l10n/app_{locale}.arb"


TURKISH_CHAR_RE = re.compile(r"[ÇĞİÖŞÜçğıöşü]")
LINE_COMMENT_RE = re.compile(r"//.*?$", re.MULTILINE)
BLOCK_COMMENT_RE = re.compile(r"/\*.*?\*/", re.DOTALL)
STRING_RE = re.compile(r"'(?:\\.|[^'\\])*'|\"(?:\\.|[^\"\\])*\"", re.DOTALL)

# Kullanıcıya görünen widget yuvaları. Prose taraması **yalnız** burada çalışır:
# tüm literal'lere bakmak teknik sabitler yüzünden kullanılamaz bir gürültü
# üretiyor (rota adları, pref anahtarları, SQL, asset yolları…).
UI_SLOT = (
    r"(?:(?:Text|SelectableText|Tooltip)\(\s*"
    r"|(?:title|subtitle|label|labelText|hintText|helperText|errorText|tooltip"
    r"|content|semanticsLabel|message|dialogTitle|confirmLabel)\s*:\s*)"
)
UI_LITERAL_RE = re.compile(
    UI_SLOT + r"'((?:\\.|[^'\\])*)'|" + UI_SLOT + r'"((?:\\.|[^"\\])*)"',
    re.DOTALL,
)

# "Cümle gibi duruyor": büyük harfle başlıyor ve içinde boşluk var.
PROSE_RE = re.compile(r"^[A-ZÇĞİÖŞÜ][^\n]*\s")
# Teknik sabit kalıpları — çeviri gerektirmez.
TECHNICAL_RE = re.compile(
    r"://"  # URL
    r"|^[a-z0-9_.]+$"  # snake/dotted id
    r"|^[A-Z0-9_]+$"  # SCREAMING_CASE sabit
    r"|^\$"  # tamamı interpolasyon
    r"|^@"  # asset/annotation
    r"|^\d"  # sayıyla başlayan biçim
    r"|^[a-z]+[A-Z]"  # camelCase id
)

# (1) Depo/istisna taksonomisi: bunlar iç sınıflandırıcı girdisidir. Sunum kodu
# kategoriyi aktif AppLocalizations kataloğuna eşler, ham mesajı **göstermez**.
INTERNAL_PREFIXES = ("app/lib/data/repositories/",)

# (2) Dosya bazlı muafiyetler — Türkçe literal taraması. Her satır bir gerekçe
# taşır; gerekçesi yazılamayan dosya muaf edilmez.
LITERAL_EXEMPTIONS: dict[str, str] = {
    "app/lib/core/time_engine/sky_phase.dart": (
        "Yalnız statik gökyüzü anchor invariantı bozulduğunda geliştiriciye atılan "
        "ArgumentError; kullanıcı yüzeyine taşınmaz."
    ),
    "app/lib/features/classroom/widgets/campfire_layout.dart": (
        "Yalnız yerleşim profilinin derleme/önizleme invariantı bozulduğunda "
        "geliştiriciye atılan ArgumentError'lar; kullanıcı yüzeyine taşınmaz."
    ),
    "app/lib/core/observability/observability_service.dart": (
        "Sentry etiketleri ve breadcrumb metinleri — telemetri alanı, kullanıcıya "
        "gösterilmez."
    ),
    "app/lib/data/models/report_target.dart": (
        "ReportTarget invariant ve wire ayrıştırma ArgumentError mesajlarıdır; "
        "kullanıcı arayüzünde gösterilmez."
    ),
    "app/lib/core/prefs/app_prefs.dart": (
        "SharedPreferences anahtarları — kalıcı depolama sözleşmesi, çevrilirse "
        "kullanıcı verisi kaybolur."
    ),
    "app/lib/features/auth/auth_screen.dart": (
        "Supabase hata kodu eşlemesi; kullanıcıya gösterilen metin katalogdan "
        "geliyor."
    ),
    "app/lib/features/profile/legal_documents.dart": (
        "Yasal metinler (gizlilik, koşullar, topluluk kuralları) kodda TR+EN "
        "olarak gömülü. 🔴 Bilinen borç: bu metinlerin katalog/asset mimarisine "
        "taşınması WP-294 kapsamı DIŞINDA, ayrı WP. Katalogla değiştirilmesi "
        "yasal sürüm takibini (policyVersion) da etkiler."
    ),
    "app/lib/features/profile/theme_builder/bundled_font_licenses.dart": (
        "`debugPrint` geliştirici günlüğü (WP-297 lisans yükleme hatası) — "
        "kullanıcı arayüzünde görünmez."
    ),
}

# (3) Prose taraması muafiyetleri — çevrilmemesi **doğru** olan metinler.
UI_PROSE_EXEMPTIONS: dict[str, str] = {
    "app/lib/core/stats/achievement_engine.dart": (
        "Motor içi başarım tanımları (`kAllAchievements`, yalnız `:194`'te "
        "tüketiliyor). Kullanıcıya görünen başarım metni sunucu sözlüğünden "
        "(`achievementDictionaryProvider`) gelir."
    ),
    "app/lib/core/stats/gamification.dart": (
        "`AchievementStatus.title` hiçbir widget'ta çizilmiyor; liste yalnız "
        "`crownTierFor` tarafından okunuyor."
    ),
    "app/lib/core/time_engine/world_clock_math.dart": (
        "IANA şehir adları (New York, São Paulo) — özel isim, çevrilmez."
    ),
    "app/lib/data/providers/alarm_providers.dart": (
        "Varsayılan dünya saati şehir adı — özel isim, çevrilmez."
    ),
    "app/lib/features/desktop/desktop_navigation_pane.dart": (
        "Klavye kısayolu ipucu (`Ctrl+1…5`): tuş adları platform sabiti, "
        "çevrilebilir kısım zaten `AppLocalizations` üzerinden geliyor."
    ),
}


def catalog(path: Path) -> dict[str, object]:
    return json.loads(path.read_text(encoding="utf-8"))


def source_keys(data: dict[str, object]) -> set[str]:
    return {key for key in data if not key.startswith("@")}


def strip_comments(source: str) -> str:
    return LINE_COMMENT_RE.sub("", BLOCK_COMMENT_RE.sub("", source))


def dart_sources() -> list[tuple[str, str]]:
    """(repo-relative path, yorumları çıkarılmış kaynak) çiftleri."""
    sources: list[tuple[str, str]] = []
    for path in sorted(DART_ROOT.rglob("*.dart")):
        relative = path.relative_to(ROOT).as_posix()
        if relative.startswith("app/lib/l10n/"):
            continue
        sources.append(
            (relative, strip_comments(path.read_text(encoding="utf-8")))
        )
    return sources


def line_of(source: str, index: int) -> int:
    return source.count("\n", 0, index) + 1


def turkish_literal_violations(sources: list[tuple[str, str]]) -> list[str]:
    violations: list[str] = []
    for relative, source in sources:
        if (
            relative.startswith(INTERNAL_PREFIXES)
            or relative in LITERAL_EXEMPTIONS
        ):
            continue
        for match in STRING_RE.finditer(source):
            literal = match.group(0)[1:-1]
            if TURKISH_CHAR_RE.search(literal):
                line = line_of(source, match.start())
                violations.append(f"{relative}:{line}: {literal!r}")
    return violations


def looks_like_prose(text: str) -> bool:
    stripped = text.strip()
    if len(stripped) < 4 or TECHNICAL_RE.search(stripped):
        return False
    return bool(PROSE_RE.match(stripped))


def ui_prose_violations(sources: list[tuple[str, str]]) -> list[str]:
    """Kullanıcı yuvasına doğrudan yazılmış cümleler (dil ne olursa olsun).

    Türkçe taramanın kaçırdığı iki sınıfı yakalar: (a) Türkçe'ye özel karakter
    içermeyen Türkçe cümleler, (b) gömülü İngilizce cümleler.
    """
    violations: list[str] = []
    for relative, source in sources:
        if (
            relative.startswith(INTERNAL_PREFIXES)
            or relative in UI_PROSE_EXEMPTIONS
        ):
            continue
        for match in UI_LITERAL_RE.finditer(source):
            literal = match.group(1)
            if literal is None:
                literal = match.group(2)
            if literal is not None and looks_like_prose(literal):
                line = line_of(source, match.start())
                violations.append(f"{relative}:{line}: {literal!r}")
    return violations


def catalog_errors() -> tuple[list[str], int]:
    """Release kataloglarında anahtar + placeholder eşliği."""
    errors: list[str] = []
    catalogs = {locale: catalog(arb_path(locale)) for locale in LOCALES}
    keys = {locale: source_keys(data) for locale, data in catalogs.items()}
    template = catalogs[TEMPLATE_LOCALE]
    template_keys = keys[TEMPLATE_LOCALE]

    for locale in LOCALES:
        if locale == TEMPLATE_LOCALE:
            continue
        if missing := sorted(template_keys - keys[locale]):
            errors.append(f"ARB keys missing in {locale.upper()}: {missing}")
        if extra := sorted(keys[locale] - template_keys):
            errors.append(f"ARB keys only in {locale.upper()}: {extra}")

    for key in sorted(template_keys):
        metadata = template.get(f"@{key}")
        if not isinstance(metadata, dict):
            errors.append(f"missing template metadata for {key}")
            continue
        placeholders = metadata.get("placeholders", {})
        if not isinstance(placeholders, dict):
            errors.append(f"invalid template placeholder metadata for {key}")
            continue
        if not placeholders:
            continue
        # Placeholder eşliği **her dilde** denetlenir; eskiden yalnız TR'de
        # bakılıyordu, DE/AR'de eksik placeholder sessizce geçiyordu.
        for locale in LOCALES:
            if locale == TEMPLATE_LOCALE or key not in keys[locale]:
                continue
            localized = catalogs[locale][key]
            for placeholder in placeholders:
                if (
                    not isinstance(localized, str)
                    or f"{{{placeholder}" not in localized
                ):
                    errors.append(
                        f"{locale.upper()} value for {key} does not reference "
                        f"{{{placeholder}}}"
                    )
    return errors, len(template_keys)


def native_errors() -> tuple[list[str], str]:
    env = dict(os.environ, PYTHONIOENCODING="utf-8")
    native = subprocess.run(
        [sys.executable, str(NATIVE_AUDIT)],
        cwd=ROOT,
        check=False,
        text=True,
        encoding="utf-8",
        errors="replace",
        capture_output=True,
        env=env,
    )
    if native.returncode:
        return (
            ["native Android audit failed:\n" + native.stdout + native.stderr],
            "",
        )
    return [], (native.stdout or "").strip()


def main() -> int:
    errors, template_key_count = catalog_errors()
    sources = dart_sources()

    for violation in turkish_literal_violations(sources):
        errors.append(f"hardcoded TR literal: {violation}")
    for violation in ui_prose_violations(sources):
        errors.append(f"hardcoded UI prose: {violation}")

    native_failures, native_summary = native_errors()
    errors.extend(native_failures)

    if errors:
        print(f"FAIL ({len(errors)}):")
        for error in errors:
            print(f"  - {error}")
        return 1

    print(
        f"OK: {template_key_count} Flutter keys across "
        f"{'/'.join(locale.upper() for locale in LOCALES)} with matching "
        "placeholders; no hardcoded user-facing literal; " + native_summary
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
