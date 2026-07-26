# Global Timer / Presence Planı — Senior Review Yanıtı

> Tarih: 2026-07-26
>
> Yanıt verilen rapor: `GLOBAL-TIMER-PRESENCE-PLAN-SENIOR-REVIEW-2026-07-26.md`
>
> Revize edilen RFC: `GLOBAL-TIMER-PRESENCE-MULTI-DEVICE-ARCHITECTURE-PLAN.md`
>
> Durum: Teknik yanıt + ikinci review talebi

---

## 1. Kısa sonuç

İncelemedeki ana teknik itirazların çoğunu kabul ettim ve RFC'yi buna göre revize ettim.

En büyük değişiklikler:

1. Run içi `run_revision` ile kullanıcı-geneli `user_state_version` ayrıldı.
2. `recovery_required` açık state olmaktan çıkarıldı; terminal `abandoned` yeni start'ı bloklamıyor.
3. Command idempotency `unique(user_id, command_id)` olarak kullanıcı kapsamına alındı.
4. Yeni paralel run tablosu varsayımı kaldırıldı; mevcut `live_study_runs` additive V2 evrimi tercih edildi.
5. V1 yalnız stopwatch start/stop + foreground reconcile + güvenli remote stop olarak daraltıldı.
6. Pause/resume, countdown/Pomodoro global fazı, native background remote-start, server finalizer ve gün-sınırı ayrı programlara çıkarıldı.
7. Push hattının bugün timer sync'i taşıyamadığı açık engel listesiyle plana işlendi.
8. Heartbeat'in bütün grup projection satırlarını yazması kaldırıldı.
9. Mevcut native UUID idempotency, `ACTION_STOP_SILENT` ve verified-command queue yeni yapılacak işler olmaktan çıkarılıp korunacak invariant yapıldı.
10. Secondary grup presence'ının sosyal achievement katılımcı sayılarını şişirmemesi için server-side `counts_for_group_progression` filtresi eklendi.
11. 12 fazlı seri uygulama yerine bağımsız Delivery A-D sırası tanımlandı.

İki konuda itirazı nitelendirerek kabul ettim:

- Pomodoro fazı yalnız ilk `started_at + preset + now` ile hesaplanamaz; mevcut manuel break eylemleri epoch'u değiştiriyor. Çözüm mutable phase değil, ileride immutable phase-event/segment ledger'dır.
- Presence fan-out önce sevk edilebilir; fakat fan-out + cold-start reconcile, uygulama süreci hiç çalışmadan widget/bildirim start'ının sunucuya **anında** ulaşmasını çözmez. Bu ayrıca güvenli native uplink problemidir.

---

## 2. İnceleme kapsamı hakkında not

Proje sahibinin bu tur için açık yönlendirmesi:

> Eski/yanlış mimari MD'leri bağlayıcı kabul etme; onlar ayrıca düzeltilecek.

Bu nedenle tarihsel yol haritası veya eski mimari belgesiyle çelişen noktaları bu revizyonun blocker'ı yapmadım.

Buna karşılık gerçek kod, migration, constraint, RPC, native servis ve test sözleşmeleri bağlayıcı teknik kanıt olarak ele alındı.

Özellikle gün-sınırının ayrı programa çıkarılması eski bir MD'ye saygı nedeniyle değil; gerçek migration/test blast radius'u nedeniyle yapıldı.

---

## 3. Bulgu bazında yanıt

### B1 — `revision` skalası tanımsız

**Karar: Kabul edildi.**

Revize protokol:

- `run_revision`: yalnız aynı `run_id` içindeki CAS.
- `user_state_version`: aynı kullanıcının bütün run'ları ve idle/terminal snapshot'ları arasında monoton sıralama.
- Device state:
  - `last_seen_state_version`
  - `last_applied_state_version`
  - `last_run_id`
  - `last_run_revision`

Yeni run `run_revision=1` ile başlayabilir; önceki run rev 11 yüzünden reddedilmez. Çünkü cihaz snapshot yeniliğini `user_state_version` ile kıyaslar.

Küçük teknik nüans:

Global sequence'ın rollback nedeniyle boşluk üretmesi tek başına “daha yüksek değer daha yeni” karşılaştırmasını bozmaz; sequence yine monotondur.

Yine de transactional kullanıcı-head satırı tercih edildi:

```text
user_timer_state(
  user_id primary key,
  state_version bigint,
  current_run_id uuid null,
  updated_at timestamptz
)
```

Sebep:

- current-run pointer ile aynı transaction'da tutulması;
- snapshot üretiminin sade olması;
- kullanıcı lock'u altında kolay test edilmesi;
- global sequence ile hesaplar arasında anlamsız ortak numara paylaşılmaması.

### B2 — `recovery_required` unique active index içinde

**Karar: Kabul edildi.**

V1 state machine:

```text
idle -> running -> stopped
idle -> running -> abandoned
```

`abandoned` terminaldir.

Lease'i düşmüş ghost run:

1. User lock altında `abandoned` yapılır.
2. Projection bir kez offline yapılır.
3. Açık-run unique constraint'inden çıkar.
4. Yeni start kabul edilir.
5. Eski run otomatik session/XP olarak finalize edilmez.

Dolayısıyla tabletten yeni start 9 saatlik ghost run'ı adopt etmez.

### B3 — Global `command_id` unique ve result snapshot sızıntısı

**Karar: Kabul edildi.**

Yeni kural:

```text
unique(user_id, command_id)
```

Duplicate lookup:

1. Önce `auth.uid()` alınır.
2. Yalnız `(auth.uid(), command_id)` aranır.
3. Başka kullanıcıya ait command veya `result_snapshot` hiçbir durumda dönmez.

Legacy `live_study_runs` içindeki `unique(user_id, client_request_id)` doğru emsal olarak plana işlendi.

### B4 — Push transport timer sync'i sessizce yutar

**Karar: Tam kabul edildi.**

RFC artık mevcut push hattını “hazır/reusable” varsaymıyor.

Zorunlu kabul kapıları:

- notification type CHECK/allowlist;
- `_push_type_enabled` timer sınıfı;
- unknown type'ın sessiz no-op olmaması;
- quiet-hours/cooldown bypass;
- kısa TTL;
- collapse key;
- `exclude_device_id`;
- delivery telemetry;
- handler sahipliği.

Timer push, Delivery D'ye taşındı. Presence çekirdeğinin ön koşulu değil.

### B5 — FCM entry point native receiver değil

**Karar: Kabul edildi.**

Bugünkü gerçek:

- background entry point Flutter/Dart isolate;
- remote notification gösteriyor;
- Main Activity method-channel handler'ı background isolate'ta hazır kabul edilemez;
- özel bir Kotlin `FirebaseMessagingService` ile doğrulanmış timer apply akışı yok.

V1 davranışı:

- FCM yalnız sinyal/bildirim;
- auth'lu snapshot app-open/foreground reconcile'da alınır;
- background native auto-start yok;
- foreground remote stop/reconcile var.

İleride native background apply istenirse ayrı paket gerekir:

- özel receiver/service;
- account binding;
- device-bound credential;
- revoke;
- process-death;
- Android FGS restriction;
- OEM/API matrisi.

### B6 — Mutable Pomodoro phase bayatlar

**Karar: Esas kaygı kabul, önerilen sade formül nitelendirildi.**

Mutable `phase/cycle_index` kanonik otorite yapılmayacak.

Ancak mevcut native ürün:

- `ACTION_START_BREAK`
- `ACTION_END_BREAK`

ile faz başlangıç epoch'unu manuel değiştiriyor.

Bu nedenle yalnız:

```text
initial_started_at + preset_snapshot + now
```

fonksiyonu bütün gerçek davranışı temsil etmiyor.

Karar:

- V1 global protokol stopwatch ile sınırlı.
- Countdown/Pomodoro ayrı program.
- İleride preset snapshot + append-only phase-event/segment ledger.
- Görüntülenen faz ledger + server time'dan deterministik türetilir.
- Manuel geçişler immutable event olur.

Bu model mutable phase kolonunu kaldırırken mevcut manuel UX'i de kaybetmiyor.

---

## 4. Gün sınırı ve session muhasebesi

### C1/C2 — Gün sınırı ayrı program olmalı

**Karar: Kabul edildi.**

Global presence ve remote stop şunlara bağlı değil:

- `study_sessions.day` dönüşümü;
- `istanbul_day` anahtar migration'ı;
- midnight split;
- server finalizer.

Ayrı gün-sınırı programının zorunlu yüzeyi:

- 24 migration'a yayılan gün/muhasebe bağı;
- personal session start-day semantiği;
- grup projection midnight split semantiği;
- `group_achievement_daily.istanbul_day`;
- Dart repository/provider tüketicileri;
- `docs/recovery/STATS-CONTRACT.md`;
- `wp231_stats_contract_test.dart`;
- DST/backfill/cron.

Bu bir tarihsel belge çelişkisi nedeniyle değil, gerçek kod sözleşmesi nedeniyle ayrıldı.

### C3 — Filtre trigger'da değil projection fonksiyonlarının içinde

**Karar: Kabul edildi.**

Attribution filtresi:

- `project_group_day`
- `project_group_week`
- catch-up
- cron/recompute

sorgularının içinde uygulanacak.

Gece/cron recompute'un secondary gruba tekrar yazmadığı test zorunlu.

### C4 — `attributed_group_id` eski group ownership modelini geri getiriyor

**Karar: Kabul edildi; veri modeli değişti.**

Tercih:

```text
study_session_group_attribution(
  session_id primary key,
  group_id_snapshot null,
  source_version,
  created_at
)
```

Neden:

- Session kullanıcıya ait kalır.
- Grup muhasebesi one-to-zero/one ilişkidir.
- Aynı session en fazla bir progression grubuna gider.
- Primary değişimi geçmiş session'ı taşımaz.
- Grup silinmesi/tombstone stratejisi ilişki katmanında çözülür.

### C5 — Legacy `live_study_runs`

**Karar: Kabul edildi; tercih mevcut tabloyu evriltmek.**

Yeni paralel `global_timer_runs` varsayımı kaldırıldı.

Additive V2 aday alanları:

- `protocol_version`
- `run_kind`
- `run_revision`
- `user_state_version`
- `controller_device_id`
- `lease_expires_at`

Mevcut bağlar korunur:

- `unique(user_id, client_request_id)`
- group snapshot
- one-open-run
- segments
- `study_sessions.live_run_id`

İkinci bir `source_run_id` eklenmez.

Son karar migration keşfi ve compatibility testinden sonra ADR ile verilir. Aynı anda iki aktif-run otoritesine izin verilmez.

### C6 — Heartbeat write amplification

**Karar: Kabul edildi.**

Yeni model:

- Kanonik lease yalnız run/state head üzerinde.
- Heartbeat grup projection'larına yazmaz.
- Projection yalnız gerçek state değişikliklerinde yazılır.
- Sweeper lease expiry'de bir kez `abandoned/offline` yazar.
- Projection `finalized_today_seconds_base + started_at` taşır.
- Client canlı görüntüyü server-time offset ile türetir.

Bu şekilde `N membership × heartbeat` write fan-out kaldırıldı.

---

## 5. Mevcut native primitive'ler

### D1 — Interval UUID idempotency zaten var

**Karar: Kabul edildi.**

Yeni iş olmaktan çıkarıldı; korunacak invariant ve regresyon testi oldu.

### D2 — Silent mirror stop zaten var

**Karar: Kabul edildi.**

`ACTION_STOP_SILENT` remote stop adaptörünün temel primitifi olarak kullanılacak.

Normal stop handler'ının yeni bir kopyası yazılmayacak.

### D3 — Native pending command queue zaten var

**Karar: Kabul edildi.**

`appendPendingVerifiedCommand + commandSeq` mevcutken üçüncü queue kurulmayacak.

Karar seçenekleri:

1. Mevcut queue formatını version ederek genişletmek.
2. Tek seferlik idempotent migration ile tek yeni ortak outbox'a taşımak.

Flutter katmanı ikinci command üreticisi değil flush/observe adaptörü olacak.

### D4 — Fire-and-forget bilinçli davranış

**Karar: Açıklığa kavuşturuldu.**

Fire-and-forget UX korunuyor:

- timer network beklemiyor;
- hata toast/modal timer akışını kesmiyor;
- widget/bildirim hot path bloklanmıyor.

Eklenen şey kullanıcıyı bloklamak değil:

- retry age;
- queue depth;
- last error class;
- divergence metric;
- support diagnostic.

Dolayısıyla “fire-and-observe”, mevcut ürün davranışını tersine çevirmiyor.

### D5 — Migration head

**Karar: Kabul edildi.**

Plan tek migration numarasını sabitlemiyor. Uygulama anında gerçek head üstüne additive migration üretilecek.

---

## 6. Yol haritası ve ürün semantiği

### E1 — Eski çoklu-timer dokümanı

**Karar: Bu review kapsamında bağlayıcı değil.**

Proje sahibinin açık talebi nedeniyle eski yanlış MD'ler blocker yapılmadı.

Yine de gereksiz geleceği kilitlememek için unique invariant:

```text
user_id + protocol_version=2 + run_kind='study' + state='running'
```

kapsamında tasarlandı.

### E2 — Pause mevcut ürün değil

**Karar: Kabul edildi.**

Pause/resume V1'den çıkarıldı.

### E3 — Çoklu grup presence sosyal achievement tetiklerini değiştirir

**Karar: Kabul edildi ve veri modeline eklendi.**

Kural:

- Bütün aktif üyeliklerde sosyal presence görünür.
- Yalnız attribution/primary projection `counts_for_group_progression=true`.
- Group target/leaderboard/quest yanında `locomotive/campfire` benzeri birlikte-çalışma katılımcı sorguları da bu filtreyi kullanır.

Bu yalnız katkı saniyesi filtresi değildir; participant count filtresidir.

### E4 — Telemetry boyutu

**Karar: Kabul edildi.**

`group count` yerine kullanıcı membership-count bucket kullanılıyor.

---

## 7. Planın uygulanabilirliği ve yeni teslimat sırası

### F1/F4/F5

**Karar: Kabul edildi.**

12 fazlı seri program authoritative olmaktan çıkarıldı.

Yeni sıra:

### Delivery A — Çoklu grup presence

- server-derived projection;
- membership fan-out;
- RLS;
- selected group bağı yok;
- primary yalnız progression flag'i;
- social achievement participant filtresi.

### Delivery B — Kaynak dayanıklılığı

- mevcut native queue versioning;
- auth/provider yarışını engelleyen durable enqueue;
- cold-start/foreground reconcile;
- process-death;
- native uplink spike.

### Delivery C — Global coordination

- `live_study_runs` V2;
- user state head;
- command ledger;
- foreground mirror;
- remote stop;
- abandoned/lease.

### Delivery D — Push/deferred signal

- push allowlist/policy düzeltmeleri;
- short TTL/collapse/exclusion;
- background signal;
- app-open reconcile.

Ayrı programlar:

- server finalizer;
- gün sınırı;
- Pomodoro/countdown;
- native background remote-start.

Blocking ürün soruları 17'den 7'ye indirildi.

---

## 8. Delivery A+B'nin neyi çözüp neyi çözmediği

Bu ayrım özellikle önemli.

Delivery A şu bug'ı bağımsız çözer:

> Server bir kullanıcının çalıştığını biliyorsa kullanıcı üye olduğu bütün gruplarda görünür.

Delivery B şunları iyileştirir:

- app içi auth/provider yarışı;
- process death sonrası command kaybı;
- uygulama açılınca eventual reconcile.

Fakat şu senaryoda:

```text
Flutter process yok
-> kullanıcı Android widget/notification ile native timer başlatıyor
-> uygulama hiç açılmıyor
```

server yerel eylemi öğrenmeden server-side fan-out çalışamaz.

FCM de çözmez; yönü server-to-device'dır.

Tam anlık çözüm için ayrıca:

- native authenticated uplink;
- device/account credential;
- revoke;
- retry;
- OS background execution;
- process/account isolation

gerekir.

Bu nedenle revize plan:

- A'yı bekletmeden sevk eder;
- B ile eventual consistency'yi güvenilir yapar;
- anlık terminated-uplink garantisini capability spike sonucuna bağlar;
- kullanıcıya yapılamayan bir platform garantisi vaat etmez.

---

## 9. İkinci review için odak soruları

Lütfen ikinci review'da özellikle şu yedi noktaya bak:

1. `live_study_runs` additive V2 evrimi yeni tabloya göre doğru tercih mi?
2. `run_revision + transactional user_state_version` protokolü bütün yeni-run/out-of-order vakalarını kapatıyor mu?
3. Tek kanonik lease + state-transition-only projection yeterli mi?
4. Mevcut native command queue tek outbox olarak güvenle evrilebilir mi?
5. V1 background sınırı “signal + app-open reconcile” olarak doğru çizildi mi?
6. `counts_for_group_progression` hem contribution hem participant-count sorgularını eksiksiz kapsıyor mu?
7. Ayrı `study_session_group_attribution` ilişkisi doğru migration yönü mü?

Eski MD yol haritası, gün-sınırı uygulaması, server finalizer, Pomodoro global fazı ve background remote-start bu ikinci onayın kapsamı değildir.

---

## 10. Sonuç

İlk review planı somut olarak iyileştirdi.

Özellikle:

- revision bug'ı,
- ghost-run lockout,
- command scope sızıntısı,
- push sessiz no-op,
- legacy tabloyu görmezden gelme,
- projection write amplification,
- native primitive'leri yeniden yapma,
- secondary presence'ın achievement yan etkisi

revize RFC'de artık açık mimari kararlara dönüştürüldü.

Kalan iki önemli belirsizlik bilinçli ve dar:

1. Mevcut `live_study_runs` additive V2 migration'ının gerçek compatibility yüzeyi.
2. Flutter süreci yokken güvenli native authenticated uplink'in mümkün ve ürün açısından değerli olup olmadığı.

Bu ikisi keşif/spike çıktısı olmadan varsayımla kapatılmayacak.
