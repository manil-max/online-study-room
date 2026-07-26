# progress.md — Canlı Durum

> Son güncelleme: **2026-07-26** · Saat dilimi: **Europe/Istanbul**
>
> 🧭 **BU DOSYA TEK GÜNCEL KAYNAKTIR** (sahip kararı, 2026-07-26). Yol haritası,
> açık kararlar, QA kuyruğu ve aktif iş — hepsi burada. `docs/PLAN.md` artık
> yalnız buraya işaret eden bir sapıdır; iki dosyada iki farklı gerçek olmaz.
>
> 🔴 **Sürüm politikası (2026-07-26):** tag oluşturma ve release tetikleme **sahip
> onayına bağlıdır**. Commit/push serbest; düzeltmeler biriktirilip tek sürümde çıkar.
>
> 🧱 **Yapı:** iş **fazlara** bölünür, her fazın altında **WP kartları** durur
> (`.agents/skills/planner/SKILL.md` sözleşmesi). Faz = "neredeyiz", WP = "kim
> neyi yazacak, nereye dokunmayacak, kabul ne".
>
> **Okuma sırası:** `⚡ Aktif Çalışma Kaydı` → `🗺️ Yol Haritası` (fazlar + WP'ler) →
> `✅ Kapanan Kararlar` → `🧪 Cihaz QA Kuyruğu` → (altı: tarihsel WP kayıtları).

## Proje Gerçekleri

- **Ortam durum modeli (WP-293, 2026-07-24 uzlaştırıldı) — altı ayrı gerçek, tek sayıya indirilmez:**
  1. Repo/local migration zinciri: **`0071`** (`supabase/migrations/` son dosya) — 🔴 **0071 hiçbir ortama uygulanmadı** (grup üye sınırı 8).
  2. Staging uygulanmış head: **`0070`**.
  3. Production **etkin şema**: **`0070`** — `0066–0070` manuel uygulandı; Database Gates + Production Push Activation koşumları başarılı (2026-07-23).
  4. Production **CLI migration history**: **legacy / uzlaştırılmamış** — `supabase_migrations.schema_migrations` relation'ı production'da yok ([`docs/recovery/PRODUCTION-BASELINE.md`](docs/recovery/PRODUCTION-BASELINE.md) §3).
  5. Deploy contract hedef/izin head: **`0070`**; production `deploy_enabled` terfi tamamlandığı için **yeniden `false`** kilitlendi.
  6. Stable **v45** artefakt manifesti: tarihsel **`0065`** (production sonradan `0070`e yükseldi).
- **Stable/production:** v45 yayında, etkin şema `0070`. Yeni production migration, Edge deploy veya stable tag/release yalnız ayrı, somut kullanıcı GO + backup + dry-run ile yapılır; deploy kapısı kilitli.
- **Beta/staging:** beta-v4308 staging `0070` üzerinde yayında. Proje sahibi 2026-07-24'te stable+beta yayınını ve bildirim/sayaç davranışını cihazda test etti; genel sorun yok, **önceki turun** (WP-269–285) bekleyen cihaz kabulleri kapatıldı. ⚠️ Aşama A'nın yeni kabulleri **henüz yayınlanmış bir artefakta girmedi** — QA kuyruğu yeni beta build gerektiriyor.
- **Release ilkesi:** Android beta/stable artefaktı Android işi başarılı olunca yayımlanır. Windows bağımsız sürer ve başarılı olursa aynı release'e eklenir; Windows hatası Android güncellemesini geri çekmez.
- 🔴 **BETA KARARI **GÜNCELLENDİ** (sahip, 2026-07-25, aynı gün ikinci karar — `§0.1`): **İKİ beta olacak.** **Beta 1 = kapanmış 9 WP, hemen** (WP-295 beklenmez); beta 1 test edilirken WP-295+299+300 kodlanır → **beta 2** (admin işleri orada) → stable. Sahip kamp ateşi isteğinin sandığından büyük olduğunu görünce sırayı kendisi değiştirdi. Ek gerekçe: kamp ateşinin `p95 ≤ 16.7 ms` bütçesi beta 1 cihaz turu olmadan **ölçülemiyordu.** Aşağıdaki "tek beta" ifadeleri **tarihsel**; bir sonraki maddedeki sonuçlar (kod/test kapısı esas, her WP ayrı commit) aynen geçerli.
- 🕰️ *Tarihsel — üstteki karar bunu değiştirdi:* **Aşama A'nın TÜM WP'leri bitmeden beta çıkmaz — tek beta turu yapılacak.** Gerekçe: beta koşumu ~3 saat sürüyor, iki tur yapılmıyor. **Sonuçları:** (1) "önce X'in cihaz kabulü" yazan yazılı kapılar bu tur için **geçersiz** — cihaz QA'sı fiziken mümkün değil, kod/test kapısı esas alınır (`.agents/AGENTS.md §0.1`); (2) QA kuyruğundaki 6 iş **aynı beta'da** test edilir; (3) bir sorun görülürse hangi WP'den geldiği belirsiz olacağı için her WP **ayrı commit** + `analyze` 0 + testler yeşil şartı **daha da kritik**.
- **Yönetim varsayılanı:** Production `deploy_enabled/release_enabled` kapalıdır. Stable yalnız protected `production` Environment, exact SHA/head/project-ref GO ve reviewer kanıtıyla ilerler.
- **Kurallar:** Kök `AGENTS.md`, `.agents/AGENTS.md` ve `docs/KALITE-PROGRAMI.md` geçerlidir. Tek çalışma dalı `main`; her WP ayrı commit; production varsayılmaz.
- **Son WP numarası:** **329** · Sıradaki boş numara: **330**. (315 kullanıldı ve kapandı; 316–329 yol haritasında kart olarak açık. Faz F için eski **WP-295** ve **WP-299** kartları geçerliliğini koruyor; **WP-300** ve **WP-301** iptal edildi — gerekçe aşağıda.)
- **Aktif tur:** **Faz B** (admin & geri bildirim döngüsü) — WP-316 · WP-317 · WP-318.
- ✅ **Ortam gerçeği uzlaştırıldı (WP-293, 2026-07-24):** yukarıdaki altı gerçekli durum modeli kanoniktir; production deploy kapısı yeniden kilitlendi. `deploy-contract.json`, `KALITE-PROGRAMI.md`, `project.md`, `backlog.md`, `tooling/README.md` aynı gerçeğe getirildi.

## ⚡ Aktif Çalışma Kaydı

### Gemini Lane
- **Durum:** [x] Boşta
- **Faz/WP:** —
- **SAHİP yollar:** —

### Claude Lane
- **Durum:** [~] Aktif · **Aşama:** Geliştiriliyor · **Dal:** `main`
- **Faz/WP:** **WP-319** — Şifre değiştirme + sıfırlama (Faz C) · **Başlangıç:** 2026-07-26 (Europe/Istanbul) · **Son güncelleme:** 2026-07-26
- **SAHİP yollar:**
  - `app/lib/features/profile/account_settings_screen.dart`
  - `app/lib/data/repositories/auth_repository.dart` · `app/lib/data/repositories/supabase/supabase_auth_repository.dart` · `app/lib/data/repositories/in_memory/in_memory_auth_repository.dart`
  - `app/lib/l10n/app_{en,tr,de,ar}.arb` + üretilen `app_localizations*.dart`
  - `app/test/data/auth_repository_test.dart` · `app/test/features/profile/change_password_test.dart` (yeni)
- **Ortak/riskli yüzey:** 🟡 **yalnız `app/lib/l10n/*.arb`.** WP-317'nin SAHİP listesinde l10n **yok** ama admin yanıt UI'ı metin isteyecektir. Codex arb'ye girecekse **haber versin, seri koşarız**; arb düzenlemem eklemeli ve tek turda yapılıyor. Kesişmeyen yüzeyler: `app/lib/features/admin/**`, `supabase_admin_repository.dart`, `supabase/migrations/**`, `supabase/tests/**` — **hiçbirine girilmiyor**.
- **Not:** Kartın "şifre değiştirme hiç yok" iddiası **yanlış** — var ([account_settings_screen.dart:113](app/lib/features/profile/account_settings_screen.dart:113)) ama yalnız "yeni şifre" soruyor, mevcut şifreyi **hiç doğrulamıyor**. Yani kartın kendi uyardığı **ölü anahtar** zaten üretimde. Gerçek iş: doğrulamayı eklemek.
- ✅ **WP-322 (2026-07-26)** — Faz B ile paralel koştu, Codex WP-316 ile **kesişim olmadı** (`pubspec.yaml`'a hiç girilmedi, `supabase/migrations/**`'e dokunulmadı). `flutter analyze` temiz · **10 ardışık tam suit koşumu 10/10 yeşil, her turda 820 test** · kararsızlık için kırmızı-yeşil kanıt alındı. Kartın passkeys ve sürüm maddeleri **konusuz** çıktı (gerekçe kartta).
- 🟡 **Sahibe açık kalan tek soru:** `pubspec.yaml`'daki `version: 1.0.43-beta.9+4309` yayınlanan etiketlerle uyumsuz ama **hiçbir mağaza paketine ulaşmıyor** (sürüm etiketten türetiliyor). Kozmetik hijyen olarak hizalansın mı, yoksa öyle mi kalsın? Sürüm politikası "onaysız dokunma" dediği için **bekletildi**.
- ✅ **v49 git tag'i silindi (2026-07-26 11:49, sahip emri):** uzak (`origin`) + yerel. Karşılığında release yoktu; sıradaki sürüm o numarayı temiz kullanabilir.
- ✅ **2026-07-26:** grup üye sınırı **8** kodlandı (`0071_group_member_limit_8.sql` + Dart sabitleri + 4 test). `analyze` temiz, 815 test yeşil, 51 deploy guard testi yeşil. 🔴 **Migration hiçbir ortama uygulanmadı.**
- ✅ **2026-07-26:** yol haritası `docs/PLAN.md`'den **bu dosyaya** taşındı (sahip kararı: tek güncel kaynak). PLAN.md sapa indirildi.
- ✅ **BETA 1 YAYINDA — `beta-v4309`, 2026-07-25 15:30 UTC.** Release Orchestrator run `30163316180`: preflight · android · windows/build · finalize_android · release_status · finalize_complete **hepsi success**. Varlıklar: `app-beta-release.apk` (77.8 MB) + sha1/sha256 · `odak-kampi-windows-beta.msix` (23.3 MB) · `odak-kampi-windows-beta.zip` (42.4 MB) + sha256'lar · `release-manifest.json`. Sürüm `1.0.43-beta.9+4309`, staging backend, migration head `0070`. **Android + Windows ikisi de çıktı.**
- **Son not:** 2026-07-25 turunda **WP-296, WP-297, WP-292, WP-298 ve WP-294** tamam — `analyze` 0, **793 test yeşil**. Taç geometrisi sahip onayıyla sabitlendi (**5 uç · span 50° · tip 1.63 · inci 0.10 · kavis 0.50**), aura kademeye göre ölçekli.
- ✅ **WP-298 açık sorusu kapandı (sahip, 2026-07-25):** "altından itibaren" = **altın kademe (3.)**. Kod doğru; bronz/gümüşte aura yok, değişiklik yapılmadı.
- ✅ **WP-295 sahip konuşması YAPILDI (2026-07-25) — blokaj kalktı.** Kararlar: [notlar F-09](docs/YENI-OZELLIK-NOTLARI.md). Tasarımcıya para verilmiyor (hayvanlar vektör kalıyor); istek üçe bölündü → **WP-295** (oturma yayları + 2 poz) · **WP-299** (gündüz/gece gökyüzü + gece uyuma) · **WP-300** (`groups.location`). Ayrıca 🔴 **WP-301** açıldı: günlük metrik gün sınırı sunucuda `Europe/Istanbul`'a sabitli ([0053:87](supabase/migrations/0053_group_achievement_metrics.sql:87)) — kamp ateşinden ayrı yürür.
- 🔴 **Yürütme sırası (sahip kararı, 2026-07-25):** **beta 1 ŞİMDİ** (kapanmış 9 WP cihazda test edilsin) → beta 1 test edilirken **WP-295 + 299 + 300** kodlanır → **beta 2** (admin işleri de burada) → sorun çıkmazsa **stable**. Kamp ateşinin `p95 ≤ 16.7 ms` bütçesi beta 1 cihaz turunda ölçülür; o ölçüm olmadan gökyüzü + sürekli marşmelov körlemesine yazılırdı.
- ✅ **Sahip yetkisi (2026-07-25):** "migration'ları sen yapabilirsin, benlik ne var" → migration **yazma ve uygulama** (staging + production) Claude'da; `Database Gates` repo secret'larıyla koşuyor, GitHub environment'larında zorunlu onaylayıcı yok. Production'da yine **dry-run + backup** koşulur ve **satır sayılarıyla raporlanır** (`§0.1` soru sormamaya izin verdi, kanıt üretmemeye değil).
- 🔴 **beta-v4309 hazırlığında yakalanan yayın tuzağı (2026-07-25) — kalıcı ders.** Repoda **hiçbir genel CI yoktu**; tam test paketi yalnız release job'ının içinde koşuyordu, yani `main`'e giren bir kırmızı ancak tag atıldığında görülüyordu. `beta-v4304`/`beta-v4305` tam bu yüzden düşmüştü ([nihai rapor](docs/BETA-YAYIN-ARIZA-NIHAI-RAPORU-2026-07-23.md)). Somut risk: **13 golden PNG'nin hepsi 2026-07-24/25'te eklendi** (WP-288/290/292/298), son başarılı release ise 07-23 → goldenlar **ubuntu'da hiç koşmamıştı**, release job'ı ise ubuntu.
  - **Tag atmadan önce** [`ci.yml`](.github/workflows/ci.yml) eklenip `main`'e push edildi: **781 geçti, 12 düştü** (run `30162826092`) — hepsi golden, **%0.12–%0.14** raster farkı. Yani beta-v4309 doğrudan tag'lenirse **üst üste üçüncü başarısız yayın** olurdu.
  - **Çözüm:** [`app/test/flutter_test_config.dart`](app/test/flutter_test_config.dart) — golden karşılaştırmasına **%0.5** platform payı (ölçülen sapmanın ~3.5 katı). ⚠️ **Bu sayı bir goldenı yeşile almak için yükseltilmez.**
  - **Kırmızı-yeşil kanıtı:** `crown_golden_test.dart`'ta yarıçap **44 → 43** yapıldı → golden **%14.41 / 182 106 px** farkla düştü (sınırın **29 katı**, platform payının ~100 katı). Yani pay gerçek bir görsel değişikliği gizlemiyor. Sonda geri alındı.
- ✅ **WP-287 staging panel adımı OTOMATİKLEŞTİ (2026-07-25).** Panel yerine [`supabase-auth-config.yml`](.github/workflows/supabase-auth-config.yml): Management API ile yalnız `site_url` + `uri_allow_list` yamalanır (`supabase config push` bilinçle kullanılmaz — repodaki `config.toml` yerel geliştirmeye göre yazılmış, push edilirse staging'in Site URL'ini localhost yapar). Staging'e uygulandı ve doğrulandı (run `30164160511`); `site_url` ve allowlist artık uygulama derin bağlantı scheme'leri. 🔴 **Free tier duvarı:** varsayılan e-posta sağlayıcısıyla Supabase, kurtarma **e-posta şablonunu hem API'den hem panelden** değiştirtmiyor → `{{ .Token }}` eklenemiyor → **Windows/masaüstündeki 6 haneli kod yolu, özel SMTP (veya ücretli plan) bağlanana kadar çalışmaz.** Android derin bağlantı yolu çalışır ve beta 1'de test edilebilir.
- 🔴 **BETA 1 GERİ BİLDİRİMİ (sahip, 2026-07-25) → WP-302/303/304 açıldı ve ÜÇÜ DE KOD/TEST TAMAM.** `analyze` 0, **795 test yeşil**, l10n audit temiz. Sahip sırası: bu üçü stable'a → sonra kalan kod işleri → beta 2 → stable.

### Codex Lane
- **Durum:** [x] Boşta
- **Faz/WP:** —
- **SAHİP yollar:** —

### Codex-2 Lane
- **Durum:** [x] Boşta
- **Faz/WP:** —
- **SAHİP yollar:** —

### Grok Lane
- **Durum:** [x] Boşta
- **Faz/WP:** —
- **SAHİP yollar:** —

## 🗺️ Yol Haritası — sırada ne var

> **İki plan, sırayla: PLAN 1 (Ürün & Kod, Faz A–F) → PLAN 2 (Mağaza, Faz G–J).**
> Tek istisna: **isim + logo kararı** Plan 2'ye ait ama Plan 1 bitmeden verilmeli —
> mağaza görselleri, MSIX kimliği ve uygulama içi marka ona bağlı.

### Şu anki gerçek durum

| Konu | Durum |
| --- | --- |
| Sürüm | **`v48` yayında (Latest).** Android APK + Windows MSIX/ZIP GitHub Releases'ta |
| `v49` | 🔴 **ÇIKMADI.** Koşum `30174581718` **başarısız** (gece yarısı test tuzağı) → release oluşmadı, cihaza hiçbir şey gitmedi. Sahip kararı: **v49 gönderilmeyecek**, düzeltmeler bir sonraki sürümde toplanır. ⚠️ `v49` **git tag'i uzakta duruyor** ama karşılığında release yok — bkz. Risk notları |
| Sürüm politikası | 🔴 Sahip onayı olmadan yeni sürüm çıkmaz |
| Test | 815 test yeşil, `flutter analyze` temiz, l10n audit temiz |
| Migration | Repo head **`0071`**; staging ve production **`0070`** — 0071 hiçbir ortama uygulanmadı |
| Play Console | Hesap açıldı, doğrulama sürüyor. Hiçbir form doldurulmadı |
| Microsoft Partner Center | Hesap açıldı. Hiçbir hazırlık yapılmadı |

---

## PLAN 1 — ÜRÜN & KOD

### Faz A — Doğrulama borcu ✅ *KAPANDI (sahip, 2026-07-26)*

Sahip v46–v48 turlarında cihazda test etti ve tek tek doğruladı: **özel tema
okunabilirliği · spektrum renk seçici · font düğmelerinin sabitliği · grafikteki
gün etiketleri · boş ikinci bildirim · taç ve aura** — hepsinde sorun yok.

- **Şifre sıfırlama** ayrı bir madde olarak tutulmuyor; şifre işinin tamamı
  **Faz C1**'de birlikte yapılıp orada test edilecek (sahip: "şifreyi de sonra
  test ederiz").
- **v49'un his adımı** cihazda görülmedi ama v49 zaten yayınlanmadı; bir sonraki
  sürümün QA'sında bakılır.

**Faz A'dan çıkan kod bulguları → Faz C5.**

---

### Faz B — Admin & geri bildirim döngüsü ⬅️ *sıradaki iş*

Şu an kullanıcıdan geri bildirim alıyoruz ama **kapatamıyoruz**: fotoğrafı
göremiyoruz, cevap yazamıyoruz, liste temizlenmiyor.

> ✅ **Çakışma yok:** tüm lane'ler boşta. WP-316 → WP-317 → WP-318 **seri** koşar —
> üçü de `admin_*` ekranlarına ve `supabase_admin_repository.dart`'a giriyor.
> **Sıcak dosya uyarısı:** WP-317 ve WP-318 ikisi de `supabase/migrations/**`'e
> giriyor; migration numarası çakışmasın diye 317 önce biter, sonra 318 başlar.
> 🔴 **Faz B sırasında yapılacak sahip konuşması: isim + logo (K6)** — bkz. Faz G.

#### WP-316: Geri bildirim eki görünmüyor 🖼️
- **Program/Faz:** Faz B · Admin & geri bildirim
- **Ajan:** Codex · **Durum:** [x] **Kod/test + staging tamam (2026-07-26)** — cihaz kabulü bekliyor
- **Problem:** Kullanıcı geri bildirime ekran görüntüsü ekliyor, admin panelinde görünmüyor. Sahip biletleri **kör** değerlendiriyor.
- **Kapsam dışı:** Yeni ek türü (video/ses), çoklu ek, ek düzenleme. Yalnız **mevcut tek görsel** yolunun çalışması.
- **SAHİP dosyalar (yaz):**
  - `app/lib/data/repositories/supabase/supabase_admin_repository.dart`
  - `app/lib/features/admin/**` (ek gösteren kart/çip)
  - `supabase/migrations/00NN_feedback_attachment_fix.sql` *(yalnız teşhis 1 çıkarsa)*
- **DOKUNMA (oku, değiştirme):** `app/lib/core/theme/**` · `app/pubspec.yaml` · diğer repository'ler
- **Adımlar (teşhis önce, kod sonra — sorun büyük olasılıkla ortamda):**
  - [x] `0019_feedback_attachments` production'da gerçekten uygulandı mı? → **Hayır/eksik:** `attachment_path` var, private bucket yok (`400 Bucket not found`); policy'ler bucket olmadan işlevsiz
  - [x] `public.is_super_admin()` production'da mevcut/çağrılabilir mi? → RPC salt-okunur anon probunda `200`; sahip hesabının `true` sonucu cihazda admin oturumuyla doğrulanmalı
  - [x] Kullanıcı yükleme yolu salt-okunur denetlendi: dosya önce private bucket'a yükleniyor, yalnız başarıdan sonra `attachment_path` insert ediliyor; bucket hatası `storage` kodlu `AdminException` olup mevcut dialog'da 8 sn snackbar ile görünür. Mevcut production satırında yolun doluluğu RLS nedeniyle ancak kullanıcı/admin cihaz oturumunda doğrulanabilir
  - [x] İmzalı URL 1 saat geçerli; süresi dolmuş URL cache'lenmiş olabilir → üretim anını ek yolu olmadan logla
  - [x] Bulunan katmanı onar + yükleme hatasını kullanıcıya **görünür** yap → hedef widget testi **3/3**, tam Flutter paketi **820/820**, `flutter analyze` **0**, deploy guard **51/51**, temiz local baseline **72 migration + 147 pgTAP** yeşil
- **Veri/Migration etkisi:** `0072_feedback_attachment_storage_fix.sql` — additive/idempotent private bucket + iki Storage RLS policy; geri alma: iki policy `drop`, bucket/veri silinmez.
- **Ortam/Deploy:** Production teşhisi yalnız **okuma**. `0071` + `0072` staging'e Database Gates run `30196412999` ile uygulandı; dry-run, push, migration-list ve linked post-check yeşil, staging head `0072`. Production `0070`'da kilitli; ayrıca somut sahip GO'su ister. Kalan WP-316 kabulü: staging bağlı gerçek cihazda ekli biletin ≤3 sn'de açılması.
- **RLS/Güvenlik:** Bucket **private kalmalı**; imzalı URL süresi uzatılmaz. `is_super_admin()` dışında kimse ek göremez. Ek yolu log'a **yazılmaz**.
- **Edge-case'ler:** ek yok · ek var ama dosya silinmiş · URL süresi dolmuş · çevrimdışı · aynı bilette birden çok ek (bugün desteklenmiyorsa açıkça yaz)
- **Kabul (ölçülebilir):** Ekli bir geri bildirimde çipe basınca görsel **≤ 3 sn**'de açılıyor · ek yoksa çip **görünmüyor** · yükleme hatasında kullanıcı snackbar görüyor (sessiz düşme yok) · teşhis sonucu hangi katmanın bozuk olduğu **yazılı** kanıtla raporlanıyor.
- **Tuzaklar:** "Kodda hata yok" diye kapatma — sorun büyük olasılıkla migration/policy tarafında. Bucket'ı public yapmak **çözüm değil**, güvenlik gerilemesidir.
- **Model önerisi:** 🟣 Pro

#### WP-317: Admin ↔ kullanıcı yazışması 💬
- **Program/Faz:** Faz B · Admin & geri bildirim
- **Ajan:** — · **Durum:** [ ] Bekliyor · **Bağımlılık:** WP-316 kabulünden sonra
- **Problem:** Admin bileti okuyor ama kullanıcıya **cevap yazamıyor**. Kullanıcı sorununun ne olduğunu asla öğrenemiyor.
- **Kapsam dışı:** Gerçek zamanlı sohbet, dosya eki ile yanıt, toplu yanıt şablonları.
- **SAHİP dosyalar (yaz):**
  - `app/lib/features/admin/**` (Yanıtla eylemi + yazışma listesi)
  - `app/lib/data/repositories/supabase/supabase_admin_repository.dart`
  - `supabase/migrations/00NN_feedback_replies.sql` (yeni)
- **DOKUNMA:** `notification_center_screen.dart` (**okunur**, yapısı bozulmaz) · push edge fonksiyonları · `app/lib/core/theme/**`
- **Adımlar:**
  - [ ] Yazışma modeli: bilete bağlı mesajlar, gönderen rolü (admin/kullanıcı), okundu bilgisi
  - [ ] Admin kartına "Yanıtla" → hedefi o kullanıcı olan duyuru (`announcements.target_type='user'` + `target_id` **zaten var**)
  - [ ] Push bildirimi tetikle
  - [ ] **Kullanıcı geri yazabilsin** (K1: çift yönlü) — kullanıcı tarafında yanıt alanı
  - [ ] Bilet durumu otomatik ilerlesin (yanıtlanınca `in_progress`)
- **Veri/Migration etkisi:** Yeni yazışma tablosu + RLS. Geri alma: `drop table` (yeni tablo, veri kaybı riski yok).
- **Ortam/Deploy:** local → staging dry-run → production ayrı GO.
- **RLS/Güvenlik:** 🔴 Kullanıcı **yalnız kendi biletinin** yazışmasını okur/yazar; admin hepsini. Yazma yetkisi **server-authoritative** — istemci `sender_role` göndermez, sunucu `auth.uid()`'den türetir.
- **Edge-case'ler:** kullanıcı hesabını silmiş · bilet arşivlenmiş (yanıt hâlâ okunabilmeli) · push izni kapalı (mesaj yine Duyurular'da görünmeli) · çok uzun mesaj · art arda yanıt
- **Kabul (ölçülebilir):** Admin yanıtı kullanıcının Duyurular'ında **≤ 5 sn**'de görünüyor · push düşüyor · kullanıcı geri yazınca admin panelinde görünüyor · yazışma biletin altında **kim ne demiş** iziyle duruyor · başka kullanıcının bileti RLS testinde **okunamıyor**.
- **Tuzaklar:** `android.notification` bloğu data-only mesajı bozar ve yanına **boş ikinci bildirim** düşürür (daha önce yaşandı). Push gönderimi mevcut data-only sözleşmesine uymalı.
- **Model önerisi:** 🔴 Opus (RLS + push + iki taraflı akış)

#### WP-318: Bilet arşivi 🗃️
- **Program/Faz:** Faz B · Admin & geri bildirim
- **Ajan:** — · **Durum:** [ ] Bekliyor · **Bağımlılık:** WP-317 (migration sırası)
- **Problem:** Sadece `open / in_progress / closed` var ve hepsi listede duruyor; liste birikip kullanılmaz hale geliyor.
- **Kapsam dışı:** Bilet silme, otomatik arşivleme, arşiv temizleme cron'u.
- **SAHİP dosyalar (yaz):**
  - `app/lib/features/admin/**` (liste filtresi + "Tamamlandı" eylemi)
  - `app/lib/data/repositories/supabase/supabase_admin_repository.dart`
  - `supabase/migrations/00NN_feedback_archive.sql` (yeni)
- **DOKUNMA:** WP-317'nin yazışma tabloları (**okunur**)
- **Adımlar:**
  - [ ] `archived_at timestamptz` alanı (nullable) — 🔴 **satır silinmez**
  - [ ] Varsayılan liste arşivlenmemişleri gösterir
  - [ ] "Arşivi göster" filtresi
  - [ ] "Tamamlandı → listeden kaldır" eylemi (geri alınabilir)
- **Veri/Migration etkisi:** Additive nullable kolon. Geri alma: `alter table ... drop column archived_at`. **Veri kaybı yok** — arşiv bir bayraktır, silme değildir.
- **Ortam/Deploy:** local → staging → production ayrı GO.
- **RLS/Güvenlik:** Arşivleme yetkisi yalnız `is_super_admin()`. Arşivlenmiş bilet kullanıcıdan **gizlenmez** (kendi biletini görmeye devam eder).
- **Edge-case'ler:** arşivlenmiş bilete yeni yanıt gelirse ne olur (öneri: listeye geri döner) · toplu arşivleme · arşivden çıkarma
- **Kabul (ölçülebilir):** 20+ biletlik listede arşivleme sonrası varsayılan görünüm **yalnız aktif** biletleri gösteriyor · "Arşivi göster" ile arşivlenen bilet **eksiksiz** geri geliyor · veritabanında satır sayısı **azalmıyor** (silme olmadığının kanıtı).
- **Tuzaklar:** `closed` ile `archived` **aynı şey değil** — kapalı bilet hâlâ listede görünebilir, arşivlenen görünmez. İkisini tek alana indirme.
- **Model önerisi:** 🔵 Sonnet

---

### Faz C — Hesap, güvenlik, ayarlar hijyeni

> ✅ **Çakışma yok** (Faz B kabulünden sonra başlar). ⚠️ **WP-320 ve WP-321 seri
> koşar** — ikisi de ayarlar ağacına ve l10n/generated'a giriyor. WP-319 ve
> WP-322 bağımsız, paralel koşabilir.

#### WP-319: Şifre değiştirme + sıfırlama 🔑
- **Program/Faz:** Faz C · Hesap & güvenlik · *(eski WP-287'nin kalan işini devralır)*
- **Ajan:** — · **Durum:** [ ] Bekliyor
- **Problem:** Şifre değiştirme **hiç yok** — `account_settings_screen.dart` yalnız hesap silmeyi taşıyor. Mağazaya "temel şeyleri eksik" bir uygulama çıkamaz.
- **Kapsam dışı:** Sosyal giriş (Google/Apple) eklemek, iki adımlı doğrulama, oturum yönetimi ekranı.
- **SAHİP dosyalar (yaz):**
  - `app/lib/features/profile/account_settings_screen.dart`
  - `app/lib/data/repositories/**/auth_repository*.dart`
  - `app/lib/l10n/*.arb` (yeni anahtarlar)
- **DOKUNMA:** `app/lib/core/navigation/**` · `main.dart` · diğer ayar ekranları (WP-320 orada)
- **Adımlar:**
  - [ ] Üç alan: *mevcut şifre · yeni şifre · yeni şifre tekrar*
  - [ ] 🔴 **Mevcut şifreyi gerçekten doğrula** — Supabase `updateUser(password:)` eski şifreyi **doğrulamaz**; önce o şifreyle yeniden kimlik doğrulaması yapılmalı
  - [ ] Aynı ekranda **"Şifremi unuttum"** yolu
  - [ ] Hata durumları: yanlış mevcut şifre · zayıf yeni şifre · iki alan uyuşmuyor
  - [ ] 4 dilde metin (TR/EN zorunlu; DE/AR WP-321'de düşecek)
- **Veri/Migration etkisi:** Yok (Auth API).
- **Ortam/Deploy:** local + staging. Staging Site URL/allowlist ayarı otomatik: [`supabase-auth-config.yml`](.github/workflows/supabase-auth-config.yml).
- **RLS/Güvenlik:** 🔴 Kullanıcı **yalnız kendi** şifresini değiştirir. Şifreler log'a/analitiğe **yazılmaz**. Başarısız denemeler oran sınırına takılmalı.
- **Edge-case'ler:** çevrimdışı · oturum süresi dolmuş · e-posta doğrulanmamış hesap · şifre değişince diğer cihazların oturumu ne olacak (karara bağlanmalı)
- **Kabul (ölçülebilir):** Yanlış mevcut şifreyle işlem **reddediliyor** (alan dekoratif değil — bu test yazılı olacak) · doğru şifreyle değişiyor ve yeni şifreyle giriş yapılabiliyor · "Şifremi unuttum" akışı Android'de uçtan uca çalışıyor · şifre hiçbir log satırında görünmüyor.
- **Tuzaklar:** 🔴 **Ölü anahtar riski buranın tam merkezinde.** "Mevcut şifre" alanı doğrulama yapmıyorsa kullanıcı korunduğunu sanır — bu, alanın hiç olmamasından **kötüdür**.
  🔴 **Devralınan engel:** Supabase free tier, varsayılan e-posta sağlayıcısıyla kurtarma şablonunu hem API'den hem panelden kilitliyor → `{{ .Token }}` eklenemiyor → **Windows/masaüstündeki 6 haneli kod yolu, özel SMTP (veya ücretli plan) bağlanana kadar çalışmaz.** Android derin bağlantı yolu çalışır. Sahip: "şifreyi de sonra test ederiz" — değiştirme ve sıfırlama **aynı turda** test edilecek.
- **Model önerisi:** 🔴 Opus (güvenlik yüzeyi)

#### WP-320: Ayarlar bilgi mimarisi 🧭
- **Program/Faz:** Faz C · Ayarlar hijyeni
- **Ajan:** — · **Durum:** [ ] Bekliyor
- **Problem:** Ayarların sırası rastgele büyümüş; "Verilerimi dışa aktar" ortada duruyor, yasal metinler gelişigüzel yerde.
- **Kapsam dışı:** Yeni ayar eklemek, mevcut ayarların davranışını değiştirmek. Yalnız **yer ve sıra**.
- **SAHİP dosyalar (yaz):** `app/lib/features/profile/settings*.dart` · `app/lib/features/profile/data_export_screen.dart` (yalnız konumu) · ilgili l10n başlıkları
- **DOKUNMA:** `account_settings_screen.dart` (WP-319 orada — **seri koş**) · `notification_center_screen.dart`
- **Adımlar:**
  - [ ] "Verilerimi dışa aktar" → **Hesabımı yönet** altına, hesap silmenin yanına
  - [ ] Sıra: *Hesap → Bildirimler → Görünüm → Çalışma tercihleri → Gizlilik & güvenlik → Hakkında/Yasal*
  - [ ] Gizlilik politikası ve yasal metinler **en alta**
  - [ ] 🔴 Öneri **önce sahibe** gösterilir, sonra kodlanır
- **Veri/Migration etkisi:** Yok.
- **Ortam/Deploy:** local.
- **RLS/Güvenlik:** Yok (yalnız yerleşim). Hesap silme ve dışa aktarma yan yana gelince **yanlışlıkla silme** riski artar — silme onayı korunmalı.
- **Edge-case'ler:** 360 px genişlikte başlık taşması · uzun çeviriler · Windows'ta aynı ağaç
- **Kabul (ölçülebilir):** Dışa aktarma ve hesap silme **aynı başlık altında** · yasal metinler listenin **son** grubunda · 360 px'te hiçbir başlık taşmıyor · mevcut ayar testleri yeşil kalıyor.
- **Tuzaklar:** Mağaza veri beyanları dışa aktarma + silmeyi **bir arada** arıyor; ikisini ayırma.
- **Model önerisi:** 🔵 Sonnet

#### WP-321: TR + EN'e in 🌍
- **Program/Faz:** Faz C · l10n
- **Ajan:** — · **Durum:** [ ] Bekliyor · **Bağımlılık:** WP-320 (aynı l10n yüzeyi — seri)
- **Problem:** 4 dil taşınıyor ama AR/DE hiç test edilmiyor; RTL QA borcu ve Arapça glif zinciri bedava değil.
- **Kapsam dışı:** `.arb` dosyalarını **silmek** (repoda kalacak), çeviri kalitesi iyileştirme.
- **SAHİP dosyalar (yaz):** `app/lib/l10n/**` (supportedLocales) · `scripts/l10n_audit.py` · `.github/workflows/l10n-gate.yml`
- **DOKUNMA:** ayar ekranları (WP-320)
- **Adımlar:**
  - [ ] `supportedLocales` → yalnız TR + EN
  - [ ] `.arb` dosyaları **kalır** (DE/AR ileride geri açılabilsin)
  - [ ] l10n kapısı iki dil parity'si kontrol etsin
  - [ ] RTL'e özel kodun ölü kalıp kalmadığını kontrol et
- **Veri/Migration etkisi:** Yok.
- **Ortam/Deploy:** local.
- **RLS/Güvenlik:** Yok.
- **Edge-case'ler:** 🔴 **Davranış değişikliği** — cihaz dili Almanca olan mevcut kullanıcı İngilizce'ye düşer. Kabul edilebilir ama **bilinerek** yapılıyor. Ayrıca: kullanıcı elle DE seçmişse kayıtlı tercih ne olacak?
- **Kabul (ölçülebilir):** Dil listesinde 2 seçenek · l10n audit **0 bulgu** · cihaz dili DE olan emülatörde uygulama **İngilizce** açılıyor ve çökmüyor · gömülü font Arapça glif zinciri gereksinimi kalkmış olarak belgeleniyor.
- **Tuzaklar:** `.arb` silmek geri dönüşü zorlaştırır; yalnız `supportedLocales` daraltılır.
- **Model önerisi:** 🔵 Sonnet

#### WP-322: Teknik borç temizliği 🧹
- **Program/Faz:** Faz C · mağaza ön şartı
- **Ajan:** **Claude** · **Durum:** ✅ **KOD/TEST TAMAM** (2026-07-26, commit `3e607a7`) · Faz B ile paralel koştu, çakışma olmadı
- **Kanıt:** `flutter analyze` **temiz** · **10 ardışık tam suit koşumu 10/10 yeşil** (her turda 820 test) · kararsızlık için **kırmızı-yeşil kanıt** alındı · kanıt etiketi **Kodda doğrulandı** (cihaz QA'sı yok — `microsoftStore` kanalı ancak **Faz H**'de gerçek bir Store paketiyle görülebilir).
- **Problem:** Dört ayrı küçük borç mağaza çıkışını riske atıyor. 🔴 **Kartın ilk iki maddesi yanlış varsayıma dayanıyormuş** — kod okunduğunda ikisi de düştü, bulgular aşağıda.
- **Kapsam dışı:** Genel bağımlılık yükseltmesi, `test.zip`'i git geçmişinden silmek (geçmiş yeniden yazılır — ayrı ve riskli iş). Store CI job'ını kurmak (**Faz H**).
- **SAHİP dosyalar (yaz):** `app/pubspec.yaml` (yalnız `version:` + `msix_config`) · `app/lib/core/config/distribution_channel.dart` · `app/test/core/distribution_channel_test.dart` · `app/test/features/classroom/study_timer_card_stop_test.dart` · `tooling/**`
- **DOKUNMA:** `supabase/migrations/**` · feature kodu · `app/lib/features/admin/**` (Codex WP-316)
- **Adımlar:**
  - [x] ❌ **`passkeys` KALDIRILAMAZ — madde geçersiz.** `pubspec.yaml`'da doğrudan bağımlılık **değil**; `supabase_flutter 2.15.0`'ın **zorunlu** bağımlılığı (`flutter pub deps`: `supabase_flutter → passkeys 2.20.0 → passkeys_android/darwin/web/windows`). Kaldırmanın tek yolu `supabase_flutter`'ı bırakmak. "Kurulu ama hiç kullanılmıyor" doğru ama **bizim seçimimiz değil**. APK boyutu/izin kazancı bu turda **yok**.
  - [x] ❌ **Sürüm hizalama madde gerekçesi yanlış — "mağaza paketleri bu numarayı okur" DOĞRU DEĞİL.** Release hattı sürümü **etiketten** türetiyor ([release.yml:49-50](.github/workflows/release.yml:49)) ve `--build-name`/`--build-number` ile geçiriyor; MSIX sürümü de build sırasında **üzerine yazılıyor** ([windows-release.yml:71](.github/workflows/windows-release.yml:71)). Yani `pubspec.yaml`'daki `version:` hiçbir yayın artefaktına ulaşmıyor — yalnız argümansız yerel `flutter build`'i etkiler. Hizalama **kozmetik hijyen**, mağaza riski değil. Sürüm politikası gereği (sahip onayı olmadan sürüm yok) bu satıra **dokunulmadı**.
  - [x] ✅ **Store self-update kapısı — asıl iş buymuş ve yazılandan büyük.** `microsoftStore` diye bir dağıtım kanalı **yoktu**: Windows build'i `DISTRIBUTION_CHANNEL=windows` alıyor ([windows-release.yml:56](.github/workflows/windows-release.yml:56)) ve o kanalda `allowsSideloadUpdates = true`. Store paketi bugünkü kodla çıkarsa **GitHub'dan kendini güncellemeye çalışır** — Store politikası bunu yasaklar. Eklendi: `microsoftStore` kanalı, sideload **kapalı**, unutulmuş `CHANNEL=beta` define'ı Store paketini beta yapamıyor.
  - [x] ✅ **Kararsız testin kök nedeni bulundu ve giderildi** (aşağıda ayrı madde).
- **Veri/Migration etkisi:** Yok.
- **Ortam/Deploy:** local. Store define'ını CI'da set etmek **Faz H**'ye ait.
- **RLS/Güvenlik:** `microsoftStore` kanalında uzaktan APK/MSIX indirme yolu tamamen kapalı (izin yüzeyi daralır). `passkeys` kalkmadığı için oradan kazanç yok.
- **Edge-case'ler:** 🔴 Android'deki `--flavor play` zorlamasının Windows karşılığı **yok** — `microsoftStore`'u yalnız define seçiyor. Define unutulursa kanal `windows`'a düşer ve updater açık kalır. Bu boşluk testle **belgelendi**; Faz H build öncesi kapı koymak zorunda.
- **Kabul (ölçülebilir):** `flutter analyze` temiz · `microsoftStore` kanalında `allowsSideloadUpdates == false` ve `releaseNotesChannel == 'stable'` (4 test) · `study_timer_card_stop_test.dart` **10 ardışık tam suit** koşumunda yeşil · kararsızlık için **kırmızı-yeşil kanıtı** var. ⚠️ passkeys ve sürüm maddeleri kabul kriterinden **düşürüldü** (konusuz).
- **Tuzaklar:** Sürüm numarasını **düşürme** — in-app güncelleme mantığı bozulur. Kararsız testi "yeniden koş geçti" diye kapatma; kök neden + 10 koşumluk kanıt şart.
- **Model önerisi:** 🟣 Pro

##### WP-322 bulgu: kararsız testin kök nedeni (2026-07-26)

`study_timer_card_stop_test.dart` **saat yarışıydı**, sıra/paylaşılan durum sorunu değil.

- Kart canlı süreyi **her karede** gerçek saatten hesaplıyor:
  `elapsed = DateTime.now().difference(startedAt).inSeconds` ([study_timer_card.dart:130](app/lib/features/classroom/widgets/study_timer_card.dart:130)).
- Test ise beklenen toplamı çok önce yakalanan bir `now`'dan türetip **tam metin eşleşmesi** bekliyordu.
- `now` ile ilk çizim arasında **1 saniye** geçerse ekrandaki sayı `expectedTotal + 1` oluyor ve saat ileri aktığı için **bir daha asla** beklenen değere dönmüyor → `pumpUntilFound` 10 sn dönüp düşüyor.
- Geliştirici makinesinde kurulum < 1 sn olduğu için geçiyordu; **tam suit yükü altında** düşüyordu. "Bir koşumda düştü, ikincide geçti" tam olarak buydu.

**Çözüm:** saati dondurmak değil — testin iddiası zaten mutlak sayı değil, `liveSeconds` (≈3600 sn) kadarlık bir **zıplama**. Bekleme, `[expectedTotal, expectedTotal + 120]` aralığına düşen bir süre metnini arıyor; olumsuz iddia payın **30 katı** uzakta duruyor. Durdurmadan sonrası zaten `settling*` alanlarıyla **tam belirlenimli**, orada değişiklik yok.

**Kırmızı-yeşil kanıtı:** `isStopping: true` → `false` yapılarak WP-250 öncesi çift sayma geri getirildi → test **düştü** (`Found 0 widgets with text "2h 0m 0s"`). Geri alındı, yeşil. Yani tolerans gerçek hatayı gizlemiyor.

**Yan bulgu (kovalandı, ÜRÜN HATASI DEĞİL):** kırmızı koşumda süreler `locale: Locale('tr')` verilmesine rağmen **İngilizce** çıktı (`2h 0m 0s`). Sebep: `formatHumanSeconds` global `activeAppLocale`'i okuyor; onu gerçek uygulamada [`main.dart:211`](app/lib/main.dart:211) `localeResolutionCallback` içinde ve dil notifier'ı ayarlıyor. Test çıplak bir `MaterialApp` kurduğu için o yol hiç çalışmıyor ve global test hostunun dili (`en`) olarak kalıyor. **Üründe böyle bir kaçak yok** — yeni bekleme yardımcısı yine de dilden bağımsız yazıldı, aynı tuzağa düşen bir sonraki test için.

---

### Faz D — Yeni kullanıcı deneyimi (tanıtım turu)

Şu an sadece açılışta tek bir `onboarding_screen` var; uygulama içinde hiçbir
yerde rehberlik yok.

> ⚠️ **WP-323 → WP-324 seri koşar.** 324, 323'ün kabul edilmiş motoruna yazar;
> motor oturmadan içerik yazmak iki kez iş demektir.

#### WP-323: Tanıtım turu motoru 🎈
- **Program/Faz:** Faz D · Yeni kullanıcı deneyimi
- **Ajan:** — · **Durum:** [ ] Bekliyor
- **Problem:** Uygulama içinde hiçbir rehberlik yok; yalnız açılışta tek bir `onboarding_screen` var. Yeni kullanıcı ekranlarda kayboluyor.
- **Kapsam dışı:** Balon **metinleri** ve ekran içerikleri (WP-324) · video/animasyonlu tanıtım · yardım merkezi.
- **SAHİP dosyalar (yaz):** `app/lib/core/tour/**` (yeni) · `app/lib/core/prefs/app_prefs.dart` (anahtarlar) · ayarlarda "sıfırla" satırı
- **DOKUNMA:** feature ekranları (WP-324 orada) · `app/lib/core/theme/**` · `main.dart` (yalnız gerekli tek kanca)
- **Adımlar:**
  - [ ] Balon/overlay bileşeni: hedef öğeyi işaret eder, **ekrana basınca sonraki balona geçer** (K3)
  - [ ] "Atla" her zaman görünür
  - [ ] Her ekranın **kendi** "görüldü" anahtarı — hepsi tek bayrağa bağlanmaz
  - [ ] Anahtarlar **sürümlenir** (`home.v1`, `home.v2`): ekran ciddi değişince tur yeniden gösterilebilsin, ama her güncellemede herkese açılmasın
  - [ ] Ayarlarda **"Tanıtım turlarını sıfırla"**
  - [ ] Kuyruk yönetimi: tur; izin diyalogları ve güncelleme bildirimiyle **çakışmaz**
- **Veri/Migration etkisi:** Yok (yerel tercihler).
- **Ortam/Deploy:** local.
- **RLS/Güvenlik:** Yok.
- **Edge-case'ler:** hedef öğe ekranda yok (kaydırma gerekiyor) · ekran döndürme · küçük ekranda balon taşması · Windows'ta fare/klavye · "hareketi azalt" açık · tur ortasında ekrandan çıkma
- **Kabul (ölçülebilir):** Yeni kurulumda tur **yalnız ilk açılışta** başlıyor · ekrana ardışık basınca balonlar sırayla geçiyor ve **takılmıyor** · "Atla" turu bitiriyor ve bir daha açılmıyor · sıfırlama sonrası yeniden başlıyor · izin diyaloğu açıkken tur **başlamıyor** · 360 px'te balon ekran dışına taşmıyor.
- **Tuzaklar:** Tek bayrak kullanmak (bir ekranı gören hepsini görmüş sayılır) klasik hata. Sürümlemesiz anahtar, her güncellemede herkese tur açtırır.
- **Model önerisi:** 🔴 Opus (overlay + kuyruk + platform farkı)

#### WP-324: Tanıtım turu içerikleri ✍️
- **Program/Faz:** Faz D · Yeni kullanıcı deneyimi
- **Ajan:** — · **Durum:** [ ] Bekliyor · **Bağımlılık:** WP-323 **kabulünden** sonra
- **Problem:** Motor tek başına bir şey anlatmaz; her ekranın kendi kısa tanıtımı gerekir.
- **Kapsam dışı:** Motor davranışı, yeni ekran tasarımı.
- **SAHİP dosyalar (yaz):** Ana Sayfa · Sayaç · Kamp Ateşi · Gruplar · İstatistik · Profil ekranlarının tur tanımları · `app/lib/l10n/*.arb`
- **DOKUNMA:** `app/lib/core/tour/**` (WP-323'ün motoru — **okunur**)
- **Adımlar:**
  - [ ] Her ekran için **az sayıda** balon (sahip: "her ekrana 15 tane koyacak halimiz yok")
  - [ ] Metinler TR + EN
  - [ ] Hızlı geçmek isteyen üst üste basıp geçebilsin
- **Veri/Migration etkisi:** Yok. · **Ortam/Deploy:** local. · **RLS/Güvenlik:** Yok.
- **Edge-case'ler:** kullanıcının henüz grubu yok (grup turu ne diyecek) · istatistik boşken · kamp ateşi kilitliyken
- **Kabul (ölçülebilir):** Her ekranda balon sayısı **≤ 4** · her balon **≤ 2 satır** · veri boşken tur anlamlı metin gösteriyor (boş ekranı işaret etmiyor) · TR ve EN'de taşma yok.
- **Tuzaklar:** Boş durumda "şurada süren görünür" demek, hiçbir şey görünmeyen bir alanı işaret eder — boş hâl metinleri ayrı yazılmalı.
- **Model önerisi:** 🔵 Sonnet

---

### Faz E — Veri doğruluğu ve grup semantiği

**E1. Gün sınırı — yurtdışı kullanıcı.**

⚠️ **Eski plandaki iddia yanlıştı.** "Gün toplamı UTC'ye göre" **değil**: sunucu
tarafı baştan sona `Europe/Istanbul` (`0007`, `0011`, `0024`, `0039`, `0051`,
`0053`, `0062`, `0063` … 60'tan fazla yerde), istemci de `istanbulDay`. "İstanbul'a
çevirme" işi **çoktan yapılmış**.

⚠️ **Backfill diye bir iş de yok.** Gün toplamları hiçbir tabloda saklanmıyor;
`get_user_day_totals` her çağrıda ham `study_sessions` satırlarından hesaplıyor.

**Gerçek açık:** herkesin günü İstanbul yarısında sıfırlanıyor.

| Kullanıcı | Gün ne zaman sıfırlanıyor | Sonuç |
| --- | --- | --- |
| Türkiye (UTC+3) | 00:00 | doğru |
| Sydney (UTC+11) | 08:00 | sabah çalışması düne yazılır |
| New York (UTC−5) | 16:00 | 🔴 akşam çalışması yarına yazılır |

**Çözüm (K8):** gün sınırı **birincil grubun bölgesinden** gelir →
grubu yoksa **cihazın** saat dilimi → o da yoksa `Europe/Istanbul`.
Böylece kişisel ve grup istatistiği **asla çelişmez**.

> 🔴 **Bu fazın tamamı `supabase/migrations/**` sıcak dosyasına giriyor → hepsi
> SERİ koşar.** Sıra: **WP-325 → WP-326 → WP-329 → WP-327 → WP-328.**
> Gerekçe: 326 (bölge) olmadan 329 (birincil grup) gün sınırını besleyemez;
> 325 (damgalama) olmadan 326 geçmişi kaydırır.

#### WP-315: Grup üye sınırı 8 ✅ TAMAM
- **Program/Faz:** Faz E · Grup semantiği · **Durum:** [x] Kod/test tamam (2026-07-26)
- **Yapılan:** Varsayılan 50 → **8**, kısıt `2..100` → `2..8`, `create_group_with_access` varsayılanı 8, Dart sabitleri (`kMinGroupMemberLimit`/`kMaxGroupMemberLimit`). 4 yeni test. Migration `0071_group_member_limit_8.sql`, güvenlik ön kontrolüyle (8'den fazla aktif üyeli grup varsa **adıyla** durur).
- 🔴 **Kalan:** migration **hiçbir ortamda koşmadı**. Staging apply gerekiyor.

#### WP-325: Gün, kayıt anında damgalanır 📌
- **Program/Faz:** Faz E · Veri doğruluğu · *(eski WP-301'in yerine — o kart iptal)*
- **Ajan:** — · **Durum:** [ ] Bekliyor
- **Problem:** Gün her sorguda `start_time`'dan yeniden hesaplanıyor. Bölge değişirse **geçmiş de kayıyor**: kullanıcı grup değiştirince eski günleri oynar, serisi kırılır. Sahip talebi: *"hep sonrasını etkileyecek şekilde"*.
- **Kapsam dışı:** Bölge seçimi (WP-326) · birincil grup (WP-329) · görsel değişiklik.
- **SAHİP dosyalar (yaz):**
  - `supabase/migrations/00NN_session_day_stamp.sql` (yeni)
  - `app/lib/core/stats/**` · `app/lib/data/repositories/**/study_repository*.dart`
- **DOKUNMA:** `groups` ile ilgili her şey (WP-326) · başarım fonksiyonları (ayrı tur)
- **Adımlar:**
  - [ ] `study_sessions.day date` (nullable → doldur → not null)
  - [ ] Mevcut satırları **İstanbul günüyle** doldur → 🔴 **ekranda hiçbir şey değişmez** (bugünkü davranışın aynısı)
  - [ ] Yazma yolunda gün damgalanır ve **bir daha dokunulmaz**
  - [ ] Gün bucket'lı sorgular saklanan kolona geçer; kolon **indekslenir**
  - [ ] Elle oturum ekleme/düzenleme akışında gün **yeniden** hesaplanır
- **Veri/Migration etkisi:** 🔴 Yeni kolon + **geri doldurma**. Geri alma: `drop column day` (türetilmiş veri, kayıp yok — ham `start_time` duruyor). Doldurma **idempotent** yazılır.
- **Ortam/Deploy:** local replay → staging dry-run + satır sayısı raporu → production **ayrı GO + backup**.
- **RLS/Güvenlik:** Mevcut `auth.uid()` kısıtları korunur; `get_user_day_totals` sözleşmesi **değişmez**.
- **Edge-case'ler:** gece yarısını aşan oturum (gün = **başlangıç** günü, yazılı karar) · elle eklenen geçmiş oturum · saat dilimi geçersiz/boş · çevrimdışı kaydedilip sonra senkronlanan oturum
- **Kabul (ölçülebilir):** Geri doldurmadan **önce ve sonra** `get_user_day_totals` çıktısı **birebir aynı** (staging'de sentetik veriyle kanıtlanır) · bölge değiştirildiğinde geçmiş gün toplamları **değişmiyor**, yalnız yeni kayıtlar yeni bölgeye düşüyor · gün kolonu üzerinde indeks kullanılıyor (`explain`).
- **Tuzaklar:** Damgalamayı yalnız istemciye bırakma — çevrimdışı/eski sürüm istemciler yanlış gün yazar; **sunucu son sözü söylemeli**. Geri doldurmayı tek dev `update` ile yapma (kilit); parçalı koş.
- **Model önerisi:** 🔴 Opus (geri alınamaz veri)

#### WP-326: Grup bölgesi + gün sınırı zinciri 🌍
- **Program/Faz:** Faz E · Grup semantiği · *(eski WP-300'ün yerine — enlem/boylam **iptal**)*
- **Ajan:** — · **Durum:** [ ] Bekliyor · **Bağımlılık:** WP-325 kabulü
- **Problem:** Herkesin günü İstanbul yarısında sıfırlanıyor. New York'ta bu **16:00**'ya denk geliyor — akşam çalışması yarına yazılıyor.
- **Kapsam dışı:** 🔴 **Konum izni, enlem/boylam** — istenmeyecek. Gerçek konum, Play Data Safety'de yeni veri kategorisi ve Android'de konum izni açar. Gökyüzü hesabı ayrı iş (Faz F).
- **SAHİP dosyalar (yaz):**
  - `supabase/migrations/00NN_group_time_zone.sql` (yeni)
  - `app/lib/data/models/study_group.dart` · grup kurma/ayar ekranları
  - `app/lib/core/stats/istanbul_calendar.dart` → gün sınırı zinciri
- **DOKUNMA:** `study_sessions` yazma yolu (WP-325) · keşif ekranı (WP-327/328)
- **Adımlar:**
  - [ ] `groups.time_zone text not null default 'Europe/Istanbul'` (IANA adı)
  - [ ] Grup kurarken ve grup ayarlarında bölge seçici
  - [ ] Gün sınırı zinciri: **birincil grubun bölgesi → cihazın saat dilimi → `Europe/Istanbul`**
  - [ ] Cihaz saat dilimi kaynağı: `0066_push_notification_delivery.sql`'deki `time_zone` **zaten toplanıyor**
- **Veri/Migration etkisi:** Additive, varsayılanlı → mevcut davranış **değişmez**. Geri alma: `drop column time_zone`.
- **Ortam/Deploy:** local → staging → production ayrı GO.
- **RLS/Güvenlik:** Bölge, grup üyesi olmayanlara da görünür (keşif kartında) — **hassas veri değil**, konum değil.
- **Edge-case'ler:** geçersiz IANA adı (kısıt + doğrulama) · kaldırılmış saat dilimi adı · grup bölgesi değişince ne olur (WP-329'daki uyarı) · yaz saati geçişi
- **Kabul (ölçülebilir):** 🔴 Saat dilimi **IANA adı** olarak saklanıyor (`America/New_York`), offset (`-5`) **değil** — bunun testi yazılı · New York bölgeli grupta gün **yerel 00:00**'da sıfırlanıyor · grubu olmayan kullanıcı cihaz saat dilimini kullanıyor · varsayılan davranış (TR grubu) **hiç değişmiyor**.
- **Tuzaklar:** 🔴 Offset saklamak yaz saatinde sessizce kayar. Türkiye'de yaz saati olmadığı için bu hata bugüne kadar **hiç görünmedi** — kod tabanı bu konuda test edilmemiş.
- **Model önerisi:** 🔴 Opus

#### WP-327: Grup bilgilerinde bölge + saat farkı 🕐
- **Program/Faz:** Faz E · Grup UI · **Durum:** [ ] Bekliyor · **Bağımlılık:** WP-326
- **Problem:** Kullanıcı bir gruba girerken o grubun hangi saate göre çalıştığını bilmiyor.
- **Kapsam dışı:** Keşif sıralaması (WP-328).
- **SAHİP dosyalar (yaz):** `app/lib/features/classroom/widgets/class_detail_screen.dart` · `group_discovery_screen.dart` (yalnız kart üzerindeki bölge satırı) · l10n
- **DOKUNMA:** keşif **sorgusu** (WP-328) · `groups` migration'ı (WP-326)
- **Adımlar:**
  - [ ] Açık grup kartında ve grup bilgi ekranında bölge adı
  - [ ] Bölgeye basınca kullanıcıya göre fark: *"Türkiye (senden +8 saat)"*
- **Veri/Migration etkisi:** Yok. · **Ortam/Deploy:** local.
- **RLS/Güvenlik:** Yok.
- **Edge-case'ler:** kullanıcı ve grup **aynı** bölgede (fark satırı gösterilmemeli) · yarım saatlik ofsetler (Hindistan +5:30) · yaz saati geçiş günü
- **Kabul (ölçülebilir):** 🔴 Fark **anlık hesaplanıyor, saklanmıyor** — yaz saati testinde aynı grup için yazın −7, kışın −8 üretiliyor · aynı bölgede fark satırı çıkmıyor · +5:30 gibi yarım saatlik ofset doğru yazılıyor.
- **Tuzaklar:** Farkı bir kez hesaplayıp veritabanına yazmak yılda iki kez sessizce yanlış olur — klasik **ölü anahtar** deseni.
- **Model önerisi:** 🔵 Sonnet

#### WP-328: Keşif sıralaması + arama/filtre 🔎
- **Program/Faz:** Faz E · Grup keşfi · **Durum:** [ ] Bekliyor · **Bağımlılık:** WP-326
- **Problem:** Açık gruplar `created_at desc` sıralanıyor; kullanıcı kendi saatine uygun grubu bulamıyor. Sınır 8'e indiği için dolu gruplara tıklayıp duruyor.
- **Kapsam dışı:** Grup önerisi algoritması (ilgi alanı, hedef benzerliği), sıralama kişiselleştirme.
- **SAHİP dosyalar (yaz):** `supabase/migrations/00NN_discover_groups_by_tz.sql` · `group_discovery_screen.dart` · `supabase_group_repository.dart`
- **DOKUNMA:** grup bilgi ekranı (WP-327)
- **Adımlar:**
  - [ ] Sıralama: iki bölgenin **o andaki** UTC farkının mutlak değeri; eşitlikte `created_at desc`
  - [ ] İsim araması + **bölge filtresi**
  - [ ] **"Boş kontenjanı var"** filtresi
- **Veri/Migration etkisi:** RPC değişikliği. Geri alma: önceki `discover_public_groups` gövdesi.
- **Ortam/Deploy:** local → staging → production ayrı GO.
- **RLS/Güvenlik:** 🔴 `discover_public_groups` yalnız **güvenli özet** alanlarını döndürür — `invite_code` sızmaz. Mevcut sözleşme korunur (test var).
- **Edge-case'ler:** 🔴 `idx_groups_public_discovery` `created_at desc` üzerine kurulu — **yeni sıralama bu indeksi kullanamaz**; sayfalama tutarlılığı ve performans birlikte gözden geçirilecek · kullanıcının saat dilimi bilinmiyorsa · tüm gruplar dolu
- **Kabul (ölçülebilir):** Farklı bölgelerden 10 grupla, kullanıcının bölgesine en yakın grup **ilk sırada** · "boş kontenjanı var" filtresi dolu grupları gizliyor · `invite_code` yanıtta **yok** (mevcut sözleşme testi yeşil) · sayfalama tekrar/atlama üretmiyor.
- **Tuzaklar:** Ofset farkını istemcide hesaplayıp sunucuya sıralama diye göndermek sayfalamayı bozar; sıralama **sunucuda** olmalı.
- **Model önerisi:** 🟣 Pro

#### WP-329: Birincil grup 🏠
- **Program/Faz:** Faz E · Grup semantiği · **Durum:** [ ] Bekliyor · **Bağımlılık:** WP-326
- **Problem:** Kullanıcı birden çok gruba üye olabiliyor ama "grup görevi hangi grubun?", "grup hedefi hangisi?", "başarım hangi grubu sayıyor?", "üç gruptan üç dürtme mi gelir?" soruları **cevapsız**.
- **Kapsam dışı:** Çoklu grup desteğini kaldırmak (üyelik çoklu kalır), grup arası veri taşıma.
- **SAHİP dosyalar (yaz):** `supabase/migrations/00NN_primary_group.sql` · `group_providers.dart` · grup seçim UI'ı · görev/hedef/başarım okuma yolları
- **DOKUNMA:** `groups.time_zone` (WP-326) · keşif (WP-328)
- **Adımlar:**
  - [ ] Kullanıcı bir **birincil grup** seçer (K5)
  - [ ] **Görev · hedef · başarım · bildirim** birincil grubu sayar
  - [ ] Diğer gruplar üyelikte kalır ama sayaç tutmaz
  - [ ] 🔴 Grup değiştirme ekranında **bir kez uyarı**: gün sınırı değişebilir
- **Veri/Migration etkisi:** Yeni alan + mevcut kullanıcılara varsayılan atama (tek grubu olan → o grup). Geri alma: kolon düşürülür.
- **Ortam/Deploy:** local → staging → production ayrı GO.
- **RLS/Güvenlik:** Kullanıcı yalnız **üye olduğu** bir grubu birincil seçebilir — sunucuda doğrulanır.
- **Edge-case'ler:** hiç grubu yok · birincil gruptan **çıkarılmış** · birincil grup silinmiş · tek grubu var (otomatik birincil olmalı, seçim sorulmamalı)
- **Kabul (ölçülebilir):** Üç gruptaki kullanıcıya **tek** grup görevi listesi geliyor · dürtme bildirimi **bir kez** düşüyor · birincil grup değişince gün sınırı yeni bölgeye geçiyor ama **geçmiş gün toplamları değişmiyor** (WP-325 damgası sayesinde) · birincil grup silinince kullanıcı boşta kalmıyor (yeniden seçim istenir).
- **Tuzaklar:** Grup değişince gün sınırı da değişir; kullanıcının serisi bir gün kayabilir — **uyarı şart**, sessiz yapılırsa "serim neden kırıldı" şikâyeti gelir.
- **Model önerisi:** 🔴 Opus

---

### Faz F — Kamp ateşi ve görsel işler

Mağaza çıkışını **bloklamaz**. Faz A–E'den sonra.

| WP | İş | Durum | Not |
| --- | --- | --- | --- |
| **WP-295** | Kamp ateşi: oturma yayları + 2 poz | [ ] Bekliyor | Kart aşağıdaki tarihsel bölümde **geçerli** duruyor. İlk çıktı kod değil, **parametrik önizleme** |
| **WP-299** | Gündüz/gece gökyüzü + gece uyuma | [ ] Bekliyor | WP-295 ile **aynı sahne dosyaları → seri koşar** |
| — | Gökyüzü için grup bölgesi | — | **WP-326**'nın saat dilimi alanına dayanır. Enlem/boylam gerekirse **ayrıca** konuşulur (konum izni açar) |

⚠️ **Kural (sahip talebi):** görsel işlerde **ilk çıktı kod değil** — parametrik
önizleme gelir, sahip sayıyı/pozu seçer, seçilen değer teste bağlanır.

⚠️ **Kare bütçesi:** kamp ateşi sahnesinde `p95 ≤ 16.7 ms · jank ≤ %1`
(`flutter run --profile` + timeline). Bu ölçüm WP-299 başlamadan **WP-295'in
kabulünde** yapılmalı; yoksa gökyüzü körlemesine yazılır.

> ⚠️ **Faz F, Faz E ile çakışmaz** (farklı dosyalar) ama `.agents/AGENTS.md §1.2`
> gereği aynı anda en fazla iki çalışma hattı açılır.

---

## PLAN 2 — MAĞAZA HAZIRLIĞI

> 🧾 **WP kartları bu fazlar başlarken açılır** (numaralar 330'dan devam eder).
> Sebep: mağaza işlerinin çoğu **ops**, kod değil; SAHİP dosya sınırı ve kabul
> kriteri ancak hesap doğrulaması ve Faz G kararı netleşince yazılabilir.
> Bugünden geçerli iki eski kart: **WP-276** (hesap silme kanıtı → Faz I2) ve
> **WP-277** (staging ops kabul kanıtı).

### Faz G — Kimlik: isim ve logo 🔴 *erken karar, geç uygulama*

Sahip: *"logo ve isim tekrar düşünülmeli, hem TR hem English."* Bu karar **her
mağaza görselini, mağaza kaydını ve MSIX kimliğini** etkiler.

- **Değişebilir:** görünen uygulama adı, logo, mağaza başlığı, uygulama içi marka
- **Değişmesi pahalı:** Android `applicationId` — değişirse **yeni uygulama** olur, mevcut kullanıcılar güncelleme alamaz
- **Değişmesi pahalı:** MSIX `Identity Name` — Partner Center'da rezerve edilen adla **birebir** eşleşmeli, sonradan değişmez

### Faz H — Microsoft Store (önce burası)

Play doğrulaması sürerken buraya çıkmak mantıklı: Windows sürümü zaten üretiliyor
ve Microsoft'un incelemesi genelde daha hızlı.

- **H1.** Partner Center'da uygulama adını rezerve et (Faz G'den sonra)
- **H2.** MSIX kimliğini Store'un verdiği `Identity Name`/`Publisher` ile hizala — şu anki paket kendi imzamızla üretiliyor, Store'a öyle gitmez
- **H3.** Yaş derecelendirme anketi · kategori · gizlilik politikası URL'i
- **H4.** Mağaza görselleri: ekran görüntüleri (TR + EN) · açıklama · tanıtım videosu
- **H5.** Windows cihaz QA'sı (`docs/QA-WINDOWS.md`, `docs/WINDOWS-VM-QA.md`)
- **H6.** İlk gönderim → geri bildirim → düzeltme turu

### Faz I — Google Play

- **I1.** 🔴 **AAB.** Play `.apk` kabul etmiyor. Release hattı sadece APK üretiyor — bundle çıktısı eklenecek
- **I2.** 🔴 **Hesap silme kanıtı.** Akış uygulama içinden **ve** webden erişilebilir olmalı, uçtan uca kanıtlanmalı (istek → 14 gün → kalıcı silme → yetkisiz çağrı reddi → rollback). Kodu var, kanıtı yok
- **I3.** **Gizlilik politikası + Kullanım şartları canlı HTTPS adreste** → **GitHub Pages** (K7). Metinler `docs/legal/` içinde hazır, hiçbir yerde yayınlanmıyor. Data Safety formu bunsuz doldurulamaz
- **I4.** **Data Safety formu** — envanter `docs/play-store/DATA-SAFETY.md`'de satır satır hazır
- **I5.** İçerik derecelendirme anketi + mağaza görselleri (TR + EN)
- **I6.** Kullanıcı içeriği beyanı (raporlama/engelleme/moderasyon) cihaz smoke testi
- **I7.** İmzalama anahtarı yedeği + rollback planı yazılı olarak
- **I8.** Kademeli yayın: %10 → %25 → %50 → %100 (her kademe ≥ 24 saat)

Kapı listesi: [`docs/play-store/PLAY-RELEASE-GATE.md`](docs/play-store/PLAY-RELEASE-GATE.md)

### Faz J — Yayın sonrası

- Çökme/hata takibi (Sentry var), ilk 72 saat gözlem
- Mağaza yorumlarına yanıt akışı — Faz B'deki döngüyle birleşir
- İlk güncelleme turu

---

## ✅ Kapanan Kararlar

| Karar | Sonuç |
| --- | --- |
| Diller | **Sadece TR + EN.** DE/AR dil seçeneğinden kalkar, `.arb` dosyaları kalır |
| Aylık e-posta raporu | **İptal.** Kod dursun, kurulum yapılmayacak (domain + SPF/DKIM + sağlayıcı gerekiyordu) |
| Tema sihirbazı sadeleştirmesi | **Gerek yok.** Tek gerçek sorun his adımıydı, v49'da çözüldü |
| **K1** Yanıt kanalı | **Çift yönlü** — kullanıcı admin yanıtına geri yazabilir |
| **K2** Şifre değiştirme | Klasik üç alan + "Şifremi unuttum"; mevcut şifre **gerçekten** doğrulanır. Google/passkey girişi zaten yok (`passkeys` ölü bağımlılık) → özel durum ekranı gerekmiyor |
| **K3** Tanıtım turu | Yalnız **ilk açılışta**, ekrana basınca sonraki balona geçer |
| **K4** Gün sınırı backfill | **Konusuz kaldı** — gün toplamları saklanmıyor, her sorguda hesaplanıyor |
| **K5** Çoklu grup | **Birincil grup** — kullanıcı seçer; görev/hedef/başarım/bildirim onu sayar |
| **K6** İsim + logo | ⏸️ **Faz B'de konuşulacak** — tek açık karar |
| **K7** Gizlilik URL'i | **GitHub Pages** — bedava, HTTPS hazır, `docs/legal/*.md`'den yayınlanır |
| **K8** Yurtdışı gün sınırı | **Birincil grubun bölgesi** belirler; grubu olmayan cihaz saat dilimini kullanır. Gruplara bölge alanı + üye sınırı 8 + keşifte yakınlık sıralaması |
| Üye sınırı | **8 kişi** — kod yazıldı (`0071`), migration **uygulanmadı** |

---

## ⚠️ Risk ve Tuzak Notları

- **Sürüm disiplini.** Sürüm sahibin onayıyla çıkar; düzeltmeler birikir, tek sürümde çıkar.
- 🔴 **Sahipsiz `v49` tag'i.** Koşum düştüğü için release oluşmadı ama **tag uzakta kaldı** (`4964188`). İki riski var: (a) tag listesine bakan "v49 çıkmış" sanır; (b) aynı numarayla yeniden denenirse tag çakışır. **Öneri: uzaktaki `v49` tag'i silinsin**, sıradaki sürüm `v49` numarasını temiz kullansın. *Uzak tag silmek dışa dönük bir iş — sahip onayı bekliyor.*
- **Migration drift.** Repo `0071`, ortamlar `0070`. Sürümden önce staging apply şart.
- **Geri alınamaz işler.** Hesap silme purge'ü bu sınıfta — yedek + staging provası + rollback betiği olmadan production'a dokunulmaz. *Gün sınırı artık bu sınıfta değil* (toplamlar saklanmıyor).
- **Ölü anahtar riski.** "Mevcut şifre" gibi görünen ama hiçbir şey doğrulamayan arayüzler en kötü hata türü — kullanıcı korunduğunu sanır. Faz C'de özellikle kontrol edilecek.
- **MSIX kimliği** Partner Center'da rezerve edilen adla eşleşmezse paket reddedilir; sonradan düzeltmek yeni uygulama demektir.
- **Saat dilimi offset olarak saklanmaz** — hep IANA adı (`America/New_York`). Türkiye'de yaz saati olmadığı için bu hata bugüne kadar hiç görünmedi.

---

## 🧪 Cihaz QA Kuyruğu — kod bitti, cihaz testi bekliyor

> ✅ **BU KUYRUK KAPANDI (sahip, 2026-07-26).** v46–v48 turlarında cihazda test
> edildi; boş ikinci bildirim ve taç/aura dahil hiçbirinde sorun çıkmadı.
> Şifre işi ayrı madde değil — **Faz C1**'de kodlanıp orada test edilecek.
>
> ℹ️ Aşağıdaki tablo **tarihsel kayıt** olarak duruyor: hangi işin neyi
> doğrulaması gerektiği yazılı kalsın diye. Yeni iş buradan sıra almaz.

| WP | Kod bitiş | Cihazda/panelde doğrulanacak | Tür |
|---|---|---|---|
| **WP-286** Ayarlar IA + Bildirim Merkezi | 2026-07-24 (Codex) | Ayarlarda bildirim/izin/rapor için tek giriş · izni sistemden kapat/aç → geri dön, özet ≤ 1 sn güncelleniyor · "Düzelt" doğru sistem ekranını açıyor · `unknown` durumda "hazır" demiyor · aylık rapor tercihi kalıcı | Android cihaz |
| **WP-287** Şifre sıfırlama | 2026-07-24 (Claude) | 🔶 **Önce sahip ops adımı:** staging Supabase panelinde Redirect URL + Site URL + recovery şablonuna `{{ .Token }}` ([runbook](docs/SIFRE-SIFIRLAMA-PANEL-RUNBOOK.md)) · sonra Android link akışı + Windows kod akışı + kayıtsız e-postada nötr mesaj. **Production paneli ayrı kapı (K-6), bu QA'nın parçası değil.** | Panel + cihaz |
| **WP-288** Tema modeli v2 + göç | 2026-07-24 (Codex) | 🔴 **Eski özel paletli gerçek cihazda** ilk açılış → **görünüm değişmemeli** (göç) · aktif tema korunuyor · silme yuvayı boşaltıyor, index kaydırmıyor · açık/koyu/sistem modu | Android cihaz (yükseltme) |
| **WP-290** Tema sihirbazı + görünüm ekranı | 2026-07-25 (Claude) | 8 adımın önizlemesi anında güncelleniyor · kaydedilen tema tüm ekranlarda geçerli · his efektleri (gren/parıltı) **gerçekten görünüyor** · AA uyarısı + Düzelt · düzenle/sil/3 yuva dolu mesajı · "hareketi azalt" · RTL (AR) | Android cihaz |
| ~~**WP-291** Kart boyut paneli~~ | 2026-07-24 (Claude) | 🔴 **Beta 1'de düştü:** düzenleme ekranı bomboş açıldı (yalnız panel görünüyordu). QA'sı **WP-305**'e devredildi. | — |
| **WP-297** Gömülü fontlar | 2026-07-25 (Claude) | Sihirbazda Inter/Literata/JetBrains Mono seçilebiliyor · seçilen font **gerçekten** değişiyor · ağırlık kaydırıcısı 4 kademede farklı görünüyor · Türkçe karakterler kutu değil · kayıtlı eski temaların görünümü aynı | Android cihaz |
| **WP-292** Taç görseli | 2026-07-25 (Claude) | 🔴 **Sahip beğenisi** (asıl kabul) · liderlik/sohbet/ısı tablosu gibi **küçük avatarlarda** taç okunuyor mu · liste satırları küçük avatarlarda ~2–4 px uzadı, göze batıyor mu · taçsız kullanıcı düz avatar · **p95 kare ≤ 16.7 ms / jank ≤ %1** (`--profile` + timeline; animasyon eklenmediği için risk düşük ama ölçüm cihazsız yapılamadı) | Android cihaz |
| **WP-298** Avatar aura efekti | 2026-07-25 (Claude) | 🔴 **Sahip beğenisi** · ✅ kademe okuması doğrulandı (altın = 3., bronz/gümüşte aura YOK) · profil ve sosyal profilde görünüyor, **listelerde görünmüyor** · aura yanlara taşıyor, kesilmiyor · fotoğraf değiştir düğmesi yerinde · **hareketi azalt** açıkken donuyor · 🔴 **p95 ≤ 16.7 ms / jank ≤ %1** — WP-298 **animasyon ekleyen tek iş**, bu ölçüm asıl burada gerekli (profil ekranı, `--profile` + timeline) | Android cihaz |

| **WP-294** l10n borcu + CI kapısı | 2026-07-25 (Claude) | Hesap silme akışı (dialog · şifre alanı · iki snackbar · kart alt metni) **cihaz dilinde** okunuyor · görev listesinde bitiş tarihi etiketi doğru ay adını veriyor (TR `28 Ağu`, EN `Aug 28`) ve **çökmüyor** · ana ekran düzenleme modunda "Boyut …" ipucu · istatistikte "En verimli saat" satırı · Android **bildirim ayarlarında** 4 kanalın adı *ve açıklaması* ayrı görünüyor · yeni/uzun metinler 360 px'te taşmıyor | Android cihaz |
| **WP-302** Sihirbaz önizleme + palet sadeleştirme | 2026-07-25 (Claude) | Tema sihirbazında aşağı kaydırırken **önizleme üstte sabit kalıyor** · yatay/kısa ekranda düzen bozulmuyor · Görünüm ekranında artık **tek liste** (Hazır Temalar) var · 🔴 **eski yerleşik paletli cihazda** ilk açılış: görünüm makul, seçili kart görünüyor | Android cihaz |
| **WP-303** Boş ikinci bildirim | 2026-07-25 (Claude) | 🔶 **Önce staging'e edge deploy şart** (aşağıdaki nota bak) · güncelleme/duyuru/dürtme bildirimi geldiğinde **yanında içeriksiz ikinci bildirim ÇIKMIYOR** · gerçek bildirim başlık+gövdesiyle ve doğru kanalda düşüyor | Android cihaz |
| **WP-307/308/309/310/311/313** v46 sahip geri bildirimi (v48) | 2026-07-25 (Claude) | **307:** Biçim/Atmosfer ayarla → His seç: **ayarlar duruyor** · **308:** koyu zemin + açık metinli özel tema kaydet → Ana Sayfa/Profil başlıkları **okunuyor** (açık modda da) · **309:** renk seçicide ızgaranın **son hücresi gökkuşağı** → spektrum açılıyor, seçilen renk önizlemeye yansıyor · **310:** font çiplerine bastıkça düğmeler **yerinde duruyor** · **311:** yazı adımında önizleme "Başlık/Gövde/Sayaç yazı tipi" örnekliğini gösteriyor · **313:** istatistikte 7 ve 14 günde **her sütunun altında** tarih, 30 günde okunabilir | Android cihaz |
| **WP-305** Düzenleme ekranı + sabit boyut paneli (WP-291 onarımı) | 2026-07-25 (Claude) | 🔴 **Beta 1 hatası:** "Kartları düzenle" bomboş açılıyordu · Ana ekran → düzenle: **kartlar, ipucu metni ve ızgara zemini görünüyor** · sayfa **kaydırılıyor** · boyut paneli **hep en altta**, kaydırınca kaybolmuyor ve **son kartı örtmüyor** · + ile kart ekleyince **ekranda beliriyor** · sürükle-bırak / ⤒ compactUp / ↺ sıfırlama çalışıyor · dokunma hedefleri ≥ 48 dp · Windows'ta da aynı | Android cihaz + Windows |
| **WP-304** Bildirim Merkezi düzeni | 2026-07-25 (Claude) | Merkezde üstte normal ayarlar, **test/tanı kartı en altta** · "Alarm ve zamanlayıcı" satırı yok · **hatırlatıcı hiçbir yerde yok** (sahip kararı: alarm aynı işi yapıyor) · Duyurular **Ayarlar'da**, okunmamış varken **nokta** çıkıyor, açınca okundu işaretleniyor · eski hatırlatıcısı olan cihazda **çökme yok** | Android cihaz |

**WP-289** (his araştırması) tamamen kapandı — doküman WP'si, QA gerektirmez.

## 🗄️ TARİHSEL — WP kayıtları (buradan yeni iş alınmaz)

> 🔴 **Bu bölüm geçmiş kayıttır** — sırada ne olduğu **yukarıdaki Yol
> Haritası**'nda, faz + WP olarak yazar.
>
> ✅ **Hâlâ geçerli iki kart:** **WP-295** (kamp ateşi oturma + 2 poz) ve
> **WP-299** (gökyüzü). İkisi de **Faz F**'e bağlandı, kartları aşağıda duruyor.
>
> ❌ **İPTAL — yol haritasıyla çelişir, uygulanmaz:**
> - **WP-300** `groups.location` (enlem/boylam + tz) → yerini **WP-326** aldı:
>   enlem/boylam **yok**, sadece saat dilimi (konum izni açmamak için).
> - **WP-301** sunucu gün sınırı + `metric_day` backfill → **konusuz**: sunucu
>   zaten `Europe/Istanbul` ve gün toplamları hiçbir tabloda saklanmıyor.
>   Yerini **WP-325** (kayıt anında damgalama) aldı.
>
> 🕰️ "Beta 1 / beta 2" modeli de tarihseldir — artık faz + sahip onaylı tek sürüm.

| # | İş | Kod durumu | Başlamaya hazır mı? |
|---|---|---|---|
| ~~1~~ | **WP-296** — `main`'de kırmızı 3 test | [x] **TAMAM** (2026-07-25) | ✅ Bitti — 759 yeşil / 0 kırmızı; 2 ürün hatası + 1 saate bağımlı test |
| ~~1~~ | **WP-297** — gömülü fontlar (Inter · **Literata** · JetBrains Mono) | [x] **TAMAM** (2026-07-25) | ✅ Bitti — 767 yeşil; Lora ölçüm sonucu elendi (eksen 400–700) |
| ~~1~~ | **WP-292** — taç görseli | [x] **TAMAM** (2026-07-25) | ✅ Bitti — 776 yeşil; sahip onaylı geometri + 2 golden. Kalan tek şey **sahip beğenisi** (QA kuyruğunda) |
| ~~1~~ | **WP-294** — l10n borcu + audit CI kapısı | [x] **TAMAM** (2026-07-25) | ✅ Bitti — 793 yeşil; 40 bulgu → 0, 26 yeni anahtar × 4 dil, CI kapısı kırmızı-yeşil kanıtlı. "EN/TR'ye daraltma" dalına **dokunulmadı** (K-7 açık, dil seti aynı) |
| **1** | **WP-295** — kamp ateşi: oturma yayları + 2 poz | [ ] Kodlanacak | ✅ **Blokaj kalktı** (sahip konuşması 2026-07-25) — **beta 2 kapsamı.** İlk çıktı kod değil, parametrik önizleme |
| **2** | **WP-299** — gündüz/gece gökyüzü + gece uyuma | [ ] Kodlanacak | ⏸️ WP-295 ile **aynı dosyalar → seri koşar.** Beta 2 kapsamı |
| **3** | **WP-300** — `groups.location` (enlem/boylam + tz) | [ ] Kodlanacak | ⏸️ WP-299'un çıpa seam'inden sonra. 🟡 Migration (additive/nullable). Beta 2 kapsamı |
| **?** | **WP-301** — 🔴 sunucu gün sınırı `Europe/Istanbul` + `metric_day` backfill | [ ] Kodlanacak | 🔴 **Sahip kapsam kararı bekliyor:** beta 2 mi, sonraya mı? Geri alınamaz veri işi, kamp ateşinden ayrı |
| ~~—~~ | **WP-298** — avatar aura efekti (PUBG tarzı sis/parıltı) | [x] **TAMAM** (2026-07-25) | ✅ Bitti — 784 yeşil; sahip üç kapsam sorusunu da yanıtladı (profil+sosyal profil · altından itibaren kademeli · kademe rengi) |
| ~~A~~ | **WP-306** — tema adı alanında klavye açılıp kapanıyor | [x] **TAMAM** (2026-07-25, v47) | v46 sahip geri bildirimi — [ayrıntı](docs/V46-SAHIP-GERI-BILDIRIMI.md#wp-306--tema-adı-alanında-klavye-açılıp-kapanıyor-) |
| ~~A~~ | **WP-313** — grafikte her sütunun altında tarih | [x] **TAMAM** (2026-07-25, v48) | Ay adı yalnız ay değişince; etiket varsayımı 26→14 px, 7/14 günde adım 1 |
| ~~B~~ | **WP-307** — His adımı önceki ayarları siliyor | [x] **TAMAM** (2026-07-25, v48) | `withFeel` koşulsuzdu; `shapesEdited`/`atmosphereEdited` bayrakları elle ayarı korur |
| ~~C~~ | **WP-308** — özel temada bazı metinler okunmuyor | [x] **TAMAM** (2026-07-25, v48) | Tipografi tek kopya + pişmiş renk; `_buildFromTokens` artık `recolored()` ile tazeliyor |
| ~~D~~ | **WP-310** — font adımında düğmeler zıplıyor | [x] **TAMAM** (2026-07-25, v48) | `showCheckmark: false` + sabit kenarlık; çip dikdörtgenleri seçimden bağımsız |
| ~~D~~ | **WP-311** — canlı önizleme değişimi göstermiyor | [x] **TAMAM** (2026-07-25, v48) | `ThemePreviewFocus.typography` — yazı adımında etiketli örneklik. His adımı odağı WP-312'ye bağlı |
| ~~E~~ | **WP-309** — renk seçici: hazır palet + spektrum düğmesi | [x] **TAMAM** (2026-07-25, v48) | Izgaranın son hücresi gökkuşağı düğmesi → HSV spektrum + hex |
| ~~F~~ | **WP-314** — his seçimi önizlemede görünmüyor (WP-307 yan etkisi) | [x] **TAMAM** (2026-07-25, v49) | Her hissin atmosferden bağımsız kendi imzası + "biçim/atmosferi de hizala" düğmesi |
| **?** | **WP-312** — 🔴 sihirbazın kavramsal sadeleştirmesi | [ ] Kodlanacak | 🔴 **Sahip kararı bekliyor:** adımlar birleşsin mi, yoksa her role açıklama + önizleme vurgusu mu |
| — | WP-276 / WP-277 — staging ops kabul kanıtı | [ ] Kod azı, ops çoğu | ⏸️ Beta dışı; sentetik staging kanıtı + WP-276 Play Store için gerekli |
| — | WP-278 / WP-279 | [?] **Ürün/ops kararı** | 🔴 Sahip kararı olmadan kod yazılmaz |
| — | Production backend değişikliği | 🔴 Kapalı | `deploy_enabled: false`; yeni terfi backup + dry-run + somut GO ister |

**Beta 1 için kalan:** ~~296~~ → ~~297~~ → ~~292~~ → ~~298~~ → ~~294~~ → ✅ **hepsi bitti, beta 1 çıkıyor.**
**Beta 2 için kalan:** **WP-295 → WP-299 → WP-300** (bu sırayla, seri) + admin işleri (kapsam sahipten bekleniyor) + WP-301 (kapsam kararı bekleniyor).

### Tema programından devreden borç — durumları

1. ✅ **ADR-4 gömülü fontlar → KARAR VERİLDİ (sahip, 2026-07-25): eklenecek. WP-297 açıldı.** 3 aile: gövde **Inter**, başlık **Lora**, saat **JetBrains Mono** (başlıkta Playfair Display alternatifi elendi — Lora her puntoda daha güvenli). Font indirmesi sahip tarafından onaylandı.
2. ✅ **APK boyut ölçümü KAPANDI (WP-297, 2026-07-25):** fontlar APK'ya **+1.02 MB** ekliyor, kriter ≤ 2.5 MB **geçti**. WP-290'ın ölçemediği borç böylece kapandı. Yöntem: iki APK'yı karşılaştırmak yerine tek APK'nın içindeki girdilerin sıkıştırılmış boyutu okundu — bayat `libapp.so` sorunundan etkilenmiyor.
3. ⏸️ **`AppFeel.edgeIrregularity`** — his değerlerinde taşınıyor, çizilmiyor (her karta özel `ShapeBorder` gerekir). Sihirbazda kullanıcı kontrolü **yok** → ölü anahtar değil. **Sahip 2026-07-25'te "sorun değil" dedi; WP açılmadı.**
4. ⏸️ **`AppMotion` süreleri** — hâlâ hiçbir animasyon tüketmiyor (WP-288'den devraldı). Sihirbazda kullanıcı kontrolü yok → ölü anahtar değil. **Sahip 2026-07-25'te "sorun değil" dedi; WP açılmadı.**

### Sahip kararları (2026-07-25 turu)

- **Gömülü font:** ✅ evet, 3 aile · başlık fontu **Lora** · indirme onaylı → WP-297.
- **AR/RTL:** "şimdilik dert etmiyoruz" — **K-7 kararı hâlâ açık.** WP-297 yine de `fontFamilyFallback` kurar (maliyeti yok, AR sonradan kalırsa kutu karakter doğmaz).
- **Bildirim/widget'ın sistem fontunda kalması:** kabul edildi (native taraf Flutter fontuna erişemez).
- **Hazır temaların gövde fontu:** hata değil, tasarım — hazır temaların şemasında gövde ailesi yok. WP-297'de hazır temalara da gövde ailesi verilip verilmeyeceği kart içinde kararlaştırılır.
- **Beta sayısı:** yukarıdaki 🔴 BETA KARARI — *aynı gün güncellendi: tek beta → **iki beta**.*
- **Kamp ateşi (WP-295) konuşması yapıldı, kararlar [notlar F-09](docs/YENI-OZELLIK-NOTLARI.md):** tasarımcıya para verilmiyor (~10.000 TL reddedildi), hayvanlar **vektör kalıyor**, PNG/Rive hattı betadan sonraya. İstek üçe bölündü (295 oturma+2 poz · 299 gökyüzü · 300 konum) + 🔴 301 (sunucu gün sınırı) açıldı.
- **Migration yetkisi (sahip):** "migration'ları sen yapabilirsin, benlik ne var" → yazma **ve uygulama** Claude'da; production'da dry-run + backup koşulur ve satır sayılarıyla raporlanır.
- **Taç geometrisi (WP-292):** canlı önizlemeden seçildi — **5 uç · span 50° · tip 1.63 · inci 0.10 · kavis 0.50**. Sahip "önce tasarımı göster, sonra kodla" dedi; akış böyle yürütüldü ve sayılar koda birebir geçti.
- **Avatar aura efekti (WP-298):** sahip üç kapsam sorusunu da yanıtladı — **(a) yalnız profil + sosyal profil** (listeler durağan kalır), **(b) altın kademede başlar, yukarı doğru kademeli artar**, **(c) parıltı o kademenin rengi**. ✅ **Doğrulandı (sahip, 2026-07-25): "altından itibaren" = altın kademe (3.)** — kod olduğu gibi doğru, bronz/gümüşte aura yok.
- **Aura efekti başarım rozetlerine taşınsın mı? → HAYIR (sahip, 2026-07-25).** Sahip sordu, değerlendirildi, **vazgeçildi** — WP açılmadı. Gerekçe kayda geçiyor ki bir daha araştırılmasın: (a) katalog listesi tembel değil ([`achievement_showcase.dart:439`](app/lib/features/profile/widgets/achievement_showcase.dart:439) `..._buildCatalog(theme)` tüm kartları `Column`'a serpiyor), yani ~24 rozetin hepsi aynı anda ağaçta → 24 ticker, WP-298'de listeler için bilinçle reddedilen şeyin aynısı; (b) katalog satırında rozetle metin arası **12 px** ([satır 1489](app/lib/features/profile/widgets/achievement_showcase.dart:1489)), `1.5×` aura başarım adının altına giriyor; (c) vitrindeki 3 rozet `spaceEvenly` duruyor, auralar birbirine değip kartın kenarlığından sızıyor; (d) `_BadgeCircle` açık rozetlerde **zaten** statik `boxShadow` parıltısı taşıyor. Mor gerekmiyordu zaten: `kSecretAchievementColor` + `badgeVisualColor` gizli+açık rozeti şimdiden mora yönlendiriyor.

## Yeni Özellik Turu — Aşama A (Plan Kuyruğu)

> **Burada yalnız KODLANMAYI BEKLEYEN kartlar var** — beta 2 kapsamı: **WP-295 → WP-299 → WP-300** (bu sırayla, seri) + kapsam kararı bekleyen **WP-301**.
> Kod/test'i bitmiş WP'lerin kartı [arşivde](docs/archive/progress-tarihsel-2026-07.md); kalan işleri yukarıdaki QA kuyruğunda.

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
DALGA 5  WP-296 ✅ → WP-297 ✅ → WP-292 ✅ Taç → WP-298 ✅ Aura   kod/test tamam
DALGA 6  WP-294 ✅ l10n borcu + CI kapısı
──────── BETA 1 BURADA ÇIKAR (2026-07-25, beta-v4309) ────────
DALGA 7  WP-295 Oturma+2 poz → WP-299 Gökyüzü → WP-300 Konum   (SERİ, aynı dosyalar)
         ‖  Admin işleri (kapsam sahipten)   ‖  WP-301? (kapsam kararı)
──────── BETA 2 ────────  →  stable
```

> ✅ **WP-295 blokajı KALKTI** (sahip konuşması 2026-07-25, [notlar F-09](docs/YENI-OZELLIK-NOTLARI.md)). İstek üçe bölündü; **DALGA 7 seri koşar** — 295/299 aynı sahne dosyalarına yazıyor, paralel çakışır.
> 🔴 **WP-295'in ilk çıktısı kod değil, parametrik canlı önizlemedir** (taç akışı). Sahip sayıyı seçer, sayı hem koda hem teste girer.
> 🟡 **WP-294'ün K-7'ye bağlı kısmı yalnız "EN/TR'ye daraltma" dalı;** audit genişletme + UTF-8 + CI kapısı bugünkü 4 dil gerçeğiyle yapılabilir.
> ⚠️ **296 → 297 → 292 SERİ koşar** — 297 ve 292 aynı golden yüzeyine giriyor, paralel çakışır.
> ⚠️ **"Önce X'in cihaz kabulü" kapıları bu tur geçersiz** (tek beta kararı, `§0.1`) — kod/test kapısı esas.
> ⚠️ Tema programı açıkken **Saat ve Başarım programları açılmaz** (`.agents/AGENTS.md §1.2`).
> ℹ️ Kapanmış kapılar (WP-293 Gate 0, golden baseline, 288↔289 sırası) arşiv kartlarında; burada tekrarlanmaz.

### WP-297: Gömülü font aileleri (ADR-4) 🔤 ✅ KOD/TEST TAMAM
- **Program/Faz:** Yeni Özellik Turu · Aşama A · Tema programı · (plan §3 F-04-B, ADR-4 — WP-290'dan devredildi)
- **Ajan:** Claude · **Durum:** [x] **Kod/test tamam (2026-07-25)** — `flutter analyze` **0**, tam paket **767 yeşil** (8 yeni). Üç aile paketlendi, sihirbazda 6 seçenek (3 platform + 3 gömülü). **Bekleyen:** cihaz QA (Android + Windows, tek beta turunda).
- 🔴 **SAHİP KARARI DEĞİŞTİ — Lora yerine Literata.** Sahip "Lora" demişti; font ikililerini indirip `fvar` tablosunu **ölçtüm** (tahmin etmedim) ve Lora'nın ağırlık ekseni yalnız **400–700** çıktı. Sihirbaz başlıkta w400/w700/w800/w900, gövdede w300/w400/w500/w600 istiyor → Lora'da **w300, w800, w900 sessizce kırpılacaktı**, yani ağırlık kaydırıcısının 4 kademesinden 3'ü ölü anahtar olurdu. Ölçülen aileler:
  | Aile | `wght` ekseni | Türkçe + `₺` | Boyut | Sonuç |
  |---|---|---|---|---|
  | **Inter** | **100–900** ✓ | tam | 856 KB | ✅ gövde/arayüz |
  | **Literata** | **200–900** ✓ | tam | 933 KB | ✅ başlık (Lora'nın yerine) |
  | **JetBrains Mono** | 100–800 (w900→800) | `₺` YOK → fallback | 183 KB | ✅ saat/sayaç |
  | ~~Lora~~ | 400–700 ✗ | tam | 207 KB | ❌ 3 kademe ölürdü |
  | ~~Playfair Display~~ | 400–900 | `₺` YOK | 294 KB | ❌ w300 kırpılır, display face |
  | ~~Bitter~~ | 100–900 ✓ | tam | 321 KB | ⏸️ yedek — **varsayılan ağırlığı 100**, eksen düşerse tüm yazı saç teli gibi olur; Literata'nın varsayılanı 400 olduğu için güvenli |
- ⚠️ **Subset adımı bilerek uygulanmadı.** Kart "Latin + Latin-Ext'e subset'le" diyordu; upstream ikililer **olduğu gibi** paketlendi. Gerekçe: (1) subset için `fonttools` kurmak gerekiyordu — CI'da tekrar üretilemeyen bir yerel araç zinciri, (2) subset sırasında bir Türkçe glif düşürmek gerçek bir risk, upstream bayt kopyası ise doğrulanabilir, (3) toplam **1.93 MB ham** zaten bütçe içinde ve APK'da sıkışıyor. Kiril/Yunan da geldiği için dil seti büyürse yeniden iş çıkmaz.
- 🔴 **Yolda bulunan gerçek tuzak — `app_theme.dart` `themed()` fallback'i düşürüyordu.** Yardımcı yalnız `fontFamily`'yi kopyalıyordu; `fontFamilyFallback` taşınmıyordu. Sonuç: gömülü (Latin) bir aile seçildiğinde `displayLarge` **dışındaki tüm** `TextTheme` slotları zincirsiz kalıyor, Arapça metin ve JetBrains Mono'da `₺` **kutu karakter** oluyordu — token'da zincir doğru kurulmuş olsa bile. Tek satır düzeltildi + regresyon testi yazıldı. `app_theme.dart` kart SAHİP listesinde yoktu, gerekçeli eklendi (o an başka lane tutmuyordu).
- ✅ **Ağırlık ekseni ölçülerek doğrulandı, varsayılmadı.** Variable font'un `wght` ekseni Flutter'da uygulanmazsa kaydırıcı ölü anahtar olurdu. Test `TextPainter` ile w300 ve w900 genişliğini karşılaştırıyor: kalın metin ölçülebilir şekilde daha geniş → eksen çalışıyor. Aynı test sihirbazın uçtan uca kademelerini de karşılaştırıyor.
- ✅ **Lisans:** üçü de **SIL OFL 1.1** — indirilen `OFL.txt` metinlerinden doğrulandı, varsayılmadı. Metinler `assets/fonts/LICENSES/` altında, `pubspec.yaml`'da asset olarak bildirildi (OFL "birlikte dağıt" şartı) ve `LicenseRegistry`'ye tembel kaydediliyor (`bundled_font_licenses.dart`). ⚠️ **Uygulamada lisans sayfasına giden bir giriş yok** — metinler APK'da ve kayıtta var ama arayüzden görünmüyor; görünür "Açık kaynak lisansları" ekranı **ayrı iş**.
- ✅ **APK boyutu ÖLÇÜLDÜ: +1.02 MB (kriter ≤ 2.5 MB → geçti).** WP-290'da başarısız olan "iki APK'yı karşılaştır" yöntemi terk edildi — bayat `libapp.so` yüzünden yalancı sonuç veriyordu. Yerine **tek APK'nın içindeki girdiler** okundu; asset ekleme kaynaklı büyüme tam olarak bu girdilerin sıkıştırılmış toplamıdır ve bayat artefakt sorunundan etkilenmez. `flutter clean` + `--flavor local --target-platform android-arm64` release build:
  | Girdi | Ham | APK'da (sıkışmış) |
  |---|---|---|
  | `Literata-Variable.ttf` | 932.7 KB | **501.3 KB** |
  | `Inter-Variable.ttf` | 856.0 KB | **448.2 KB** |
  | `JetBrainsMono-Variable.ttf` | 182.8 KB | **88.7 KB** |
  | 3 × OFL lisans metni | 12.9 KB | **5.7 KB** |
  | **WP-297 toplamı** | **1.94 MB** | **1.02 MB** |
  APK dosya boyutu bu build'de **29.07 MB**. (`MaterialIcons` 16.9 KB zaten vardı, sayıya dahil edilmedi.) `--flavor stable` **kullanılamaz**: production backend'e bağlı ve `CHANNEL` olmadan fail-closed duruyor — bu yüzden kartın rev.3 komutu koşulamıyor, `local` flavor eşdeğer ölçüm veriyor (aynı Dart/asset paketi).
- ⚠️ **Hazır temalara dokunulmadı** (bilinçli): `AppTypography.standard` gövdeye hâlâ aile yazmıyor, hazır temalar platform fontlarında kalıyor. Böylece WP-288'in preset goldenları **değişmedi** ve göç görünümü aynı kaldı. Gömülü fontlar yalnız sihirbazla oluşturulan temalarda devreye giriyor — kullanıcı seçtiği için ölü anahtar değil.
- **Değişen dosyalar:** yeni `assets/fonts/` (3 TTF + 3 OFL metni) · `pubspec.yaml` (`fonts:` bloğu + LICENSES asset) · yeni `theme_builder/bundled_font_licenses.dart` · `theme_builder/theme_draft.dart` (3 aile sabiti + `kBundledFontFallback` + `fallbackFor` + `toTokens` zinciri) · `theme_builder/theme_builder_steps.dart` (etiketler + gömülü işareti) · `core/theme/app_theme.dart` (`themed()` fallback) · `main.dart` (+1 lisans kaydı satırı) · yeni `test/features/profile/bundled_fonts_test.dart` (8 test). **l10n'a anahtar EKLENMEDİ** — font adları özel isim, çevrilmiyor (l10n sıcak yüzeyine girilmedi).
- **Model önerisi:** 🟣 Pro
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

### WP-295: Kozmetik — kamp ateşi oturma düzeni + iki poz 🔥 *(rev. 2026-07-25)*
- **Program/Faz:** Yeni Özellik Turu · Aşama A (son) · (plan §3 F-08 → notlar **F-09**)
- **Ajan:** — · **Durum:** [ ] Bekliyor · **Bağımlılık:** ✅ **Sahip konuşması yapıldı (2026-07-25)** — şart kapandı. **Asset kararı: tasarımcıya para verilmiyor, hayvanlar vektör kalıyor.**
- **Problem (sahip maddeleri 1 ve 2):** (a) `angle = π/2 + 2πi/n` ([campfire_scene.dart:264](app/lib/features/classroom/widgets/campfire_scene.dart:264)) **her n için** birini ateşin tam önüne (`sin=1`, ateşin üstünü kapatıyor), birini tam arkasına (`sin=-1`, `scale 0.6`, alevin içinde) koyuyor — sahip "önündeki ve arkasındaki görünmüyor" dedi, render bunu doğruladı. (b) Poz sayısı 4; sahip **2** istiyor: çalışmıyorken solgun boşta, çalışırken marşmelov.
- **Kapsam dışı:** 🔴 Gökyüzü/gündüz-gece (**WP-299**) · `groups.location` (**WP-300**) · sunucu gün sınırı (**WP-301**) · taç (WP-292) · tema motoru · XP/başarım mantığı · **PNG/Rive asset hattı** (betadan sonraki ayrı program).
- **SAHİP dosyalar (yaz):** `app/lib/features/classroom/widgets/campfire_scene.dart`, `app/lib/features/classroom/widgets/camp_critter.dart`, ilgili testler.
- **DOKUNMA:** `app/lib/core/stats/**`, `app/lib/core/widgets/crowned_avatar.dart` (WP-292'nin), tema motoru, `campfire/layered_campfire_fire.dart` gökyüzü tarafı (WP-299'un).
- **Adımlar:**
  - [ ] **Önce parametrik canlı önizleme** (halka yarıçapı · ölü bölge genişliği · ateş boyutu/yüksekliği · marşmelov döngüsü) — sahip sayıları seçer, seçilen sayı **hem koda hem teste** birebir girer. *(WP-292 taç akışının aynısı.)*
  - [ ] Oturma: kutuplarda **ölü bölge**, üyeler sol + sağ yaya dağıtılır. **Tek üye kutba düşmemeli** (yana oturur). Halka yarıçapı daraltılır (`rx = min(w*0.40, 232)` 4 üyede kenarlara savuruyor).
  - [ ] Pozlar 2'ye indirilir: `working`(laptop) ve `sleepy` atılır. Çalışan = marşmelov, çalışmayan = solgun boşta. **Molada = solgun, çevrimdışı = daha solgun + daha saydam** (mola/çevrimdışı bilgisi kaybolmasın).
  - [ ] 🔴 **Marşmelov pişme döngüsü:** `doneness = elapsed/(40*60)` clamp'li ([camp_critter.dart:414](app/lib/features/classroom/widgets/camp_critter.dart:414)) — kalıcı pozda 40 dk sonra ekranda **sabit koyu kahve leke** kalır. ~10 dk'lık **yiyip yenisini takma** döngüsüne çevrilir.
  - [ ] Eşzamanlı kızartma: 6 çalışan üye = 6 dal. Dal açısı/salınımı mevcut `phase`'den türetilir (kilitli hareket olmasın).
  - [ ] `_kPoseCycleSeconds`/`_kRoastStartSeconds` (170/135) kalkar — marşmelovun **%20 görünürlük** sebebi buydu.
- **Veri/Migration etkisi:** Yok. **Ortam/Deploy:** Local. **RLS/Güvenlik:** Yok.
- **Edge-case'ler:** n=1 (kutba düşmemeli) · n=2 · büyük n'de yaylara sığma · "hareketi azalt" açık · koyu/açık tema · 40 dk+ oturum (marşmelov yanmamalı).
- **Kabul (ölçülebilir):** Sahip kabulü · **hiçbir üye kutup ölü bölgesine düşmüyor** (testle: her yerleşimin `|sin(angle)|` değeri eşiğin altında) · `CritterPose` yalnız 2 değer · 40 dk+ oturumda marşmelov rengi `deep`e sabitlenmiyor · "hareketi azalt" açıkken animasyon durur · 🔴 **performans bütçesi:** orta seviye Android'de **p95 kare süresi ≤ 16.7 ms**, **jank ≤ %1** (`flutter run --profile` + timeline) — **beta 1 cihaz turunda ölçülür.**
- **Tuzaklar:** Sayıları önizlemeden geçirmeden koda gömmek · ölü bölgeyi n=1'de unutmak · marşmelov döngüsünü atlayıp "poz kalıcı oldu" demek · gökyüzünü buraya sızdırmak (WP-299).
- **Model önerisi:** 🟣 Pro

### WP-299: Kozmetik — gündüz/gece gökyüzü + gece uyuma pozu 🌅 *(yeni, 2026-07-25)*
- **Program/Faz:** Yeni Özellik Turu · Aşama A · (notlar **F-09 madde 3**)
- **Ajan:** — · **Durum:** [ ] Bekliyor · **Bağımlılık:** WP-295 (aynı sahne dosyaları — **seri koşar, paralel değil**)
- **Problem:** Sahne her zaman gece; ay ve yıldızlar sabit ([`ForestBackdropPainter`](app/lib/features/classroom/widgets/camp_critter.dart:14), `_SceneFrame` sabit gradyan). Sahip gerçek saate göre **kademeli** (anlık değil) hava değişimi istiyor.
- **Kapsam dışı:** 🔴 `groups.location` (**WP-300**) · sunucu gün sınırı (**WP-301**) · oturma düzeni ve pozlar (WP-295).
- **SAHİP dosyalar (yaz):** `app/lib/features/classroom/widgets/campfire_scene.dart` (`_SceneFrame`), `app/lib/features/classroom/widgets/camp_critter.dart` (`ForestBackdropPainter`), yeni `app/lib/core/time_engine/sky_phase.dart` + testi.
- **DOKUNMA:** `app/lib/core/stats/**`, sunucu, tema motoru, `groups` şeması.
- **Adımlar:**
  - [ ] **Saf fonksiyon önce:** `skyPhase(DateTime local, SkyAnchors anchors) → 0..1 + faz` — deterministik, cihaz saatinden bağımsız test edilir.
  - [ ] 🔴 **Çıpa kaynağı seam'i:** dört sivil çıpa (şafak · gündoğumu · günbatımı · akşam) **başta sabit saatlerden** gelir. WP-300 bitince aynı imza gerçek gündoğumu/batışını alır — **gökyüzü kodu değişmez.** Bu ayrım kartın varlık sebebi; birleştirilmez.
  - [ ] Gradyan + ay/yıldız sönümlemesi + gündüz güneşi. Geçiş **saatlik yumuşak**, ani kesme yok.
  - [ ] **Gece uyuma pozu** (sahibin opsiyonel isteği): gece fazında çalışmayan üye yan yatar. 🔴 **Gökyüzüyle AYNI saati kullanır** — ayrı saat kullanılırsa gökyüzü gündüzken hayvan uyur. *(WP-295'te atılan `sleepy` pozundan farklı bir şey: bu gökyüzüne bağlı.)*
- **Veri/Migration etkisi:** Yok. **Ortam/Deploy:** Local. **RLS/Güvenlik:** Yok.
- **Edge-case'ler:** gece yarısı sarması (23:59→00:01) · kutup bölgesi/olmayan gündoğumu (WP-300 sonrası) · yaz saati · "hareketi azalt" açık · cihaz saati elle değiştirilmiş · gündüz fazında ateşin glow'u okunur kalmalı (gündüz gökyüzü açık, alev kontrastı düşer).
- **Kabul (ölçülebilir):** `skyPhase` **saf ve testli** (sabit girdi → sabit çıktı, `DateTime.now()` okumaz) · 24 saatin her saati için faz testi · gece yarısı sarması testli · gündüz/gece/geçiş için 3 golden · çıpa kaynağı **tek yerden** geliyor (WP-300 tek satırla bağlanabiliyor) · gündüz fazında alev/glow görünür kalıyor.
- **Tuzaklar:** Faz fonksiyonuna `DateTime.now()` gömüp test edilemez hâle getirmek · geçişi ani yapmak · gece yarısı sarmasını atlamak · gündüzü sadece "gradyanı açtım" sanıp alevi görünmez bırakmak · WP-300'ü beklemek (beklemeye gerek yok, seam var).
- **Model önerisi:** 🟣 Pro

### WP-300: `groups.location` — grup konumu (enlem/boylam + IANA tz) 🌍 *(yeni, 2026-07-25)*
- **Program/Faz:** Yeni Özellik Turu · Aşama A · (notlar **F-09 madde 3**)
- **Ajan:** — · **Durum:** [ ] Bekliyor · **Bağımlılık:** WP-299 (çıpa seam'i hazır olmalı ki bağlanacak yer belli olsun)
- **Problem:** Grubun konumu yok. Sahip gökyüzünün **grubun şehrinin** gerçek gündoğumu/batışını izlemesini istiyor. `kWorldCityCatalog` ([world_clock_math.dart:73](app/lib/core/time_engine/world_clock_math.dart:73)) yalnız `label` + `tz` taşıyor — **koordinat yok.**
- **Kapsam dışı:** 🔴 **Günlük sıralama/metrik gün sınırı — WP-301.** Bu kart yalnız konumu **saklar ve gökyüzüne verir**; hiçbir istatistik semantiğine dokunmaz.
- **SAHİP dosyalar (yaz):** yeni `supabase/migrations/00NN_group_location.sql`, `app/lib/data/models/group*.dart`, grup oluştur/düzenle ekranları, `app/lib/core/time_engine/solar_position.dart` (yeni), ilgili testler + pgTAP.
- **DOKUNMA:** 🔴 `0053`/`0063`/`0064` metrik fonksiyonları ve `metric_day` (WP-301'in) · XP/başarım motoru · uygulanmış migration dosyaları (asla düzenlenmez, yeni dosya yazılır).
- **Adımlar:**
  - [ ] Migration: `groups` tablosuna **nullable** `latitude`/`longitude`/`timezone` (nullable = geri dönüşü kolay, mevcut gruplar bozulmaz). RLS: konum grup üyelerine okunur, yalnız yöneticisi yazar.
  - [ ] Gündoğumu/batış hesabı **yerelde, ağsız** (NOAA güneş konumu, ~80 satır, deterministik → testli). Yeni paket bağımlılığı yok.
  - [ ] WP-299'un çıpa kaynağını gerçek gündoğumu/batışa bağla (tek satır). **Konum yoksa sivil çıpalara düşer** — özellik kaybı değil, sessiz fallback.
  - [ ] Grup oluştur/düzenle UI + l10n (4 dil, `scripts/l10n_audit.py` kapısı geçmeli).
  - [ ] `kWorldCityCatalog`'a koordinat alanı.
- **Veri/Migration etkisi:** 🟡 **Var — additive, nullable, geri alınabilir.** **Ortam/Deploy:** staging → production (`Database Gates` iş akışı; dry-run + backup adımları koşulur, sonuç satır sayılarıyla raporlanır). **RLS/Güvenlik:** yeni sütunlar için politika + pgTAP şart.
- **Edge-case'ler:** konumu olmayan eski gruplar (fallback) · kutup bölgesinde gündoğumu **hiç olmayabilir** (matematik `null` dönebilir → çökmemeli) · yaz saati · geçersiz/uydurma koordinat · konum değişince gökyüzü anında tutarlı olmalı.
- **Kabul (ölçülebilir):** Migration local replay + pgTAP yeşil · konumsuz grup **fallback ile çalışıyor** (testli) · kutup bölgesi (örn. lat 78) çökmüyor · gündoğumu hesabı bilinen bir şehir/tarih için ±2 dk doğrulukta (testli) · `flutter analyze` 0 · tam paket yeşil · l10n kapısı yeşil.
- **Tuzaklar:** Sütunu `not null` yapıp mevcut grupları kırmak · gündoğumunu ağdan çekmek · kutup bölgesinde `null`'ı unutmak · **WP-301'i buraya sızdırmak** (en büyük tuzak — sahip ikisini aynı istekte söyledi ama boyutları farklı).
- **Model önerisi:** 🟣 Pro

### WP-301: 🔴 Sunucu — günlük metrik gün sınırı `Europe/Istanbul`'a sabitli *(yeni, 2026-07-25)*
- **Program/Faz:** Ayrı yürür — **kamp ateşinin parçası DEĞİL** · (notlar **F-09**)
- **Ajan:** — · **Durum:** [ ] Bekliyor · **Bağımlılık:** 🔴 **Sahip kapsam kararı** (beta 2 mi, sonraya mı) + WP-300 (konum olmadan doğru gün hesaplanamaz)
- **Problem:** Günlük metrik günü sunucuda **sabit yazılı**: `if p_day >= (timezone('Europe/Istanbul', clock_timestamp()))::date` ([0053_group_achievement_metrics.sql:87](supabase/migrations/0053_group_achievement_metrics.sql:87)); aynı sabit `metric_day` üretiminde de var (satır 116/120/151/174) ve 0063/0064 RPC'lerine akıyor. **Los Angeles'taki kullanıcının "günü" kendi saatiyle 15:00'te dönüyor.** Sahibin sezgisi doğruydu; bu kozmetik değil, var olan bir veri hatası.
- **Kapsam dışı:** Kamp ateşi görselleri (WP-295/299), XP eşikleri, taç kademeleri.
- **SAHİP dosyalar (yaz):** yeni `supabase/migrations/00NN_*.sql`, `supabase/tests/**`, `docs/recovery/MIGRATION-BASELINE.md`.
- **DOKUNMA:** 🔴 Uygulanmış migration'lar **düzenlenmez** · `crownRankForXp` / `kCrownXpThresholds` · uygulama tarafı gösterim mantığı (bu bir veri katmanı işi).
- **Adımlar:**
  - [ ] Etki ölçümü: kaç satır `metric_day` kayacak? **Önce sayıyı çıkar** (dry-run/read-only sorgu), sonra tasarım.
  - [ ] Karar: gün sınırı **grup konumuna** mı bağlanacak, **kullanıcıya** mı? (Grup sıralaması grup, kişisel istatistik kullanıcı olabilir — ikisi farklı cevap verebilir.)
  - [ ] Geriye dönük `metric_day` backfill + doğrulama; eski/yeni toplamların **tutarlılık karşılaştırması**.
  - [ ] pgTAP: birden fazla tz'de gün sınırı testi.
- **Veri/Migration etkisi:** 🔴 **Var ve GERİ ALINAMAZ** — mevcut geçmiş satırlar yeniden yazılır. **Ortam/Deploy:** staging'de tam prova → production. Production'da **backup + dry-run zorunlu**, sonuç **satır sayılarıyla raporlanır**. **RLS/Güvenlik:** mevcut politikalar korunur.
- **Edge-case'ler:** yaz saati geçişinde gün 23/25 saat olabilir · konumu olmayan grup · aynı oturum iki güne yayılıyor · sıralama liderinin geçmişe dönük değişmesi (kullanıcı gözünde "XP'm değişti" algısı) · streak/seri hesapları gün sınırına bağlıysa onlar da kayar.
- **Kabul (ölçülebilir):** Etkilenen satır sayısı **önce** raporlandı · staging'de eski/yeni toplam karşılaştırması yapıldı ve sapma açıklandı · pgTAP en az 3 farklı tz için yeşil · streak/seri hesaplarının etkilenip etkilenmediği **yazılı olarak** cevaplandı · production backup kimliği kayda geçti.
- **Tuzaklar:** WP-300 ile birleştirmek · backfill'i ölçmeden koşmak · "kimse fark etmez" varsayımı (sıralama kullanıcı gözünde değişir) · streak'i unutmak.
- **Model önerisi:** 🟣 Pro

### WP-292: Kozmetik — taç görseli ✨ ✅ KOD/TEST TAMAM
- **Program/Faz:** Yeni Özellik Turu · Aşama A (son) · (plan §3 F-08) · *rev.2: kamp ateşi WP-295'e ayrıldı*
- **Ajan:** Claude · **Durum:** [x] **Kod/test tamam (2026-07-25)** — ayrıntı aşağıdaki sonuç kaydında. *Eski "WP-290 cihaz kabulü" kapısı tek beta kararıyla düşmüştü (`§0.1`); 297'den sonra seri koştu.*
- **Problem:** Profil fotoğrafı üstündeki taç sahibe göre kötü duruyor; görsel yenilenecek.
- **Kapsam dışı:** **XP/kademe mantığı**, başarım motoru, tema motoru, yeni ekonomi kuralı, kamp ateşi (WP-295).
- **SAHİP dosyalar (yaz):** `app/lib/core/widgets/crowned_avatar.dart`, `app/lib/core/widgets/crown_tiers_sheet.dart`, ilgili golden testler.
- **DOKUNMA:** 🔴 `app/lib/core/stats/achievement_ledger_engine.dart` — **`crownRankForXp:358` ve `kCrownXpThresholds` DEĞİŞTİRİLMEZ**; taç XP'den türer ve XP server-authoritative'dir (`AGENTS.md §2`). Eşiğe dokunmak kullanıcıların görünen kademesini sessizce kaydırır. Ayrıca: sunucu tarafı, tema motoru, `campfire*` (WP-295'in).
- **Adımlar:**
  - [x] Taç çizim katmanı yenilendi; **kademe→görsel eşlemesi birebir korundu** (6 rütbe + eski `platinum_scholar` için renk testi).
  - [x] Golden baseline kuruldu (2 golden); performans bütçesi **cihazsız ölçülemedi**, aşağıda gerekçesiyle QA'ya devredildi.
- **Veri/Migration etkisi:** Yok. **Ortam/Deploy:** Local. **RLS/Güvenlik:** Yok.
- **Edge-case'ler:** Taçsız kullanıcı (rank null/boş) · en yüksek kademe · küçük avatar boyutları · "hareketi azalt" açık · düşük donanım.
- **Kabul (ölçülebilir):** **Aynı XP → aynı kademe** (regresyon testi yeşil) · taçsız durumda düz avatar · golden yeşil · "hareketi azalt" açıkken animasyon durur · 🔴 **p95 kare süresi ≤ 16.7 ms, jank ≤ %1** (`flutter run --profile` + timeline).
- **Tuzaklar:** Görsel değişiklik sırasında kademe eşiğini kaydırmak (kullanıcıların tacı sessizce değişir) · ağır efektle kare düşürmek.
- **Model önerisi:** 🟣 Pro

#### WP-292 sonuç kaydı (2026-07-25)

- **Durum:** [x] **Kod/test tamam** — `flutter analyze` **0**, tam paket **776 yeşil / 0 kırmızı** (öncesi 767; +7 birim testi, +2 golden). **Bekleyen:** sahip beğenisi + cihaz QA (tek beta turunda).
- 🔴 **Kök neden (tahmin değil, kodda okundu):** eski taç iki hata taşıyordu. (1) Bant `RRect` olarak çiziliyordu ([eski `crowned_avatar.dart:144`](app/lib/core/widgets/crowned_avatar.dart:144)) — **düz bir dikdörtgenin daireye teğet olabileceği tek nokta tepe noktasıdır**, iki uç zorunlu olarak havada kalıyordu. (2) Taç `Positioned(top: -radius * 0.22)` ile sabit bir kutuya çiziliyordu ve **çizim kodu avatarın yarıçapını hiç bilmiyordu**, dolayısıyla kavis üretmesi mümkün değildi. Sahibin "doğal durmuyor" dediği şey buydu.
- **Çözüm:** geometri **kutupsal** hâle getirildi (`CrownGeometry`): her nokta avatar merkezine göre *açı + yarıçap çarpanı*. Bandın alt kenarı avatarla **eş merkezli bir yay** (`Path.arcToPoint`), yani her açıda teğet. Testte hem teğetlik hem "kafanın içine girmeme" beş ayrı açıda doğrulanıyor.
- **Sahip onaylı geometri (canlı önizlemeden seçildi):** `5 uç · span 50° · tip 1.63 · inci 0.10 · kavis 0.50`. Sayılar `CrownGeometry.standard`'da ve testte sabitlendi — biri değişirse test kırmızıya döner.
- ⚠️ **Golden'a bakarak iki düzeltme yapıldı (yeşile dönmesi yeterli sayılmadı):**
  1. Küçük avatarlar için ilk yazılan "tok" varyant tacı **kısaltıyordu**; golden'da r = 12'de taç okunaksız bir tümseğe indi (24 px'lik avatarda taca ~7 px kalıyor). Doğru yön tersiydi: tok varyantta uçlar **uzatıldı** (`tipRadius 1.74`), inci kapatıldı (çapı ~2 px'e düşüp lekeye dönüşüyordu), kavis azaltıldı (uçlar 2 px'lik tarak olmasın).
  2. Kademe listesindeki `workspace_premium` madalyasını gerçek taçla değiştirmek denendi ve **geri alındı**: taç tabanı avatar yayı olduğu için altında kafa olmadan "kanat" gibi okunuyor. Düzgün liste ikonu **düz tabanlı** ikinci bir geometri ister (vadi yarıçapı da uç yüksekliğiyle oranlanmalı) — sahip onayıyla ayrı iş, gerekçe kodda yorum olarak duruyor.
- ✅ **Halka da oranlandı:** eskiden sabit 3 px'ti; r = 12'de 24 px'lik avatarın çeyreğini yiyor, r = 48'de ince kalıyordu. Artık `max(2, radius * 0.075)`. Glow blur'u da sabit 12 px yerine `radius * 0.3` — **küçük avatarlarda çizim maliyeti düştü**, artmadı.
- ⚠️ **Kutu boyutu değişti, ölçüldü:** genişlik **her boyutta daraldı** (eski kutu kareydi ve altta boş yer bırakıyordu), yükseklik r ≥ 28'de düştü ama **küçük avatarlarda ~2–4 px arttı** (tok varyant tacı uzattığı için). Liste satırları o kadar uzuyor. Test bu sınırı 8 gerçek yarıçapta bağlıyor, ileride taç uzatılırsa satırların sessizce şişmesi yakalanır. Göze batıp batmadığı **QA maddesi**.
- 🔴 **Performans bütçesi ölçülemedi — dürüst kayıt.** `p95 ≤ 16.7 ms / jank ≤ %1` cihaz + `--profile` timeline ister; tek beta kararı gereği elde cihaz koşumu yok. **Yerine ne biliniyor:** animasyon **eklenmedi** (statik `CustomPaint`, ticker yok), dolayısıyla "hareketi azalt" kabulü kendiliğinden sağlanıyor; boxShadow blur'u küçüldü ve widget ağacı sadeleşti (eski kod her çağrıda bir `UserAvatar`'ı boşa kuruyordu). Yani değişiklik öncesinden **kesin olarak daha pahalı değil**. Ölçüm QA kuyruğuna yazıldı.
- **Değişen dosyalar:** `app/lib/core/widgets/crowned_avatar.dart` (yeniden yazıldı: `CrownGeometry` + `CrownVertex` + `crownRingWidth` + yeni `CrownPainter`) · `app/lib/core/widgets/crown_tiers_sheet.dart` (yalnız yorum — denenip geri alınan ikon değişikliğinin gerekçesi) · `app/test/features/profile/crowned_avatar_test.dart` (2 → 9 test) · yeni `app/test/features/profile/crown_golden_test.dart` + `goldens/crown_tiers_r44.png`, `goldens/crown_sizes.png`. **`achievement_ledger_engine.dart`'a dokunulmadı** — `crownRankForXp` ve `kCrownXpThresholds` bit bit aynı, testte de sabitlendi.

### WP-298: Avatar aura efekti ✨ ✅ KOD/TEST TAMAM
- **Program/Faz:** Yeni Özellik Turu · Aşama A · kozmetik (WP-292'nin devamı, sahip isteği)
- **Ajan:** Claude · **Durum:** [x] **Kod/test tamam (2026-07-25)** — `flutter analyze` **0**, tam paket **784 yeşil** (+6 birim, +2 golden). **Bekleyen:** sahip beğenisi + 🔴 **performans ölçümü** (aşağıda).
- **Problem:** Sahip PUBG'deki profil fotoğrafı arkası "büyülü renkli sis/parıltı" efektini istedi.
- **Sahip kararı (3 soru, 3 cevap):**
  1. **Kapsam:** yalnız **profil + sosyal profil** ekranı. Listeler (liderlik r14, sohbet r14, aktif üyeler r16, ısı tablosu r12) **durağan kalır**. Gerekçe teknik ve sahip kabul etti: bir listede 10–20 avatar var, her birine ticker takmak `p95 ≤ 16.7 ms` bütçesini gerçekten tehdit eder; profilde tek örnek var.
  2. **Kademe ayrımı:** aura **altın kademede başlar**, yukarı doğru kademeli artar (`0 · 0 · 0.45 · 0.62 · 0.80 · 1.0`). Bronz ve gümüşte hiç çizilmez. ✅ **Sahip 2026-07-25'te doğruladı: "altından itibaren" = altın (3. kademe)** — okuma doğru, değişiklik yapılmadı. Bu ayrım **görsel**dir; XP eşikleri ve kademe→renk eşlemesi değişmedi.
  3. **Renk:** o kademenin rengi (`crownColorFor`) — ayrı bir aura paleti yok.
- ⚠️ **Kutu bilerek büyütülmedi — gerçek bir tuzak vardı.** Profil ekranındaki "fotoğraf değiştir" düğmesi avatar kutusunun köşesine `Positioned(right: 0, bottom: 0)` ile bağlı ([`profile_screen.dart:87`](app/lib/features/profile/profile_screen.dart:87)). Aura için kutuyu büyütmek düğmeyi avatardan koparırdı. Çözüm: aura kutunun **dışına** taşarak çiziliyor (`Stack(clipBehavior: Clip.none)`), yerleşim hiç değişmiyor.
- 🔴 **Auranın yarıçapı (`1.5 × taban`) tahminle değil kısıtla seçildi.** İki ekranda da avatar bir `ListView` içinde ve **`ListView` dikeyde kırpar**. Taç uçları merkezden `1.73 × taban` yukarıda olduğu için `1.5` seçilince aura **dikeyde kutunun içinde kalıyor**, yalnız yanlara taşıyor — yani listenin tepesinde kesilme riski yok. Bu kısıt teste bağlandı (`kAuraOuterRadius < tipRadius + pearlRadius`), ileride biri aurayı büyütürse test kırmızıya döner.
- ⚠️ **`MaskFilter.blur` ve özel shader bilerek kullanılmadı.** Blur daha güzel bir sis verirdi ama ölçülemeyen GPU maliyeti + shader derleme riski getiriyordu ve bütçe cihazsız doğrulanamıyor. Yumuşaklık her kuşağın iki geçişte (geniş+soluk / dar+parlak) çizilip `SweepGradient` ile uçlarının söndürülmesiyle elde edildi. Üç kuşağın hızları **birbirinin katı değil** ve biri ters yönde — aksi hâlde üçü kilitlenip tek bir halka gibi dönüyor (golden'da dört faz karşılaştırılarak doğrulandı).
- ✅ **"Hareketi azalt" kabulü test edilir hâlde:** `disableAnimations` açıkken ticker duruyor, faz sabitleniyor ve **aura görünür kalıyor** (yoğunluk sıfırlanmıyor). Test 3 saniye pump edip fazın ilerlemediğini, ayrı bir test de hareket açıkken ilerlediğini doğruluyor — ikinci test olmasa "hep durgun" bir hata sessizce geçerdi.
- ⚠️ **Test tuzağı belgelendi:** aura `repeat()` çalıştırdığı için aurası açık avatar içeren ağaçta **`pumpAndSettle()` asla dönmez**. Bugün o iki ekranı pump eden test yok (arandı), ama ileride yazılacaksa `MediaQuery(disableAnimations: true)` ya da `pump(Duration)` gerekir. Not hem kodda hem testte duruyor.
- 🔴 **Performans ölçümü yapılamadı ve bu WP'de risk gerçek.** WP-292'de animasyon yoktu, burada **var**: tek `AnimationController` (9 s devir) + karede 1 radial + 6 sweep gradient + (üst kademelerde) 6 küçük daire. Cihaz + `--profile` timeline olmadan `p95 ≤ 16.7 ms` doğrulanamaz. **Beta QA'sında ilk bakılacak yer profil ekranıdır.** Kare düşerse en ucuz geri adım: `_wisps` listesini üçten ikiye indirmek (tek satır).
- **Değişen dosyalar:** yeni `app/lib/core/widgets/avatar_aura.dart` · `app/lib/core/widgets/crowned_avatar.dart` (+`showAura` bayrağı, **varsayılan kapalı**) · `app/lib/features/profile/profile_screen.dart` (+1 satır) · `app/lib/features/profile/social_profile_screen.dart` (+2 satır, iki `when` dalı) · yeni `app/test/features/profile/avatar_aura_test.dart` (6 test) · `crown_golden_test.dart` (+2 golden: `crown_aura_tiers.png`, `crown_aura_phases.png`). **l10n anahtarı eklenmedi** (görsel efekt, metin yok).
- **Veri/Migration etkisi:** Yok. **Ortam/Deploy:** Local. **RLS/Güvenlik:** Yok.
- **Kabul (ölçülebilir):** Aura yalnız iki profil yüzeyinde · listelerde **hiç katman kurulmuyor** (`showAura` varsayılan kapalı, testle sabit) · bronz/gümüşte çizilmiyor · yoğunluk kademeyle **monoton artıyor** · renk kademe rengi · "hareketi azalt" açıkken faz ilerlemiyor · golden'lar gözle incelendi · 🔴 **p95 ≤ 16.7 ms / jank ≤ %1 — cihazda ölçülecek (açık)**.
- **Tuzaklar:** Aurayı bir listeye açmak (kare bütçesi gider) · kutuyu büyütüp fotoğraf düğmesini koparmak · auranın dikeyde taşıp `ListView` tepesinde kesilmesi · kuşak hızlarını birbirinin katı yapmak (tek halka gibi döner) · `pumpAndSettle` ile kilitlenen test yazmak.
- **Model önerisi:** 🟣 Pro

### WP-294: l10n borcu ayıklama + audit CI kapısı 🌍 ✅ KOD/TEST TAMAM
- **Program/Faz:** Yeni Özellik Turu · Aşama A · (plan §3 l10n borcu, R23)
- **Ajan:** Claude · **Durum:** [x] **Kod/test tamam (2026-07-25)** — ayrıntı aşağıdaki sonuç kaydında. Eski durum notu tarihsel olarak duruyor: 🟡 **Kısmen açık (2026-07-25 uzlaştırıldı):** audit'i 4 katalog + sabit EN/TR literal + native yüzeye genişletme, UTF-8 düzeltmesi, bulguların sınıflandırılması ve CI kapısı **bugünkü 4 dil gerçeğiyle yapılabilir**. 🔴 **Yalnız "AR/DE'yi üründen çıkarıp EN/TR'ye daraltma" dalı K-7'ye bağlıdır** — o dal K-7 kapanmadan uygulanmaz. Sahip 2026-07-25'te "Arapça'yı şimdilik dert etmiyoruz" dedi; bu **K-7 kararı değildir**, dil setine dokunulmaz.
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

#### WP-294 sonuç kaydı (2026-07-25)

- **Durum:** [x] **Kod/test tamam** — `flutter analyze` **0**, tam paket **793 yeşil / 0 kırmızı** (öncesi 784; +9 test). **Ölçüm:** denetim `FAIL (40)` → `OK`. Kataloglar 1263 → **1289 anahtar × 4 dil**.
- ✅ **(a) UTF-8 çöküşü düzeldi.** Denetim Windows'ta bulguları *yazdırırken* `UnicodeEncodeError` ile düşüyordu, yani raporu **hiç göstermeden** ölüyordu (`→` karakteri `cp1254`'te yok). İki script de artık `sys.stdout.reconfigure(encoding="utf-8")` yapıyor. Ubuntu CI'da görünmeyen bir hataydı; Windows release runner'ı için bloklayıcıydı.
- ✅ **(b) Denetim dört kataloğu kapsıyor.** Eskiden `:23-24` yalnız EN/TR yüklüyordu → **DE/AR hiç denetlenmiyordu**. Artık anahtar eşliği *ve* placeholder eşliği her dil için bakılıyor (eskiden placeholder yalnız TR'de bakılıyordu; DE/AR'de eksik placeholder sessizce geçiyordu). Kırmızı-yeşil doğrulandı: DE'den bir anahtar silinince ve bir placeholder bozulunca denetim iki bulguyla kırmızıya döndü.
- 🔴 **(c) Gömülü metin taraması genişledi ve iki gerçek hata buldu.** Eski tarama yalnız *Türkçe karakter* arıyordu; Türkçe'ye özgü harf içermeyen Türkçe cümleleri ve gömülü İngilizceyi görmüyordu. Yeni prose taraması (`Text(`, `title:`, `tooltip:` … yuvalarıyla sınırlı) şunları yakaladı: [`home_screen.dart:923`](app/lib/features/home/home_screen.dart:923) `'Boyut … dokun ve ayarla'` ve [`hour_activity_chart.dart:70`](app/lib/features/stats/widgets/hour_activity_chart.dart:70) `'En verimli saat: …'` — ikisi de kullanıcının gördüğü, **hiçbir denetimin fark etmediği** metinlerdi.
- 🔴 **En büyük borç `languageCode == 'tr'` üçlemesiydi.** [`account_settings_screen.dart`](app/lib/features/profile/account_settings_screen.dart) ve [`build_identity_card.dart`](app/lib/core/config/build_identity_card.dart) katalogu **tamamen atlayıp** iki dili elle tutuyordu → **DE/AR kullanıcısı İngilizce görüyordu** ve eski denetim İngilizce dalı hiç göremiyordu. İkisi de katalog altına alındı; kalıbın geri gelmesi teste bağlandı. (`release_notes_service.dart`'taki aynı kalıp **bilinçli bırakıldı**: orada seçilen şey UI metni değil, sürüm notu varlığının TR/EN alanları.)
- ✅ **Ham istisna metni gösterimi kaldırıldı:** hesap silme akışında iki yerde `Text(e.toString())` vardı — yerelleştirilemez *ve* sunucu/istisna metnini kullanıcıya sızdırıyordu. Yerine katalogdaki genel hata mesajı geldi.
- 🔴 **Bildirim kanallarında gerçek bir çift-tanım hatası bulundu.** Kanal adı/açıklaması **iki yerde** tanımlıydı: `initialize()` katalogdan kuruyor, `_channelFor` ise Türkçe sabit taşıyordu; üstelik `description` alanı adın **kopyasıydı**. Kanal adı Android sistem ayarlarında görünür, yani gerçek kullanıcı yüzeyi. Artık tek kaynak `_channelFor(type, l10n)` ve tür listesi `kNotificationChannelTypes`; her kanalın kendi açıklaması var. Kanal **kimlikleri değişmedi** (değişse kullanıcının kanal ayarları sıfırlanırdı) — mevcut testler bunu zaten bağlıyor.
- ✅ **Ay adları katalog yerine `intl`'e bağlandı.** `taskDueDateLabel` 12 Türkçe ay kısaltmasını sabit taşıyordu. Katalog anahtarı **açılmadı**: `DateFormat.MMMd(locale)` aynı veriyi CLDR'den veriyor ve yerelin gün/ay **sırasını** da düzeltiyor (Arapça'da sıra farklı). ⚠️ Bu değişiklik `main()`'e `initializeDateFormatting()` eklemeyi zorunlu kıldı — **testim olmasa runtime'da `LocaleDataException` ile çökecekti**; bugün o etiketi çizen tek test yoktu.
- ✅ **Yeni CI kapısı:** [`.github/workflows/l10n-gate.yml`](.github/workflows/l10n-gate.yml). 🔴 **Kırmızı-yeşil ispatı kapının içinde:** ikinci adım geçici olarak gömülü **İngilizce** bir `Text(...)` ekliyor, denetimin kırmızıya döndüğünü doğruluyor, sondayı siliyor. İngilizce seçildi çünkü Türkçe tarama WP-89'dan beri vardı; kanıtlanması gereken şey WP-294'ün eklediği taramadır. Yerelde de koşturuldu: sonda varken `FAIL (1)`, silinince `OK`.
- ✅ **Muafiyetler artık gerekçeli.** `INTERNAL_PREFIXES` / `LITERAL_EXEMPTIONS` / `UI_PROSE_EXEMPTIONS` her dosya için **neden** muaf olduğunu yazıyor (Sentry etiketi, SharedPreferences anahtarı, IANA şehir adı, motor içi başarım verisi, `debugPrint` günlüğü…). Gerekçesi yazılamayan dosya muaf edilmiyor.
- ℹ️ **Native audit zaten çağrılıyordu** (`subprocess` ile `l10n_android_audit.py`) — rev.2'nin "native audit ayrı" ifadesi yanlıştı, doğrusu script başlığına yazıldı. Native tarafta bir gerçek bulgu vardı: `timer_notification.xml` düzeninde `android:text="Durdur"` gömülüydü; `@string/action_stop` zaten mevcuttu, ona bağlandı.
- 🔴 **K-7'ye DOKUNULMADI.** Dil seti aynı (EN/TR/DE/AR); "AR/DE'yi çıkarıp EN/TR'ye daraltma" dalı **hiç açılmadı**. Sahip "Arapça'yı şimdilik dert etmiyoruz" dedi ama bu K-7 kararı değil. Karar geldiğinde daraltma ayrı iş.
- 🔴 **Bilinen borç, kapsam dışı bırakıldı (kart böyle diyordu):** yasal metinler (`legal_documents.dart`) kodda TR+EN gömülü duruyor. Katalog/asset mimarisine taşınması `policyVersion` sürüm takibini de etkiler → **ayrı WP**. Gerekçe denetimin muafiyet listesinde de yazılı, yani "unutulmuş" görünmüyor.
- **Değişen dosyalar:** `scripts/l10n_audit.py` (yeniden yazıldı) · `scripts/l10n_android_audit.py` (UTF-8) · yeni `.github/workflows/l10n-gate.yml` · `app/lib/l10n/app_{en,tr,de,ar}.arb` (+26 anahtar) · `app/lib/main.dart` (`initializeDateFormatting`) · `account_settings_screen.dart` · `build_identity_card.dart` · `build_configuration_error_app.dart` (kendi l10n delegate'lerini bağlıyor) · `app_push_notification_service.dart` · `task_deadline.dart` + `tasks_screen.dart` · `theme_settings.dart` · `achievement_reward_provider.dart` · `class_detail_screen.dart` · `group_avatar.dart` · `home_screen.dart` · `hour_activity_chart.dart` · `updater_dialog.dart` · `timer_notification.xml` · yeni `app/test/l10n/wp294_l10n_debt_test.dart` (9 test).
- **Cihaz QA'sı gerekiyor mu?** Küçük ama evet — QA kuyruğuna eklendi (metin uzunlukları + görev tarihi etiketi).

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

**Beta 2'ye kadar sırayla verilecek komutlar** (DALGA 7 seri koşar, aynı sahne dosyaları):
- `worker'ı oku ve WP-295'i yap` — **sıradaki.** ⚠️ İlk çıktı kod değil: **parametrik canlı önizleme**, sahip sayıyı seçer
- `worker'ı oku ve WP-299'u yap` — 295 bitince
- `worker'ı oku ve WP-300'ü yap` — 299'un çıpa seam'i hazır olunca
- 🔴 WP-301 → **worker komutu değil:** önce sahip kapsam kararı (beta 2 mi, sonraya mı)

Kod/test'i bitmiş WP'ler (286, 287, 288, 289, 290, 291, 292, 293, 294, 296, 297, 298) için **worker komutu verilmez** — sıra sahipte (beta 1 cihaz QA + WP-287 staging paneli).

Önceki tur:
- `worker'ı oku ve WP-276'yı yap` · `worker'ı oku ve WP-277'yi yap`
- WP-278/279 için önce ürün/ops kararı alınır.

> Her worker önce Aktif Çalışma Kaydı'nı okur, kendi lane'ini claim eder ve SAHİP yolları çakışıyorsa başlamaz. Production/stable hiçbir WP'nin örtük parçası değildir.
