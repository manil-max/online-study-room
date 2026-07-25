import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/features/notifications/announcements_screen.dart';
import 'package:online_study_room/features/notifications/notification_center_screen.dart';
import 'package:online_study_room/features/profile/settings_screen.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// WP-304: Bildirim Merkezi bir **ayar** ekranıdır. Beta 1 raporu:
/// test/tanı düğmeleri en üstteydi, alarm satırı Saat sekmesini tekrarlıyordu,
/// hatırlatıcılar alarmla aynı işi anlatıyordu ve duyurular ayar listesinin
/// içinde kaybolup fark edilmiyordu.
void main() {
  Future<void> pump(WidgetTester tester, Widget home) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    tester.view.physicalSize = const Size(1080, 12000);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authStateProvider.overrideWith(
            (ref) => Stream.value(
              Profile(id: 'u1', displayName: 'Ben', createdAt: DateTime.now()),
            ),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: home,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('merkezde hatırlatıcı ve alarm satırı kalmadı', (tester) async {
    await pump(tester, const NotificationCenterScreen());

    // Hatırlatıcı tamamen kaldırıldı (sahip kararı: alarm aynı işi yapıyor).
    expect(find.text('Hatırlatıcılar'), findsNothing);
    expect(find.text('Hatırlatıcı ekle'), findsNothing);
    expect(find.text('Çalışma hatırlatıcıları'), findsNothing);
    // Alarm/zamanlayıcı Saat sekmesinde; ayarlar onu tekrarlamaz.
    expect(find.text('Alarm ve zamanlayıcı'), findsNothing);
    // Duyuru listesi buradan Ayarlar'a taşındı; yalnız tercih anahtarı kalır.
    expect(find.text('Uygulama ve grubuna özel duyurular'), findsNothing);
    expect(find.text('Şimdilik duyuru yok.'), findsNothing);

    // Gündelik ayarlar duruyor.
    expect(find.text('Bildirim türleri'), findsOneWidget);
    expect(find.text('Sessiz saatler'), findsOneWidget);
  });

  testWidgets('test/tanı kartı en altta durur', (tester) async {
    await pump(tester, const NotificationCenterScreen());

    final health = find.text('Bildirim sağlığı');
    final quiet = find.text('Sessiz saatler');
    expect(health, findsOneWidget);
    // Eskiden tanı kartı listenin ikinci sırasındaydı: ayar aramaya gelen
    // kullanıcı önce "yerel test / uzak test" düğmeleriyle karşılaşıyordu.
    expect(
      tester.getTopLeft(health).dy,
      greaterThan(tester.getTopLeft(quiet).dy),
    );
  });

  testWidgets('duyurular Ayarlar\'dan açılır', (tester) async {
    await pump(tester, const SettingsScreen());

    expect(find.text('Uygulama ve grubuna özel duyurular'), findsOneWidget);
    // Okunmamış duyuru varken satırda nokta çıkar (başarım rozetiyle aynı dil);
    // kullanıcı ayarlara bakınca yeni bir şey geldiğini görsün.
    expect(find.byKey(const Key('announcements-unread-dot')), findsOneWidget);
    await tester.tap(find.text('Duyurular'));
    await tester.pumpAndSettle();
    expect(find.byType(AnnouncementsScreen), findsOneWidget);
  });
}
