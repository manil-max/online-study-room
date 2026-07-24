# progress.md — Canlı Durum

> Son güncelleme: **2026-07-24** · Saat dilimi: **Europe/Istanbul**
>
> Bu dosya yalnız aktif iş, açık kabul ve ürün kararlarını taşır. Tamamlanmış WP'lerin ayrıntısı git geçmişi, [`docs/archive/progress-tarihsel-2026-07.md`](docs/archive/progress-tarihsel-2026-07.md) ve kanonik raporlardadır; burada tekrar edilmez.

## Proje Gerçekleri

- **Stable/production:** v45 yayında. Production migration head `0065`; staging `0070`. Yeni production migration, Edge deploy veya stable tag/release yalnız ayrı, somut kullanıcı GO ile yapılır.
- **Beta/staging:** beta-v4308 staging `0070` üzerinde yayında. Proje sahibi 2026-07-24'te stable+beta yayınını ve bildirim/sayaç davranışını cihazda test etti; genel sorun yok, bekleyen cihaz kabulleri kapatıldı.
- **Release ilkesi:** Android beta/stable artefaktı Android işi başarılı olunca yayımlanır. Windows bağımsız sürer ve başarılı olursa aynı release'e eklenir; Windows hatası Android güncellemesini geri çekmez.
- **Yönetim varsayılanı:** Production `deploy_enabled/release_enabled` kapalıdır. Stable yalnız protected `production` Environment, exact SHA/head/project-ref GO ve reviewer kanıtıyla ilerler.
- **Kurallar:** Kök `AGENTS.md`, `.agents/AGENTS.md` ve `docs/KALITE-PROGRAMI.md` geçerlidir. Tek çalışma dalı `main`; her WP ayrı commit; production varsayılmaz.
- **Son WP:** **295** (286–295 planlandı, uygulanmadı) · Sıradaki boş numara: **296**.
- **Aktif tur:** Yeni Özellik Turu **Aşama A** — plan **rev. 2** hazır, uygulama bekliyor. Kanonik plan: [`docs/YENI-OZELLIK-PLANI.md`](docs/YENI-OZELLIK-PLANI.md).
- ⚠️ **Ortam gerçeği çelişkili:** aşağıdaki `0065` ile `tooling/release/deploy-contract.json` (`0070`) ve `docs/KALITE-PROGRAMI.md:108` (v43/HOLD) uyuşmuyor. **WP-293 (Gate 0)** bunu salt-okunur doğrulayıp uzlaştıracak; o bitene kadar bu satıra operasyon kararı için güvenilmez.

## ⚡ Aktif Çalışma Kaydı

### Gemini Lane
- **Durum:** [x] Boşta
- **Faz/WP:** —
- **SAHİP yollar:** —

### Claude Lane
- **Durum:** [x] Boşta
- **Faz/WP:** —
- **SAHİP yollar:** —

### Codex Lane
- **Durum:** [x] Boşta
- **Faz/WP:** —
- **SAHİP yollar:** —
- **Son not:** WP-285 kod/test tamam; beta-v4308 P7 cihaz kabulü bekler. Timer state motoru, migration, backend ve production değişmedi.

### Codex-2 Lane
- **Durum:** [x] Boşta
- **Faz/WP:** —
- **SAHİP yollar:** —

### Grok Lane
- **Durum:** [x] Boşta
- **Faz/WP:** —
- **SAHİP yollar:** —

## Öncelik ve Yürütme Sırası

| Öncelik | İş | Durum | Kalan gerçek iş |
|---|---|---|---|
| **0** | **WP-293 Gate 0 — ortam uzlaştırma** | [ ] Bekliyor | 🔴 **Diğer tüm WP'ler buna bağlı**; salt-okunur doğrulama + 4 belge |
| 0b | Production backend değişikliği | 🔴 Kapalı | Yeni migration/Edge deploy/secret yalnız backup+dry-run ve somut GO ile |
| 1 | WP-287 şifre sıfırlama · WP-286 ayarlar IA | [ ] Bekliyor | **Canlı hata** + bileşen ayıklama; paralel |
| 2 | WP-291 boyut paneli · WP-289 his araştırması | [ ] Bekliyor | Bağımsız, paralel |
| 3 | WP-288 tema modeli · WP-294 l10n borcu | [ ] Bekliyor | 288 **289'a bağımlı**; 294 l10n sıcak yüzey |
| 4 | WP-290 tema sihirbazı | [ ] Bekliyor | Tek başına; `core/theme/**` + `pubspec.yaml` |
| 5 | WP-292 taç · WP-295 kamp ateşi | [ ] Bekliyor | 295 sahiple konuşma ister |
| Sonra | WP-276/277 ops kabulü | [ ] Bekliyor | Sentetik staging ops kanıtı; WP-276 Play Store için de gerekli |
| Karar | WP-278/279 | [?] Ürün/ops kararı | Açık sahip ve kapsam kararı olmadan başlanmaz |

## Yeni Özellik Turu — Aşama A (Plan Kuyruğu)

Konuşma fazı kapandı (9 tur). Kanonik belgeler:
- Konuşma kaydı: [`docs/YENI-OZELLIK-NOTLARI.md`](docs/YENI-OZELLIK-NOTLARI.md)
- **Detaylı teknik plan: [`docs/YENI-OZELLIK-PLANI.md`](docs/YENI-OZELLIK-PLANI.md)** ← WP'lerin gerekçesi, repo analizi, riskler burada

Sıra: **Aşama A (kod) → Aşama B (Play Store) → Aşama C (Microsoft Store).** Aşama B/C'nin WP'leri Aşama A kabulünden sonra açılır.

**⚠️ Plan rev. 2 (2026-07-24, senior teknik değerlendirmesi sonrası).** Beş P1 bulgu kodda doğrulandı ve plana işlendi: **WP-293 (Gate 0), WP-294 (l10n borcu), WP-295 (kamp ateşi ayrıldı)** eklendi; **289 artık 288'den önce**; ADR-1 ve ADR-6 yeniden yazıldı. Gerekçeler: plan §9 Revizyon günlüğü.

**Dalga modeli (aynı anda en fazla 2 lane):**
```
GATE 0   WP-293  Ortam/migration uzlaştırma      ← HER ŞEYDEN ÖNCE
DALGA 1  WP-287  Şifre sıfırlama  ‖  WP-286  Ayarlar IA + bileşen ayıklama
DALGA 2  WP-291  Boyut paneli     ‖  WP-289  His araştırması + AppFeel şeması
DALGA 3  WP-288  Tema modeli      ‖  WP-294  l10n borcu + audit CI kapısı
DALGA 4  WP-290  Tema sihirbazı      (tek başına)
DALGA 5  WP-292  Taç              ‖  WP-295  Kamp ateşi (sahip kararı sonrası)
```

> 🔴 **WP-293 bitmeden hiçbir WP başlamaz** — `progress.md:9` (`0065`), `deploy-contract.json` (`0070`) ve `KALITE-PROGRAMI.md:108` (v43/HOLD) çelişiyor.
> ⚠️ **288, 289'a bağımlı** — `AppFeel` alanlarını 289'un kataloğu belirler (döngüsel bağımlılık düzeltildi).
> ⚠️ **288 ve 290 seri** — ikisi de `app/lib/core/theme/**`; 290 ayrıca `app/pubspec.yaml`'a girer.
> ⚠️ **294 (l10n) ile 286/290 aynı dalgada olmaz** — l10n sıcak yüzey.
> ⚠️ Tema programı açıkken **Saat ve Başarım programları açılmaz** (`.agents/AGENTS.md §1.2`).

### WP-293: Gate 0 — ortam/migration gerçeğini uzlaştır 🧭
- **Program/Faz:** Yeni Özellik Turu · **Gate 0** · (plan §3 Gate 0, R15)
- **Ajan:** — · **Durum:** [ ] Bekliyor · **Diğer tüm WP'ler buna bağlı**
- **Problem:** Aynı soruya üç belge üç cevap veriyor: `progress.md:9` production head `0065`; `tooling/release/deploy-contract.json` production `0070` + `deploy_enabled: true`; `docs/KALITE-PROGRAMI.md:108` hâlâ v43 ve WP-269–274 HOLD. `8b53290` commit'i contract'ı `0070`'e çekmiş → `progress.md` bayat görünüyor. Yanlış belgeye bakan ajan yanlış operasyon kararı verir.
- **Kapsam dışı:** Migration uygulamak, contract kapısı açmak/kapatmak, release tetiklemek, herhangi bir özellik kodu. **Bu WP yalnız okur ve belgeyi düzeltir.**
- **SAHİP dosyalar (yaz):** `progress.md`, `docs/KALITE-PROGRAMI.md`, `project.md`, `tooling/release/deploy-contract.json` (yalnız **gerçeğe uydurma**, kapı açma değil).
- **DOKUNMA:** `app/**`, `supabase/migrations/**`, workflow dosyaları, herhangi bir kod.
- **Adımlar:**
  - [ ] Canlı production + staging migration head'ini **salt-okunur** doğrula: `tooling/supabase/remote.ps1` list veya protected `Database Gates` workflow'u. **Doğrudan remote Supabase CLI komutu yasak** (`AGENTS.md §2`).
  - [ ] Çıktıyı (redacted) kanıt olarak kaydet.
  - [ ] Dört belgeyi tek gerçeğe getir; çelişen satırları düzelt.
  - [ ] `KALITE-PROGRAMI.md`'deki v43 / WP-269–274 HOLD kaydını güncel duruma çek (v45 yayında, cihaz kabulleri kapandı).
- **Veri/Migration etkisi:** **Yok** — hiçbir migration uygulanmaz.
- **Ortam/Deploy:** Yalnız salt-okunur sorgu. Deploy/push/release **yok**.
- **RLS/Güvenlik:** Salt-okunur. Project-ref, token, DB parolası çıktıya/commit'e yazılmaz.
- **Edge-case'ler:** Canlı head beklenenden farklı çıkarsa → **kullanıcıya bildir, kendi başına düzeltme yapma** · sorgu erişimi yoksa → belgeye "doğrulanamadı" yaz, **uydurma**.
- **Kabul (ölçülebilir):** Dört belge aynı head'i söylüyor · kanıt redacted kayıtlı · hiçbir migration/deploy tetiklenmedi · `git diff` yalnız doküman + contract.
- **Tuzaklar:** Contract'ı "geçsin diye" değiştirmek (`AGENTS.md §2` açıkça yasaklıyor) · sahte head/backup/GO girdisi yazmak · doğrulamadan `0070` varsayıp belgeye yazmak.
- **Model önerisi:** 🟣 Pro

### WP-294: l10n borcu ayıklama + audit CI kapısı 🌍
- **Program/Faz:** Yeni Özellik Turu · Aşama A · (plan §3 l10n borcu, R23)
- **Ajan:** — · **Durum:** [ ] Bekliyor
- **Problem:** `scripts/l10n_audit.py` gerçek bulgular veriyor: `account_settings_screen.dart:257,264,272,318,347,482,484,493`, `app_push_notification_service.dart:325,326,331`, `task_deadline.dart:152,153`, `achievement_reward_provider.dart:50,68` ve dahası — koda gömülü Türkçe metinler. Denetim **CI'da çalışmıyor**, yani yeni borç eklenmesi engellenmiyor.
- **Kapsam dışı:** Yeni özellik, tema, yasal metinlerin mimari olarak dışarı taşınması (**not edilir, ayrı WP**), genel analyze/test CI kapısı kurulumu.
- **SAHİP dosyalar (yaz):** `scripts/l10n_audit.py`, yeni l10n kapısı için `.github/workflows/**`, tespit edilen sabit metinlerin bulunduğu dosyalar, `app/lib/l10n/app_*.arb`.
- **DOKUNMA:** `app/lib/core/theme/**`, `app/lib/features/profile/theme*`, `supabase/**`.
- **Adımlar:**
  - [ ] Önce `l10n_audit.py`'ın **UTF-8 çıktı hatasını düzelt** — Windows `cp1254` altında `UnicodeEncodeError` ile çöküyor, bu haliyle CI'a bağlanamaz.
  - [ ] Bulguları sınıflandır: kullanıcıya görünen metin / geliştirici log'u / yanlış pozitif.
  - [ ] Görünen metinleri 4 dile taşı.
  - [ ] Audit'i CI kapısı yap (yeni sabit metin eklenemesin) — kırmızı-yeşil ispatıyla.
  - [ ] Yasal metin mimarisi konusunu **not et**, çözme.
- **Veri/Migration etkisi:** Yok. **Ortam/Deploy:** Local + CI. **RLS/Güvenlik:** Yok.
- **Edge-case'ler:** Yanlış pozitifler (teknik sabitler, log) · native XML sabitleri (`l10n_android_audit.py` ayrı) · uzun metinlerin AR/DE'de taşması.
- **Kabul (ölçülebilir):** Audit UTF-8'de çökmeden çalışıyor · CI kapısı yeni sabit metni **reddediyor** (kırmızı-yeşil ispatı) · kullanıcıya görünen sabit metin sayısı ölçülüp düşürüldü · 4 dilde build yeşil.
- **Tuzaklar:** Yanlış pozitifleri körü körüne çevirmek · yasal metin refactor'ına girip kapsamı patlatmak · 286/290 ile aynı anda l10n'e girmek.
- **Model önerisi:** 🔵 Sonnet

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
- **Kabul (ölçülebilir):** Sahip kabulü · golden yeşil · "hareketi azalt" açıkken animasyon durur · kare düşmesi ölçüldü.
- **Tuzaklar:** Sahiple konuşmadan tasarıma başlamak (açık şart) · ağır efektle performans düşürmek.
- **Model önerisi:** 🟣 Pro

### WP-286: Ayarlar bilgi mimarisi — ölü kartı sil, bölümleri ayıkla, bildirim/izin/rapor birleştir 🧹
- **Program/Faz:** Yeni Özellik Turu · Aşama A · (plan §3 F-01 + F-02, ADR-6 rev.2, R18/R19)
- **Ajan:** — · **Durum:** [ ] Bekliyor · **Bağımlılık:** WP-293
- **Problem:** "Uygulama kısayolları (rutinler)" kartı hiçbir şeye bağlı değil (`settings_screen.dart:330-339` — `onTap` yok); ayrıca bildirim tercihleri, cihaz izinleri ve aylık rapor ayarlarda üç ayrı yerde duruyor, ilk kullanan anlamıyor.
- **Kapsam dışı:** Yeni bildirim türü, yeni izin API'si, push altyapısı değişikliği, tema.
- **SAHİP dosyalar (yaz):** `app/lib/features/profile/settings_screen.dart`, `app/lib/features/notifications/**` (yeni birleşik ekran dosyası dahil), `app/lib/features/clock/clock_widgets_screen.dart`, `app/lib/l10n/app_*.arb`, ilgili testler.
- **DOKUNMA:** `app/lib/core/theme/**`, `app/lib/core/navigation/**`, `app/pubspec.yaml`, `supabase/**`.
- **Adımlar (sıra önemli — ADR-6 rev.2):**
  - [ ] Kısayol kartını (`settings_screen.dart:329-339`) ve `profileUygulamaKisayollariRutinler` anahtarını 4 dilden sil. Önce `grep` ile başka kullanım yok doğrula. ⚠️ `device_integration_listener.dart` / `samsung_modes_service.dart` içindeki "routine/shortcut" **Samsung Modes & Routines** entegrasyonudur — **dokunma**.
  - [ ] **1) Characterization testi:** mevcut iki ekranın bugünkü davranışını testle sabitle (refactor güvenlik ağı).
  - [ ] **2) Public bileşen ayıklama:** `_TypesCard`, `_QuietHoursCard`, `_RemindersCard`, `_AnnouncementsCard`, `_PushHealthCard`, `_PermTile`, `_WidgetCard`, `_PermissionRevocationGuide` → `features/notifications/sections/notification_preference_sections.dart` ve `.../clock_permission_sections.dart`. **Davranış değişmez**, yalnız görünürlük + konum. ⚠️ Bunlar `_` önekli = library-private; **başka dosyadan import edilemezler**, bu yüzden ayıklama şart (import etmek Dart'ta mümkün değil).
  - [ ] **3) Birleşik ekran:** "Bildirimler ve izinler" — bölümleri dizer. Tek parça 1000+ satırlık dosya **olmayacak**.
  - [ ] **Üç durumlu izin snapshot'ı:** `ClockPermissionSnapshot` `granted`/`unsupported`/`unknown` ayrımı taşır. ⚠️ Bugün `clock_permissions.dart:69-78` native hatayı da desteklenmeyen platformu da `ok` sayıyor (**fail-open**) → özet yalan söylüyor. Mevcut çağıranlar geriye uyumlu kalır.
  - [ ] En üste **durum özeti**: eksik izin sayısı + "Düzelt". `unknown`'da **"her şey hazır" iddiası yapılmaz**.
  - [ ] Aylık rapor switch'i ayarlar listesinden bu ekrana taşınır.
  - [ ] Ayarlar listesinde 3 giriş → 1 giriş.
- **Veri/Migration etkisi:** Yok.
- **Ortam/Deploy:** Local. Production dokunuşu yok.
- **RLS/Güvenlik:** Yok (yalnız istemci IA). `monthlyReportOptIn` yazma davranışı **değişmez**.
- **Edge-case'ler:** Sistem ayarından izin verip dönme (`resume`'da yenilenir) · snapshot okunamıyor (`unknown` → "durum okunamadı", sahte yeşil yok) · Windows/masaüstü (`unsupported` → Android'e özgü olduğunu söyler) · çevrimdışıda push sağlığı kartı mevcut hata durumunu korur.
- **Kabul (ölçülebilir):** Ayarlarda bildirim/izin/rapor için **tam 1** giriş (öncesi 3) · characterization testleri ayıklama **öncesi ve sonrası aynı sonucu** veriyor · eksik izin sayısı doğru · "Düzelt" ilgili sistem ekranını açar · izin verilip dönüldüğünde özet ≤ 1 sn güncellenir · `unknown` durumunda "hazır" denmiyor · bu WP'nin yüzeyinde **yeni sabit metin eklenmedi**, yeni anahtarlar 4 dilde tam · `flutter analyze` 0.
- **Tuzaklar:** `_` önekli widget'ları başka dosyadan import etmeye çalışmak (**derlenmez**) · 1236 satırı sıfırdan yazmaya kalkmak (yüksek regresyon riski) · characterization testi yazmadan refactor'a girmek · birleşik ekranı tek dev dosya yapmak · l10n anahtarını generated dosyadan temizlemeyi unutmak.
- **Model önerisi:** 🟣 Pro *(rev.2: ayıklama + üç durumlu snapshot eklendiği için Sonnet'ten yükseltildi)*

### WP-287: Şifre sıfırlama derin bağlantı düzeltmesi 🔑
- **Program/Faz:** Yeni Özellik Turu · Aşama A · (plan §3 F-03) · **canlı hata**
- **Ajan:** — · **Durum:** [ ] Bekliyor
- **Problem:** `supabase_auth_repository.dart:185` `resetPasswordForEmail`'i **`redirectTo` olmadan** çağırıyor. Supabase linki Site URL'e (`localhost:3000`) yönlendiriyor; kullanıcı "check your internet connection" hatası alıyor ve şifresini sıfırlayamıyor. Sahip stable'da doğruladı.
- **Kapsam dışı:** Yeni auth yöntemi, OAuth, e-posta şablonu tasarımı, hesap silme.
- **SAHİP dosyalar (yaz):** `app/lib/data/repositories/supabase/supabase_auth_repository.dart`, `app/lib/data/repositories/in_memory/in_memory_auth_repository.dart`, `app/lib/data/repositories/auth_repository.dart`, `app/lib/core/config/**` (redirect çözümleyici), `app/lib/features/auth/**`, ilgili testler, `docs/` runbook.
- **DOKUNMA:** `AndroidManifest.xml` (intent-filter **zaten var**, `:64`), `supabase/migrations/**`, tema.
- **Adımlar:**
  - [ ] Ortama göre `redirectTo` çözümleyici: scheme = applicationId (`build.gradle.kts:148-174` ile birebir), host `login-callback`. Sabit yazma.
  - [ ] `resetPasswordForEmail(safe, redirectTo: …)`; in_memory implementasyonu arayüzle uyumlu kalsın.
  - [ ] **ADR-5:** Android deep link + **her platformda çalışan e-posta kodu (OTP) yolu** (Windows'ta protokol kaydı yok, portable ZIP'te de çalışmalı). Android akışı **değişmez**.
  - [ ] 🆕 **OTP tek başına istemci işi değil:** recovery e-posta şablonuna **`{{ .Token }}`** eklenmeli (yoksa kullanıcıya kod hiç gitmez) + istemcide `verifyOTP(..., type: recovery)` + kod giriş ekranı.
  - [ ] 🆕 **Yeniden gönder + hız sınırı** davranışı: art arda istekte kullanıcıya bekleme süresi söylenir.
  - [ ] 🔒 🆕 **Kullanıcı varlığını açığa vurmama:** e-posta kayıtlı olsa da olmasa da **aynı nötr mesaj** döner (user-enumeration koruması). Mevcut `sendPasswordResetEmail` davranışı için de test edilir.
  - [ ] Ops runbook: staging + production panelinde **Redirect URL allowlist + Site URL + recovery şablonu `{{ .Token }}`** (**sahip uygulayacak**).
  - [ ] Kırmızı-yeşil test: `redirectTo` olmadan çağrıyı yakalayan regresyon testi.
- **Veri/Migration etkisi:** Yok. **Supabase panel yapılandırması var** (kod dışı, üç adım).
- **Ortam/Deploy:** Kod local; panel adımları staging **ve** production auth ayarı → sahip yapar.
- **RLS/Güvenlik:** Redirect allowlist'e **yalnız uygulama scheme'leri**; joker/üçüncü taraf domain **yok** (open-redirect riski). Token/kod hiçbir log'a, Sentry breadcrumb'ına veya kullanıcı yanıtına yazılmaz. User-enumeration koruması test edilir.
- **Edge-case'ler:** Süresi dolmuş link/kod · link veya kod iki kez kullanılması · uygulama kapalıyken tıklama (cold start → `auth_gate.dart:39`) · beta linkinin stable uygulamayı açması (scheme ayrımı çözüyor) · kullanıcı e-postayı bilgisayarda açıyor telefonu yanında (kod yolu çözer) · Windows (kod yolu).
- **Kabul (ölçülebilir):** (1) **Android:** şifremi unuttum → e-posta → linke dokun → uygulama açılır → `RecoveryScreen` → yeni şifre → **yeni şifreyle giriş başarılı**. (2) **Windows:** kod ile aynı sonuç. (3) Kayıtlı olmayan e-postada da aynı nötr mesaj. (4) `redirectTo`'suz çağrıda test kırmızı. `Cihazda doğrulanmalı`.
- **Tuzaklar:** Scheme'i sabit yazıp beta/stable'ı karıştırmak · yalnız kodu düzeltip panel adımlarını atlamak (kullanıcı için düzelmez) · **şablona `{{ .Token }}` eklemeden OTP yolunu "bitti" saymak** · `config.toml`'u değiştirip hosted projeyi düzelttiğini sanmak · hata mesajında hesabın varlığını sızdırmak.
- **Model önerisi:** 🟣 Pro

### WP-288: Tema modeli genişletmesi, yerel saklama v2 ve göç 🗄️
- **Program/Faz:** Yeni Özellik Turu · Aşama A · Tema programı · (plan §3 F-04-A, ADR-1 rev.2/2/3/7/8)
- **Ajan:** — · **Durum:** [ ] Bekliyor · **Bağımlılık:** 🔄 **WP-289** (`AppFeel` alanlarını 289'un kataloğu belirler — rev.2'de sıra ters çevrildi)
- **Problem:** Özel tema bugün yalnız **4 renk** tutuyor (`AppPalette` — `app_theme.dart:22-27`) ve **silme yok**. Sahip: 3 yuva, her yuvada tam tema (renk+yazı+biçim+atmosfer+his), **düzenleme ve silme**. Saklama **cihazda kalacak** (10. tur kararı — sunucu senkronu iptal).
- **Kapsam dışı:** Sihirbaz UI (WP-290), sunucu tablosu/migration/RLS (**iptal edildi**), cihazlar arası senkron, tema paylaşma, XP ile kilitleme, widget/bildirim teması.
- **SAHİP dosyalar (yaz):** `app/lib/core/theme/custom_theme.dart` (yeni), `app/lib/core/theme/theme_settings.dart`, `app/lib/core/theme/theme_tokens.dart`, `app/lib/core/theme/app_theme.dart` (`extensions:` listesi), `app/lib/main.dart` (tema karar akışı), ilgili testler.
- **DOKUNMA:** `app/lib/features/profile/**` (UI WP-290'ın), `app/pubspec.yaml` (font WP-290'ın), `supabase/**` (bu WP'nin sunucu işi YOK), `AndroidManifest.xml`.
- **Adımlar:**
  - [ ] 🔄 **ADR-1 rev.2 — İKİ RENK VARYANTI.** `CustomTheme`: `id` (custom_1/2/3 — **index sabit**), `name`, `isDefined`, `updatedAt`, **`lightColors` + `darkColors` (ikisi de tam `AppColors`)**, ortak tipografi/şekil/atmosfer/his. ⚠️ Tek renk seti **yetmez**: `fromFamily:197-228` karşı modda `AppColors.fromScheme` ile metin/kenarlığı türetiyor → kullanıcının seçtiği yazı ve kenarlık rengi karşı modda **çöpe gider** (R16).
  - [ ] `core/theme/brightness_derivation.dart` — karşı varyantı üreten **saf fonksiyon** (test edilir). Kullanıcı bir varyantı kurar, diğeri türetilir ve **düzenlenebilir sunulur**.
  - [ ] `AppTheme.fromCustomTokens({colors, typography, shapes, atmosphere, feel, brightness})` — mevcut `_buildFromTokens:297` üzerine ince sarmalayıcı. ⚠️ `fromPreset` **kullanılmaz**: `ThemePreset` tipografiyi yalnız iki bool ile taşıyor, font ailesi/ağırlık/aralık/ölçek sözleşmesini taşıyamaz; genişletmek `kThemePresets:90` listesini de kırar.
  - [ ] 🔴 **TextTheme 13/13.** Bugün `app_theme.dart:414-418` yalnız 4 slot dolduruyor (`displayLarge`, `titleLarge`, `bodyMedium`, `labelMedium`); uygulama 13 slot kullanıyor → **90/375 = %24 kapsama**. Font seçimi yüzeylerin **%76'sında etkisiz** kalır (R17). `buildTextTheme(AppTypography, AppColors)` saf fonksiyonu ile 13 slot token'dan üretilir. ⚠️ Bu tüm uygulamanın tipografisine dokunur → hazır preset/palet görüntüsü kaymamalı, **mevcut golden'lar güvenlik ağıdır**.
  - [ ] `AppTypography` genişlet: font aileleri (başlık/gövde/sayaç), ağırlıklar, harf aralığı, ölçek. **`copyWith` ve `lerp` mutlaka güncellenir** (R4).
  - [ ] `AppFeel` katmanı — **alanları WP-289 kataloğundan gelir** + **`app_theme.dart:338` `extensions:` listesine ekle** (R3 — eklenmezse seçim ölü anahtar olur).
  - [ ] Saklama: `custom_themes_v2`, `active_custom_theme_id`, `custom_themes_migrated_v1`. Eski `custom_palettes` **okunur, silinmez, yazılmaz**.
  - [ ] 🆕 **ADR-7:** `saveCustomTheme` / `deleteCustomTheme` / `setActiveCustomTheme` **`Future<ThemeSaveResult>`** döner. ⚠️ Bugün `theme_settings.dart:144` `prefs.setStringList(...)`'i **`await` etmeden** çağırıp `void` dönüyor → hata durumunda kullanıcı "kaydedildi" görür, 7 adımlık emeği sessizce kaybolur (R21).
  - [ ] 🆕 **ADR-8:** okunan kaydın `schemaVersion`'ı uygulamanınkinden **büyükse** o tema **salt-okunur** işaretlenir (uygulanır ama üzerine yazılmaz), UI net söyler. ⚠️ Beta ve stable yan yana kurulu (`AGENTS.md §4.1`); eski sürüm yeni şemayı okuyup geri yazarsa tanımadığı alanları **siler** (R22).
  - [ ] `deleteCustomTheme(slot)` **index kaydırmaz**, yuvayı boşaltır (R2).
  - [ ] `main.dart:160-166` üç yollu: **özel tema > palet > aile** (ADR-3).
  - [ ] **Göç:** eski 4 renk aynı index'e; kalan alanlar **o an seçili preset'ten devralınır** (görüntü değişmesin). İdempotent, bayraklı.
- **Veri/Migration etkisi:** **Yok** — sunucu şeması değişmiyor. Yalnız yerel `SharedPreferences` şeması v2. Geri alma: yeni anahtarlar silinir, eski `custom_palettes` yerinde olduğu için kullanıcı eski durumuna döner.
- **Ortam/Deploy:** Local. Production/staging dokunuşu **yok**.
- **RLS/Güvenlik:** Yok (sunucuya veri gitmiyor). Sır/token yok.
- **Edge-case'ler:** Bozuk JSON (o yuva boş, çökmez) · **ileri `schemaVersion` (salt-okunur, sessiz yeniden yazma yok)** · 3 yuva dolu · aktif tema silinmiş (palet/aile yoluna güvenli dönüş) · yeni kurulum (3 boş yuva) · göç iki kez çalışıyor · **kayıt başarısız (disk/platform) → kullanıcıya söylenir**.
- **Kabul (ölçülebilir):** Göç sonrası kullanıcının gördüğü tema **değişmez** (golden) · göç idempotent · **açık, koyu ve sistem modu ayrı ayrı doğrulanır** · `textTheme` slot kapsaması **13/13** · "font değişti → ekranda başlık+gövde+etiket gerçekten değişti" regresyon testi yeşil · silme index kaydırmaz · aktif silinince çökme 0 · 3'ten fazla tema oluşturulamaz · bozuk veride açılış çökmesi 0 · ileri şema salt-okunur · kayıt hatası UI'da görünür · her yeni token seçimi **gerçek etki üretir** (ölü anahtar yok) · `flutter analyze` 0, testler yeşil.
- **Tuzaklar:** Tek renk seti ile açık/koyu üretmeye çalışmak (R16) · `TextTheme`'i 4 slotta bırakıp "%95 yüzey" iddia etmek (R17) · `extensions:` listesine yeni katmanı eklememek (R3) · `copyWith`/`lerp`'i güncellememek (R4) · kaydı `await`siz bırakmak (R21) · ileri şemayı sessizce yeniden yazmak (R22) · göç yazmadan modeli değiştirmek (R1) · **Riverpod 3:** dinleyicisiz provider her `read`'de yeniden build olur → testte `container.listen(...)` açılmazsa regresyon testi sessizce etkisiz kalır (R13) · `main.dart` sıcak dosya, aynı anda başka WP girmemeli.
- **Model önerisi:** 🔴 Opus

### WP-289: Animasyon/his araştırma turu, katalog ve `AppFeel` şema kararı 🔍
- **Program/Faz:** Yeni Özellik Turu · Aşama A · (plan §3 F-04-C)
- **Ajan:** — · **Durum:** [ ] Bekliyor · 🔄 **WP-288'DEN ÖNCE** (rev.2)
- **Problem:** Sahip tema "hissi" için oyun/uygulama örneklerinden ilham istedi ama hangi efektlerin gireceği belirsiz. **Daha kritiği:** `AppFeel` katmanının **alanlarını** bu katalog belirler — 288 bu şemayı yazacağı için 289 **önce** bitmeli. (İlk planda 288 → 289 sırası vardı, döngüsel bağımlılıktı; rev.2'de düzeltildi.)
- **Kapsam dışı:** Kod yazma, asset üretme, tema motoru.
- **SAHİP dosyalar (yaz):** `docs/TEMA-HIS-KATALOGU.md` (yeni), `docs/YENI-OZELLIK-PLANI.md` §3 F-04-C güncellemesi.
- **DOKUNMA:** Tüm kod dosyaları (bu WP kod yazmaz).
- **Adımlar:**
  - [ ] Yaygın tema/kişiselleştirme uygulamalarında ve oyunlarda kullanılan "his" ailelerini derle.
  - [ ] Her aile için: hangi token'larla ifade edilir (renk/şekil/atmosfer/hareket), Flutter'da maliyeti ne, performans riski ne.
  - [ ] Erişilebilirlik: "hareketi azalt" ile nasıl davranır.
  - [ ] Sahibe **kısa liste** sun; K-3 kararı birlikte verilir.
  - [ ] 🆕 **`AppFeel` şema önerisi yaz:** seçilen hisleri ifade etmek için hangi alanlar gerekiyor (ör. `feelId`, `grainStrength`, `edgeIrregularity`, `motion`). WP-288 bunu birebir uygular.
- **Veri/Migration etkisi:** Yok. **Ortam/Deploy:** Yok. **RLS/Güvenlik:** Yok.
- **Edge-case'ler:** Düşük donanımlı cihazda kare düşmesi · blur/gölge/shader maliyeti · koyu/açık modda aynı efektin farklı görünmesi · "hareketi azalt" açıkken davranış.
- **Kabul (ölçülebilir):** Katalogda her his ailesi için token karşılığı + maliyet notu + erişilebilirlik notu var · **`AppFeel` alan listesi kesinleşti** (288 bunsuz başlamaz) · sahip kısa listeden seçim yapabildi.
- **Tuzaklar:** Telif korumalı görsel/asset kopyalamak — **yalnız fikir/teknik desen alınır**, varlık kopyalanmaz.
- **Model önerisi:** 🔵 Sonnet

### WP-290: "Kendi Temanı Oluştur" sihirbazı ve görünüm ekranı yeniden düzeni 🎨
- **Program/Faz:** Yeni Özellik Turu · Aşama A · Tema programı · (plan §3 F-04-B)
- **Ajan:** — · **Durum:** [ ] Bekliyor · **Bağımlılık:** WP-288 kabul (289 zaten 288'in girdisi)
- **Problem:** Görünüm ekranı bugün "renk seçimi" gibi duruyor; kullanıcı arka plan/yazı/font/şekil/atmosferi tek tek seçemiyor. Sahip adım adım, canlı önizlemeli bir oluşturucu istiyor. Ayrıca **3 yuva için düzenleme ve silme** UI'ı gerekiyor (10. tur).
- **Kapsam dışı:** Tema paylaşma/kod ile aktarma, XP ile kilit, widget/bildirim teması, yeni ekonomi kuralı, sunucu senkronu (iptal).
- **SAHİP dosyalar (yaz):** `app/lib/features/profile/appearance_screen.dart`, `app/lib/features/profile/theme_studio_screen.dart` (**kaldırılacak**), yeni sihirbaz dosyaları `app/lib/features/profile/theme_builder/**`, `app/lib/core/theme/theme_tokens.dart` (tipografi/his genişletmesi), `app/pubspec.yaml` (font asset'leri), `app/assets/fonts/**`, `app/lib/l10n/app_*.arb`, golden + widget testleri.
- **DOKUNMA:** `supabase/migrations/**`, `app/lib/core/navigation/**`, bildirim/timer kodu.
- **Adımlar:**
  - [ ] Ekran düzeni: en üstte **"Kendi Temanı Oluştur"** girişi → kullanıcının temaları (**en yeni en üstte**, `updatedAt` desc) → **ince ayraç çizgi (başlık metni yok)** → hazır temalar.
  - [ ] Her tema satırında **düzenle (✎)** ve **sil (🗑)**; silme **onay dialogu** ister. 3 yuva doluysa "oluştur" yerine net mesaj.
  - [ ] 7 adımlı sihirbaz: zemin → renkler → yazılar → biçim → atmosfer → his → özet/ad ver.
  - [ ] 🆕 **Karşı mod adımı:** kullanıcı bir varyantı kurar, diğeri türetilir ve **düzenlenebilir gösterilir** ("koyu modu da ayarla"). ADR-1 rev.2.
  - [ ] Her adımda **canlı önizleme** (mevcut `_LivePreview` — `theme_studio_screen.dart:482` — taşınıp genişletilir, sıfırdan yazılmaz).
  - [ ] Kontrast koruması: AA altı seçimde uyarı + tek dokunuşla düzeltme (kaydetmeyi engelleme).
  - [ ] **ADR-4:** fontlar `app/assets/fonts/**` altına paketlenir (`google_fonts` **kullanılmaz**). Yalnız SIL OFL / Apache-2.0; lisans metinleri `assets/fonts/LICENSES/`. Subset: Latin + Latin-Ext (Türkçe dahil). **`fontFamilyFallback` zorunlu** — AR locale'de kutu karakter olmasın (R7).
  - [ ] Eski `ThemeStudioScreen` **kaldırılır**; işe yarar parçalar taşınır. `custom_palette_editor.dart` gereksizleşir → kaldırılır. Eski `family`/`palette` seçimleri kırılmaz.
- **Veri/Migration etkisi:** Yok (model ve saklama WP-288'de). Yeni alan eklenirse `schemaVersion` korunur.
- **Ortam/Deploy:** Local. Sunucu/production dokunuşu yok.
- **RLS/Güvenlik:** Sunucuya veri gitmiyor. **Font asset lisansları tek tek doğrulanır.**
- **Edge-case'ler:** Hiç tema yokken sade boş durum daveti (3 boş yuva **gösterilmez** — 4. turda düşürüldü) · çok uzun tema adı (≤ 24 karakter) · okunamaz renk seçimi · sihirbaz yarıda bırakılıyor (kaydedilmemiş değişiklik uyarısı) · açık/koyu geçişi · masaüstünde sol kontrol + sağ sabit önizleme · RTL (AR) · "hareketi azalt" açıkken his efektleri durur · font yüklenemedi (fallback).
- **Kabul (ölçülebilir):** Her adımda değişiklik önizlemede ≤ 1 kare içinde görünür · kaydedilen tema uygulamanın ≥ %95 yüzeyinde token'dan uygulanır · AA altı kontrastta uyarı çıkar · kaydedilen/düzenlenen tema listenin en üstünde · silme onay ister ve sonrası çökme 0 · 3 temsili tema × açık/koyu = 6 golden yeşil · **APK boyut artışı ≤ 2.5 MB** (`--analyze-size` kanıtı) · 4 dilde anahtar tam, AR'de kutu karakter yok.
- **Tuzaklar:** Sihirbazı ekran başlıklarıyla şişirmek (sahip **sade** istedi) · `pubspec.yaml` ve `core/theme/**` sıcak dosya — aynı anda başka WP girmemeli · font paket boyutunu kontrolsüz büyütmek · AR fallback zincirini atlamak · eski kullanıcının seçili temasını bozmak.
- **Model önerisi:** 🔴 Opus

### WP-291: Ana sayfa kart boyut paneli → sabit alt panel 📐
- **Program/Faz:** Yeni Özellik Turu · Aşama A · (plan §3 F-05)
- **Ajan:** — · **Durum:** [ ] Bekliyor
- **Problem:** `_SizePanel` (`home_screen.dart:818`) grid'in altına akış içinde çiziliyor (`:487`) ve tüm gövde tek `SingleChildScrollView` içinde (`:87`). Kart aşağıdaysa panel ekrandan çıkıyor; kullanıcı sürekli aşağı yukarı kaydırmak zorunda kalıyor.
- **Kapsam dışı:** Saydamlık ayarı (**eklenmeyecek**), yeni kart türü, ızgara motoru değişikliği, tema.
- **SAHİP dosyalar (yaz):** `app/lib/features/home/home_screen.dart`, gerekiyorsa `app/lib/features/home/widgets/**` yeni panel dosyası, ilgili widget testleri.
- **DOKUNMA:** `app/lib/features/home/dashboard_providers.dart` (düzen motoru — okunur, davranışı değiştirilmez), tema, navigation.
- **Adımlar:**
  - [ ] Seçili kart state'i (`_MatrixGridState._selected`, `:300`) yukarı taşınır; grid bildirir, panel dinler.
  - [ ] `_SizePanel` `Scaffold.bottomSheet`'e bağlanır — **yalnız `_editing == true` iken** (HomeScreen kendi Scaffold'una sahip: `:161` ve `:210`).
  - [ ] Kapalı ~72 dp ince şerit (boyut), yukarı çekilince genişleyen panel (Seçenek C).
  - [ ] Grid altına panel yüksekliği kadar boşluk — son kart panelin altında kalmasın.
  - [ ] Masaüstünde dar/köşeye hizalı varyant.
- **Veri/Migration etkisi:** Yok. **Ortam/Deploy:** Local.
- **RLS/Güvenlik:** Yok.
- **Edge-case'ler:** Düzen boş → panel yok · seçili kart silinir → `_effectiveSelected()` (`:312`) ilk karta düşer · klavye açık (`viewInsets`) · düzenleme modundan çıkış · çok küçük ekran · masaüstü geniş pencere.
- **Kabul (ölçülebilir):** Düzenleme modunda sayfa en alta kaydırılsa bile panel ekranda kalır · kapalı yükseklik ≤ 80 dp, açık ≤ ekranın %40'ı · boyut değişince kart ≤ 1 kare içinde güncellenir · panel yüzünden erişilemez kart kalmaz · dokunma hedefleri ≥ 48 dp.
- **Tuzaklar:** Seçim state'ini yukarı taşırken sürükle-bırak davranışını bozmak · panel yüzünden son kartın kapanması · `_editing` kapanınca panelin ekranda kalması.
- **Model önerisi:** 🟣 Pro

### WP-292: Kozmetik — taç görseli ✨
- **Program/Faz:** Yeni Özellik Turu · Aşama A (son) · (plan §3 F-08) · *rev.2: kamp ateşi WP-295'e ayrıldı*
- **Ajan:** — · **Durum:** [ ] Bekliyor · **Bağımlılık:** WP-290 kabul
- **Problem:** Profil fotoğrafı üstündeki taç sahibe göre kötü duruyor; görsel yenilenecek.
- **Kapsam dışı:** **XP/kademe mantığı**, başarım motoru, tema motoru, yeni ekonomi kuralı, kamp ateşi (WP-295).
- **SAHİP dosyalar (yaz):** `app/lib/core/widgets/crowned_avatar.dart`, `app/lib/core/widgets/crown_tiers_sheet.dart`, ilgili golden testler.
- **DOKUNMA:** 🔴 `app/lib/core/stats/achievement_ledger_engine.dart` — **`crownRankForXp:358` ve `kCrownXpThresholds` DEĞİŞTİRİLMEZ**; taç XP'den türer ve XP server-authoritative'dir (`AGENTS.md §2`). Eşiğe dokunmak kullanıcıların görünen kademesini sessizce kaydırır. Ayrıca: sunucu tarafı, tema motoru, `campfire*` (WP-295'in).
- **Adımlar:**
  - [ ] Taç çizim katmanı yenilenir; **kademe→görsel eşlemesi birebir korunur**.
  - [ ] Golden testler güncellenir; performans (kare düşmesi) kontrol edilir.
- **Veri/Migration etkisi:** Yok. **Ortam/Deploy:** Local. **RLS/Güvenlik:** Yok.
- **Edge-case'ler:** Taçsız kullanıcı (rank null/boş — `crowned_avatar.dart:29`) · en yüksek kademe · küçük avatar boyutları · "hareketi azalt" açık · düşük donanım.
- **Kabul (ölçülebilir):** **Aynı XP → aynı kademe** (regresyon testi yeşil) · taçsız durumda düz avatar · golden yeşil · "hareketi azalt" açıkken animasyon durur.
- **Tuzaklar:** Görsel değişiklik sırasında kademe eşiğini kaydırmak (kullanıcıların tacı sessizce değişir) · ağır efektle kare düşürmek.
- **Model önerisi:** 🟣 Pro

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

## Worker'a Verilecek Kısa Komutlar

Yeni özellik turu — **dalga sırasıyla** (rev. 2):
- **ÖNCE:** `worker'ı oku ve WP-293'ü yap` — Gate 0, ortam uzlaştırma (**bu bitmeden diğerleri başlamaz**)
- Dalga 1: `worker'ı oku ve WP-287'yi yap` · `worker'ı oku ve WP-286'yı yap`
- Dalga 2: `worker'ı oku ve WP-291'i yap` · `worker'ı oku ve WP-289'u yap`
- Dalga 3: `worker'ı oku ve WP-288'i yap` (289 bitmiş olmalı) · `worker'ı oku ve WP-294'ü yap`
- Dalga 4: `worker'ı oku ve WP-290'ı yap`
- Dalga 5: `worker'ı oku ve WP-292'yi yap` · WP-295 için **önce sahiple kamp ateşi konuşması**

Önceki tur:
- `worker'ı oku ve WP-276'yı yap` · `worker'ı oku ve WP-277'yi yap`
- WP-278/279 için önce ürün/ops kararı alınır.

> Her worker önce Aktif Çalışma Kaydı'nı okur, kendi lane'ini claim eder ve SAHİP yolları çakışıyorsa başlamaz. Production/stable hiçbir WP'nin örtük parçası değildir.
