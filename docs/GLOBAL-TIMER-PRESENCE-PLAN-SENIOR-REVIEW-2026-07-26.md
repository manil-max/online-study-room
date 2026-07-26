# Senior review — `GLOBAL-TIMER-PRESENCE-MULTI-DEVICE-ARCHITECTURE-PLAN.md`

> İnceleyen: Claude (Opus 5) · Tarih: 2026-07-26
>
> İncelenen belge: `docs/GLOBAL-TIMER-PRESENCE-MULTI-DEVICE-ARCHITECTURE-PLAN.md` (3552 satır, Codex tarafından yazıldı)
>
> Bu belge **yalnız incelemedir**: kod, migration veya plan dosyası değiştirilmedi.
>
> Yöntem: planın her somut iddiası repodaki kaynağa karşı doğrulandı (migration SQL, Kotlin native servis, Flutter provider/repository, edge function, kanonik dokümanlar). Aşağıdaki her bulguda "doğrulandı" = dosyayı okudum, "değerlendirme" = benim mühendislik görüşüm.

---

## 0. Genel yargı

Planın **mimari yönü doğru**. Local-first native timer + server-authoritative koordinasyon + server-derived presence ayrımı bu ürün için doğru karardır; "FCM sinyal, PostgreSQL truth" ilkesi ve "mirror cihaz session/XP yazmaz" invariant'ı programın en değerli iki cümlesidir. §14A.3'ün WP-329 metnindeki "diğer gruplar sayaç tutmaz" ifadesini iki okunuşa ayırması, tek başına bu belgeyi yazmaya değer kıldı.

Ancak belge **bu haliyle uygulama yetkisi verilecek olgunlukta değil** ve zaten öyle olduğunu iddia etmiyor. İki tür problem var:

1. **Protokolde altı somut tasarım hatası** (§1). Bunlar yazıldığı gibi kodlanırsa çalışmaz — "eksik detay" değil, yanlış davranış üretir. En ciddisi `revision` skalasının tanımsız olması ve `recovery_required`'in tek-aktif-run kısıtına dahil edilmesi.
2. **Kapsam yanlış ölçülmüş** (§2). Özellikle gün sınırı/saat dilimi maddesi planda WP-329'un bir alt bulleti gibi duruyor; gerçekte 24 migration dosyası, bir tablonun birincil anahtar kolonu (`istanbul_day`), 29 Dart kaynak dosyası ve **test'le zorlanan kanonik bir sözleşme** anlamına geliyor. Bu, global timer'dan bağımsız ayrı bir programdır.

Ayrıca planın "önlem alınmalı" dediği üç riskin **kodda çözülmüş olduğunu** doğruladım (§3). Bu, kanıt haritasının koddan değil eski rapordan türetildiğini gösteriyor — bu repoda tekrarlayan bir hata deseni.

Kapsam kesme önerim §7'de: kullanıcının bugün yaşadığı şikâyetin üçte ikisi, global run programının hiçbir fazını beklemeden sevk edilebilir.

---

## 1. Bloklayıcı protokol hataları (P0 — kod yazılmadan düzeltilmeli)

### B1 — `revision` skalası tanımsız; §11.3'ün CAS kuralı yeni run'ı kalıcı olarak reddeder

Plan `revision`'ı `global_timer_runs` satırının alanı olarak tanımlıyor (§8.1) — yani **run başına monoton**. Ama:

- §15.5 örneği "rev 10 start, rev 11 stop" diyor; bu **kullanıcı geneli** bir sayaç davranışı.
- §8.3 cihaz tablosunda tek bir `last_applied_revision bigint` var, yanında `run_id` yok.
- §11.3 native store kuralı: *"daha düşük/eşit revision'ı no-op saymalı"*.

Bu üçü birlikte tutarsız. Revision run başınaysa, yeni run rev 1'den başlar; cihazın `last_applied_revision = 11` olduğu için **yeni run'ın rev 1'i sonsuza kadar no-op sayılır** — telefonda başlatılan her yeni çalışma tablette sessizce yok sayılır. §15.6 `run_id` uyumsuzluğunu ayrı bir kural olarak ekliyor ama §11.3 ile hangisinin önce geldiği yazılmamış; iki kural birbirini iptal ediyor.

**Öneri:** iki ayrı sayaç tanımla ve ikisini de şemaya yaz:

- `global_timer_runs.revision` — run içi mutasyon sürümü (mevcut haliyle kalsın).
- `user_timer_state_version bigint` — **kullanıcı başına** monoton, her kabul edilen komutta artan, run kimliğinden bağımsız sıralama otoritesi (ayrı tablo veya `profiles` alanı; sequence değil, transaction içinde `for update` ile artan sayaç — sequence rollback'te boşluk bırakır ve "gördüğüm en yüksek" karşılaştırmasını bozar).

Cihaz karşılaştırması `(state_version)` üzerinden yapılır; `(run_id, revision)` yalnız aynı run'ın içindeki idempotency için kullanılır. `global_timer_device_state` iki alanı birlikte tutar. §15.5/§15.6 senaryoları ancak bundan sonra deterministik olur.

### B2 — `recovery_required` tek-aktif-run kısıtında; ghost run yeni çalışmayı sunucuda kilitler

§8.1'in partial unique index'i:

```sql
where state in ('running', 'paused', 'recovery_required')
```

§14.6 ise: lease dolsa bile *"global run doğrudan ve sessizce finalize edilmemeli; kullanıcı sonraki açılışta recovery kararı görmelidir"*.

İkisi birlikte şu senaryoyu üretir: telefonun pili biter → lease dolar → run `recovery_required` olur → kullanıcı tabletten yeni çalışma başlatır → **start reddedilir**, çünkü açık run var. §10.3 bu durumda `adopt_existing` dönmeyi öneriyor; o zaman tablet, 9 saat önce ölmüş bir run'ın `effective_started_at`'ini benimser ve §18.9'a rağmen ekranda 9 saatlik bir süre gösterir. Kullanıcı yeni bir çalışma başlatmak istemişti.

Bu, planın kendi birinci ilkesini ("sunucu çalışmasa bile başlat/durdur çalışmaya devam etmelidir") yerelde koruyor ama **global katmanda ihlal ediyor**: kullanıcı yerelde başlatabiliyor, ama hiçbir çalışması bir daha kanonik run üretemiyor.

**Öneri:**
- `recovery_required`'i unique index'ten **çıkar**. İnvariant yalnız `running`/`paused` üzerinde olsun.
- Recovery gereken run'ı terminal-ama-onaylanmamış bir durum yap (`abandoned`), yeni start'ı engellemesin; kullanıcının onaylayacağı şey **süre kaydı**, çalışma hakkı değil.
- Recovery kuyruğu birden fazla satır tutabilsin; "aynı anda tek bekleyen recovery" gibi ikinci bir kilit eklemeyin.
- §10.3'ün `adopt_existing` kararı yalnız **lease'i canlı** run'lar için geçerli olsun; ölü run adopt edilmez.

### B3 — `command_id` global unique + duplicate'te `result_snapshot` dönmek = hesaplar arası sızıntı yüzeyi

§8.2: `command_id uuid unique`, ve §10.1 sırası: *"3. Command idempotency kaydı var mı kontrol et"* → varsa §8.2'ye göre `result_snapshot` (önceki cevap) dönülür.

`command_id` istemci tarafından üretiliyor ve **global** unique. Kontrol adımı `auth.uid()` ile daraltılmazsa, A kullanıcısının gönderdiği bir `command_id` B kullanıcısının kaydına çarparsa B'nin `result_snapshot`'ı (run_id, started_at, subject, accounting group) A'ya döner. UUID çarpışması kazara olmaz; **kasten denenebilir** — istemci `command_id`'yi kendi seçiyor.

**Öneri:**
- `unique (user_id, command_id)`; global unique kaldırılsın.
- İdempotency lookup'ı **her zaman** `user_id = auth.uid()` ile yapılsın; eşleşme kullanıcı dışıysa kayıt yokmuş gibi davranılsın (varlık bilgisi de sızmasın).
- `result_snapshot`'a başka hesabın alanı hiç yazılamayacağı için bu iki değişiklik yeterli; ek şifreleme gerekmiyor.
- pgTAP negatif testi: "B'nin command_id'siyle A'nın RPC çağrısı → yeni komut olarak işlenir, B'nin snapshot'ı dönmez" (§22.2 listesinde bu test yok, eklenmeli).

### B4 — "Mevcut push transport'un parçaları kullanılabilir" iddiası altı somut değişikliği saymıyor

§3.7 ve §8.6, mevcut push altyapısının timer sync için "iyi bir temel" olduğunu söylüyor. Doğru, ama mevcut kod `timer_sync` tipini **sessizce yutar**:

| Engel | Kaynak | Sonuç |
|---|---|---|
| `_push_type_enabled` bilinmeyen tipte `else false` döner | `0066_push_notification_delivery.sql:194-209` | `timer_sync` için **hiç delivery satırı oluşmaz**; outbox `no_devices` yazar, hata yok, sessiz kayıp |
| `notification_type` CHECK listesi `('nudge','announcement','update','self_test')` | `0066:43-44` | insert reddedilir |
| Quiet-hours retry yalnız `self_test`'i muaf tutuyor | `supabase/functions/dispatch-push/index.ts:239-241` | timer sync gece 22:00–07:00 arası **ertelenir** (planın §29.6 yasağı ihlal) |
| TTL sabit: `self_test` 60s, diğer her şey `3600s` | `dispatch-push/index.ts:264-266` | §13.3'ün "kısa TTL" gereği kod değişikliği ister |
| `collapse_key` alanı yok | `dispatch-push/index.ts` FCM payload | eski revision yeni revision'ı collapse edemez |
| `exclude_device_id` yok; `_create_push_deliveries` alıcının **tüm** cihazlarına fan-out eder | `0066:212-231` | origin cihaz kendi komutunun push'unu alır → §11.5 echo koruması buna hazır olmak zorunda |

**Öneri:** §8.6'yı "mevcut outbox genişletilecekse" belirsizliğinden çıkar; yukarıdaki altı maddeyi **kabul kriteri** olarak yaz. Ayrıca `_push_type_enabled`'ın `else false` davranışı bir "sessiz kayıp" tuzağıdır: yeni tip eklerken bu fonksiyon güncellenmezse hiçbir yerde hata görünmez. §22.2'ye "yeni notification_type için delivery üretiliyor" testi eklensin.

### B5 — FCM giriş noktası native değil; §11.2/§13.5'in "native receiver" varsayımı mevcut mimaride yok

Plan §13.5 adım 2'de *"Sinyal önce kalıcı pending remote event store'a yazılır"*, Faz 6 işlerinde *"Native receiver pending event store"* diyor. Repoda **özel Kotlin `FirebaseMessagingService` yok**; FCM Dart tarafında karşılanıyor:

- `app/lib/core/notifications/app_push_notification_service.dart:385` — `FirebaseMessaging.onBackgroundMessage(firebasePushBackgroundHandler)`
- `:389` — `FirebaseMessaging.onMessage`
- Manifest'teki servisler `io.flutter.plugins.firebase.messaging.*` (plugin'in kendisi)

Bu, remote apply zincirinin **Dart background isolate → method channel → FGS** olması demek. Sonuçları:

1. Background isolate'in provider grafiği yok; auth/session ve Supabase client yeniden kurulmalı (plan §9.6'da native auth'u tartışıyor ama bu isolate'i ayrı bir vaka olarak ele almıyor).
2. FGS başlatma bu yoldan **background start** sayılır. Mevcut native yol bu yasağı bildirim `PendingIntent`'inin `getForegroundService` muafiyetiyle aşıyor (`StudyTimerService.kt:44-45` yorumu bunu açıkça yazıyor). Push tetiklemeli remote start bu muafiyeti **kaybeder**; yalnız high-priority FCM'in geçici allowlist penceresine kalır.
3. Dolayısıyla §11.7'nin kademeli açılışı doğru ama sıralaması iyimser: "2. background'da yalnızca state/widget bildirimi" adımı pratikte **varsayılan** olmalı, "3. FGS auto-start" ise ölçülmüş bir istisna.

**Öneri:** §11.2'ye "remote apply'ın giriş noktası Dart background isolate'tir; native servis yalnız açık `REMOTE_APPLY_*` intent'iyle çağrılır" cümlesini ekle. Pending event store'u `SharedPreferences`/`FlutterSharedPreferences` üzerinde tut (native ile aynı dosya — `TimerStateStore.PREFS_NAME` zaten `FlutterSharedPreferences`), böylece isolate ve native aynı kuyruğu görür. Ayrı bir native store tasarlamak gereksiz ikinci gerçeklik üretir.

### B6 — Pomodoro/countdown phase otoritesi boşta; mutable `phase` alanı bunu çözmüyor

§3.10 phase geçişini "ayrıca kararlaştırılmalı" diye erteliyor, ama §8.1 şemaya mutable `phase`, `cycle_index`, `phase_started_at`, `elapsed_before_phase_ms` alanlarını koyuyor. Mutable phase, geçişi yapacak birinin olmasını gerektirir. Hiçbir cihaz online değilken (ki tam olarak korunmak istenen senaryo bu) sunucudaki `phase` bayatlar; sonra açılan mirror cihaz **yanlış fazı** uygular ve §18.9'un "sıfıra resetlenmeme" kuralı bunu yakalamaz — süre doğru, faz yanlış olur.

**Öneri — bu, planın en kolay kazanacağı basitleştirme:** run'ı immutable girdilerin **deterministik fonksiyonu** yap.

```text
phase, cycle, remaining = f(effective_started_at, preset_snapshot, pause_intervals, now)
```

`preset_snapshot` zaten immutable olarak planlanmış (§8.1). Bunu yaparsan:

- phase geçişi için komut yok → revision artmaz → çakışma sınıfı komple ortadan kalkar (§3.10'un "bir cihaz phase değiştirirken diğerinin eski phase komutu göndermesi" riski **var olmaz**).
- countdown bitişi de aynı fonksiyondan çıkar; sunucunun tick etmesi gerekmez.
- native alarm yalnız **bildirim** için gerekir, durum otoritesi için değil.
- `phase`/`cycle_index` kolonları şemadan çıkar; `phase_started_at` ve `elapsed_before_phase_ms` yalnız pause varsa gerekir — ve B6'nın yanında E2'ye bakınca pause v1'de yok.

Sunucuda saklanan yalnız `effective_started_at` + `preset_snapshot` + (varsa) pause aralıkları olur. Bu, §5.2'nin "sunucu her saniyeyi tick etmek zorunda değildir" ilkesinin mantıksal sonucudur; plan bu sonucu yarı yolda bırakmış.

---

## 2. Kapsam yanlış ölçülmüş (P1)

### C1 — Gün sınırı değişikliği ayrı bir programdır; planda alt madde olarak duruyor

§14A.9 ve §17.5, `study_sessions.day`'in sabit `Europe/Istanbul` yerine primary grubun IANA bölgesine geçmesini öneriyor. Planın kanıt haritası bunun için tek dosya gösteriyor: `0073_session_day_stamp.sql`. Gerçek yüzey:

| Yüzey | Doğrulanan gerçek |
|---|---|
| Migration | **24 dosya** `Europe/Istanbul` içeriyor; en yoğunu `0063_equal_study_sources.sql` (28 kez), `0053_group_achievement_metrics.sql` (10), `0062_weekly_alpha_wolf.sql` (7) |
| Tablo anahtarı | `group_achievement_daily` **birincil anahtarı** `(group_id, istanbul_day, user_id)` — kolon adı bölgeyi taşıyor (`0053:4-15`) |
| Dart | `app/lib/core/stats/istanbul_calendar.dart` ("ürünün tek takvim sınırı"), toplam **29 lib + 16 test** dosyası `Istanbul` içeriyor |
| Kanonik sözleşme | `docs/recovery/STATS-CONTRACT.md`: *"Tüm gün/dönem hesapları Europe/Istanbul duvar saatini kullanır; cihazın yerel saat dilimi dönem sınırını değiştiremez."* |
| Test kilidi | `app/test/core/stats/wp231_stats_contract_test.dart` — sözleşmeyi fikstürle zorluyor |
| WP-326 durumu | `groups.time_zone` var ve doğrulanıyor (`0076`), ama `calendarDayInTimeZone`'un **production çağıranı yok** — yalnız test çağırıyor. Bugün grup bölgesi gün sınırını hiç etkilemiyor. |

Yani `0076` planın §3.9'da yazdığı gibi "primary gün sınırı için güvenilir server-side bölge" **değil**; henüz yalnız metadata. Değişiklik greenfield değil, tam tersi: mevcut her muhasebe yüzeyine dokunuyor ve **test'le zorlanmış bir sözleşmeyi bilinçli olarak ezmesi** gerekiyor.

**Öneri:** gün sınırı maddesini global timer RFC'sinden **çıkar**, ayrı bir program yap. Ayrıca §36'ya `docs/recovery/STATS-CONTRACT.md` eklenmeli ve ADR listesine "STATS-CONTRACT §Dönemler'in yerini alan yeni gün sınırı sözleşmesi" ADR'si girmeli — plan şu an bu sözleşmeden hiç haberdar görünmüyor.

### C2 — İki farklı gün muhasebesi zaten yan yana çalışıyor; plan bunları uzlaştırmıyor

- `study_sessions.day`: oturumun **tamamını başlangıç gününe** damgalıyor (`0073:24` → `(new.start_time at time zone 'Europe/Istanbul')::date`).
- `project_group_day`: oturumu gün sınırında **gerçekten dilimliyor** (`0063:257-295`, `tstzrange` + `greatest/least` kesişimi).

Yani 23:30–00:30 arası bir oturum kişisel `day` tarafında tamamen dünde, grup projeksiyonunda 30/30 dakika bölünmüş görünüyor. Bu bugünkü davranış.

§17.5 "gece yarısını geçen run süreyi doğru günlere bölmeli" **ve** aynı paragrafta "server-stamped `day`" diyor. Hangisi otorite? Plan cevap vermiyor, ve §3.10'un "birden fazla bugünkü toplam" riski tam olarak burada yaşıyor — ama plan bunu bir client provider sorunu gibi tarif ediyor; gerçekte **şemada** iki farklı model var.

**Öneri:** ADR'de tek cümle seç: ya "oturum atomiktir, başlangıç gününe yazılır" (grup projeksiyonu da dilimlemeyi bırakır) ya da "her şey dilimlenir" (`study_sessions.day` tek gün anahtarı olmaktan çıkar, gün başına dağıtım tablosu gerekir). İkincisi doğru olan ama pahalı; birincisi mevcut `day` damgasıyla uyumlu. Karar verilmeden Faz 10 yazılamaz.

### C3 — Attribution'ı yalnız trigger'da sınırlamak yetmez; cron çoklu sayımı geri getirir

§14A.6 tespiti doğru ve önemli: `refresh_group_metrics_for_session` kullanıcının **zaman aralığında aktif olduğu tüm** `group_members` satırlarını dolaşıyor (`0063:450-455`, doğrulandı). Faz 10 işi bunu "attribution grubuna yöneltme" diyor.

Eksik olan: `project_group_day(group_id, day)` fonksiyonu çağrıldığı grup için **sıfırdan** hesaplıyor ve session'ın attribution grubunu hiç bilmiyor. `catch_up_group_days` / `catch_up_group_weeks` cron job'ları (0063; pg_cron 0060'ta açıldı) bu fonksiyonu tüm gruplar için çağırıyor. Sonuç: trigger'ı daraltsan bile **gece cron'u çoklu sayımı geri yazar**, ve bu sessizce olur.

**Öneri:** filtre projeksiyon **fonksiyonunun içinde** olmalı (`join ... and s.attributed_group_id = p_group_id`), trigger'ın dışında değil. Faz 10 çıkış kapısına "cron catch-up sonrası attribution invariant'ı hâlâ geçerli" testi eklensin. Bu, §22.2'de eksik olan bir pgTAP senaryosu.

### C4 — `attributed_group_id`, 0010'da bilinçli düşürülen kolonun geri gelmesidir

`study_sessions.group_id` `0010_drop_session_group_id.sql`'de **kasten** düşürüldü; başlıkta gerekçe yazılı: *"Oturum artık yalnızca kullanıcıya aittir; grup istatistiği study_sessions ⨝ group_members join'iyle hesaplanır"* ve K10'da tarihsel veri kaybı açıkça kabul edilmiş.

§8.8 aynı kolonu farklı adla geri getiriyor. Bu yanlış olmayabilir — join tabanlı model çoklu sayımı üretiyor, tespit doğru — ama **ters bir mimari karar** ve ADR'de bu şekilde adlandırılmalı.

Bonus: aynı dosyanın 11. satırı planın §3.8'de temkinli bıraktığı soruyu cevaplıyor: *"⚠️ presence tablosu group_id'yi KORUR — ona dokunma (K9)."* Yani plan "böyle bir not bulunması halinde çelişen bir ADR gerekir" diye şart cümlesi yazmış; çelişki **somut ve mevcut**. Şart cümlesi kesin ifadeye çevrilmeli.

### C5 — Legacy altyapı planın varsaydığından çok daha yakın; iki paralel run-id riski var

§5.4 "eski verified live run doğrudan açılmasın" kararı doğru. Ama plan bu tablonun **ne içerdiğini** hiç saymıyor, ve bu karar kalitesini düşürüyor. `0051_verified_live_sessions.sql` doğrulandı:

| Plan neyi yeni öneriyor (§8) | Legacy'de zaten var mı |
|---|---|
| Kullanıcı başına tek aktif run (partial unique) | ✅ `live_study_runs_one_active_user ... where status in ('running','paused')` (`0051:25-27`) |
| Command idempotency anahtarı | ✅ `unique (user_id, client_request_id)` (`0051:19`) — üstelik doğru şekilde **kullanıcıya scope'lu** (bkz. B3) |
| `accounting_group_id_snapshot` | ✅ `group_id_snapshot`, FK'siz, yorumda "immutable audit/metric snapshot" (`0051:10,22-23`) |
| `source_run_id` (session ↔ run tek bağ) | ✅ `study_sessions.live_run_id` + **UNIQUE** + FK `on delete restrict` (`0051:50-70`) |
| Segment/finalization | ✅ `live_study_segments`, `live_study_segments_one_open_run` |
| Revision / device state / projection | ❌ yok — gerçekten yeni |

Yani planın §8.1/§8.8'de "yeni" diye tasarladığı alanların yarısı üretim şemasında duruyor, ve `study_sessions.live_run_id` **UNIQUE** olduğu için yeni bir `source_run_id` kolonu eklemek aynı satırda **iki ayrı run kimliği ve iki ayrı "tek aktif run" invariant'ı** yaratır. Bu, duplicate session riskini azaltmak için tasarlanan yapının kendisinin bir duplicate kaynağı olması demek.

**Öneri:** Faz 1'de açık bir karar ver ve ADR'ye yaz:
- (a) `live_study_runs`'ı `global_timer_runs`'a **evrimleştir** (revision/lease/device kolonlarını ekle, status enum'unu genişlet, `_verifiedServerAvailable` yerine yeni flag), veya
- (b) yeni tablo aç ve `live_study_runs`'ı **aynı migration'da** tarihsel-salt-okunur ilan et, `study_sessions.live_run_id`'yi yeni run'lar için kullanma ve `source_run_id` ekleme yerine **aynı kolonu** yeniden kullan.

Hangisi olursa olsun `study_sessions` üzerinde ikinci bir run-id kolonu olmamalı. Ayrıca §33 checklist'indeki "eski `live_study_runs` neden kapatıldı" maddesinin cevabı `0063` başlığında yazılı (WP-229: kaynak eşitliği; verified tabloları denetim geçmişi olarak tutuldu) — checklist'e bu bulgu işlenmeli, tekrar araştırılmasın.

### C6 — Presence projection'a lease ve `today_seconds` koymak yazma/realtime amplifikasyonu ve bir **regresyon** üretiyor

§8.4 projection satırına `lease_expires_at` ve `personal_today_seconds` koyuyor, PK `(group_id, user_id)`. İki sonuç:

1. **Amplifikasyon.** Heartbeat lease'i yeniliyorsa (60 sn, §10.5) ve lease projection satırındaysa, kullanıcının üye olduğu her grup için satır güncellenir → N yazma + N Realtime olayı, dakikada. §10.5 "heartbeat revision artırmamalı" diyor ama `updated_at`/`lease_expires_at` yazımı Realtime `postgres_changes` olayını yine tetikler. Grup üye sınırı 8 (`0071_group_member_limit_8.sql`) olduğu için abonelik başına yük küçük; **kullanıcı başına üyelik sayısı sınırsız** olduğu için değişken orada. §23'ün SLO boyutu "group count bucket" değil, "kullanıcının aktif üyelik sayısı" olmalı.

2. **Regresyon riski.** Bugün grup ekranındaki `today_seconds` her heartbeat'te client tarafından tazeleniyor (`presence_lifecycle.dart:84` → `todayRecordedSecondsProvider`). Plan §14.4 client otoritesini kaldırıyor (doğru karar) ama server-derived değerin **tazeleme kadansını hiç tanımlamıyor**. Yalnız session finalization'da yazılırsa, 3 saatlik bir çalışma boyunca grup arkadaşları kullanıcının "bugün"ünün donduğunu görür — bugünden **kötü**. §23.3'te bu kalem için SLO yok.

**Öneri:** lease'i ve `personal_today_seconds`'ı projection satırından çıkar.
- Lease `global_timer_runs`'ta kalsın (tek satır, tek yazma, tek Realtime olayı); grup ekranı "canlı mı" kararını `run_revision` + kendi `started_at`'iyle okuma anında versin.
- Canlı toplam istemcide `finalized_total (server) + (now - started_at)` olarak hesaplansın — sunucu yalnız finalize edilmiş toplamı ve `started_at`'i verir. Bu, §3.10'un "birden fazla bugünkü toplam" riskine de doğru cevap: tek kanonik formül, iki alan.
- Projection satırı yalnız gerçek durum değişiminde (start/stop/phase) yazılsın.

---

## 3. Yanlış veya eskimiş tespitler (P1 — plan "yapılmalı" diyor, kodda zaten var)

Bu bölüm, planın kanıt haritasının koddan değil `docs/archive/TIMER_ARCHITECTURE_REPORT.md`'den türetildiğini gösteriyor.

### D1 — §3.10 "her native interval kalıcı UUID/source key taşımalı" → WP-251 ile zaten var

`TimerStateStore.appendPendingInterval` her aralığa `UUID.randomUUID()` yazıyor ve kod yorumu amacını açıkça söylüyor: *"Dart bunu doğrudan `study_sessions.id` olarak kullanır; kuyruk kısmen başarısız olup tekrar işlense bile upsert AYNI satıra düşer → çift oturum yazılmaz"* (`TimerStateStore.kt:85-113`). Dart tarafı da toptan silmeyi bırakmış: `_dropProcessedPendingEntries` kuyruğu taze okuyup **yalnız işlenen anahtarları** düşürüyor (`study_providers.dart:951-981`, `_pendingEntryKey` `id:`/`legacy:` ayrımıyla).

Planın §3.10'daki dört önlem maddesinin üçü uygulanmış durumda. Açık kalan tek soru: `global run_id` ile native interval `id` arasındaki ilişki — bu gerçekten yeni ve planın doğru sorusu. Diğerlerini "önlem" listesinden çıkar, "korunacak mevcut invariant" listesine taşı (aksi halde bir WP bunu ikinci kez inşa eder).

### D2 — §11.4/§11.6 mirror-stop primitifi zaten var: `ACTION_STOP_SILENT`

Plan "mirror stop session append etmemeli" için yeni bir sözleşme icat ediyor. `StudyTimerService` bunu zaten ayırmış: `ACTION_STOP -> handleStop(recordInterval = true)` ve `ACTION_STOP_SILENT -> handleStop(recordInterval = false)` (`StudyTimerService.kt:72-73`, sabitler `:516-517`). `REMOTE_APPLY_STOP` yeni bir davranış değil, mevcut sessiz durdurmanın revision/run_id CAS'ı ile sarılmış hali.

Bu iyi haber: §21 Faz 7'nin risk profili planın öngördüğünden düşük. Ama plan bu primitifi bilmediği için Faz 7'yi olduğundan büyük tahmin ediyor.

### D3 — §12.3 "dayanıklı command outbox" için native tarafta kuyruk ve monoton dizi zaten var

- `TimerStateStore.appendPendingVerifiedCommand(p, action, runToken, origin)` — native pending **komut** kuyruğu, aynı `KEY_PENDING_INTERVALS` dizisinde (`TimerStateStore.kt:116-137`).
- `timerExternalCommandStoreProvider` + `state.commandSeq` — bildirim/widget komutları için monoton dizi ve tek-seferlik tüketim (`study_providers.dart:987-1005`).

Plan sıfırdan bir `GlobalTimerCommandOutbox` tasarlıyor. Değerlendirme: yeni outbox **gerekli** (account binding, backoff, RPC sonucu saklama bunlarda yok), ama mevcut iki kuyruğun akıbeti planda hiç geçmiyor. Üç kuyruk yan yana yaşarsa hangisinin hangi komutu tuttuğu takip edilemez. Faz 3'e "mevcut pending verified command kuyruğu emekliye ayrılır veya yeni outbox'a göç eder" maddesi girmeli.

### D4 — §3.5'in "fire-and-observe zorunlu" önerisi mevcut bir bilinçli kararı ezmek zorunda

Tespit doğru (`offline_first_presence_repository.dart:44-56` — `catch (_) { queuePresence }`; `_publishPresence` `catchError((_) {})` `study_providers.dart:1516-1519`). Ama bu davranış `OPTIMIZATIONS.md §B12 — Presence heartbeat hata yutma (by design)` olarak **kayıtlı bir karar**: *"presence düşer, timer sürer... timer kaybı yok"*.

Plan bunu "eksiklik" olarak sunuyor; aslında ters çevrilmesi gereken bir karar. ADR listesine girmeli, yoksa gözlem eklemesi "önceki karara aykırı" diye geri çevrilebilir.

### D5 — Migration head 0077, plan 0076'da duruyor

`0077_public_group_time_zone_summary.sql` mevcut ve tam olarak WP-328'in yüzeyi (public keşif + bölge özeti). Planın §21.4'teki "WP-328/329/global timer paralel yazılmamalı" uyarısı doğru; ama kanıt haritası 0077'yi görmediği için uyarının somut gerekçesi eksik.

---

## 4. Ürün ve yol haritası çelişkileri

### E1 — `docs/SAAT-MIMARISI.md §4 Çoklu Timer` ↔ "hesap başına tek aktif run" DB kısıtı

Kanonik saat mimarisi belgesi §4: *"Aynı anda sorunsuzca çalışabilen birden fazla timer desteği (Örn: Makarna Timer'ı 10 dk, Çamaşır Timer'ı 45 dk)"*, önayarlı butonlar, timer başına renk/etiket.

Plan §2.2 "kullanıcının aynı anda iki bağımsız timer çalıştırması"nı kapsam dışı bırakıyor — süreç olarak doğru. Ama §8.1'in `one_open_global_timer_run_per_user` partial unique index'i bu ürün kararını **veri katmanında kilitler**, ve plan `SAAT-MIMARISI.md`'den hiç haberdar değil (§36 listesinde yok).

**Öneri:** invariant'ı bugünden genişletilebilir yaz — örn. `where state in (...) and run_kind = 'study'`, veya `unique (user_id, timer_slot) where ...`. Çoklu timer geldiğinde "çalışma kronometresi" ile "mutfak timer'ı" farklı sınıflar olacak; bunu şimdi bir kolonla ayırmak bedava, sonra ayırmak veri migration'ı.

### E2 — Pause/resume üründe yok; `paused` state'i v1'den çıkarılmalı

§7.2 "mevcut timer'da pause semantiği belirsizse start/stop ile başlanıp pause ayrı faza bırakılsın" diyor ve kararı erteliyor. Cevabı veriyorum: **pause yok.** `study_providers.dart`'ta pause/resume metodu bulunmuyor; olan şey start/stop ve mola fazı (`ACTION_START_BREAK`/`ACTION_END_BREAK`, `TimerPhase.work`/`TimerPhase.rest`).

Sonuç: `global_timer_runs`'tan `paused_at`, `elapsed_before_phase_ms`, `state = 'paused'` ve `apply_global_timer_command`'ın `pause`/`resume` action'ları v1'de **çıkarılmalı**. Mola bir phase'dir ve B6'nın deterministik türetmesiyle komut bile gerektirmez. Bu, RPC'nin state matrisini (§7.3) yarıya indirir.

Not: `live_study_runs.status` zaten `'paused'` içeriyor (`0051:12-13`) — legacy tasarımın pause'u vardı, ürün onu hiç kullanmadı. Aynı hatayı tekrarlamayın.

### E3 — Çoklu grup presence, sosyal başarımların **girdi sinyalini** değiştiriyor; plan yalnız attribution'dan söz ediyor

`docs/BASARIM-MIMARISI.md:140` — Lokomotif: *"Grupta kimse çalışmıyorken (0 aktif) masaya ilk senin oturman ve ardından gelen 15 dakika içinde en az 2 grup üyesinin daha... çalışmaya başlaması."* Metrik `group_achievement_daily.locomotive_events` (`0053:10`).

Bu metriğin **tetikleyicisi** bir grupta kimin canlı olduğudur. Plan kullanıcıyı bugüne kadar tek grupta görünürken artık **tüm gruplarda** canlı yapıyor. Yani:

- B grubunda (primary değil) kullanıcı ilk oturan olur ve 2 kişi peşinden gelir → Lokomotif olayı B'de tetiklenir ama §14A.5'e göre B'ye progression yazılmaz. Olay **düşer mi**, A'ya mı yazılır?
- Tersi: A'da (primary) kullanıcı hiç ilk oturan değil ama tüm gruplarda canlı göründüğü için diğer üyelerin Lokomotif/Kamp Ateşi koşullarını **değiştiriyor** — başka kullanıcıların metrikleri etkileniyor.

§14A.10 `locomotive`'i "yalnız accounting group'ta ilerler" diye sınıflandırıyor; bu attribution cevabı, tetikleme cevabı değil. Bu, plan onaylanmadan cevaplanmalı çünkü **başka kullanıcıların** kazanımını etkiliyor.

### E4 — Grup üye limiti 8; SLO boyutu yanlış değişkende

`0071_group_member_limit_8.sql` doğrulandı. §24.2 telemetri boyutları arasında "group count bucket" var; asıl amplifikasyon değişkeni **kullanıcının üyelik sayısı** (sınırsız) ve §22.8'de 10 grup senaryosu test ediliyor ama §23'te buna bağlı bir SLO yok. C6'nın yazma amplifikasyonu bu değişkende lineer.

---

## 5. Süreç ve belge tutarlılığı

| # | Bulgu | Öneri |
|---|---|---|
| F1 | `docs/adr` dizini **yok**; `.agents/AGENTS.md` ve `docs/KALITE-PROGRAMI.md` içinde "ADR" hiç geçmiyor | Faz 1 çıkış kapısı "15 ADR onaylı" diyor ama ADR'nin yeri/formatı/onay biçimi tanımlı değil. Ya ADR konvansiyonunu ilk iş olarak kur, ya da kararları `docs/KALITE-PROGRAMI.md` altında "Karar Kayıtları" bölümü olarak yaz. Uygulanamaz kapı, kapı değildir. |
| F2 | §36 ilgili belgeler listesi eksik | Ekle: `docs/recovery/STATS-CONTRACT.md` (C1 — sözleşme çelişkisi), `docs/SAAT-MIMARISI.md` (E1), `docs/BASARIM-MIMARISI.md` (E3), `docs/recovery/MIGRATION-BASELINE.md`, `OPTIMIZATIONS.md` (D4) |
| F3 | §3.9 kanıt haritası satır numarası vermemeyi bilinçli seçmiş — **doğru karar** | Ama D1–D3'teki üç madde kodda çözülmüş olduğu için harita eski rapordan türetilmiş. Uygulama başında graph index'ten yeniden üretilsin (plan bunu §3.9 sonunda kendisi söylüyor; §3.10'un önlem listesi bu kurala uymamış). |
| F4 | 12 faz × tek dal `main` × timer dosyalarında tek sahipli lane | Program tamamen seri yürümek zorunda. Plan bunu §32'de kabul ediyor ama takvim/sıra sonucunu yazmıyor. En azından "hangi faz hangi ortama kadar gider" ve "hangi fazlar aynı WP'ye birleşebilir" kararı Faz 1'de verilmeli; 12 ayrı fazın 12 ayrı beta turu anlamına gelmesi ihtimali sahibin maliyet kabulünü değiştirir. |
| F5 | §19'da 17 zorunlu + §30'da 32 review sorusu | Bunların çoğu cevaplanmadan kod yazılabilir. Gerçekten **bloklayıcı** olanlar: B1 (revision skalası), B2 (recovery semantiği), B6 (phase otoritesi), C2 (gün muhasebesi modeli), C5 (legacy tablo kararı), E2 (pause v1'de mi), E3 (sosyal metrik tetikleme). Diğerleri faz içinde çözülebilir. Uzun soru listesi kararı geciktiriyor. |

---

## 6. Korunması gereken doğru kararlar

Bunları zayıflatmadan ilerlenmeli:

- **Local-first + server-coordination ayrımı** (§5.1). Tam server-first reddi doğru gerekçelendirilmiş.
- **FCM = sinyal, PostgreSQL = truth** (§4.4, §13.1). Bu repoda daha önce bedeli ödenmiş bir ders (`fcm-data-only`, `notif-not-syncing`).
- **Mirror cihaz session/XP yazmaz** (§11.4). Programın tek gerçek P0 veri riski bu ve doğru yerde kilitlenmiş.
- **§14A.6 fan-out tespiti.** Kodda doğrulandı, ürün için kritik, ve WP-329'un "yalnız bir seçim ekranı değil" tespiti doğru.
- **§14A.3'ün iki okunuş ayrımı.** Bu belgenin en yüksek değerli 10 satırı; WP-329 kartına aynen geçmeli.
- **§29 kesin uyarılar.** Pratik, uygulanabilir, çoğu doğrulandı. Sadece 6. madde (quiet-hours) kod değişikliği olmadan **ihlal** durumda (B4).
- **Donuk native sözleşme** (§11.1). Sırayı `StudyTimerService.handleStart`'a karşı doğruladım: store → `startForegroundCompat` → notify → `TimerWidgets.updateAll` → `notifyStateChanged` (`StudyTimerService.kt:117-138`), ve kodda "Deterministik sıra: store → UI yüzeyler → Dart broadcast" yorumu var. Plan bu sözleşmeyi doğru okumuş.

---

## 7. Kapsam önerim — ne keserdim

Plan 12 faz + 15 ADR + 12 feature flag'lik tek bir program. Kullanıcının §1.2'de saydığı bugünkü şikâyetin **üçte ikisi global run olmadan çözülebilir** ve bu, programın 3 fazını beklemez.

**Teslim A — çoklu grup görünürlüğü (global run'a bağımlı değil).**
Presence'i "kullanıcının global durumu, üyeliklere dağıtılmış" modeline geçirmek için gereken minimum: presence yazımını client fan-out'undan çıkaran bir server RPC (`set_presence_state(status, started_at, subject)`), fan-out'u transaction içinde yapan projection, ve okuma tarafının projection'a geçmesi. Bu, `global_timer_runs`, command ledger, revision, device state, FCM ve finalizer'ın **hiçbirine** ihtiyaç duymaz. §5.3'ün "sadece presence PK'sını değiştirmek yetmez" itirazı doğru — ama itiraz *client fan-out'a* karşı, *server projection'a* karşı değil. Plan Faz 4'ü Faz 2-3'ün arkasına koymuş; bu sıralama gereksiz.

Bu teslim §1.2'nin 1., 4. ve 5. semptomlarını bitirir.

**Teslim B — widget/bildirim kaynaklı presence boşluğu.**
Native start Flutter kapalıyken presence yazamıyor (§3.3, doğrulandı). Tam çözüm native auth'tur (§9.6, riskli). Ama %90'ı ucuz: cold-start reconcile zaten çalışıyor (`_syncBackgroundTimerState`), ve `started_at` native store'da duruyor — yani uygulama açıldığında **geçmişe dönük doğru `started_at` ile** presence yazılıyor. Kalan boşluk "hiç açılmazsa" senaryosu, ki onun gerçek çözümü de push/native credential değil, sunucunun `started_at`'i kabul etmesidir. Teslim A'nın RPC'si bunu zaten yapar.

**Teslim C — global run + command ledger + remote stop.**
Planın Faz 2/3/5/7'si. Buradan itibaren gerçekten yeni altyapı gerekiyor. B1, B2, B3, B6 ve C5 kararları bu teslimden **önce** verilmeli.

**Ayrı programa taşınacaklar:**
- Gün sınırı / saat dilimi muhasebesi (C1, C2) — kendi RFC'si, WP-329'dan sonra.
- Server finalization (Faz 10) — C3, C4, C5 çözülmeden başlanmamalı.
- Remote start (Faz 8) — B5 nedeniyle en düşük değer/risk oranı; kullanıcı şikâyet listesinde yok.

Değerlendirme: A + B tek WP çiftiyle, C ise 3-4 WP ile sevk edilebilir. Planın 12 fazı bu üç teslimin içine sığar; 12 ayrı beta turu gerekmez.

---

## 8. Kod yazılmadan cevaplanması gereken yedi soru

Planın 49 sorusundan gerçekten bloklayıcı olanlar:

1. **Revision skalası:** run başına mı, kullanıcı başına mı? (B1 — cevap: ikisi de, ayrı alanlar)
2. **Ölü run yeni çalışmayı engelleyecek mi?** (B2 — cevap: hayır, `recovery_required` unique index'ten çıkmalı)
3. **Pomodoro phase otoritesi:** mutable kolon mu, immutable girdiden türetme mi? (B6 — cevap: türetme)
4. **Gün muhasebesi modeli:** oturum atomik mi, dilimlenir mi? (C2 — şu an şemada ikisi birden var)
5. **`live_study_runs` evrimleşecek mi, emekli mi olacak?** (C5 — `study_sessions`'ta ikinci run-id kolonu olmamalı)
6. **Pause v1'de var mı?** (E2 — cevap: üründe pause yok, şemadan çıkarılmalı)
7. **Çoklu grup presence sosyal başarım tetiklemesini nasıl etkiliyor?** (E3 — başka kullanıcıların kazanımını etkilediği için ürün kararı)

Bunlar cevaplanınca §8'in şeması ve §10'un RPC sırası tekrar yazılmalı; sonra Faz 2'ye girilebilir.

---

## 9. Özet tablo

| ID | Bulgu | Şiddet | Tür |
|---|---|---|---|
| B1 | `revision` skalası tanımsız → yeni run mirror'da kalıcı no-op | 🔴 P0 | Protokol hatası |
| B2 | `recovery_required` unique index'te → ghost run yeni start'ı kilitler, adopt saatlik sıçrama yapar | 🔴 P0 | Protokol hatası |
| B3 | `command_id` global unique + snapshot dönüşü → hesaplar arası sızıntı | 🔴 P0 | Güvenlik |
| B4 | Push transport `timer_sync`'i sessizce yutar (6 somut engel) | 🔴 P0 | Eksik kapsam |
| B5 | FCM giriş noktası Dart isolate; "native receiver" varsayımı yok | 🟠 P0/P1 | Mimari boşluk |
| B6 | Mutable `phase` → offline'da otorite yok; deterministik türetme gerekli | 🟠 P1 | Tasarım basitleştirmesi |
| C1 | Gün sınırı = 24 migration + PK kolon adı + 29 Dart dosyası + test'li sözleşme | 🔴 P1 | Kapsam yanlış ölçülmüş |
| C2 | İki gün muhasebesi modeli zaten yan yana; plan seçim yapmıyor | 🟠 P1 | Karar eksiği |
| C3 | Attribution filtresi projeksiyon fonksiyonunda olmalı; cron çoklu sayımı geri yazar | 🟠 P1 | Eksik kapsam |
| C4 | `attributed_group_id` = 0010'da bilinçli düşürülen kolon; ters karar ADR'si şart | 🟡 P1 | Belge tutarlılığı |
| C5 | Legacy tablo planın varsaydığından yakın; iki paralel run-id riski | 🟠 P1 | Mimari risk |
| C6 | Projection'da lease + today_seconds → amplifikasyon + "bugün donar" regresyonu | 🟠 P1 | Tasarım hatası |
| D1 | Pending interval UUID/idempotency **zaten var** (WP-251) | 🟡 P1 | Eskimiş tespit |
| D2 | Mirror-stop primitifi **zaten var** (`ACTION_STOP_SILENT`) | 🟡 P2 | Eskimiş tespit |
| D3 | Native command kuyruğu + `commandSeq` zaten var; üç kuyruk riski | 🟡 P1 | Eksik kapsam |
| D4 | Fire-and-forget bir **kayıtlı karar** (OPTIMIZATIONS B12); ters ADR gerekir | 🟡 P2 | Belge tutarlılığı |
| D5 | Migration head 0077, plan 0076'da | 🟢 P2 | Kanıt eksiği |
| E1 | SAAT-MIMARISI §4 Çoklu Timer ↔ tek-aktif-run DB kısıtı | 🟠 P1 | Yol haritası çelişkisi |
| E2 | Pause üründe yok; `paused` state v1'den çıkmalı | 🟡 P1 | Gereksiz karmaşıklık |
| E3 | Çoklu grup presence sosyal başarım **tetiklemesini** değiştiriyor | 🟠 P1 | Cevapsız ürün kararı |
| E4 | SLO boyutu "grup sayısı" değil "kullanıcının üyelik sayısı" olmalı | 🟢 P2 | Ölçüm |
| F1 | `docs/adr` yok; Faz 1 çıkış kapısı uygulanamaz | 🟡 P1 | Süreç |
| F2 | §36 ilgili belgeler eksik (5 kanonik doküman) | 🟡 P1 | Belge tutarlılığı |
| F3 | Kanıt haritası koddan değil arşiv raporundan türetilmiş | 🟡 P1 | Süreç |
| F4 | 12 faz × tek dal → seri yürütme maliyeti yazılmamış | 🟡 P2 | Planlama |
| F5 | 49 soru; gerçekten bloklayıcı 7 tanesi | 🟢 P2 | Planlama |

---

## 10. Sonuç

Plan **reddedilmemeli, revize edilmeli**. Mimari yön, invariant seçimi ve donuk-native disiplini doğru. Sorun iki yerde:

1. Protokol katmanı henüz tutarlı değil — B1/B2/B3/B6 yazıldığı gibi kodlanamaz.
2. Kapsam, gün sınırı ve legacy şema tarafında olduğundan küçük ölçülmüş; C1 ve C5 tek başlarına ayrı karar/program gerektiriyor.

Önerim: §8 ve §10'u B1/B2/B3/B6/E2 kararlarıyla yeniden yaz; gün sınırını (C1/C2) ayrı RFC'ye çıkar; Teslim A'yı (§7) global run programından **önce** ve bağımsız sevk et. Bu haliyle kullanıcının bugünkü şikâyeti 12 faz beklemeden çözülür, ve global run altyapısı çözülmüş bir presence modeli üzerine kurulur — tersi değil.
