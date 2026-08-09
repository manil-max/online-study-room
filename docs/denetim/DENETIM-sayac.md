# DENETIM — Sayaç motoru + oturum kaydı

**Tarih:** 2026-08-09 · **Kapsam:** kronometre/geri sayım/pomodoro, başlat-durdur yolları, native FGS + kalıcı bildirim, soğuk açılış geri yükleme, oturum kaydı/süre hesabı/gün anahtarı, çevrimdışı kayıt kuyruğu.

**Yöntem:** salt okunur kod denetimi. `progress.md`, `docs/**` ve kod yorumları **kanıt sayılmadı**; her bulgunun kanıtı `dosya:satır`. Bugün (2026-08-09) sayaç alanına dokunan commit'ler (`899abea` WP-598, `0a6dfb9` WP-599, `989638f` WP-608, `f2b513c` WP-595, `17dc780` WP-603) `git log -- <dosya>` ile tek tek kontrol edildi; bugün düzeltilmiş konular rapora alınmadı.

**Özet:** 2 KANAMA · 5 RİSK · 2 TEMİZLİK.

---

## KANAMA-1 — Kaydedilen oturum, süreç ölürse hem sunucuya gitmez hem cache'ten SİLİNİR

**Belirti.** Kullanıcı Durdur'a basar, süre "Bugün" toplamına eklenmiş görünür. Uygulamayı hemen kapatır (ya da Android süreci öldürür). Bir dahaki açılışta o oturum yoktur: ne sunucuda, ne yerelde, ne de bir hata/uyarı olarak.

**Kanıt.**
- `app/lib/data/repositories/offline/offline_first_study_repository.dart:199-202` — `addSessionLocalFirst` önce cache'e yazar, uzak gönderimi `unawaited` bırakır.
- `app/lib/data/repositories/offline/offline_first_study_repository.dart:209-217` — outbox kaydı (`queueStudyMutation`) **yalnız `catch` içinde** yazılır. "Gönderilmeyi bekleyen kayıt" diye kalıcı bir iz, ancak uzak gönderim BAŞARISIZ OLURSA doğar. Gönderim sonuçlanmadan süreç ölürse outbox boştur.
- `app/lib/data/repositories/offline/offline_first_study_repository.dart:452-467` — `_reconcileRemoteSessions` yalnız `remoteRows` + **bekleyen outbox** birleşimini üretir. Outbox'ta olmayan, yalnız cache'te duran oturum bu kümede yoktur.
- `app/lib/data/repositories/offline/offline_first_study_repository.dart:276-294` — bu küme `saveUserSessions(userId, reconciled)` ile cache'e yazılır; `app/lib/data/repositories/offline/offline_cache_store.dart:58-68` bu çağrının listeyi birleştirmediğini, tamamını değiştirdiğini gösterir.

Zincir: cache'te var → outbox'ta yok → ilk uzak snapshot geldiğinde cache'ten de silinir. Silme sessizdir; `deadLetter`/telemetri yolu da çalışmaz (o yollar yalnız outbox'taki kayıtlar içindir).

**Etki.** Sessiz veri kaybı. Pencere `_writeSessionLocally` bittikten sonra `_dispatchAddSessionRemote` sonuçlanana kadardır; kötü ağda üst sınır `_remoteDispatchTimeout` = 12 sn (`:67`), üstelik `flushPending()` de aynı `Future` içinde beklenir. "Durdur'a bas, uygulamayı kapat" en sık kullanıcı davranışıdır. Açılışta `emitCached()` (`:255-261`) önce oturumu gösterip snapshot'ın silmesi, "bugünkü sürem düştü" şikâyetinin bilinen imzasıdır.

**Öncelik:** KANAMA.

---

## KANAMA-2 — Kalıcı bildirim koşunun ilk saniyesinde donuyor; pomodoro fazlarını hiç görmüyor

**Belirti.** Pomodoro'da mola başlar; bildirim hâlâ "Odaklanıyorsun" der, süreyi ilk çalışma başlangıcından saymayı sürdürür ve düğmesi "Durdur"da kalır. Uygulamadaki sayaçla bildirimdeki sayaç birbirini tutmaz. Geri sayımda uygulama geriye, bildirim ileriye sayar.

**Kanıt.**
- Native bildirim yalnız `handleStart`/`handleStop` komutlarında kurulur: `app/android/app/src/main/kotlin/com/manilmax/online_study_room/timer/StudyTimerService.kt:56-100`. Faz/etiket kararı prefs'ten o anda okunur (`:347-350`), sonradan tazelenmez.
- Dart'ta native servise komut gönderen tek yüzey `TimerForegroundService.start/stop`'tur; `lib/` içindeki TÜM çağrı yerleri: `app/lib/data/providers/study_providers.dart:1027, 1158, 1178, 1372, 1726, 2277`. **Faz geçişinde çağrı yok.**
- Faz geçişi gövdesi: `app/lib/data/providers/study_providers.dart:2561-2588` — `state.copyWith(phase: …)`, `_publishPresence`, `_persistActiveTimer`, `_startTick`, `_syncTimerSurfaces`. Native start/stop yok.
- `_syncTimerSurfaces`'in bildirim kolu hiçbir şey göstermiyor, yalnız ESKİ bildirimi iptal ediyor: `app/lib/data/providers/study_providers.dart:2977-2985`.
- Method channel'da faz güncelleme metodu da yok: `app/android/app/src/main/kotlin/com/manilmax/online_study_room/MainActivity.kt:59-105` (yalnız `startTimer` / `stopTimer` / `discardProjection`).

**İkincil sonuç — "Çalışmaya dön" düğmesi ulaşılamaz.** `endBreakActionPending()` yalnız `isBreak == true` iken bildirime konur (`StudyTimerService.kt:384`, `:437`); `isBreak` prefs'teki faz `rest` iken doğrudur; bildirim faz `rest` olduğunda hiç yeniden kurulmadığı için o dal üretimde hiç çalışmaz. `ACTION_END_BREAK` (`:84`, `:168-193`) pratikte ölü yoldur.

**Ölçmeyen kapı (aynı bulgunun ikinci yüzü).** `app/test/core/verified_timer_bridge_contract_test.dart:202-204` bu yolun canlı olduğunu iddia ediyor:

```
// ACTION_END_BREAK OLU DEGIL: bildirimdeki 'Calismaya don' dugmesi.
expect(service, contains('ACTION_END_BREAK'));
expect(service, contains('endBreakActionPending()'));
```

İddia `.kt` dosyasında **metin arıyor**; düğmenin kullanıcıya çıkıp çıkmadığını ölçmüyor. Metin var, düğme yok.

**Etki.** Uygulama kapalıyken sayacın tek yüzeyi bildirimdir. Pomodoro kullanıcısı molada olduğunu bildirimden anlayamıyor, molayı bildirimden bitiremiyor ve gördüğü süre yanlış. Kaydedilen süre doğru kalıyor — kayıt `startedAtMs` prefs'inden okunuyor (`StudyTimerService.kt:216-232`) — yani hata görüntüde, veride değil.

**Öncelik:** KANAMA.

---

## RİSK-1 — Tam ekran odakta "Bugün" gece yarısını aşan koşuda şişiyor (WP-561 düzeltmesi bu yüzeye uygulanmamış)

**Belirti.** 23:00'da başlayan koşuda saat 01:30'da kart "Bugün 1 sa 30 dk" derken tam ekran odak ekranı "Bugün 2 sa 30 dk" diyor; Durdur'da odak ekranının sayısı çöküyor.

**Kanıt.**
- Kart doğru çağırıyor: `app/lib/features/classroom/widgets/study_timer_card.dart:228-241` — `liveStartedAt: timer.startedAt, nowInstant: now` verilmiş.
- Odak ekranı vermiyor: `app/lib/features/classroom/widgets/focus_timer_screen.dart:170-177` — `liveStartedAt` ve `nowInstant` yok.
- Kırpma tam bu iki argümana bağlı: `app/lib/core/stats/study_stats.dart:123-132` (`if (live > 0 && liveStartedAt != null && nowInstant != null)`).

**Ölçmeyen kapı.** WP-561 testleri yalnız saf fonksiyonu ölçüyor (`app/test/core/study_stats_test.dart:96-167`); dahası `:148`'deki "liveStartedAt verilmezse eski (kırpmasız) davranış korunur" testi, argümanı vermeyen çağıranın davranışını **sözleşmeye bağlıyor**. Yüzeylerin argümanı geçtiğini doğrulayan hiçbir iddia yok (`grep -rl resolveTodayDisplayTotal app/test` → yalnız `study_stats_test.dart` ve `timer_background_reconcile_test.dart`).

**Etki.** Gece çalışan kullanıcıya yanlış toplam ve yanlış hedef halkası, Durdur'da düşüş. Odak modu tam olarak uzun/gece koşularının ekranı.

**Öncelik:** RİSK.

---

## RİSK-2 — Tam ekran odakta ayna koşusunu durdurma: onay da yok, hata bildirimi de yok (çıkmaz sokak)

**Belirti.** Başka cihazda başlamış (ayna) koşu tam ekran odakta görünürken Durdur'a basılır. Ağ yoksa ya da revision uyuşmazsa hiçbir şey olmaz: mesaj yok, buton aynı, sayaç akmaya devam eder. Ayrıca "bu sayaç başka cihazda çalışıyor" onayı hiç sorulmaz.

**Kanıt.**
- Odak ekranı düğmesi ham tear-off: `app/lib/features/classroom/widgets/focus_timer_screen.dart:267` → `onPressed: timer.isRunning ? notifier.stop : notifier.start`.
- `stop()` ayna koşusunda doğrudan devrediyor: `app/lib/data/providers/study_providers.dart:2345`.
- `stopMirroredRun()` iki ayrı yoldan **fırlatıyor** ve `finally` yalnız `isStopping`'i geri alıyor: `app/lib/data/providers/study_providers.dart:2469-2496` (kimlik yoksa `StateError` `:2477`; sunucu reddi/ağ kopması `coordinator.stopMirroredRun`'dan). `VoidCallback` bağlamında bu hata yakalanmıyor.
- Karşı örnek — kart bunu doğru yapıyor: `app/lib/features/classroom/widgets/study_timer_card.dart:113-152` (önce onay diyaloğu, sonra `try/catch` + `classroomStopTimerMirrorFailed` şeridi).

**Etki.** Çıkmaz sokak: kullanıcıya ne olduğu söylenmiyor, çıkış yolu verilmiyor. Aynı kural iki yüzeyde ayrık yaşıyor (WP-560 dersinin tekrarı).

**Öncelik:** RİSK.

---

## RİSK-3 — Sayaç kendi kendine bittiğinde de "Az önce durdurdun" penceresi açılıyor

**Belirti.** 25 dakikalık geri sayım kendiliğinden biter, "Bitti" uyarısı çıkar. Kullanıcı hemen Başlat'a basar; sayaç başlamaz ve ekranda **"Az önce durdurdun; sayaç yeniden başlatılmadı"** yazar. Kullanıcı durdurmamıştır.

**Kanıt.**
- Pencere `_finish()` içinde koşulsuz açılıyor: `app/lib/data/providers/study_providers.dart:2678` (`_lastRunEndedAt = ref.read(studyTimerClockProvider)();`).
- `_finish()` doğal bitişte de çağrılıyor: `app/lib/data/providers/study_providers.dart:2554-2560` (`if (t.finished) { _finish(lastEvent: t.event, …) }`), yani `countdownDone` / `allDone` de 10 sn'lik pencereyi açıyor.
- Başlat bu pencereye takılıyor: `:2083-2087` → `_acceptStartAfterStop` (`:2164-2192`).
- Pencereyi kapatan tek şey ayar değişikliği: `_clearRestartWindow` tanımı `:2016-2019`, çağrıları yalnız `setMode` `:2023`, `setCountdownMinutes` `:2031`, `setPomodoro` `:2040`. Doğal bitiş için karşılığı yok.
- Metin: `app/lib/l10n/app_tr.arb:2029` — "Az önce durdurdun; …".

**Etki.** Kullanıcıya yanlış bir sebep söyleniyor ve meşru "bir tur daha" akışı iki dokunuşa çıkıyor. WP-608 aynı sorunun ayar-değiştirme kolunu kapatmış; bu kol açık kalmış. WP-598 testlerinde doğal bitiş vakası yok (`app/test/data/timer_accidental_restart_wp598_test.dart` — tüm senaryolar `notifier.stop()` ile kuruluyor).

**Öncelik:** RİSK.

---

## RİSK-4 — Saat Merkezi geri sayımı, geç fark edildiğinde YANLIŞ GÜNE oturum yazıyor

**Belirti.** Saat Merkezi'nde 40 dakikalık geri sayım 23:50'de biter, kullanıcı uygulamayı ertesi sabah 09:00'da açar. 40 dakika bugüne (09:00 civarına) yazılır; dünkü hedef/seri o süreyi hiç görmez.

**Kanıt.**
- Soğuk açılışta kredi: `app/lib/data/providers/alarm_providers.dart:210-219` — kalıcı durum `running`, hesaplanan durum `done` ise `_creditTimerStudy(inst, fullDuration: true)`.
- Kredi gerçek bitiş anını taşımıyor: `app/lib/data/providers/alarm_providers.dart:427-429` — `recordDuration(durationSeconds: seconds)`; `end` argümanı geçilmiyor.
- Varsayılan "şimdi": `app/lib/core/time_engine/clock_study_recorder.dart:30-32` — `final endAt = end ?? DateTime.now(); final startAt = endAt.subtract(...)`.
- Gerçek bitiş elde var: `app/lib/data/models/timer_preset.dart:132` (`endsAtEpochMs`).
- Gün anahtarı başlangıç anından türetiliyor: `app/lib/core/stats/study_stats.dart:10` + `dailyTotals` `:158-165` — yanlış `start` doğrudan yanlış güne yazılıyor.

**Ek (aynı sınıf, TEMİZLİK):** `ClockStudyRecorder.recordRange` (`app/lib/core/time_engine/clock_study_recorder.dart:49-58`) ve `recordDuration`'ın `end` parametresi `lib/` içinde **hiç çağrılmıyor** (`grep -rn recordRange app/lib app/test` → yalnız tanım satırı). Doğru bitişi taşıyacak API yazılmış, kullanılmamış.

**Etki.** Yanlış gün → yanlış günlük toplam, yanlış hedef tutturma, yanlış seri. Süre miktarı doğru, konumu yanlış.

**Öncelik:** RİSK.

---

## RİSK-5 (gizli; KANAMA-2 düzeltilirse patlar) — "Çalışmaya dön" pomodoro döngü sayacını ilerletmiyor

**Belirti.** (Bugün ulaşılamaz olduğu için sahada görünmüyor.) Bildirimden mola bitirilirse pomodoro döngü numarası sabit kalır; her manuel mola atlamada bir döngü kaybolur, her seferinde atlanırsa pomodoro hiç bitmez.

**Kanıt.**
- Native mola bitirme, döngüyü prefs'ten **aynen** okuyup yeniden yazıyor: `app/android/app/src/main/kotlin/com/manilmax/online_study_room/timer/StudyTimerService.kt:180-192` (`cycle = TimerStateStore.readIntCompat(p, KEY_CYCLE, 1)`).
- Ürünün kuralı `rest → work` geçişinde döngüyü artırmak: `app/lib/data/providers/study_providers.dart:354-361` (`nextCycle: cycle + 1`).
- Dart, native'den benimserken döngüyü sorgusuz alıyor: `app/lib/data/providers/study_providers.dart:1762-1765`, `:1787-1800`.

**Öncelik:** RİSK (bugün etkisiz; KANAMA-2 ile birlikte düşünülmeli).

---

## TEMİZLİK-1 — Dış komut kuyruğunun (`timer_external_command`) hiçbir üreticisi kalmamış

**Belirti.** `_processPendingExternalCommand` ve ona bağlı tüm sözleşme (sıra numarası, `pending.at`, kaza korkuluğunun `guardAccidentalRestart: false` istisnası) üretimde hiç tetiklenmiyor.

**Kanıt.** Anahtarı yazan iki yol da ölü:
- `widgetBackgroundCallback` (`app/lib/features/android_widgets/android_widget_service.dart:11-19`) `home_widget` URI tıklamasını bekliyor ve `app/lib/main.dart:100`'de kayıtlı; ama sayaç widget'ının düğmesi doğrudan native broadcast'e bağlanıyor: `app/android/app/src/main/kotlin/com/manilmax/online_study_room/widgets/StudyWidgetProviders.kt:199-210` (`Intent(context, TimerActionReceiver::class.java)`), yani URI callback'i hiç çağrılmıyor.
- `timerNotificationBackgroundHandler` (`app/lib/core/notifications/timer_notification_service.dart:66-88`) `flutter_local_notifications` aksiyonuna bağlı; WP-563'ten beri Dart hiç bildirim GÖSTERMİYOR (`app/lib/core/notifications/timer_notification_service.dart:19-35`, `app/lib/data/providers/study_providers.dart:2977-2985`), dolayısıyla aksiyon da doğmuyor.
- Kotlin tarafında bu anahtarı yazan kod yok (`grep -rn timer_external_command app/android` → sıfır sonuç).

**Not.** `app/lib/data/providers/study_providers.dart:1893-1897`'daki "🔴 Tanı bulgusu (V56-S02): `pending.at` bugün HİÇBİR üretici tarafından yazılmıyor" yorumu doğru ama eksik: yalnız `at` değil, **komutun tamamı** üretilmiyor. Eski kurulumlardan prefs'te kalmış bir kayıt hâlâ soğuk açılışta yaşsız uygulanabilir (`:1912-1930`).

**Öncelik:** TEMİZLİK.

---

## TEMİZLİK-2 — Bildirimden Başlat, kullanıcının modunu ve dersini sessizce düşürüyor

**Belirti.** Boştaki bildirimin "Başlat"ına basıldığında sayaç her zaman **kronometre** ve **dersiz** başlıyor; kullanıcının seçtiği geri sayım/pomodoro ayarı ve ders yok sayılıyor, hiçbir yerde söylenmiyor.

**Kanıt.**
- `startActionPending()` → `actionPending()` intent'e yalnız `EXTRA_START_ORIGIN` koyuyor: `app/android/app/src/main/kotlin/com/manilmax/online_study_room/timer/StudyTimerService.kt:468`, `:475-484`.
- Eksik extra'lar varsayılana düşüyor: `:58-66` (`mode = "stopwatch"`, `phase = "work"`, `cycle = 1`, `targetSeconds = 0 → null`, `subjectId = ""`).
- Widget'ın toggle'ı da aynı: `:85-99`.
- Uygulama kapalıyken durdurulursa oturum bu boş dersle kuyruğa yazılıyor: `:226-231` (`subject = p.getString(KEY_SUBJECT, "")`).
- Dart bu koşuyu benimserken **modu** native'den alıyor: `app/lib/data/providers/study_providers.dart:1771-1775`, `:1787-1800` (`mode: fgTimerMode`), yani ekrandaki mod da sessizce kronometreye dönüyor.

**Etki.** Kullanıcı dokunuşu yok sayılmıyor ama niyeti yok sayılıyor ve bu söylenmiyor. Ürün kararı olabilir; kararın kendisi kodda yazılı değil, varsayılanların yan etkisi.

**Öncelik:** TEMİZLİK.

---

## Kontrol ettim, SAĞLAM çıktı

Negatif sonuç da bilgidir; aşağıdakiler kod düzeyinde doğrulandı, bulgu ÇIKMADI.

1. **Dart ↔ native `setInt`/`getInt` tip sözleşmesi.** Native tüm sayısal sayaç anahtarlarını `putLong` ile yazıyor (`TimerStateStore.kt:139-155`), okurken iki yönlü dayanıklı yardımcı kullanıyor (`readIntCompat`, `:120-125`); `KEY_TARGET_SECONDS`'ı okuyan tek yer de onu kullanıyor (`StudyWidgetProviders.kt:82-86`). Kotlin kaynağında sayaç prefs'ine ham `getInt` çağrısı yok (`grep -rn getInt app/android/.../kotlin` → yalnız `getIntExtra` ve `Bundle.getInt`). v58 çökmesinin deseni geri gelmemiş.
2. **`run_id`/`revision` string tutuluyor** (`TimerStateStore.kt:72-73`; okuma `StudyTimerService.kt:255-257` `toLongOrNull()`), aynı tuzağın ikinci kolu kapalı.
3. **İstanbul gün anahtarı tek kaynak.** `dayOf` → `istanbulDay` (`app/lib/core/stats/study_stats.dart:10`); `_recordSession`, settling ve `todayRecordedSecondsProvider` aynı fonksiyonu kullanıyor. Sayaç yolunda cihaz yerel takvimine dayanan ayrık bir gün hesabı bulunmadı.
4. **`stop()` reentrancy.** `_stopInFlight` alanı `app/lib/data/providers/study_providers.dart:616`; `stop()` `:2346`/`:2462`, `stopMirroredRun()` `:2472`/`:2486`. Aynı aralığın iki kez kaydı bu yoldan mümkün değil.
5. **Geriye giden saat.** Monotonik koşu saati (`:660`, `_syncRunClock` `:728-766`, `_monotonicElapsedSeconds` `:767-770`) ve `stop()` içindeki kurtarma (`:2379-2397`) `end <= startedAt` durumunda oturumu düşürmüyor, bağımsız ölçüden yazıyor.
6. **Bekleyen aralık kuyruğu kısmi silme.** `_dropProcessedPendingEntries` kuyruğu TAZE okuyup yalnız işlenen id'leri düşürüyor (`:1843-1873`); native her kayda UUID yazıyor (`TimerStateStore.kt:187-215`). "Toptan sil" regresyonu geri gelmemiş; `study_sessions` upsert'i de id üzerinden idempotent (`app/lib/data/repositories/supabase/supabase_study_repository.dart:151-157`).
7. **Boş verified token zehiri.** `_normalizeRunToken` (`:1203-1204`) hem soğuk açılışta (`:983-984`) hem reconcile'da (`:1767-1770`) uygulanıyor.
8. **Soğuk açılışta ayna diriltilmiyor.** `restoringMirror` dalı koşuyu `isRunning: false` ile kuruyor ve yerel izi düşürüyor (`:960-1040`); sunucuya stop göndermiyor.
9. **FGS yaşam döngüsü.** `START_NOT_STICKY` (`StudyTimerService.kt:115`) + her komut yolunda `startForegroundCompat` (`:156`, `:199`, `:282`, `:294`), API'ye göre doğru servis tipi (`:321-337`). beta-v12 / WP-103 çökme desenleri kodda yok.
10. **V2 durdurma zarfı `recordInterval`'dan bağımsız** (`StudyTimerService.kt:252-262`) — WP-373'ün kök nedeni gerçekten kapatılmış; ayna rolü prefs'te açık tutuluyor (`:144`, `TimerStateStore.kt:48-62`) ve ayna cihaz uydurma aralık yazmıyor (`StudyTimerService.kt:213-232`).
11. **Geri sayım/pomodoro aşımı.** `_onTick` hedefi aşan tetiklemede bile `target` kadar kaydediyor (`:2502-2512`); uygulama uzun süre kapalı kalıp sonra açılsa da fazla süre yazılmıyor.
12. **WP-595 uyarısı gerçekten çiziliyor.** Saf kural (`app/lib/core/time_engine/implausible_run_guard.dart:47-58`) iki yüzeye de bağlı (`study_timer_card.dart:412`, `focus_timer_screen.dart:288`, `:316`) ve her iki yüzeyin saniyelik ticker'ı var (`study_timer_card.dart:57-61`, `focus_timer_screen.dart:128-131`) — "yazıldı ama çizilmiyor" değil.
13. **WP-598 testleri iki yönlü.** Pencere içi/dışı, onayın taşınmaması ve `guardAccidentalRestart: false` istisnası ayrı ayrı ölçülmüş (`app/test/data/timer_accidental_restart_wp598_test.dart:164-322`); zaman enjekte edilmiş. Tek boşluk RİSK-3'te yazıldı.

---

## Emin olmadıklarım (açıkça yazıyorum)

- **KANAMA-1'in saha sıklığı.** Kod yolu kesin, ama pencerenin gerçek cihazda ne sıklıkla yakalandığını ölçmedim (denetim salt okunur; test/telemetri koşturulmadı).
- **RİSK-5'in "hiç bitmez" sonucu**, KANAMA-2 düzeltilip mola bildirimi gerçekten çıktığı varsayımına dayanıyor. Bugünkü kodda ulaşılamaz olduğu için sahada gözlenemez.
- `stop()` içinde `_reconcileBackgroundTimer()` sırasında **başka** bir native koşu benimsenirse (`state.startedAt != startedAt`, `:2448`) `finally { _finish(); }` yeni koşuyu kaydetmeden kapatıyor gibi görünüyor (`:2455-2461`). Yarışı kurgulayamadığım için bulgu olarak yazmadım; yalnız not.
