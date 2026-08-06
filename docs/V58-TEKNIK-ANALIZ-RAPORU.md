# v58 Teknik Analiz Raporu

> **Tarih:** 6 Ağustos 2026 · **Sürüm:** v58 stable (tag `v58`, aday `3ede412`,
> release `9365895`, production migration head `0119`)
> **Girdi:** `docs/V58-SAHIP-GERI-BILDIRIM-RAPORU.md` (11 ham belirti)
> **Revizyon 1 (2026-08-06):** sahip kararları (seçili grup, sade rozet) ve
> N10-N11 eklendi; T06/T08/T10 yeniden yazıldı, T14 açıldı.
> **Revizyon 2 (2026-08-06):** sahip talebiyle tam doğrulama turu — T01 ve T11'in
> gerekçesi **düzeltildi**, T05/T09/T10 kanıtı sertleştirildi. Bkz. §2.5.
> **Yöntem:** yalnız **statik kod analizi**. Cihazda koşum, logcat, profil ve
> production sorgusu **yapılmadı**; her bulgunun kanıt seviyesi ayrıca yazılıdır.
> **Amaç:** belirtiden koda inmek, kök nedeni dosya:satır ile göstermek ve her
> bulgu için tek bir düşürücü (falsifying) test önermek.

---

## 0. Yönetici özeti

Dokuz belirtinin **altısı tek tek koda kadar izlendi**. Bunlar birbirinden
bağımsız hatalar değil, **beş sistemik desenin** yüzeye vuruşları:

| # | Desen | Bu turda ürettiği belirti |
|---|---|---|
| D1 | Dart ↔ native `SharedPreferences` sözleşmesinde **tip asimetrisi** | Geri sayım + pomodoro çökmesi (N05) |
| D2 | **Bitmiş backend, bağlanmamış yazma yolu** | Seri hiç çalışmıyor (N03) |
| D3 | `AsyncValue` **yükleniyor** durumunun "veri yok" sayılması | "create group" flaşı, kaybolan taç (N02), aktif çalışmanın kaybolması (N07) |
| D4 | `build()` içinde **stream/abonelik açmak** | Grup ekranının sürekli yenilenmesi + yavaşlık (N01) |
| D5 | Yerleşimin **sabit piksel varsayımlarına** dayanması | Beş ayrı UI kusuru (N04) |

Ayrıca iki **veri modeli/ürün sözleşmesi** hatası var: ayna cihaz durdurmasının
hiçbir şey kaydetmemesi (N08) ve haftalık grup başarımının gruplar arasında
toplanması (N06).

**En kritik bulgu:** geri sayım ve pomodoro çökmesi bir Flutter hatası değil,
**native süreç ölümü**. `SharedPreferences.getInt()` çağrısı, Dart tarafının
`putLong` ile yazdığı aynı anahtarı okuyor → `ClassCastException`. Kronometrede
çökme olmamasının sebebi tam olarak budur: o modda ilgili anahtar hiç yazılmaz.

---

## 1. Kanıt seviyeleri

| Seviye | Anlamı |
|---|---|
| **A — Doğrulandı** | Kaynak kodda determinist olarak gösterildi; mekanizma tek yoruma açık. Cihazda koşum gerekmez, yalnız teyit için istenir. |
| **B — Güçlü hipotez** | Mekanizma ve kod yolu belirlendi; tetikleyici koşul (veri/cihaz durumu) doğrulanmadı. |
| **C — Veri bekliyor** | Belirti gerçek; kök neden için üretim verisi ya da iz kaydı şart. |

---

## 2. Bulgular

### T01 — Geri sayım ve pomodoro çökmesi: prefs tip asimetrisi (N05)

**Seviye: A · Şiddet: Kritik · Etki: uygulama süreci ölüyor**

**Mekanizma.** Flutter'ın `shared_preferences` Android eklentisi Dart `int`
değerini **`putLong`** ile yazar. Kanıt, eklentinin kendi kaynağında:

```
shared_preferences_android-2.4.26/.../SharedPreferencesPlugin.kt:317
  override fun setInt(key: String, value: Long, ...) =
      createSharedPreferences(options).edit().putLong(key, value).apply()
```

Dart tarafı sayaç durumunu bu API ile yazıyor:

```
app/lib/data/providers/study_providers.dart:2415  prefs.setInt(_kActiveStartedAtMs, ...)   // → putLong
app/lib/data/providers/study_providers.dart:2418  prefs.setInt(_kActiveCycle, state.cycle) // → putLong
app/lib/data/providers/study_providers.dart:2421  prefs.setInt(_kActiveTargetSeconds, ...) // → putLong
```

Native taraf **aynı anahtarları** okuyor ama iki farklı tiple:

```
app/android/.../widgets/StudyWidgetProviders.kt:115
    appPrefs.getLong("flutter.timer_active_started_at_ms", 0L)      // ✅ doğru
app/android/.../widgets/StudyWidgetProviders.kt:122
    appPrefs.getInt("flutter.timer_active_target_seconds", 0)       // 💥 ClassCastException
app/android/.../timer/StudyTimerService.kt:205, 239
    p.getInt(TimerStateStore.KEY_CYCLE, 1)                          // 💥 ClassCastException
```

`SharedPreferencesImpl.getInt` gövdesi `(Integer) mMap.get(key)` yapar; değer
`Long` ise **atılan istisna yakalanmaz**.

**Neden yalnız geri sayım ve pomodoro?**

- `timer_active_target_seconds` yalnız `phaseTargetSeconds != null` iken yazılır;
  kronometrede `prefs.remove(...)` çağrılır (`study_providers.dart:2423`). Anahtar
  yoksa `getInt` varsayılan `0` döner, çökme olmaz.
- `getInt(KEY_CYCLE)` çağrılarının ikisi de **mola** yollarındadır
  (`handleStartBreak`, `handleEndBreak`) — mola yalnız pomodoroda vardır.

**Neden anahtarın tipi değişken?** İki yazıcı var ve **farklı tip yazıyorlar**:
native `TimerStateStore.writeRunning` `putInt` (satır 128, 131), Dart
`_persistActiveTimer` `putLong`. Son yazan kazanır.

**Başlatmadaki sıra (2026-08-06 doğrulama turunda düzeltildi).** İlk taslak
"Dart, native çağrıdan sonra yazıyor" diyordu; **yanlıştı**. `start()` gövdesinde
sıra şudur:

```
study_providers.dart:1852  _persistActiveTimer();                     // putLong  ← ÖNCE
study_providers.dart:1868  unawaited(_bindStartAndPublishGlobalTimer…) // native putInt (async, SONRA)
study_providers.dart:1882  unawaited(_showTimerSurfaces(...));        // → _syncTimerWidget()
```

Sonuç aynı kapıya çıkıyor ama gerekçe **daha güçlü**: widget tazelemesi (1882)
native servisin `writeRunning`'inden **önce** koşar, çünkü native yol
`startForegroundService` → `onStartCommand` zincirini bekler. Yani widget
`onUpdate` prefs'i okuduğu anda değer kesinlikle **Long**'dur. Bu, hatayı
"yarışa bağlı ara sıra" olmaktan çıkarıp **başlatmada beklenen sonuç** hâline
getirir — sahibin "basar basmaz" ifadesiyle birebir uyuşan da budur.

**Zincir uçtan uca doğrulandı:**

```
_syncTimerWidget() → HomeWidget.updateWidget(...)
  → HomeWidgetPlugin.kt:110-116  intent.action = ACTION_APPWIDGET_UPDATE; context.sendBroadcast(intent)
  → TimerWidgetProvider.onReceive → onUpdate   (uygulama süreci, try/catch YOK)
  → appPrefs.getInt("flutter.timer_active_target_seconds")   💥
```

`TimerWidgetProvider.onUpdate` gövdesinde tek `runCatching` ISO tarih
ayrıştırmasında (satır 118); prefs okumaları korumasız. Dosyadaki diğer `try`
(satır 365) alarm widget'ının JSON ayrıştırmasına ait. Bir `BroadcastReceiver`
içindeki yakalanmamış istisna **süreci öldürür**; kullanıcının gördüğü "alta
atıyor" budur, Flutter hata ekranı çıkmaz çünkü çöken katman Dart değildir.

**Prefs arka ucu da doğrulandı.** Uygulama eski (legacy) `SharedPreferences`
API'sini kullanıyor (`SharedPreferences.getInstance()`), yani XML dosyası
`FlutterSharedPreferences` ve yazım `putLong` (`SharedPreferencesPlugin.kt:317`).
Yeni `SharedPreferencesAsync`/DataStore arka ucu (aynı dosyada satır 96) devrede
olsaydı anahtar bambaşka bir depoya yazılırdı ve native taraf hiç göremezdi —
öyle olmadığını `timer_active_started_at_ms`'in sahada çalışıyor olması da
gösteriyor.

**Ön koşul (düşürücü test).** Widget yolu yalnız **ana ekranda yerleştirilmiş bir
sayaç widget'ı varsa** tetiklenir. Sayaç widget'ını ana ekrandan kaldırıp geri
sayımı başlat: çökme kesiliyorsa T01 doğrulanmıştır. Pomodoro çökmesi ayrıca
çalışma→mola geçişinde widget olmadan da tekrarlamalıdır.

**Doğrulama komutu:**

```
adb logcat -b crash -v time | grep -i "ClassCastException\|timer_active"
```

**Düzeltme yönü.** Tip sözleşmesini **tek yerde** sabitle: prefs'e giden tüm
sayısal sayaç alanları `Long` olsun; native okuma `getLong(...).toInt()` yapsın ve
`TimerStateStore.writeRunning` `putInt` yerine `putLong` yazsın. Ek olarak her
native prefs okuması `runCatching` ile sarılmalı — widget sağlayıcısındaki tek bir
istisnanın uygulamayı öldürmesi kabul edilemez.

**Kapı neden kaçırdı?** `TimerChronometerProjectionTest` **saf fonksiyonu** test
ediyor (`timerChronometerProjection`), prefs okumasını değil. Yani kırılan satır
hiçbir testin altından geçmiyor. Bu, projedeki tekrar eden "iki uçlu sözleşme
testi yoksa sessizce ölür" dersinin native karşılığıdır.

---

### T02 — Seri hiçbir zaman artmıyor: yazma yolu hiç bağlanmamış (N03)

**Seviye: A · Şiddet: Kritik · Etki: özellik yok hükmünde**

Okuma tarafı eksiksiz: `goal_streak_projection` RPC → repository → provider →
rozet. Rozet de artık daima çiziliyor (WP-481).

**Yazma tarafı yok.** `goal_progress_events` tablosuna satır yazan **tek** yol
`record_goal_completion` RPC'sidir (`supabase/migrations/0112_goal_streak_projection.sql:96`)
ve bu RPC'yi çağıran hiçbir tetikleyici ya da istemci kodu yoktur:

- `supabase/migrations/` içinde `goal_progress_events` yalnız `0112`'de geçer;
  `study_sessions` üzerinde tamamlama yazan **trigger yok**.
- `app/lib/` içinde `record_goal_completion` yalnız **yorum satırlarında** geçer
  (`goal_streak_providers.dart:28`, `supabase_goal_streak_repository.dart:19`).
  `completionParams(...)` (satır 96) üretimde **hiçbir yerden çağrılmıyor** —
  tek çağıran `test/data/goal_streak_parity_wp453_test.dart:93`.

Sonuç: `last_completed_day` daima `null` → repository `_empty(...)` döndürüyor →
rozet `GoalStreakState.empty` → **her zaman gri alev + `0` + "Henüz seri yok"**.
Ekran görüntüsü 3 birebir bu durumdur.

**Kritik ayrım:** bu bir "seri hesabı yanlış" hatası değil; **seri hiç
kaydedilmiyor**. Hedef tutturulsa bile ekran değişmez. Sahip haklı olarak
"çalışmıyor" diyor.

**Doğrulama sorgusu (production):**

```sql
select count(*) from public.goal_progress_events;          -- beklenen: 0
select * from public.goal_streak_projection('personal', '<user_id>', current_date);
```

**Düzeltme yönü.** Tamamlamayı **sunucunun** yazması doğrusudur: `study_sessions`
insert/update sonrası, gün toplamı hedefi geçtiğinde `record_goal_completion`'ı
çağıran bir trigger ya da hedef değişiminde de yeniden değerlendiren bir job.
İstemciden çağırmak (a) çevrimdışı cihazda seriyi düşürür, (b) `0112`'nin
"tek yazıcı sunucudur" tasarım kararını bozar. Grup serisi de aynı yoldan gelir;
tek düzeltme iki belirtiyi birden kapatır.

**Kapı neden kaçırdı?** `037_goal_streak_projection.test.sql` RPC'yi **doğrudan
çağırarak** test ediyor; "bu RPC'yi üretimde kim çağırıyor" sorusunu hiçbir test
sormuyor. Bu, `bitmis-backend-baglanmamis-ui` dersinin üçüncü tekrarıdır.

---

### T03 — Grup ekranı sonsuz yenileme + realtime abonelik sızıntısı (N01)

**Seviye: A (kod) / B (yavaşlığın tamamını açıkladığı) · Şiddet: Yüksek**

```
app/lib/features/classroom/widgets/class_detail_screen.dart:866
    child: StreamBuilder<List<Profile>>(
             stream: repo.watchMembers(group.id),      // ← build() içinde yaratılıyor
```

`watchMembers` ucuz bir getter değil; **her çağrıda yeni bir Supabase realtime
aboneliği açıyor ve her emisyonda bir RPC atıyor**:

```
app/lib/data/repositories/supabase/supabase_group_repository.dart:288-308
    _client.from('group_members').stream(primaryKey: [...]).eq(...)
        .asyncMap((rows) async { ... await _client.rpc('group_member_directory', ...) })
```

Aynı `build()` içinde `groupPresenceProvider` ve `mutedNudgeSenderIdsProvider`
izleniyor (satır 855-863). Presence saniyeler mertebesinde değişir → widget
yeniden kurulur → **yeni stream** → `snapshot.data == null` → tam kart yerine
`CircularProgressIndicator` (satır 872-877) → veri gelir → yeniden çizim…
Kullanıcının gördüğü "sürekli ekran yenilenip geliyordu" tam olarak budur.

Yan etkiler: her turda bir realtime kanal + bir RPC; eski kanallar kapanmadığı
için abonelikler birikir. Reboot sonrası iki gün süren yavaşlığın **kaynağı değil
ama çarpanı** budur: kanal sayısı arttıkça soğuk açılışta el sıkışma maliyeti
büyür, uygulama kapanınca sıfırlanır — belirtinin "kendiliğinden geçmesi" bu
resimle tutarlıdır.

**Not:** bu desen repoda **tek yerde** var; `grep -rn "StreamBuilder" lib/features`
yalnız bu satırı döndürüyor. Yani düzeltme lokal.

**Düzeltme yönü.** Üye akışını bir `StreamProvider.family` arkasına al (Riverpod
zaten her yerde kullanılıyor), `StreamBuilder`'ı kaldır. Ayrıca "veri yok" →
tam ekran spinner yerine **son bilinen listeyi koru** (bkz. T04).

---

### T04 — Yükleniyor durumu "veri yok" sayılıyor: create-group flaşı ve kaybolan taç (N02, N07)

**Seviye: A · Şiddet: Yüksek (algılanan kalite)**

İki ayrı yerde aynı hata sınıfı:

**(a) "Currently studying" kartı — "create group" flaşı**

```
app/lib/features/home/widgets/active_members_card.dart:29-36
    final group = ref.watch(userGroupProvider).value;
    if (group == null) {
      return GroupCardShell(... onCreateGroup: ..., onJoinGroup: ...);
    }
```

`AsyncValue.value`, **ilk yüklemede** `null` döner (yenilenmede önceki değeri
korur; asıl tuzak burada değil, `asData`'da — bkz. (b)). Yani soğuk açılışta
"grup henüz yüklenmedi" ile "kullanıcının grubu yok" aynı dala düşüyor ve kullanıcıya
`GroupCardShell` — yani "Bir gruba katılınca burada…" + **Grup Oluştur** butonu —
gösteriliyor (`group_card_shell.dart:33-60`). Veri gelince kart yerine oturuyor.
Sahibin gördüğü flaş budur.

**(b) Taç gidip geri geliyor**

```
app/lib/core/widgets/crowned_avatar.dart:459-463
    final rank = ref.watch(gamificationProfileProvider(userId)).asData?.value.crownRank;
```

`asData`, sağlayıcı **yenilenirken** `null` döner — `AsyncData` olmayan her
durumda null olduğu için önceki değeri korumaz. `.value`/`.valueOrNull` ise
yenilenmede önceki veriyi taşır; ikisi arasındaki bu fark hatanın tamamıdır. Provider her invalidate/refresh turunda taç bir kare kayboluyor, sonra
geri geliyor. Doğrusu `valueOrNull` (yenilenme sırasında son veriyi korur).

**(c) Aynı sınıfın üçüncü örneği** — aktif üye listesi
(`active_members_card.dart:38-39`) `.value ?? const []` ile yükleniyor durumunu
**boş liste** sayıyor. N07'nin ("grupta aktif çalışma bazen gözükmüyor") en olası
açıklaması budur; presence akışı yeniden kurulurken liste bir süre boş çizilir.

**Düzeltme yönü.** Üç durumu (yükleniyor / veri / hata) ayırmayan hiçbir yüzey
kalmasın: yükleniyorken **son bilinen veri** veya iskelet gösterilsin; "boş
durum" yalnız `hasValue && value.isEmpty` iken çizilsin. `.value ?? const []` ve
`.asData?.value` kullanımları repo genelinde taranmalı — bu üç örnek muhtemelen
tek değil.

---

### T05 — Ayna cihazda Durdur hiçbir şey kaydetmiyor + 12 saatlik hayalet koşu (N08)

**Seviye: A (kayıt yolu) / B (12 saatlik pencerenin sahadaki payı) · Şiddet: Kritik**

İki kusur üst üste biniyor.

**(a) Ayna durdurması oturum yazmıyor.**

```
app/lib/data/providers/study_providers.dart:2109-2133  stopMirroredRun()
    state = state.copyWith(isStopping: true, clearSettling: true);
    await coordinator.stopMirroredRun(runId: ..., expectedRunRevision: ...);
    _finish();                                   // ← settlingSeconds YOK, _recordSession YOK
```

Normal `stop()` yolu (satır 2046-2060) kaydedilecek saniyeyi hesaplayıp
`settling*` alanlarına yazar ve `_recordSession(...)` çağırır. Ayna yolu bunların
**hiçbirini** yapmaz; yalnız sunucudaki koşuyu kapatır. Dolayısıyla ekranda
görünen 4-5 saat, Durdur'a basıldığında **hiçbir günlük toplama eklenmez** —
sahibin "stop diyorum, toplam sürede değişmiyor" dediği davranış tam da budur ve
kodun bugünkü hâlinde **beklenen** davranıştır.

Süreyi origin cihazın (tablet) yazması gerekir; o cihaz kapalı/uykudaysa süre
hiçbir yere yazılmaz. Yani veri sadece "görünmüyor" değil, **kayıp**.

**(b) Koşu 12 saat boyunca "çalışıyor" kalıyor.**

`supabase/migrations/0119_global_timer_lease_recovery_grace.sql` v58'de tam da bu
turda geldi: lease süresi dolan koşu artık **12 saat** boyunca terminal
`abandoned` durumuna geçmiyor (`lease_expires_at <= v_now - interval '12 hours'`).
Gerekçesi doğru (Android Dart isolate'i askıya alırken native sayaç yaşamaya devam
ediyor), ama sonucu şu: tablette unutulan bir koşu yarım gün boyunca canlı sayılır
ve telefon açıldığında **ayna olarak birikmiş süreyi** gösterir.

**Bu, v58'de değişen ve cihazda hiç doğrulanmayan bir davranıştır** — belirtinin
bu turda ortaya çıkması tesadüf değil.

**(c) Doğrulama turunda ortaya çıkan üçüncü katman: kayıp yalnız aynada değil.**
İlk taslak "süreyi origin cihaz yazmalı" diyordu; origin de yazmıyor:

- Sunucuda ayrı bir `stop_mirrored_run` RPC'si **yok**; Dart
  `apply_global_timer_command(action: 'stop')` çağırıyor
  (`global_timer_providers.dart:194-203`). O fonksiyonun stop dalı yalnız
  `live_study_runs.status = 'stopped'` yazıp presence'ı kapatıyor
  (`0101_global_timer_controller_contract.sql:274-281`) — `study_sessions`'a
  **hiçbir insert yok**. (`insert into public.study_sessions` tüm migration'larda
  tek yerde: `0051`'deki `finalize_verified_live_run`, ve o yalnız
  `run_token`'lı verified koşu için çağrılır.)
- Origin cihaz uzak durdurmayı öğrendiğinde de kayıt yapmıyor:
  `_applyRemoteMirrorStop` → `_finish(globalTimerStoppedRemotelyAt: …)`
  (`study_providers.dart:1154`). `_finish` zaten belgesinde "**kayıt yapmadan**
  durdurur" diyor ve native tarafa giden `STOP_SILENT` kuyruğa aralık yazmaz.

Yani uzaktan/aynadan durdurulan bir koşunun süresi **iki uçta da** hiçbir yere
yazılmıyor. Bu, "toplam değişmiyor"un tam açıklamasıdır ve belirtinin
şiddetini yükseltir: veri geç gelmiyor, **hiç gelmiyor**.

**Düzeltme yönü — sıralı:**
1. Ayna durdurmasını **kayıtlı** hâle getir: sunucu, koşuyu kapatırken oturumu
   kendisi yazsın (`stop_mirrored_run` içinde `study_sessions` kaydı). İstemciden
   yazmak çift kayıt riski taşır; tek yazıcı sunucu olmalı.
2. Terk edilmiş koşu için 12 saat **çok uzun**. Native sayacın canlılığını lease
   yerine ayrı bir sinyalle ölç (FGS heartbeat'i zaten var) ve grace'i o sinyale
   bağla; sinyal yoksa 1-2 saat sonra kapat.
3. Kullanıcıya "başka cihazda X saattir açık koşu var, kapatılsın mı?" sorusu —
   sessizce 4 saat biriktirmekten iyidir.

---

### T06 — `alpha_wolf_weekly` gruplar arasında toplanıyor (N06)

**Seviye: B · Şiddet: Orta**

İstemci bu metriği hesaplamıyor; `progressForAchievement` `alpha_wolf_weekly`
için bilinçli olarak `0` döner (`achievement_ledger_engine.dart:546-549`). Yani
"çift sayma" **sunucu tarafındadır**.

```
supabase/migrations/0063_equal_study_sources.sql:588-593
  insert into public.achievement_metric_progress(...)
  select user_id, 'alpha_wolf_weekly', sum(weekly_alpha_wins)::bigint, ...
  from public.group_achievement_weekly where finalized_at is not null
  group by user_id;
```

`group_achievement_weekly` birincil anahtarı `(group_id, iso_week_start, user_id)`
ve `weekly_alpha_wins` satır başına 0/1 ile sınırlı (`0062:17`). Toplama
`group by user_id` olduğu için **hafta değil, (grup × hafta) sayılır**: kullanıcı
iki grupta aynı hafta birinci olursa metrik 2 artar. Sahibin gördüğü "tek hafta,
iki sayı" bu tanımın doğal sonucudur.

**Ürün kararı geldi (2026-08-06):** *"Hangi grup seçili ise ondan sayılsın."*
Yani metrik **gruplar arası toplanmayacak**; gösterilen değer seçili grubun
değeridir.

Bu, tek satırlık bir SQL düzeltmesi değildir çünkü `achievement_metric_progress`
kullanıcı başına **tek satır** tutuyor (`(user_id, achievement_id)` birincil
anahtar) — grup boyutu şemada yok. İki uygulama yolu var, ikisi de gerçek iş:

1. **Projeksiyonu grup kırılımlı yap:** `achievement_metric_progress`'e
   `group_id` boyutu ekle (ya da grup metrikleri için ayrı bir görünüm), okuma
   tarafı seçili grubun satırını çeksin. Doğru olan budur; başarım rozeti
   "hangi grupta" sorusunu cevaplayabilir hale gelir.
2. **Okuma tarafında filtrele:** metrik satırı yerine
   `group_achievement_weekly`'yi doğrudan seçili `group_id` ile sorgula.
   Daha ucuz ama XP/kademe zinciri hâlâ toplam üzerinden ilerlerse iki uç
   ayrışır — `0063`'teki XP döngüsü de aynı kaynağı okumalı.

**Öneri:** (1). `alpha_wolf`, `campfire_hours`, `team_player`, `locomotive` de
aynı tabloyu paylaştığı için düzeltme bu dört metriği birlikte kapsamalı; yoksa
"seçili grup" kuralı yalnız Lider Kurt'ta geçerli olur ve tutarsızlık kalır.

**Doğrulama sorgusu:**

```sql
select group_id, iso_week_start, weekly_alpha_wins, finalized_at
from public.group_achievement_weekly
where user_id = '<user_id>' order by iso_week_start desc limit 10;
```

Aynı `iso_week_start` için iki satır dönüyorsa mevcut davranış (toplama)
doğrulanmış olur.

### T07 — Üye satırında ad tek harfe düşüyor (N04.2)

**Seviye: A · Şiddet: Yüksek (okunabilirlik)**

```
app/lib/features/classroom/widgets/class_detail_screen.dart:903-948
    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        _NudgeButton(...), _MuteNudgeButton(...),
        if (isAdmin ...) IconButton(person_remove), if (isAdmin ...) IconButton(gavel),
    ])
```

`ListTile`, `trailing`'e **istediği kadar genişlik** verir; kalan alanı `title`
alır. Dört `IconButton` × 48dp minimum dokunma hedefi = ~192dp; buna 18 yarıçaplı
avatar ve iç boşluklar eklenince 360-411dp'lik telefonda ada ~40-60dp kalır →
`overflow: ellipsis` adı "B..." yapar. Ekran görüntüsü 2 bunu kanıtlıyor: eylem
simgesi **olmayan** tek satır (yöneticinin kendi satırı, `m.id != currentUserId`
koşulu yüzünden `trailing: null`) adı **tam** gösteriyor.

Bu, WP-487'nin (V57-N11: "ünvan satırı 4 satıra çıkarıyor") **yan etkisidir**:
dikey şişme `maxLines: 1` ile kapatıldı, sorun yataya taşındı.

**Düzeltme yönü.** `ListTile` yerine kendi satırını kur ve ada `Expanded` ver;
eylemleri tek bir "…" taşma menüsüne indir (dürtme dışında hepsi ikincil eylem).
Kabul ölçütü ada **en az 3-4 karakter** garantisi olmalı ve 320dp genişlikte
golden test ile kilitlenmeli.

---

### T08 — Seri rozeti "Bugün" yazısının üstüne biniyor (N04.3)

**Seviye: A · Şiddet: Orta**

```
app/lib/features/classroom/widgets/study_timer_card.dart:298-311
    Positioned(top: 14, left: 14, child: GoalStreakBadge(...)),
    Padding(padding: const EdgeInsets.fromLTRB(16, 48, 16, 20), ...)  // ← sabit 48
```

Rozet `Stack` içinde serbest konumlu; içerik ise **sabit 48 px** üst boşlukla
itiliyor. Rozetin gerçek yüksekliği ise değişken: ikon (20) + dikey padding (2×8)
+ **iki satıra kadar sarabilen** etiket (`goal_streak_flame.dart:86-95`,
`maxLines: 2`) + kapsam rozeti. Uzun etiket ("Henüz seri yok") ve/veya sistem
yazı ölçeği >1 olduğunda rozet 48 px'i aşar ve "Bugün" satırının üstüne biner.

**Sahip kararı (2026-08-06, kesinleşmiş):** rozette **hiç yazı olmayacak** —
yalnız **alev + sayı**. Ne durum metni ("Henüz seri yok"), ne kapsam etiketi
("Kişisel"/"Grup"). Gerekçe sahibin kendi ifadesi: *"grup kısmında grup streak
yazıyor, oradan anlaşılır zaten"* — yani kapsamı **bağlam** (rozetin hangi
ekranda/bölümde durduğu) söyler, rozetin kendisi değil. Bu tek başına çakışmayı
da büyük ölçüde bitirir; rozet tek satır ikon+sayıya iner.

**Düzeltme yönü.**
1. `GoalStreakFlame`'de görünür metin ve `_ScopeBadge` kaldırılsın; ikon + sayı
   kalsın (`goal_streak_flame.dart:84-102`).
2. **Erişilebilirlik, karar bozulmadan korunuyor.** WP-454'ün kuralı "ayrım
   yalnız RENGE dayanmaz" idi (`goal_streak_flame.dart:15-18`). Görünür metin
   kalkıyor ama iki kanal duruyor: (a) her durumun **ayrı ikonu** (dolu alev /
   içi boş alev / pause / gri alev) — renk körü kullanıcı için ayrım burada,
   (b) `Semantics` etiketi (satır 47) aynen kalır, ekran okuyucu hâlâ
   "Kişisel · 3 · bugün tamamlandı" der. Kapsam ayrımı görsel olarak bağlamdan
   okunacağı için `_ScopeBadge` tümüyle silinir; çerçeve biçimi farkı
   (yuvarlak/köşeli) kalabilir ama artık **taşıyıcı** kanal değildir.
3. Sabit `48` üst boşluk (`study_timer_card.dart:307`) yine de kaldırılmalı;
   rozet küçülse bile sistem yazı ölçeği 1.6'da aynı çakışma geri gelir.
   Doğrusu rozeti `Stack` yerine başlık satırının parçası yapmak.

**Not — dördüncü durum.** Metin kalkınca kullanıcı durumları yalnız ikondan
ayırt edecek. Sahibin tarif ettiği üç durumun kodda dört karşılığı var:
`completedToday` (dolu alev), `pendingToday` (**içi boş alev** — dün tamamlandı,
bugün henüz değil), `atRisk` (pause), `expired`/`empty` (gri alev). Dolu ile içi
boş alev ayrımı küçük rozette zayıf kalabilir; tasarım turunda bu iki ikon
belirgin şekilde ayrışmalı.

### T09 — Trend grafiğinde Y ekseni etiketleri çakışıyor (N04.1)

**Seviye: A · Şiddet: Düşük-Orta**

```
app/lib/features/stats/widgets/daily_line_chart.dart:26-28
    final maxY = maxMinutes <= 0 ? 60.0 : maxMinutes * 1.2;   // ← ölçek kırığı
    final yInterval = niceMinuteInterval(maxY);
...:68  if (value <= 0 || value > maxY) return const SizedBox.shrink();
```

`maxY`, veri maksimumunun 1.2 katı — yani seçilen `yInterval`'in **katı değil**.

**Kütüphane kaynağında doğrulandı (fl_chart 1.2.0):** eksen etiketleri
`AxisChartHelper.iterateThroughAxis` ile üretiliyor ve fonksiyon aralık
tıklarına **ek olarak** eksen sınırını da veriyor:

```
fl_chart-1.2.0/lib/src/chart/base/axis_chart/axis_chart_helper.dart:56-58
    if (maxIncluded && !lastPositionOverlapsWithMax) {
      yield max;                       // ← aralık ızgarasında olmayan fazladan etiket
    }
```

`SideTitles.maxIncluded` varsayılanı `true` (`axis_chart_data.dart:204`) ve kod
bunu geçersiz kılmıyor. Ekrandaki seri için: veri maks ≈ 10.4 sa → `maxY` = 12.5
sa (750 dk) → `niceMinuteInterval(750)` = 240 dk → tıklar 4h/8h/**12h**, üstüne
sınır etiketi **12.5h**. İki etiket ~30 dakikalık mesafede, yani ekranda birkaç
piksel arayla çiziliyor → ekran görüntüsü 1'deki iç içe geçmiş üst etiket. Bu
**her veri kümesinde** olur, çünkü `maxY` hiçbir zaman aralığın katı değildir.

**Bir satırlık geçici çare de var:** `SideTitles(maxIncluded: false)`. Kalıcı
doğru çözüm yine `maxY`'yi aralığın üst katına yuvarlamaktır (aşağıda).

**Düzeltme yönü.** Önce aralığı seç, sonra `maxY`'yi o aralığın üst katına
yuvarla: `maxY = (dataMax * 1.15 / interval).ceil() * interval`. Böylece tepe
etiketi tam eksen sınırına oturur, çakışma yapısal olarak imkânsızlaşır.
`daily_bar_chart.dart:50-51` aynı deseni (×1.32) kullanıyor — birlikte düzeltilmeli.

---

### T10 — "Currently studying" kartında satır kırpılması (N04.1)

**Seviye: A · Şiddet: Düşük-Orta**

```
app/lib/features/home/widgets/active_members_card.dart:60-80
    const rowHeight = 42.0;
    const headerHeight = 32 + 24 + 12;
    maxItems = ((availableHeight - headerHeight) / rowHeight).floor().clamp(1, 20);
```

Kaç satırın sığdığı **sabit 42 px** varsayımıyla hesaplanıyor. Gerçek satır
yüksekliği avatar (32) + dikey padding (2×5) = 42'yi ancak yazı ölçeği 1.0 iken
tutar; ölçek büyüdüğünde satır büyür, hesap büyümez → son satır alttan kırpılır
(ekran görüntüsü 1'deki yarım "Minik Kuş" satırı).

**🔴 Asıl tetikleyici bulundu — taçlı avatar 42 px'e sığmıyor.** `CrownedAvatar`
taç varken kutusunu **büyütüyor**:

```
app/lib/core/widgets/crowned_avatar.dart:274-283
    final top = geometry.topExtent(base) + outlineW;   // tacın üste taşan payı
    avatar = SizedBox(width: half * 2, height: top + base + outlineW, ...)
```

Sayı, kartın kullandığı `radius: 16` için birebir hesaplandı: `ring` =
max(2.0, 16×0.075) = **2.0** → `base` = 18. `radius 16 < kCrownCompactRadius (18)`
olduğu için **compact** geometri seçilir (`tipRadius` 1.74, `pearlRadius` 0):
`topExtent` = 18 × 1.74 = **31.3**, `outlineW` = max(0.8, 0.72) = 0.8 →
`height` = 31.3 + 0.8 + 18 + 0.8 = **≈50.9 px**.

Yani taçsız avatar 32 px iken taçlı avatar **51 px**; satır `Padding(vertical: 5)`
ile **≈61 px** eder — kartın bütçesi ise **42**. Bütçe %45 aşılıyor.
Sonuç: (a) `maxItems` fazla satır sığacağını sanır, son satır alttan kırpılır;
(b) her satırın içinde tacın üst payı boşluk gibi görünür ve satırlar aşağı
kaymış izlenimi verir. Sahibin "aşağı kayıyorlar" dediği (V58-N11) budur ve
ekran görüntüsü 1'de **iki üyenin de tacı var**.

**Düzeltme yönü.** Sabit `rowHeight`/`headerHeight` aritmetiği tümüyle kalksın:
gerçek `ListView` (kendi `physics`'i ile) + içeriğe göre yükseklik. Satır sayısı
tahmin edilmeyecekse `maxItems` hesabına da gerek kalmaz. Kabul ölçütü: **taçlı**
üyelerle ve `textScaleFactor 1.3` ile kırpılmış piksel olmamalı — golden test bu
iki koşulu birlikte kurmalı (taçsız golden bu hatayı göremez).

### T11 — İngilizce arayüzde Türkçe rozet: "2 aktif" (N04.1)

**Seviye: A · Şiddet: Orta (mağaza kalitesi)**

```
app/lib/features/home/widgets/active_members_card.dart:121
    child: Text('${active.length} aktif', ...)
```

Gömülü Türkçe metin; `app_en.arb` içinde karşılığı yok, `AppLocalizations`'tan
geçmiyor.

**Kapının deliği doğrulama turunda tam olarak bulundu** (ilk taslaktaki
"interpolasyonu taramıyor" ifadesi eksikti — denetçi tarıyor, iki ayrı kural
birden eliyor):

1. `TURKISH_CHAR_RE = re.compile(r"[ÇĞİÖŞÜçğıöşü]")` (`l10n_audit.py:55`) —
   literal, **Türkçe'ye özgü bir karakter** içermek zorunda. `"aktif"` sırf ASCII
   harflerden oluşuyor → bu kural kördür. Aynı körlük `grup`, `hedef`, `toplam`,
   `seri`, `mola`, `dakika` gibi onlarca sözcük için de geçerlidir.
2. İkinci kural (`ui_prose_violations`) tam da bu boşluğu kapatmak için yazılmış
   ("Türkçe'ye özel karakter içermeyen Türkçe cümleler"), ama `TECHNICAL_RE`
   içindeki `^\$` deseni (`l10n_audit.py:101`, yorumu "tamamı interpolasyon")
   yalnız **başlangıcı** kontrol ediyor. Literal `'${active.length} aktif'`
   `$` ile başladığı için "tamamı interpolasyon" sayılıp muaf tutuluyor.

Yani `'$degisken Türkçe kelime'` biçimindeki **her** metin iki kuralın da altından
geçiyor. Bu tek karakterlik desen hatası, l10n kapısının en büyük kör noktasıdır.

**Düzeltme:** `^\$` yerine literalin **tamamının** tek bir interpolasyon olmasını
arayan desen (`^\$\{?[\w.]+\}?$`). Kapı düzeltildikten sonra kasten kırık bir
girdiyle sınanmalı (bkz. `ci-kapisi-yesil-sanilmaz-dogrulanir` dersi); v55
boyunca aynı kapı kırmızıyken yeşil sanılmıştı.

**Düzeltme yönü.** (1) Anahtarı ekle (`homeAktifSayisi` + `{count}` çoğul formu).
(2) **Kapıyı** düzelt: denetçi `'...$degisken ...'` biçimindeki interpolasyonlu
literalleri de taramalı. Kapıyı kasten kırık bir girdiyle sınamadan yeşil sayma.

---

### T12 — Reboot sonrası iki gün süren yavaş açılış (N01)

**Seviye: C · Şiddet: Yüksek ama tekrarlamıyor**

Belirti kendiliğinden geçti ve elimizde iz kaydı yok. Statik analizden çıkan iki
katkı adayı:

1. **T03'ün abonelik sızıntısı** — kanal sayısı büyüdükçe açılış el sıkışması
   pahalılaşır; süreç yeniden başlayınca sıfırlanır.
2. Reboot sonrası `TimerBootReceiver` + widget güncellemeleri + auth token
   yenilemesinin aynı ana yığılması.

"Neden 2 gün sonra geçti" sorusunun statik koddan cevabı yok; bu ancak açılış izi
(`flutter run --trace-startup` ya da `adb shell am start -W`) ve Supabase kanal
sayacıyla yanıtlanır. **Tavsiye:** bu maddeyi kapatmak için bir açılış bütçesi
telemetrisi (soğuk açılış süresi + açık kanal sayısı) eklemek, tek seferlik
teşhis avından daha değerlidir.

---

### T13 — Bildirim sayacı / ayna senkronunda kalıntı sapma (N09)

**Seviye: C · Şiddet: Orta**

Foreground uzlaşma 5 saniyede bir (`kGlobalTimerForegroundReconcileInterval`,
`study_providers.dart:86`) çalışıyor; kalan sapmanın ölçüsü sahipten "daha az da
olsa var" ifadesiyle geliyor, sayısal değil. T01 ve T05 düzeltilmeden bu maddeyi
ölçmek anlamsız: ikisi de aynı yüzeyin (native SSOT + ayna) davranışını
değiştiriyor. **Önce T01/T05, sonra yeniden ölçüm.**

---

## 2.5 Doğrulama turu (2026-08-06, sahip talebi)

Sahip *"emin misin, son kez kontrol et"* dedi. Bulguların tamamı ikinci kez
sürüldü; aşağıda **ne değişti** ve **ne sertleşti** ayrı ayrı yazılıdır. Bu
bölümün amacı raporu savunmak değil, hangi iddianın hangi kanıta dayandığını
senior'ın tek bakışta görmesidir.

### Değişen iki iddia

| Bulgu | İlk taslakta yazan | Doğrulamada çıkan |
|---|---|---|
| **T01** | "Dart native'den **sonra** yazdığı için değer Long kalır" | **Yanlıştı.** Dart `start()` içinde **önce** yazıyor (satır 1852), widget tazelemesi hemen ardından (1882), native `putInt` ise `startForegroundService` zincirini beklediği için **en son** geliyor. Sonuç aynı, gerekçe daha güçlü: değer widget okuduğu anda **kesin** Long → hata yarışa bağlı değil, başlatmada **beklenen** sonuç. |
| **T11** | "l10n denetçisi interpolasyonlu metni taramıyor" | **Eksikti.** Denetçi tarıyor; iki kural birden eliyor: (1) Türkçe taraması yalnız `ÇĞİÖŞÜçğıöşü` arıyor, `"aktif"` sırf ASCII; (2) `TECHNICAL_RE`'deki `^\$` deseni `$` ile **başlayan** her literali "tamamı interpolasyon" sayıp muaf tutuyor. Delik tek karakterlik bir desen hatası. |

### Sertleşen üç iddia

| Bulgu | Yeni kanıt |
|---|---|
| **T05** | Sunucuda `stop_mirrored_run` RPC'si **yok**; stop dalı (`0101:274-281`) yalnız durum güncelliyor, `study_sessions` insert'i tüm migration'larda tek yerde (`0051`, verified koşu). Origin cihaz da uzak durdurmada `_finish()` çağırıyor — o da "kayıt yapmadan durdurur". Yani süre **iki uçta da** kayıp. |
| **T09** | Varsayım değil, kütüphane kaynağı: `iterateThroughAxis` satır 56-58 eksen sınırı için **fazladan** etiket üretiyor ve `maxIncluded` varsayılanı `true`. Çakışma her veri kümesinde deterministik. |
| **T10** | Taçlı avatar yüksekliği elle hesaplandı: r=16 → **50.9 px** (taçsız 32), satır ≈ **61 px**, kartın bütçesi **42** → %45 aşım. |

### Değişmeyen, ikinci turda da doğrulanan iddialar

- **T02** — `record_goal_completion` çağrısı `app/lib`, `supabase/migrations` ve
  **`supabase/functions` (7 edge function)** içinde yok; yalnız tanım, testler ve
  dokümanlarda geçiyor. Tetikleyici de yok.
- **T03** — `StreamBuilder`'a her `build()`'de **yeni bir stream nesnesi**
  veriliyor; Flutter nesne kimliği değişince yeniden abone olur, bu yüzden döngü
  gerçek.
- **T04** — `.value` (ilk yükleme) ile `asData` (her yenileme) farkı doğrulandı;
  ikisi ayrı belirti üretiyor.
- **T06** — `achievement_metric_progress` birincil anahtarı `(user_id,
  achievement_id)`; şemada grup boyutu **yok**, dolayısıyla "seçili grup" kuralı
  şema değişikliği gerektiriyor.
- **T14** — `MediaQuery.paddingOf(context).top` uygulamanın **hiçbir yerinde**
  okunmuyor; `home_screen.dart`'taki tek `SafeArea` boyut paneline ait ve
  `top: false`.

### Kapanış taraması (aynı tur, sahip "son kez bak" dedi)

**1. Native prefs okumalarının TAMAMI tarandı.** `android/app/src/main/kotlin`
içinde tip belirten her prefs okuması (`getInt`/`getLong`/`getBoolean`/`getFloat`)
listelendi; sonuç **dört okuma, iki kusurlu anahtar**:

| Okuma | Dart'ın yazdığı tip | Durum |
|---|---|---|
| `TimerStateStore.kt:100,103` `getLong(KEY_STARTED_AT_MS)` | `setInt` → Long | ✅ doğru |
| `StudyWidgetProviders.kt:115` `getLong(started_at_ms)` | `setInt` → Long | ✅ doğru |
| `StudyWidgetProviders.kt:122` `getInt(target_seconds)` | `setInt` → **Long** | 💥 T01 |
| `StudyTimerService.kt:205,239` `getInt(KEY_CYCLE)` | `setInt` → **Long** | 💥 T01 |
| `StudyTimerService.kt:476` `getBoolean(timer_panel_expanded)` | *(Dart hiç yazmıyor)* | ⚠️ aşağıya bak |

Yani T01 iki anahtar ve üç çağrı yeriyle **sınırlı**; başka gizli tip uyuşmazlığı
yok. Ters yön (Dart'ın native `putInt` değerini okuması) risk değildir — Dart
tarafı Integer ve Long'u aynı `int` olarak alır.

**2. İki çökme yolunun tetikleyicileri farklı — ikisi de koşullu.**

- `getInt(target_seconds)`: ana ekranda **yerleştirilmiş sayaç widget'ı** gerekir
  (yoksa `appWidgetIds` boş gelir, `forEach` hiç dönmez). Sahibin V57-N06'daki
  kendi ifadesi (*"Android ana ekran widget'ında olmuyor"*) bu ön koşulun
  sağlandığını gösteriyor, ama bu **çıkarım**, ölçüm değil.
- `getInt(KEY_CYCLE)`: yalnız `ACTION_START_BREAK` / `ACTION_END_BREAK` ile
  çalışır ve bu action'ları **yalnız bildirimdeki mola düğmeleri** gönderir
  (`breakActionPending()` / `endBreakActionPending()`). Yani otomatik faz
  geçişinde değil, kullanıcı bildirimden mola düğmesine bastığında patlar.

**3. `timer_panel_expanded` ölü bayrak.** `StudyTimerService.kt:476` bu anahtarı
okuyor ama `app/lib` içinde onu **yazan hiçbir kod yok** — yani v43'te bırakılan
"OEM kaçış valfi" uygulamadan hiç açılıp kapatılamıyor, daima varsayılan `true`.
Sahibin bildirdiği bir belirti değil; T02 ile aynı aileden (bağlanmamış uç) ve
bir sonraki panel şikâyetinde bunu bilmek gerekir.

**4. T04'ün gerçek kapsamı ölçüldü.** Yükleniyor-durumunu-yok-sayan desen tek
yerde değil: `asData?.value` **22**, `.value ?? const …` **49**,
`ref.watch(...).value;` (features altında) **31** kullanım. Hepsi hata değildir —
boş listenin görsel olarak zararsız olduğu yerler var — ama düzeltme bir dosya
işi değil, **denetimli bir tarama** olarak planlanmalıdır.

### Hâlâ kanıtlanmamış olanlar (dürüstlük payı)

- **T01'in cihazdaki teyidi** — mekanizma uçtan uca kodda doğrulandı ve native
  prefs okumalarının tamamı tarandı, ama logcat'te `ClassCastException` satırını
  **görmedim**. Kodda kusur kesin (`getInt` bir `Long` değeri okuyor, bu her
  koşulda hatalıdır ve er geç patlar); belirsiz olan tek şey, sahibin gördüğü
  çökmenin **bu** kusurdan mı geldiği. Ayrım pratikte önemsiz: düzeltme her
  hâlükârda yapılacak, ama "çökme bitti" demeden önce logcat satırı görülmeli.
  🔴 Bu, raporun **tek** çalışma zamanı belirsizliğidir; kalan 13 bulgunun
  hepsi statik olarak kapalıdır.
- **T06'nın çift sayma verisi** — mekanizma (gruplar arası toplama) kodda net,
  ama sahibin gerçekten iki grupta birinci olduğunu **veriyle** görmedim.
- **T12 / T13** — telemetri olmadan kapanmaz; değişmedi.
- **T07** — `ListTile` sıkıştırması standart Flutter davranışı ve ekran görüntüsü
  birebir uyuyor, ama ölçümü cihazda yapılmadı.

---

### T14 — Ana ekran üst güvenli alanı taşımıyor: WP-488 regresyonu (N10)

**Seviye: A · Şiddet: Yüksek · Etki: içerik durum çubuğunun altında kalıyor**

WP-488 (V57-N12, sahip kararı) görüntüleme modunda üst şeridi kaldırdı. Commit
mesajı *"gövde üst güvenli alanı kendisi taşır"* diyor — **taşımıyor**.

```
app/lib/core/navigation/tab_action_bar.dart:12-13
    /// Eylem yoksa `null` döner; çağıran ekran bu durumda gövdeyi
    /// `SafeArea(bottom: false)` ile sarar.        ← yazılı sözleşme
```

Home bunu yapmıyor. Gövdenin tek üst boşluğu şu yardımcıdan geliyor:

```
app/lib/core/widgets/safe_screen_padding.dart:15-18
    final bottomSafe = MediaQuery.paddingOf(context).bottom;
    return EdgeInsets.fromLTRB(horizontal, vertical, horizontal, vertical + bottomSafe);
                                          ^^^^^^^^ sabit 16 — üst inset HİÇ okunmuyor
```

`MediaQuery.paddingOf(context).top` hiçbir yerde kullanılmıyor; `home_screen.dart`
içindeki tek `SafeArea` (satır 926) boyut paneline ait ve zaten `top: false`.
`Scaffold`'un `appBar` yuvası `null` olduğu için durum çubuğu payını kimse
tüketmiyor → ilk kart ekranın tepesinden yalnız **16 px** aşağıda başlıyor,
yani saat/pil/bildirim simgelerinin altına giriyor. Ekran görüntüsü 4 bunu
gösteriyor.

Kart sıralaması sahibin panosunda sayaç kartını en üste koyduğu için, çakışan şey
seri rozeti oluyor; hata rozete değil **ekran kabuğuna** aittir.

**Düzeltme yönü.** İki seçenekten biri, ikisi birden değil (aksi hâlde boşluk iki
kez eklenir):
- `getSafeVerticalPadding`'e `top: vertical + MediaQuery.paddingOf(context).top`
  eklemek — ama bu yardımcı `classroom_screen`, `class_chat_screen` gibi **şeridi
  olan** ekranlarda da kullanılıyor; oralarda AppBar payı zaten tüketildiği için
  çift boşluk oluşur. Bu yüzden **tercih edilmez**.
- ✅ `home_screen.dart`'ta gövdeyi `SafeArea(bottom: false)` ile sarmak — yani
  `tab_action_bar.dart`'ta zaten **yazılı olan** sözleşmeyi uygulamak. Lokal,
  yan etkisiz ve diğer sekmelerin davranışını değiştirmez.

**Ek kontrol.** Aynı sözleşmeyi ihlal eden başka ekran var mı diye
`buildTabActionBar` çağıran her ekranın "eylem yok" dalı taranmalı; WP-488 bu
şeridi kaldıran tek karar değildi.

**Kapı neden kaçırdı?** Golden testler widget'ı `MediaQuery` üst inset'i **0**
olan bir yüzeyde kuruyor; durum çubuğu payı olmayan bir dünyada bu hata
görünmez. Kabul ölçütü olarak `MediaQueryData(padding: EdgeInsets.only(top: 48))`
ile en az bir golden gerekir.

---

## 3. Öncelik sırası

| Sıra | Bulgu | Gerekçe |
|---|---|---|
| 1 | **T01** | Süreç ölümü. Kullanıcı iki sayaç modunu kullanamıyor. Düzeltme küçük ve lokal. |
| 2 | **T05** | Veri **kaybı** (4-5 saatlik koşu hiçbir yere yazılmıyor) + v58'de değişen davranış. |
| 3 | **T02** | Reklam edilen bir özellik tümüyle çalışmıyor; düzeltme sunucu tarafında tek noktada. |
| 4 | **T03** | Pil/ağ maliyeti ve görünür titreme; tek dosyada. |
| 5 | **T04** | Algılanan kalitede en görünür kusur; desen taraması gerektirir. |
| 6 | **T14** | Tek satırlık kabuk düzeltmesi, en görünür kusuru kapatıyor (içerik durum çubuğunun altında). |
| 7 | **T07, T08, T09, T10, T11** | UI kümesi; tek turda golden testleriyle birlikte. T08 ve T10 sahip kararıyla yeniden tanımlandı. |
| 8 | **T06** | Sahip kararı geldi (seçili grup); şema boyutu eklenecek. |
| 9 | **T12, T13** | Telemetri kurulmadan kapatılamaz. |

---

## 4. Bu turun asıl dersi (senior için not)

Dört bulgunun (T01, T02, T03, T04) ortak özelliği şudur: **hiçbiri "yanlış
hesaplanmış" bir mantık hatası değil.** Dördü de *iki katman arasındaki
sözleşmenin hiç test edilmemiş* olmasından geliyor:

- T01: Dart ↔ Android prefs tip sözleşmesi (saf fonksiyon test edildi, sınır
  okuması edilmedi).
- T02: istemci ↔ RPC çağrı sözleşmesi (RPC test edildi, **çağıran** hiç
  aranmadı).
- T03/T04: Riverpod/Flutter yaşam döngüsü sözleşmesi (widget çıktısı test edildi,
  **yeniden kurulum davranışı** edilmedi).

Bu yüzden dört kapı (analyze, flutter test, l10n, Database Gates) tamamen yeşilken
sürüm çıktı. Somut öneri: her katman sınırı için **tek bir çift uçlu test**
(bir uçta üretim yolu, diğer uçta gerçek karşı taraf) — projede bunun örneği
zaten var (`user_task_rpc_contract_wp472_test.dart`) ve işe yaradığı yerde bu
sınıf hatayı yakaladı.

---

## 5. Bu rapor ne değildir

- Cihazda koşum raporu değildir; hiçbir bulgu için logcat/profil alınmadı.
- İş paketi kesimi değildir; WP'ler `progress.md`'de açılacak.
- T06'nın ürün kararı bu raporda verilmemiştir; sahibe sorulacaktır.
