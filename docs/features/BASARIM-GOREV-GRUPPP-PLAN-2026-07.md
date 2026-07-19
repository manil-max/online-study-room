# Başarım Canlı İlerleme + Topla-Ödül + Ölü Başarı Fix + Günlük Görev + Grup PP — PLAN (v2)

> Kaynak: kullanıcı isteği 2026-07-19 (Minik Kuş). Planlayıcı: Claude.
> **v2 (2026-07-19):** Codex denetimi sonrası revize. Değişen mimari kararlar ve yeni WP-216 (oturum bütünlüğü) aşağıda. Denetim yanıtı: `docs/features/DENETIM-YANIT-CODEX-01.md`.
> Kanon kurallar `.agents/AGENTS.md`, program `docs/KALITE-PROGRAMI.md`, format `.agents/skills/planner/SKILL.md`.
> **Kod yok — yalnız plan.** Worker'lar bu karttan claim eder. Migration numaraları claim anında `progress.md` "Proje Gerçekleri"nden **yeniden teyit edilir** (yerelde en yüksek `0046`).

## Bağlam ve mevcut durum (koda karşı doğrulandı)

- **Başarı motoru** server-authoritative: `_achievement_metrics` + `process_achievement_event` (son sürüm `0033`); istemci XP yazmaz, yalnız olay tetikler. Ledger `xp_ledger` append-only, `event_key` UNIQUE (idempotent), **`AFTER INSERT` trigger'ı `trg_xp_ledger_apply` satır eklenir eklenmez XP'yi profile bankalar** (`0024:210`). Bu davranış claim modelinin merkezinde — aşağıya bak.
- **Canlı ilerleme temel hâli VAR ama BOZUK:** `achievement_showcase.dart` `_CatalogTile` kilitli/ilerleyen başarıda `LinearProgressIndicator` + `$progress / $need` gösteriyor (`~1038`). **Ancak** server `user_achievements.progress` alanına gerçek metrik değil **tier numarasını** yazıyor (`0024:194`). Yani "26/30" sosyal/server metriklerinde **güvenilir değil** — bar tier-no'yu eşiğe bölüyor. Bu bir server sözleşme boşluğu (Codex bulgu #3). Eksikler: (a) sonraki kademe netliği, (b) canlı streak, (c) ölü başarılarda progress hep 0, (d) claim/topla akışı, (e) profil dışı bildirim, (f) "az kaldı", **(g) gerçek server progress sözleşmesi.**
- **Ölü başarılar (server'da `then 0`, asla kazanılamaz):** `alpha_wolf`, `campfire_hours`, `locomotive`, `secret_break_enemy` — `0025/0027/0033` hepsinde sabit sıfır (`process_achievement_event` içinde `when 'alpha_wolf' then 0`).
  - **Retroaktif hesaplanabilirlik:** metrikler `study_sessions` zaman aralıkları + grup üyeliğinden türetilebilir. **DİKKAT:** `group_members.joined_at` yeniden katılımda **eziliyor** (`0012:121` `joined_at = now()`), yani üyelik penceresi tarihsel olarak güvenilir DEĞİL. Bu yüzden retro hesap **doğrudan `study_sessions.group_id` + zaman damgasından** türetilir; `group_members` yalnız "şu an üye mi" kontrolü için kullanılır, tarihsel pencere için değil.
- **Oturum verisi güvenilmez (Codex bulgu #4 — GERÇEK):** `sessions_insert` RLS yalnız `user_id = auth.uid()` kontrol ediyor (`0001:179`) — grup üyeliği, `end>start`, süre tutarlılığı, gelecek-tarih, üst sınır **yok**. Kullanıcı doğrudan API'den sahte grup oturumu üretip Alfa Kurt/Kamp Ateşi/Lokomotif/Mola Düşmanı kazanabilir. Sosyal başarılar gerçek XP'ye bağlanınca bu bir bütünlük açığı → **WP-216 (yeni)**.
- **Kusursuz Ay** = bir takvim ayında ≥28 hedef günü (`_achievement_metrics` `0024:509` `if r.goal_days >= 28`; sözlük metni "30 gün" diyor — çelişki). Açıklama netleştir.
- **Görevler** şu an cihazda (`SharedPreferences`, `user_tasks_v2`); model `user_task.dart` "Tekrar yok" diyor. Repo katmanı adı `SupabaseUserTaskRepository` ama prefs'e yazıyor (yanıltıcı). Bulut + günlük tekrar bunun üstüne eklenecek.
- **Grup PP yok:** `groups` tablosunda `avatar_url` **yok**; `is_group_admin` = **yalnız `created_by`** (`0004:19` — rol tablosu değil, tek-sahip modeli); `discover_public_groups` avatar döndürmüyor (`0032:142`).

## Mimari kararlar (v2 — Codex denetimi sonrası KİLİTLİ)

**MK-1 — Claim mimarisi: ayrı `achievement_rewards` tablosu (claimed_at kolonu DEĞİL).**
Önceki plan `xp_ledger`'a `claimed_at` kolonu ekliyordu. Codex haklı olarak üç sorun gösterdi: (a) trigger yalnız `AFTER INSERT`, claim `UPDATE` ile yapılırsa XP hiç banklanmaz; (b) `max(tier)` projeksiyonu pending satırları da sayar → tier-1 claim edilirken pending tier-5 rozeti fırlatır; (c) mutable `claimed_at` "append-only" sözleşmesini bozar; (d) tüm eski satırları `claimed_at` ile geri-doldurma riskli (kitlesel XP kaybı) ve WP sırasıyla çelişiyor.
**Yeni tasarım — split table:**
- Yeni `public.achievement_rewards(id, user_id, achievement_id, tier, xp_amount, status ['pending'|'claimed'], earned_at, claimed_at null, event_key UNIQUE)`. **Kazanılan ama toplanmamış** ödüllerin kişisel gelen kutusu.
- `xp_ledger` **hiç değişmez**: literal append-only, `AFTER INSERT` = XP bankalama aynen korunur. Yalnızca **claim edilmiş** XP burada.
- Eşik geçilince `process_achievement_event`, `_award_achievement_tier` (ledger'a yazan) yerine yeni `_record_pending_reward` çağırır → `achievement_rewards`'a `status='pending'` satır ekler (idempotent, `event_key`), **XP banklanmaz**. Ek koşul: aynı `(user,ach,tier)` `xp_ledger`'da yoksa (zaten toplanmamışsa) pending yaratılır.
- `claim_achievement_reward(p_achievement_id, p_tier)`: atomik `update achievement_rewards set status='claimed', claimed_at=now() where user_id=auth.uid() and achievement_id=... and tier=... and status='pending' returning ...`; sonra `_award_achievement_tier` çağrılır → `xp_ledger`'a **aynı `event_key`** ile yazar → mevcut trigger XP'yi bankalar. Çifte-claim iki katmanda da idempotent (`achievement_rewards.event_key` UNIQUE + `xp_ledger.event_key` UNIQUE).
- **Rozet tier projeksiyonu otomatik doğru:** `user_achievements.tier` yalnız `xp_ledger`'dan (claimed) türediği için pending tier rozeti fırlatmaz — Codex bulgu #2(b) **yapısal olarak çözülür**, `max(tier)` sorgusuna filtre eklemeye gerek kalmaz.
- **Göç riski yok (Codex bulgu #1 çözülür):** mevcut `xp_ledger` satırları zaten banklanmış = "toplanmış". Onlar için pending yaratılmaz (eski kullanıcılar zaten sahip). Yalnız **yeni** eşik geçişleri (retro ölü metrikler dâhil) pending olur. `claimed_at` backfill'i, kitlesel XP kaybı riski **ortadan kalkar**.
- **Saat başı 50 XP:** ambient/otomatik → doğrudan `xp_ledger`'a yazılır (auto-banked), reward satırı yaratmaz, tek tek toplatılmaz. Taç seviyesinin saat XP'siyle kullanıcı dokunmadan yükselmesi **bilinçli** ürün davranışıdır (UI metninde belirtilir).
- **Toplu topla:** `claim_all_rewards()` RPC pending'leri döngüyle claim eder (her biri idempotent).
- **RLS:** `achievement_rewards` select = `user_id = auth.uid()` (kişisel gelen kutusu, başkasının toplanmamışı görünmez); yazma yalnız SECURITY DEFINER RPC (doğrudan DML revoke). status yalnız `pending→claimed` yönünde değişebilir (RPC dışı yazım yok).

**MK-2 — Gerçek server progress sözleşmesi (Codex bulgu #3).**
`user_achievements`'a yeni `metric_progress integer` kolonu eklenir. `process_achievement_event` **her** başarı için gerçek metrik değerini (sosyal dâhil) hesaplayıp `metric_progress`'e upsert eder. UI "26/30"'u `metric_progress` / sonraki eşikten okur; `tier` yalnız rozet seviyesi için. Böylece sosyal metriklerde de gerçek ilerleme server-authoritative görünür. Bu **WP-208/210 server kapsamında**, WP-211 UI cilasına ertelenemez.

**MK-3 — Oturum bütünlüğü ön-koşulu (Codex bulgu #4).**
Sosyal başarıları gerçek XP'ye bağlamadan önce oturum fabrikasyonu kapatılmalı → **WP-216**. Not: bu açık **mevcut** (lider tablosu/kamp ateşi de aynı veriye güveniyor), yeni doğmuyor; ancak ödül bağlanınca risk yükselir. Retro hesap tarihsel veriyi temizleyemez (hardening yalnız ileriyi korur); erken/küçük kullanıcı tabanında tarihsel risk düşük kabul edilir. WP-216 **ileriye dönük güven için önerilen ön-koşul**, WP-209 retro için sert blok değil ama yayından önce inmeli.

**MK-4 — Retro performans (Codex uyarısı).**
- Kamp Ateşi çakışması: pairwise self-join (O(n²)) **değil**, interval sweep-line (O(n log n)); aynı kullanıcının çakışan oturumları önce union edilir.
- Mola Düşmanı 5h kayan pencere: union edilmiş kullanıcı interval'lerinde iki-pointer/kayan pencere.
- Backfill: her profil açılışında tam yeniden tarama **yok**; kullanıcı başına `backfill_checkpoint` (son işlenen zaman) + ileriye dönük artımlı projeksiyon.
- Kabul kriteri: beklenen maks veri setiyle `EXPLAIN ANALYZE`, p95 süre bütçesi, timeout eşiği. In-memory Dart testi SQL perfını kanıtlamaz.

**MK-5 — Açık mikro-kararlar (Codex "açık uç kalmadı" iddiasını haklı olarak sorguladı).**
Aşağıdaki varsayılanlar WP'lerde uygulanır; ürün sahibi itiraz ederse değişir:
- **Alfa Kurt beraberlik:** eşit toplamda **ikisi de** o günün birincisi sayılır. **Çoklu grup:** her grup ayrı → aynı gün 2 grupta birinci = 2 sayım. **Gün bitmeden:** yalnız **tamamlanmış geçmiş günler** (İstanbul dün ve öncesi) sayılır; bugünkü liderlik gün kapanana dek verilmez.
- **Lokomotif "boş grup":** kullanıcı `source='live'` oturum başlattığında grupta önceki N dk içinde başka aktif live oturum yoktu **ve** ardından X=15 dk içinde ≥2 **farklı** üye live oturum başlattı → 1 olay. Tek olay/başlatma sınırı.
- **team_player:** metrik ("grup günlük hedefine katkı günü") korunur, **açıklama metni** buna hizalanır (metrik değişimi değil metin netleştirme — daha ucuz, WP-210).
- **Manuel oturumlar:** sosyal/odak başarıları (Alfa Kurt/Kamp/Lokomotif/Mola Düşmanı) **yalnız `source='live'`** oturumları sayar; elle girilen oturum bunlara dâhil değil.
- **Kazanım sonrası oturum silme/düzenleme:** XP append-only → **geri alınmaz**; gaming WP-216 insert-time sıkılaştırmasıyla önlenir (silme sonrası XP iadesi yok, dokümante edilir).

## Ürün kararları (önceki, korunur)

1. **Claim modeli — C (gerçek toplama).** ✅ 2026-07-19. Uygulama = MK-1 (split table).
2. **`secret_break_enemy` (Mola Düşmanı) — "yoğun odak penceresi".** ✅ Herhangi bir 5 saatlik kayan dilimde toplam ≥270 dk (≤30 dk boşluk). Tek kademe. Yalnız `source='live'`. Retro hesaplanır (MK-4 kayan pencere).
3. **Ölü başarıların retroaktif dağıtımı — EVET.** ✅ Geçmişten hesaplanınca kullanıcıya toplu **pending** düşer (MK-1 sayesinde otomatik pending, backfill riski yok).

---

# İŞ PAKETLERİ

> ⚠️ **YAYIN / BAĞIMLILIK SIRASI (numara ≠ yürütme sırası — bunu oku):**
> `WP-209` (claim/earned altyapı) **ÖNCE** → `WP-216` (oturum bütünlüğü, önerilen ön-koşul) → `WP-208` (ölü metrik retro + gerçek progress sözleşmesi + team_player) → `WP-210` (Başarım UI). `WP-211` (bildirim) yalnız `WP-209`'a bağlı, WP-208'den bağımsız.
> **Neden ters:** WP-208 retro metrikleri `_award_achievement_tier`'ı çağırırsa mevcut trigger XP'yi anında banklar (pending olmaz). Bu yüzden pending/earned altyapısı (WP-209) canlıda **önce** olmalı; retro en son açılır. (Codex bulgu #1.)
>
> Bağımsız hatlar: **B)** Görev (`WP-212`→`WP-213`), **C)** Grup PP (`WP-214`), **D)** Tap-to-top (`WP-215`).
> Aynı anda en fazla **iki hat** (KALITE-PROGRAMI çakışma kuralı). Başarım büyük program = 1 hat; ikinci hat B/C/D'den biri.
> **Git:** `.agents/AGENTS.md §1.5` = tek `main`, branch/merge/push yok. Bu planda **dal önerisi yok**; her WP tek ayrık commit (`git add -A` yasak, yalnız SAHİP dosyalar). "wpNN-…" yalnız commit mesajı/kapsam etiketidir.
> **Migration sıcak dosyası:** `supabase/migrations/**` tamamı sıcak → **WP-208/209/212/214/216'nın hiçbiri aynı anda açık olamaz** (yalnız numara değil, tüm yüzey). Migration ekleyen WP'ler tek tek serileştirilir; numara claim anında `progress.md`'den teyit.

## WP-209: Topla-ödülü-al — earned/pending reward + claim RPC (SERVER/DATA) 🎁 ⟶ ÖNCE İNER
- **Program/Faz:** Başarım & Sosyal Profil 3.0 · **Model:** 🔴 Opus (XP otoritesi + idempotency) · **Bağımlılık:** yok (altyapı tabanı) · **Yayın:** WP-208'den **önce**
- **Durum:** [ ] Bekliyor
- **Problem:** XP eşik geçilince otomatik banklanıyor; kullanıcı "başarı yaptığını" hissetmiyor. İstenen: eşik geçilince ödül **pending** olsun, dokununca görünür artışla banklansın; toplamamak ilerlemeyi durdurmaz (battle-pass).
- **Kapsam dışı:** UI/animasyon (WP-210), bildirim (WP-211), metrik hesabı (WP-208), oturum güvenliği (WP-216).
- **SAHİP dosyalar (yaz):**
  - `supabase/migrations/00NN_achievement_rewards.sql` (yeni — `achievement_rewards` tablosu + RLS; `_record_pending_reward`; `claim_achievement_reward` + `claim_all_rewards` RPC; `process_achievement_event` eşik geçişini pending yazacak şekilde günceller — `_award_achievement_tier`'ı doğrudan çağırmayı bırakır, claim'e erteler; saat XP yolu doğrudan ledger'da kalır)
  - `app/lib/data/models/achievement_reward.dart` (yeni — pending/claimed model)
  - `app/lib/data/repositories/**/*achievement*reward*` (çift repo: pending listesi + claim çağrısı)
  - `app/lib/data/providers/achievement_provider.dart` (claim aksiyonu + `claimableRewards` stream)
  - ilgili testler
- **DOKUNMA (oku, değiştirme):** `xp_ledger` tablo/trigger (0024 — **değişmez**, MK-1), profil UI, WP-208 metrik fonksiyonu.
- **Adımlar:**
  - [ ] `achievement_rewards` şeması (MK-1) + RLS (select self, yazma yalnız DEFINER RPC) + `event_key` UNIQUE.
  - [ ] `_record_pending_reward(user, ach, tier, xp)`: `(user,ach,tier)` `xp_ledger`'da yoksa **ve** `achievement_rewards`'da yoksa pending ekler (çift idempotency). XP banklamaz.
  - [ ] `process_achievement_event`: eşik geçilince `_award_achievement_tier` yerine `_record_pending_reward`. **Retro/mevcut kullanıcı guard:** zaten ledger'da olan tier için pending yaratma.
  - [ ] `claim_achievement_reward` + `claim_all_rewards`: atomik pending→claimed, sonra `_award_achievement_tier` (ledger insert → trigger XP bankalar). İki cihazdan yarış idempotent.
  - [ ] Saat XP: `study_hour_xp` sistem satırları doğrudan ledger (auto-claimed), reward yaratmaz.
  - [ ] İstemci `claimableRewards` + `claim()` / `claimAll()`; offline/yeniden-deneme güvenli.
  - [ ] Uzlaştırma testi: `gamification_profiles.xp == SUM(xp_ledger.xp_amount)` (yalnız claimed/banked); pending XP'ye dâhil değil.
  - [ ] `flutter analyze` 0; "eşik→pending→claim→XP düşer, iki kez claim artırmaz, pending XP'ye sızmaz" testleri yeşil.
- **Veri/Migration etkisi:** Yeni `achievement_rewards` tablosu + 3 RPC + `process_achievement_event` güncelleme. **Geri alma:** `drop table achievement_rewards` + `process_achievement_event` 0033 sürümüne dön (pending yerine doğrudan award). `xp_ledger` dokunulmadığından eski davranışa dönüş temiz. **Göç: YOK** (mevcut ledger = toplanmış; backfill gerekmez — MK-1).
- **RLS/Güvenlik:** claim yalnız kendi pending'i; istemci XP miktarı göndermez (sözlükten okunur); idempotent.
- **Edge-case'ler:** Aynı anda iki cihazdan claim, offline claim kuyruğu, çok sayıda pending (claim_all), gizli başarı pending'i (silüet korunur), retro ödülleriyle etkileşim (hepsi pending, kullanıcı toplu toplar).
- **Kabul (ölçülebilir):** Eşik geçilince XP profile yazılmaz, pending listede görünür; claim sonrası XP tam ödül kadar artar, ikinci claim artırmaz; mevcut kullanıcıların XP'si göç sonrası değişmez (uzlaştırma testi eşit); `flutter analyze` 0, testler yeşil.
- **Tuzaklar:** `process_achievement_event`'te retro/mevcut kullanıcı guard'ını unutup zaten sahip olunan tier'a pending yaratmak; saat XP'yi yanlışlıkla pending'e sokmak; claim'i atomik yapmayıp çifte bankalamak.

## WP-216: Oturum bütünlüğü sıkılaştırma (session integrity) (SERVER/DATA) 🛡️ ⟶ ÖN-KOŞUL
- **Program/Faz:** Başarım (güvenlik ön-koşulu) · **Model:** 🔴 Opus (RLS + veri bütünlüğü) · **Bağımlılık:** yok · **Yayın:** WP-208 (retro) canlıya çıkmadan önce
- **Durum:** [ ] Bekliyor
- **Problem:** `sessions_insert/update` yalnız `user_id=auth.uid()` kontrol ediyor (`0001:179`) — kullanıcı üye olmadığı gruba, gelecek tarihli, `end<start`, saçma süreli, sınırsız oturum yazabilir. Sosyal başarılar gerçek XP'ye bağlanınca fabrikasyonla Alfa Kurt/Kamp/Lokomotif/Mola Düşmanı kazanılır (Codex bulgu #4).
- **Kapsam dışı:** Başarı metrik hesabı (WP-208), mevcut tarihsel verinin temizliği (hardening yalnız ileriyi korur; geçmiş tolere edilir — MK-3).
- **SAHİP dosyalar (yaz):**
  - `supabase/migrations/00NN_session_integrity.sql` (yeni — `study_sessions` insert/update WITH CHECK sıkılaştırma + `BEFORE` trigger veya CHECK constraint ile zaman/süre doğrulaması)
  - ilgili server testleri (in_memory eşleniği varsa parite)
- **DOKUNMA (oku, değiştirme):** Başarı dosyaları, diğer migration WP'leri (sıcak — serileştir).
- **Adımlar:**
  - [ ] `sessions_insert`/`sessions_update` WITH CHECK: `group_id is null or public.is_group_member(group_id)` (üye olmadığın gruba yazamazsın).
  - [ ] Zaman/süre doğrulama (CHECK veya trigger): `end_time > start_time`; `duration_seconds` ≈ `(end-start)` (tolerans ±%bir eşik); `start_time <= now() + skew`; `duration_seconds <= 24h` üst sınır.
  - [ ] `source` alanı: `'live'` yalnız gerçek-zamanlı akışta yazılabilir mi netleştir; en azından sosyal/odak başarıları **yalnız `source='live'`** oturumları sayar (WP-208 buna güvenir). İstemcinin `source`'u serbest beyan etmemesi için sunucu tarafı doğrulama/kısıt.
  - [ ] Geriye uyum: mevcut meşru istemci akışı (kronometre/manuel giriş) kırılmamalı — mevcut insert yollarını test et.
  - [ ] `flutter analyze` 0; "üye olmayan grup insert reddi, `end<start` reddi, gelecek tarih reddi, aşırı süre reddi, meşru oturum kabul" testleri yeşil.
- **Veri/Migration etkisi:** RLS/constraint güncellemesi. Geri alma: eski `0001` politikalarına dön. **Mevcut kayıtlar:** yeni CHECK'ler yalnız yeni insert/update'e uygulanır (veya `NOT VALID` ile ekleyip mevcutları etkilemeden ileriyi korur).
- **RLS/Güvenlik:** Bu WP'nin kendisi güvenlik sıkılaştırması. Meşru akışı kırmama önceliği.
- **Edge-case'ler:** Solo (grupsuz) oturum `group_id null`, gece yarısı sınırında oturum, offline sonra senkron eski zaman damgası (geçmiş ama makul), saat dilimi/skew toleransı.
- **Kabul (ölçülebilir):** Üye olmayan grup/`end<start`/gelecek/aşırı-süre insert **reddedilir**; mevcut kronometre ve manuel giriş akışları çalışır; `flutter analyze` 0, testler yeşil; `Cihazda doğrulanmalı`.
- **Tuzaklar:** Toleransı çok dar koyup meşru manuel girişleri reddetmek; `NOT VALID` unutup mevcut (belki tutarsız) kayıtlarda migration'ı patlatmak; `is_group_member`'ı update'te unutmak (insert temiz, update'ten kaçış).

## WP-208: Ölü metrik retro fix + gerçek progress sözleşmesi + team_player (SERVER/DATA) 🔧 ⟶ WP-209 & WP-216 SONRASI
- **Program/Faz:** Başarım · **Model:** 🔴 Opus (server-authoritative + geçmiş veri + RLS + perf) · **Bağımlılık:** **WP-209** (pending altyapısı), **WP-216** (oturum güveni) · **Yayın:** her ikisinden sonra
- **Durum:** [ ] Bekliyor
- **Problem:** `alpha_wolf`/`campfire_hours`/`locomotive`/`secret_break_enemy` server'da `then 0` → kazanılamıyor. `team_player` progress "grup hedefi katkısı" değil "grupta gün sayısı" sayıyor. Ayrıca `user_achievements.progress` = tier-no (gerçek metrik değil) → canlı "26/30" bozuk (MK-2).
- **Kapsam dışı:** Claim/pending (WP-209 — bu WP `_record_pending_reward`'ı çağırır), UI cilası (WP-210), oturum güvenliği (WP-216).
- **SAHİP dosyalar (yaz):**
  - `supabase/migrations/00NN_achievement_group_metrics.sql` (yeni — `_achievement_metrics` sosyal metrikleri gerçek hesaplar; `process_achievement_event` gerçek `metric_progress`'i her başarı için upsert eder + eşik geçişini WP-209'un `_record_pending_reward`'ına yönlendirir; `user_achievements.metric_progress` kolonu — MK-2)
  - `app/lib/core/stats/achievement_ledger_engine.dart` (istemci `_progressFor` paritesi/yorum güncelleme; sosyal metrikler artık server'dan gerçek `metric_progress` ile gelir)
  - ilgili testler (server-metrik in_memory eşleniği + `achievement_ledger_engine_test.dart`)
- **DOKUNMA (oku, değiştirme):** `achievement_rewards` tablosu/RPC (WP-209 — çağırır, değiştirmez), `xp_ledger` (0024), profil UI.
- **Adımlar:**
  - [ ] `user_achievements.metric_progress integer` kolonu; `process_achievement_event` **her** başarı için gerçek metrik değerini upsert eder (MK-2). UI "26/30" buradan.
  - [ ] `alpha_wolf`: her (grup, İstanbul-günü, **yalnız tamamlanmış geçmiş gün**) için üye toplamlarından max sahibi = birinci; beraberlikte ikisi de (MK-5). Grup üyeliği `study_sessions.group_id`'den türetilir (joined_at güvenilmez — MK-5).
  - [ ] `campfire_hours`: `source='live'` oturumlarda aynı grupta ≥3 eşzamanlı üye çakışması; **sweep-line O(n log n)** (MK-4), aynı kullanıcının çakışan oturumları önce union.
  - [ ] `locomotive`: MK-5 tanımı (boş grup + 15 dk içinde ≥2 farklı live üye).
  - [ ] `secret_break_enemy`: 5h kayan pencerede ≥270 dk (`source='live'`); union interval'lerde iki-pointer (MK-4).
  - [ ] `team_player`: metrik korunur, açıklama WP-210'da hizalanır (MK-5).
  - [ ] Backfill checkpoint (MK-4): profil açılışında tam yeniden tarama yok; artımlı.
  - [ ] Retro ödüller `_record_pending_reward` ile **pending** düşer (WP-209 sayesinde otomatik; XP banklanmaz).
  - [ ] Idempotency: retro tekrar çalışınca aynı `event_key` ikinci pending/XP vermez.
  - [ ] Perf kabul: beklenen maks veriyle `EXPLAIN ANALYZE`, p95 bütçe, timeout eşiği.
  - [ ] `flutter analyze` 0; server-metrik + perf testleri yeşil.
- **Veri/Migration etkisi:** `_achievement_metrics` + `process_achievement_event` yeniden tanımlanır (CREATE OR REPLACE) + `user_achievements.metric_progress`. Geri alma: 0033 + kolon drop. İlk `manual_refresh`'te retro pending düşer.
- **RLS/Güvenlik:** SECURITY DEFINER; kullanıcı yalnız kendi metriği; grup okuması `is_group_member`/`can_see_user_sessions` sınırında; XP yalnız claim'de (WP-209).
- **Edge-case'ler:** Gruptan ayrılmış üye, çoklu grup, aynı gün çoklu birincilik, gece yarısı sınırı, beraberlik, çok büyük geçmiş (perf/timeout — MK-4), manuel oturumların hariç tutulması (`source='live'`).
- **Kabul (ölçülebilir):** 6 gün grup birincisi test kullanıcısı `manual_refresh` sonrası `alpha_wolf` `metric_progress` ≥6, tier-1 **pending** düşer (banklanmaz); `campfire`/`locomotive` ≥1 ilerler; aynı çağrı iki kez pending/XP vermez; `metric_progress` gerçek değeri gösterir; perf p95 bütçe içinde; `flutter analyze` 0; `Cihazda doğrulanmalı`.
- **Tuzaklar:** Zaman-çakışması O(n²) patlaması (sweep-line kullan); İstanbul TZ/UTC karışımı; retro'nun mevcut XP'yi çifte saymaması; `joined_at`'e güvenmek (kullanma); `metric_progress` yerine tier yazmak (eski hata).

## WP-210: Başarım UI — canlı ilerleme + claim akışı + "az kaldı" + metin netleştirme (CLIENT) 🎨
- **Program/Faz:** Başarım · **Model:** 🟣 Pro · **Bağımlılık:** WP-208 (gerçek `metric_progress`) + WP-209 (claim RPC + pending stream)
- **Durum:** [ ] Bekliyor
- **Problem:** İlerleme temel hâli var ama sonraki kademe netliği zayıf, streak canlı değil, claim akışı + XP animasyonu yok, "az kaldı" yok, bazı açıklamalar belirsiz (Kusursuz Ay).
- **Kapsam dışı:** Profil dışı bildirim (WP-211), server metrik/claim mantığı (WP-208/209).
- **SAHİP dosyalar (yaz):**
  - `app/lib/features/profile/widgets/achievement_showcase.dart` (`metric_progress`'ten "26/30 · sonraki: Gümüş", canlı streak, claim düğmesi + XP animasyonu — `progress` alanını **`metric_progress`'e taşı**, tier-no'yu bar için kullanma)
  - `app/lib/features/profile/social_profile_screen.dart` (pending/claim bağlama + "az kaldı" minimal şerit — 1 başarı)
  - `app/lib/core/stats/progression_visuals.dart` (gerekirse)
  - `app/lib/l10n/app_en.arb`, `app/lib/l10n/app_tr.arb` (**ARB — bu WP tek ARB yazarı**; Kusursuz Ay="28+ gün", team_player metni hizala, claim/az-kaldı metinleri, saat-XP-otomatik açıklaması)
  - ilgili widget testleri
- **DOKUNMA (oku, değiştirme):** `home_shell.dart` (WP-211), server dosyaları, generated l10n.
- **Adımlar:**
  - [ ] "26/30 · sonraki: Gümüş" `metric_progress`'ten; tamamlanan kademe rozeti + o anki tier.
  - [ ] Canlı streak "7/10", kaçırınca 0 davranışı görünür.
  - [ ] Claim: pending ödülde "Topla" düğmesi/parıltısı; dokununca XP barı animasyonla artar, rozet açılır (mevcut confetti; ek paket yok). "Tümünü topla" seçeneği (claim_all).
  - [ ] "Az kaldı": profil üstünde en yakın **1** başarı için ince şerit (minimal).
  - [ ] Metin netleştirme: Kusursuz Ay="Bir ayda 28+ gün hedef tuttur" (sözlük "30 gün" çelişkisini düzelt), team_player açıklaması metriğe hizalı, saat-XP-otomatik notu.
  - [ ] Tema-güvenli (token renk), WCAG AA, 360/600/1200px taşma yok.
  - [ ] `flutter analyze` 0; showcase/claim/az-kaldı testleri yeşil.
- **Veri/Migration etkisi:** Yok.
- **Edge-case'ler:** Pending yokken düğme gizli, çok pending (tümünü topla), gizli başarı pending (silüet), başkasının profilinde claim gizli (`isSelf`), `metric_progress` null (fallback 0).
- **Kabul (ölçülebilir):** Pending dokununca ≤1 sn XP barı artar + rozet açılır; "26/30 · sonraki kademe" okunur ve **gerçek metriği** yansıtır; "az kaldı" ≤1 satır; Kusursuz Ay net; `flutter analyze` 0; `Cihazda doğrulanmalı`.
- **Tuzaklar:** Claim animasyonunu server yazımından önce oynatıp tutarsızlık (optimistic + doğrula); ARB'ye WP-213 ile aynı anda yazmak (serileştir); tier-no'yu progress bar'a sokmak (eski hata — `metric_progress` kullan); sabit renk (WP-141).

## WP-211: Başarı/taç bildirimi — açılış banner'ı + Brawl Stars nav-işaret (CLIENT) 🔔
- **Program/Faz:** Başarım · **Model:** 🟣 Pro · **Bağımlılık:** WP-209 (pending stream) — WP-208'den bağımsız
- **Durum:** [ ] Bekliyor
- **Problem:** Kullanıcı başarı açtığında/taç yükseldiğinde haberi olmuyor. İki mekanizma: (1) Clash tarzı açılış banner'ı; (2) Brawl Stars tarzı Profil sekmesi üstünde kalıcı nokta (pending>0), toplanınca kaybolur.
- **Kapsam dışı:** Claim mantığı (WP-209), profil içi liste/claim UI (WP-210), sistem push (ayrı iş).
- **SAHİP dosyalar (yaz):**
  - `app/lib/core/navigation/home_shell.dart` (pending banner + alt nav Profil nokta rozeti; **sıcak dosya — dar dokun**)
  - yeni `app/lib/features/profile/widgets/reward_toast.dart` (banner + nav-nokta bileşeni)
  - ilgili testler
- **DOKUNMA (oku, değiştirme):** `achievement_showcase.dart` (WP-210), ARB (WP-210 yazar — salt-oku), server dosyaları, `nav_index.dart` (oku).
- **Adımlar:**
  - [ ] Pending>0 olunca home üstünde küçük, kapatılabilir "n ödül hazır · Topla" banner'ı; dokununca profil başarı bölümüne götürür.
  - [ ] Alt nav Profil ikonunda nokta/sayı rozeti (pending>0), `claimableRewards` stream'inden reaktif; toplanınca kaybolur.
  - [ ] Taç yükselişinde tek seferlik kutlama (`_seenUnlockKeys` deseni).
  - [ ] WP-105 (oturum-bitti XP tetiği, parkta) ile aynı `home_shell` yüzeyi — salt pending-okuma, XP tetiğine dokunma.
  - [ ] `flutter analyze` 0; banner + nav-rozet görünürlük/temizlenme/tekrar-göstermeme testleri yeşil.
- **Veri/Migration etkisi:** Yok.
- **Edge-case'ler:** Açılışta birikmiş çok pending, banner spam'i (debounce/tek banner), banner kapanınca nav-rozet kalır (rozet pending'e bağlı), offline, gizli başarı pending'i (rozet sayılır, içerik silüet).
- **Kabul (ölçülebilir):** Yeni pending ≤5 sn'de banner + Profil noktası; toplanınca ikisi de kaybolur; taç bir kez kutlanır; `flutter analyze` 0; `Cihazda doğrulanmalı`.
- **Tuzaklar:** WP-105 ile `home_shell` çakışması (ayrı SAHİP mantık, dar dokun); nav-rozeti banner state'ine bağlamak (pending'e bağla); her tick'te banner tetikleme; ARB'ye yazmak.
- **> ⚠️ Çakışma:** WP-210 & WP-211 ikisi de Başarım UI hattı → tek lane'de sıralı (WP-211, WP-209 sonrası; WP-210 ile ARB'yi yalnız WP-210 yazar). SAHİP kesişmiyor (WP-210=showcase/social_profile, WP-211=home_shell/reward_toast).

## WP-212: Günlük yenilenen görev — bulut model + tekrar/tamamlama (DATA) 🗓️
- **Program/Faz:** Görevler (bağımsız hat B) · **Model:** 🟣 Pro (veri göçü + gün sınırı + çok-cihaz) · **Bağımlılık:** yok
- **Durum:** [ ] Bekliyor
- **Problem:** Görevler cihazda (prefs), tekrar yok. Kullanıcı sabit günlük rutinini her gün otomatik istiyor; telefon değişince kaybolmasın; streak tutulsun. Karar: bulut.
- **Kapsam dışı:** UI (WP-213), görev↔başarı bağlama.
- **SAHİP dosyalar (yaz):**
  - `supabase/migrations/00NN_user_tasks_cloud.sql` (yeni — `user_tasks` şablon + `user_task_completions` gün-damgalı; RLS own-rows)
  - `app/lib/data/models/user_task.dart` (recurrence/target/tombstone alanları)
  - `app/lib/data/repositories/user_task_repository.dart` + `supabase/` + `in_memory/` (gerçek bulut repo; prefs'ten göç)
  - `app/lib/data/providers/user_task_providers.dart`
  - ilgili testler
- **DOKUNMA (oku, değiştirme):** `tasks_card.dart`/Araçlar UI (WP-213), başarı dosyaları, diğer migration WP'leri (sıcak).
- **Adımlar:**
  - [ ] Şema: `user_tasks(id, user_id, title, due_at null, is_recurring bool, recurrence text null, target_count int null, sort_order, created_at, updated_at, archived_at null)`. `user_task_completions(id, task_id, user_id, day date, completed_at, UNIQUE(task_id, day))` — **`UNIQUE(task_id, day)` idempotency** (Codex). Composite FK / kontrol: completion `user_id` = task sahibi.
  - [ ] **Tek-seferlik görev tamamlama (Codex):** non-recurring görev de tamamlama = `user_task_completions` satırı (day = tamamlanma günü); "completed" durumu bu satırdan türetilir (ayrı `completed` bayrağı tutmak yerine tek kaynak) **veya** `user_tasks.completed_at` — WP'de tek yol seç ve tutarlı uygula (öneri: completions tek kaynak, hem tekrarlı hem tek-seferlik).
  - [ ] RLS: her tablo own-rows (insert/select/update/delete `user_id=auth.uid()`).
  - [ ] **Çok-cihaz senkron (Codex):** şablon düzenleme last-write-wins (`updated_at`); silme = **tombstone** (`archived_at`, hard-delete değil) → cihazlar arası silme yayılır; completions additif (union, `UNIQUE(task_id,day)` çift-yazımı engeller).
  - [ ] Prefs→bulut tek seferlik göç: `user_tasks_v2` okunur, buluta yazılır, **göç-tamamlandı bayrağı** ile çift-yazım engellenir; yarım-göç (offline) güvenli.
  - [ ] "Bugünün görevleri" türetimi: tekrarsız = eskisi gibi; tekrarlı = bugün completion yoksa aktif. 00:00 İstanbul = **kayıt silme yok** (gün-damgalı). Streak = ardışık gün completion.
  - [ ] Offline: çevrimdışı işaretlemeler kuyruğa, bağlanınca senkron.
  - [ ] `flutter analyze` 0; model/repo/gün-sınırı (TZ mock)/çok-cihaz-merge/tombstone testleri yeşil.
- **Veri/Migration etkisi:** İki yeni tablo + RLS. Geri alma: `drop table`. Kullanıcı SQL Editor'da uygular.
- **RLS/Güvenlik:** Own-rows zorunlu; PII yok; gün sınırı İstanbul (`istanbul_calendar.dart`).
- **Edge-case'ler:** 23:59→00:01 geçişi, cihaz TZ ≠ İstanbul, offline işaretleme sonra senkron, göç sırasında offline, iki cihazdan aynı görev düzenleme/silme, `maxTasks` sınırı.
- **Kabul (ölçülebilir):** Tekrarlı görev işaretlenince completed; ertesi İstanbul-günü 00:00'da tekrar aktif (kayıt silinmeden); telefon değişince rutin korunur; bir cihazda silinen görev diğerinde kaybolur (tombstone); streak doğru; `flutter analyze` 0, testler yeşil.
- **Tuzaklar:** 00:00'ı "kayıt sıfırlama" ile yapmak; prefs göçünde çift kayıt; hard-delete ile çok-cihaz silme kaybı; TZ/UTC gün kayması; tek-seferlik görevde iki farklı "completed" kaynağı (tek kaynak seç).

## WP-213: Görev UI — günlük tip ekleme + bugünün listesi + 00:00 yenileme (CLIENT) ✅
- **Program/Faz:** Görevler · **Model:** 🔵 Sonnet · **Bağımlılık:** WP-212
- **Durum:** [ ] Bekliyor
- **Problem:** Kullanıcı görev ekleme akışına "günlük yenilenen" tipini seçebilmeli; işaretleyince completed, ertesi gün geri gelsin. "Gerisi aynı, sadece yeni tip."
- **Kapsam dışı:** Bulut model/RLS (WP-212). Sayaçlı hedef ("25 paragraf" tek tek) opsiyonel — kullanıcı "üstüne basınca onaylansın" → basit onay yeterli (sayaç ayrı ürün kararı).
- **SAHİP dosyalar (yaz):**
  - `app/lib/features/home/widgets/tasks_card.dart` (bugünün tekrarlı görevleri)
  - Araçlar/Görevler CRUD ekranı ("Günlük yenilenen" seçeneği — grep: `features/**tools**`/`**tasks**`)
  - `app/lib/l10n/app_en.arb`, `app/lib/l10n/app_tr.arb` (**ARB — bu hat tek yazar**; "Günlük", "Her gün yenilenir")
  - ilgili widget testleri
- **DOKUNMA (oku, değiştirme):** WP-210 (başarım ARB yazarı — **aynı `app_*.arb` dosyası → Başarım ve Görev ARB'ye aynı anda yazamaz, serileştir**).
- **Adımlar:**
  - [ ] Ekleme akışına "Günlük yenilenen" anahtarı; kaydedince `is_recurring=true, recurrence='daily'`.
  - [ ] Home kartı: tekrarlı görevler bugünkü durumla; işaretleyince completed, 00:00'da geri (WP-212 türetimi).
  - [ ] Tekrarlı görevi rozet/ikonla ayırt et (🔁); streak varsa minimal gösterim (opsiyonel).
  - [ ] `flutter analyze` 0; ekleme + bugün-işaretle + ertesi-gün (TZ mock) testleri yeşil.
- **Veri/Migration etkisi:** Yok.
- **Edge-case'ler:** Gece yarısı açık ekran yenilenmesi (provider invalidation + app-resume — WP-212 türetiminden oku, UI'da manuel timer zorlama), karışık liste sıralaması, boş liste.
- **Kabul (ölçülebilir):** Günlük görev eklenir→bugün listede; işaretlenir→completed; ertesi İstanbul-günü aktif; tekrarsız eskisi gibi; `flutter analyze` 0; `Cihazda doğrulanmalı`.
- **Tuzaklar:** ARB'ye Başarım hattıyla eşzamanlı yazmak (serileştir); 00:00'ı UI manuel timer ile zorlamak.

## WP-214: Grup profil fotoğrafı (grup pp) (DATA + CLIENT) 🖼️
- **Program/Faz:** Sosyal gruplar (bağımsız hat C) · **Model:** 🟣 Pro (storage RLS + UI) · **Bağımlılık:** yok
- **Durum:** [ ] Bekliyor
- **Problem:** Grupların pp'si yok; liste/kamp ateşi/istatistik jenerik. Admin grup pp koyabilsin.
- **Kapsam dışı:** Üye avatar (var), grup banner, foto moderasyon (UGC ayrı — WP-115/125 deseni).
- **SAHİP dosyalar (yaz):**
  - `supabase/migrations/00NN_group_avatar.sql` (yeni — `groups.avatar_url text` + `groups.avatar_updated_at timestamptz` + `group-avatars` public bucket; yazma yalnız `is_group_admin`; okuma public; `discover_public_groups` **avatar_url dönecek şekilde güncellenir** — Codex)
  - `app/lib/data/models/group*.dart` (`avatarUrl`, `avatarUpdatedAt`)
  - `app/lib/data/repositories/**/*group*` (upload + url güncelle; çift repo)
  - grup ayarları/oluşturma UI + `class_switcher.dart` + grup listesi/kamp ateşi/istatistik başlığı
  - ilgili testler
- **DOKUNMA (oku, değiştirme):** başarı/görev dosyaları, `profiles` avatar akışı (desen referans, dokunma), diğer migration WP'leri (sıcak).
- **Adımlar:**
  - [ ] Migration: `groups.avatar_url` + `avatar_updated_at` + `group-avatars` bucket; RLS insert/update/delete yalnız `is_group_admin`; okuma public. **`discover_public_groups` avatar_url ekle** (aksi halde keşifte pp görünmez — Codex).
  - [ ] **Cache-busting (Codex):** sabit `<group_id>/avatar.jpg` yolu cache/realtime yenilemez → ya versiyonlu yol (`<group_id>/<timestamp>.jpg`) ya da `avatar_url`'e `?v=<avatar_updated_at>` query. WP'de tek yol seç.
  - [ ] Upload: admin ayarlarda foto seç → yükle → `avatar_url`+`avatar_updated_at` güncelle (profil avatar desenini yeniden kullan; boyut/tip sınırı).
  - [ ] Gösterim: switcher, keşif/liste, kamp ateşi başlığı, grup istatistik başlığı — `avatarUrl` varsa göster, yoksa mevcut fallback (baş harf/ikon).
  - [ ] Erişilebilirlik + tema-güvenli; büyük görselde cache/boyut.
  - [ ] `flutter analyze` 0; upload izin (admin/üye reddi), gösterim/fallback/cache-bust testleri yeşil.
- **Veri/Migration etkisi:** `groups.avatar_url`+`avatar_updated_at` + bucket/policy + `discover_public_groups` güncelleme. Geri alma: kolon+bucket+RPC eski sürüm.
- **RLS/Güvenlik:** Yazma yalnız admin (RLS + storage policy iki katman); okuma public. **Gizlilik notu (Codex):** gruplar varsayılan private ama keşif RPC'si zaten ad/üye sayısı ifşa ediyor; grup avatarı keşifte görünecek → public bucket bilinçli karar, dokümante. `is_group_admin` = **yalnız oluşturan** (tek-sahip modeli, `0004:19`) — rol tabanlı admin ileride ayrı iş. Üye admin değilse upload reddi + UI hata (WP-109 B7: sessiz başarı yok).
- **Edge-case'ler:** Admin olmayan upload denemesi, grup silinince avatar temizliği, çok büyük dosya, eski url cache (cache-bust çözer), public bucket kötüye kullanımı (boyut/tip sınırı).
- **Kabul (ölçülebilir):** Admin pp yükler → tüm yüzeylerde (keşif dâhil) ≤5 sn görünür; yeni yükleme eski cache'i **geçersiz kılar** (cache-bust); üye (admin değil) yükleyemez (RLS reddi + UI hata); avatar yoksa fallback bozulmaz; `flutter analyze` 0; `Cihazda doğrulanmalı`.
- **Tuzaklar:** Storage policy'de `is_group_admin` yerine yalnız auth (herkes yazar); sabit yol → cache bayat; `discover_public_groups`'u güncellememek (keşifte pp yok); tip/boyut sınırsız.

## WP-215: Aktif sekmeye tekrar basınca en yukarı çık — tüm sekmeler (CLIENT) ⬆️
- **Program/Faz:** IA/Navigasyon cilası (bağımsız hat D, küçük, düşük risk) · **Model:** 🔵 Sonnet · **Bağımlılık:** yok · **Not:** WP-211 (`home_shell`) ile SAHİP kesişimini önlemek için **kesin ekran-kökü dosyaları** aşağıda; `core/navigation/**`'a yazmaz.
- **Durum:** [ ] Bekliyor
- **Problem:** "Tap-to-top" yalnız Ana Sayfa'da (`home_screen.dart` `navReselectProvider` dinliyor). Gruplar, İstatistikler, Profil, Araçlar'da yok. Altyapı **var** (`nav_index.dart` her sekme tekrar-basımında `navReselectProvider`'ı `(tabIndex, tick)` ile tetikliyor) — yalnız dinleyici bağlanacak.
- **Kapsam dışı:** Yeni navigasyon mimarisi, animasyon süresi, Ana Sayfa mevcut davranışı, `home_shell.dart` (WP-211 sahibi — **yazma**).
- **SAHİP dosyalar (yaz) — kesin ekran kökleri (grep ile teyit, WP-210/214 SAHİP'leriyle kesişmeyen kök scroll dosyaları):**
  - Gruplar sekmesi kök ekranı (`features/classroom/**` ana scroll ekranı — kök ScrollController; WP-214 `class_switcher.dart`'a dokunuyor, WP-215 **switcher'a değil sekme kök scroll'una** yazar)
  - İstatistikler sekmesi kök ekranı (`features/stats/**` ana scroll)
  - Profil sekmesi kök ekranı (`features/profile/**` ana scroll; WP-210 `achievement_showcase`/`social_profile_screen`'e yazıyor → WP-215 **farklı kök scroll dosyasına** yazmalı; kesişirse WP-210 sonrası sıraya al)
  - Araçlar sekmesi kök ekranı (gerçek kök: `clock_screen.dart` — grep `features/**clock**`/`**tools**` ile teyit)
  - ilgili testler
- **DOKUNMA (oku, değiştirme):** `nav_index.dart` (oku — desen), `home_screen.dart` (dokunma), `home_shell.dart` (WP-211).
- **Adımlar:**
  - [ ] Her sekme ekranı kökünde `ref.listen(navReselectProvider, ...)`; `tabIndex == kendi indeksi` ve tick arttıysa `animateTo(0)` (home deseni). **Tab indeksini hardcode etme** — `nav_index.dart` sabitlerinden oku.
  - [ ] Her ekranın kök kaydırıcısını bul/normalize et (nested scroll varsa dış controller — WP-172 dersi).
  - [ ] `flutter analyze` 0; her sekme "tekrar bas → offset 0" testi yeşil.
- **Veri/Migration etkisi:** Yok.
- **Edge-case'ler:** Nested scroll (Gruplar), zaten en üstteyken (no-op), liste boş, ekran build olmadan tick.
- **Kabul (ölçülebilir):** Gruplar/İstatistik/Profil/Araçlar'da aşağı kaydırıp sekmeye tekrar basınca ≤300 ms'de en üste; Ana Sayfa regresyonsuz; `flutter analyze` 0; `Cihazda doğrulanmalı`.
- **Tuzaklar:** Ayrı ScrollController tutup PrimaryScrollController ile çakışmak; nested'de yanlış controller; `home_shell`'e yazıp WP-211 çakışması; tab indeksi hardcode; WP-210/214 SAHİP dosyalarıyla kesişmek (kök scroll dosyası ayrı olmalı — kesişirse ilgili WP sonrası sıraya al).
- **> ⚠️ SAHİP hassasiyeti (Codex):** `features/profile/**` (WP-210), `features/classroom/**` & `features/stats/**` (WP-214) hatlarıyla klasör paylaşır. Kesişim **dosya bazında** yoksa (WP-215 yalnız kök scroll dosyaları) paralel güvenli; kesişim varsa o hat sonrası sıraya al. Claim anında kesin dosya listesiyle teyit.

---

## Çakışma matrisi (v2)

- **Migration sıcak yüzey:** `supabase/migrations/**` tamamı sıcak (`AGENTS.md:83`). **WP-208/209/212/214/216'nın hiçbiri aynı anda açık olamaz** — yalnız numara değil tüm migration yüzeyi. Migration WP'leri **tek tek serileştirilir**; numara claim anında `progress.md`'den teyit (numara kontrolü TOCTOU'yu çözmez → tek-lane serileştirme çözer).
- **Başarım iç yayın sırası:** **WP-209 → WP-216 → WP-208 → WP-210**; WP-211 yalnız WP-209'a bağlı. (Numara ≠ sıra — üstteki banner.)
- **ARB sıcak:** WP-210 (başarım) ve WP-213 (görev) ikisi de `app_*.arb` yazar → aynı anda yazamaz; serileştir.
- **Görev iç sıra:** WP-212 → WP-213.
- **`core/navigation/**` sıcak:** WP-211 buraya yazar (`home_shell`); WP-215 **yazmaz** (ekran köklerine yazar) → SAHİP kesişimi yoksa paralel; yine de her ikisi navigasyon davranışına dokunduğundan claim'de kesin dosya teyidi.
- **Grup PP:** WP-214 bağımsız; migration sıcak yüzey dışında başka hatla SAHİP kesişimi yok.
- **Hat sayısı:** Başarım = 1 lane (kendi içinde 209→216→208→210/211 sıralı). İkinci lane = Görev **veya** Grup PP **veya** WP-215.
- **Git:** tek `main`, branch yok (`AGENTS.md:85`). ⚠️ **CLAUDE.md** "WP başına ayrı dal aç" diyor — bu `.agents/AGENTS.md §1.5` ile **çelişiyor**; ürün sahibi hangisi kanon karar vermeli (öneri: AGENTS.md kanon, CLAUDE.md güncellensin). Bu plan AGENTS.md'yi izler: dal yok.
- **Parktakiler:** WP-105 (`home_shell`, test bekliyor) WP-211 ile aynı dosya ama parkta → bloklamaz; WP-211 dar dokunur.

## Model önerileri özeti
- 🔴 Opus: WP-208, WP-209, WP-216 (server-authoritative XP + retro + RLS güvenlik).
- 🟣 Pro: WP-210, WP-211, WP-212, WP-214.
- 🔵 Sonnet: WP-213, WP-215.

---

# DENETÇİ (SENIOR) İÇİN — okuma listesi, mimari gerekçe, riskler

> Bu bölüm planı **tek başına denetlenebilir** kılmak için. Codex denetimi (tur 1) yanıtı: `docs/features/DENETIM-YANIT-CODEX-01.md`.

## 1. İddiaları doğrulamak için okunacak mevcut kod

| Ne doğrulanır | Dosya |
|---|---|
| Ölü başarılar (`then 0`) | `0033_study_hour_xp_50.sql`, `0025_achievements_social_metrics.sql:255`, `process_achievement_event` `when 'alpha_wolf' then 0` |
| Ledger append-only + `AFTER INSERT` XP bankalama (claim mimarisi buna dayanır) | `0024_achievements_ledger.sql:210` (trigger), `:186` (max_tier projeksiyonu), `:194` (progress=tier) |
| Server progress = tier-no (gerçek metrik değil — bulgu #3) | `0024:194` + `achievement_showcase.dart:1038` (`userAch?.progress`) |
| Oturum fabrikasyonu açığı (bulgu #4) | `0001_initial_schema.sql:179` (`sessions_insert` yalnız `user_id=auth.uid()`) |
| `joined_at` yeniden katılımda eziliyor (retro güvenilirliği) | `0012_group_join_hardening.sql:121` |
| `is_group_admin` = yalnız oluşturan | `0004_group_admin.sql:19` |
| `discover_public_groups` avatar döndürmüyor | `0032_public_group_discovery.sql:142` |
| Kusursuz Ay = 28 gün (sözlük "30 gün" çelişki) | `0024:509`, `achievement_ledger_engine.dart:436` |
| Görevler prefs'te, "Tekrar yok" | `user_task.dart:5`, `user_task_providers.dart` |
| Tap-to-top altyapısı var | `nav_index.dart`, `home_screen.dart` |
| Sıcak dosyalar + git kuralı | `.agents/AGENTS.md:83`, `:85` |

## 2. Mimari gerekçe (v2 — neden böyle)

- **Claim = ayrı `achievement_rewards` tablosu (MK-1):** `xp_ledger` literal append-only + insert-banks korunur; pending kazanımlar ayrı kişisel gelen kutusunda; claim = ledger'a aynı `event_key` ile insert (mevcut trigger bankalar). Rozet tier'ı yalnız ledger'dan (claimed) türediği için pending rozet fırlatmaz. **Codex bulgu #1 (WP sırası) ve #2 (trigger/max_tier/append-only) yapısal olarak çözülür**; kitlesel XP-kaybı riskli backfill **elenir** (mevcut ledger zaten "toplanmış").
- **Gerçek progress (MK-2):** `user_achievements.metric_progress` kolonu; server her başarı için gerçek metriği upsert eder; UI "26/30"'u buradan okur (tier-no'yu değil).
- **Oturum bütünlüğü (MK-3/WP-216):** sosyal başarılar gerçek XP'ye bağlanmadan fabrikasyon kapatılır; retro doğrudan `study_sessions`'tan türer (`joined_at` güvenilmez).
- **Retro perf (MK-4):** sweep-line/iki-pointer + backfill checkpoint + `EXPLAIN ANALYZE` p95 bütçe.
- **Görev 00:00 (değişmez):** gün-damgalı completion, silme yok, streak doğal + tombstone çok-cihaz silme.

## 3. En büyük riskler (denetçi öncelikli baksın)

1. **Claim mimarisi geçişi (WP-209):** `process_achievement_event`'te "zaten ledger'da olan tier'a pending yaratma" guard'ı — yanlışsa eski kullanıcıya sahte pending. Uzlaştırma testi (`profile.xp == SUM(ledger)`) şart.
2. **Retro performans (WP-208):** sweep-line/kayan pencere + checkpoint; `EXPLAIN ANALYZE` p95/timeout kabul kriteri.
3. **Oturum bütünlüğü (WP-216):** meşru kronometre/manuel akışı kırmadan sıkılaştırma; `NOT VALID` ile mevcut kayıtları patlatmama.
4. **Migration serileştirme:** 5 WP migration ekler; tümü sıcak yüzey → tek-lane, numara `progress.md` teyidi.
5. **ARB çakışması:** WP-210 & WP-213 aynı `app_*.arb`; serileştir.
6. **`home_shell` sıcak:** WP-211 + park WP-105; WP-215 buraya yazmaz.

## 4. Açık ürün/mikro kararlar (Codex haklı — "açık uç kalmadı" düzeltildi)

MK-5'te varsayılanlar verildi; ürün sahibi teyidi beklenenler: Alfa Kurt beraberlik/çoklu-grup/gün-kapanışı · Lokomotif boş-grup tanımı · manuel oturum sosyal başarıya dâhil mi (öneri: hayır) · kazanım sonrası oturum silme XP iadesi (öneri: iade yok) · team_player metrik-mi-metin (öneri: metin) · toplu claim (öneri: var) · CLAUDE.md↔AGENTS.md dal çelişkisi (öneri: AGENTS.md kanon).

## 5. Kapsam bütünlüğü — kullanıcıyla konuşulan her madde bir WP'de

| Konuşulan istek | WP |
|---|---|
| Canlı ilerleme (26/30 + rozet) — **gerçek metrik** | WP-208 (server progress) + WP-210 (UI) |
| Canlı streak (7/10) | WP-210 |
| Topla-ödülü-al, gerçek toplama (C) | WP-209 (+UI WP-210) |
| Toplamamak ilerlemeyi durdurmaz (battle-pass) | WP-209 (MK-1) |
| Ölü başarı fix: Alfa Kurt/Kamp/Lokomotif | WP-208 |
| Mola Düşmanı (5h'te ≥4.5h) | WP-208 (karar #2) |
| Retroaktif geçmiş sayımı | WP-208 (pending) |
| team_player anlam | WP-208 (metrik) + WP-210 (metin) |
| Açıklama netleştirme (Kusursuz Ay) | WP-210 |
| "Az kaldı" minimal şerit | WP-210 |
| Başarı/taç bildirimi (Clash) | WP-211 |
| Brawl Stars nav-nokta | WP-211 |
| Günlük görev, bulut, 00:00 | WP-212 + WP-213 |
| Görev streak | WP-212 |
| Grup pp | WP-214 |
| Tap-to-top tüm sekmeler | WP-215 |
| **(yeni) Oturum fabrikasyonu kapatma** | WP-216 |

Konuşulan tüm maddeler + Codex'in ortaya çıkardığı bütünlük/güvenlik boşlukları planlandı. Açık **mikro** kararlar MK-5'te varsayılanlarıyla listelendi (ürün sahibi itiraz edebilir).
