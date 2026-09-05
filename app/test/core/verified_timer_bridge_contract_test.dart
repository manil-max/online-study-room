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

    // 🔴 WP-772 — İDDİA YÖN DEĞİŞTİRDİ (cihazda ölçüldü, S23 / One UI 8.5).
    // Çip `shortCriticalText` verilirse SAATİ DEĞİL METNİ çizer: bizim çipte
    // "Focus" yazıyordu, Samsung Saat'in çipinde `00:05` akıyordu. Sahip
    // sayaç istiyor; metin hiç gönderilmez, çip `when` kronometresini çizer.
    expect(
      service,
      isNot(contains('.setShortCriticalText(')),
      reason:
          'Cip metni saati gizler (WP-772 cihaz olcumu). Kronometre kipinde '
          'metin gonderilmez; geri gelirse cipte sayac yerine yazi cikar.',
    );
    // Terfi eden kartın başlığı saf karardan gelir: ders adı / etiket.
    expect(service, contains('promotedCardTitle('));

    // Durum çubuğu ikonu monokrom; renkli launcher ikonu değil.
    // WP-772: jenerik saat kadranı yerine uygulamanın logosu (kamp ateşi
    // silueti, beş yoğunlukta alfa PNG).
    expect(service, contains('R.drawable.ic_stat_focus_camp'));
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
    // 🔴 v71: varsayilan true (v43 zengin panel). Live Update yolu duruyor
    // ama artik OPT-IN: cihazda dogrulanmadan varsayilan yapilmasi
    // bildirimin sayacini 00:00'a dusurup Start/Stop'u yok etmisti.
    expect(service, contains('prefs.getBoolean(KEY_PANEL_EXPANDED, true)'));
    expect(service, contains('if (plan.usesCustomView) {'));
    // 🔴 WP-759: eylem ikonu artik `0` DEGIL, gercek bir cizim.
    //
    // Eski iddia ikonsuz `addAction(0, ...)` cagrisini kilitliyordu. Bildirim
    // golgesi Android 7'den beri eylem ikonunu zaten cizmez -- ama Wear/Auto,
    // eski surumler ve terfi cipi icin ikon eylemin TEK gorsel karsiligidir.
    // Sahibin S23'te "Start/Stop tusu gitmis" demesinin sebeplerinden biri buydu.
    expect(
      service,
      contains('R.drawable.ic_notif_action_start'),
      reason: 'Baslat eylemi gercek bir ikon tasimali.',
    );
    expect(
      service,
      contains('R.drawable.ic_notif_action_stop'),
      reason: 'Durdur eylemi gercek bir ikon tasimali.',
    );
    // Yorum metni tarihi anlatmak icin eski cagriyi ANABILIR; olculen sey
    // gercekten derlenen koddur. Bu yuzden yorum satirlari once atilir --
    // aksi halde kusurun ANLATIMI kusurun KENDISI sanilir.
    final serviceCode = service
        .split('\n')
        .where((line) {
          final s = line.trimLeft();
          return !s.startsWith('//') && !s.startsWith('*') && !s.startsWith('/*');
        })
        .join('\n');
    expect(
      serviceCode,
      isNot(contains('addAction(0,')),
      reason: 'Ikonsuz eylem geri gelmemeli; kusur tam olarak oydu.',
    );
    // 🔴 WP-759: `base` yerel degiskeni yerini `panelChronometerBaseMs(...)`
    // adli SAF fonksiyona birakti -- sayacin tabani artik cihazsiz olculebiliyor.
    // Eski iddia degiskenin ADINI kilitliyordu; olculmesi gereken ad degil
    // SOZLESME: dogru gorunume, hesaplanmis bir tabanla, bicimsiz ve calisir
    // kurulur. Ustelik SIRA onemli -- `setBase` metni yeniden cizdigi icin
    // geri sayim bayragi ONCE gelmeli (uretim kodundaki yorum da bunu soyler).
    final countDownAt = service.indexOf('views.setChronometerCountDown(');
    final chronometerAt = service.indexOf('views.setChronometer(');
    expect(countDownAt, greaterThan(-1));
    expect(chronometerAt, greaterThan(-1));
    expect(
      countDownAt,
      lessThan(chronometerAt),
      reason: 'Geri sayim bayragi tabandan ONCE kurulmali.',
    );
    expect(
      service.substring(chronometerAt, chronometerAt + 400),
      allOf(
        contains('R.id.notif_timer_elapsed'),
        contains('panelChronometerBaseMs('),
        contains('null,'),
        contains('true,'),
      ),
      reason: 'Sayac hesaplanmis tabanla, bicimsiz ve calisir kurulmali.',
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
    // 🔴 WP-759: bu iddia TERS CEVRILDI, cunku olculerek yanlislandi.
    //
    // Renk kurali IKI YONLUDUR (`timer_notification.xml` basligi, emulator
    // olcumleri):
    //   WP-205 ham `#FFFFFF` yazdi -> ACIK golgede metin kayboldu.
    //   WP-753 tema NITELIGI yazdi -> KOYU golgede dugme kayboldu (1.08:1).
    // `RemoteViews` uygulamanin `ApplicationInfo` temasiyla sisirilir, yani
    // `?android:attr/...` HOST'un koyu/acik ayarini izlemez. Golge zemini
    // ustundeki metin bildirim `TextAppearance`ini kullanmali; onun rengi
    // yapilandirmaya bagli bir KAYNAKTIR ve host'u izler.
    expect(
      layout,
      isNot(contains('?android:attr/textColor')),
      reason: 'Golge ustundeki metin tema niteligi kullanamaz; koyu golgede kaybolur.',
    );
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

  test('WP-760: terfi karari GERCEKTEN soruluyor ve sonucu okunabiliyor', () {
    final service = File(
      'android/app/src/main/kotlin/com/manilmax/online_study_room/timer/'
      'StudyTimerService.kt',
    ).readAsStringSync();
    final capability = File(
      'android/app/src/main/kotlin/com/manilmax/online_study_room/timer/'
      'TimerPromotionCapability.kt',
    ).readAsStringSync();

    // 🔴 Yorumlar once atilir: bu turda yazilan aciklamalar kok nedeni
    // ANLATMAK icin eski ifadeyi kelimesi kelimesine aliyor. Kusurun
    // anlatimi kusurun kendisi degildir.
    String code(String source) => source
        .split('\n')
        .where((line) {
          final s = line.trimLeft();
          return !s.startsWith('//') && !s.startsWith('*') && !s.startsWith('/*');
        })
        .join('\n');

    final serviceCode = code(service);

    // KOK NEDEN (v72'ye kadar): sol taraf her zaman `true` oldugundan `||`
    // kisa devre yapiyor, sistemin terfiyi verip vermedigi HIC sorulmuyordu.
    // Zincirin devami `requestPromotedOngoing = !usesCustomView` oldugu icin
    // `setRequestPromotedOngoing(true)` hicbir cihazda hic cagrilmadi.
    expect(
      serviceCode,
      isNot(contains('useV43CustomPanel()')),
      reason:
          'Kosulsuz `true` donen valf geri geldi: terfi sorusu yine hic '
          'sorulmaz ve dinamik panel destekleyen cihazda bile cikmaz.',
    );
    expect(
      serviceCode,
      contains('richPanel = useRichPanel('),
      reason: 'Sunum karari saf `useRichPanel` uzerinden verilmeli.',
    );
    expect(serviceCode, contains('override = panelOverride(p)'));

    // Yoklama kendini duzeltmeli: RED olcumunden sonra dogru kart hemen
    // yeniden gonderilir, yoksa kullanici o oturumun TAMAMINI yanlis kartla
    // gecirir (kalici karar ancak bir sonraki Baslat'ta ise yarardi).
    // 🔴 Olcum GECIKMELI olmali. `notify()` bildirimi KUYRUKLAR;
    // `activeNotifications` gonderilmis listeyi okur. Senkron okuma cogu
    // zaman bildirimi bulamaz, verdict hic yazilmaz ve terfi etmeyen cihaz
    // her Baslat'ta duz kartta kalir.
    // 🔴 WP-763 GERI ALMA. WP-762 buraya `setProgressIndeterminate(true)`
    // iddiasini koymustu: "acik uclu kronometre de ProgressStyle tasimali,
    // yoksa sistemin cizecek bir Live Update ogesi olmaz". Hipotez CIHAZDA
    // yanlislandi -- v74'te bildirimde soldan saga suzulen belirsiz cubuk
    // belirdi, sayac 00:00'a dustu, dugme kayboldu ve cip YINE cikmadi.
    //
    // Iddia silinmedi, TERSINE CEVRILDI: acik uclu dal stil TASIMAMALI.
    expect(
      serviceCode,
      isNot(contains('setProgressIndeterminate')),
      reason:
          'Belirsiz ilerleme cubugu calisan bildirimi bozuyor ve karsiliginda '
          'hicbir sey vermiyor; cihazda olculdu (v74).',
    );
    expect(
      serviceCode,
      contains('schedulePromotionProbe(startedAtMs)'),
      reason: 'Senkron olcum geri geldi: yoklama bildirimi bulamadan biter.',
    );
    expect(
      serviceCode,
      contains('TimerPromotion.Verdict.DENIED'),
      reason:
          'Olcum sonucu okunmuyorsa `recordOutcome` yalniz diske yazar; '
          'ekrandaki kart bu oturum boyunca yanlis kalir.',
    );

    // Sonucun Dart tarafindan OKUNABILIR olmasi sozlesmenin parcasi:
    // `shared_preferences` yalniz `flutter.` onekli anahtarlari gorur.
    // Onek dusersen olcum yine yapilir ama kimse goremez -- alti tur boyunca
    // yasanan tam olarak buydu.
    expect(
      code(capability),
      contains('KEY_VERDICT = "flutter.timer_promotion_verdict_v1"'),
      reason:
          'Onek kalkarsa teshis ekrani sonsuza kadar "henuz olculmedi" der.',
    );
  });

  test('WP-767: silinen sayac bildirimi GORUNMEZ kosmaya devam etmez', () {
    final service = File(
      'android/app/src/main/kotlin/com/manilmax/online_study_room/timer/'
      'StudyTimerService.kt',
    ).readAsStringSync();

    final serviceCode = service
        .split('\n')
        .where((line) {
          final s = line.trimLeft();
          return !s.startsWith('//') && !s.startsWith('*') && !s.startsWith('/*');
        })
        .join('\n');

    // 🔴 Android 14'ten beri on plan bildirimi SILINEBILIR ve bu engellenemez;
    // istisnalar (CallStyle, medya, cihaz yoneticisi) bir calisma sayacini
    // kapsamiyor. Sahibin defalarca bildirdigi sikayet buydu.
    //
    // Engellenemeyen sey silinmesi; cozulebilen sey silindikten SONRA sayacin
    // GORUNMEDEN kosmaya devam etmesi. `setDeleteIntent` olmadan silinmeden
    // haberimiz bile olmuyordu.
    expect(
      serviceCode,
      contains('setDeleteIntent(actionPending(ACTION_NOTIFICATION_DISMISSED'),
      reason:
          'Silme haberi alinmazsa sayac gorunmeden kosar; kullanici ne kadar '
          'calistigini goremez ve durduracak dugmeyi bulamaz.',
    );
    expect(
      serviceCode,
      contains('ACTION_NOTIFICATION_DISMISSED -> handleNotificationDismissed()'),
      reason: 'Niyet tanimlandi ama DAGITILMADIYSA hicbir sey olmaz.',
    );

    // 🔴 Silme ile geri cagri arasinda Durdur'a basilmis olabilir. Kor bir
    // geri getirme, durmus sayac icin kosan kart gonderir -- yani sayaci
    // dirilmis gibi gosterir. Ayni kosul gecikmeli terfi yoklamasinda da var.
    final handlerAt = serviceCode.indexOf('fun handleNotificationDismissed(');
    expect(handlerAt, greaterThan(-1));
    final handlerBody = serviceCode.substring(handlerAt, handlerAt + 600);
    expect(
      handlerBody,
      contains('TimerStateStore.isRunning'),
      reason: 'Durmus sayac icin kosan kart gonderilemez.',
    );
  });

  test('WP-764: yuzen serit GERCEKTEN bagli ve KAPALI dogar', () {
    final service = File(
      'android/app/src/main/kotlin/com/manilmax/online_study_room/timer/'
      'StudyTimerService.kt',
    ).readAsStringSync();
    final overlay = File(
      'android/app/src/main/kotlin/com/manilmax/online_study_room/overlay/'
      'TimerOverlay.kt',
    ).readAsStringSync();
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();

    String code(String source) => source
        .split('\n')
        .where((line) {
          final s = line.trimLeft();
          return !s.startsWith('//') && !s.startsWith('*') && !s.startsWith('/*');
        })
        .join('\n');

    final serviceCode = code(service);
    final overlayCode = code(overlay);

    // 🔴 Bu deponun tekrar eden kusuru: "bitmis arka uc, baglanmamis on uc".
    // WP-759'da terfi kapisi eksiksiz yazilmis ama HICBIR YERDEN
    // CAGRILMIYORDU; kusur ancak grep'le yakalandi. Serit ayni sekilde
    // yazilip baglanmadan kalabilirdi.
    expect(
      serviceCode,
      contains('syncOverlay(startedAtMs)'),
      reason: 'Serit yazildi ama sayac baslarken CAGRILMIYOR: hic cizilmez.',
    );
    expect(
      serviceCode,
      contains('TimerOverlay.hide(this)'),
      reason:
          'Sayac durunca serit KALDIRILMALI; aksi halde ekranin ustunde '
          'durmus bir sayac asili kalir.',
    );

    // 🔴 Bu turda UC KEZ deneysel bir yol varsayilan yapildi ve calisan
    // bildirimi bozdu (v71, v74). Sahibin kurali: "test ederken sadece biz
    // gorelim, digerlerinde normal olsun". Serit KAPALI dogar.
    expect(
      overlayCode,
      contains('getBoolean(KEY_ENABLED, false)'),
      reason: 'Serit varsayilan ACIK dogarsa ayni hata dorduncu kez tekrarlanir.',
    );
    expect(
      overlayCode,
      contains('KEY_ENABLED = "flutter.timer_overlay_enabled"'),
      reason:
          'Onek dusersse Dart ayni anahtari goremez; anahtar iki tarafta '
          'ayrisir ve kullanicinin actigi serit hic acilmaz.',
    );

    // Izin ilan edilmemisse `canDrawOverlays` her zaman false doner ve serit
    // sessizce hic cizilmez.
    expect(
      manifest,
      contains('android.permission.SYSTEM_ALERT_WINDOW'),
      reason: 'Izin ilan edilmemisse serit hicbir cihazda cizilemez.',
    );
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
