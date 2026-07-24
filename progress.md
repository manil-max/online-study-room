# progress.md — Canlı Durum

> Son güncelleme: **2026-07-25** · Saat dilimi: **Europe/Istanbul**
>
> Bu dosya yalnız aktif iş, açık kabul ve ürün kararlarını taşır. Tamamlanmış WP'lerin ayrıntısı git geçmişi, [`docs/archive/progress-tarihsel-2026-07.md`](docs/archive/progress-tarihsel-2026-07.md) ve kanonik raporlardadır; burada tekrar edilmez.
>
> **Okuma sırası:** `⚡ Aktif Çalışma Kaydı` → `🧪 Cihaz QA Kuyruğu` (kodu bitmiş, **test** bekleyen işler) → `🛠️ Kalan Kod İşi` (**kodlanacak** işler) → yalnız kodlanmayı bekleyen WP kartları.

## Proje Gerçekleri

- **Ortam durum modeli (WP-293, 2026-07-24 uzlaştırıldı) — altı ayrı gerçek, tek sayıya indirilmez:**
  1. Repo/local migration zinciri: **`0070`** (`supabase/migrations/` son dosya).
  2. Staging uygulanmış head: **`0070`**.
  3. Production **etkin şema**: **`0070`** — `0066–0070` manuel uygulandı; Database Gates + Production Push Activation koşumları başarılı (2026-07-23).
  4. Production **CLI migration history**: **legacy / uzlaştırılmamış** — `supabase_migrations.schema_migrations` relation'ı production'da yok ([`docs/recovery/PRODUCTION-BASELINE.md`](docs/recovery/PRODUCTION-BASELINE.md) §3).
  5. Deploy contract hedef/izin head: **`0070`**; production `deploy_enabled` terfi tamamlandığı için **yeniden `false`** kilitlendi.
  6. Stable **v45** artefakt manifesti: tarihsel **`0065`** (production sonradan `0070`e yükseldi).
- **Stable/production:** v45 yayında, etkin şema `0070`. Yeni production migration, Edge deploy veya stable tag/release yalnız ayrı, somut kullanıcı GO + backup + dry-run ile yapılır; deploy kapısı kilitli.
- **Beta/staging:** beta-v4308 staging `0070` üzerinde yayında. Proje sahibi 2026-07-24'te stable+beta yayınını ve bildirim/sayaç davranışını cihazda test etti; genel sorun yok, **önceki turun** (WP-269–285) bekleyen cihaz kabulleri kapatıldı. ⚠️ Aşama A'nın yeni kabulleri **henüz yayınlanmış bir artefakta girmedi** — QA kuyruğu yeni beta build gerektiriyor.
- **Release ilkesi:** Android beta/stable artefaktı Android işi başarılı olunca yayımlanır. Windows bağımsız sürer ve başarılı olursa aynı release'e eklenir; Windows hatası Android güncellemesini geri çekmez.
- 🔴 **BETA KARARI (sahip, 2026-07-25):** **Aşama A'nın TÜM WP'leri bitmeden beta çıkmaz — tek beta turu yapılacak.** Gerekçe: beta koşumu ~3 saat sürüyor, iki tur yapılmıyor. **Sonuçları:** (1) "önce X'in cihaz kabulü" yazan yazılı kapılar bu tur için **geçersiz** — cihaz QA'sı fiziken mümkün değil, kod/test kapısı esas alınır (`.agents/AGENTS.md §0.1`); (2) QA kuyruğundaki 6 iş **aynı beta'da** test edilir; (3) bir sorun görülürse hangi WP'den geldiği belirsiz olacağı için her WP **ayrı commit** + `analyze` 0 + testler yeşil şartı **daha da kritik**.
- **Yönetim varsayılanı:** Production `deploy_enabled/release_enabled` kapalıdır. Stable yalnız protected `production` Environment, exact SHA/head/project-ref GO ve reviewer kanıtıyla ilerler.
- **Kurallar:** Kök `AGENTS.md`, `.agents/AGENTS.md` ve `docs/KALITE-PROGRAMI.md` geçerlidir. Tek çalışma dalı `main`; her WP ayrı commit; production varsayılmaz.
- **Son WP:** **297** · Sıradaki boş numara: **298**. WP-296 kapandı (759 test yeşil, 0 kırmızı). Aşama A'da kod/test tamamlanan: 286, 287, 288, 289, 290, 291, 293 — **kartları arşive taşındı** ([arşiv](docs/archive/progress-tarihsel-2026-07.md)), kalan işleri aşağıdaki QA kuyruğunda.
- **Aktif tur:** Yeni Özellik Turu **Aşama A** — plan **rev. 3** kanonik. 8 WP'nin kodu bitti (296 dahil); **kodlanmayı bekleyen 4 iş kaldı** (297, 292, 294, 295). Kanonik plan: [`docs/YENI-OZELLIK-PLANI.md`](docs/YENI-OZELLIK-PLANI.md).
- ✅ **Ortam gerçeği uzlaştırıldı (WP-293, 2026-07-24):** yukarıdaki altı gerçekli durum modeli kanoniktir; production deploy kapısı yeniden kilitlendi. `deploy-contract.json`, `KALITE-PROGRAMI.md`, `project.md`, `backlog.md`, `tooling/README.md` aynı gerçeğe getirildi.

## ⚡ Aktif Çalışma Kaydı

### Gemini Lane
- **Durum:** [x] Boşta
- **Faz/WP:** —
- **SAHİP yollar:** —

### Claude Lane
- **Durum:** [x] Boşta
- **Faz/WP:** —
- **SAHİP yollar:** —
- **Son not:** WP-296 tamam (2026-07-25) — **tam paket 759 yeşil, 0 kırmızı**. İkisi ürün hatasıydı (masaüstünde yanlış izin iddiası), biri saate bağımlı testti. Sıradaki: WP-297 (fontlar).

### Codex Lane
- **Durum:** [x] Boşta
- **Faz/WP:** —
- **SAHİP yollar:** —
- **Son not:** WP-286 ve WP-288 kod/test tamam → QA kuyruğunda.

### Codex-2 Lane
- **Durum:** [x] Boşta
- **Faz/WP:** —
- **SAHİP yollar:** —

### Grok Lane
- **Durum:** [x] Boşta
- **Faz/WP:** —
- **SAHİP yollar:** —

## 🧪 Cihaz QA Kuyruğu — kod bitti, cihaz testi bekliyor

> **Bu tablodaki işlerin kodu bitti; ajan tarafında yapılacak iş yok.** Kalan tek adım proje
> sahibinin cihazda/panelde doğrulaması. Kart ayrıntıları [arşivde](docs/archive/progress-tarihsel-2026-07.md).
> QA sırasında bulunan hata **yeni WP** olur, eski kart yeniden açılmaz.
>
> 🔴 **Beta kararı gereği bu kuyruk TEK beta turunda test edilecek** — yani `Kalan Kod İşi` bitmeden
> QA başlamıyor. Sıra: kalan 4 WP (297 → 292 → 294 → 295) → beta build → aşağıdaki 5 + 297/292 aynı turda cihazda test.
> ℹ️ **WP-296 ayrıca cihaz QA istemiyor** ama Windows yüzeyine dokundu: masaüstünde alarm eklemenin dialogsuz açılması ve izin kartının nötr görünmesi aynı turda bakılmalı.
> ⚠️ Bu yüzden bir hata görüldüğünde kaynağı belirsiz olabilir; ilk bakılacak yer o yüzeye
> dokunan **son commit**'tir (her WP ayrı commit).

| WP | Kod bitiş | Cihazda/panelde doğrulanacak | Tür |
|---|---|---|---|
| **WP-286** Ayarlar IA + Bildirim Merkezi | 2026-07-24 (Codex) | Ayarlarda bildirim/izin/rapor için tek giriş · izni sistemden kapat/aç → geri dön, özet ≤ 1 sn güncelleniyor · "Düzelt" doğru sistem ekranını açıyor · `unknown` durumda "hazır" demiyor · aylık rapor tercihi kalıcı | Android cihaz |
| **WP-287** Şifre sıfırlama | 2026-07-24 (Claude) | 🔶 **Önce sahip ops adımı:** staging Supabase panelinde Redirect URL + Site URL + recovery şablonuna `{{ .Token }}` ([runbook](docs/SIFRE-SIFIRLAMA-PANEL-RUNBOOK.md)) · sonra Android link akışı + Windows kod akışı + kayıtsız e-postada nötr mesaj. **Production paneli ayrı kapı (K-6), bu QA'nın parçası değil.** | Panel + cihaz |
| **WP-288** Tema modeli v2 + göç | 2026-07-24 (Codex) | 🔴 **Eski özel paletli gerçek cihazda** ilk açılış → **görünüm değişmemeli** (göç) · aktif tema korunuyor · silme yuvayı boşaltıyor, index kaydırmıyor · açık/koyu/sistem modu | Android cihaz (yükseltme) |
| **WP-290** Tema sihirbazı + görünüm ekranı | 2026-07-25 (Claude) | 8 adımın önizlemesi anında güncelleniyor · kaydedilen tema tüm ekranlarda geçerli · his efektleri (gren/parıltı) **gerçekten görünüyor** · AA uyarısı + Düzelt · düzenle/sil/3 yuva dolu mesajı · "hareketi azalt" · RTL (AR) | Android cihaz |
| **WP-291** Kart boyut paneli | 2026-07-24 (Claude) | Düzenleme modunda en alta kaydırınca panel ekranda kalıyor · boyut değişimi anında · sürükle-bırak/compactUp/sıfırlama bozulmamış · dokunma hedefleri ≥ 48 dp | Android cihaz |

**WP-289** (his araştırması) tamamen kapandı — doküman WP'si, QA gerektirmez.

## 🛠️ Kalan Kod İşi — ne kodlanacak

> **Beta kararı gereği bu işlerin HEPSİ bitmeden beta çıkmaz.** Sıra: hazır olan → sahip girdisi bekleyen.
> **Kalan 4 iş** (296 kapandı).

| # | İş | Kod durumu | Başlamaya hazır mı? |
|---|---|---|---|
| ~~1~~ | **WP-296** — `main`'de kırmızı 3 test | [x] **TAMAM** (2026-07-25) | ✅ Bitti — 759 yeşil / 0 kırmızı; 2 ürün hatası + 1 saate bağımlı test |
| **1** | **WP-297** — gömülü fontlar (Inter · Lora · JetBrains Mono) | [ ] **Kodlanacak** | ✅ **SIRADAKİ** — sahip onayı verildi (2026-07-25); font indirmesi onaylı |
| **2** | **WP-292** — taç görseli | [ ] **Kodlanacak** | ✅ **HAZIR** — "önce WP-290 cihaz kabulü" kapısı **beta kararıyla düştü** (§0.1); kod/test kapısı esas |
| **3** | **WP-294** — l10n borcu + audit CI kapısı | [ ] Kodlanacak | 🟡 **Kısmen** — audit genişletme + UTF-8 + CI kapısı **bugünkü 4 dil gerçeğiyle** yapılabilir; yalnız "EN/TR'ye daraltma" dalı K-7'ye bağlı |
| **4** | **WP-295** — kamp ateşi animasyonları | [ ] Kodlanacak | 🔴 **TEK GERÇEK BLOKAJ** — sahiple tasarım konuşması yapılmadan başlamaz (kartın açık şartı, aşılmaz) |
| — | WP-276 / WP-277 — staging ops kabul kanıtı | [ ] Kod azı, ops çoğu | ⏸️ Beta dışı; sentetik staging kanıtı + WP-276 Play Store için gerekli |
| — | WP-278 / WP-279 | [?] **Ürün/ops kararı** | 🔴 Sahip kararı olmadan kod yazılmaz |
| — | Production backend değişikliği | 🔴 Kapalı | `deploy_enabled: false`; yeni terfi backup + dry-run + somut GO ister |

**Beta çıkabilmesi için kalan:** ~~296~~ → **297** → 292 → 294 → 295 (295 sahiple konuşmayı bekler; diğer üçü ajan işi).

### Tema programından devreden borç — durumları

1. ✅ **ADR-4 gömülü fontlar → KARAR VERİLDİ (sahip, 2026-07-25): eklenecek. WP-297 açıldı.** 3 aile: gövde **Inter**, başlık **Lora**, saat **JetBrains Mono** (başlıkta Playfair Display alternatifi elendi — Lora her puntoda daha güvenli). Font indirmesi sahip tarafından onaylandı.
2. 🟡 **APK boyut ölçümü** — font eklendiği için artık **anlamlı** ve **WP-297'nin kabul kriteri**. Ölçüm `local` flavor + `flutter clean` ile temiz baseline üzerinden yapılır (`stable` flavor production backend'e bağlı olduğu için kullanılamaz — kartın rev.3 komutu bu yüzden koşulamıyor).
3. ⏸️ **`AppFeel.edgeIrregularity`** — his değerlerinde taşınıyor, çizilmiyor (her karta özel `ShapeBorder` gerekir). Sihirbazda kullanıcı kontrolü **yok** → ölü anahtar değil. **Sahip 2026-07-25'te "sorun değil" dedi; WP açılmadı.**
4. ⏸️ **`AppMotion` süreleri** — hâlâ hiçbir animasyon tüketmiyor (WP-288'den devraldı). Sihirbazda kullanıcı kontrolü yok → ölü anahtar değil. **Sahip 2026-07-25'te "sorun değil" dedi; WP açılmadı.**

### Sahip kararları (2026-07-25 turu)

- **Gömülü font:** ✅ evet, 3 aile · başlık fontu **Lora** · indirme onaylı → WP-297.
- **AR/RTL:** "şimdilik dert etmiyoruz" — **K-7 kararı hâlâ açık.** WP-297 yine de `fontFamilyFallback` kurar (maliyeti yok, AR sonradan kalırsa kutu karakter doğmaz).
- **Bildirim/widget'ın sistem fontunda kalması:** kabul edildi (native taraf Flutter fontuna erişemez).
- **Hazır temaların gövde fontu:** hata değil, tasarım — hazır temaların şemasında gövde ailesi yok. WP-297'de hazır temalara da gövde ailesi verilip verilmeyeceği kart içinde kararlaştırılır.
- **Tek beta:** yukarıdaki 🔴 BETA KARARI.

## Yeni Özellik Turu — Aşama A (Plan Kuyruğu)

> **Burada yalnız KODLANMAYI BEKLEYEN kartlar var** (WP-296, 295, 292, 294 — bu sırayla).
> Kod/test'i bitmiş 7 WP'nin kartı [arşivde](docs/archive/progress-tarihsel-2026-07.md); kalan işleri yukarıdaki QA kuyruğunda.

Konuşma fazı kapandı (9 tur). Kanonik belgeler:
- Konuşma kaydı: [`docs/YENI-OZELLIK-NOTLARI.md`](docs/YENI-OZELLIK-NOTLARI.md)
- **Detaylı teknik plan: [`docs/YENI-OZELLIK-PLANI.md`](docs/YENI-OZELLIK-PLANI.md)** ← WP'lerin gerekçesi, repo analizi, riskler burada

Sıra: **Aşama A (kod) → Aşama B (Play Store) → Aşama C (Microsoft Store).** Aşama B/C'nin WP'leri Aşama A kabulünden sonra açılır.

**⚠️ Plan rev. 3 (2026-07-24, senior 2. incelemesi sonrası).** rev.2 yamalarla üretildiği için kendi içinde çelişiyordu; plan **baştan yazıldı**. Başlıca düzeltmeler: WP-293 "altı ayrı ortam gerçeği + production kapısını yeniden kilitleme" olarak yeniden modellendi · tema göçü **etkin ThemeData snapshot'ına** bağlandı (açık/koyu farklı tabanlardan geliyor) · **golden baseline** WP-288'in ilk adımı oldu (projede golden test yok) · `clock_permissions.dart` WP-286 SAHİP listesine eklendi · WP-287 production paneli **ayrı kapıya** taşındı · yanlış Riverpod uyarısı kaldırıldı · ADR-8 gerekçesi düzeltildi. Tam liste: plan §9.

**Dalga modeli (aynı anda en fazla 2 lane) — kalan: 296 → 297 → 292 → 294, sonra 295:**
```
GATE 0   WP-293  Ortam/migration uzlaştırma      ✅ kod/doküman tamam
DALGA 1  WP-287  Şifre sıfırlama  ‖  WP-286  Ayarlar IA      ✅ kod/test tamam → QA
DALGA 2  WP-291  Boyut paneli ✅ → QA  ‖  WP-289  His araştırması ✅ tümüyle kapandı
DALGA 3  WP-288  Tema modeli      ✅ kod/test tamam → QA  ‖  WP-294  l10n  🟡 kısmen açık
DALGA 4  WP-290  Tema sihirbazı   ✅ kod/test tamam → QA
DALGA 5  WP-296 ✅ tamam → WP-297  Fontlar → WP-292  Taç   (SERİ, golden yüzeyi)  ← KALAN
DALGA 6  WP-294  l10n borcu  ‖  WP-295  Kamp ateşi (sahiple konuşma sonrası)
──────── TEK BETA BURADA ÇIKAR (hepsi bitince) ────────
```

> 🔴 **WP-295, sahiple tasarım konuşması yapılmadan başlamaz** — bu tur kalan **tek gerçek blokaj**.
> 🟡 **WP-294'ün K-7'ye bağlı kısmı yalnız "EN/TR'ye daraltma" dalı;** audit genişletme + UTF-8 + CI kapısı bugünkü 4 dil gerçeğiyle yapılabilir.
> ⚠️ **296 → 297 → 292 SERİ koşar** — 297 ve 292 aynı golden yüzeyine giriyor, paralel çakışır.
> ⚠️ **"Önce X'in cihaz kabulü" kapıları bu tur geçersiz** (tek beta kararı, `§0.1`) — kod/test kapısı esas.
> ⚠️ Tema programı açıkken **Saat ve Başarım programları açılmaz** (`.agents/AGENTS.md §1.2`).
> ℹ️ Kapanmış kapılar (WP-293 Gate 0, golden baseline, 288↔289 sırası) arşiv kartlarında; burada tekrarlanmaz.

### WP-297: Gömülü font aileleri (ADR-4) 🔤
- **Program/Faz:** Yeni Özellik Turu · Aşama A · Tema programı · (plan §3 F-04-B, ADR-4 — WP-290'dan devredildi)
- **Ajan:** — · **Durum:** [ ] **Kodlanacak — HAZIR** (sahip onayı 2026-07-25) · **Model önerisi:** 🟣 Pro
- **Problem:** Sihirbaz ve hazır temalar bugün yalnız **platformun genel ailelerini** kullanıyor (`sans-serif`/`serif`/`monospace` — [`theme_tokens.dart:132`](app/lib/core/theme/theme_tokens.dart:132), [`theme_draft.dart:31`](app/lib/features/profile/theme_builder/theme_draft.dart:31)). Bunlar cihaza göre değişiyor: Samsung'un "serif"i ile Xiaomi'nin "serif"i aynı değil, Windows'ta üçüncü bir şey. Kullanıcı karakteri seçmiş oluyor ama **görünümü telefon belirliyor**. Gömülü font = her cihazda aynı ve seçilen görünüm.
- **Sahip kararı:** 3 aile · gövde **Inter** · başlık **Lora** · saat/sayaç **JetBrains Mono** · font indirmesi onaylı · Playfair Display elendi.
- **Kapsam dışı:** `google_fonts` paketi (**kullanılmaz** — ağdan indirme, ADR-4), 4'ten fazla aile, native bildirim/widget tipografisi (**erişilemez**, sistem fontunda kalır — sahip kabul etti), yeni tema token'ı, AR insan çevirisi.
- **SAHİP dosyalar (yaz):** `app/assets/fonts/**` (yeni), `app/assets/fonts/LICENSES/**` (yeni), `app/pubspec.yaml` (`fonts:` bloğu), `app/lib/features/profile/theme_builder/theme_draft.dart` (`kFamilies` + aile adları), `app/lib/core/theme/theme_tokens.dart` (fallback zinciri; hazır tema gövdesi kararı), `app/lib/l10n/app_*.arb` (aile adları), golden testler + `app/test/**`.
- **DOKUNMA:** `supabase/**` · `app/lib/features/profile/theme_builder/feel_overlay.dart` · bildirim/timer kodu · `app/android/**` native.
- **Adımlar:**
  - [ ] Fontları indir: **Inter** (Regular/Bold ya da variable), **Lora** (Regular/Bold), **JetBrains Mono** (Regular). Kaynak Google Fonts resmî deposu. **Lisans metinleri (`OFL.txt` / `LICENSE-2.0.txt`) `assets/fonts/LICENSES/` altına konur** — Play Store beyanı için de gerekli.
  - [ ] 🔴 **Subset: Latin + Latin Extended-A.** Türkçe glyph'leri (`ı İ ş Ş ğ Ğ ç Ç ö Ö ü Ü`) **tek tek doğrulanır** — eksikse kutu karakter çıkar. Subset aracı repoya girmez (yalnız sonuç dosyaları).
  - [ ] 🔴 **`fontFamilyFallback` zorunlu.** Gömülü aile Latin-only; zincir kurulmazsa AR/başka alfabede □□□ görünür (R7). AR ürün kararı (K-7) açık olsa da fallback **şimdi** kurulur, maliyeti yok.
  - [ ] ⚠️ **Ağırlık kademeleri:** sihirbaz başlıkta `w400/w700/w800/w900`, gövdede `w300/w400/w500/w600` istiyor ([`theme_draft.dart:123-134`](app/lib/features/profile/theme_builder/theme_draft.dart:123)). Statik 400+700 paketlersek **ara kademeler en yakınına düşer → ağırlık kaydırıcısı gömülü fontta sessizce etkisizleşir (ölü anahtar!)**. İki çözüm: (a) **variable font** (tek dosya, tüm eksen — önerilen, ama Flutter'ın `fontWeight` → `wght` eşlemesi **cihazda doğrulanmalı**), (b) gerekli ağırlıkları statik paketle (dosya sayısı ve boyut artar). Karar kartta gerekçelenir; hangisi olursa olsun **"ağırlık gerçekten değişiyor" testi** yazılır.
  - [ ] `kFamilies` listesine 3 aile eklenir; sihirbazda **6 seçenek** olur (3 platform + 3 gömülü). Platform aileleri **kaldırılmaz** (mevcut temalar bozulmasın).
  - [ ] Hazır temaların gövde ailesi: bugün `AppTypography.standard` gövdeye **hiç `fontFamily` yazmıyor** ([`theme_tokens.dart:148`](app/lib/core/theme/theme_tokens.dart:148)) — bu **hata değil, şemada gövde ailesi yok**. Hazır temalara Inter verilecek mi **kart içinde karar**; verilirse golden'lar buna göre yenilenir.
  - [ ] Golden testler yenilenir (`--update-goldens`) ve **fark gözle incelenir** — "yeşile döndü" yeterli değil.
  - [ ] 🔴 **Taşma taraması:** font metrikleri Roboto'dan farklı; dar ekranda (≤ 360 dp genişlik) ve **en büyük ölçek + en kalın ağırlıkta** başlık/etiket taşması aranır.
  - [ ] **APK boyut ölçümü:** `flutter clean` + `local` flavor ile **öncesi/sonrası** ölçülür ve sayı karta yazılır. (`stable` flavor production backend'e bağlı, kullanılamaz.)
- **Veri/Migration etkisi:** **Yok** — `fontFamily` zaten string olarak saklanıyor, `CustomTheme` şeması değişmez. ⚠️ Kaydedilmiş temalarda `sans-serif` yazan alanlar **olduğu gibi kalır**; eski temalar gömülü fonta **zorla geçirilmez**.
- **Ortam/Deploy:** Local. Production/staging dokunuşu yok.
- **RLS/Güvenlik:** Sunucuya veri gitmez. 🔴 **Lisanslar tek tek doğrulanır** (yalnız SIL OFL / Apache-2.0); lisans metni olmadan font commit edilmez.
- **Edge-case'ler:** Türkçe glyph eksikliği · AR/başka alfabe (fallback) · variable font desteklenmeyen platform (Windows masaüstü **ayrıca** kontrol) · font yüklenemedi → sistem fontuna düşüş · uzun metnin taşması · `useSerifTitles` bayraklı eski hazır temalar · reduce-motion ile ilgisi yok.
- **Kabul (ölçülebilir):** Seçilen her aile **başlık + gövde + etiket + saat** yüzeylerinde gerçekten uygulanıyor · **ağırlık kaydırıcısı gömülü fontta da görünür fark üretiyor** (ölü anahtar yok) · Türkçe karakterlerin hiçbiri kutu değil · fallback zinciri kurulu · lisans metinleri repoda · golden'lar yenilenmiş ve gözle onaylanmış · ≤ 360 dp'de taşma yok · **APK artışı ölçülmüş ve sayı yazılmış (hedef ≤ 2.5 MB)** · `flutter analyze` 0, testler yeşil.
- **Tuzaklar:** `google_fonts` paketine sapmak (ağdan indirir, ADR-4 yasak) · lisans metnini atlamak · subset'te Türkçe glyph'i düşürmek · fallback zincirini atlamak · **statik 2 ağırlık paketleyip ağırlık kaydırıcısını sessizce öldürmek** · golden'ları bakmadan `--update-goldens` ile ezmek · boyut ölçümünü `flutter clean` olmadan yapmak (bayat `libapp.so` → yalancı sonuç, WP-290'da tam bu oldu).

### WP-296: `main`'de kırmızı 3 testi yeşile al ✅ KOD/TEST TAMAM
- **Program/Faz:** Yeni Özellik Turu · Aşama A · **kalite borcu** (dalga dışı, tek başına koştu)
- **Ajan:** Claude · **Durum:** [x] **Tamam (2026-07-25)** — `flutter analyze` **0**, tam paket **759 yeşil / 0 kırmızı** (öncesi 755+3 kırmızı; +1 yeni regresyon testi).
- 🔴 **Tanı sonucu: 2'si ÜRÜN HATASI, 1'i saate bağımlı test.** Üçünün kök nedeni ayrıydı, tahmin edildiği gibi tek sebep değildi.
  1. **Ürün hatası (masaüstü) — `alarms_screen.dart:150`.** WP-286 izin API'sini üç duruma (`available`/`unsupported`/`unknown`) çevirdiğinde masaüstü/web `unsupported` → `allOk == false` dalına düştü. Sonuç: **Windows'ta alarm eklemeye basınca "4 izin eksik, Android ayarlarını aç" diyen, kullanıcının düzeltmesi imkânsız bir dialog** açılıyordu. Düzeltme: dialog yalnız `unsupported` **değilken** çıkar; `unknown` fail-closed olarak uyarıda kalır.
  2. **Ürün hatası (masaüstü) — `clock_widgets_screen.dart:212` `_PermissionStatusSummary`.** Aynı kök: `unsupported` "eksik izin" dalına düşüyor, kart **kırmızı** ve **"4 Eksik izinleri aç"** diyordu (o platformda var olmayan izinler için yanlış iddia); alt satır da ekranın başlığındaki cümleyi (`:107`) **aynen tekrar** ediyordu — testin `findsOneWidget` beklentisi bu yüzden 2 buluyordu. Düzeltme: `unsupported` kendi nötr dalını aldı (bilgi ikonu, "Bu izinler yalnız Android'de geçerli", alt satır yok). Aynı dosyadaki "eksikleri aç" düğmesi (`:161`) zaten yalnız `available` durumunda çiziliyordu — kart artık onunla tutarlı.
  3. **Test hatası (ürün doğru) — `study_timer_card_stop_test.dart`.** Fikstür `now - 3h` kullanıyordu; test **00:00–03:00 arasında** koşarsa o oturum dünkü güne düşüyor, `dailyTotals` bugüne 0 yazıyor, toplam 2 saat yerine 1 saat görünüyordu. **Saate bağımlı testti** (bu yüzden gündüz yeşil, gece kırmızıydı — WP kartlarının "testler yeşil" demesi de bundan). Fikstür günün başına sabitlendi; **WP-250 regresyon iddiasının kendisine dokunulmadı**, tüm `expect`'ler aynı kaldı.
- 🔴 **Kök kök neden:** WP-286'nın üç durumlu API'sinin `available` dalı **test edilemiyordu** — `snapshot()` masaüstünde `Platform.isAndroid == false` olduğu için `MethodChannel`'a hiç gitmiyor, kanal mock'lamak yetmiyor. Bu yüzden `available` davranışını doğrulayan testler sessizce `unsupported` yolunu ölçüyordu. `ClockPermissions.debugSnapshotOverride` (`@visibleForTesting`, repoda yerleşik desen) eklendi; testler artık izin durumunu **açıkça** kuruyor.
- ⚠️ **Kapsam dışı bırakılan bulgu (WP-286 QA'sına not):** `unknown` durumunda alarm dialogu `missingLabels()` ile **dört izni de "eksik" olarak listeliyor** — oysa `unknown` "okuyamadım" demek. Yanıltıcı ama bu WP'nin kırmızısı değil ve düzeltmesi yeni kullanıcı metni gerektiriyor. Ayrıca masaüstünde 4 `_PermTile` hâlâ uyarı ikonu gösteriyor (yüksek sesli yanlış iddia olan kart düzeltildi).
- **Değişen dosyalar:** `app/lib/features/clock/alarms_screen.dart` · `app/lib/features/clock/clock_widgets_screen.dart` · `app/lib/core/time_engine/clock_permissions.dart` (test dikişi) · `app/lib/l10n/app_*.arb` (+1 anahtar ×4: `clockIzinlerYalnizAndroid`) · `app/test/features/clock_widgets_screen_test.dart` (yeniden yazıldı, +1 test) · `app/test/features/classroom/study_timer_card_stop_test.dart` (fikstür). `alarms_screen_test.dart` **hiç değişmedi** — ürün düzeltildiği için kendiliğinden yeşile döndü, yani regresyon bekçisi olarak duruyor.
- **Kanıt etiketi:** `Kodda doğrulandı`. **Cihaz QA:** ayrı gerekmiyor; Android davranışı değişmedi (yalnız `unsupported` dalı düzeldi). ⚠️ **Windows** yüzeyi değiştiği için tek beta turunda masaüstünde de bakılmalı: alarm ekleme dialogsuz açılıyor mu, saat widget'ları ekranındaki izin kartı nötr mü.
- **Model önerisi:** 🔵 Sonnet
- **Problem:** `main`'de (commit `0781d05`) tam paket **755 yeşil + 3 kırmızı**. Üçü WP-290'dan **önce** de kırmızıydı (`git stash` ile temiz HEAD'de doğrulandı; 2026-07-25'te üç dosya tek tek yeniden koşuldu). Ortak kaynak **varsayılmamalı** — `git log` üç ayrı tabloya işaret ediyor. WP kartları "testler yeşil" diyordu → **kanıt ile kayıt çelişiyor**, bu çelişki kapatılmalı.
  1. `test/features/alarms_screen_test.dart:127` — "AlarmsScreen opens editor sheet": `+` ikonuna dokunulduktan sonra `find.text('Yeni alarm')` **0 sonuç** (sheet açılmıyor ya da başlık metni/l10n anahtarı değişti).
  2. `test/features/classroom/study_timer_card_stop_test.dart:99` — "WP-250: Durdur sırasında 'Bugün' toplamı zıplamaz": `find.text(formatHumanSeconds(7200))` (`2h 0m 0s`) **0 sonuç** → kartın süre biçimi ya da "Bugün" toplamının kaynağı değişmiş. 🔴 **Bu test bir regresyon bekçisi** (WP-250 sayaç zıplaması); kırmızı kaldığı sürece o hata korumasız.
  3. `test/features/clock_widgets_screen_test.dart:29` — `find.textContaining('Android sistem ayarlarından')` **2 sonuç**, beklenen 1 (`findsOneWidget`); metin iki kez çiziliyor.
- **Elde olan kanıt (tanıyı hızlandırır, bitirmez):**
  - `app/lib/features/clock/clock_widgets_screen.dart`'a **son dokunan commit `e7301bf` = WP-286** → 3. madde büyük olasılıkla o birleştirmenin çift çizimi. Düzeltme bu dosyaya girerse **WP-286 QA'sı yenilenir**.
  - `app/lib/features/classroom/widgets/study_timer_card.dart` ve testi **aynı commit'ten** (`62bacac`, WP-250) beri değişmemiş → 2. maddenin kaynağı **kartın kendisi değil**; besleyen sağlayıcı/biçimlendirici (`formatHumanSeconds` çağrı yolu veya "Bugün" toplamının kaynağı) aranmalı.
  - `alarms_screen_test.dart` en son `904a3b9`'da (WP-87 yerelleştirme) değişmiş; ekranın kendisi sonradan değişmiş olabilir → **`Yeni alarm` metninin bugünkü karşılığı doğrulanmalı**.
- **Kapsam dışı:** Yeni özellik, tema, refactor, "testi silmek/skip'lemek", kabul kriterini teste uydurmak için ürün davranışını değiştirmek.
- **SAHİP dosyalar (yaz):** yukarıdaki 3 test dosyası **ve** kök nedeni barındıran uygulama dosyası (tanı sonrası netleşir — büyük olasılıkla `app/lib/features/clock/**`, `app/lib/features/notifications/**`, `app/lib/features/classroom/widgets/study_timer_card.dart`), gerekirse `app/lib/l10n/app_*.arb`.
- **DOKUNMA:** `app/lib/core/theme/**` ve `app/lib/features/profile/theme_builder/**` (WP-290 QA'da) · `supabase/**` · `app/lib/core/stats/**`.
- **Adımcıklar:**
  - [ ] Her kırmızı için **önce tanı**: test mi bayat (ürün doğru) yoksa ürün mü bozuk (test doğru)? Kararı kartta yaz.
  - [ ] 🔴 **Test bayatsa** bile davranışın **kasıtlı** olduğu kanıtlanmadan test güncellenmez — özellikle 2. madde WP-250 regresyon bekçisi.
  - [ ] Ürün bozuksa: kök nedeni düzelt, testi olduğu gibi bırak.
  - [ ] `flutter test` **tam paket** yeşil; kırmızı sayısı 0.
- **Veri/Migration etkisi:** Yok. **Ortam/Deploy:** Local. **RLS/Güvenlik:** Yok.
- **Edge-case'ler:** Üçünün kök nedeni **ayrı** olabilir (kanıt öyle gösteriyor) · düzeltme WP-286/288 yüzeyine dokunursa o WP'lerin cihaz QA'sı **yeniden** gerekir → QA kuyruğu tablosuna yaz · `flutter test` tek dosya yeşil ama tam paket kırmızı olabilir (test sırası/paylaşılan state).
- **Kabul (ölçülebilir):** `flutter analyze` 0 · `flutter test` **0 kırmızı** · her üç test için "test bayattı" / "ürün bozuktu" kararı gerekçeli yazılmış · hiçbir test silinmemiş/`skip` edilmemiş · WP-250 regresyon iddiası hâlâ gerçek bir şeyi koruyor.
- **Tuzaklar:** Testi `skip` edip "yeşil" demek · `findsOneWidget` → `findsWidgets` gevşetip çift çizimi gizlemek · üç kırmızıyı tek varsayımla açıklamak · düzeltmeyi tema yüzeyine sıçratmak.

### WP-295: Kozmetik — kamp ateşi animasyonları 🔥
- **Program/Faz:** Yeni Özellik Turu · Aşama A (son) · (plan §3 F-08)
- **Ajan:** — · **Durum:** [ ] Bekliyor · **Bağımlılık:** **Sahiple ayrı konuşma turu** + asset kararı
- **Problem:** Kamp ateşi animasyonları yenilenecek. Sahip bu tasarımı **birlikte konuşarak** yapmak istiyor; tek başına tasarlanmayacak.
- **Kapsam dışı:** Taç (WP-292), tema motoru, sunucu, XP/başarım mantığı.
- **SAHİP dosyalar (yaz):** `app/lib/features/classroom/widgets/campfire_scene.dart`, `app/lib/features/classroom/widgets/campfire/**`, `app/lib/features/classroom/widgets/camp_critter.dart`, ilgili golden testler.
- **DOKUNMA:** `app/lib/core/stats/**`, `app/lib/core/widgets/crowned_avatar.dart` (WP-292'nin), tema motoru.
- **Adımlar:**
  - [ ] **Önce sahiple konuşma turu** — kararlar `docs/YENI-OZELLIK-NOTLARI.md`'ye yazılır.
  - [ ] Hayvanlar şu an vektör fallback; tasarımcı asset'i gelecek mi karar ver (`references/campfire/TASARIMCI_BRIEF.md`).
  - [ ] Animasyonları uygula; golden ve performans kontrolü.
- **Veri/Migration etkisi:** Yok. **Ortam/Deploy:** Local. **RLS/Güvenlik:** Yok.
- **Edge-case'ler:** "Hareketi azalt" açık · düşük donanımda kare düşmesi · koyu/açık tema · asset gelmezse vektör fallback korunur.
- **Kabul (ölçülebilir):** Sahip kabulü · golden yeşil · "hareketi azalt" açıkken animasyon durur · 🔴 **performans bütçesi:** orta seviye Android cihazda ilgili ekranda **p95 kare süresi ≤ 16.7 ms** ve animasyon boyunca **jank kare oranı ≤ %1** (`flutter run --profile` + timeline). *rev.2'deki "kare düşmesi ölçüldü" ifadesi sayısızdı, kabul değil.*
- **Tuzaklar:** Sahiple konuşmadan tasarıma başlamak (açık şart) · ağır efektle performans düşürmek.
- **Model önerisi:** 🟣 Pro

### WP-292: Kozmetik — taç görseli ✨
- **Program/Faz:** Yeni Özellik Turu · Aşama A (son) · (plan §3 F-08) · *rev.2: kamp ateşi WP-295'e ayrıldı*
- **Ajan:** — · **Durum:** [ ] **Kodlanacak — HAZIR.** *Eski "WP-290 cihaz kabulü" kapısı **tek beta kararıyla düştü** (2026-07-25, `§0.1`): kabul beta'dan önce fiziken alınamıyor. Kapı yerine şart: WP-290/297 commit'lenmiş ve testler yeşil olmalı; **297 ile paralel koşulmaz** (golden yüzeyi).*
- **Problem:** Profil fotoğrafı üstündeki taç sahibe göre kötü duruyor; görsel yenilenecek.
- **Kapsam dışı:** **XP/kademe mantığı**, başarım motoru, tema motoru, yeni ekonomi kuralı, kamp ateşi (WP-295).
- **SAHİP dosyalar (yaz):** `app/lib/core/widgets/crowned_avatar.dart`, `app/lib/core/widgets/crown_tiers_sheet.dart`, ilgili golden testler.
- **DOKUNMA:** 🔴 `app/lib/core/stats/achievement_ledger_engine.dart` — **`crownRankForXp:358` ve `kCrownXpThresholds` DEĞİŞTİRİLMEZ**; taç XP'den türer ve XP server-authoritative'dir (`AGENTS.md §2`). Eşiğe dokunmak kullanıcıların görünen kademesini sessizce kaydırır. Ayrıca: sunucu tarafı, tema motoru, `campfire*` (WP-295'in).
- **Adımlar:**
  - [ ] Taç çizim katmanı yenilenir; **kademe→görsel eşlemesi birebir korunur**.
  - [ ] Golden testler güncellenir; performans bütçesi ölçülür.
- **Veri/Migration etkisi:** Yok. **Ortam/Deploy:** Local. **RLS/Güvenlik:** Yok.
- **Edge-case'ler:** Taçsız kullanıcı (rank null/boş — `crowned_avatar.dart:29`) · en yüksek kademe · küçük avatar boyutları · "hareketi azalt" açık · düşük donanım.
- **Kabul (ölçülebilir):** **Aynı XP → aynı kademe** (regresyon testi yeşil) · taçsız durumda düz avatar · golden yeşil · "hareketi azalt" açıkken animasyon durur · 🔴 **p95 kare süresi ≤ 16.7 ms, jank ≤ %1** (`flutter run --profile` + timeline).
- **Tuzaklar:** Görsel değişiklik sırasında kademe eşiğini kaydırmak (kullanıcıların tacı sessizce değişir) · ağır efektle kare düşürmek.
- **Model önerisi:** 🟣 Pro

### WP-294: l10n borcu ayıklama + audit CI kapısı 🌍
- **Program/Faz:** Yeni Özellik Turu · Aşama A · (plan §3 l10n borcu, R23)
- **Ajan:** — · **Durum:** [ ] Kodlanacak · 🟡 **Kısmen açık (2026-07-25 uzlaştırıldı):** audit'i 4 katalog + sabit EN/TR literal + native yüzeye genişletme, UTF-8 düzeltmesi, bulguların sınıflandırılması ve CI kapısı **bugünkü 4 dil gerçeğiyle yapılabilir**. 🔴 **Yalnız "AR/DE'yi üründen çıkarıp EN/TR'ye daraltma" dalı K-7'ye bağlıdır** — o dal K-7 kapanmadan uygulanmaz. Sahip 2026-07-25'te "Arapça'yı şimdilik dert etmiyoruz" dedi; bu **K-7 kararı değildir**, dil setine dokunulmaz.
- **Problem:** Üç katmanlı borç. **(a)** `l10n_audit.py` UTF-8'de **38 bulguyla kırmızı**: `account_settings_screen.dart:257,264,272,318,347,482,484,493`, `app_push_notification_service.dart:325,326,331`, `task_deadline.dart:152,153`, `achievement_reward_provider.dart:50,68` — koda gömülü Türkçe metinler. **(b)** Audit **yalnız EN/TR** yüklüyor (`:23-24`) → **DE/AR denetlenmiyor**; ayrıca sabit **İngilizce** kullanıcı metnini yakalamıyor → sahte güven üretiyor. **(c)** Denetim CI'da çalışmıyor, yeni borç engellenmiyor.
- 🔴 **Yönetişim çelişkisi:** `progress.md` WP-278 AR/DE'nin üründe kalıp kalmayacağını **hâlâ ürün kararı olarak açık** bırakıyor; plan ise dört dili zorunlu sayıyor. **K-7 kapanmadan bu WP ve font/RTL işi başlamaz.**
- **Kapsam dışı:** Yeni özellik, tema, yasal metinlerin mimari olarak dışarı taşınması (**not edilir, ayrı WP**), genel analyze/test CI kapısı kurulumu.
- **SAHİP dosyalar (yaz):** `scripts/l10n_audit.py`, yeni l10n kapısı için `.github/workflows/**`, tespit edilen sabit metinlerin bulunduğu dosyalar, `app/lib/l10n/app_*.arb`.
- **DOKUNMA:** `app/lib/core/theme/**`, `app/lib/features/profile/theme*`, `supabase/**`.
- **Adımlar:**
  - [ ] **K-7 kararını al** (AR/DE kalacak mı). Kalırsa audit dört katalogu kapsar + RTL QA ayrı WP olur; kalmazsa dil seçenekleri ve plan **EN/TR'ye dürüstçe daraltılır**.
  - [ ] 🔴 **Audit'i genişlet:** `app_de.arb` + `app_ar.arb` kataloglara eklenir (bugün `:23-24` yalnız EN/TR), **placeholder eşliği dahil**; sabit **İngilizce** kullanıcı metni de yakalanır (bugün yalnız Türkçe literal).
  - [ ] ℹ️ **Native audit zaten çağrılıyor** (`:26,108` `l10n_android_audit.py` subprocess) — rev.2'deki "native audit ayrı" ifadesi yanıltıcıydı; doğru belgelenir.
  - [ ] UTF-8 çıktı hatasını düzelt. ℹ️ Windows `cp1254` çökmesi **Ubuntu CI için bloklayıcı değil**; Windows release runner'ına bağlanacaksa şart.
  - [ ] Bulguları sınıflandır: kullanıcıya görünen / geliştirici log'u / yanlış pozitif. Görünenleri kataloglara taşı.
  - [ ] Audit'i CI kapısı yap (yeni sabit metin eklenemesin) — **kırmızı-yeşil ispatıyla**.
  - [ ] Yasal metin mimarisi konusunu **not et**, çözme (ayrı WP).
- **Veri/Migration etkisi:** Yok. **Ortam/Deploy:** Local + CI. **RLS/Güvenlik:** Yok.
- **Edge-case'ler:** Yanlış pozitifler (teknik sabitler, log) · uzun metinlerin AR/DE'de taşması · K-7 "AR/DE çıkacak" derse katalog silme sırası.
- **Kabul (ölçülebilir):** Audit **dört katalog + sabit EN/TR literal + native yüzeyleri** kapsıyor · UTF-8'de çökmüyor · CI kapısı yeni sabit metni **reddediyor** (kırmızı-yeşil ispatı) · kullanıcıya görünen sabit metin sayısı ölçülüp düşürüldü · **K-7 kararına uygun dil seti** ile build yeşil.
- **Tuzaklar:** Yanlış pozitifleri körü körüne çevirmek · yasal metin refactor'ına girip kapsamı patlatmak · 286/290 ile aynı anda l10n'e girmek.
- **Model önerisi:** 🔵 Sonnet

## Bekleyen Uygulanabilir WP'ler

### WP-276 — Hesap silme staging ops ve kabul kanıtı
- **Durum:** [ ] Bekliyor · **Bağımlılık:** Kurtarma release güveni; production için ayrıca somut GO.
- **Amaç:** Sentetik staging hesapta request/cancel/purge, 14 günlük grace simülasyonu, yetkisiz çağrı, retry/terminal hata ve rollback runbook'unu kanıtlamak.
- **Sınır:** Gerçek kullanıcı hesabı, production purge, yeni feature/migration kapsam dışıdır.
- **Sahip yollar:** `docs/qa/ACCOUNT-DELETION-STAGING.md`, `docs/play-store/PLAY-RELEASE-GATE.md`, redacted staging kanıtı ve yalnız gerekli testler.

### WP-277 — Başarım, görev ve grup ilerlemesi kabul matrisi
- **Durum:** [ ] Bekliyor · **Bağımlılık:** WP-271 cihaz/release güveni; WP-276 ile paralel backend ops yok.
- **Amaç:** Beş süre kaynağında istatistik/XP/başarım/grup sonucunu, pending reward/claim'i, iki cihazı ve İstanbul gün sınırını sentetik staging kanıtıyla sınıflandırmak.
- **Sınır:** Yeni ekonomi kuralı, migration/backfill ve production claim kapsam dışıdır; bulunmuş hata ayrı WP olur.

### WP-278 — AR/DE dil desteği ve RTL ürün kararı
- 🔴 **Yeni özellik turunun K-7 kararı budur ve WP-294 + font/RTL işini BLOKLAR.** Karar verilmeden WP-294 başlamaz; ayrıca ADR-4 font paketlemesinde AR fallback zinciri gerekip gerekmediğini de bu belirler.
- **Durum:** [?] Kullanıcı üründe AR/DE olup olmayacağını ve çeviri sahibini belirlemeli.
- **Karar sonrası:** Evetse insan çevirisi/RTL cihaz QA için ayrı WP'ler; hayırsa EN/TR sınırı ve kullanıcıya görünen dil seçenekleri dürüstçe güncellenir.

### WP-279 — Aylık rapor canlı ops kararı
- **Durum:** [?] DNS domaini, sender, sağlayıcı, maliyet limiti ve opt-in sahibi kararı yok.
- **Sınır:** Karar olmadan secret, cron, staging/production e-posta gönderimi yapılmaz.

## Kapanan / Tekilleştirilen Kayıtlar

| Kayıt | Canlı durum |
|---|---|
| WP-269–275, 280–285 | **Kapandı (2026-07-24).** Kod/test kanıtı + proje sahibinin v45 stable ve beta-v4308 üzerindeki cihaz testi; bekleyen cihaz kabulü kalmadı |
| WP-271 | Staging gerçek push/retry ve timer action davranışı sahip testinde sorunsuz; ölçümlü matris kaydı istenirse yeni WP açılır |
| WP-225, 226, 258 | Tarihsel tamamlanmış işler; ayrıntı arşiv+git'te |
| WP-266/267/268 | Eski ayrıntılar arşivde; açık push/timer kabulü WP-271 ve QA matrisinde |
| WP-286, 287, 288, 289, 290, 291, 293 | **Kod/test tamam (2026-07-24/25).** Kartlar [arşive taşındı](docs/archive/progress-tarihsel-2026-07.md) (2026-07-25) — ajan tarafında iş yok. 289 tümüyle kapandı; diğer 6'sı **Cihaz QA Kuyruğu**'nda. Yeniden claim edilmez; QA'da bulunan hata yeni WP olur |

## Worker'a Verilecek Kısa Komutlar

**Beta'ya kadar sırayla verilecek komutlar** (hepsi bitmeden beta çıkmaz):
- ✅ `worker'ı oku ve WP-296'yı yap` — `main`'deki 3 kırmızı test
- ✅ `worker'ı oku ve WP-297'yi yap` — gömülü fontlar (sahip onayı var)
- ✅ `worker'ı oku ve WP-292'yi yap` — taç görseli (cihaz kapısı beta kararıyla düştü)
- 🟡 `worker'ı oku ve WP-294'ü yap` — bugünkü 4 dil gerçeğiyle; "EN/TR'ye daraltma" dalı K-7 bekler
- 🔴 WP-295 → **worker komutu değil:** önce sahiple kamp ateşi tasarım konuşması

⚠️ **297 ile 292 aynı anda koşulmaz** — ikisi de golden test yüzeyine giriyor.

Kod/test'i bitmiş WP'ler (286, 287, 288, 289, 290, 291, 293) için **worker komutu verilmez** — sıra sahipte (cihaz QA + WP-287 staging paneli).

Önceki tur:
- `worker'ı oku ve WP-276'yı yap` · `worker'ı oku ve WP-277'yi yap`
- WP-278/279 için önce ürün/ops kararı alınır.

> Her worker önce Aktif Çalışma Kaydı'nı okur, kendi lane'ini claim eder ve SAHİP yolları çakışıyorsa başlamaz. Production/stable hiçbir WP'nin örtük parçası değildir.
