# Başarım Canlı İlerleme + Topla-Ödül + Ölü Başarı Fix + Günlük Görev + Grup PP — PLAN

> Kaynak: kullanıcı isteği 2026-07-19 (Minik Kuş). Planlayıcı: Claude.
> Kanon kurallar `.agents/AGENTS.md`, program `docs/KALITE-PROGRAMI.md`, format `.agents/skills/planner/SKILL.md`.
> **Kod yok — yalnız plan.** Worker'lar bu karttan claim eder. Migration numaraları claim anında `progress.md` "Proje Gerçekleri"nden **yeniden teyit edilir** (yerelde en yüksek `0046`).

## Bağlam ve mevcut durum (koda karşı doğrulandı)

- **Başarı motoru** server-authoritative: `_achievement_metrics` + `process_achievement_event` (son sürüm `0033`); istemci XP yazmaz, yalnız olay tetikler. Ledger `xp_ledger` append-only, `event_key` UNIQUE (idempotent).
- **Canlı ilerleme temel hâli ZATEN VAR:** `achievement_showcase.dart` `_CatalogTile` kilitli/ilerleyen başarıda `LinearProgressIndicator` + `$progress / $need` gösteriyor. Yani #1 sıfırdan değil; eksik olan: (a) açılmış ama sonraki kademeye ilerlemenin netliği, (b) canlı streak ("7/10, kaçırınca 0"), (c) ölü başarılarda progress hep 0, (d) claim/topla akışı, (e) profil dışı bildirim, (f) "az kaldı" yüzeyi.
- **Ölü başarılar (server'da `then 0`, asla kazanılamaz):** `alpha_wolf`, `campfire_hours`, `locomotive`, `secret_break_enemy` — `0025/0027/0033` hepsinde sabit sıfır.
  - **Retroaktif hesaplanabilirlik:** `alpha_wolf` (grup gün birincisi) → `study_sessions` × `group_members` gün bazında max toplam sahibinden türetilebilir ✓. `campfire_hours` (≥3 kişi aktifken saat) → grup üyelerinin oturum zaman-çakışmasından türetilebilir ✓. `locomotive` (ilk oturan, ardından başlayanlar) → grup içi oturum başlangıç zamanlarından türetilebilir ✓. `secret_break_enemy` → koşul tanımı yok → **ürün kararı**.
- **Kusursuz Ay** = bir takvim ayında ≥28 gün günlük hedef tutturma (`achievement_ledger_engine.dart:436`). Açıklama metni bunu anlatmıyor → netleştir.
- **Görevler** şu an cihazda (`SharedPreferences`, `user_tasks_v2`); model `user_task.dart` "Tekrar yok" diyor. Repo katmanı adı `SupabaseUserTaskRepository` ama prefs'e yazıyor (yanıltıcı). Bulut + günlük tekrar bunun üstüne eklenecek.
- **Grup PP yok:** `groups` tablosunda `avatar_url` **yok** (yalnız `profiles.avatar_url` var, bucket `avatars` — `0002`). Grup için yeni kolon + bucket + admin-yazma RLS gerekir.

## Ürün kararları

1. **Claim modeli — KARAR: C (gerçek toplama).** ✅ 2026-07-19 onaylandı. Eşik geçilince "pending" (XP profile'a yazılmaz); kullanıcı dokununca `claim` RPC XP'yi ledger'a bankalar (animasyonla görünür artış). İlerleme claim'den bağımsız devam eder (battle-pass). Saat başı 50 XP ambient/otomatik kalır.
2. **`secret_break_enemy` koşulu ne olsun?** (AÇIK) — ör. "X dk molasız oturum" / "mola bildirimini Y kez görmezden gel". Tanımlanmazsa bu gizli başarı ölü kalır veya kaldırılır.
3. **Ölü başarıların retroaktif dağıtımı:** (AÇIK, öneri: evet) geçmiş veriden hesaplanınca kullanıcılara toplu pending ödül düşer (kullanıcı 6 günlük Alfa Kurt'unu geri alır). Hayır denirse yalnız ileriye dönük.

---

# İŞ PAKETLERİ

> 3 bağımsız hat: **A) Başarım** (büyük program, kendi içinde serileştir), **B) Görevler**, **C) Grup PP**.
> Aynı anda en fazla iki hat açılır (KALITE-PROGRAMI çakışma kuralı). Başarım büyük olduğu için: Başarım = 1 hat, ikinci hat B veya C.

## WP-208: Başarım ölü metrik fix + team_player gözden geçirme (SERVER/DATA) 🔧
- **Program/Faz:** Başarım & Sosyal Profil 3.0 (KALITE-PROGRAMI §Başarım) · **Model:** 🔴 Opus (server-authoritative + geçmiş veri + RLS)
- **Durum:** [ ] Bekliyor
- **Problem:** `alpha_wolf`, `campfire_hours`, `locomotive`, `secret_break_enemy` server'da `then 0` → hiç kazanılamıyor (kullanıcı Alfa Kurt bug'ını bildirdi). `team_player` progress'i "grup hedef katkısı" değil "grupta çalışılan gün sayısı"nı sayıyor (isim/mantık uyuşmazlığı).
- **Kapsam dışı:** Claim/pending modeli (→ WP-209). UI ilerleme cilası (→ WP-210). Yeni başarı ekleme.
- **SAHİP dosyalar (yaz):**
  - `supabase/migrations/00NN_achievement_group_metrics.sql` (yeni — `_achievement_metrics` + `process_achievement_event` yeni sürüm; `alpha_wolf`/`campfire_hours`/`locomotive` gerçek hesap)
  - `app/lib/core/stats/achievement_ledger_engine.dart` (istemci `_progressFor` paritesi — offline metrikler; sosyal olanlar sunucudan gelir, istemci 0 bırakabilir ama yorum/parite güncellenir)
  - ilgili testler (`test/core/stats/achievement_ledger_engine_test.dart`, yeni server-metrik birim testleri in_memory ile)
- **DOKUNMA (oku, değiştirme):** `xp_ledger` tablo şeması (0024), profil UI, claim WP'si dosyaları.
- **Adımlar:**
  - [ ] `alpha_wolf` (`group_day_first`): her (grup, İstanbul-günü) için üye toplamlarından max sahibi = o günün birincisi; kullanıcının birinci olduğu **benzersiz gün** sayısı. Beraberlik kuralı tanımla (ör. ikisi de sayılır / ilk ulaşan). `group_members` katılım/ayrılış aralığına saygı.
  - [ ] `campfire_hours`: kullanıcının oturumu sırasında **aynı grupta ≥2 başka üyenin** oturumu zamanca çakışıyorsa (≥3 eşzamanlı), o çakışan saatler sayılır. Oturum zaman-aralığı kesişiminden türet.
  - [ ] `locomotive` (`locomotive_events`): kullanıcı bir oturum başlattıktan sonra **X dk içinde** aynı grupta ≥N üye oturum başlattıysa 1 "lokomotif olayı". X/N eşiklerini WP'de sabitle (öneri X=15dk, N=2).
  - [ ] `team_player`: mevcut `group_goal_contrib` semantiğini "grup günlük hedefine katkı sağlanan gün" olarak netleştir veya metrik adını/açıklamasını hizala (UI metni WP-210, burada yalnız server metrik doğru olsun).
  - [ ] `secret_break_enemy`: ürün kararı gelene kadar `then 0` bırak; karar gelirse ayrı adımda ekle (bu WP'yi bloklamaz).
  - [ ] Idempotency: retroaktif hesap tekrar çalışınca aynı `event_key` ikinci XP vermez (0024 garantisi korunur).
  - [ ] `flutter analyze` 0; server metrik mantığının in_memory eşleniği + birim testleri yeşil.
- **Veri/Migration etkisi:** `_achievement_metrics` + `process_achievement_event` yeniden tanımlanır (CREATE OR REPLACE). Geri alma: 0033 sürümüne dön. Kullanıcı SQL Editor'da uygular. Retroaktif ilk `manual_refresh` çağrısında geçmiş ödüller düşer.
- **RLS/Güvenlik:** SECURITY DEFINER fonksiyonlar; kullanıcı yalnız kendi metriğini işler (`auth.uid()`). Grup verisi okuması `is_group_member`/`can_see_user_sessions` sınırında kalır. İstemci XP yazmaz.
- **Edge-case'ler:** Gruptan ayrılmış üye, çoklu grup üyeliği, aynı gün birden çok grupta birincilik, oturum tam gece yarısı (İstanbul gün sınırı), beraberlik, çok büyük geçmiş (performans/timeout — gerekiyorsa gün bazlı agregasyon indeksinden yararlan).
- **Kabul (ölçülebilir):** Test kullanıcısı geçmişte 6 gün grup birincisiyse `manual_refresh` sonrası `alpha_wolf` progress ≥6, tier-1 (5 gün) ödülü düşer; `campfire_hours`/`locomotive` ≥1 senaryosunda ilerler; aynı çağrı iki kez XP vermez; `flutter analyze` 0; server-metrik testleri yeşil. Cihazda: kullanıcının Alfa Kurt rozeti görünür (`Cihazda doğrulanmalı`).
- **Tuzaklar:** Zaman-çakışması hesabının O(n²) patlaması (indeks/pencere ile sınırla); İstanbul TZ ile UTC karışımı; retroaktif hesabın mevcut XP'yi çifte saymaması; grup gizlilik sınırını aşmamak.
- **Dal önerisi:** `wp208-basarim-grup-metrik`

## WP-209: Topla-ödülü-al (pending reward + claim RPC) (SERVER/DATA) 🎁
- **Program/Faz:** Başarım · **Model:** 🔴 Opus (XP otoritesi + idempotency) · **Bağımlılık:** WP-208 kabul (aynı RPC yüzeyi → serileştir)
- **Durum:** [ ] Bekliyor
- **Problem:** XP şu an eşik geçilince otomatik banklanıyor; kullanıcı "başarı yaptığını" hissetmiyor/fark etmiyor. İstenen: eşik geçilince ödül **toplanabilir (pending)** olsun, kullanıcı dokununca XP görünür artışla banklanır; toplamamak ilerlemeyi durdurmaz (battle-pass).
- **Kapsam dışı:** UI/animasyon (→ WP-210). Bildirim (→ WP-211). Metrik hesabı (WP-208).
- **SAHİP dosyalar (yaz):**
  - `supabase/migrations/00NN_achievement_claim.sql` (yeni — pending ödül durumu + `claim_achievement_reward(achievement_id, tier)` RPC; `process_achievement_event` eşik geçişini "pending" yazacak şekilde günceller, XP'yi claim'e erteler)
  - `app/lib/data/models/achievement_ledger.dart` (pending/claimed alanları)
  - `app/lib/data/repositories/**/*achievement*` (çift repo: pending listesi + claim çağrısı)
  - `app/lib/data/providers/achievement_provider.dart` (claim aksiyonu + pending stream)
  - ilgili testler
- **DOKUNMA (oku, değiştirme):** WP-208 metrik fonksiyonu (kabul edilmiş sürüm üstüne yazılır — sıra kritik), profil UI.
- **Adımlar:**
  - [ ] Model kararı: pending'i `xp_ledger`'a `claimed_at` kolonu ekleyerek mi (XP yalnız `claimed_at` dolu satırlardan sayılır) yoksa ayrı `pending_rewards` tablosu ile mi tutacağını WP'de sabitle. **Öneri:** `xp_ledger`'a `claimed_at timestamptz null` + crown/XP toplayıcı trigger'ı yalnız `claimed_at is not null` satırları sayar → append-only korunur, tek tablo.
  - [ ] `process_achievement_event`: eşik geçilince satırı `claimed_at=null` (pending) yazar, XP profile'a **eklenmez**. `claim_achievement_reward`: satırı `claimed_at=now()` yapar (idempotent), XP profile'a düşer, crown yeniden hesaplanır.
  - [ ] Saat başı 50 XP: ürün kararına göre otomatik-claimed yazılır (ambient), tek tek toplatılmaz.
  - [ ] İstemci `claimableRewards` sağlayıcısı + `claim(id, tier)` aksiyonu; offline/yeniden-deneme güvenli.
  - [ ] `flutter analyze` 0; "eşik geç → pending → claim → XP düşer, iki kez claim XP artırmaz" testi yeşil.
- **Veri/Migration etkisi:** `xp_ledger.claimed_at` kolonu + toplayıcı trigger güncellemesi + `claim_achievement_reward` RPC. **Geri alma:** kolon drop + trigger 0024 sürümüne dön. **Göç:** mevcut tüm ledger satırları `claimed_at=now()` ile geriye-doldurulur (eski kullanıcılar XP kaybetmez, hepsi "toplanmış" sayılır).
- **RLS/Güvenlik:** `claim` yalnız kendi satırını claim eder (`user_id=auth.uid()`); istemci XP miktarını göndermez (server sözlükten okur). Idempotent.
- **Edge-case'ler:** Aynı anda iki cihazdan claim, offline claim kuyruğu, WP-208 retroaktif ödülleriyle etkileşim (hepsi pending düşer — kullanıcı toplu toplar), göç sırasında yarış.
- **Kabul (ölçülebilir):** Eşik geçilince XP profile'a yazılmaz, pending listesinde görünür; `claim` sonrası XP tam ödül kadar artar ve ikinci claim artırmaz; eski ledger satırları göç sonrası XP'yi değiştirmez; `flutter analyze` 0, testler yeşil.
- **Tuzaklar:** Göçte eski satırları pending bırakıp kullanıcıların XP'sini sıfırlamak (mutlaka `claimed_at=now()` geri-doldur); toplayıcı trigger'ı `claimed_at` filtresini unutup pending'i sayması; crown rütbesinin claim'den önce yükselmesi.
- **Dal önerisi:** `wp209-basarim-claim`

## WP-210: Başarım UI — canlı ilerleme cilası + claim/topla akışı + "az kaldı" + metin netleştirme (CLIENT) 🎨
- **Program/Faz:** Başarım · **Model:** 🟣 Pro · **Bağımlılık:** WP-209 kabul (claim RPC + pending stream)
- **Durum:** [ ] Bekliyor
- **Problem:** İlerleme temel hâli var ama: açılmış başarıda sonraki kademe netliği zayıf, streak canlı değil, claim/topla akışı + XP animasyonu yok, "az kaldı" yüzeyi yok, bazı açıklamalar belirsiz (Kusursuz Ay vb.).
- **Kapsam dışı:** Profil dışı bildirim (→ WP-211). Server metrik/claim mantığı (WP-208/209).
- **SAHİP dosyalar (yaz):**
  - `app/lib/features/profile/widgets/achievement_showcase.dart` (26/30 + sonraki-kademe, canlı streak, claim düğmesi + XP artış animasyonu)
  - `app/lib/features/profile/social_profile_screen.dart` (pending/claim bağlama + "az kaldı" minimal şerit — 1 başarı)
  - `app/lib/core/stats/progression_visuals.dart` (gerekirse ilerleme yardımcıları)
  - `app/lib/l10n/app_en.arb`, `app/lib/l10n/app_tr.arb` (**ARB sıcak dosya — bu WP tek ARB yazarı**; Kusursuz Ay vb. açıklama netleştirme + claim/az-kaldı metinleri)
  - ilgili widget testleri
- **DOKUNMA (oku, değiştirme):** `home_shell.dart` (WP-211 sahibi), server dosyaları, generated l10n.
- **Adımlar:**
  - [ ] Açılmış başarıda "26/30 · sonraki: Gümüş" netliği; tamamlanan kademe rozeti + o anki tier gösterimi.
  - [ ] Canlı streak: `fire_streak` için mevcut seri "7/10" ve kaçırınca 0'a düşen davranışı görünür (metrik zaten streak veriyor).
  - [ ] Claim: pending ödül olan başarıda "Topla" düğmesi/parıltısı; dokununca XP barı animasyonla artar, rozet açılır (mevcut confetti altyapısını kullan — ek paket yok, pubspec sıcak).
  - [ ] "Az kaldı": profil üstünde hedefe en yakın **1** başarı için ince şerit (yer kaplamaz; kullanıcı isteği "minimal").
  - [ ] Açıklama netleştirme: Kusursuz Ay = "Bir ayda 28+ gün günlük hedefini tuttur"; diğer belirsizleri (`achievementTierConditionTr`/`achievementDetailDescription`) gözden geçir.
  - [ ] Tema-güvenli (token'dan renk, sabit renk yok), WCAG AA kontrast, 360/600/1200px taşma yok.
  - [ ] `flutter analyze` 0; showcase/claim/az-kaldı widget testleri yeşil.
- **Veri/Migration etkisi:** Yok (WP-209 RPC'sini tüketir).
- **RLS/Güvenlik:** Yok (okuma + claim çağrısı; XP server'da).
- **Edge-case'ler:** Pending yokken düğme gizli, çok sayıda pending (toplu topla?), gizli başarı pending'i (silüet korunur), başkasının profilinde claim düğmesi görünmez (`isSelf`).
- **Kabul (ölçülebilir):** Pending ödül dokununca ≤1 sn'de XP barı artar + rozet açılır; açılmış başarıda 26/30 + sonraki kademe okunur; "az kaldı" tek şerit ≤1 satır yer kaplar; Kusursuz Ay açıklaması net; `flutter analyze` 0, testler yeşil; `Cihazda doğrulanmalı`.
- **Tuzaklar:** Claim animasyonunu server-yazımından önce oynatıp tutarsızlık (optimistic + doğrulama); ARB'ye WP-211 ile aynı anda yazıp çakışma (bu WP tek ARB yazarı — WP-211 salt-okur); sabit renk sokmak (WP-141 kuralı).
- **Dal önerisi:** `wp210-basarim-ui-claim`

## WP-211: Başarı/taç bildirimi — açılış banner'ı + Brawl Stars tarzı nav-işaret (CLIENT) 🔔
- **Program/Faz:** Başarım · **Model:** 🟣 Pro · **Bağımlılık:** WP-209 kabul (pending stream)
- **Durum:** [ ] Bekliyor
- **Problem:** Kullanıcı başarı açtığında/taç yükseldiğinde haberi olmuyor (yalnız profil açarsa görüyor). İki mekanizma isteniyor:
  1. **Açılış banner'ı (Clash Royale tarzı):** başarı açılınca/taç yükselince normal ekranda üstte küçük "topla" bildirimi belirir.
  2. **Kalıcı nav-işareti (Brawl Stars tarzı):** toplanmamış ödül varken ilgili menü butonunun (Profil) üstünde **minik nokta/rozet** durur; kullanıcı listede o başarıyı bulup toplayınca işaret kaybolur. Az başarı olduğundan kafası karışmaz — sadece "ne çıktı, nerede" yönlendirmesi.
- **Kapsam dışı:** Claim mantığı (WP-209), profil içi liste/claim UI (WP-210), sistem push bildirimi (uygulama-içi yeterli — push ayrı iş).
- **SAHİP dosyalar (yaz):**
  - `app/lib/core/navigation/home_shell.dart` (pending varsa açılış banner'ı + **alt nav Profil sekmesinde nokta rozeti**; **sıcak dosya, dar dokun**)
  - yeni `app/lib/features/profile/widgets/reward_toast.dart` (banner + nav-nokta bileşeni)
  - ilgili testler
- **DOKUNMA (oku, değiştirme):** `achievement_showcase.dart` (WP-210), ARB (WP-210 yazar; buradan salt-okur), server dosyaları, `app_*.arb`, `nav_index.dart` (yalnız oku).
- **Adımlar:**
  - [ ] Pending ödül sayısı > 0 olunca home üstünde küçük, kapatılabilir "n ödül hazır · Topla" banner'ı; dokununca profil başarı bölümüne götürür.
  - [ ] Alt navigasyonda Profil sekmesi ikonunun köşesinde nokta/sayı rozeti (pending>0). Kullanıcı ödülleri toplayınca (pending=0) rozet kaybolur — reaktif, `claimableRewards` stream'inden türer.
  - [ ] Taç yükselişinde tek seferlik kutlama; tekrar göstermeme (görülen anahtarları sakla, `_seenUnlockKeys` desenine benzer).
  - [ ] WP-105 (oturum-bitti XP tetiği, parkta) ile aynı `home_shell` yüzeyi — salt pending-okuma, XP tetiğine dokunma.
  - [ ] `flutter analyze` 0; banner + nav-rozet görünürlük/temizlenme/tekrar-göstermeme testleri yeşil.
- **Veri/Migration etkisi:** Yok.
- **RLS/Güvenlik:** Yok.
- **Edge-case'ler:** Açılışta birikmiş çok pending, banner spam'i (debounce/tek banner), kullanıcı banner'ı kapatınca nav-rozetin kalması (rozet pending'e bağlı, banner'a değil), offline, gizli başarı pending'i (rozet sayılır ama içerik silüet).
- **Kabul (ölçülebilir):** Yeni pending oluşunca ≤5 sn'de banner + Profil sekmesinde nokta görünür; ödül toplanınca nokta ve banner kaybolur; taç yükselişi bir kez kutlanır; `flutter analyze` 0, testler yeşil; `Cihazda doğrulanmalı`.
- **Tuzaklar:** `home_shell`'de WP-105 ile çakışmak (ayrı SAHİP mantık, dar dokun); nav-rozeti banner state'ine bağlayıp kapatınca yanlış temizlemek (rozet pending'e bağlı olmalı); her stream tick'inde banner yeniden tetikleme; ARB'ye yazmak (WP-210 yazar).
- **Dal önerisi:** `wp211-basarim-bildirim`
- **> ⚠️ Çakışma:** WP-210 & WP-211 ikisi de Başarım UI hattı. ARB'yi yalnız WP-210 yazar. SAHİP dosyalar kesişmiyor (WP-210=showcase/social_profile, WP-211=home_shell/reward_toast) ama ikisi de Başarım lane'i → tek lane'de **sıralı** (WP-211, WP-210 sonrası). WP-215 de `home_shell`'e dokunabilir → aşağıdaki nota bak.

## WP-215: Aktif sekmeye tekrar basınca en yukarı çık — tüm sekmeler (CLIENT) ⬆️
- **Program/Faz:** IA/Navigasyon cilası (bağımsız, küçük, düşük risk) · **Model:** 🔵 Sonnet · **Bağımlılık:** yok
- **Durum:** [ ] Bekliyor
- **Problem:** "Tap-to-top" yalnız Ana Sayfa'da bağlı (`home_screen.dart` `navReselectProvider`'ı dinliyor). Gruplar, İstatistikler ve (kısa da olsa ileride uzayabilir) Profil, Araçlar sekmelerinde yok. Altyapı **zaten var** (`nav_index.dart` her sekme tekrar-basımında `navReselectProvider`'ı `(tabIndex, tick)` ile tetikliyor) — yalnız dinleyici bağlanacak.
- **Kapsam dışı:** Yeni navigasyon mimarisi, animasyon süresi değişimi, Ana Sayfa'nın mevcut davranışı (dokunma).
- **SAHİP dosyalar (yaz):**
  - `app/lib/features/classroom/**` (Gruplar ana scroll — ekran kökündeki ScrollController/PrimaryScrollController)
  - `app/lib/features/stats/**` (İstatistikler ana scroll)
  - `app/lib/features/profile/**` (Profil ana scroll — kısa ama ekle)
  - Araçlar sekmesi kök scroll (grep: `features/**tools**`)
  - ilgili testler
- **DOKUNMA (oku, değiştirme):** `nav_index.dart` (yalnız oku — desen kaynağı), `home_screen.dart` (mevcut, dokunma), `home_shell.dart` (WP-211 sahibi — buraya yazma; her sekme kendi ekranında dinler).
- **Adımlar:**
  - [ ] Her sekme ekranı kökünde `ref.listen(navReselectProvider, ...)`; `tabIndex == kendi indeksi` ve tick arttıysa scroll controller `animateTo(0)` (home deseninin aynısı).
  - [ ] Her ekranın kök kaydırıcısını bul/normalize et (nested scroll varsa dış controller'a bağlan — WP-172 nested scroll dersine dikkat).
  - [ ] `flutter analyze` 0; her sekme için "tekrar bas → offset 0" testi yeşil.
- **Veri/Migration etkisi:** Yok.
- **RLS/Güvenlik:** Yok.
- **Edge-case'ler:** Nested scroll (Gruplar), zaten en üstteyken tekrar bas (no-op), liste boşken, ekran henüz build olmadan tick.
- **Kabul (ölçülebilir):** Gruplar/İstatistik/Profil/Araçlar sekmesinde aşağı kaydırıp sekmeye tekrar basınca ≤300 ms'de en üste döner; Ana Sayfa davranışı regresyonsuz; `flutter analyze` 0, testler yeşil; `Cihazda doğrulanmalı`.
- **Tuzaklar:** Her ekranda ayrı ScrollController tutup PrimaryScrollController ile çakışmak; nested scroll'da yanlış controller'a bağlanmak; `home_shell`'e yazıp WP-211 ile çakışmak (her ekran kendi içinde dinler, shell'e dokunma).
- **Dal önerisi:** `wp215-tap-to-top-tum-sekmeler`

## WP-212: Günlük yenilenen görev — bulut model + tekrar/tamamlama (DATA) 🗓️
- **Program/Faz:** Görevler (bağımsız hat) · **Model:** 🟣 Pro (veri göçü + gün sınırı) · **Bağımlılık:** yok
- **Durum:** [ ] Bekliyor
- **Problem:** Görevler cihazda (prefs), tekrar yok. Kullanıcı sabit günlük rutinini (2s fizik, 2s mat, 25 paragraf) her gün otomatik listede istiyor; telefon değişince kaybolmasın; streak tutulabilsin. Karar: **bulut**.
- **Kapsam dışı:** UI ekleme akışı + bugünün görünümü (→ WP-213). Görev↔başarı bağlama.
- **SAHİP dosyalar (yaz):**
  - `supabase/migrations/00NN_user_tasks_cloud.sql` (yeni — `user_tasks` şablon tablosu: `is_recurring`, `recurrence`='daily', `target_count` opsiyonel; `user_task_completions` gün-damgalı tamamlama; RLS own-rows)
  - `app/lib/data/models/user_task.dart` (recurrence/target alanları — model "Tekrar yok" notu güncellenir)
  - `app/lib/data/repositories/user_task_repository.dart` + `supabase/` + `in_memory/` (gerçek bulut repo; mevcut prefs repo'dan göç)
  - `app/lib/data/providers/user_task_providers.dart`
  - ilgili testler
- **DOKUNMA (oku, değiştirme):** `tasks_card.dart`/Araçlar UI (WP-213), başarı dosyaları.
- **Adımlar:**
  - [ ] Şema: `user_tasks(id, user_id, title, due_at null, is_recurring bool, recurrence text null, target_count int null, sort_order, created_at)`; `user_task_completions(task_id, user_id, day date, completed_at)` — günlük tamamlama gün-damgalı (00:00 İstanbul yenileme = **kayıt silme yok**, "bugün tamamlandı mı" = bugün için completion var mı).
  - [ ] RLS: her kullanıcı yalnız kendi satırları (insert/select/update/delete `user_id=auth.uid()`).
  - [ ] Prefs'ten buluta tek seferlik göç (mevcut `user_tasks_v2` okunur, buluta yazılır, çift yazımı önle).
  - [ ] "Bugünün görevleri" türetimi: tekrarsız görev = eskisi gibi; tekrarlı görev = bugün completion yoksa aktif. Streak = ardışık gün completion.
  - [ ] Offline: çevrimdışı işaretlemeler kuyruğa, bağlanınca senkron (mevcut offline cache deseni).
  - [ ] `flutter analyze` 0; model/repo/gün-sınırı testleri (TZ mock) yeşil.
- **Veri/Migration etkisi:** İki yeni tablo + RLS. Geri alma: `drop table`. Kullanıcı SQL Editor'da uygular.
- **RLS/Güvenlik:** Own-rows zorunlu; PII yok; gün sınırı İstanbul.
- **Edge-case'ler:** Gece 23:59→00:01 geçişi, cihaz TZ ≠ İstanbul, offline işaretleme sonra senkron, göç sırasında çevrimdışı, `maxTasks` sınırı.
- **Kabul (ölçülebilir):** Tekrarlı görev bugün işaretlenince completed'a düşer; ertesi İstanbul-günü 00:00'da tekrar aktif görünür (kayıt silinmeden); telefon/oturum değişince rutin korunur; streak ardışık günleri doğru sayar; `flutter analyze` 0, testler yeşil.
- **Tuzaklar:** 00:00 yenilemeyi "kayıt sıfırlama" ile yapmak (yanlış — completion gün-damgalı olmalı); prefs göçünde çift kayıt; TZ karışıklığı; UTC/İstanbul gün kayması.
- **Dal önerisi:** `wp212-gorev-bulut-tekrar`

## WP-213: Görev UI — günlük tip ekleme + bugünün listesi + 00:00 yenileme (CLIENT) ✅
- **Program/Faz:** Görevler · **Model:** 🔵 Sonnet · **Bağımlılık:** WP-212 kabul
- **Durum:** [ ] Bekliyor
- **Problem:** Kullanıcı normal görev ekleme akışına "günlük yenilenen" tipini seçebilmeli; işaretleyince completed'a kaysın, ertesi gün geri gelsin. Kullanıcı: "gerisi aynı, sadece yeni tip".
- **Kapsam dışı:** Bulut model/RLS (WP-212). Sayaçlı hedef ("25 paragraf" tek tek artırma) opsiyonel — kullanıcı "üstüne basınca onaylansın" dedi → **basit onay kutusu** yeterli (sayaç ürün kararı, bu WP dışı).
- **SAHİP dosyalar (yaz):**
  - `app/lib/features/home/widgets/tasks_card.dart` (bugünün tekrarlı görevlerini göster)
  - Araçlar/Görevler CRUD ekranı (görev ekleme akışına "Günlük yenilenen" seçeneği — mevcut ekleme ekranı; grep ile bul: `features/**tools**`/`**tasks**`)
  - `app/lib/l10n/app_en.arb`, `app/lib/l10n/app_tr.arb` (**ARB — bu hat tek yazar**; "Günlük", "Her gün yenilenir" metinleri)
  - ilgili widget testleri
- **DOKUNMA (oku, değiştirme):** başarı ARB yazarı WP-210 (farklı hat; ARB aynı dosya → **hat sıralaması**: Başarım ve Görev ARB'ye aynı anda yazamaz → serileştir veya farklı zaman).
- **Adımlar:**
  - [ ] Görev ekleme akışına "Günlük yenilenen" anahtarı; kaydedince `is_recurring=true, recurrence='daily'`.
  - [ ] Home Görevler kartı: tekrarlı görevler bugünkü durumla; işaretleyince completed görünüm, 00:00'da geri gelir (WP-212 türetimi).
  - [ ] Tekrarlı görevi rozet/ikonla ayırt et (ör. 🔁); streak varsa küçük gösterim (opsiyonel, minimal).
  - [ ] `flutter analyze` 0; ekleme + bugün-işaretle + ertesi-gün-geri-gelme (TZ mock) widget testleri yeşil.
- **Veri/Migration etkisi:** Yok (WP-212 şemasını tüketir).
- **RLS/Güvenlik:** Yok.
- **Edge-case'ler:** Gece yarısı açık ekranda görünüm yenilenmesi, tekrarlı + tekrarsız karışık liste sıralaması, boş liste.
- **Kabul (ölçülebilir):** Kullanıcı günlük görev ekler → bugün listede; işaretler → completed; ertesi İstanbul-günü tekrar aktif; tekrarsız görevler eskisi gibi; `flutter analyze` 0, testler yeşil; `Cihazda doğrulanmalı`.
- **Tuzaklar:** ARB'ye Başarım hattıyla aynı anda yazmak (serileştir); 00:00 yenilemeyi UI'da manuel timer ile zorlamak yerine türetimden okumak.
- **Dal önerisi:** `wp213-gorev-gunluk-ui`

## WP-214: Grup profil fotoğrafı (grup pp) (DATA + CLIENT) 🖼️
- **Program/Faz:** Sosyal gruplar (bağımsız hat) · **Model:** 🟣 Pro (storage RLS + UI) · **Bağımlılık:** yok
- **Durum:** [ ] Bekliyor
- **Problem:** Grupların profil fotoğrafı yok; grup listesi/kamp ateşi/istatistik hep jenerik. Yönetici grup pp'si koyabilsin.
- **Kapsam dışı:** Üye avatar sistemi (zaten var). Grup banner/kapak. Fotoğraf moderasyonu (UGC kuralları ayrı — okuma: WP-115/125 deseni).
- **SAHİP dosyalar (yaz):**
  - `supabase/migrations/00NN_group_avatar.sql` (yeni — `alter table groups add column avatar_url text` + `group-avatars` public bucket; **yazma yalnız grup admini** `is_group_admin(gid)`, yol kuralı `<group_id>/avatar.jpg`, okuma public)
  - `app/lib/data/models/group*.dart` (grup modeline `avatarUrl`)
  - `app/lib/data/repositories/**/*group*` (avatar upload + url güncelle; çift repo)
  - grup ayarları/oluşturma UI (admin upload) + `app/lib/features/classroom/widgets/class_switcher.dart` + grup listesi/kamp ateşi/istatistik başlığı (göster)
  - ilgili testler
- **DOKUNMA (oku, değiştirme):** başarı/görev dosyaları, `profiles` avatar akışı (dokunma, yalnız desen referans).
- **Adımlar:**
  - [ ] Migration: `groups.avatar_url` + `group-avatars` bucket; RLS insert/update yalnız `is_group_admin`; okuma public; silme admin.
  - [ ] Upload akışı: admin grup ayarlarında fotoğraf seç → `<group_id>/avatar.jpg` yükle → `groups.avatar_url` güncelle (mevcut profil avatar upload desenini yeniden kullan).
  - [ ] Gösterim: grup switcher, keşif/liste, kamp ateşi başlığı, grup istatistik başlığı — `avatarUrl` varsa göster, yoksa mevcut fallback (baş harf/ikon).
  - [ ] Erişilebilirlik + tema-güvenli; büyük görselde performans (cache/boyut sınırı).
  - [ ] `flutter analyze` 0; upload izin (admin/üye), gösterim/fallback testleri yeşil.
- **Veri/Migration etkisi:** `groups.avatar_url` kolonu + storage bucket/policy. Geri alma: kolon drop + bucket policy drop. Kullanıcı SQL Editor'da uygular.
- **RLS/Güvenlik:** Yazma yalnız grup admini (RLS + storage policy iki katman); okuma public (görsel gösterimi basit). Üye admin değilse upload reddedilir ve UI hata gösterir (sessiz başarı yok — WP-109 B7 dersi).
- **Edge-case'ler:** Admin olmayan yükleme denemesi, grup silinince avatar temizliği, çok büyük dosya, eski url cache, public bucket kötüye kullanımı (boyut/tip sınırı).
- **Kabul (ölçülebilir):** Admin grup pp yükler → tüm grup yüzeylerinde ≤5 sn görünür; üye (admin değil) yükleyemez (RLS reddi + UI hata); avatar yoksa fallback bozulmaz; `flutter analyze` 0, testler yeşil; `Cihazda doğrulanmalı`.
- **Tuzaklar:** Storage policy'de `is_group_admin` yerine yalnız auth kontrolü (herkes yazar); public bucket'ta tip/boyut sınırsız bırakmak; grup modeli sıcaksa geniş dokunmak.
- **Dal önerisi:** `wp214-grup-pp`

---

## Çakışma matrisi

- **Migration sıcak dosya:** WP-208/209/212/214 dördü de yeni migration ekler. Numaralar claim anında sırayla alınır (yerelde 0046 sonrası). Aynı anda iki migration WP'si açılırsa numara çakışmasına dikkat — claim anında `progress.md`'den teyit.
- **ARB sıcak dosya:** WP-210 (başarım) ve WP-213 (görev) ikisi de `app_*.arb` yazar → **aynı anda ikisi ARB'ye yazamaz**; hatlar farklı olsa da ARB yazımını serileştir.
- **Başarım iç sıra:** WP-208 → WP-209 → WP-210 → WP-211 (hepsi aynı RPC/UI yüzeyi; sıralı).
- **Görev iç sıra:** WP-212 → WP-213.
- **Grup PP:** WP-214 bağımsız; başka hatla SAHİP kesişimi yok.
- **WP-215 (tap-to-top):** `home_shell.dart`'a **yazmaz** (her ekran kendi içinde `navReselectProvider` dinler) → WP-211 ile SAHİP kesişimi yok. Gruplar/İstatistik/Profil/Araçlar ekran dosyalarına dokunur; başka aktif hat o ekranlarda yoksa paralel güvenli. Bağımsız küçük iş — herhangi bir ikinci lane boşluğunda yapılabilir.
- **Hat sayısı:** Başarım büyük program = 1 lane. İkinci lane = Görev **veya** Grup PP **veya** WP-215 (aynı anda en fazla iki hat). Başarım açıkken yalnız biri ikinci lane.
- **Parktakiler çakışma saymaz:** WP-105 (`home_shell`, test için bekliyor) WP-211 ile aynı dosya ama parkta → bloklamaz; WP-211 dar dokunur.

## Model önerileri özeti
- 🔴 Opus: WP-208, WP-209 (server-authoritative XP + retroaktif veri).
- 🟣 Pro: WP-210, WP-211, WP-212, WP-214.
- 🔵 Sonnet: WP-213, WP-215.
