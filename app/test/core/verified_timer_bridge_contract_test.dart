import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/providers/study_providers.dart';

void main() {
  test('verified timer state requires both server run id and token', () {
    const pending = StudyTimerState(
      isRunning: true,
      liveRunId: 'run-1',
      verification: TimerVerification.pending,
    );
    final verified = pending.copyWith(
      liveRunToken: 'token-1',
      verification: TimerVerification.verified,
    );

    expect(pending.isVerifiedRun, isFalse);
    expect(verified.isVerifiedRun, isTrue);
    expect(verified.copyWith(clearLiveRun: true).isVerifiedRun, isFalse);
  });

  test('Dart bridge carries only scoped run identity, never auth tokens', () {
    final bridge = File(
      'lib/core/background/timer_foreground_service.dart',
    ).readAsStringSync();
    expect(bridge, contains("'liveRunId': liveRunId"));
    expect(bridge, contains("'liveRunToken': liveRunToken"));
    expect(bridge, isNot(contains('accessToken')));
    expect(bridge, isNot(contains('refreshToken')));
  });

  test('native outbox preserves verified pause/resume/finalize ordering', () {
    final store = File(
      'android/app/src/main/kotlin/com/manilmax/online_study_room/timer/'
      'TimerStateStore.kt',
    ).readAsStringSync();
    final service = File(
      'android/app/src/main/kotlin/com/manilmax/online_study_room/timer/'
      'StudyTimerService.kt',
    ).readAsStringSync();

    expect(store, contains('appendPendingVerifiedCommand'));
    expect(store, contains('.put("runToken", runToken)'));
    // WP-558: `pause` zarfinin native URETICISI yoktu — tek yazan yer
    // `handleStartBreak`ti ve o yol ulasilamazdi (`breakActionPending()`
    // hicbir yerden cagrilmiyordu). Olu yol silindi; Dart tarafi kuyrugu
    // hala `case 'pause'` ile TUKETIR, native uretici geri gelirse buraya
    // da geri gelmeli.
    expect(service, isNot(contains('"pause"')));
    expect(service, contains('p, "resume", liveRunToken, startOrigin'));
    expect(service, contains('p, "finalize", liveRunToken, startOrigin'));
    expect(service, contains('START_NOT_STICKY'));
  });

  test('saf-native fallback originleri ayrı ve unverified kalır', () {
    final service = File(
      'android/app/src/main/kotlin/com/manilmax/online_study_room/timer/'
      'StudyTimerService.kt',
    ).readAsStringSync();
    final provider = File(
      'lib/data/providers/study_providers.dart',
    ).readAsStringSync();

    expect(service, contains('startOrigin = "native_widget"'));
    expect(service, contains('"native_notification"'));
    expect(provider, contains('LiveRolloutOutcome.unverifiedFallback'));
    expect(provider, contains('TimerVerification.statisticsOnly'));
  });

  test('Android manifest FGS sözleşmesi değiştirilmeden uyumlu kalır', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    // WP-103: API 29–33 DATA_SYNC, API 34+ SPECIAL_USE kullanır; bildirilen tip
    // ikisinin üst kümesi olmalı, yalnız `specialUse` iken ≤13'te
    // IllegalArgumentException/RemoteServiceException ile çöker.
    expect(
      manifest,
      contains('android:foregroundServiceType="dataSync|specialUse"'),
    );

    // 🔴 WP-546: burada eskiden ayrıca `foregroundServiceType="dataSync"`
    // aranıyordu. O dizeyi sağlayan tek satır, HİÇ KULLANILMAYAN
    // `flutter_foreground_task` eklentisinin elle bildirdiğimiz servisiydi
    // (`com.pravera...ForegroundService`) — yani iddia bizim sözleşmemizi
    // değil, ölü bir eklentiyi ölçüyordu. Eklenti düşürülünce ortaya çıktı.
    //
    // Yerine gerçek sözleşme: uygulamanın **tek** foreground service'i vardır.
    // İkinci bir FGS, Play'in FGS beyanında açıklanamayan bir yüzey demektir.
    final declarations = RegExp(
      r'android:foregroundServiceType="[^"]*"',
    ).allMatches(manifest).map((m) => m.group(0)).toList();
    expect(
      declarations,
      ['android:foregroundServiceType="dataSync|specialUse"'],
      reason:
          'Manifestte birden fazla foreground service tipi bildirildi: '
          '$declarations. Play FGS beyani tek servisi anlatiyor.',
    );
  });

  // 🔴 WP-753 — KARAR İPTALİ, kapı yön değiştirdi.
  //
  // Bu test eskiden Live Update kodunun YAZILMASINI yasaklıyordu:
  //   :115  expect(manifest, isNot(contains('POST_PROMOTED_NOTIFICATIONS')));
  //   :140  expect(service, isNot(contains('.setRequestPromotedOngoing(true)')));
  //   :141  expect(service, isNot(contains('hasPromotableCharacteristics')));
  //
  // Üçünü de `3bdf8bb8` (2026-07-22 23:50) yazdı — yani terfi denemesini
  // (`c6110404`, aynı gün 19:52) geri alan commit'in KENDİSİ. Deneme cihazda
  // hiç ölçülmeden 3 saat 58 dakika sonra silindi ve silinme bir kapıya
  // çevrildi. O günden sonra doğru yazılmış bir uygulama bile kırmızı düşerdi;
  // `docs/analiz/WP-751-dinamik-panel-kok-neden.md` bunu K2 kök nedeni olarak
  // ölçtü. (Belge bu satırları WP-558/`29b37d7c`'ye atfediyor; `git log -S`
  // düzeltiyor — WP-558 onlara dokunmadı, yalnız komşu iddiaları temizledi.)
  //
  // İddia silinmedi, TERSİNE çevrildi: aşağısı artık "terfi isteniyor ve
  // istendiği yolda özel görünüm yok" sözleşmesini ölçer.
  test('running timer follows the Android Live Update contract', () {
    final service = File(
      'android/app/src/main/kotlin/com/manilmax/online_study_room/timer/'
      'StudyTimerService.kt',
    ).readAsStringSync();
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();

    // Compat yolu şart: minSdk 24, ham platform API'sine inilmez.
    expect(gradle, contains('androidx.core:core-ktx:1.18.0'));

    // Resmî şart 5: terfi izni manifestte bildirilmeli.
    expect(manifest, contains('android.permission.POST_PROMOTED_NOTIFICATIONS'));

    // Resmî şart 6: terfi açıkça istenmeli.
    expect(
      service,
      contains('.setRequestPromotedOngoing(plan.requestPromotedOngoing)'),
    );

    // 🔴 Resmî şart 2 (ANA BLOKAJ): terfi istenen bildirim `customContentView`
    // TAŞIYAMAZ. Karşılıklı dışlama kodda tek satırda yazılı olmalı ki bir
    // sonraki tur ikisini yeniden aynı bildirime yüklemeye çalışmasın.
    expect(
      service,
      contains('get() = !usesCustomView'),
      reason:
          'Terfi ile ozel gorunum birbirini disliyor; bu kural kodda tek '
          'yerde yazili olmali (WP-751 K1).',
    );

    // Resmî şart 3: `contentTitle` dolu olmalı — eskiden `setContentTitle("")`.
    expect(service, contains('.setContentTitle(getString(plan.titleRes))'));

    // Resmî şart 1: stil Standard veya ProgressStyle.
    expect(service, contains('NotificationCompat.ProgressStyle()'));
    expect(service, contains('TimerNotificationStyle.STANDARD'));

    // Çip metni: açık uçlu kronometrede `when` geçmişte kalır, çip süreyi
    // çizemez → kısa kritik metin şart.
    expect(service, contains('.setShortCriticalText('));

    // Durum çubuğu ikonu monokrom vektör; renkli launcher ikonu değil.
    expect(service, contains('R.drawable.ic_stat_focus_timer'));
    expect(
      service,
      isNot(contains('setSmallIcon(R.mipmap.ic_launcher)')),
      reason:
          'Durum cubugu/cip ikonu monokrom vektor olmali; adaptif launcher '
          'ikonu yanlis turdur.',
    );

    // Geri dönüş valfi: v43 zengin panel hâlâ derlenir ve `true` yazılırsa
    // koşar; ama artık varsayılan DEĞİL (eskiden default true idi ve anahtarı
    // yazan kod olmadığı için standart dal ulaşılamazdı).
    expect(
      service,
      contains('RemoteViews(packageName, R.layout.timer_notification)'),
    );
    expect(service, contains('.setCustomContentView(custom)'));
    expect(service, contains('.setCustomBigContentView(custom)'));
    expect(service, contains('prefs.getBoolean(KEY_PANEL_EXPANDED, false)'));
    expect(service, contains('if (plan.usesCustomView) {'));
    expect(
      service,
      contains(
        'addAction(0, getString(R.string.action_start), '
        'startActionPending())',
      ),
    );
    expect(
      service,
      contains('views.setChronometer(\n            R.id.notif_timer_elapsed,\n            base,\n            null,\n            true,'),
    );
    expect(
      File(
        'android/app/src/main/res/layout/timer_notification.xml',
      ).readAsStringSync(),
      allOf(contains('notif_timer_elapsed'), contains('notif_timer_action')),
    );
  });

  // WP-753: geri dönüş paneli okunabilir kalmalı. WP-205 (1d9db60d) bunu bir
  // kez düzeltmiş, WP-206 (5792d759) 26 dakika sonra geri almıştı; bugün geri
  // alınmış hâl canlıydı. Ham beyaz literal, açık temalı bildirim gölgesinde
  // beyaz üstüne beyaz demektir.
  test('fallback timer panel takes its colors from the theme, not literals', () {
    final layout = File(
      'android/app/src/main/res/layout/timer_notification.xml',
    ).readAsStringSync();
    final pill = File(
      'android/app/src/main/res/drawable/timer_pill_bg.xml',
    ).readAsStringSync();

    expect(
      layout,
      contains('@style/TextAppearance.Compat.Notification.Title'),
      reason: 'Kronometre rengi sistem bildirim TextAppearance\'indan gelmeli.',
    );
    expect(layout, contains('?android:attr/textColorPrimary'));
    expect(pill, contains('?android:attr/colorControlHighlight'));

    // Renk NİTELİĞİ ham hex taşıyamaz. (Yorum metni tarihi anlatmak için
    // eski literalleri anabilir; ölçülen şey gerçekten çizilen değerdir.)
    final hardCodedColor = RegExp(r'android:(textColor|color)="#');
    for (final entry in {'timer_notification.xml': layout, 'timer_pill_bg.xml': pill}.entries) {
      expect(
        hardCodedColor.hasMatch(entry.value),
        isFalse,
        reason:
            '${entry.key} ham renk literali tasiyor: acik temada '
            'gorunmezlik hatasi geri gelir (WP-205 -> WP-206 sarkaci).',
      );
    }
  });

  test('fixture records the live update main path and the v43 fallback', () {
    final fixture = File(
      'test/fixtures/timer_notification_v43_contract.json',
    ).readAsStringSync();
    final service = File(
      'android/app/src/main/kotlin/com/manilmax/online_study_room/timer/'
      'StudyTimerService.kt',
    ).readAsStringSync();

    // WP-753: iki yolun rolleri YER DEĞİŞTİRDİ. `"promotedNowBar":
    // "not_requested"` satırını `a2884611` (WP-272) yazmış ve kararı
    // fixture'a çakmıştı; terfi artık isteniyor.
    expect(fixture, contains('"defaultPresentation": "live_update"'));
    expect(fixture, contains('"fallbackPresentation": "v43_custom_panel"'));
    expect(fixture, contains('"promotedOngoing": "requested"'));
    expect(fixture, contains('"hourBoundaryFormat"'));
    expect(service, isNot(contains('"00:%s"')));
    expect(service, isNot(contains('chronometerFormatHandler')));
    expect(service, contains('.setUsesChronometer(true)'));
    // Geri sayımda `when` GELECEKTEDİR; çip canlı sayıyı oradan çizer.
    expect(service, contains('.setChronometerCountDown(plan.countDown)'));
    // WP-558: tani ekstralari her bildirime yaziliyordu, okuyucusu yoktu.
    expect(service, isNot(contains('EXTRA_PROMOTED_NOW_BAR')));
    expect(service, isNot(contains('EXTRA_TIMER_PRESENTATION')));
  });

  test('WP-558: widget gereksiz uyandirmaz, boot sonrasi tazelenir', () {
    final boot = File(
      'android/app/src/main/kotlin/com/manilmax/online_study_room/'
      'TimerBootReceiver.kt',
    ).readAsStringSync();
    final info = File(
      'android/app/src/main/res/xml/odak_timer_widget_info.xml',
    ).readAsStringSync();
    final service = File(
      'android/app/src/main/kotlin/com/manilmax/online_study_room/timer/'
      'StudyTimerService.kt',
    ).readAsStringSync();

    // Chronometer.base `elapsedRealtime`e goredir; reboot'ta sifirlanir ve
    // launcher'in sakladigi eski base anlamsizlasir. Boot'ta widget'i
    // tazeleyen TEK yer bu receiver'dir.
    expect(boot, contains('TimerWidgets.updateAll(context)'));
    // Olu anahtar: Dart hicbir yerde okumuyordu.
    expect(boot, isNot(contains('timer_restore_pending')));

    // Periyodik onUpdate hicbir bilgi tasimiyordu (gunde ~48 uyandirma):
    // tek dinamik oge kendi kendine akan Chronometer, dugme etiketi ise
    // basla/durdur aninda TimerWidgets.updateAll ile itiliyor.
    expect(info, contains('android:updatePeriodMillis="0"'));
    expect(info, isNot(contains('1800000')));

    // Ulasilamaz mola yolu + uykudaki rol tuzagi silindi.
    expect(service, isNot(contains('ACTION_START_BREAK')));
    expect(service, isNot(contains('handleStartBreak')));
    // ACTION_END_BREAK OLU DEGIL: bildirimdeki 'Calismaya don' dugmesi.
    expect(service, contains('ACTION_END_BREAK'));
    expect(service, contains('endBreakActionPending()'));
  });

  test('WP-558: sayac bildirim kanali her acilista guncellenir', () {
    final service = File(
      'android/app/src/main/kotlin/com/manilmax/online_study_room/timer/'
      'StudyTimerService.kt',
    ).readAsStringSync();

    // Erken `return` kanal ADINI ilk kurulumdaki dile cakiyordu; Dart
    // tarafi (app_push_notification_service) kosulsuz cagiriyor.
    expect(service, contains('createNotificationChannel(channel)'));
    expect(service, isNot(contains('if (existing != null) return')));
  });
}
