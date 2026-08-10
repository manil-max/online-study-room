// WP-685 — Bildirim Merkezi'nin WINDOWS kolu.
//
// Bu dosya iki AYRI soruyu ölçer; ikisi de "masaüstünde ne görünüyor?" sorusu
// ama cevapları zıt yönde çıktı:
//
//   1. "Bildirim sağlığı" tanı kartı Windows'ta hiç çizilmiyor
//      (`_PushHealthCard` → `SizedBox.shrink()`).  Bu **kusur değildir**:
//      kart bir tanı yüzeyidir ve gövdesi iki düğmeden ibarettir ("Yerel test",
//      "Uzak test"). Windows'ta FCM yoktur (`AppPushNotificationService
//      .isSupported` → android-only) ve `AppNotificationCoordinator` da
//      android kapısı arkasındadır; kartı çizmek WP-611'in adını koyduğu
//      "bozuk düğme"yi geri getirirdi. Kullanıcının ihtiyaç duyduğu BİLGİ ise
//      kaybolmuyor: aynı ekranın en üstündeki izin kartı masaüstünde
//      `notificationsIzinMasaustundeGecersiz` metnini yazıyor.
//      Aşağıdaki iddialar bu davranışı KİLİTLER — bugüne kadar hiçbir test
//      Windows kolunu çizmiyordu (varsayılan platform android).
//
//   2. Aynı ekrandaki "Dürtme bildirimleri" ve "Güncelleme bildirimleri"
//      anahtarları Windows'ta AÇIK ve dokunulabilir. İkisinin de teslim yolu
//      yalnız Android'dir. Bu, WP-611'in "ayarı açtım, hiçbir şey olmadı"
//      diye kapattığı kusurun HÂLÂ AÇIK olan kardeşidir.
//
// İddialar iki yönlüdür: her Windows iddiasının yanında Android kolunun
// bugünkü davranışı aynen sürdüğünü ölçen bir eş iddia vardır.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:online_study_room/core/notifications/notification_preferences.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/features/notifications/notification_center_screen.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

/// Platformu enjekte eder ve gövde biter bitmez geri alır.
///
/// Ağaç önce sökülür: `debugDefaultTargetPlatformOverride` hâlâ ayarlıyken
/// sökmek, sökülme sırasında platform okuyan bir dalın yalan söylemesine yol
/// açardı; `tearDown` ise çok geç kalır.
Future<void> _withPlatform(
  WidgetTester tester,
  TargetPlatform platform,
  Future<void> Function() body,
) async {
  debugDefaultTargetPlatformOverride = platform;
  try {
    await body();
  } finally {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    debugDefaultTargetPlatformOverride = null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => debugDefaultTargetPlatformOverride = null);

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  /// ListView tembeldir: tanı kartı listenin SON çocuğudur. Küçük bir görünüm
  /// alanında "çizilmedi" sonucu platformdan değil kaydırmadan gelirdi.
  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 12000);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: MaterialApp(
          locale: const Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const NotificationCenterScreen(),
        ),
      ),
    );
    await tester.pump();
  }

  AppLocalizations l10nOf(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(NotificationCenterScreen)));

  group('bildirim sağlığı kartı', () {
    testWidgets('Windows: kart çizilmez ama nedeni ekranda yazar', (
      tester,
    ) async {
      await _withPlatform(tester, TargetPlatform.windows, () async {
        await pump(tester);
        final l10n = l10nOf(tester);

        // Tanı kartı ve İKİ DÜĞMESİ de yok — "bozuk düğme" yasağı.
        expect(find.text(l10n.notificationsHealthTitle), findsNothing);
        expect(find.text(l10n.notificationsLocalTest), findsNothing);
        expect(find.text(l10n.notificationsRemoteTest), findsNothing);

        // 🔴 Gizlemeyi MEŞRU kılan şart: bilgi kaybolmuyor. Bu iddia düşerse
        // kartın gizlenmesi bilgi boşluğuna dönüşür ve karar (b) geçersizdir.
        final note = tester.widget<Text>(
          find.byKey(const Key('notification_permission_note')),
        );
        expect(note.data, l10n.notificationsIzinMasaustundeGecersiz);
      });
    });

    testWidgets('Android: kart ve düğmeleri eskisi gibi çizilir', (
      tester,
    ) async {
      await _withPlatform(tester, TargetPlatform.android, () async {
        await pump(tester);
        final l10n = l10nOf(tester);

        // İŞLEV KAYBI YOK: Android'de tanı kartı bugünkü hâliyle duruyor.
        expect(find.text(l10n.notificationsHealthTitle), findsOneWidget);
        expect(find.text(l10n.notificationsLocalTest), findsOneWidget);
        expect(find.text(l10n.notificationsRemoteTest), findsOneWidget);
      });
    });
  });

  group('teslim edilemeyen bildirim türleri', () {
    // 🔴 WP-611 aynı ekranda akıllı hatırlatıcı satırlarını devre dışı bıraktı
    // çünkü masaüstünde teslim edilemiyorlardı. Dürtme ve güncelleme
    // bildirimleri de masaüstünde teslim EDİLEMEZ:
    //   - dürtme  : nudge_notification_service → AppNotificationCoordinator
    //               .showNudge → `if (!_isAndroid) return;`
    //   - güncelleme: `updatesEnabled` tercihinin lib/ içinde tek tüketicisi
    //               push kaydıdır (push_notification_providers.dart:194) ve
    //               Windows'ta readiness `unsupported` olduğu için cihaz hiç
    //               kaydedilmez.
    // Duyurular anahtarı BU LİSTEDE DEĞİLDİR: masaüstünde de gerçek bir işi
    // vardır (notification_providers.dart:28 uygulama içi duyuru listesini
    // kapatır), o yüzden açık kalmalıdır.

    testWidgets('Windows: dürtme ve güncelleme satırları devre dışı', (
      tester,
    ) async {
      await _withPlatform(tester, TargetPlatform.windows, () async {
        await pump(tester);
        final l10n = l10nOf(tester);

        final nudge = tester.widget<SwitchListTile>(
          find.widgetWithText(
            SwitchListTile,
            l10n.notificationsDurtmeBildirimleri,
          ),
        );
        final update = tester.widget<SwitchListTile>(
          find.widgetWithText(
            SwitchListTile,
            l10n.notificationsGuncellemeBildirimleri,
          ),
        );

        expect(
          nudge.onChanged,
          isNull,
          reason:
              'masaüstünde dürtme bildirimi teslim edilemiyor; anahtar '
              'açılabiliyorsa "ayarı açtım hiçbir şey olmadı" kusuru sürüyor',
        );
        expect(update.onChanged, isNull);

        // 🔴 İki tercihin de varsayılanı AÇIK. Devre dışı ama "açık" görünen
        // bir anahtar, alt yazısı "masaüstünde kapalı" derken kendisiyle
        // çelişir; ekran bu cihazdaki GERÇEK etkiyi göstermeli.
        expect(nudge.value, isFalse);
        expect(update.value, isFalse);

        // Sessizce kapatmak da yasak: nedeni yazılı olmalı.
        expect(
          find.text(l10n.notificationsHatirlaticiMasaustundeYok),
          findsNWidgets(4),
          reason:
              'seri + haftalık (WP-611) ve dürtme + güncelleme (WP-685) = 4 satır',
        );

        // Devre dışı satıra dokunmak tercihi YAZMAMALI.
        await tester.tap(
          find.widgetWithText(
            SwitchListTile,
            l10n.notificationsDurtmeBildirimleri,
          ),
        );
        await tester.pump();
        expect(
          prefs.getBool(NotificationPreferencesNotifier.kNudgeNotifications),
          isNull,
        );
      });
    });

    testWidgets('Windows: duyurular anahtarı AÇIK kalır (işi var)', (
      tester,
    ) async {
      await _withPlatform(tester, TargetPlatform.windows, () async {
        await pump(tester);
        final l10n = l10nOf(tester);

        final announcements = tester.widget<SwitchListTile>(
          find.widgetWithText(SwitchListTile, l10n.notificationsDuyurular),
        );
        expect(
          announcements.onChanged,
          isNotNull,
          reason:
              'duyuru tercihi masaüstünde de uygulama içi listeyi kapatır; '
              'kapatmak gerçek bir özelliği öldürürdü',
        );

        await tester.tap(
          find.widgetWithText(SwitchListTile, l10n.notificationsDuyurular),
        );
        await tester.pump();
        expect(
          prefs.getBool(NotificationPreferencesNotifier.kAnnouncements),
          isFalse,
        );
      });
    });

    testWidgets('Android: dört satırın hepsi açık ve gerekçesiz', (
      tester,
    ) async {
      await _withPlatform(tester, TargetPlatform.android, () async {
        await pump(tester);
        final l10n = l10nOf(tester);

        for (final title in <String>[
          l10n.notificationsDurtmeBildirimleri,
          l10n.notificationsGuncellemeBildirimleri,
          l10n.notificationsDuyurular,
        ]) {
          expect(
            tester
                .widget<SwitchListTile>(
                  find.widgetWithText(SwitchListTile, title),
                )
                .onChanged,
            isNotNull,
            reason: 'İŞLEV KAYBI YOK: Android kolunda "$title" açık kalmalı',
          );
        }

        // Android'de masaüstü gerekçesi hiç görünmez.
        expect(
          find.text(l10n.notificationsHatirlaticiMasaustundeYok),
          findsNothing,
        );
        expect(
          find.text(l10n.notificationsSinifArkadaslarinSeniDurttugunde),
          findsOneWidget,
        );
        expect(
          find.text(l10n.notificationsYeniSurumCikincaHaber),
          findsOneWidget,
        );

        // Varsayılan AÇIK değeri Android'de aynen görünüyor (İŞLEV KAYBI YOK).
        expect(
          tester
              .widget<SwitchListTile>(
                find.byKey(const Key('notification_nudge_switch')),
              )
              .value,
          isTrue,
        );
        expect(
          tester
              .widget<SwitchListTile>(
                find.byKey(const Key('notification_updates_switch')),
              )
              .value,
          isTrue,
        );
      });
    });
  });
}
