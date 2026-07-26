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

- **Migration gerçeği:** repo/local **`0084`** · staging **`0084`** · production
  etkin şema **`0070`**. Production CLI geçmişi legacy/uzlaştırılmamış;
  ayrıntı [`docs/recovery/PRODUCTION-BASELINE.md`](docs/recovery/PRODUCTION-BASELINE.md).
  Deploy contract aynı üç head'i taşır ve production `deploy_enabled: false` kilitlidir.
- **Stable/production:** **v48** yayında, etkin şema `0070`. Yeni production migration, Edge deploy veya stable tag/release yalnız ayrı, somut kullanıcı GO + backup + dry-run ile yapılır; deploy kapısı kilitli.
- **Beta/staging:** `beta-v4401` APK'sız tarihsel başarısız adaydır. **`beta-v4402` yayımlandı**: Android APK + Windows MSIX/ZIP mevcut, release run `30212796092` bütünüyle PASS. Staging veritabanı `0084`te; V3 `0073–0084` zinciri dry-run/apply/post-check PASS. Fiziksel cihaz bağlı olmadığı için cihaz kabulü yapılmadı; V3 rollout flag'leri kapalıdır.
- **Release ilkesi:** Android beta/stable artefaktı Android işi başarılı olunca yayımlanır. Windows bağımsız sürer ve başarılı olursa aynı release'e eklenir; Windows hatası Android güncellemesini geri çekmez.
- **Sürüm sırası:** kod/testi biten işler tek QA kuyruğunda birikir; yeni beta/stable yalnız sahip onayıyla çıkar. Eski beta dalga kararları tarihsel arşivdedir.
- **Yönetim varsayılanı:** Production `deploy_enabled/release_enabled` kapalıdır. Stable yalnız protected `production` Environment, exact SHA/head/project-ref GO ve reviewer kanıtıyla ilerler.
- **Kurallar:** Kök `AGENTS.md`, `.agents/AGENTS.md` ve `docs/KALITE-PROGRAMI.md` geçerlidir. Tek çalışma dalı `main`; her WP ayrı commit; production varsayılmaz.
- **Aktif tur:** **Stable öncesi seri ürün revizyonu: WP-348 → WP-349 → WP-350 → WP-351.** Birincil grup IA/24 saat kuralı, tema kapağı, mobil kamp ateşi ve kontrollü stable teslimi bu sırada ilerler.
- **Son WP numarası:** **WP-352** (v49 sonrası seri fix kuyruğu · Hotfix WP-1).
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
- **Son not (2026-07-27 02:20):** WP-351 production 0085 apply + v49 stable release tamamlandı, lane bırakıldı. Kalan iş sahipte: cihaz kabulü.
  - **Kök neden:** production'ın Supabase CLI migration geçmişi boştu (tarihsel migration'lar SQL Editor'den uygulanmış), bu yüzden `db push` 0001'den başlayıp 0010'da düşürülen `study_sessions.group_id` üzerinde patlıyordu. Şema sağlamdı, yalnız geçmiş tablosu boştu.
  - **Çözüm:** dar `repair-baseline-0070` yolu — 0001-0070'i yalnız `applied` işaretler, şemaya DDL göndermez. `migration repair` repo genelinde yasak kalır; sadece bu yol `AllowBaselineRepair` + production + CI + allowlist'li sürüm kapılarından geçer.
  - **Yedek:** sahip kararı ile muaf (`production.backup_requirement: "waived"`). Free plan projesinde PITR/backup yok, geri dönüş yolu olmadan uygulandı. Bir daha backup sorulmayacak. Repo PUBLIC olduğu için CI'da `db dump` alıp artifact'a koymak asla seçenek değil.
  - **Kanıt:** baseline repair [30222267119](https://github.com/manil-max/online-study-room/actions/runs/30222267119) · apply + post-check head 0085 [30222414307](https://github.com/manil-max/online-study-room/actions/runs/30222414307) · release [30222542841](https://github.com/manil-max/online-study-room/actions/runs/30222542841) (android+windows+finalize hepsi yeşil).
  - **Sürüm:** `v49` → `2e19cfb` (WP-352 fix dahil). APK SHA-256 `0628cff960430fb9850eb90f276ce9c6a274d68b96159ef64b15a384de65c935`.
  - **Açık risk:** sahadaki kullanıcılar hâlâ v48 iken production şeması 0085'e çıktı. Eski istemcinin yeni şemayla çökmediği cihazda doğrulanmadı — kabul listesinin ilk maddesi bu.

### Codex Lane
- **Durum:** [~] Aktif
- **Faz/WP:** Faz F2 · WP-351
- **Aşama:** Stable APK aday derlemesi
- **SAHİP yollar:** `.github/workflows/stable-candidate.yml`, `progress.md` (yalnız Codex lane + WP-351 kartı)
- **Ortak/riskli yüzey:** protected `production` CI environment, Android signing ve production build manifesti
- **Dal:** main
- **Başlangıç:** 2026-07-27 00:40 (Europe/Istanbul)
- **Son güncelleme:** 2026-07-27 00:40 (Europe/Istanbul)
- **Not:** Kullanıcı, backup/PITR doğrulaması sürerken imzalı stable APK adayının paralel derlenmesini istedi. Public release ve update bildirimi bu jobun kapsamı dışındadır.

### Codex-2 Lane
- **Durum:** [x] Boşta
- **Faz/WP:** —
- **SAHİP yollar:** —
- **Son not:** WP-340 commit/test ile tamamlandı; fiziksel cihaz regresyonu ortak QA kuyruğunda.

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
| Otomatik doğrulama | `2800484` için CI + Database Gates PASS; yerelde tam paket **910 test**, Windows golden paketi **16 test**, `flutter analyze` temiz |
| l10n audit | **0 bulgu**: WP-335, WP-295 önizleme metinlerini katalogladı; 7 kullanıcı-dışı invariant mesajı dar ve gerekçeli muafiyetle ayrıldı |
| Migration | Repo/local **`0084`** · staging **`0084`** · production etkin şema **`0070`** |
| Beta | **`beta-v4402` yayımlandı**; Android APK + Windows MSIX/ZIP hazır, V3 flag'leri kapalı |
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
| **WP-325** Oturum gününü kayıt anında damgalama | Kod/test + staging tamam | Cihaz/veri eşliği kabulü |
| **WP-326** Grup bölgesi ve gün sınırı zinciri | Kod/test + staging tamam | Beta saat dilimi kabulü |
| **WP-327** Grup bölgesi ve anlık saat farkı | Kod/test + staging tamam | Beta kart/diyalog kabulü |
| **WP-328** Keşif sıralaması + arama/filtre | Kod/test + staging tamam | Android/Windows filtre kabulü |
| **WP-329** Birincil grup | Kod/test + staging tamam | WP-348 revizyonu + iki cihaz primary kabulü |

> `0073→0084` zinciri staging'e terfi etti. Bu kartlar yeniden claim edilmez;
> birincil grubun yeni IA/cooldown talebi ileri migration kullanan **WP-348**'dir.

#### WP-329: Birincil grup 🏠
- **Program/Faz:** Faz E · Grup semantiği · **Durum:** [~] Kod/test + staging tamam; WP-348 revizyonu/cihaz kabulü bekliyor · **Bağımlılık:** WP-326 + WP-328
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
- **Program/Faz:** Faz E2 · WP-329 entegrasyonu · **Ajan:** Codex · **Durum:** [~] Kod/test + staging tamam — cihaz kabulü bekliyor · **Bağımlılık:** WP-329
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
- **Program/Faz:** Faz E2 · Delivery C0 · **Ajan:** Codex · **Durum:** [x] Kod/test + aggregate kanıtı tamam (staging GO) · **Bağımlılık:** Yok
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
- **Kanıt:** `docs/GLOBAL-TIMER-V3-COMPATIBILITY-EVIDENCE.md`; G1–G6/H1–H4 PASS, local/staging/production aggregate `running=0`, `paused=0`; Database Gates `30211293548`/`30211294358` salt-okunur PASS. `flutter analyze` temiz, tam `flutter test` 910 test yeşil (2026-07-26). **Kodda ve remote aggregate'de doğrulandı.**
- **Tuzaklar:** GO yalnız staging V3 terfisi içindir; production migration/flag/stable GO türetmez.
- **Model önerisi:** 🔴 Opus

#### WP-338: Server-derived çoklu grup presence çekirdeği 👥
- **Program/Faz:** Faz E2 · Delivery A backend · **Ajan:** Codex · **Durum:** [~] Kod/test + staging tamam; flag/cihaz kabulü bekliyor · **Bağımlılık:** WP-329; migration sırası WP-328/WP-329 sonrası
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
- **Program/Faz:** Faz E2 · Delivery C backend · **Ajan:** Codex-3 · **Durum:** [~] Kod/test + staging tamam; flag/cihaz kabulü bekliyor · **Bağımlılık:** WP-337 GO + WP-338; migration hattında WP-336/WP-338 sonrası
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
- **Program/Faz:** Faz E2 · Delivery D backend · **Ajan:** Codex-3 · **Durum:** [~] Kod/test + staging tamam; flag/FCM cihaz kabulü bekliyor · **Bağımlılık:** WP-341
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
- **Program/Faz:** Faz E2 · QA/rollout · **Ajan:** — · **Durum:** [~] Staging + beta artefaktı tamam; fiziksel çoklu cihaz/flag rollout bekliyor · **Bağımlılık:** WP-336 + WP-339 + WP-343 + WP-345
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
- **Kanıt/durum:** Staging `0084`, `beta-v4402` Android+Windows release ve otomatik kapılar PASS. ADB listesi boş olduğu için cihaz sonucu yok; V3 flag'leri kapalı tutuldu. **Cihazda doğrulanmalı.**
- **Tuzaklar:** Test bug'ı bu WP'de yamalanmaz; yeni debug WP/beta gerekir. Production GO türetilmez.
- **Model önerisi:** 🔴 Opus

#### WP-347: Grup attribution yapılandırması RLS güvenlik düzeltmesi 🔒
- **Program/Faz:** Faz E2 · release-blocking debug · **Ajan:** Codex · **Durum:** [x] Kod/test + staging terfisi tamam · **Bağımlılık:** WP-336
- **Problem:** `group_progression_attribution_config` doğrudan client yetkileri geri alınmış olsa da RLS kapalı oluşturulmuş; güvenlik denetimi bunu kritik bulgu olarak raporluyor.
- **SAHİP dosyalar (yaz):** `supabase/migrations/0084_group_progression_attribution_config_rls.sql` · `supabase/tests/011_session_group_attribution.test.sql` · `tooling/release/deploy-contract.json` · bu WP kartı.
- **Kapsam dışı:** `0080`i değiştirmek · client policy vermek · timer/notification/widget kodu · production deploy.
- **Kabul:** RLS açık; `anon/authenticated` doğrudan select/insert/update/delete yapamaz; mevcut SECURITY DEFINER trigger/resolver zinciri attribution testinde çalışır; local replay/pgTAP yeşil.
- **Geri alma:** Veri silmeden yeni ileri migration ile yalnız policy/RLS davranışı düzeltilir; `0084` uygulanmışsa geriye dosya değiştirilmez.
- **Kanıt:** Local `0084` replay/246 pgTAP PASS · deploy guard 56 PASS · Database Gates [30211582040](https://github.com/manil-max/online-study-room/actions/runs/30211582040) staging `0073→0084` apply, migration-list ve push post-check PASS. **Kodda ve staging'de doğrulandı; cihazda doğrulanmalı.**

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

### Faz F2 — Stable öncesi seri ürün revizyonu

> **Ürün kararı (2026-07-26):**
>
> - Hesap başına aynı anda **tam olarak bir** birincil grup seçilebilir. Çoklu
>   seçim hiçbir UI/repository/RPC yolunda mümkün değildir.
> - Birincil grup seçimi **Başarımlar** ekranında, kullanıcının katıldığı bütün
>   grupları gösteren tek-seçimli karttan yönetilir.
> - Farklı bir birincil gruba geçiş, son başarılı **açık kullanıcı seçiminden
>   itibaren kayan 24 saat** sonra mümkündür. Takvimde “sonraki 00.00” kuralı
>   kullanılmaz; cihaz saati değil sunucu `now()` değeri otoritedir.
> - Birincil grup; grup görev/hedef/gün-hafta ilerlemesi, grup başarımı ve grup
>   gün sınırı saat dilimini etkiler. **Kişisel XP/kişisel başarımlar, bütün
>   gruplardaki canlı presence, direct grup bildirimleri ve timer-sync sinyali
>   bundan filtrelenmez.**
> - Seri sıra zorunludur: **WP-348 → WP-349 → WP-350 → WP-351**. Aynı anda iki
>   worker açılmaz; `progress.md`, l10n/generated, golden/release metadata ve
>   migration yüzeyleri sıcak olduğu için paralellik kazanım değil risk üretir.

#### WP-348: Başarımlar içinde tek birincil grup + kayan 24 saat kuralı 🏠
- **Program/Faz:** Faz E/F2 · WP-329/WP-336 ürün revizyonu
- **Ajan:** —
- **Durum:** [~] Kod/test tamamlandı; staging yapılandırması ve cihaz kabulü bekliyor
- **Bağımlılık:** WP-329 + WP-336; staging head `0084`.
- **Problem:** Birincil grup seçimi bugün grup detayında dağınık bir eylemdir;
  kullanıcı katıldığı grupları tek yerde kıyaslayamaz. Mevcut server sözleşmesi
  revision yarışı çözüyor ancak seçimler arasında 24 saatlik ürün kuralı yoktur.
  “Birden fazla grupta birincil” ifadesi ayrıca yanlış anlaşılmaya açıktır.
- **Ürün/tasarım sözleşmesi:**
  - Başarımlar ekranının kendi-profil görünümünde, taç/başarım kataloğundan önce
    **“Birincil grup”** kartı yer alır.
  - Kart bütün aktif üyelikleri avatar/ad/bölge ile listeler; radio/check
    davranışıyla yalnız bir satır seçilebilir. Mevcut birincil açıkça işaretlenir.
  - Yardım metni kısa ve dürüsttür: “Grup hedeflerin, grup başarımların ve grup
    günün bu gruba yazılır.” Kişisel XP/başarı/presence için yanlış vaat yoktur.
  - Grup detayındaki **“Birincil yap”** yazma eylemi kaldırılır; aynı tercihi
    değiştiren ikinci bir yüzey bırakılmaz.
  - Kilitliyken diğer gruplar disabled olur; kalan süre ve kesin açılma zamanı
    gösterilir. İlk seçim, aynı grubu yeniden seçme ve otomatik tek-grup
    uzlaştırması ayrı davranır.
- **Kapsam dışı:** Çoklu primary · kişisel başarı motoru/XP ekonomisi · geçmiş
  session retro-attribution · presence/push filtresi · timer UX/refactor ·
  notification/widget/PendingIntent değişikliği.
- **SAHİP dosyalar (yaz):**
  - yeni `supabase/migrations/0085_primary_group_change_cooldown.sql`
  - `supabase/tests/010_primary_group_preference.test.sql` ve deploy/contract testleri
  - `app/lib/data/repositories/group_repository.dart`
  - `app/lib/data/repositories/supabase/supabase_group_repository.dart`
  - `app/lib/data/repositories/in_memory/in_memory_group_repository.dart`
  - `app/lib/data/providers/group_providers.dart`
  - `app/lib/features/profile/achievements_screen.dart`
  - `app/lib/features/profile/social_profile_screen.dart`
  - yeni `app/lib/features/profile/widgets/primary_group_selector_card.dart`
  - `app/lib/features/classroom/widgets/class_detail_screen.dart` (yalnız eski seçim CTA'sını kaldırma)
  - `app/lib/l10n/app_{en,tr,de,ar}.arb`, üretilen l10n ve ilgili Dart/widget testleri
- **DOKUNMA (oku, değiştirme):**
  - uygulanmış `0079_primary_group_preference.sql` ve `0080_session_group_attribution.sql`
  - achievement evaluator/XP ledger · presence/global timer/push kodu
  - `study_providers.dart` · Android native timer · bildirim/widget kaynakları
- **Adımlar:**
  - [x] `0085` ile server-authoritative cooldown read-modelini ekle; ilk açık
    seçim serbest, farklı hedefe sonraki açık seçim `last_explicit_change_at +
    interval '24 hours'` öncesinde reddedilsin.
  - [x] Aynı grubu yeniden seçmeyi idempotent no-op yap; cooldown/revision
    tüketmesin. `automatic_single` ve `membership_reconcile` kullanıcı cooldown'ı
    başlatmasın.
  - [x] RPC aynı kullanıcı advisory lock'u, üyelik doğrulaması ve expected
    revision altında `next_change_allowed_at` döndürsün; istemci saati karar
    vermesin.
  - [x] DTO/repository/provider çiftlerini yeni zamana taşı; Supabase ve
    InMemory davranışı aynı olsun, eski/null kayıtlar güvenli parse edilsin.
  - [x] Başarımlar kartını empty/loading/error/offline/stale-revision ve 1–8
    grup durumlarıyla uygula; seçim öncesi etkiyi açıklayan kısa onay göster.
  - [x] Grup detayındaki mutasyon CTA'sını kaldır; aktif timer sırasında seçim
    yerel timer/bildirim/widget'ı restart etmesin, yeni tercih yalnız sonraki
    session attribution'ına girsin.
- **Veri/Migration etkisi:** `0085` yalnız ileri/additive migration'dır; `0079`
  değiştirilmez. Son açık seçim zamanı mevcut append-only history'den
  deterministik backfill edilir; otomatik nedenler cooldown sayılmaz. Geri alma:
  veri silmeden RPC policy'sini ileri migration ile gevşetmek ve istemcide kartı
  salt-okunur yapmak.
- **Ortam/Deploy:** Local full replay + pgTAP/RLS abuse → staging `0084→0085`;
  production terfisi yalnız WP-351'de.
- **RLS/Güvenlik:** Preference/history yalnız hesap sahibi tarafından okunur;
  client zaman/revision/reason yazamaz. Üye olunmayan grup ve başka kullanıcı
  tercihi RPC/RLS ile reddedilir.
- **Edge-case'ler:** 0 grup · tek grup otomatik primary · çok grup/seçim yok ·
  ilk açık seçim · aynı gruba no-op · 23:59/00:00 · DST/saat dilimi değişimi ·
  cihaz saatini ileri alma · iki cihaz eşzamanlı seçim · offline stale ekran ·
  primary gruptan çıkma/silinme · cooldown sırasında zorunlu uzlaşma · aktif timer.
- **Kabul (ölçülebilir):**
  - DB'de kullanıcı başına primary satırı **≤1**, UI'da seçili grup **≤1**.
  - İlk açık seçim başarılı; farklı ikinci seçim `<24 saat`te server tarafından
    reddedilir, `≥24 saat`te başarılıdır; 00.00 geçmek tek başına kilidi açmaz.
  - Aynı hedef no-op'tur; revision/history/cooldown artışı **0**.
  - İki cihaz yarışında yalnız geçerli revision kazanır; eski cihaz güncel
    tercihi geri alamaz ve her iki cihaz Realtime/refresh sonrası aynı grubu gösterir.
  - Primary değişiminde çalışan kronometre, bildirim ve widget süre kaybı/reset
    olmadan devam eder; kapanan session başlangıç anındaki primary'ye, sonraki
    session yeni primary'ye yazılır.
  - 360 dp Android ve Windows'ta 1–8 grup listesi taşmasız; satır dokunma hedefi
    ≥48 dp, kritik metin kontrastı WCAG AA.
- **Tuzaklar:** Cooldown'ı yalnız Flutter'da kontrol etmek kolay aşılır; `changed_at`
  yerine cihaz zamanı kullanmak saat manipülasyonu üretir; otomatik membership
  reconciliation'ı açık seçim sanmak kullanıcıyı haksız kilitler.
- **Model önerisi:** 🔴 Opus

#### WP-349: Forest Cabin tema kapağını gerçek paletle hizala 🎨
- **Program/Faz:** Tema · Faz F2 görsel doğruluk
- **Ajan:** —
- **Durum:** [~] Kod/test tamamlandı; cihaz kabulü bekliyor
- **Bağımlılık:** WP-348 seri kapısı; teknik olarak bağımsızdır.
- **Problem:** `forest_study` temasının gerçek baskın scaffold/surface rengi
  yeşildir; hazır tema kartı yalnız kahverengi `primary` ve sarı `accent`
  noktalarını gösterdiği için seçilince bambaşka tema açılmış gibi görünür.
- **Kapsam dışı:** Forest Cabin'in çalışan tema renklerini değiştirmek · tema
  motoru/kalıcılık · özel tema sihirbazı · yeni tema eklemek.
- **SAHİP dosyalar (yaz):**
  - `app/lib/features/profile/appearance_screen.dart`
  - hazır tema kartı/swatch widget testleri ve gerekli Windows golden baseline'ı
- **DOKUNMA (oku, değiştirme):**
  - `app/lib/core/theme/theme_presets.dart` içindeki `forest_study` runtime token'ları
  - `app/lib/core/theme/app_theme.dart` · `theme_settings.dart` · l10n
- **Adımlar:**
  - [x] Hazır tema kapağını yalnız primary/accent çifti yerine gerçek
    scaffold/surface alanı baskın, primary/accent küçük vurgu olacak biçimde çiz.
  - [x] Çözümü bütün `ThemePreset` kartlarına semantik tokenlardan uygula;
    `forest_study` için ID'ye özel hard-code ekleme.
  - [x] Selected border/check kontrastını hem açık hem koyu presetlerde doğrula.
- **Veri/Migration etkisi:** Yok. Geri alma tek widget/golden geri dönüşüdür.
- **Ortam/Deploy:** Local; WP-351 stable artefaktına girer.
- **RLS/Güvenlik:** Yok.
- **Edge-case'ler:** açık/koyu tema · çok yakın scaffold/surface tonları · 360 dp
  iki sütun · uzun TR/EN tema adı · seçili/seçili değil · high contrast.
- **Kabul (ölçülebilir):**
  - Forest Cabin kartında yeşil scaffold/surface görsel alanın çoğunluğunu,
    kahverengi ve sarı vurgu alanını oluşturur; tıklandığında açılan temanın
    baskın rengi kapakla eşleşir.
  - Diğer 14 preset aynı token tabanlı önizleme sözleşmesini kullanır.
  - Tema seçme/kalıcılık davranışı değişmez; 360 dp'te overflow 0, kart dokunma
    hedefi ≥48 dp; Windows golden testi birebir geçer.
- **Tuzaklar:** Primary rengini yeşile çevirerek problemi “çözmek” çalışan temayı
  değiştirir; istenen kapak doğruluğudur.
- **Model önerisi:** 🔵 Sonnet

#### WP-350: Telefon için kamp ateşi kompozisyon revizyonu 🔥
- **Program/Faz:** Kamp ateşi · Faz F2 mobil görsel revizyon
- **Ajan:** —
- **Durum:** [~] Kod/test tamamlandı; cihaz kabulü bekliyor
- **Bağımlılık:** WP-349 seri/golden kapısı.
- **Problem:** Masaüstü için ayarlanan perspektif telefonda aynı sabitlerle
  çalışınca ateş fazla yukarıda, hayvanlar büyük ve ateşe yapışık, 8 kişilik arka
  sıra havada, orman ağaçları kalabalık ve alt ışık lekesi geniş görünüyor.
- **Tasarım sözleşmesi:**
  - “Start studying / Çalışmaya başla” sahne üstü metni tamamen kaldırılır.
  - Yalnız telefon sınıfında ateş aşağı alınır, oturma halkası genişletilir,
    hayvan/etiket ölçeği küçültülür ve ön/arka derinlik korunur.
  - Telefon sınıfında arka plan ağaç katmanı geçici olarak çizilmez; gökyüzü,
    ay/güneş, yıldızlar, zemin/açıklık korunur.
  - Ateşin alt sıcak aydınlatma/glow yarıçapı ve opaklığı telefonda azaltılır.
  - Windows/masaüstü kompozisyonu ve mevcut native timer/bildirim/widget
    davranışı birebir korunur.
- **Kapsam dışı:** Yeni hayvan/poz/asset üretmek · presence semantiği · kamp
  ateşinden timer başlatmak · masaüstü yerleşimini yeniden tasarlamak ·
  notification/widget/native timer.
- **SAHİP dosyalar (yaz):**
  - `app/lib/features/classroom/widgets/campfire_scene.dart`
  - `app/lib/features/classroom/widgets/camp_critter.dart`
  - gerekirse yalnız adaptif geometri için `app/lib/features/classroom/widgets/campfire_layout.dart`
  - `app/test/features/campfire_scene_test.dart`
  - `app/test/features/campfire_sky_golden_test.dart` ve yeni mobil 1/4/8 kişi golden'ları
- **DOKUNMA (oku, değiştirme):**
  - `app/lib/data/providers/study_providers.dart`
  - presence/global timer repository/provider'ları
  - `app/lib/core/notifications/**`
  - `app/android/**` bildirim/widget/timer kaynakları
  - kamp ateşi PNG assetleri ve `app/pubspec.yaml`
- **Adımlar:**
  - [x] Platform + logical shortest-side tabanlı test edilebilir telefon viewport
    sınıfı çıkar; dar Windows penceresini yanlışlıkla mobil kompozisyona sokma.
  - [x] Telefon geometri profilinde fire baseline'ı aşağı taşı, ring `rx/ry`
    değerlerini güvenli sınıra kadar büyüt ve critter scale aralığını küçült.
  - [x] 1–8 yerleşimde arka sıranın zemin/ufuk ilişkisini koru; isim/süre
    etiketlerini sahne sınırında clamp et.
  - [x] `GroundedForestPainter`a telefon için ağaçları kapatan açık parametre ekle;
    desktop default'u değişmesin.
  - [x] Glow radius/alpha'yı viewport profiline bağla; alev/kor/taş okunurluğu
    kaybolmadan alt lekeyi küçült.
  - [x] Sıfır çalışan durumundaki metni ve test beklentisini kaldır; çalışan
    sayısı rozeti kalır.
- **Veri/Migration etkisi:** Yok. Geri alma adaptif profil/golden commit'inin
  geri çevrilmesidir.
- **Ortam/Deploy:** Local widget/golden/profile → WP-351 stable.
- **RLS/Güvenlik:** Yok; kullanıcı verisi veya görünürlük kuralı değişmez.
- **Edge-case'ler:** 0/1/4/8 üye · hepsi çalışan/hepsi offline · çok uzun ad ·
  360×640 telefon · büyük yazı ölçeği · landscape telefon · Android tablet ·
  dar Windows pencere · reduce-motion · gündüz/geçiş/gece.
- **Kabul (ölçülebilir):**
  - Telefon 360×640 golden'larında 1/4/8 hayvan ve etiket sahne sınırından en az
    8 dp içeride; havada kalan/ateşle fiziksel çakışan gövde **0**.
  - Telefon profilinde critter kutuları mevcut tabana göre yaklaşık %20–30 daha
    küçük; halka yatay açıklığı yaklaşık %15–25 daha geniş ve ateş merkezi
    sahnenin alt yarısına taşınmış görünür.
  - Telefon ağaç çizimi **0**; “Çalışmaya başla/Start studying” metni **0**;
    glow sahne kısa kenarının yaklaşık %22'sini aşmaz.
  - Masaüstü day/transition/night golden'ları istenmeyen piksel farkı olmadan
    korunur; yeni Android mobil golden'ları strict geçer.
  - Android profile sahnede `p95 ≤16.7 ms`, jank `≤%1`; reduce-motion'da
    sonsuz dekoratif animasyon çalışmaz.
- **Tuzaklar:** Yalnız `scale` küçültmek label/marshmallow anchor'larını bozar;
  width tabanlı breakpoint dar Windows'u etkiler; ağaçları tüm platformlardan
  kaldırmak kabul edilen PC görünümünü bozar.
- **Model önerisi:** 🟣 Pro

#### WP-351: Production migration terfisi + doğrudan stable teslim 🚀
- **Program/Faz:** Release/Ops · Faz F2 kapanış
- **Ajan:** Codex (2026-07-27 preflight)
- **Durum:** [~] Bloklu — staging `0085` apply ve production `0085` dry-run PASS; doğrulanmış production backup/PITR kaydı olmadan apply/release yapılmaz
- **Bağımlılık:** WP-348 → WP-349 → WP-350; clean `main`; staging `0085`.
- **Problem:** Son stable'dan beri grup/keşif/primary/V3 altyapısı ve görsel
  revizyonlar birikti. Proje sahibi mağaza öncesi 5 kişilik ekipte testi stable
  kanalında yapmak ve sorun çıkarsa benzersiz hotfix çıkarmak istiyor.
- **Sahip risk kabulü:** Proje sahibi **2026-07-26** tarihinde bu somut teslim
  için beta soak/önce cihaz kabulü kapısını atlayıp doğrudan stable istemiştir.
  Bu istisna otomatik test, staging migration, production backup/dry-run,
  post-check, kanal/backend fail-closed ve rollback hazırlığını kaldırmaz.
- **Kapsam dışı:** Bu WP içinde feature bug'ı düzeltmek · Play/Store submission ·
  V3 global timer flag'lerini açmak · mevcut tag/build kimliğini yeniden kullanmak.
- **SAHİP dosyalar (yaz):**
  - `CHANGELOG.md`
  - `app/assets/release_notes.json`
  - `app/pubspec.yaml`
  - `tooling/release/deploy-contract.json` (yalnız korumalı exact head/SHA penceresi)
  - release preflight/manifest ve redacted deploy/acceptance kanıtları
  - `progress.md` içindeki yalnız WP-351/release gerçeği
- **DOKUNMA (oku, değiştirme):** WP-348/349/350 feature kodu · uygulanmış
  migration'lar · Android signing key · notification/widget/native timer kodu.
- **Adımlar:**
  - [ ] Üç WP'nin ayrık commitlerini, temiz worktree'yi, secret dışı diff'i ve
    bir daha kullanılmamış next stable version/build kimliğini doğrula.
  - [ ] `flutter analyze`, non-golden tam test, Windows strict golden, release
    manifest gate, local full migration replay/pgTAP/RLS/deploy guard çalıştır.
  - [x] Staging'i `0084→0085` protected dry-run/apply/post-check ile terfi et;
    primary cooldown/iki hesap/RLS smoke kanıtını al.
  - [ ] Production `0070→0085` zinciri için hedef project-ref, migration-list,
    salt-okunur session/XP/reward/RLS/cron baseline, backup ve protected dry-run
    kanıtını üret; exact SHA/head GO penceresi dışında apply etme.
  - [ ] Production terfisinden sonra aynı invariantları post-check et. V3
    presence/global timer/timer-sync rollout flag'lerini **kapalı** tut; mevcut
    kronometre/bildirim/widget sıcak yolunu stable'da değiştirme.
  - [ ] Android stable APK + Windows stable MSIX/ZIP artefaktlarını production
    backend manifestiyle üret, benzersiz stable tag/release yayımla ve SHA-256
    değerlerini kaydet.
  - [ ] ADB'de yetkili cihaz varsa veriyi silmeden `install -r` ile güncelle;
    cihaz yoksa kurulum/testi yapılmış gibi yazma, kullanıcıya APK bağlantısı ve
    aşağıdaki 5 hesaplık kabul listesini ver.
  - [ ] Yayın sonrası hata P0/P1 ise rollout/flag kapalı kalır; aynı tag
    değiştirilmez, ayrı debug WP + bir sonraki benzersiz stable hotfix açılır.
- **Veri/Migration etkisi:** Staging `0085`; production tek kanonik zincirle
  `0070→0085`. Remote migration immutable. Rollback şema düşürme değil:
  rollout flag kapalı, additive tablolar korunur, gerekirse ileri migration +
  benzersiz hotfix istemci.
- **Ortam/Deploy:** Local → staging → production stable. Kullanıcının bu karttaki
  açık doğrudan-stable emri somut GO kaydıdır; hedef/SHA/head uyuşmazlığında
  fail-closed durulur.
- **RLS/Güvenlik:** Cross-account primary/preference/history, discovery,
  presence/command/result ve attribution abuse testleri PASS; kanıtta secret,
  UUID/e-posta veya service-role yok.
- **Stable sonrası 5 hesaplık kabul listesi:**
  - [ ] Başarımlar ekranında 0/1/çok grup durumu; yalnız tek primary seçimi.
  - [ ] İlk seçim, aynı gruba no-op, `<24 saat` red ve iki cihaz aynı tercih.
  - [ ] Primary değişirken çalışan timer + bildirim + ana ekran widget sürekliliği.
  - [ ] Yeni session yalnız başlangıçtaki primary grup ilerlemesine yazılır;
    secondary katkı 0, kişisel XP/süre korunur.
  - [ ] Forest Cabin kapağı yeşil ağırlıklı; seçilen tema kapakla eşleşir.
  - [ ] Telefon kamp ateşinde 1/4/8 kişi; metin yok, ateş aşağıda, hayvanlar
    küçük/uzak, halka geniş, ağaç yok, glow küçük.
  - [ ] Grup konumu/saat farkı, keşif arama+bölge+boş kontenjan ve 8 kişi sınırı.
  - [ ] App/widget/bildirimden start-stop, app kapalı/yeniden açılış ve 8 saat
    drift regresyonu.
- **Kabul (ölçülebilir):** Production post-check invariant kaybı 0 · Android ve
  Windows artefaktları aynı stable tag/SHA/backend/head'i taşır · channel/backend
  mismatch 0 · migration head `0085` · release assetleri ve digestleri mevcut ·
  timer/widget/notification otomatik regresyonu 0 · fiziksel test sonucu yalnız
  gerçek cihaz kanıtıyla PASS olarak yazılır.
- **Tuzaklar:** 5 kişilik/pre-market olmak veri kaybı veya timer regresyonunu
  zararsız yapmaz; bu yüzden soak atlanabilse de backup/dry-run/post-check ve
  V3 flag-off kalkanı atlanmaz.
- **Model önerisi:** 🔴 Opus

#### Seri yürütme ve çakışma kararı

```text
WP-348 (migration + Başarımlar primary IA)
  → WP-349 (tema kapağı)
    → WP-350 (mobil kamp ateşi)
      → WP-351 (staging/production/stable)
```

> ⚠️ **Paralel worker açma.** WP-348 migration+l10n/profile, WP-349 theme
> golden, WP-350 campfire golden ve WP-351 release metadata/progress sıcak
> yüzeylerini paylaşıyor. Her WP ayrı commit + yeşil kapı ile sıradakine devreder.

---

## PLAN 2 — MAĞAZA HAZIRLIĞI

> 🧾 **WP kartları bu fazlar başlarken açılır** (güncel son numara WP-351;
> yeni kartlar WP-352'den devam eder).
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
- **Migration drift.** Repo/local/staging `0084`, production etkin şema `0070`. WP-348 yeni `0085`i local→staging'e taşır; WP-351 production `0070→0085` terfisini backup + protected dry-run + post-check ile yapar.
- **V3 migration sırası.** WP-328 → WP-329 → WP-336 → WP-338 → WP-341 → WP-344 zinciri local/staging `0084`te tamamlandı. Yeni tek migration WP-348'in `0085`idir; production terfisi WP-351 dışında yapılmaz.
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
| **WP-349** Forest Cabin tema kapağı | Windows + Android | Hazır tema kartı baskın scaffold/surface paletini doğru yansıtıyor; açık/koyu preset seçimi, 360 dp iki sütun ve 48 dp dokunma hedefi gerçek cihazda doğrulanmalı. **Cihazda doğrulanmalı.** |
| **WP-350** Telefon kamp ateşi | Android + Windows | Telefonda 1/4/8 kişi, düşük ateş, geniş halka, küçük hayvanlar/etiketler, ağaçsız arka plan ve küçük glow; masaüstü kompozisyonu korunuyor. Android profile `p95 ≤16.7 ms`, jank `≤%1` cihazda doğrulanmalı. **Cihazda doğrulanmalı.** |
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
| **WP-325** Oturum günü damgası | Staging `0084` | Öncesi/sonrası gün toplamı birebir; bölge değişimi geçmişi oynatmıyor; indeks planı kanıtlı |
| **WP-326** Grup saat dilimi | Staging `0084` + beta | IANA adı, New York yerel gece yarısı, cihaz fallback'i ve DST davranışı doğru |
| **WP-327** Grup bölgesi + saat farkı | Staging `0084` + beta | Açık grup kartı/bilgi ekranı, aynı bölgede farkın gizlenmesi, New York ve +5:30 farklarının doğruluğu |
| **WP-328** Keşif sıralaması + arama/filtre | Staging `0084` + Android + Windows | Kullanıcı bölgesine göre sıralama, bölge filtresi, boş kontenjan filtresi ve sayfalama gerçek cihazda doğrulanmalı. **Cihazda doğrulanmalı.** |
| **WP-329/348** Birincil grup | Staging + iki Android cihaz | WP-348 kod/test tamam; staging terminal yapılandırması eksik olduğundan remote dry-run/apply bekliyor. Ardından tek seçim, kayan 24 saat server kuralı, iki cihaz stale-revision reddi, üyelikten çıkış/silmede uzlaşma ve timer/bildirim/widget regresyonu doğrulanmalı. **Cihazda doğrulanmalı.** |
| **WP-336** Tek-grup session attribution | Staging `0084` + iki Android cihaz | Yeni session yalnız başlangıçtaki primary gruba yazılır; secondary day/week/achievement katkısı ve cron geri yazımı 0, kişisel süre/XP korunur. **Cihazda doğrulanmalı.** |
| **WP-343** Foreground mirror + remote stop | Staging + iki Android cihaz | Aynı hesapta foreground start/stop p95≤2 sn; ek session/XP 0; eski stop yeni yerel run'ı kesmez; bildirim/widget regresyonu 0. **Cihazda doğrulanmalı.** |
| **WP-345** Timer-sync signal + app-open reconcile | Staging FCM + Android lifecycle | Data-only sinyal p95≤10 sn; açılış reconcile p95≤2 sn; terminated/doze/logout/force-stop sonrasında payload state uygulamaz, snapshot doğru state'i getirir. **Cihazda doğrulanmalı.** |

**Ortam sırası:** staging `0084`tedir. WP-348 `0085`i önce local, sonra
staging'e taşır. Production `0070→0085` terfisi yalnız WP-351'in backup,
protected dry-run, exact SHA/head GO ve post-check adımlarıyla yapılır.

## 🗄️ Tarihsel kayıt

Tamamlanan ayrıntılı WP kartları ve eski beta dalga planı
[`docs/archive/progress-tarihsel-2026-07.md`](docs/archive/progress-tarihsel-2026-07.md)
ile git geçmişindedir. Canlı dosyada tekrar tutulmaz.

- **WP-300** enlem/boylam yaklaşımı iptal edildi; yerini konum izni istemeyen **WP-326** aldı.
- **WP-301** eski `metric_day` backfill yaklaşımı iptal edildi; yerini kayıt anı damgası **WP-325** aldı.
- Eski iki-beta/dalga sırası tarihsel kayıttır; güncel sıra Yol Haritası + Aktif Çalışma Kaydı'dır.

## 🔧 Seri Fix Kuyruğu

> **Sahip kararı (2026-07-27, revize):** Kuyruk v49 *sonrasına* bırakılmıyor.
> v49 henüz yayımlanmadığı için **Hotfix WP-1 · WP-352 v49 kapsamına alındı** —
> sonradan ayrı hotfix turu açmamak için. Sıradaki maddeler v49 çıktıktan sonra
> değerlendirilir. `Hotfix WP-n` etiketi kuyruk sırasıdır, kanonik numara her
> zaman yanında verilir ve `Son WP numarası` ile birlikte ilerler.

### Hotfix WP-1 · WP-352 — Birincil grup seçilmemişse görünür uyarı 🏠
- **Program/Faz:** Faz F2 devamı · WP-329/WP-336/WP-348 ürün açığı
- **Ajan:** Claude
- **Durum:** [~] Kod/test tamamlandı; v49 kapsamında, cihaz kabulü bekliyor
- **Bağımlılık:** Yok. WP-348 birincil grup kartı yerinde
  (`social_profile_screen.dart` kendi-profil/Başarımlar görünümü).
- **Problem (2026-07-27 sahip gözlemi + kod doğrulaması):** Çoklu üyelikte açık
  seçim yoksa `reconcile_user_primary_group` bilinçli olarak
  `primary_group_id = NULL` bırakıyor
  ([`0079_primary_group_preference.sql:126-128`](supabase/migrations/0079_primary_group_preference.sql:126)).
  Cutover sonrası her oturuma `group_id = NULL` attribution satırı yazılıyor
  ([`0080_session_group_attribution.sql:50-84`](supabase/migrations/0080_session_group_attribution.sql:50))
  ve `groups_for_session_progression` `a.group_id is not null` filtresi yüzünden
  **hiçbir grup döndürmüyor** ([`0080:127-155`](supabase/migrations/0080_session_group_attribution.sql:127)).
  Sonuç: grup başarımı, grup görev/hedef ve grup gün-hafta ilerlemesi sessizce
  durur. Grup liderlik tablosu ham `study_sessions` topladığı için
  ([`0040_group_contribution_breakdown.sql:8`](supabase/migrations/0040_group_contribution_breakdown.sql:8))
  kullanıcı **UI'da normal görünür** — kaybın hiçbir işareti yok.
  `PrimaryGroupSelectorCard` bugün hiç uyarı göstermiyor; `primaryGroupNotSelected`,
  `primaryGroupCurrent` ve `primaryGroupOther` l10n anahtarları **hiçbir kod
  yolundan çağrılmıyor** (ölü string).
- **Etki alanı:** Yalnız 0079 kurulurken zaten 2+ grupta olan hesaplar (bugün
  sahip + bir hesap). Yeni kullanıcı ilk gruba katıldığında `automatic_single`
  ile otomatik atanır ve ikinci gruba katılmak mevcut birincili bozmaz
  ([`0079:122-124`](supabase/migrations/0079_primary_group_preference.sql:122)).
  Ayrıca 3+ gruptayken birincil gruptan ayrılmak veya birincil grubun silinmesi
  aynı NULL durumuna düşürür — uyarı bu yolları da kapsar.
- **Yapılan:**
  - `primaryGroupSelectionMissingProvider` (`group_providers.dart`): üyelik var
    + `primaryGroupId == null` → `true`. Yükleme/hata durumunda `false`; olmayan
    bir kayıp ilan edilmez.
  - `PrimaryGroupSelectorCard` içinde `errorContainer` renkli uyarı bloğu
    (`ValueKey('primary-group-missing-warning')`). Metin mevcut
    `primaryGroupNotSelected` anahtarından okunur — **yeni string yazılmadı**,
    WP-348'den kalan ölü anahtar bağlandı. Uyarı seçimi engellemez.
  - Mobil kabukta Profil sekmesine nokta (`home_shell.dart`
    `_profileTabIcon`). Bekleyen ödül sayısı varsa mevcut sayı rozeti korunur;
    iki sinyal aynı sekmede yarışmaz.
  - `app/test/features/profile/primary_group_missing_warning_test.dart`:
    3 widget + 4 provider senaryosu.
- **Kapsam dışı:** Migration, RPC, cooldown kuralı, otomatik birincil atama,
  yeni l10n anahtarı.
- **Bilerek yapılmadı — masaüstü nokta.** `DesktopNavigationPane` bugün hiç
  badge altyapısı taşımıyor (`DesktopNavItem` yalnız `IconData`); bekleyen ödül
  rozeti de masaüstünde yok. Rozet eklemek paylaşılan gezinti widget'ının
  sözleşmesini değiştirir ve v49 teslimi için gereksiz risktir. Masaüstünde
  uyarı yüzeyi kartın kendisidir. Rozet istenirse ayrı kart açılır.
- 🔴 **Kapanan karar (sahip, 2026-07-27): geçmiş yetim oturumlar telafi
  edilmeyecek.** Attribution `after insert` + `on conflict (session_id) do
  nothing` olduğu için
  ([`0080:86-89`](supabase/migrations/0080_session_group_attribution.sql:86))
  `primary_group_id` NULL'ken yazılmış oturumlar seçim sonrası da hiçbir grup
  projeksiyonuna girmez. Bu kabul edildi; backfill/yeniden atama WP'si
  **açılmayacak**. Bu kart yalnız bundan sonrasını korur.
- **Sahip yollar:** `app/lib/features/profile/widgets/primary_group_selector_card.dart`,
  `app/lib/data/providers/group_providers.dart`,
  `app/lib/core/navigation/home_shell.dart`,
  `app/test/features/profile/primary_group_missing_warning_test.dart`,
  `progress.md` (yalnız bu kart).
- **Ortak/riskli yüzey:** `home_shell.dart` paylaşılan gezinti yüzeyidir; nokta
  dışında hiçbir gezinti davranışı değiştirilmedi. Mevcut bekleyen-ödül rozeti
  regresyon testi (`widget_test.dart`) yeşil kaldı.
- **Kabul (DoD):** ✅ 7/7 yeni test yeşil · ✅ `flutter analyze` temiz (0 sorun) ·
  ✅ tam paket 926 test, tek hata `campfire_sky_golden_test.dart` "kamp telefonu
  golden · 8 kişi" ve o **temiz HEAD'de de patlıyor** (bu WP'den bağımsız,
  mevcut sorun) · ⏳ cihaz kabulü: 2 gruplu hesapta uyarı + nokta görülüyor,
  seçim sonrası ikisi de kayboluyor.

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

1. **WP-348** — Başarımlar içinde tek primary + server-authoritative kayan 24 saat.
2. **WP-349** — Forest Cabin tema kapağı gerçek palet önizlemesi.
3. **WP-350** — Telefon kamp ateşi kompozisyonu.
4. **WP-351** — production `0070→0085` + doğrudan stable release.

Bu dört WP **yalnız seri** verilir; bir worker commit/test/lanesini kapatmadan
sonraki başlamaz. WP-346 fiziksel V3 çoklu cihaz/flag rollout kabulü olarak parkta
kalır; stable WP-351 V3 flag'lerini açmaz.

`Test için bekleyenler` tablosundaki hiçbir kayıt yeniden worker'a verilmez.

> Her worker önce Aktif Çalışma Kaydı'nı okur, kendi lane'ini claim eder ve SAHİP yolları çakışıyorsa başlamaz. Production/stable hiçbir WP'nin örtük parçası değildir.
