import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/time_engine/clock_permissions.dart';
import 'package:online_study_room/features/clock/clock_widgets_screen.dart';
import 'package:online_study_room/features/clock/platform_limit_banner.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

/// WP-687 — Bildirim Merkezi'nin ikinci sekmesi (`ClockWidgetsScreen`)
/// Windows'ta da çiziliyor (`notification_permissions_screen.dart:122`).
///
/// Ekranın iki yarısı da Android'e özgüdür:
///  * ANA EKRAN WIDGET KATALOĞU — Windows'ta ana ekran widget'ı diye bir şey
///    yoktur; `androidWidgetServiceProvider` bu platformda `_Noop` döner
///    (`android_widget_service.dart:23-28`).
///  * DÖRT İZİN SATIRI — `ClockPermissions` her metodunda `if (!_android)
///    return;` yapar (`clock_permissions.dart:152-188`). Yani "Aç" düğmesi
///    Windows'ta **bozuk düğmedir**: basılır, hiçbir şey olmaz, sebebi de
///    söylenmez. Bu, WP-611'in `AlarmsScreen`/`TimersScreen` şeridiyle
///    kapattığı sınıfın ta kendisi.
///
/// Bu testler ekranın Windows kolunu kilitler; son test Android kolunun
/// **birebir** korunduğunu ölçer (işlev kaybı yok).
///
/// WP-852 (sahip kararı): dört izin satırı bu ekrandan kalktı; izinler yalnız
/// Ayarlar → İzinler ekranında yönetilir. Bu sekme durumu özetler ve Android'de
/// oraya TEK düğmeyle götürür. Satır/düğme sayan iddialar bu yeni biçime göre
/// yeniden yazıldı; şerit, katalog ve başlık iddiaları aynen kalır.
///
/// Platform `debugDefaultTargetPlatformOverride` ile enjekte edilir ve test
/// gövdesi bitmeden `finally` içinde geri alınır; aksi hâlde flutter_test'in
/// `debugAssertAllFoundationVarsUnset` denetimi patlar ve — daha kötüsü —
/// sonraki testler yalan söyler.

/// Windows'ta `ClockPermissions.snapshot()` `Platform.isAndroid == false`
/// olduğu için **her zaman** bunu döndürür (`clock_permissions.dart:127`).
const _windowsSnapshot = ClockPermissionSnapshot.unsupported;

/// Android'de kanal cevap verdiğinde oluşan gerçek durum: izinler sorulabilir
/// ve henüz verilmemiş. (WP-852'den beri özet "4 izin eksik" der.)
const _androidMissingSnapshot = ClockPermissionSnapshot(
  availability: ClockPermissionAvailability.available,
  notifications: false,
  exactAlarm: false,
  batteryUnrestricted: false,
  fullScreenIntent: false,
);

void main() {
  tearDown(() => ClockPermissions.debugSnapshotOverride = null);

  Future<void> onPlatform(
    TargetPlatform platform,
    Future<void> Function() body,
  ) async {
    debugDefaultTargetPlatformOverride = platform;
    try {
      await body();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }

  Future<void> pump(WidgetTester tester, {String locale = 'tr'}) async {
    // 🔴 WP-708: yukseklik 6000 -> 14000 (mantiksal 2000 -> ~4667).
    // WP-707 dort widget'i yayina alinca katalog 3 karttan 7 karta cikti
    // ve IZIN satirlari 2000 px'in altina dustu. `ListView(children:)`
    // gorunmeyen cocugun ELEMENTINI kurmaz, yani satirlar agacta hic
    // olusmadi ve `find` onlari bulamadi -- islev kaybi DEGIL, olcum
    // alani yetersizligi. Bu dosyanin iddiasi yapisal ("Android kolunda
    // kontroller duruyor"), o yuzden dogru duzeltme alani buyutmek.
    // Kaydirarak da olculebilirdi; alani buyutmek iddianin "hepsi ayni
    // anda var" anlamini korur.
    tester.view.physicalSize = const Size(1080, 14000);
    tester.view.devicePixelRatio = 3;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: Locale(locale),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ClockWidgetsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('WP-687 Windows: platform sınırı ekranda yazılı', (tester) async {
    await onPlatform(TargetPlatform.windows, () async {
      ClockPermissions.debugSnapshotOverride = _windowsSnapshot;
      await pump(tester);

      expect(
        find.byKey(const Key('clock_widgets_desktop_limit_banner')),
        findsOneWidget,
        reason:
            'Windows kolunda ekranın tamamı Android\'e özgü; sınır '
            'kapatılamaz biçimde yazılmalı (WP-611 şeridiyle aynı dil).',
      );
      expect(find.byType(PlatformLimitBanner), findsOneWidget);
    });
  });

  testWidgets('WP-687 Windows: Android ana ekran widget kataloğu çizilmez', (
    tester,
  ) async {
    await onPlatform(TargetPlatform.windows, () async {
      ClockPermissions.debugSnapshotOverride = _windowsSnapshot;
      await pump(tester);

      // Yayındaki tek widget "Çalışma sayacı"
      // (`published_home_widgets.dart:45`). Windows'ta kurulacağı bir ana
      // ekran yok — vaat edilmemeli.
      expect(find.text('Çalışma sayacı'), findsNothing);
      expect(
        find.text('Akan süre + Başlat/Durdur (app kapalı çalışır)'),
        findsNothing,
      );
    });
  });

  // 🔴 WP-852: bu test eskiden dört "Aç" düğmesinin Windows'ta DEVRE DIŞI
  // çizildiğini ölçüyordu (satır bilgi taşısın, düğme basılamasın). Sahip
  // kararıyla satırlar bu ekrandan tamamen kalktı. Bozuk düğmeye karşı
  // korumanın niyeti aynı: Windows'ta basılıp hiçbir şey yapmayan bir izin
  // düğmesi YOK — ne satır düğmesi ne de İzinler ekranına giden düğme.
  testWidgets(
    'WP-687/852 Windows: izin düğmesi yok, özet platform sınırını söyler',
    (tester) async {
      await onPlatform(TargetPlatform.windows, () async {
        ClockPermissions.debugSnapshotOverride = _windowsSnapshot;
        await pump(tester);

        expect(find.widgetWithText(TextButton, 'Aç'), findsNothing);
        expect(
          find.byKey(const Key('clock_widgets_open_permissions')),
          findsNothing,
          reason:
              'Windows\'ta verilecek izin yok; İzinler ekranı orada yalnız '
              '"izin gerekmiyor" der. Eylem düğmesi çizilmemeli (WP-688).',
        );
        expect(
          find.byKey(const Key('clock_widgets_permission_summary')),
          findsOneWidget,
        );
        expect(
          find.text('Bu izinler yalnız Android\'de geçerli'),
          findsOneWidget,
        );
      });
    },
  );

  testWidgets('WP-687 Android kolu birebir korunur (işlev kaybı yok)', (
    tester,
  ) async {
    await onPlatform(TargetPlatform.android, () async {
      ClockPermissions.debugSnapshotOverride = _androidMissingSnapshot;
      await pump(tester);

      expect(
        find.byKey(const Key('clock_widgets_desktop_limit_banner')),
        findsNothing,
        reason: 'Android\'de platform sınırı yok.',
      );
      expect(
        find.text('Çalışma sayacı'),
        findsOneWidget,
        reason: 'Yayındaki widget kartı Android\'de görünmeye devam etmeli.',
      );
      // 🔴 WP-852: eskiden dört ETKİN "Aç" düğmesi ve toplu "Eksik izinleri
      // aç" düğmesi ölçülüyordu. Sahip kararıyla izinler İzinler ekranına
      // taşındı; Android kolunun işlevi artık "eksik sayısı görünür + İzinler
      // ekranına giden düğme ETKİN" demektir.
      expect(find.widgetWithText(TextButton, 'Aç'), findsNothing);
      expect(find.text('4 izin eksik'), findsOneWidget);
      final open = tester.widget<ButtonStyleButton>(
        find.byKey(const Key('clock_widgets_open_permissions')),
      );
      expect(
        open.onPressed,
        isNotNull,
        reason: 'Android\'de İzinler ekranına giden düğme ETKİN olmalı.',
      );
    });
  });

  // ────────────────────────────────────────────────────────────────────────
  // WP-688 — WP-687'nin bıraktığı metin borcu.
  //
  // WP-687 şeridi koydu ama `.arb` onun SAHİP yollarında değildi, bu yüzden
  // en yakın dizeyi ödünç aldı: `notificationsIzinMasaustundeGecersiz`
  // ("Masaüstü sürümü işletim sistemi bildirimi göndermez…"). O cümle yalnız
  // ekranın **izin** yarısını anlatıyor; katalog yarısı hakkında tek kelime
  // etmiyor. Başlık ("Widget ve izinler") ise masaüstünde artık çizilmeyen bir
  // şeyi vaat ediyordu.
  // ────────────────────────────────────────────────────────────────────────

  /// WP-688 şerit metni — iki yarıyı da adıyla anar.
  const trBanner =
      'Masaüstü sürümünde ana ekran widget\'ı da Android izinleri de yoktur; '
      'bu sekmede kurulacak ya da verilecek bir şey yok.';
  const enBanner =
      'The desktop build has no home screen widgets and no Android '
      'permissions, so there is nothing to add or grant on this tab.';

  /// WP-687'nin ödünç aldığı, yalnız bildirim izninden söz eden dize.
  const borrowedNotificationsOnly =
      'Masaüstü sürümü işletim sistemi bildirimi göndermez; burada kontrol '
      'edilecek bir izin yok.';

  testWidgets('WP-688 Windows: şerit iki yarıyı da anlatır (ödünç dize yok)', (
    tester,
  ) async {
    await onPlatform(TargetPlatform.windows, () async {
      ClockPermissions.debugSnapshotOverride = _windowsSnapshot;
      await pump(tester);

      expect(
        find.text(trBanner),
        findsOneWidget,
        reason:
            'Şerit hem ana ekran widget kataloğunun hem de dört iznin bu '
            'platformda olmadığını söylemeli; ekranda çizilen METİN ölçülür.',
      );
      expect(
        find.text(borrowedNotificationsOnly),
        findsNothing,
        reason:
            'WP-687 bu dizeyi ödünç almıştı: yalnız bildirim izninden söz '
            'ediyor, kataloğu hiç anmıyor.',
      );
    });
  });

  testWidgets('WP-688 Windows: şerit EN katalogda da çizilir', (tester) async {
    await onPlatform(TargetPlatform.windows, () async {
      ClockPermissions.debugSnapshotOverride = _windowsSnapshot;
      await pump(tester, locale: 'en');

      expect(
        find.text(enBanner),
        findsOneWidget,
        reason: 'Yeni anahtar iki dilde de gerçekten çiziliyor olmalı.',
      );
    });
  });

  testWidgets('WP-688 Windows: başlık olmayan widget\'ı vaat etmez', (
    tester,
  ) async {
    await onPlatform(TargetPlatform.windows, () async {
      ClockPermissions.debugSnapshotOverride = _windowsSnapshot;
      await pump(tester);

      expect(
        find.text('Widget ve izinler'),
        findsNothing,
        reason:
            'Masaüstünde katalog hiç çizilmiyor; başlık var olmayan bir yüzeyi '
            'vaat edemez.',
      );
      expect(
        find.text('Android izin bilgisi'),
        findsNWidgets(2),
        reason:
            'Başlık iki yerde geçer: AppBar (`:214`) ve gövdenin ilk satırı '
            '(`:95`). İkisi de düzeltilmeli, biri değil.',
      );
    });
  });

  testWidgets('WP-688 Windows: "İzinleri yenile" düğmesi çizilmez', (
    tester,
  ) async {
    await onPlatform(TargetPlatform.windows, () async {
      ClockPermissions.debugSnapshotOverride = _windowsSnapshot;
      await pump(tester);

      // Karar: dört izin SATIRI devre dışı bırakılır (satır bilgi taşır:
      // Android'de hangi izin gerekiyor), ama bu düğme yalnız EYLEMDEN ibaret.
      // `snapshot()` masaüstünde `Platform.isAndroid == false` diye kanala hiç
      // gitmeden `unsupported` döner (`clock_permissions.dart:127`) — yani
      // "yenile" sonucu ASLA değişemez. Devre dışı gri bir düğme "şimdilik
      // olmuyor" der; doğrusu "bu platformda böyle bir şey yok".
      expect(
        find.text('İzinleri yenile'),
        findsNothing,
        reason:
            'Sonucu değişemeyen, bilgi de taşımayan bir eylem düğmesi '
            'çizilmemeli (WP-611 bozuk düğme sınıfı).',
      );
      expect(
        find.widgetWithText(OutlinedButton, 'İzinleri yenile'),
        findsNothing,
      );
    });
  });

  testWidgets(
    'WP-688/852 Android kolu: başlık korunur, izin eylemi tek düğme',
    (tester) async {
      await onPlatform(TargetPlatform.android, () async {
        ClockPermissions.debugSnapshotOverride = _androidMissingSnapshot;
        await pump(tester);

        expect(
          find.text('Widget ve izinler'),
          findsNWidgets(2),
          reason: 'Android başlığı bugünkü gibi kalmalı (AppBar + gövde).',
        );
        expect(find.text('Android izin bilgisi'), findsNothing);
        // 🔴 WP-852: "İzinleri yenile" Android'de de kalktı (sahip kararı: tek
        // eylem). Yenileme kaybolmadı: özet uygulama öne döndüğünde ve İzinler
        // ekranından geri gelindiğinde kendiliğinden yeniden okunur.
        expect(
          find.widgetWithText(OutlinedButton, 'İzinleri yenile'),
          findsNothing,
        );
        expect(
          find.byKey(const Key('clock_widgets_open_permissions')),
          findsOneWidget,
        );
        expect(find.text(trBanner), findsNothing);
      });
    },
  );
}
