import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/time_engine/clock_permissions.dart';
import 'package:online_study_room/features/clock/clock_widgets_screen.dart';

Future<void> _pumpScreen(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 6000);
  tester.view.devicePixelRatio = 3;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    const ProviderScope(
      child: MaterialApp(
        locale: Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ClockWidgetsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  // WP-296: izin durumu artık AÇIKÇA kuruluyor. Öncesinde test, masaüstünde
  // izinlerin "verilmiş" sayılmasına güveniyordu; WP-286 fail-closed'a geçince
  // (masaüstü → `unsupported`, hiçbiri verilmemiş) test sessizce kırmızıya
  // döndü. Bu testin niyeti "izin VERİLMİŞKEN kapatma rehberi çalışıyor mu",
  // o yüzden anlık görüntü test içinde `ok` olarak sabitlenir.
  tearDown(() => ClockPermissions.debugSnapshotOverride = null);

  testWidgets('izinler açıldıktan sonra sistem ayarından kapatılabilir', (
    tester,
  ) async {
    ClockPermissions.debugSnapshotOverride = ClockPermissionSnapshot.ok;
    await _pumpScreen(tester);

    expect(find.textContaining('Android sistem ayarlarından'), findsOneWidget);
    expect(find.text('Kapat'), findsNWidgets(4));

    await tester.tap(find.text('İzni geri almak ister misin?'));
    await tester.pumpAndSettle();

    expect(find.text('Bildirimleri kapat:'), findsOneWidget);
    expect(find.text('Kesin alarmı kapat:'), findsOneWidget);
    expect(find.text('Pil istisnasını kaldır:'), findsOneWidget);
    expect(find.text('Tam ekran alarmı kapat:'), findsOneWidget);
  });

  // 🔴 WP-688 madde 4: bu test kendini "Masaüstü/web" diye tanıtıyordu ama
  // `debugDefaultTargetPlatformOverride` hiç kurulmuyordu — `flutter test`'in
  // varsayılan platformu **android**'dir, yani Windows kolu (şerit, başlık,
  // devre dışı düğmeler) hiç çizilmiyordu. Dahası kurduğu bileşim üretimde
  // imkânsızdı: Android'de kanal cevap vermezse `snapshot()` `unknown` döner,
  // `unsupported` DEĞİL (`clock_permissions.dart:124-134`). İddia artık
  // ölçtüğü şeye eşit: platform gerçekten Windows.
  testWidgets(
    'WP-296/688 Windows: izinler bu platformda yoksa eksik izin iddiası '
    'yapılmaz',
    (tester) async {
      // Masaüstü: bu Android izinleri hiç yok. Kart öncesinde kırmızı
      // "4 Eksik izinleri aç" diyordu — kullanıcının düzeltmesi imkânsız,
      // yanlış bir iddia. Ayrıca alt satır ekran başlığındaki cümleyi
      // aynen tekrar ediyordu.
      //
      // Örtü `finally` ile geri alınır, `addTearDown` ile DEĞİL:
      // `debugAssertAllFoundationVarsUnset` denetimi test gövdesi biter
      // bitmez koşar, tearDown'lardan ÖNCE — addTearDown geç kalır ve test
      // "foundation debug variable was changed" diye kırmızı düşer (ölçüldü).
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        ClockPermissions.debugSnapshotOverride =
            ClockPermissionSnapshot.unsupported;
        await _pumpScreen(tester);

        expect(
          find.text('Bu izinler yalnız Android\'de geçerli'),
          findsOneWidget,
        );
        expect(find.textContaining('Eksik izinleri aç'), findsNothing);
        // Cümle yalnız ekran başlığında geçer, kart onu tekrarlamaz.
        expect(
          find.textContaining('Android sistem ayarlarından'),
          findsOneWidget,
        );
        // WP-688: Windows kolu gerçekten çizildiyse şerit de oradadır. Bu
        // satır olmadan test yine sessizce Android'e kayabilir.
        expect(
          find.byKey(const Key('clock_widgets_desktop_limit_banner')),
          findsOneWidget,
          reason: 'Şerit yoksa Windows kolu hiç çizilmemiş demektir.',
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );
}
