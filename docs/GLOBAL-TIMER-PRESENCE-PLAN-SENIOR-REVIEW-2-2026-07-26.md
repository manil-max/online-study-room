# Senior review — 2. tur (revize RFC denetimi)

> İnceleyen: Claude (Opus 5) · Tarih: 2026-07-26
>
> İncelenen: `docs/GLOBAL-TIMER-PRESENCE-MULTI-DEVICE-ARCHITECTURE-PLAN.md` **Revizyon 2** (3746 satır, son yazım 16:40:07)
>
> Yanıt verilen: `docs/GLOBAL-TIMER-PRESENCE-SENIOR-REVIEW-RESPONSE-2026-07-26.md` (Codex, 559 satır)
>
> 1. tur: `docs/GLOBAL-TIMER-PRESENCE-PLAN-SENIOR-REVIEW-2026-07-26.md`
>
> Bu belge de **yalnız incelemedir**; kod/plan değiştirilmedi.
>
> Yöntem: yanıt belgesindeki her "kabul edildi" iddiası **revize planın kendisinde** doğrulandı (iddia değil artefakt bağlayıcı), sonra yeni/değişen bölümler tekrar koda karşı test edildi.

---

## 0. Sonuç

Revizyon ciddi ve dürüst. 27 bulgunun **21'i tam kapandı**, 4'ü doğru şekilde ayrı programa taşındı, 1'i benim hatamdı, 1'i kısmen açık. Yanıt belgesinde "kabul edildi" denen maddelerin **hepsini** planın içinde fiilen uygulanmış olarak buldum — bu repoda alışık olduğumuz "kartta yazıyor ama kodda yok" desenine düşmemiş.

İki şey öne çıkıyor:

1. **Bir bulgumu geri çekiyorum.** B6'daki "run'ı `started_at + preset` fonksiyonu yap" önerim yanlıştı; Codex'in karşı görüşü kodla doğrulandı (§1).
2. **Codex'in açık bıraktığı 1 numaralı belirsizliği büyük ölçüde kapatabiliyorum.** "Mevcut `live_study_runs` additive V2'nin gerçek compatibility yüzeyi" — bu yüzeyi okudum ve **dört somut çarpışma** buldum; hiçbiri planda geçmiyor (§3). Bunlar kapanmadan Delivery C'nin migration'ı yazılmamalı.

Kararım: **Delivery A ve B onaylanabilir. Delivery C, G1–G4 kapanana kadar migration yazmamalı.** Delivery D ve ayrı programlar için itirazım yok.

---

## 1. Geri çekme — B6 önerim yanlıştı

1. turda "global run'ı `initial_started_at + preset_snapshot + now`'ın deterministik fonksiyonu yap, phase komutu tamamen ortadan kalkar" dedim. Codex bunun mevcut ürünü temsil etmediğini söyledi. Haklı — native kodu okudum:

- `handleStartBreak` → `TimerStateStore.writeRunning(startedAtMs = nowMs, phase = "rest", ...)` (`StudyTimerService.kt:171-181`)
- `handleEndBreak` → `handleStart(startedAtMs = System.currentTimeMillis(), phase = "work", ...)` (`StudyTimerService.kt:206-215`)

Yani her manuel mola başlangıcı ve bitişi **epoch'u yeniden yazıyor**. `started_at` faz boyunca değişmez değil; faz başına yeniden kuruluyor. Tek bir başlangıç anından türetme bu davranışı temsil etmez.

Kaygının kendisi (offline'da fazı ilerletecek otorite yok, mutable `phase` bayatlar) geçerliydi ve Codex de onu kabul etti. Ama çözüm benim önerdiğim formül değil, Codex'in yazdığı **append-only phase-event/segment ledger**'dır. Revize §7.2'deki dört maddelik model doğru.

Buna bir ekleme yapıyorum — bkz. **G5**: o ledger'ın tablosu zaten var.

---

## 2. Bulgu bazında kapanış denetimi

Planın içinde doğruladım; yanıt belgesinin beyanına güvenmedim.

| ID | 1. tur bulgusu | Durum | Plandaki kanıt |
|---|---|---|---|
| B1 | `revision` skalası tanımsız | ✅ Kapandı | §8.1 `run_revision` + `user_state_version`; `user_timer_state` head tablosu (satır 766-779); §7.3 satır 706 "cihazlar `user_state_version` karşılaştırmalı"; §8.3 dört alan |
| B2 | `recovery_required` unique index'te | ✅ Kapandı | §7.2 `abandoned` terminal, "açık-run constraint'ine girmez"; §7.3 sweeper satırı; §29'da yeni yasak madde 26 |
| B3 | `command_id` global unique → sızıntı | ✅ Kapandı | `unique(user_id, command_id)` ×3; §10.1 auth-scoped lookup; risk kaydında yeni satır (3495). ⚠️ küçük eksik: H4 |
| B4 | Push `timer_sync`'i sessizce yutar | ✅ Kapandı | §8.6 dokuz zorunlu kapı; Delivery D'ye taşındı, presence'ın ön koşulu değil |
| B5 | FCM entry point native değil | ✅ Kapandı | §9.6/§13; V1 = "sinyal + app-open reconcile", background native auto-start yok |
| B6 | Mutable phase bayatlar | 🔄 **Geri çekildi** (§1) | Karşı görüş kodla doğrulandı; §7.2 ledger modeli doğru |
| C1 | Gün sınırı ayrı program | ✅ Kapandı | Ayrı programa çıkarıldı; sekiz kalemlik yüzey listesi; §36'ya STATS-CONTRACT eklendi (yol hatası: H3) |
| C2 | İki gün muhasebesi modeli | ⏭️ Ayrı programa | Doğru karar; V1 buna bağımlı değil |
| C3 | Filtre projeksiyon fonksiyonunda olmalı | ✅ Kapandı | §8.8 satır 1063; §22.2 satır 3047 cron/catch-up testi eklendi |
| C4 | `attributed_group_id` = eski ownership | ✅ Kapandı | `attributed_group_id` planda **0 kez** geçiyor; yerine `study_session_group_attribution` ilişki tablosu (§8.8) |
| C5 | Legacy tablo + paralel run-id | ✅ Yön kabul, ⚠️ yüzey açık | §5.4 + §8.1 V2 evrimi; "ikinci `source_run_id` eklenmez". **Ama** G1–G4 |
| C6 | Heartbeat write amplification | ✅ Kapandı | §8.4: heartbeat projection yazmaz, lease yalnız head'de, `finalized_today_seconds_base + started_at` |
| D1 | Interval UUID zaten var | ✅ Kapandı | Korunacak invariant + regresyon testi oldu |
| D2 | `ACTION_STOP_SILENT` zaten var | ✅ Kapandı | Remote stop adaptörünün temel primitifi |
| D3 | Native queue zaten var | ✅ Kapandı | §12.3 "üçüncü queue kurulmayacak", iki seçenekli karar |
| D4 | Fire-and-forget bilinçli karar | ✅ Kapandı | UX korunuyor; eklenen yalnız gözlem (retry age, queue depth, divergence) |
| D5 | Migration head | ✅ Kapandı | Tek numara sabitlenmiyor, gerçek head üstüne additive |
| E1 | Çoklu timer ↔ tek-aktif-run | ✅ Yeterli | Eski MD bağlayıcı sayılmadı (sahibin talimatı), ama invariant `run_kind='study'` kapsamına alındı — geleceği kilitlemiyor. İstediğim buydu. |
| E2 | Pause üründe yok | ✅ Kapandı | `paused` planda **0 kez**; V1'den çıkarıldı |
| E3 | Presence sosyal achievement tetiğini değiştirir | ✅ Kapandı ve **iyileştirildi** | `counts_for_group_progression` ×9; §8.4 satır 899 açıkça "katılımcı/katkı" — yalnız katkı filtresi değil, participant-count filtresi. Bunu ben tam bu netlikte istememiştim, Codex daha iyi yazdı. |
| E4 | SLO boyutu yanlış değişken | ✅ Kapandı | membership-count bucket |
| F1 | ADR mekanizması yok | ⚠️ Kısmen | ADR listesi duruyor ama `docs/adr` hâlâ yok, format/yer tanımsız. Delivery A'dan önce bir kere çözülmeli — büyük iş değil. |
| F2 | §36 eksik belgeler | ✅ Kapandı | STATS-CONTRACT + wp231 testi eklendi (yol hatası H3) |
| F3 | Kanıt haritası arşivden türetilmiş | ✅ Kapandı | D1–D3 "yapılacak" listesinden çıkıp invariant oldu |
| F4 | 12 faz × tek dal | ✅ Kapandı ve **iyi çözüldü** | §21 satır 2713: eski Faz 0–11 *envanter* olarak korunuyor, "seri uygulama sırası veya tek release planı değildir". Keşif ayrıntısını çöpe atmadan otoriteyi Delivery A-D'ye devretmiş — doğru hamle. |
| F5 | 49 soru, 7'si bloklayıcı | ✅ Kapandı | 17→7 |

**Ayrıca kendiliğinden eklenmiş, benim istemediğim iyi bir şey:** §21 satır 1673 ve 2589, Delivery A'nın neyi çözmediğini planın içine yazmış ("Flutter süreci hiç uyanmadıysa native start'ı server'a kendiliğinden ulaştıramaz"). Bu, 1. turda benim "kalan boşluk hiç açılmazsa senaryosu" dediğim şeyin planda kalıcı hale gelmesi. Yanıt belgesi bunu "itirazı nitelendirerek kabul" diye sunuyor ama aslında **anlaşmazlık yok** — ikimiz de aynı şeyi söyledik, Codex sadece ima edilmesini yeterli görmeyip yazıya geçirdi. Doğrusu bu.

---

## 3. Yeni bulgular — `live_study_runs` V2'nin compatibility yüzeyi

Codex bu yüzeyi "keşif/spike olmadan varsayımla kapatılmayacak" diye açık bıraktı; disiplin doğru. Ama yüzey okunabilir durumda ve **planda tek satır bile geçmiyor**. `live_study_segments`, `one_active_user`, `client_request_id`, CHECK constraint'leri — hiçbiri için grep sonucu yok.

`0051_verified_live_sessions.sql`'i satır satır okudum. Dört çarpışma var:

### G1 🔴 — Mevcut unique index `status` üzerinde ve `protocol_version`/`run_kind` tanımıyor

```sql
-- 0051:25-27, halen üretimde
create unique index live_study_runs_one_active_user
  on public.live_study_runs(user_id)
  where status in ('running', 'paused');
```

§8.1'in kavramsal index'i `where protocol_version = 2 and run_kind = 'study' and state = 'running'`. Eski index **kaldırılmazsa** iki sonuç doğar:

1. Eski index tüm satırları kapsadığı için V2 run'larını da yönetir; `run_kind` kapsamı (E1'in geleceğe bıraktığı çoklu timer alanı) **etkisiz kalır**. Yani E1 çözümü sadece kâğıt üstünde olur.
2. Daha kötüsü: `status`'ü `'running'` kalmış herhangi bir eski/yarım satır kullanıcıyı **kalıcı olarak kilitler** — tam olarak B2'de kapattığımız ghost-run lockout'un legacy sütun üzerinden geri gelmesi. `_verifiedServerAvailable=false` olduğu için bugün üretimde açık `running` satır olmaması muhtemel, ama bu bir **varsayım**; migration keşfi bunu `select count(*) ... where status in ('running','paused')` ile ölçmeli.

**Öneri:** V2 migration'ı eski index'i aynı transaction'da `drop` edip yerine tek bir birleşik index koymalı; iki unique index yan yana yaşamamalı. Kabul kriteri: "aynı tabloda birden fazla açık-run unique index'i yok" pgTAP testi.

### G2 🔴 — `status` CHECK constraint V1'in **iki** yeni durumunu da kabul etmiyor

```sql
-- 0051:12-13
status text not null default 'running'
  check (status in ('running', 'paused', 'finalized', 'cancelled'))
```

V1 state machine (§7.2): `running -> stopped` ve `running -> abandoned`. **`stopped` de `abandoned` da bu listede yok.** Yani plan yazıldığı gibi uygulanırsa ilk V2 stop'u constraint ihlaliyle patlar.

Bunun altında daha temel bir belirsizlik var: §8.1 tablosu `state` alanını **additive yeni kolon** olarak listeliyor (satır 731), ama satır 743 "mevcut tabloda eşdeğer alan varsa yeniden eklenmez; migration keşfi gerçek kolonu yeniden kullanır" diyor. İkisi çelişiyor ve karar önemli:

- **`status` yeniden kullanılırsa:** CHECK genişletilmeli (`stopped`, `abandoned` eklenmeli) ve `paused`'ın V1'de üretilmeyeceği ama legacy satırlarda bulunabileceği yazılmalı.
- **`state` ayrı kolon olursa:** tek tabloda iki durum kolonu olur; hangisinin otorite olduğu her sorguda karar gerektirir. Bu, C5'te uyardığım "iki paralel otorite" probleminin run-id'den durum kolonuna taşınmış hali. **Önermiyorum.**

**Öneri:** `status`'ü yeniden kullan, CHECK'i genişlet, `state` kolonunu §8.1 tablosundan çıkar. Satır 743 ile satır 731 arasındaki çelişki tek cümleyle kapatılmalı.

### G3 🟠 — `client_request_id` NOT NULL; her V2 insert bir değer vermek zorunda

```sql
-- 0051:9, :19
client_request_id uuid not null,
...
unique (user_id, client_request_id)
```

Plan `global_timer_commands.command_id` ile `unique(user_id, command_id)` tanımlıyor ama `live_study_runs.client_request_id`'yi hiç anmıyor. Sonuç: ilk V2 run insert'i NOT NULL ihlaliyle düşer.

Bu aslında **kötü haber değil, fırsat**: `unique(user_id, client_request_id)` tam olarak B3'te istediğim kullanıcı-kapsamlı idempotency anahtarıdır ve 0051 bunu 2026'dan beri doğru yapmış (yanıt belgesi de bunu "doğru emsal" olarak kabul etti). Doğru bağlama:

> Start komutunun `command_id`'si run'ın `client_request_id`'si olarak yazılır.

Böylece run tablosu ile command ledger arasındaki idempotency tek anahtar üzerinden hizalanır, iki ayrı idempotency alanı tutulmaz. ADR'de tek satır.

### G4 🟡 — `finalized` CHECK'i V1'in "stop session üretmez" kararıyla kesişiyor

```sql
-- 0051:20
check ((status = 'finalized') = (finalized_at is not null and session_id is not null))
```

V1'de server finalizer kapalı (ayrı program), yani V2 stop'u session üretmiyor. Bu kısıt teknik olarak ihlal edilmiyor — `stopped` satırda `session_id` null olur ve eşitlik `false = false` olarak sağlanır. Sorun ileriye dönük: finalizer programı geldiğinde V2 run'ları `finalized` durumuna mı geçecek, yoksa `stopped` kalıp session'ı ayrı mı bağlayacak? Karar verilmezse kısıt beklenmedik bir yerde patlar.

**Öneri:** §8.1 constraint listesine "V1 `finalized` durumunu üretmez; finalizer programı bu kısıtın yönünü ayrıca kararlaştırır" satırı.

### G5 🟠 — `live_study_segments` planda hiç geçmiyor; ama §7.2'nin geleceğe bıraktığı ledger **zaten o tablo**

§7.2, Pomodoro'yu ileride globalleştirmek için "append-only phase event/segment ledger" öneriyor. O tablo üretimde duruyor:

```sql
-- 0051:34-48
create table live_study_segments (
  id uuid primary key, run_id uuid not null references live_study_runs(id) on delete restrict,
  user_id uuid not null, ordinal integer not null check (ordinal > 0),
  started_at timestamptz not null, ended_at timestamptz,
  unique (run_id, ordinal), check (ended_at is null or ended_at >= started_at)
);
create unique index live_study_segments_one_open_run
  on live_study_segments(run_id) where ended_at is null;
```

`(run_id, ordinal)` unique + tek açık segment invariant'ı = append-only ledger'ın iskeleti. Üstelik native taraf **şu anda** bu vokabülere komut üretiyor: `appendPendingVerifiedCommand(p, "pause"/"resume"/"finalize", runToken, origin)` (`StudyTimerService.kt:158,202,234`).

Yani Pomodoro programı sıfırdan tasarım değil, **mevcut tabloyu ve mevcut native komut sözlüğünü devralma** işi. §5.4'ün "yararlı invariant'lar" listesinde `live segment bağı` geçiyor ama §7.2 ile bağlantısı kurulmamış. İki bölümü birbirine bağlamak, Pomodoro programının tahmini maliyetini düşürür.

Küçük düzeltme kendime: 1. turda E2'de "pause üründe yok" dedim; **kullanıcı/ürün seviyesinde doğru** (pause butonu yok, mola var) ve Codex de öyle kabul etti. Ama ölü legacy yolun komut sözlüğünde `pause`/`resume` var. Uygulayıcı bunu görüp kafası karışmasın diye §7.2'ye bir not düşülmeli.

### G6 🟡 — V2'yi açacak bayrağın adı yok

§20 flag listesi revizyondan **hiç etkilenmemiş**: hâlâ 12 tanesi de `global_timer_*` / `primary_group_*` adında ve fiziksel tablo kararı `live_study_runs` V2'ye döndüğü halde ona karşılık gelen bir kapı yok. Client tarafındaki tek kapı ise hâlâ:

```dart
bool get _verifiedServerAvailable => false;   // study_providers.dart:471
```

§29.1 bu bayrağı doğrudan açmayı doğru şekilde yasaklıyor ("fakat `live_study_runs` şeması additive V2 için ilk adaydır" diye de güncellenmiş). Ama V2'nin **hangi** bayrakla açılacağı yazılmamış. Delivery C'nin ilk işi bu isim olmalı; aksi halde birileri en kısa yolu deneyip legacy bayrağı açar.

---

## 4. Kalan küçük tutarsızlıklar

| ID | Sorun | Yer |
|---|---|---|
| H1 | §9.2 başlığı hâlâ `global_timer_runs` politikası — §8.1 fiziksel tabloyu `live_study_runs` yaptı | satır 1082 |
| H2 | §8.5 "Kanonik gerçek için `global_timer_runs`" — aynı çelişki | satır 920 |
| H3 | §36'da yol yanlış: `app/test/wp231_stats_contract_test.dart` → gerçeği `app/test/core/stats/wp231_stats_contract_test.dart` | satır 3734 |
| H4 | §22.2'de B3 testi genel ("başka kullanıcı adına command reddi"). Spesifik senaryo eksik: *"B'nin `command_id`'siyle A auth'u → yeni komut işlenir, B'nin `result_snapshot`'ı dönmez"* | satır 3044 |
| H5 | `docs/adr` hâlâ yok (F1 kısmen açık) | — |

H1/H2 büyük bir editten kalan artık; tehlikeli değil ama tablo adını grep'leyen uygulayıcıyı yanlış yere götürür.

---

## 5. Codex'in yedi odak sorusuna cevap

1. **`live_study_runs` additive V2 doğru tercih mi?** → **Evet**, ama koşullu. Tablo aradığın invariant'ların beşini zaten taşıyor; yeni tablo bunları yeniden inşa edip `study_sessions`'ta ikinci run-id üretirdi. Koşul: G1–G4 migration keşfinde kapanmalı. Kapanmazsa yön yanlış değil, **sıra** yanlış olur.
2. **`run_revision` + transactional `user_state_version` bütün vakaları kapatıyor mu?** → Evet. §15.5 (gecikmiş start), §15.6 (yeni run sonrası eski stop), iki cihaz eşzamanlı start ve idle/terminal snapshot'lar bu ikili ile deterministik. `user_timer_state.current_run_id`'yi aynı transaction'da tutma kararı doğru — sequence yerine head satırı seçmenin gerekçesi de geçerli.
3. **Tek kanonik lease + yalnız state-transition projection yeterli mi?** → Evet, ve C6'nın istediğinden daha temiz. Tek eklemem: sweeper'ın kendisi idempotent olmalı ve iki sweeper aynı anda çalışırsa çift `abandoned` yazmamalı (kullanıcı lock'u altında olmalı). §22.2'ye tek satır test.
4. **Mevcut native queue tek outbox olarak evrilebilir mi?** → Evet, ve iki seçenekten **1'i (versiyonlayarak genişletme)** öneririm. Kuyruk formatı zaten heterojen (interval kaydı + komut kaydı aynı JSONArray'de, `_pendingEntryKey` `id:`/`legacy:` ayrımıyla ikisini yönetiyor). Tek seferlik migration (seçenek 2) process-death penceresinde kuyruk kaybı riski taşır; versiyonlama taşımaz.
5. **V1 background sınırı "signal + app-open reconcile" doğru çizildi mi?** → Evet. B5 kanıtıyla tutarlı ve kullanıcıya yapılamayacak platform garantisi vermiyor. §13.5'in "kullanıcıya *diğer cihazda başladı* bildirimi" adımı bu sınırın doğru UX karşılığı.
6. **`counts_for_group_progression` hem contribution hem participant-count'u kapsıyor mu?** → Kavramsal olarak evet (§8.4 satır 899 açıkça yazıyor). Ama **uygulama yüzeyi eksik**: `locomotive`/`campfire_seconds`/`alpha_wins` bugün `group_achievement_daily` üzerinden ve `project_group_day`/`project_verified_group_day` sorgularıyla üretiliyor. Bu üç metriğin hangi sorgusunun participant sayımı yaptığı isim isim envanterlenmeli; "filtre uygulanacak" cümlesi tek başına yetmez. Bu, C3'ün achievement tarafındaki eşleniği.
7. **Ayrı `study_session_group_attribution` doğru migration yönü mü?** → **Evet, ve kolon eklemekten daha iyi.** 0010'un "oturum yalnız kullanıcıya aittir" kararını bozmadan one-to-zero/one muhasebe bağı kuruyor; grup silinmesinde tombstone'u ilişki katmanında çözüyor; `study_sessions`'a geri dönüşsüz kolon eklemiyor. C4'e verilen cevap benim önerimden daha iyi.

---

## 6. Karar

| Teslimat | Karar |
|---|---|
| **Delivery A** (çoklu grup presence) | ✅ Onaylanabilir. Ön koşul: F1/H5 (ADR yeri) tek seferlik çözülsün. |
| **Delivery B** (kaynak dayanıklılığı) | ✅ Onaylanabilir. §5'teki 4. cevaba göre "versiyonlayarak genişletme" seçilsin. |
| **Delivery C** (global coordination) | ⚠️ Yön doğru, **migration G1–G4 kapanmadan yazılmasın**. Keşif çıktısı: mevcut index/CHECK envanteri + `select count(*) where status in ('running','paused')` ölçümü + G6 bayrak adı. |
| **Delivery D** (push) | ✅ İtiraz yok; §8.6'nın dokuz kapısı kabul kriteri olarak duruyor. |
| **Ayrı programlar** (finalizer, gün sınırı, Pomodoro, native remote-start) | ✅ Doğru ayrıldı. Pomodoro'ya G5 notu işlensin. |

Revizyon, 1. turdaki altı protokol hatasının beşini kapattı, altıncısında beni düzeltti ve kapsamı gerçekçi hale getirdi. Kalan iş artık mimari tartışma değil, **migration keşfi**: G1–G4 tek bir SQL envanter turuyla kapanabilir ve Codex'in "1 numaralı belirsizlik" dediği şey o turdan sonra belirsizlik olmaktan çıkar.
