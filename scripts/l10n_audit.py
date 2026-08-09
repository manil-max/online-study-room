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
from functools import lru_cache
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

# Kullanıcıya görünen widget yuvaları. Prose taraması **yalnız** burada çalışır:
# tüm literal'lere bakmak teknik sabitler yüzünden kullanılamaz bir gürültü
# üretiyor (rota adları, pref anahtarları, SQL, asset yolları…).
#
# 🔴 WP-623: burası eskiden `UI_SLOT + "'(...)'"` biçiminde tek bir regex'ti,
# yani literal'in yuvanın **hemen ardında** gelmesini şart koşuyordu. Gerçek
# kod öyle yazılmıyor:
#
#     Text(isMe ? '$name (sen)' : name)
#
# Literal ternary'nin içinde, yuvadan sonra bir ifade var; regex hiç eşleşmedi
# ve kapı "gömülü kullanıcı metni yok" diyerek YEŞİL verdi. İngilizce arayüzde
# "Ali (sen)" ve "3 ders" yazıyordu (DENETIM-istatistik R7). Bu, kapının
# ölçtüğünü sandığı şeyi ölçmediği bir vakaydı — üç bulguyu tek tek düzeltmek
# dördüncüsünü engellemez, o yüzden **tarama** düzeltildi.
#
# Yuva artık bir "açılış" işaretidir; literal'i `slot_literals()` yürüyüşü
# bulur (aşağıya bakın).
UI_SLOT_RE = re.compile(
    r"(?:Text|SelectableText|Tooltip)\(\s*"
    r"|(?:title|subtitle|label|labelText|hintText|helperText|errorText|tooltip"
    r"|content|semanticsLabel|message|dialogTitle|confirmLabel)\s*:\s*"
)

# "Cümle gibi duruyor": harfle başlıyor ve içinde boşluk var.
#
# WP-477: eskiden **büyük** harf şartı vardı ve `Text('hedef serisi')` gibi
# küçük harfle başlayan etiketler denetimin tamamen dışında kalıyordu. Küçük
# harf serbest bırakılınca teknik sabitleri `TECHNICAL_RE` eliyor (camelCase,
# snake_case, URL); ölçüm: gevşetme yalnız 4 yeni bulgu üretti, gürültü değil.
PROSE_RE = re.compile(r"^[A-Za-zÇĞİÖŞÜçğıöşü][^\n]*\s")

# Dart string interpolasyonu: `${ifade}` ya da `$tanımlayıcı`.
INTERPOLATION_RE = re.compile(r"\$\{[^{}]*\}|\$[A-Za-z_]\w*")

# "Çevrilecek sözcük": en az iki harf. Tek harf (`d`, `s`) birim kısaltması,
# rakam/emoji/ayıraç ise zaten dilden bağımsızdır.
WORD_RE = re.compile(r"[A-Za-zÇĞİÖŞÜçğıöşü]{2,}")

# WP-477: veri katmanında kullanıcıya dönen metin yuvaları. Widget yuvası yok;
# metin `throw XException('…')`, `return '…'` ya da `=> '…'` ile çıkar.
# `throw StateError(...)` / `FormatException` gibi geliştirici invariantları
# bilinçli olarak dışarıda: bu projede yalnız adı `Exception` ile biten **alan**
# tipleri (`NudgeException`, `GroupException` …) kullanıcı yüzeyine taşınır;
# `FormatException` wire ayrıştırma hatasıdır ve arayüzde gösterilmez.
#
# WP-623: bu yuva da aynı bitişiklik körlüğünü taşıyordu
# (`return cond ? '…' : '…'`, `=> x ?? '…'`, bitişik parça birleştirme). Artık
# UI yuvasıyla aynı yürüyüşü kullanır.
DATA_SLOT_RE = re.compile(
    r"throw\s+(?:const\s+)?(?!FormatException\b)\w*Exception(?:\.\w+)?\(\s*"
    r"|return\s+|=>\s*"
)
DATA_LAYER_PREFIXES = ("app/lib/data/", "app/lib/core/")

# `String toString()` gövdesi Dart'ın **geliştirici** temsilidir; hata ayıklama
# günlüğüne ve `print`e gider, kullanıcı arayüzüne değil. Yürüyüş bu gövdeleri
# atlar. Bu, dosya bazlı bir muafiyetten kasten daha dar: `nudge_repository.dart`
# yalnız `toString()`i yüzünden muaf tutulsaydı dosyanın **tamamı** taramadan
# çıkardı ve yarın oraya yazılacak gerçek kullanıcı metni de görünmezdi.
TO_STRING_RE = re.compile(r"\bString\s+toString\(\s*\)\s*")
# Teknik sabit kalıpları — çeviri gerektirmez.
TECHNICAL_RE = re.compile(
    r"://"  # URL
    r"|^[a-z0-9_.]+$"  # snake/dotted id
    r"|^[A-Z0-9_]+$"  # SCREAMING_CASE sabit
    # 🔴 WP-500: burada `^\$` yazıyordu ve niyeti "tamamı interpolasyon" idi,
    # ama `^` yalnız **başlangıcı** kontrol eder. Sonuç: `$` ile başlayan her
    # literal muaf sayılıyordu — `'${active.length} aktif'` gibi bir cümle
    # kapıdan görünmeden geçti (V58-N04 / rapor T11: İngilizce arayüzde
    # "2 aktif"). Desen artık literalin **tamamının** interpolasyon olmasını
    # şart koşuyor; `${a}${b}` gibi bitişik interpolasyonlar da geçerli.
    r"|^(?:\$\{[^{}]*\}|\$[A-Za-z_]\w*)+$"  # tamamı interpolasyon
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
    # WP-623: prose 24 → 26. Yeni metin eklenmedi; kayıt onayı mesajı bitişik
    # üç parçadan oluşuyor (`:269-271`) ve eski desen yalnız ilkini görüyordu.
    "app/lib/data/repositories/supabase/supabase_auth_repository.dart": (
        25,
        26,
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
    # WP-500: prose sayısı 10 → 11. Yeni bir metin eklenmedi; kapının kör
    # noktası kapanınca `:77` `'$userMessage\nDetay: $detail'` ilk kez göründü
    # ("Detay" gömülü Türkçe). Sayı borcun **gerçek** büyüklüğüne çekildi.
    # WP-623: 11 → 12. Yine yeni metin yok; yuva yürüyüşü `throw`un ilk
    # literal'inden sonra devam ettiği için `'Geri bildirim gönderilemedi.'`
    # (`:92`, ternary'nin son dalı) ilk kez göründü.
    "app/lib/data/repositories/admin_repository.dart": (10, 12, _ADMIN_DEBT),
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
    "app/lib/core/config/build_configuration_error_app.dart": (
        "WP-594: yapılandırma hata yüzeyi TR+EN metni **bilerek** gömülü "
        "taşır. Bu ekran derlemenin bozuk olduğu durumda çalışır; katalog ve "
        "delegate zincirinin sağlam olduğunu varsayamaz (`Localizations` "
        "çözülemezse alt ağaç boş kutuya döner). Ayrıca kendi `MaterialApp`'i "
        "olduğu için `resolvePreferredAppLocale` sözleşmesinin dışında "
        "kalıyordu ve Türkçe Windows'ta ekran İngilizce çıkıyordu (ölçüldü). "
        "Dil seçimi yapılmaz, iki dil birden basılır."
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
    # WP-582: `alarm_providers.dart` muafiyeti SILINDI. WP-576 ölü dünya
    # saati sağlayıcısını kaldırınca koruduğu literaller de gitti; muafiyet
    # dosyanın tamamını taramadan çıkarmaya devam ediyordu. Aşağıdaki
    # `stale_exemptions` kontrolü bu çürümeyi bir daha sessiz bırakmaz.
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

# (4) WP-500: prose taramasının **UI borç sicili** — dosya → (bulgu sayısı,
# gerekçe).
#
# 🔴 Neden blanket muafiyet değil: `UI_PROSE_EXEMPTIONS` dosyanın tamamını
# taramadan çıkarır ve yarın o dosyaya eklenen gerçek Türkçe metni de gizler.
# WP-477'nin `INTERNAL_PREFIXES` dersi tam buydu. Sicil `DATA_LAYER_DEBT` ile
# aynı cırcırı kullanır: sayı **artarsa** kapı kırmızı (yeni gömülü metin
# yasak), **azalırsa** da kırmızı (kazanımı sayıyı düşürerek kilitle).
#
# ⚠️ Bu WP kapının kendisini düzeltti; çıkan bulguların **tamamını çevirmek**
# kartın kapsamı dışıdır (kart: "kapı düzelince çıkacak bulgular ayrı WP").
# Gerçek çeviri borcu WP-504'e yazıldı.
# WP-504: sicil **beşten bire** indi. Dört dosya borcunu ödedi ve satırları
# tamamen silindi — sayıyı 0'a çekmek yetmezdi, çünkü sicilde adı geçen dosya
# `ui_prose_violations` taramasından tümüyle **çıkarılıyor**; 0 yazmak o
# dosyaya yarın eklenecek gerçek Türkçe metni de görünmez yapardı.
UI_PROSE_DEBT: dict[str, tuple[int, str]] = {
    "app/lib/features/desktop/desktop_home_shell.dart": (
        2,
        "Klavye kısayolu ipuçları `(Ctrl+,)` ve `(Ctrl+Shift+P)` — tuş adları "
        "platform sabiti, çevrilmez; çevrilebilir kısım zaten katalogdan "
        "geliyor. Kardeş dosya `desktop_navigation_pane.dart` aynı gerekçeyle "
        "zaten muaf; burada dosyanın geri kalanı taranmaya devam etsin diye "
        "muafiyet değil sicil kullanıldı. "
        "🔴 WP-623: sayı 1 → 2. İkinci bir ipucu EKLENMEDİ — gerekçe zaten "
        "`(Ctrl+,)`yi anlatıyordu ama eski bitişiklik deseni ternary içindeki "
        "o satırı (`:238`) hiç görmemiş, 1 sayısı yalnız `:257`yi sayıyormuş. "
        "Sayı borcun gerçek büyüklüğüne çekildi. 2'de kilitli: üçüncü bir "
        "gömülü metin eklenirse kapı düşer.",
    ),
}


def catalog(path: Path) -> dict[str, object]:
    return json.loads(path.read_text(encoding="utf-8"))


def source_keys(data: dict[str, object]) -> set[str]:
    return {key for key in data if not key.startswith("@")}


def strip_comments(source: str) -> str:
    return LINE_COMMENT_RE.sub("", BLOCK_COMMENT_RE.sub("", source))


# --------------------------------------------------------------------------
# WP-623: gerçek bir Dart string tarayıcısı.
#
# Eski `STRING_RE` düz bir regex'ti ve aynı tırnağı taşıyan interpolasyonda
# literal'i parçalara bölüyordu:
#
#     "$h:${m.toString().padLeft(2, '0')}"   ->   üç ayrı sahte "literal"
#
# `looks_like_prose` bunu fark edip `'${' in outside` dalıyla **hüküm vermeyi
# bırakıyordu** (dosyanın kendi notu: "doğru çözüm gerçek bir Dart lexer'ı
# olurdu, o da bu kapının kapsamı değil"). Yuva yürüyüşü literal sınırlarının
# doğru olmasını şart koştuğu için o lexer artık burada. Ölçüldü: TR literal
# taramasının sonucu **değişmedi** (0 ihlal, tüm sicil sayıları aynı), yani
# tarayıcı bir davranış değişikliği değil, doğruluk düzeltmesi.


def _scan_string(source: str, i: int) -> int | None:
    """`i` bir string açılışına bakıyorsa kapanışın bir sonrasını döndürür."""
    n = len(source)
    raw = source[i] == "r"
    if raw:
        i += 1
    quote = source[i]
    quote_len = 3 if source[i : i + 3] == quote * 3 else 1
    close = quote * quote_len
    i += quote_len
    while i < n:
        char = source[i]
        if char == "\\" and not raw:
            i += 2
            continue
        # Tek tırnaklı Dart string'i satır atlayamaz. Bu kural aynı zamanda
        # `strip_comments`in bozduğu satırlara karşı sigortadır: `'https://x'`
        # yorum ayıklayıcı tarafından `'https:` hâline getirilirse tarayıcı
        # dosyanın geri kalanını string sanıp yutmaz, açılışı reddeder.
        if char == "\n" and quote_len == 1:
            return None
        if source[i : i + quote_len] == close:
            return i + quote_len
        if char == "$" and not raw and source[i + 1 : i + 2] == "{":
            nested = _scan_interpolation(source, i + 1)
            if nested is None:
                return None
            i = nested
            continue
        i += 1
    return None


def _scan_interpolation(source: str, i: int) -> int | None:
    """`i` `{` üzerindeyken eşleşen `}`nin bir sonrasını döndürür."""
    n = len(source)
    depth = 0
    while i < n:
        char = source[i]
        if char in "'\"" or (
            char == "r" and source[i + 1 : i + 2] in ("'", '"')
        ):
            nested = _scan_string(source, i)
            if nested is None:
                return None
            i = nested
            continue
        if char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return i + 1
        i += 1
    return None


@lru_cache(maxsize=None)
def dart_strings(source: str) -> tuple[tuple[int, int, str], ...]:
    """Kaynaktaki string literal'leri: (başlangıç, bitiş, tırnaksız içerik)."""
    found: list[tuple[int, int, str]] = []
    n = len(source)
    i = 0
    while i < n:
        char = source[i]
        starts_string = char in "'\"" or (
            char == "r"
            and source[i + 1 : i + 2] in ("'", '"')
            and (i == 0 or not (source[i - 1].isalnum() or source[i - 1] == "_"))
        )
        if starts_string:
            end = _scan_string(source, i)
            if end is not None:
                quote_at = i + 1 if char == "r" else i
                quote = source[quote_at]
                quote_len = 3 if source[quote_at : quote_at + 3] == quote * 3 else 1
                found.append(
                    (i, end, source[quote_at + quote_len : end - quote_len])
                )
                i = end
                continue
        i += 1
    return tuple(found)


@lru_cache(maxsize=None)
def mask_strings(source: str) -> str:
    """String içerikleri `\\0` ile silinmiş kaynak — parantez derinliği için.

    🔴 Maskeleme boşlukla YAPILMAZ. Boşlukla maskelenirse yuva desenindeki
    `\\s*` literal'in **üzerinden atlar** ve yürüyüş literal'i hiç görmez
    (ölçüldü: veri katmanı bulguları 183'ten 1'e düşüyordu). Satır sonları
    korunur, böylece uzunluk ve satır numaraları kaynakla birebir kalır.
    """
    buffer = list(source)
    for start, end, _ in dart_strings(source):
        for index in range(start, end):
            if buffer[index] != "\n":
                buffer[index] = "\0"
    return "".join(buffer)


@lru_cache(maxsize=None)
def to_string_bodies(source: str) -> tuple[tuple[int, int], ...]:
    """`String toString()` gövdelerinin (başlangıç, bitiş) aralıkları."""
    masked = mask_strings(source)
    ranges: list[tuple[int, int]] = []
    for match in TO_STRING_RE.finditer(masked):
        i = match.end()
        if masked[i : i + 2] == "=>":
            end = masked.find(";", i)
            ranges.append((match.start(), len(masked) if end < 0 else end))
        elif masked[i : i + 1] == "{":
            depth = 0
            while i < len(masked):
                if masked[i] == "{":
                    depth += 1
                elif masked[i] == "}":
                    depth -= 1
                    if depth == 0:
                        break
                i += 1
            ranges.append((match.start(), i))
    return tuple(ranges)


OPEN_BRACKETS = "([{"
CLOSE_BRACKETS = ")]}"


def slot_literals(source: str, slot_re: re.Pattern[str]) -> list[tuple[int, str]]:
    """Bir yuvanın **değer konumunda** duran literal'ler.

    Yuvadan başlayarak argümanın kendisi yürünür ve parantez derinliği tutulur.
    Bir literal yalnız **derinlik 0**'da sayılır; yani argümanın kendi değeri
    (ternary dalları, `??` yedeği, bitişik parça birleştirme) sayılır, iç içe
    bir çağrının argümanı sayılmaz. Yürüyüş derinlik 0'daki `,` / `;` ile ya da
    kapsayan parantez kapanınca biter.

    🔴 Derinlik kuralı gürültü kalkanıdır, gevşetme değil:
    `Text(DateFormat('d MMMM').format(now))` içindeki `'d MMMM'` bir biçim
    deseni, cümle değil — derinlik 1'de kaldığı için sessiz kalır. Kural
    kalkarsa kapı biçim desenleri, sınıflandırıcı anahtarlar ve asset adlarıyla
    dolar; bu depoda kapıyı kullanılamaz yapmak onu gevşetmenin ilk adımıdır.
    """
    masked = mask_strings(source)
    literals = {start: (end, text) for start, end, text in dart_strings(source)}
    skip = to_string_bodies(source)
    hits: list[tuple[int, str]] = []
    seen: set[int] = set()
    for match in slot_re.finditer(masked):
        if any(start <= match.start() < end for start, end in skip):
            continue
        i = match.end()
        depth = 0
        while i < len(masked):
            if i in literals:
                end, text = literals[i]
                if depth == 0 and i not in seen:
                    seen.add(i)
                    hits.append((i, text))
                i = end
                continue
            char = masked[i]
            if char in OPEN_BRACKETS:
                depth += 1
            elif char in CLOSE_BRACKETS:
                depth -= 1
                if depth < 0:
                    break
            elif char in ",;" and depth == 0:
                break
            i += 1
    hits.sort()
    return hits


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
    for start, _, literal in dart_strings(source):
        if TURKISH_CHAR_RE.search(literal):
            hits.append((line_of(source, start), literal))
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
    return [
        (line_of(source, position), literal)
        for position, literal in slot_literals(source, DATA_SLOT_RE)
        if looks_like_prose(literal)
    ]


def ui_prose(source: str) -> list[tuple[int, str]]:
    """Kullanıcıya görünen widget yuvasının değer konumundaki cümleler."""
    return [
        (line_of(source, position), literal)
        for position, literal in slot_literals(source, UI_SLOT_RE)
        if looks_like_prose(literal)
    ]


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


def ui_prose_debt_drift(sources: list[tuple[str, str]]) -> tuple[list[str], int]:
    """UI prose sicilindeki dosyaların sayımı sabit mi? (aynı cırcır)"""
    errors: list[str] = []
    by_path = dict(sources)
    total = 0
    for relative, (expected, _) in sorted(UI_PROSE_DEBT.items()):
        source = by_path.get(relative)
        if source is None:
            errors.append(
                f"UI prose debt register points at a missing file: {relative}"
            )
            continue
        actual = len(ui_prose(source))
        total += actual
        if actual > expected:
            errors.append(
                f"{relative}: UI prose debt grew {expected} -> {actual}; "
                "new user-facing literals are not allowed in this file"
            )
        elif actual < expected:
            errors.append(
                f"{relative}: UI prose debt shrank {expected} -> {actual}; "
                "lower the number in UI_PROSE_DEBT to lock the gain"
            )
    return errors, total


def looks_like_prose(text: str) -> bool:
    stripped = text.strip()
    if len(stripped) < 4 or TECHNICAL_RE.search(stripped):
        return False
    # 🔴 WP-500 ikinci kör nokta. `TECHNICAL_RE`nin `^\$` muafiyeti
    # düzeltildikten sonra bile `'${active.length} aktif'` görünmedi, çünkü
    # `PROSE_RE` literalin **harfle başlamasını** şart koşuyor ve bu literal
    # `$` ile başlıyor. Yani "değişkenle başlayan cümle" iki kuralın kesişimine
    # düşüp tamamen denetim dışı kalıyordu.
    #
    # Çözüm: interpolasyonlar prose sınamasından **önce** tek harfli bir
    # sözcüğe indirgenir. Böylece `'${n} aktif'` → `X aktif` (harfle başlar,
    # boşluk içerir → cümle) olurken `'${path}/foo.png'` → `X/foo.png`
    # (boşluk yok → teknik) ayrımı korunur.
    #
    # ⚠️ Tek başına bu gevşetme **52 bulgu** açıyordu ve büyük çoğunluğu gerçek
    # hata değildi: `'${l10n.x} · ${y}'`, `'${formatHuman(a)} / ${b}'` gibi
    # literaller zaten çevrilmiş parçaları ayıraçla birleştiriyor. Ölçüldü:
    # 52 bulgunun 44'ü bu sınıftaydı. Kapıyı gürültüyle kırmızıya boğmak
    # yerine kural keskinleştirildi — interpolasyonlu bir literalde çeviri
    # gerektiren şey, ifadelerin **arasında kalan** metindir. Dışarıda en az
    # iki harflik bir sözcük yoksa (yalnız ` · `, ` / `, `: `, `+`, emoji,
    # rakam) çevrilecek bir şey de yoktur.
    if INTERPOLATION_RE.search(stripped):
        outside = INTERPOLATION_RE.sub(" ", stripped)
        # Literal, interpolasyonun **içinde aynı tırnağı** taşıdığı için
        # taramada kırpılmış olabilir: `'${h.padLeft(2, '0')}:00'` düz bir
        # regex'le `'${h.padLeft(2, '` olarak yakalanır. Kırık parçadan hüküm
        # verilmez — doğru çözüm gerçek bir Dart lexer'ı olurdu, o da bu
        # kapının kapsamı değil. Ölçüldü: bu duruma düşen tek yer
        # `week_hour_heatmap.dart:89`.
        if "${" in outside:
            return False
        if not WORD_RE.search(outside):
            return False
    return bool(PROSE_RE.match(INTERPOLATION_RE.sub("X", stripped)))


def ui_prose_violations(sources: list[tuple[str, str]]) -> list[str]:
    """Kullanıcı yuvasına doğrudan yazılmış cümleler (dil ne olursa olsun).

    Türkçe taramanın kaçırdığı iki sınıfı yakalar: (a) Türkçe'ye özel karakter
    içermeyen Türkçe cümleler, (b) gömülü İngilizce cümleler.
    """
    violations: list[str] = []
    for relative, source in sources:
        if (
            relative in UI_PROSE_EXEMPTIONS
            or relative in DATA_LAYER_DEBT
            or relative in UI_PROSE_DEBT
        ):
            continue
        for line, literal in ui_prose(source):
            violations.append(f"{relative}:{line}: {literal!r}")
    return violations


def stale_exemptions(sources: list[tuple[str, str]]) -> list[str]:
    """Hâlâ bir şey koruyan muafiyetler mi, yoksa çürümüş kayıtlar mı?

    🔴 WP-582 — sebep ölçüldü. WP-576 ölü dünya saati sağlayıcısını silince
    `UI_PROSE_EXEMPTIONS` içindeki "Varsayılan dünya saati şehir adı" muafiyeti
    bayatladı: koruduğu literal artık yok, ama muafiyet duruyor ve
    `alarm_providers.dart`ın **tamamını** taramadan çıkarıyordu. Yarın o dosyaya
    yazılacak gerçek bir Türkçe cümle sessizce geçerdi.

    Bu, dosyanın kendi uyarısının gerçekleşmesiydi: "blanket muafiyet dosyanın
    tamamını taramadan çıkarır ve yarın eklenen gerçek metni de gizler."

    Kural: bir muafiyet ancak GERÇEKTEN bir bulgu bastırıyorsa meşrudur. Dosya
    yoksa ya da muaf tutulmasaydı hiçbir bulgu üretmeyecekse, kayıt ölüdür ve
    silinmelidir. Muafiyeti daraltmak değil, gereksizini kaldırmak.
    """
    errors: list[str] = []
    by_path = dict(sources)
    for relative in sorted(UI_PROSE_EXEMPTIONS):
        source = by_path.get(relative)
        if source is None:
            errors.append(
                f"stale UI_PROSE_EXEMPTIONS entry: {relative} artık yok. "
                "Var olmayan dosya için muafiyet tutmak, listeyi okuyanı "
                "yanıltır."
            )
            continue
        if not ui_prose(source):
            errors.append(
                f"stale UI_PROSE_EXEMPTIONS entry: {relative} artık hiçbir "
                "bulgu üretmiyor, yani muafiyet bir şey korumuyor — ama "
                "dosyanın TAMAMINI taramadan çıkarmaya devam ediyor. Kaydı sil."
            )
    return errors


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


SELF_TEST_PROBE = DART_ROOT / "features" / "_l10n_gate_probe.dart"
SELF_TEST_DATA_PROBE = DART_ROOT / "data" / "_l10n_gate_probe.dart"

# 🔴 WP-500 kabul md. 2: "kasten eklenen kırık girdi kapıyı düşürüyor".
# Bu tek seferlik elle denenmez — kapı kendini her koşumda sınar
# (`backend_contract_audit.py --self-test` ile aynı desen).
#
# Altı prob, kapının **altı ayrı** kör noktasına karşılık gelir:
#   1. `$` ile başlayan gömülü cümle — WP-500'ün asıl hatası;
#   2. Türkçe'ye özgü karakter içermeyen düz gömülü cümle;
#   3. interpolasyon **arasında** kalan gömülü sözcük;
#   4. ternary'nin **ilk** dalındaki cümle — WP-623 (`Text(isMe ? '…' : x)`);
#   5. ternary'nin **son** dalındaki cümle — aynı körlük, diğer taraf;
#   6. `??` yedeğindeki cümle.
# 4-6 eski desenin hiç göremediği biçimdir: literal yuvanın hemen ardında değil,
# arada bir ifade var. Kapı YEŞİL diyordu, İngilizce arayüzde Türkçe metin
# çıkıyordu.
#
# Ayrıca **geçmemesi gereken** iki satır var; kapıyı gürültüye boğmak onu
# gevşetmenin ilk adımıdır:
#   (a) yalnız ayıraç birleştiren literal;
#   (b) iç içe bir çağrının argümanı olan biçim deseni (`DateFormat('d MMMM')`)
#       — yürüyüşün derinlik kuralı bunu sessiz tutmalı.
SELF_TEST_SOURCE = """// GECICI KAPI PROBU — l10n_audit.py --self-test tarafindan yazilir ve hemen
// silinir. Repoda kalici olarak bulunmamalidir.
import 'package:flutter/material.dart';

class L10nGateProbe extends StatelessWidget {
  const L10nGateProbe({super.key, required this.count, required this.label});

  final int count;
  final String label;

  // 🔴 Ternary dallarinda `label` DEGIL `who` kullanilir. `cond ? label : '…'`
  // yazilirsa `label :` parcasi yuva listesindeki `label:` adli argumana
  // benziyor ve literal ESKI desenle de yakalaniyordu; prob o zaman
  // genisletmeyi degil bir rastlantiyi sinamis olurdu.
  String get who => label;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text('$count gate_probe_leading'),
      const Text('gate probe plain sentence'),
      Text('$label gate_probe_between $count'),
      Text(count > 0 ? 'gate probe ternary left' : who),
      Text(count > 0 ? who : 'gate probe ternary right'),
      Text(who ?? 'gate probe fallback branch'),
      // Bu satir kapiyi DUSURMEMELI: disarida yalniz ayirac var.
      Text('$label · $count'),
      // Bu satir da DUSURMEMELI: bicim deseni, ic ice cagrinin argumani.
      Text(DateFormat('d MMMM').format(DateTime.now())),
    ],
  );
}
"""

# Veri katmani probu: ayni bitisiklik korlugu `return`/`throw` yuvasinda da
# vardi. Ayrica `toString()` govdesi GELISTIRICI yuzeyidir — kapinin onu
# yakalamamasi gerekir, yoksa her `toString()` yanlis pozitif uretir.
SELF_TEST_DATA_SOURCE = """// GECICI KAPI PROBU — l10n_audit.py --self-test tarafindan yazilir ve hemen
// silinir. Repoda kalici olarak bulunmamalidir.

class GateProbeException implements Exception {
  const GateProbeException(this.code);

  final String code;

  // Bu satir kapiyi DUSURMEMELI: toString() hata ayiklama temsilidir.
  @override
  String toString() => 'GateProbeException($code) gate probe debug only';
}

String gateProbeMessage(int count, String detail) {
  if (count < 0) {
    throw GateProbeException(
      count == -1 ? 'gate probe throw ternary' : detail,
    );
  }
  return count > 1 ? 'gate probe data ternary' : detail;
}
"""


def self_test() -> int:
    """Kapının kırmızıya döndüğünü kanıtlar."""
    # 🔴 Prob DISKE YAZILMAZ. Onceki sürüm `app/lib/features/` altina gecici
    # bir dosya yazip siliyordu; `test_all.py` ayni tier'i paralel kosturdugu
    # icin `contract`/`l10n` kapilari o dosyayi yakalayip ya FileNotFoundError
    # ile cokuyor ya da bilerek bozuk probu gercek kaynak sanip yanlis kirmizi
    # uretiyordu. Prob artik ayni giris noktasina bellekten verilir; paylasilan
    # agac hic degismez.
    for path in (SELF_TEST_PROBE, SELF_TEST_DATA_PROBE):
        if path.exists():
            print(f"FAIL: gecici kapi probu repoda kalmis: {path}")
            return 1
    sources = dart_sources()
    probes = [
        (
            SELF_TEST_PROBE.relative_to(ROOT).as_posix(),
            strip_comments(SELF_TEST_SOURCE),
        ),
        (
            SELF_TEST_DATA_PROBE.relative_to(ROOT).as_posix(),
            strip_comments(SELF_TEST_DATA_SOURCE),
        ),
    ]

    def scan(all_sources: list[tuple[str, str]]) -> set[str]:
        return set(ui_prose_violations(all_sources)) | set(
            data_layer_violations(all_sources)
        )

    baseline = scan(sources)
    new = scan(sources + probes) - baseline

    # Yakalanması ŞART olanlar — her biri kapının bir kör noktası.
    expected = (
        "gate_probe_leading",
        "gate probe plain sentence",
        "gate_probe_between",
        "gate probe ternary left",
        "gate probe ternary right",
        "gate probe fallback branch",
        "gate probe throw ternary",
        "gate probe data ternary",
    )
    caught = {token: any(token in item for item in new) for token in expected}

    # Yanlış pozitif kontrolü — bunlar SESSİZ kalmalı. Kapıyı gürültüye
    # boğmak, sonraki turda onu gevşetmenin gerekçesi olur.
    silent = {
        "ayıraç birleştiren literal": [item for item in new if "·" in item],
        "iç içe çağrının biçim deseni": [
            item for item in new if "d MMMM" in item
        ],
        "toString() hata ayıklama çıktısı": [
            item for item in new if "gate probe debug only" in item
        ],
    }

    print("self-test — kapı probu:")
    for token, hit in caught.items():
        print(f"  {'yakalandı' if hit else 'KAÇIRILDI'}: {token}")
    for label, noise in silent.items():
        print(f"  {'temiz' if not noise else 'GURULTU'}: {label}")

    noisy = any(silent.values())
    if not all(caught.values()) or noisy:
        print("FAIL: kapı ya probu kaçırdı ya da gürültü üretti.")
        for item in sorted(new):
            print(f"    - {item}")
        return 1
    print(
        f"OK: kapı {len(expected)} probu da reddetti, gürültü üretmedi "
        f"({len(new)} bulgu)."
    )
    return 0


def main() -> int:
    if "--self-test" in sys.argv[1:]:
        return self_test()

    errors, template_key_count = catalog_errors()
    sources = dart_sources()

    for violation in turkish_literal_violations(sources):
        errors.append(f"hardcoded TR literal: {violation}")
    for violation in ui_prose_violations(sources):
        errors.append(f"hardcoded UI prose: {violation}")
    for violation in data_layer_violations(sources):
        errors.append(f"hardcoded data-layer message: {violation}")
    errors.extend(stale_exemptions(sources))

    drift_errors, debt_total = debt_drift(sources)
    errors.extend(drift_errors)
    ui_drift_errors, ui_debt_total = ui_prose_debt_drift(sources)
    errors.extend(ui_drift_errors)

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
    print(
        f"UI prose debt: {ui_debt_total} literals still embedded in "
        f"{len(UI_PROSE_DEBT)} files (locked at these counts; see "
        "UI_PROSE_DEBT)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
