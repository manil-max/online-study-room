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

# "Cümle gibi duruyor": harfle başlıyor ve içinde boşluk var.
#
# WP-477: eskiden **büyük** harf şartı vardı ve `Text('hedef serisi')` gibi
# küçük harfle başlayan etiketler denetimin tamamen dışında kalıyordu. Küçük
# harf serbest bırakılınca teknik sabitleri `TECHNICAL_RE` eliyor (camelCase,
# snake_case, URL); ölçüm: gevşetme yalnız 4 yeni bulgu üretti, gürültü değil.
PROSE_RE = re.compile(r"^[A-Za-zÇĞİÖŞÜçğıöşü][^\n]*\s")

# WP-477: veri katmanında kullanıcıya dönen metin yuvaları. Widget yuvası yok;
# metin `throw XException('…')`, `return '…'` ya da `=> '…'` ile çıkar.
# `throw StateError(...)` / `FormatException` gibi geliştirici invariantları
# bilinçli olarak dışarıda: bu projede yalnız adı `Exception` ile biten **alan**
# tipleri (`NudgeException`, `GroupException` …) kullanıcı yüzeyine taşınır;
# `FormatException` wire ayrıştırma hatasıdır ve arayüzde gösterilmez.
DATA_SLOT = (
    r"(?:throw\s+(?:const\s+)?(?!FormatException\b)\w*Exception(?:\.\w+)?\(\s*"
    r"|return\s+|=>\s*)"
)
DATA_LITERAL_RE = re.compile(
    DATA_SLOT + r"'((?:\\.|[^'\\])*)'|" + DATA_SLOT + r'"((?:\\.|[^"\\])*)"',
    re.DOTALL,
)
DATA_LAYER_PREFIXES = ("app/lib/data/", "app/lib/core/")
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

# (1) WP-477: veri katmanı borç sicili — dosya → (TR literal sayısı,
# veri-katmanı prose sayısı, gerekçe).
#
# 🔴 Buradaki eski satır `INTERNAL_PREFIXES = ("app/lib/data/repositories/",)`
# idi ve **tüm** repository katmanını her iki taramadan da muaf tutuyordu.
# Gerekçesi "repository yalnız sınıflandırıcı kod döndürür, sunum katmanı
# çevirir" idi — ama kod öyle yazılmamıştı: repository'ler hazır Türkçe cümle
# döndürüyordu ve İngilizce arayüzde Türkçe hata çıkıyordu (V57-N01/N08).
# Muafiyet, kapatması gereken hatayı görünmez kılıyordu.
#
# Blanket muafiyetin yerine **sayım kilidi** kondu: listedeki dosya kapıyı
# kırmızıya düşürmez, fakat sayısı değişirse düşürür. Yani bu dosyalara yeni
# gömülü metin eklenemez ve borç azaldığında sayıyı düşürmek zorunludur.
# Sayılar `main()` çıktısında toplam borç olarak **raporlanır**.
_ADMIN_DEBT = (
    "Yönetici/moderasyon yüzeyinin hata metinleri hâlâ repository sabitleri. "
    "Bu bölge fazın en yoğun l10n boşluğudur ve WP-486 kapsamında sırayla "
    "çevrilecek; WP-477 yalnız dürtme yüzeyini taşıdı (28 dosyaya birden "
    "dokunmanın regresyon riski faydayı aşıyor)."
)
_GROUP_DEBT = (
    "Grup oluşturma/katılma/fotoğraf doğrulama mesajları repository sabiti. "
    "İki repository (supabase + in_memory) aynı cümleleri ayrı ayrı taşıyor; "
    "kod'a çevrim tek WP'de yapılmalı, WP-477 kapsamı dışında."
)
_AUTH_DEBT = (
    "Kayıt/giriş/şifre doğrulama mesajları repository sabiti. Auth ekranı "
    "ayrıca kendi kod eşlemesini taşıyor (`auth_screen.dart` muafiyeti); "
    "ikisinin birlikte taşınması gerekir, WP-477 kapsamı dışında."
)
_SMALL_DEBT = (
    "Tekil doğrulama/hata mesajları repository sabiti; dürtme deseniyle "
    "(kod + sunum katmanı eşlemesi) taşınacak, WP-477 kapsamı dışında."
)

DATA_LAYER_DEBT: dict[str, tuple[int, int, str]] = {
    "app/lib/data/repositories/supabase/supabase_group_repository.dart": (
        29,
        31,
        _GROUP_DEBT,
    ),
    "app/lib/data/repositories/in_memory/in_memory_group_repository.dart": (
        30,
        25,
        _GROUP_DEBT,
    ),
    "app/lib/data/repositories/supabase/supabase_auth_repository.dart": (
        25,
        24,
        _AUTH_DEBT,
    ),
    "app/lib/data/repositories/in_memory/in_memory_auth_repository.dart": (
        28,
        23,
        _AUTH_DEBT,
    ),
    "app/lib/data/repositories/supabase/supabase_admin_repository.dart": (
        22,
        27,
        _ADMIN_DEBT,
    ),
    "app/lib/data/repositories/admin_repository.dart": (10, 10, _ADMIN_DEBT),
    "app/lib/data/repositories/supabase/supabase_admin_moderation_repository.dart": (
        10,
        10,
        _ADMIN_DEBT,
    ),
    "app/lib/data/repositories/in_memory/in_memory_admin_moderation_repository.dart": (
        12,
        12,
        _ADMIN_DEBT,
    ),
    "app/lib/data/repositories/in_memory/in_memory_admin_repository.dart": (
        6,
        3,
        _ADMIN_DEBT + " Ayrıca demo duyuru başlıkları burada seed ediliyor.",
    ),
    "app/lib/data/repositories/supabase/supabase_moderation_repository.dart": (
        2,
        2,
        _ADMIN_DEBT,
    ),
    "app/lib/data/repositories/in_memory/in_memory_moderation_repository.dart": (
        3,
        3,
        _ADMIN_DEBT,
    ),
    "app/lib/data/repositories/supabase/supabase_notification_repository.dart": (
        3,
        3,
        _SMALL_DEBT,
    ),
    "app/lib/data/repositories/in_memory/in_memory_notification_repository.dart": (
        3,
        0,
        _SMALL_DEBT + " Demo bildirim gövdeleri de burada seed ediliyor.",
    ),
    "app/lib/data/repositories/chat_repository.dart": (1, 2, _SMALL_DEBT),
    "app/lib/data/repositories/supabase/supabase_chat_repository.dart": (
        1,
        1,
        _SMALL_DEBT,
    ),
    "app/lib/data/repositories/in_memory/in_memory_support_repository.dart": (
        5,
        0,
        _SMALL_DEBT,
    ),
    "app/lib/data/repositories/supabase/supabase_achievement_reward_repository.dart": (
        3,
        3,
        _SMALL_DEBT,
    ),
    "app/lib/data/repositories/in_memory/in_memory_achievement_reward_repository.dart": (
        4,
        3,
        _SMALL_DEBT,
    ),
}

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
    "app/lib/core/theme/theme_presets.dart": (
        "WP-477: `'Paper & Ink'` bir tema **adıdır** (özel isim); diğer preset "
        "adları katalogdan geliyor, bu biri bilinçli olarak çevrilmiyor."
    ),
    "app/lib/core/grid/grid_reflow.dart": (
        "WP-477: `toString()` hata ayıklama çıktısı ve `StateError` döngü "
        "koruması — kullanıcı yüzeyine taşınmaz."
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
    # WP-477 üç geçici muafiyet açmıştı (`Text('hedef serisi')` /
    # `Text('grup serisi')`, PROSE_RE gevşetilince ilk kez görünmüştü).
    # WP-481 o üç rozeti `GoalStreakBadge`e çevirip metinleri kataloğa taşıdı;
    # muafiyetler bu yüzden **silindi**, geri eklenmesi regresyondur.
    "app/lib/wp295_preview.dart": (
        "Geliştirici önizleme koşumu (`wp295_preview`), üründe yönlendirilen "
        "bir rota değil; ölçüm etiketleri çevrilmez."
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


def turkish_literals(source: str) -> list[tuple[int, str]]:
    hits: list[tuple[int, str]] = []
    for match in STRING_RE.finditer(source):
        literal = match.group(0)[1:-1]
        if TURKISH_CHAR_RE.search(literal):
            hits.append((line_of(source, match.start()), literal))
    return hits


def turkish_literal_violations(sources: list[tuple[str, str]]) -> list[str]:
    violations: list[str] = []
    for relative, source in sources:
        if relative in LITERAL_EXEMPTIONS or relative in DATA_LAYER_DEBT:
            continue
        for line, literal in turkish_literals(source):
            violations.append(f"{relative}:{line}: {literal!r}")
    return violations


def data_layer_prose(source: str) -> list[tuple[int, str]]:
    """`throw XException('…')` / `return '…'` ile kullanıcıya dönen cümleler."""
    hits: list[tuple[int, str]] = []
    for match in DATA_LITERAL_RE.finditer(source):
        literal = match.group(1)
        if literal is None:
            literal = match.group(2)
        if literal is not None and looks_like_prose(literal):
            hits.append((line_of(source, match.start()), literal))
    return hits


def data_layer_violations(sources: list[tuple[str, str]]) -> list[str]:
    """WP-477: veri katmanının kullanıcıya dönen metinleri.

    Türkçe karakter taraması bu sınıfı tek başına kapatmaz: `Gecerli bir
    e-posta girin` gibi aksansız yazılmış Türkçe ve gömülü İngilizce cümleler
    orada görünmez.
    """
    violations: list[str] = []
    for relative, source in sources:
        if not relative.startswith(DATA_LAYER_PREFIXES):
            continue
        if (
            relative in LITERAL_EXEMPTIONS
            or relative in UI_PROSE_EXEMPTIONS
            or relative in DATA_LAYER_DEBT
        ):
            continue
        for line, literal in data_layer_prose(source):
            violations.append(f"{relative}:{line}: {literal!r}")
    return violations


def debt_drift(sources: list[tuple[str, str]]) -> tuple[list[str], int]:
    """Sicildeki dosyaların sayımı sabit mi? (cırcır)"""
    errors: list[str] = []
    by_path = dict(sources)
    total = 0
    for relative, (tr_expected, prose_expected, _) in sorted(
        DATA_LAYER_DEBT.items()
    ):
        source = by_path.get(relative)
        if source is None:
            errors.append(f"debt register points at a missing file: {relative}")
            continue
        tr_actual = len(turkish_literals(source))
        prose_actual = len(data_layer_prose(source))
        total += tr_actual + prose_actual
        for label, expected, actual in (
            ("TR literal", tr_expected, tr_actual),
            ("data prose", prose_expected, prose_actual),
        ):
            if actual > expected:
                errors.append(
                    f"{relative}: {label} debt grew {expected} -> {actual}; "
                    "new user-facing literals are not allowed in this file"
                )
            elif actual < expected:
                errors.append(
                    f"{relative}: {label} debt shrank {expected} -> {actual}; "
                    "lower the number in DATA_LAYER_DEBT to lock the gain"
                )
    return errors, total


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
        if relative in UI_PROSE_EXEMPTIONS or relative in DATA_LAYER_DEBT:
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
    for violation in data_layer_violations(sources):
        errors.append(f"hardcoded data-layer message: {violation}")

    drift_errors, debt_total = debt_drift(sources)
    errors.extend(drift_errors)

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
    # WP-477: kalan borç gizlenmez — kapı yeşilken bile ölçüsü basılır.
    print(
        f"data-layer debt: {debt_total} literals still embedded in "
        f"{len(DATA_LAYER_DEBT)} files (locked at these counts; see "
        "DATA_LAYER_DEBT)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
