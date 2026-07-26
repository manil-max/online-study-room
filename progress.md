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
> **Okuma sırası:** `⚡ Aktif Çalışma Kaydı` → `🗺️ Yol Haritası` →
> `Test için bekleyenler` → `Bekleyen Uygulanabilir WP'ler`.

## Proje Gerçekleri

- **Migration gerçeği:** repo/local **`0077`** · staging **`0072`** · production
  etkin şema **`0070`**. Production CLI geçmişi legacy/uzlaştırılmamış;
  ayrıntı [`docs/recovery/PRODUCTION-BASELINE.md`](docs/recovery/PRODUCTION-BASELINE.md).
  Deploy contract aynı üç head'i taşır ve production `deploy_enabled: false` kilitlidir.
- **Stable/production:** **v48** yayında, etkin şema `0070`. Yeni production migration, Edge deploy veya stable tag/release yalnız ayrı, somut kullanıcı GO + backup + dry-run ile yapılır; deploy kapısı kilitli.
- **Beta/staging:** **beta-v4309** artefaktı `0070` ile çıktı; staging veritabanı sonradan `0072`ye yükseldi. Yeni kabul kuyruğu `0073–0077` staging terfisinden sonra ortak beta turunda doğrulanır.
- **Release ilkesi:** Android beta/stable artefaktı Android işi başarılı olunca yayımlanır. Windows bağımsız sürer ve başarılı olursa aynı release'e eklenir; Windows hatası Android güncellemesini geri çekmez.
- **Sürüm sırası:** kod/testi biten işler tek QA kuyruğunda birikir; yeni beta/stable yalnız sahip onayıyla çıkar. Eski beta dalga kararları tarihsel arşivdedir.
- **Yönetim varsayılanı:** Production `deploy_enabled/release_enabled` kapalıdır. Stable yalnız protected `production` Environment, exact SHA/head/project-ref GO ve reviewer kanıtıyla ilerler.
- **Kurallar:** Kök `AGENTS.md`, `.agents/AGENTS.md` ve `docs/KALITE-PROGRAMI.md` geçerlidir. Tek çalışma dalı `main`; her WP ayrı commit; production varsayılmaz.
- **Aktif tur:** **Faz E**. WP-327 kod/test tamam; sıradaki uygulanabilir kartlar **WP-328** ve **WP-329**.
- ✅ **Ortam gerçeği uzlaştırıldı (WP-293):** production deploy kapısı kilitli; ortam head'leri tek sayıya indirgenmez.

## ⚡ Aktif Çalışma Kaydı

### Gemini Lane
- **Durum:** [x] Boşta
- **Faz/WP:** —
- **SAHİP yollar:** —

### Claude Lane
- **Durum:** [x] Boşta
- **Faz/WP:** —
- **SAHİP yollar:** —
- **Son not:** WP-327 kod/test tamamlandı; güvenli keşif özeti için 0077 local replay ile doğrulandı. Staging/beta kabulü sonraki ortak turda (2026-07-26).

### Codex Lane
- **Durum:** [x] Boşta
- **Faz/WP:** —
- **SAHİP yollar:** —
- **Son not:** WP-299 kod + otomatik test tamamlandı; gerçek cihaz/ürün kabulü için `Test için bekleyenler`e taşındı. WP-327/334 yüzeyleriyle kesişme olmadı.

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
| `v49` | **Çıkmadı.** Başarısız koşumun release'i oluşmadı; yerel ve uzak `v49` tag'i sahip emriyle silindi |
| Sürüm politikası | 🔴 Sahip onayı olmadan yeni sürüm çıkmaz |
| Otomatik doğrulama | Son tamamlanan taban: **881 test yeşil**, `flutter analyze` temiz |
| l10n audit | **31 bilinen bulgu**: WP-295 parametrik önizleme metinleri + iç doğrulama mesajları; temiz değil, ayrı hijyen işi |
| Migration | Repo/local **`0077`** · staging **`0072`** · production **`0070`** |
| Play Console | Hesap açıldı, doğrulama sürüyor. Hiçbir form doldurulmadı |
| Microsoft Partner Center | Hesap açıldı. Hiçbir hazırlık yapılmadı |

---

## PLAN 1 — ÜRÜN & KOD

### Faz A — Doğrulama borcu ✅ *KAPANDI (sahip, 2026-07-26)*

Sahip v46–v48 turlarında cihazda test etti ve tek tek doğruladı: **özel tema
okunabilirliği · spektrum renk seçici · font düğmelerinin sabitliği · grafikteki
gün etiketleri · boş ikinci bildirim · taç ve aura** — hepsinde sorun yok.

- **Şifre değiştirme/sıfırlama** Faz C'de kodlandı; iki cihazlı kabulü tek QA
  kuyruğunda WP-319 olarak duruyor.

**Faz A'dan çıkan kod bulguları → Faz C5.**

---

### Faz B — Admin & geri bildirim döngüsü · kodlandı, QA bekliyor

Ek görüntüleme, çift yönlü yazışma ve arşivleme kodlandı. Faz B'de yeni kod işi
yok; üç akış aynı staging/beta kabul turunda doğrulanacak.

#### Kod/testi tamamlanan WP'ler

| WP | Kod durumu | Kalan kapı |
| --- | --- | --- |
| **WP-316** Geri bildirim eki | Kod/test + staging tamam | Staging cihaz kabulü |
| **WP-317** Admin ↔ kullanıcı yazışması | Kod/test tamam | Beta akış + RLS/push kabulü |
| **WP-318** Bilet arşivi | Kod/test tamam | Beta arşiv/geri alma kabulü |

> Bu üç WP yeniden claim edilmez; yalnız aşağıdaki **Test için bekleyenler**
> kuyruğundan doğrulanır. Testte hata çıkarsa yeni WP açılır.
---

### Faz C — Hesap, güvenlik, ayarlar hijyeni

Faz C'nin kod işleri tamamlandı. Yalnız cihaz kabulü ve Faz H'deki gerçek Store
paketi kontrolü kaldı.

#### Kod/testi tamamlanan WP'ler

| WP | Kod durumu | Kalan kapı |
| --- | --- | --- |
| **WP-319 / 319-G** Şifre değiştirme, sıfırlama, diğer oturumları kapatma | Kod/test tamam | İki cihaz + Android recovery kabulü |
| **WP-320** Ayarlar bilgi mimarisi | Kod/test tamam | Android/Windows yerleşim kabulü |
| **WP-321** Yalnız TR + EN | Kod/test tamam | Dil listesi + DE cihaz fallback kabulü |
| **WP-322** Teknik borç temizliği | Kod/test tamam | Kapandı; Store kanalının gerçek paket kontrolü Faz H'ye ait |

> Test bekleyen ilk üç kayıt aşağıdaki tek QA kuyruğundadır. WP-322 yeniden
> claim edilmez; Microsoft Store paketi oluşmadan ayrıca cihaz testi yoktur.
---

### Faz D — Yeni kullanıcı deneyimi (tanıtım turu)

Şu an sadece açılışta tek bir `onboarding_screen` var; uygulama içinde hiçbir
yerde rehberlik yok.

> ⚠️ **WP-323 → WP-324 seri koşar.** 324, 323'ün kabul edilmiş motoruna yazar;
> motor oturmadan içerik yazmak iki kez iş demektir.

#### WP-323: Tanıtım turu motoru 🎈

- **Durum:** [~] Kod/test tamam — Android + Windows cihaz kabulü bekliyor.
- **Kanıt:** `flutter analyze` temiz · tam paket **849 test yeşil**; kullanıcı,
  sürüm ve ekran anahtarları, kuyruk engeli, kalıcılık ve 360 px sınırı kapsandı.
- **Kalan:** Ayrıntılı kabul adımları aşağıdaki **Test için bekleyenler** kuyruğunda.

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

> **Tamamlanan zincir:** WP-325 → WP-326 → WP-327. Kalan WP-328 ve WP-329
> `supabase/migrations/**` sıcak yüzeyi nedeniyle seri yürür.

#### Kod/testi tamamlanan WP'ler

| WP | Kod durumu | Kalan kapı |
| --- | --- | --- |
| **WP-315** Grup üye sınırı 8 | Kod/test tamam; `0071` staging'e uygulandı | Beta cihazda 8 sınırı |
| **WP-325** Oturum gününü kayıt anında damgalama | Kod/test tamam; `0073` local | Staging dry-run + veri eşliği |
| **WP-326** Grup bölgesi ve gün sınırı zinciri | Kod/test tamam; `0076` local | Staging + beta saat dilimi kabulü |
| **WP-327** Grup bölgesi ve anlık saat farkı | Kod/test tamam; `0077` local | Staging + beta kart/diyalog kabulü |

> Migration sırası korunur: staging'deki `0072` ardından **`0073` → `0077`**.
> Bu dört WP yeniden claim edilmez; test sonucu hata çıkarsa yeni WP açılır.

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

Kod/test tamam; mağaza çıkışını **bloklamaz**. Kalan kabul tek QA kuyruğunda.

| WP | İş | Durum | Not |
| --- | --- | --- | --- |
| **WP-295** | Kamp ateşi: oturma yayları + 2 poz | [~] Kod/test tamam | Cihaz ve performans kabulü aşağıdaki QA kuyruğunda |
| **WP-299** | Gündüz/gece gökyüzü + gece uyuma | [~] Kod/test tamam | Cihaz/ürün kabulü aşağıdaki QA kuyruğunda |
| — | Gökyüzü için grup bölgesi | — | **WP-326**'nın saat dilimi alanına dayanır. Enlem/boylam gerekirse **ayrıca** konuşulur (konum izni açar) |

⚠️ **Kare bütçesi:** kamp ateşi sahnesinde `p95 ≤ 16.7 ms · jank ≤ %1`
(`flutter run --profile` + timeline); Android cihaz kabulünde ölçülür.

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
| **K6** İsim + logo | ⏸️ Plan 2 başlamadan konuşulacak |
| **K7** Gizlilik URL'i | **GitHub Pages** — bedava, HTTPS hazır, `docs/legal/*.md`'den yayınlanır |
| **K8** Yurtdışı gün sınırı | **Birincil grubun bölgesi** belirler; grubu olmayan cihaz saat dilimini kullanır. Gruplara bölge alanı + üye sınırı 8 + keşifte yakınlık sıralaması |
| Üye sınırı | **8 kişi** — `0071` staging'e uygulandı; beta cihaz kabulü bekliyor |

---

## ⚠️ Risk ve Tuzak Notları

- **Sürüm disiplini.** Sürüm sahibin onayıyla çıkar; düzeltmeler birikir, tek sürümde çıkar.
- **Migration drift.** Repo/local `0077`, staging `0072`, production `0070`. `0073–0077` seri dry-run + post-check olmadan staging'e uygulanmaz.
- **l10n kapısı kırmızı.** Audit 31 bilinen sabit metin buluyor; çoğu WP-295 önizleme yüzeyi olsa da kapı temiz sayılmaz. Yayın öncesi ayrı hijyen WP'siyle sınıflandırılmalı.
- **Geri alınamaz işler.** Hesap silme purge'ü bu sınıfta — yedek + staging provası + rollback betiği olmadan production'a dokunulmaz. *Gün sınırı artık bu sınıfta değil* (toplamlar saklanmıyor).
- **Ölü anahtar riski.** WP-319'daki sahte “mevcut şifre” koruması düzeltildi; benzer ayarlar yeni işlerde sözleşme testiyle engellenmeli.
- **MSIX kimliği** Partner Center'da rezerve edilen adla eşleşmezse paket reddedilir; sonradan düzeltmek yeni uygulama demektir.
- **Saat dilimi offset olarak saklanmaz** — hep IANA adı (`America/New_York`). Türkiye'de yaz saati olmadığı için bu hata bugüne kadar hiç görünmedi.

---

## Test için bekleyenler

> **Tek QA kuyruğu budur.** Buradaki WP'lerin kodu ve otomatik testleri bitti;
> worker'a verilmez. Cihaz, staging veya ürün kabulünde hata bulunursa ayrı WP açılır.

| WP | Ortam | Bekleyen kabul |
| --- | --- | --- |
| **WP-295** Kamp ateşi oturma/poz | Windows + Android profile | Seçilen 1–8 kişi yerleşimleri ve marshmallow erişimi görsel olarak doğru; Android profile'da `p95 ≤ 16.7 ms`, jank `≤ %1` |
| **WP-299** Gündüz/gece gökyüzü | Android + Windows | Yerel saate göre geçişler, zemin/gökyüzü birleşimi ve gece uyuma pozu gerçek cihazda doğal görünüyor |
| **WP-315** Grup üye sınırı 8 | Staging + beta | Grup kurma/katılma akışında 8 sınırı çalışıyor; dokuzuncu üye sunucuda reddediliyor |
| **WP-316** Geri bildirim eki | Staging cihaz | Ekli bilet görseli `≤ 3 sn` açılıyor; eksiz bilette çip yok, yükleme hatası görünür |
| **WP-317** Admin ↔ kullanıcı yazışması | Staging + beta | Çift yönlü mesaj `≤ 5 sn`, push/duyuru izi ve başka kullanıcının bileti için RLS reddi |
| **WP-318** Bilet arşivi | Staging + beta | Varsayılan liste yalnız aktif; arşiv görünümü/geri alma eksiksiz; satır silinmiyor |
| **WP-319 / 319-G** Şifre akışı | İki Android cihaz | Mevcut şifre doğrulaması, Android recovery linki ve diğer cihaz oturumunun kapanması. Windows kod yolu özel SMTP/ücretli plan gelene kadar bloklu |
| **WP-320** Ayarlar IA | Android + Windows | Hesap/dışa aktarma/silme aynı grupta, yasal metinler sonda; 360 px'te taşma yok |
| **WP-321** Yalnız TR + EN | Android + Windows | Listede iki dil; cihaz dili DE iken güvenli EN fallback ve kayıtlı eski tercihte çökme yok |
| **WP-323** Tanıtım turu motoru | Android + Windows | İlk açılış, atla, sıfırla ve izin/güncelleme diyaloğu varken erteleme gerçek cihazda çalışıyor |
| **WP-325** Oturum günü damgası | Staging | `0073` dry-run/apply; öncesi/sonrası gün toplamı birebir; bölge değişimi geçmişi oynatmıyor; indeks planı kanıtlı |
| **WP-326** Grup saat dilimi | Staging + beta | `0076`; IANA adı, New York yerel gece yarısı, cihaz fallback'i ve DST davranışı doğru |
| **WP-327** Grup bölgesi + saat farkı | Staging + beta | `0077`; açık grup kartı/bilgi ekranı, aynı bölgede farkın gizlenmesi, New York ve +5:30 farklarının doğruluğu |

**Ortam sırası:** staging şu anda `0072`; veri/grup zinciri **`0073` → `0077`**
olarak dry-run ve post-check ile seri ilerler. Production bu kuyruğun parçası değildir ve
ayrı somut sahip GO'su olmadan değişmez.

## 🗄️ Tarihsel kayıt

Tamamlanan ayrıntılı WP kartları ve eski beta dalga planı
[`docs/archive/progress-tarihsel-2026-07.md`](docs/archive/progress-tarihsel-2026-07.md)
ile git geçmişindedir. Canlı dosyada tekrar tutulmaz.

- **WP-300** enlem/boylam yaklaşımı iptal edildi; yerini konum izni istemeyen **WP-326** aldı.
- **WP-301** eski `metric_day` backfill yaklaşımı iptal edildi; yerini kayıt anı damgası **WP-325** aldı.
- Eski iki-beta/dalga sırası tarihsel kayıttır; güncel sıra Yol Haritası + Aktif Çalışma Kaydı'dır.

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

## Kapanan / Tekilleştirilen Kayıtlar

| Kayıt | Canlı durum |
|---|---|
| WP-269–275, 280–285 | **Kapandı (2026-07-24).** Kod/test kanıtı + proje sahibinin v45 stable ve beta-v4308 üzerindeki cihaz testi; bekleyen cihaz kabulü kalmadı |
| WP-271 | Staging gerçek push/retry ve timer action davranışı sahip testinde sorunsuz; ölçümlü matris kaydı istenirse yeni WP açılır |
| WP-225, 226, 258 | Tarihsel tamamlanmış işler; ayrıntı arşiv+git'te |
| WP-266/267/268 | Eski ayrıntılar arşivde; açık push/timer kabulü WP-271 ve QA matrisinde |
| WP-278 | **Kapandı:** ürün yalnız TR + EN; DE/AR `.arb` dosyaları geri dönüş için repoda kalır |
| WP-279 | **Kapandı:** aylık e-posta raporu iptal; canlı sağlayıcı/domain kurulmayacak |
| WP-286–294, 296–298, 302–314 | **Kapandı.** Kod/test ve sahip cihaz kabulü tamam; ayrıntılar tarihsel arşiv+git'te |

## Worker'a Verilecek Kısa Komutlar

Yalnız **Bekleyen Uygulanabilir WP'ler** ve Yol Haritası'nda `[ ] Bekliyor` olan
kartlar worker'a verilir. Güncel ürün sırası:

1. **WP-328** — keşif sıralaması + arama/filtre.
2. **WP-329** — birincil grup; migration sıcak yüzeyi nedeniyle 328 ile seri planlanır.
3. **WP-324** — WP-323 cihaz kabulünden sonra tanıtım turu içerikleri.
4. **WP-276 / WP-277** — staging ops kanıtı; ürün UI işlerinden bağımsız planlanır.

`Test için bekleyenler` tablosundaki hiçbir kayıt yeniden worker'a verilmez.

> Her worker önce Aktif Çalışma Kaydı'nı okur, kendi lane'ini claim eder ve SAHİP yolları çakışıyorsa başlamaz. Production/stable hiçbir WP'nin örtük parçası değildir.
