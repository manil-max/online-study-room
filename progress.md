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

- **Migration gerçeği:** repo/local **`0083`** · staging **`0072`** · production
  etkin şema **`0070`**. Production CLI geçmişi legacy/uzlaştırılmamış;
  ayrıntı [`docs/recovery/PRODUCTION-BASELINE.md`](docs/recovery/PRODUCTION-BASELINE.md).
  Deploy contract aynı üç head'i taşır ve production `deploy_enabled: false` kilitlidir.
- **Stable/production:** **v48** yayında, etkin şema `0070`. Yeni production migration, Edge deploy veya stable tag/release yalnız ayrı, somut kullanıcı GO + backup + dry-run ile yapılır; deploy kapısı kilitli.
- **Beta/staging:** **beta-v4309** artefaktı `0070` ile çıktı; staging veritabanı sonradan `0072`ye yükseldi. Yeni kabul kuyruğu `0073–0078` staging terfisinden sonra ortak beta turunda doğrulanır.
- **Release ilkesi:** Android beta/stable artefaktı Android işi başarılı olunca yayımlanır. Windows bağımsız sürer ve başarılı olursa aynı release'e eklenir; Windows hatası Android güncellemesini geri çekmez.
- **Sürüm sırası:** kod/testi biten işler tek QA kuyruğunda birikir; yeni beta/stable yalnız sahip onayıyla çıkar. Eski beta dalga kararları tarihsel arşivdedir.
- **Yönetim varsayılanı:** Production `deploy_enabled/release_enabled` kapalıdır. Stable yalnız protected `production` Environment, exact SHA/head/project-ref GO ve reviewer kanıtıyla ilerler.
- **Kurallar:** Kök `AGENTS.md`, `.agents/AGENTS.md` ve `docs/KALITE-PROGRAMI.md` geçerlidir. Tek çalışma dalı `main`; her WP ayrı commit; production varsayılmaz.
- **Aktif tur:** **Faz E + Global Timer/Presence V3**. İlk paralel dalga: **WP-328** (grup keşfi) + **WP-337** (salt-okunur legacy compatibility gate). Sonrasında migration hattı WP-329 → WP-336 → WP-338 → WP-341 → WP-344 olarak seridir.
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
- **Durum:** [~] Aktif
- **Faz/WP:** Faz E2 · WP-337 kapı kapanışı + WP-346 staging/çoklu cihaz kabulü
- **Aşama:** Local replay → salt-okunur compatibility kanıtı → staging terfisi → beta/cihaz QA
- **SAHİP yollar:** `docs/GLOBAL-TIMER-V3-COMPATIBILITY-EVIDENCE.md` · `docs/qa/DEVICE-QA-MATRIX.md` · staging acceptance kanıtı · `.artifacts/deploy-evidence/**`
- **Ortak/riskli yüzey:** Staging migration/flag sırası; timer notification/widget hot path'a kod değişikliği yok. Production/stable kapsam dışı.
- **Dal:** `main`
- **Başlangıç/Son güncelleme:** 2026-07-26 22:10 (Europe/Istanbul)
- **Not:** Sahip talimatıyla V3 kabul turu başlatıldı. Önce WP-337 aggregate kanıtı, sonra staging `0073→0083`, benzersiz beta APK ve fiziksel cihaz matrisi; bağlı cihaz olmadan cihaz sonucu yazılmaz.

### Codex-2 Lane
- **Durum:** [~] Aktif
- **Faz/WP:** Faz E2 · WP-340
- **Aşama:** Geliştiriliyor
- **SAHİP yollar:** `app/android/app/src/main/kotlin/com/manilmax/online_study_room/timer/TimerStateStore.kt` · `app/android/app/src/main/kotlin/com/manilmax/online_study_room/timer/StudyTimerService.kt` (yalnız envelope enqueue) · Dart parser/flush adapter · ilgili Android/Dart contract testleri
- **Ortak/riskli yüzey:** Native timer/SharedPreferences queue; `TimerExternalCommandStore` semantiği, notification ID/channel/layout/PendingIntent ve `ACTION_STOP_SILENT` değişmez.
- **Dal:** `main`
- **Başlangıç/Son güncelleme:** 2026-07-26 18:23 (Europe/Istanbul)
- **Not:** WP-340 tamamlandı; V2 envelope additive olarak mevcut native queue'ya eklendi, account mismatch fail-closed karantinada ve flush shadow-only. `TimerExternalCommandStore`, bildirim/widget yüzeyleri ve `ACTION_STOP_SILENT` korunuyor. WP-338 tamamlanana kadar WP-339'a geçilmeyecek; remote, beta ve cihaz kabulü zincirin sonundaki ortak QA turunda.

### Codex-3 Lane
- **Durum:** [x] Boşta
- **Faz/WP:** —
- **SAHİP yollar:** —
- **Son not:** WP-344 `0083` local replay, 244 pgTAP ve uygulama kalite kapılarıyla kod/test tamamlandı; timer-sync rollout flag kapalıdır. Staging/cihaz kabulü V3 zincirinin ortak QA turunda yapılacak.

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
| Otomatik doğrulama | Son tamamlanan taban: **886 test yeşil**, `flutter analyze` temiz |
| l10n audit | **0 bulgu**: WP-335, WP-295 önizleme metinlerini katalogladı; 7 kullanıcı-dışı invariant mesajı dar ve gerekçeli muafiyetle ayrıldı |
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

> **WP-323 → WP-324 zinciri tamamlandı.** Proje sahibi WP-324 için WP-323 cihaz
> kabulü ön koşulunu ve ayrıca cihaz kabulünü açıkça atladı (2026-07-26).

#### WP-323: Tanıtım turu motoru 🎈

- **Durum:** [~] Kod/test tamam — Android + Windows cihaz kabulü bekliyor.
- **Kanıt:** `flutter analyze` temiz · tam paket **849 test yeşil**; kullanıcı,
  sürüm ve ekran anahtarları, kuyruk engeli, kalıcılık ve 360 px sınırı kapsandı.
- **Kalan:** Ayrıntılı kabul adımları aşağıdaki **Test için bekleyenler** kuyruğunda.

#### WP-324: Tanıtım turu içerikleri ✍️
- **Program/Faz:** Faz D · Yeni kullanıcı deneyimi
- **Ajan:** Codex · **Durum:** [x] Tamamlandı · **Bağımlılık:** WP-323 motoru
- **Problem:** Motor tek başına bir şey anlatmaz; her ekranın kendi kısa tanıtımı gerekir.
- **Kapsam dışı:** Motor davranışı, yeni ekran tasarımı.
- **SAHİP dosyalar (yaz):** Ana Sayfa · Sayaç · Kamp Ateşi · Gruplar · İstatistik · Profil ekranlarının tur tanımları · `app/lib/l10n/*.arb`
- **DOKUNMA:** `app/lib/core/tour/**` (WP-323'ün motoru — **okunur**)
- **Adımlar:**
  - [x] Ana Sayfa, Sayaç, Gruplar, Kamp Ateşi, İstatistik ve Profil için en fazla 2 balon
  - [x] Metinler TR + EN; DE/AR geri dönüş dosyaları da üretim paritesi için güncellendi
  - [x] Hızlı geçiş WP-323 motoruyla korunuyor; boş veri durumları ayrı ve var olmayan hedefe bağlanmıyor
- **Veri/Migration etkisi:** Yok. · **Ortam/Deploy:** local. · **RLS/Güvenlik:** Yok.
- **Edge-case'ler:** kullanıcının henüz grubu yok (grup turu ne diyecek) · istatistik boşken · kamp ateşi kilitliyken
- **Kabul (ölçülebilir):** Her ekranda balon sayısı **≤ 4** · her balon **≤ 2 satır** · veri boşken tur anlamlı metin gösteriyor (boş ekranı işaret etmiyor) · TR ve EN'de taşma yok.
- **Tuzaklar:** Boş durumda "şurada süren görünür" demek, hiçbir şey görünmeyen bir alanı işaret eder — boş hâl metinleri ayrı yazılmalı.
- **Kanıt:** `flutter analyze` temiz · tam paket **885 test yeşil** · WP-324 içerik/360 px testleri **4/4** · l10n audit yeni bulgu eklemedi (**31 bilinen taban**).
- **Kabul notu:** Proje sahibinin açık yetkisiyle cihaz kabulü atlandı; QA kuyruğuna eklenmedi.
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
| **WP-328** Keşif sıralaması + arama/filtre | Kod/test tamam; `0078` local | Staging dry-run + Android/Windows filtre kabulü |
| **WP-329** Birincil grup | Kod/test tamam; `0079` local | Staging dry-run + iki cihaz primary kabulü |

> Migration sırası korunur: staging'deki `0072` ardından **`0073` → `0079`**.
> Bu beş WP yeniden claim edilmez; test sonucu hata çıkarsa yeni WP açılır.

#### WP-329: Birincil grup 🏠
- **Program/Faz:** Faz E · Grup semantiği · **Durum:** [~] Kod/test tamam; staging/cihaz kabulü bekliyor · **Bağımlılık:** WP-326 + WP-328
- **Problem:** Kullanıcı birden çok gruba üye olabiliyor; UI'da seçili grup ile görev/hedef/grup progression muhasebesini alan birincil grup aynı kavram sanılıyor. Tercih cihazlar arasında ortak ve server-authoritative değil.
- **Kapsam dışı:** Çoklu grup üyeliğini kaldırmak · presence'ı yalnız primary gruba indirmek · direct grup bildirimlerini primary ile filtrelemek · geçmiş session'ları yeniden atfetmek · gün-sınırı algoritmasını değiştirmek.
- **SAHİP dosyalar (yaz):** `supabase/migrations/00NN_primary_group_preference.sql` · `app/lib/data/providers/group_providers.dart` · ilgili group repository interface + Supabase/InMemory çiftleri · birincil grup seçim UI'ı ve testleri
- **DOKUNMA:** `groups.time_zone` (WP-326) · keşif (WP-328) · `study_sessions`/`project_group_day`/başarım projeksiyonları (WP-336) · presence/timer kodu (WP-338+) · push dispatcher
- **Adımlar:**
  - [ ] Private `user_group_preferences` + append-only preference history kur; mutation yalnız security-definer RPC.
  - [ ] Kullanıcı yalnız aktif üyesi olduğu grubu primary seçebilsin; iki cihaz seçimi kullanıcı lock'u + selection revision ile sıralansın.
  - [ ] Tek aktif grubu olan kullanıcı otomatik primary olsun; hiç grubu yoksa null; çok grubu olup seçimi yoksa rastgele atama yapılmasın.
  - [ ] Aktif timer varken primary değişimi timer/bildirim/widget'ı restart etmesin; yeni seçim sonraki çalışma/session için geçerli olsun.
  - [ ] UI'daki seçili/gezilen grup cihaz-yerel kalırken primary hesap-geneli gösterilsin.
  - [ ] Direct grup duyurusu/dürtmesi bütün ilgili üyeliklerde sürsün; yalnız duplicate event idempotency uygulansın.
- **Veri/Migration etkisi:** Yeni preference + history tabloları/RPC. Tek grubu olanlara deterministic backfill; çok gruplular seçim bekler. Remote'a uygulanınca down migration yerine flag kapatma + ileri düzeltme. `study_sessions.day` değişmez.
- **Ortam/Deploy:** local → staging → production ayrı GO.
- **RLS/Güvenlik:** Preference/history public profile'a sızmaz; client primary revision veya history zamanı seçemez; membership leave/delete ile preference aynı kullanıcı lock sınırında uzlaştırılır.
- **Edge-case'ler:** hiç grup yok · tek grup · çok grup/seçim yok · iki cihaz eşzamanlı seçim · primary üyeliği bitmiş · grup silinmiş · aktif timer sırasında seçim · offline cihazda stale preference.
- **Kabul (ölçülebilir):** Telefon ve tablette aynı primary görünür · stale selection revision güncel tercihi geri alamaz · üye olunmayan grup RPC'de reddedilir · tek grup otomatik seçilir · primary silinince güvenli null/yeniden seçim oluşur · timer/bildirim/widget primary değişiminde sıfırlanmaz · secondary gruptan geçerli direct bildirim primary filtresiyle kaybolmaz.
- **Tuzaklar:** `active_group_id/userGroupProvider` primary otoritesi yapılmaz; current preference geçmiş session'a uygulanmaz; “bildirimler yalnız primary” eski kart ifadesi geçersizdir.
- **Model önerisi:** 🔴 Opus

### Faz E2 — Global Timer, Çoklu Grup Presence ve Çoklu Cihaz V3

> Kanonik teknik plan: `docs/GLOBAL-TIMER-PRESENCE-MULTI-DEVICE-ARCHITECTURE-PLAN.md` V3.
>
> Delivery A/B uygulanabilir; Delivery C migration'ı WP-337 compatibility gate geçmeden yazılmaz. Gün sınırı, server finalizer, Pomodoro global fazı ve background native auto-start bu fazın dışındadır.

#### WP-336: Tek-grup session attribution ve progression filtresi 🎯
- **Program/Faz:** Faz E2 · WP-329 entegrasyonu · **Ajan:** Codex · **Durum:** [~] Kod/test tamam — staging/cihaz kabulü bekliyor · **Bağımlılık:** WP-329
- **Problem:** `project_group_day/week` session'ı üye olunan bütün gruplara yazıyor; primary UI seçimi grup hedefi/başarımı/leaderboard çift sayımını durdurmaz.
- **Kapsam dışı:** Gün/timezone algoritması · geçmiş XP'yi geri almak · presence'ı primary gruba indirmek · server timer finalizer.
- **SAHİP dosyalar (yaz):** yeni `supabase/migrations/00NN_session_group_attribution.sql` · ilgili `supabase/tests/*.test.sql` · grup metric contract testleri
- **DOKUNMA:** WP-329 preference UI/provider · native timer/bildirim/widget · push · uygulanmış `0010/0053/0063`
- **Adımlar:** one-to-zero/one `study_session_group_attribution` kur · başlangıç anındaki primary'yi preference history'den server-side çöz · cutover öncesini `legacy_multi_group`, sonrasını fail-closed `primary_v1` ayır · yeni ileri migration ile day/week/trigger/cron/catch-up yollarını attribution-aware yap · `raw→seg→camp/alpha/loco` zincirini yalnız attribution grubuyla kur.
- **Veri/Migration etkisi:** Additive ilişki + cutover config + fonksiyon replace; eski session/ödül korunur. Geri alma: flag kapatma + ileri düzeltme, veri silme yok.
- **Ortam/Deploy:** Local replay/pgTAP → staging; production yalnız backup/dry-run/soak ve somut GO.
- **RLS/Güvenlik:** Client attribution seçemez; session/preference history server doğrular; silinen grup için audit snapshot'ı korunur.
- **Edge-case'ler:** offline geç session · çalışma sırasında primary değişimi · cutover sınırı · cron eski günü recompute · grup silinmesi.
- **Kabul (ölçülebilir):** Cutover sonrası bir session en fazla bir gruba gider · secondary day/week/achievement katkısı 0 · cron secondary veriyi geri getirmez · kişisel süre/XP mevcut tek writer ile değişmez · geçmiş ödül geri alınmaz.
- **Kanıt:** Local `0080` replay ve 206 pgTAP PASS · `flutter analyze` temiz · `flutter test --dart-define-from-file=env.json` PASS. **Kodda doğrulandı; staging/cihazda doğrulanmalı.**
- **Tuzaklar:** `counts_for_group_progression` canlı read-model alanıdır; tarihsel recompute otoritesi değildir. Eski `0063` düzenlenmez.
- **Model önerisi:** 🔴 Opus

#### WP-337: V3 legacy compatibility ve donuk kontrat kapısı 🔬
- **Program/Faz:** Faz E2 · Delivery C0 · **Ajan:** Codex-2 · **Durum:** [~] Kod/test tamam — güncel ortam aggregate kanıtı bekliyor (NO-GO) · **Bağımlılık:** Yok
- **Problem:** `live_study_runs` index/CHECK/NOT NULL, legacy RPC, Dart enum ve iki native queue sınırı kanıtlanmadan migration yazılırsa ghost lock veya parse hatası oluşur.
- **Kapsam dışı:** Migration/feature/deploy · timer UX refactor · remote mutasyon.
- **SAHİP dosyalar (yaz):** `docs/GLOBAL-TIMER-V3-COMPATIBILITY-EVIDENCE.md` · `app/test/data/global_timer_v3_legacy_contract_test.dart`
- **DOKUNMA:** `supabase/migrations/**` · `study_providers.dart` · Android native kaynaklar · `LiveStudyRun`
- **Adımlar:** 0051 invariant envanteri · local/staging/production salt-okunur `running/paused` count + index/CHECK kanıtı · birleşik active-study index testi · ortak advisory-lock kararı · legacy DTO/InMemory/Supabase yüzeyi · `commandSeq` ile `pendingIntervals` ayrımı · V2 flag/DTO kararları.
- **Veri/Migration etkisi:** Yok; çıktı WP-341'in GO/NO-GO girdisidir.
- **Ortam/Deploy:** Local + redacted salt-okunur staging/production; deploy yok.
- **RLS/Güvenlik:** Yalnız aggregate/schema metadata; UUID/token/secret kanıta girmez.
- **Edge-case'ler:** açık/paused legacy run · eksik CLI history · V2 terminal status'un legacy DTO'ya düşmesi · iki protocol start yarışı.
- **Kabul (ölçülebilir):** G1–G6/H1–H4 PASS/FAIL · ortam başına açık legacy sayısı · hedef tek active index · V2 DTO/flag/lock kararı · migration GO/NO-GO.
- **Kanıt:** `docs/GLOBAL-TIMER-V3-COMPATIBILITY-EVIDENCE.md` ve `app/test/data/global_timer_v3_legacy_contract_test.dart`; G1–G6/H1–H4 PASS, local/staging/production güncel `running/paused` aggregate eksik olduğu için WP-341 **NO-GO**. `flutter analyze` temiz, tam `flutter test` 893 test yeşil (2026-07-26). **Kodda doğrulandı.**
- **Tuzaklar:** “Muhtemelen açık run yok” kanıt değildir; remote satır değiştirme yetkisi yoktur.
- **Model önerisi:** 🔴 Opus

#### WP-338: Server-derived çoklu grup presence çekirdeği 👥
- **Program/Faz:** Faz E2 · Delivery A backend · **Ajan:** Codex · **Durum:** [~] Kod/test tamam; staging/cihaz kabulü bekliyor · **Bağımlılık:** WP-329; migration sırası WP-328/WP-329 sonrası
- **Problem:** `presence(user_id PK, group_id)` kullanıcıyı yalnız seçili grupta gösterebilir; Flutter heartbeat ölünce görünürlük kaybolur.
- **Kapsam dışı:** Global run · push · session/XP finalizer · gün sınırı · native uplink.
- **SAHİP dosyalar (yaz):** yeni `supabase/migrations/00NN_multi_group_presence_projection.sql` · ilgili pgTAP/RLS testleri
- **DOKUNMA:** client provider/repository (WP-339) · native timer · push · session projectionları (WP-336)
- **Adımlar:** kullanıcı başına `user_live_presence_state` kanonik state/lease · `(group_id,user_id)` projection · start/stop'ta üyelik fan-out · heartbeat yalnız kanonik lease · join/leave/ban cleanup · primary progression flag · kullanıcı-lock'lu idempotent sweeper · eski presence fallback.
- **Veri/Migration etkisi:** Additive tablolar/RPC/RLS/Realtime; rollback new-read flag kapatma, eski tablo korunur.
- **Ortam/Deploy:** Local replay/pgTAP → staging; production ayrı GO.
- **RLS/Güvenlik:** Client projection DML yapamaz; yalnız kendi state RPC'si; aktif aynı grup üyeliği yoksa read yok.
- **Edge-case'ler:** 0/1/2/10 grup · join/leave/ban · primary null · iki heartbeat/sweeper · stale stop.
- **Kabul (ölçülebilir):** Bütün aktif gruplarda tek satır · heartbeat başına projection write 0 · leave/ban read 0 · secondary flag false · iki sweeper tek transition · çapraz grup sızıntısı 0.
- **Tuzaklar:** Yalnız server'ın bildiği state fan-out edilir; Flutter hiç uyanmazsa native start henüz bilinmez.
- **Kanıt:** Local `0081` replay ve 218 pgTAP PASS · deploy guard 51 PASS · `flutter analyze` temiz · `flutter test --dart-define-from-file=env.json` PASS. **Kodda doğrulandı; staging/cihazda doğrulanmalı.**
- **Model önerisi:** 🔴 Opus

#### WP-339: Presence client cutover ve seçili-grup bağını kaldırma 🔄
- **Program/Faz:** Faz E2 · Delivery A client · **Ajan:** Codex · **Durum:** [~] Kod/test tamam; staging/cihaz kabulü bekliyor · **Bağımlılık:** WP-338
- **Problem:** Publish/watch `userGroupProvider` ve tek `group_id`ye bağlı; auth/grup hazır değilse start presence kayboluyor.
- **Kapsam dışı:** Native outbox · global mirror · push · timer UI refactor.
- **SAHİP dosyalar (yaz):** presence repository interface + Supabase/InMemory/Offline çiftleri · `presence_providers.dart` · `presence_lifecycle.dart` · dar `study_providers.dart` adapter'ı · testler
- **DOKUNMA:** Android notification/widget action/layout · `TimerStateStore` · global coordinator · discovery/primary UI
- **Adımlar:** group parametresiz state/heartbeat API · grup projection subscription · auth-ready pending publish · old/new dual-read telemetry/flags · repository parity · sessiz hata yerine queue-age/error gözlemi.
- **Veri/Migration etkisi:** Yok; WP-338 şeması.
- **Ortam/Deploy:** Local → staging beta; production read switch ayrı kabul.
- **RLS/Güvenlik:** Client fan-out gruplarını seçmez; account switch pending publish'i başka hesaba göndermez.
- **Edge-case'ler:** cold-start auth · cihazlarda farklı selected group · primary üçüncü grup · offline/reconnect · eski client.
- **Kabul (ölçülebilir):** App start bütün gruplarda · selected group projection ownership'i değiştirmez · auth gecikmesinde event kaybı 0 · ağ hatası timer yüzeylerini bozmaz · kill switch çalışır.
- **Kanıt:** `flutter analyze` temiz · V3 lease/fallback/offline kuyruk/contract testleri yeşil. Tam `flutter test` koşumu tek worker'da ilerlemesiz kaldığı için sonlandırıldı; staging + çoklu cihaz kabulü WP-346 ortak QA turunda. **Kodda doğrulandı; cihazda doğrulanmalı.**
- **Tuzaklar:** Sıcak timer yolunda network await yok; notification/widget kodu temizlenmez.
- **Model önerisi:** 🟣 Pro

#### WP-340: Native V2 durable command envelope ve cold-start flush 📦
- **Program/Faz:** Faz E2 · Delivery B · **Ajan:** Codex-2 · **Durum:** [x] Kod/test tamam · **Bağımlılık:** WP-337
- **Problem:** External-command köprüsü ve interval kuyruğu global start/stop intent'ini hesap-bağlı, retry edilebilir command olarak temsil etmiyor.
- **Kapsam dışı:** Native network/credential uplink · server apply · notification/widget UI · remote start.
- **SAHİP dosyalar (yaz):** `TimerStateStore.kt` · `StudyTimerService.kt` yalnız envelope enqueue noktaları · Dart parser/flush adapter · Android/Dart contract testleri
- **DOKUNMA:** notification ID/channel/layout/PendingIntent · `ACTION_STOP_SILENT` · server migration · `TimerExternalCommandStore` yerel köprü semantiği
- **Adımlar:** V2 `kind/schema_version/command_id/account_id/installation_id/action/client_occurred_at/origin/run_id?/expected_run_revision?` · legacy parser uyumu · Android'de tek native envelope üreticisi · Flutter command ID aktarımı/native UUID · unbound account karantinası · UUID kısmi ack · shadow flag.
- **Veri/Migration etkisi:** Yalnız SharedPreferences format evrimi; DB yok.
- **Ortam/Deploy:** Local/unit/instrumentation; remote yok.
- **RLS/Güvenlik:** Secret/token yok; account mismatch fail-closed; action allowlist.
- **Edge-case'ler:** process kill · start-stop-start · logout/account switch · bozuk JSON · legacy+V2 karışık array · disk failure · duplicate.
- **Kabul (ölçülebilir):** Eylem başına tek command ID · legacy interval kaybı/çift session 0 · yanlış hesap gönderimi 0 · widget ≤500 ms ve 8 saat drift baseline değişmez.
- **Tuzaklar:** `commandSeq` distributed sürüm değildir; start'a sahte `runToken` yazılmaz; üçüncü queue açılmaz.
- **Kanıt:** `flutter analyze` temiz; `flutter test --dart-define-from-file=env.json -r compact` 899 test geçti. Hedefsiz Gradle Kotlin çağrısı varyant/ortam validasyonunda kesildi; beta artefakt/cihaz doğrulaması kullanıcı sırasına göre WP-345 sonrasındaki ortak QA turunda, `env.json` ile yapılacak.
- **Model önerisi:** 🔴 Opus

#### WP-341: Global timer V2 server çekirdeği ve compatibility migration 🧠
- **Program/Faz:** Faz E2 · Delivery C backend · **Ajan:** Codex-3 · **Durum:** [~] Kod/test tamam; staging/cihaz kabulü bekliyor · **Bağımlılık:** WP-337 GO + WP-338; migration hattında WP-336/WP-338 sonrası
- **Problem:** Aynı hesabın cihazları arasında kanonik run, kullanıcı-geneli state version ve idempotent command otoritesi yok.
- **Kapsam dışı:** Client native apply · push · server session/XP finalizer · pause/Pomodoro/countdown · production deploy.
- **SAHİP dosyalar (yaz):** yeni `supabase/migrations/00NN_global_timer_v2.sql` · ilgili pgTAP/RLS/concurrency testleri
- **DOKUNMA:** uygulanmış `0051` · legacy Dart model/repository · client/native · push
- **Adımlar:** `live_study_runs` additive V2 alanları/backfill · `status` CHECK genişletme, ikinci state yok · eski index'i birleşik study index ile aynı transaction'da değiştir · `user_timer_state`/command/device tabloları · `command_id→client_request_id` · ortak lock · start/stop/heartbeat/snapshot/ack · run/state version · abandoned/sweeper · presence transaction · V2 flag false.
- **Veri/Migration etkisi:** Additive + tek index replacement + CHECK genişletme; delete yok. Rollback flag kapatma + ileri migration.
- **Ortam/Deploy:** Local full replay/concurrency; staging WP-346; production yok.
- **RLS/Güvenlik:** auth.uid owner · device revoke · direct DML kapalı · result snapshot hesap izolasyonu · rate limit.
- **Edge-case'ler:** legacy açık run · iki protocol yarışı · yeni run rev1/eski rev11 · stale stop · iki sweeper · ghost · aynı command ID iki hesap.
- **Kabul (ölçülebilir):** Bütün protocol'lerde aktif study ≤1 · new-run rev1 kabul · abandoned bloklamaz · hesaplar arası snapshot sızıntısı 0 · heartbeat projection write 0 · iki sweeper tek abandoned/state version.
- **Tuzaklar:** V2-only index yasak; legacy DTO'ya terminal V2 status dönmez; V1 `finalized` üretmez; `_verifiedServerAvailable` açılmaz.
- **Kanıt:** `0082` local şemada uygulandı; 236 pgTAP PASS · deploy guard 51 PASS · `flutter analyze` temiz · `flutter test --dart-define-from-file=env.json` PASS. V2 runtime flag kapalı. **Kodda doğrulandı; staging/cihazda doğrulanmalı.**
- **Model önerisi:** 🔴 Opus

#### WP-342: Flutter global coordinator ve shadow publish 🛰️
- **Program/Faz:** Faz E2 · Delivery C shadow · **Ajan:** Codex · **Durum:** [~] Kod/test tamam; staging/cihaz kabulü bekliyor · **Bağımlılık:** WP-340 + WP-341
- **Problem:** Server çekirdeği ile local/native timer arasında versioned snapshot, outbox flush ve reconcile katmanı yok.
- **Kapsam dışı:** Native remote apply · push · timer UI · session finalizer.
- **SAHİP dosyalar (yaz):** yeni global timer model/repository/coordinator · Supabase/InMemory çiftleri · WP-340 flush entegrasyonu · testler
- **DOKUNMA:** legacy `LiveStudyRun/LiveRunStatus` ve verified repository · Android notification/widget görünümü
- **Adımlar:** ayrı `GlobalTimerSnapshot` DTO · state/run CAS · auth/account-bound flush · login/cold-start/foreground/network/realtime coordinator · shadow-only divergence · InMemory parity · support telemetry.
- **Veri/Migration etkisi:** Yok; WP-341 RPC.
- **Ortam/Deploy:** Local → staging shadow; native apply kapalı.
- **RLS/Güvenlik:** Account switch isolation; başka hesap snapshot'ı apply edilmez; secret loglanmaz.
- **Edge-case'ler:** commit/response loss · duplicate retry · auth refresh · offline iki start · existing run · local newer start.
- **Kabul (ölçülebilir):** Retry aynı sonuç · snapshot rollback 0 · process-death queue korunur · local start p95 baseline aynı · divergence ölçülebilir.
- **Tuzaklar:** Android Flutter ikinci command producer olmaz; legacy verified yolu açılmaz.
- **Kanıt:** `flutter analyze` temiz · V2 snapshot/idempotency ve push-device contract testleri yeşil. Rollout varsayılanı `disabled`; staging/cihaz kabulü WP-346 ortak turunda. **Kodda doğrulandı; cihazda doğrulanmalı.**
- **Model önerisi:** 🟣 Pro

#### WP-343: Foreground çoklu cihaz mirror ve güvenli remote stop 📱↔️📱
- **Program/Faz:** Faz E2 · Delivery C apply · **Ajan:** Codex · **Durum:** [~] Kod/test tamam; staging/cihaz kabulü bekliyor · **Bağımlılık:** WP-342 shadow kabulü
- **Problem:** İki foreground cihaz aynı global çalışmayı göstermiyor; başka cihaz stop'u native yüzeylere güvenle uygulanmıyor.
- **Kapsam dışı:** Background auto-start · FCM · finalizer · Pomodoro/countdown mirror.
- **SAHİP dosyalar (yaz):** coordinator foreground apply · dar Android remote-apply metadata/action alanları · ack/UX · testler
- **DOKUNMA:** normal local start/stop sırası · notification/widget layout · session/XP · push
- **Adımlar:** Realtime→auth snapshot · CAS/account/run doğrulama · foreground start mirror · `ACTION_STOP_SILENT` remote stop · echo suppression · device ack/opt-out · stale stop guard.
- **Veri/Migration etkisi:** Yok.
- **Ortam/Deploy:** Local iki client → staging iki Android; production yok.
- **RLS/Güvenlik:** Aynı auth + kayıtlı device; doğrulanmamış payload native apply edilmez.
- **Edge-case'ler:** aynı anda start · başka cihaz stop · echo · eski stop · opt-out · logout · local start yarışı.
- **Kabul (ölçülebilir):** Foreground start/stop p95≤2 sn · ek session/XP 0 · eski stop yeni run'ı kesmez · notification/widget regression 0.
- **Tuzaklar:** Remote apply sanal kullanıcı tıklaması değildir; silent stop değiştirilmez.
- **Kanıt:** Doğrulanmış V2 snapshot'tan mirror-start/deferred/aynı-run stop kararı; account+device scoped seen/ack; mirror kaynaklı native V2 echo bastırması ve session/XP yazmayan silent stop kod/test ile kapsandı. `flutter analyze` temiz · tam `flutter test --dart-define-from-file=env.json` PASS. **Kodda doğrulandı; staging/cihazda doğrulanmalı.**
- **Model önerisi:** 🔴 Opus

#### WP-344: Timer-sync push transport sınıfı 📬
- **Program/Faz:** Faz E2 · Delivery D backend · **Ajan:** Codex-3 · **Durum:** [~] Kod/test tamam; staging/cihaz kabulü bekliyor · **Bağımlılık:** WP-341
- **Problem:** Mevcut push allowlist/preference/quiet-hours/TTL hattı `timer_sync`i sessizce yutar veya yanlış policy uygular.
- **Kapsam dışı:** Client auto-start · remote truth · genel bildirim refactor · production Edge deploy.
- **SAHİP dosyalar (yaz):** yeni push-policy migration · `supabase/functions/dispatch-push/index.ts` timer handler · contract testleri
- **DOKUNMA:** nudge/announcement/update davranışı · Android timer service · client apply
- **Adımlar:** type CHECK + `_push_type_enabled` · unknown-type hata · quiet-hours/cooldown bypass · kısa TTL/high priority/collapse/`exclude_device_id` · minimal payload · retry/expiry telemetry.
- **Veri/Migration etkisi:** Additive policy/outbox alanları; rollback timer push flag.
- **Ortam/Deploy:** Local function test → staging; production ayrı GO.
- **RLS/Güvenlik:** Token yalnız delivery; minimal payload; başka kullanıcı installation'ına fan-out yok.
- **Edge-case'ler:** quiet hours · duplicate/reverse · expired event · token rotate/revoke · unknown type · origin exclusion.
- **Kabul (ölçülebilir):** Delivery satırı oluşur · unknown silent success 0 · origin delivery 0 · TTL/collapse testleri · push fail global commit'i bozmaz.
- **Tuzaklar:** Timer policy normal kullanıcı bildirimi değildir.
- **Kanıt:** Local `0083` replay ve 244 pgTAP PASS · deploy guard 51 PASS · `flutter analyze` temiz · `flutter test --dart-define-from-file=env.json` PASS. Timer-sync rollout flag kapalı. **Kodda doğrulandı; staging/cihazda doğrulanmalı.**
- **Model önerisi:** 🟣 Pro

#### WP-345: Background timer sinyali ve app-open reconcile 🔔
- **Program/Faz:** Faz E2 · Delivery D client · **Ajan:** Codex · **Durum:** [~] Kod/test tamam; staging/cihaz kabulü bekliyor · **Bağımlılık:** WP-343 + WP-344
- **Problem:** Background/terminated cihaz için timer-sync deferred UX/ack ve güvenli snapshot reconcile yok.
- **Kapsam dışı:** Kotlin auto-FGS · native authenticated uplink · force-stop anlık garantisi.
- **SAHİP dosyalar (yaz):** Flutter FCM timer routing · coordinator tetikleri · deferred notification/ack UX · testler
- **DOKUNMA:** Android normal timer action/layout · server push handler · hot-path başlangıç
- **Adımlar:** payload schema/state version doğrulama · truth olarak uygulamadan signal · app-open auth snapshot + CAS · seen/deferred/failed ack · token/account cleanup · push-yok reconcile.
- **Veri/Migration etkisi:** Yok.
- **Ortam/Deploy:** Staging gerçek FCM + Android lifecycle; production yok.
- **RLS/Güvenlik:** Payload token/private subject yok; auth olmadan state apply yok.
- **Edge-case'ler:** terminated/force-stop/doze · duplicate/reverse · logout · token rotate · FGS restriction.
- **Kabul (ölçülebilir):** Foreground p95≤2 sn · teslim edilen background signal p95≤10 sn · app-open reconcile p95≤2 sn · rollback 0 · force-stop sonrası açılış doğru.
- **Tuzaklar:** FCM server→device'dır; native start uplink'i değildir.
- **Kanıt:** Yalnız minimal v1 `timer_sync` payload'ı kabul edilir; sinyal SharedPreferences'ta defer edilir ve foreground/app-open'ta auth snapshot reconcile'ını tetikler; payload asla state apply etmez, logout'ta silinir. `flutter analyze` temiz · tam `flutter test --dart-define-from-file=env.json` PASS. **Kodda doğrulandı; staging/cihazda doğrulanmalı.**
- **Model önerisi:** 🟣 Pro

#### WP-346: V3 staging, çoklu cihaz kabulü ve rollout kapıları 🧪
- **Program/Faz:** Faz E2 · QA/rollout · **Ajan:** — · **Durum:** [ ] Bekliyor · **Bağımlılık:** WP-336 + WP-339 + WP-343 + WP-345
- **Problem:** Global/native değişiklikler gerçek Samsung/Pixel/tablet lifecycle ve migration terfisiyle kanıtlanmadan güvenli sayılamaz.
- **Kapsam dışı:** Production/stable · background auto-start · finalizer; bug düzeltmek (ayrı debug WP).
- **SAHİP dosyalar (yaz):** `docs/qa/DEVICE-QA-MATRIX.md` V3 satırları · staging acceptance raporu · gerekli kanıt/manifest
- **DOKUNMA:** Feature kodu
- **Adımlar:** local replay + staging dry-run · flag sıralı açılış · telefon/tablet, Pixel/Samsung, API33–36 · app/widget/notification/lifecycle/offline/auth yarışları · drift/session/RLS/lease/push/batarya ölçümü · rollback tatbikatı · ≥3 gün beta soak.
- **Veri/Migration etkisi:** Yalnız staging terfisi/kanıt; production yok.
- **Ortam/Deploy:** Local → staging → benzersiz beta; production ayrı somut GO.
- **RLS/Güvenlik:** Cross-account command/result/presence abuse matrisi; redacted kanıt.
- **Edge-case'ler:** OEM pil · force-stop · iki hesap · stale push · lease · join/leave · primary değişimi · eski client.
- **Kabul (ölçülebilir):** Timer/widget/notification regresyon 0 · 8 saat ≤±1 sn · ek session/XP 0 · visibility %100 · secondary progression 0 · foreground p95≤2 sn · teslim edilen push p95≤10 sn · P0/P1 0 · soak≥3 gün.
- **Tuzaklar:** Test bug'ı bu WP'de yamalanmaz; yeni debug WP/beta gerekir. Production GO türetilmez.
- **Model önerisi:** 🔴 Opus

#### WP-347: Grup attribution yapılandırması RLS güvenlik düzeltmesi 🔒
- **Program/Faz:** Faz E2 · release-blocking debug · **Ajan:** Codex · **Durum:** [~] Geliştiriliyor · **Bağımlılık:** WP-336
- **Problem:** `group_progression_attribution_config` doğrudan client yetkileri geri alınmış olsa da RLS kapalı oluşturulmuş; güvenlik denetimi bunu kritik bulgu olarak raporluyor.
- **SAHİP dosyalar (yaz):** `supabase/migrations/0084_group_progression_attribution_config_rls.sql` · `supabase/tests/011_session_group_attribution.test.sql` · `tooling/release/deploy-contract.json` · bu WP kartı.
- **Kapsam dışı:** `0080`i değiştirmek · client policy vermek · timer/notification/widget kodu · production deploy.
- **Kabul:** RLS açık; `anon/authenticated` doğrudan select/insert/update/delete yapamaz; mevcut SECURITY DEFINER trigger/resolver zinciri attribution testinde çalışır; local replay/pgTAP yeşil.
- **Geri alma:** Veri silmeden yeni ileri migration ile yalnız policy/RLS davranışı düzeltilir; `0084` uygulanmışsa geriye dosya değiştirilmez.
- **Not:** Staging `0073→0084` terfisinden ve beta üretiminden önce kapanmalıdır.

#### V3 paralel çalışma ve migration sırası

```text
Migration hattı:
WP-328 → WP-329 → WP-336 → WP-338 → WP-341 → WP-344

Kanıt/client/native hattı:
WP-337 → WP-340
WP-338 → WP-339
WP-340 + WP-341 → WP-342 → WP-343
WP-343 + WP-344 → WP-345
hepsi → WP-346
```

> ✅ İlk güvenli paralel dalga: WP-328 + WP-337.
>
> ⚠️ Migration kullanan WP-328/329/336/338/341/344 paralel başlamaz.
>
> ⚠️ `study_providers.dart`/native timer yüzeyindeki WP-339/340/342/343 sahip sınırı teyit edilmeden paralel başlamaz.

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

#### WP-335: l10n hijyeni ve audit kapısı 🧹
- **Program/Faz:** Faz F · kalite kapısı
- **Ajan:** Codex · **Durum:** [~] Kod/test tamam — cihaz kabulü bekliyor · **Bağımlılık:** Yok
- **Problem:** `python scripts/l10n_audit.py` 31 bulguyla kırmızı. Bunların 24'ü WP-295 parametrik önizlemede kullanıcıya görünen sabit metin; 7'si ise kullanıcıya hiç gösterilmeyen gökyüzü/yerleşim invariant hata mesajı.
- **Kapsam dışı:** AR/DE ürünleştirmesi veya RTL (WP-278 ürün kararı) · yasal metin mimarisi · l10n denetimini gevşetmek/genel muafiyet eklemek · kamp ateşi yerleşim davranışını değiştirmek.
- **SAHİP dosyalar (yaz):** `app/lib/wp295_preview.dart` · `app/lib/l10n/app_{en,tr,de,ar}.arb` · `scripts/l10n_audit.py` · `app/test/features/wp295_preview_test.dart` · WP-335 l10n testleri.
- **DOKUNMA (oku, değiştirme):** `app/lib/features/classroom/widgets/campfire_scene.dart` · `app/lib/core/tour/**` · dil seçimi/supported locale politikası (WP-321).
- **Adımlar:**
  - [x] WP-295 önizlemesinin AppBar, chip, denetim etiketi, açıklama ve tooltip metinlerini ARB anahtarlarına taşı; değer ve interpolasyonlar her iki görünür dilde doğru olsun.
  - [x] `sky_phase.dart` ve `campfire_layout.dart`daki yalnız geliştirici/invariant `ArgumentError` mesajlarını, nedenleri yazılı iki **dosya-bazlı** audit muafiyetine al; genel regex veya UI yuvası muafiyeti ekleme.
  - [x] TR + EN önizleme widget testini ve audit sıfır-bulgu kapısını çalıştır; dört katalog anahtar eşliğini koru.
- **Veri/Migration etkisi:** Yok. Geri alma: eklenen ARB anahtarları ve dar muafiyet kayıtları geri alınır; şema/uzak ortam değişmez.
- **Ortam/Deploy:** Yalnız local; release, tag veya remote mutasyon yok.
- **RLS/Güvenlik:** Yok. Ham invariant hata metni kullanıcıya gösterilmez; muafiyet bunu belgelemek içindir.
- **Edge-case'ler:** sayı/değer interpolasyonu · TR/EN uzun metin · 360 px önizleme · geliştirici dışa-aktarım metninin kullanıcı etiketi sayılmaması · DE/AR katalog eşliği.
- **Kabul (ölçülebilir):** `python scripts/l10n_audit.py` **0** ile çıkar · dört ARB katalog anahtar/placeholder eşliği korunur · WP-295 önizlemesi TR ve EN'de başlık, chip ve tüm erişilebilir tooltip'lerle render olur · `flutter analyze` 0 uyarı ve ilgili testler yeşil.
- **Tuzaklar:** İnvariant mesajlarını kataloglamak gereksiz kullanıcı metni üretir; buna karşılık tüm dosyayı muaf tutmak gelecekte gerçek UI metni kaçırır. Yalnız iki dosya, gerekçeli ve dar muaf tutulur.
- **Kanıt:** `python scripts/l10n_audit.py` **0 bulgu** · `flutter analyze` temiz · tam paket **886 test yeşil** · TR+EN widget testinde 360 px mobil yerleşim ve tüm denetim etkileşimleri kapsandı. **Cihazda doğrulanmalı.**
- **Model önerisi:** 🔵 Sonnet

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
| **K5** Çoklu grup | **Birincil grup** — kullanıcı seçer; görev/hedef/grup progression yalnız onu sayar. Canlı presence bütün aktif üyeliklerde görünür; direct grup bildirimleri ve timer-sync sinyalleri primary ile filtrelenmez |
| **K6** İsim + logo | ⏸️ Plan 2 başlamadan konuşulacak |
| **K7** Gizlilik URL'i | **GitHub Pages** — bedava, HTTPS hazır, `docs/legal/*.md`'den yayınlanır |
| **K8** Yurtdışı gün sınırı | **Birincil grubun bölgesi** belirler; grubu olmayan cihaz saat dilimini kullanır. Gruplara bölge alanı + üye sınırı 8 + keşifte yakınlık sıralaması |
| Üye sınırı | **8 kişi** — `0071` staging'e uygulandı; beta cihaz kabulü bekliyor |

---

## ⚠️ Risk ve Tuzak Notları

- **Sürüm disiplini.** Sürüm sahibin onayıyla çıkar; düzeltmeler birikir, tek sürümde çıkar.
- **Migration drift.** Repo/local `0083`, staging `0072`, production `0070`. `0073–0083` seri dry-run + post-check olmadan staging'e uygulanmaz.
- **V3 migration sırası.** WP-328 → WP-329 → WP-336 → WP-338 → WP-341 → WP-344 tek migration hattıdır; aynı anda iki migration worker'ı açılmaz. Her adım local replay, şema post-check ve önceki head kanıtı ister.
- **Sayaç sıcak yolu donuktur.** WP-340–345 normal local start/stop sırasını, notification ID/channel/layout/PendingIntent'leri, widget görünümünü ve `ACTION_STOP_SILENT` davranışını yeniden tasarlamaz. Global senkron additive envelope + shadow + feature flag ile gelir; WP-346 gerçek cihaz regresyon kapısı geçmeden varsayılan açılmaz.
- **l10n kapısı temiz.** WP-335, 24 gerçek WP-295 kullanıcı metnini kataloğa taşıdı; 7 kullanıcı-dışı invariant mesajını dar ve gerekçeli muafiyetle ayırdı. Yeni UI metni ekleyen WP'ler audit sıfır-bulgu kuralını korumalıdır.
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
| **WP-335** l10n hijyeni | Android + Windows | TR/EN WP-295 önizlemesinde başlık, durum çipi, denetimler ve tooltip'ler doğal; 360 px'te sahne + kaydırılabilir kontrol alanı taşmasız. **Cihazda doğrulanmalı.** |
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
| **WP-328** Keşif sıralaması + arama/filtre | Staging + Android + Windows | `0078` önce `0073→0078` seri dry-run/apply ile terfi etmeli; ardından kullanıcı bölgesine göre sıralama, bölge filtresi, boş kontenjan filtresi ve sayfalama gerçek cihazda doğrulanmalı. **Cihazda doğrulanmalı.** |
| **WP-329** Birincil grup | Staging + iki Android cihaz | `0079`, `0073→0079` seri dry-run/apply ile terfi etmeli; tek grup otomatik seçim, iki cihaz stale-revision reddi, üyelikten çıkış/silmede güvenli uzlaşma ve timer/bildirim/widget regresyonu doğrulanmalı. **Cihazda doğrulanmalı.** |
| **WP-336** Tek-grup session attribution | Staging + iki Android cihaz | `0080`, `0073→0080` seri dry-run/apply sonrasında yeni session yalnız başlangıçtaki primary gruba yazılır; secondary day/week/achievement katkısı ve cron geri yazımı 0, kişisel süre/XP korunur. **Cihazda doğrulanmalı.** |
| **WP-343** Foreground mirror + remote stop | Staging + iki Android cihaz | Aynı hesapta foreground start/stop p95≤2 sn; ek session/XP 0; eski stop yeni yerel run'ı kesmez; bildirim/widget regresyonu 0. **Cihazda doğrulanmalı.** |
| **WP-345** Timer-sync signal + app-open reconcile | Staging FCM + Android lifecycle | Data-only sinyal p95≤10 sn; açılış reconcile p95≤2 sn; terminated/doze/logout/force-stop sonrasında payload state uygulamaz, snapshot doğru state'i getirir. **Cihazda doğrulanmalı.** |

**Ortam sırası:** staging şu anda `0072`; veri/grup zinciri **`0073` → `0080`**
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

1. İlk güvenli paralel dalga: **WP-328** (keşif) + **WP-337** (salt-okunur V3 compatibility gate).
2. Migration hattı: **WP-329 → WP-336 → WP-338 → WP-341 → WP-344**. Bunlar seri claim edilir.
3. Client/native hattı: **WP-337 → WP-340**; **WP-338 → WP-339**; ardından **WP-340 + WP-341 → WP-342 → WP-343** ve **WP-343 + WP-344 → WP-345**.
4. Bütün V3 yolları **WP-346** staging + çoklu cihaz + rollback kabulünde birleşir.
5. **WP-276 / WP-277**, SAHİP dosya ve ortam çakışması yoksa V3 dışındaki ops kanıtı olarak ayrıca planlanabilir.

`Test için bekleyenler` tablosundaki hiçbir kayıt yeniden worker'a verilmez.

> Her worker önce Aktif Çalışma Kaydı'nı okur, kendi lane'ini claim eder ve SAHİP yolları çakışıyorsa başlamaz. Production/stable hiçbir WP'nin örtük parçası değildir.
