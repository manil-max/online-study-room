// WP-682 — ÖDÜL BANNERI ÜST ŞERİDİ SÜRESİZ ÖRTÜYORDU.
//
// WP-681 taç KUTLAMASINI düzeltti (`IgnorePointer`) ama ödül BANNERI'nı
// bilerek dışarıda bıraktı: bannerın kendi Topla/Kapat düğmeleri var,
// `IgnorePointer` onları öldürürdü. Banner kutlamadan daha kötüydü — kutlama
// 1800 ms sonra kendi kalkar, banner **kullanıcı kapatana kadar** durur.
//
// 🔴 BU DOSYA KAYNAĞA BAKMAZ. Her iddia gerçek kabuktan (`OnlineStudyRoomApp`)
// boyanan dikdörtgenle ve gerçek bir `tester.tap`in tetiklediği ekran
// değişimiyle ölçülür. "home_shell.dart'ta konum değişti" kanıt değildir.
//
// ================== DÜZELTME ÖNCESİ ÖLÇÜM (2026-08-10) ======================
//
// masaüstü 1920x1080, Araçlar (Saat) sekmesi:
//   banner kutusu              : (680.0, 8.0) – (1240.0, 48.0)
//   "Timer" şerit ögesi         : (552.7, 22.0) – (751.3, 72.0)
//   ölü kesişim                 : (680.0, 22.0) – (751.3, 48.0)
//   tester.tapAt(715.7, 35.0)  : yutuldu — TimersScreen hiç açılmadı
//   (ögenin merkezi 652,47 bannerın SOLUNDA kaldığı için merkez tıklaması
//    geçiyordu; kullanıcının gördüğü sağ yarısı ölüydü. Kusur budur.)
//
// mobil 393x852, Araçlar sekmesi:
//   banner kutusu              : (12.0, 8.0) – (381.0, 56.0)
//   "Timer" şerit ögesi         : (134.3, 14.0) – (258.7, 64.0)  → TAMAMEN altta
//   ölü kesişim                 : (134.3, 14.0) – (258.7, 56.0)
//   tester.tapAt(196.5, 35.0)  : yutuldu; merkez tıklaması (196.5, 39.0) da
//                                yutuldu — TimersScreen hiç açılmadı
//
// Kutlamadan farkı: bu durum 1800 ms değil, kullanıcı bannerı kapatana kadar
// sürer. Şeridin orta ögesi süresiz erişilemez.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/core/device_integrations/samsung_modes_service.dart';
import 'package:online_study_room/data/models/achievement_reward.dart';
import 'package:online_study_room/data/providers/achievement_reward_provider.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/group_providers.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_group_repository.dart';
import 'package:online_study_room/features/android_widgets/android_widget_service.dart';
import 'package:online_study_room/features/clock/timers_screen.dart';
import 'package:online_study_room/l10n/app_localizations_tr.dart';
import 'package:online_study_room/main.dart';

import '../../support/v8_test_setup.dart';

void main() {
  final tr = AppLocalizationsTr();
  final rewardText = tr.profileRewardReady(3, 900);

  Future<void> onWindows(Future<void> Function() body) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      await body();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }

  Future<void> settle(WidgetTester tester) async {
    try {
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 3),
      );
    } catch (_) {
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 120));
      }
    }
  }

  /// Gerçek kabuğu bekleyen ödülle ayağa kaldırır ve Araçlar sekmesini açar.
  /// Sekme etiketi iki kolda FARKLI: masaüstü `desktopSaat`, mobil `navTools`.
  Future<void> openTools(WidgetTester tester, {required Size window}) async {
    tester.binding.platformDispatcher.localesTestValue = const [Locale('tr')];
    addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = window;
    addTearDown(tester.view.reset);

    final preferences = await v8SharedPreferences();
    final auth = await signedInV8AuthRepository(prefs: preferences);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          groupRepositoryProvider.overrideWithValue(InMemoryGroupRepository()),
          sharedPreferencesProvider.overrideWithValue(preferences),
          // 🔴 Ölçümün tek koşulu: banner GÖRÜNÜR olmalı.
          pendingAchievementRewardSummaryProvider.overrideWith(
            (ref) =>
                const AchievementRewardSummary(pendingCount: 3, pendingXp: 900),
          ),
          deviceIntegrationServiceProvider.overrideWithValue(
            V8TestDeviceIntegrationService(),
          ),
          androidWidgetServiceProvider.overrideWithValue(V8TestWidgetGateway()),
        ],
        child: const OnlineStudyRoomApp(),
      ),
    );
    await settle(tester);

    final tab = debugDefaultTargetPlatformOverride == TargetPlatform.windows
        ? tr.desktopSaat
        : tr.navTools;
    expect(
      find.text(tab),
      findsWidgets,
      reason: 'Kabuk çizilmedi: "$tab" gezinme ögesi yok.',
    );
    await tester.tap(find.text(tab).first);
    await settle(tester);
  }

  /// Kullanıcının GÖRDÜĞÜ banner kutusu (elevation'lı `Material` yüzeyi).
  Rect bannerRect(WidgetTester tester) => tester.getRect(
    find
        .ancestor(of: find.text(rewardText), matching: find.byType(Material))
        .first,
  );

  /// Şeridin ORTA ögesi — bannerın altında kalan gerçek dokunma hedefi.
  final stripMiddle = find.byKey(const Key('clock_tab_timer'));

  Future<void> measureOverlap(
    WidgetTester tester, {
    required Size window,
  }) async {
    await openTools(tester, window: window);

    // 1) Banner gerçekten ekranda mı? Değilse bu test hiçbir şey ölçmez.
    expect(
      find.text(rewardText),
      findsOneWidget,
      reason: 'Banner çizilmedi; örtme ölçülemez.',
    );
    expect(stripMiddle, findsOneWidget, reason: 'Araçlar şeridi çizilmedi.');

    final banner = bannerRect(tester);
    final strip = tester.getRect(stripMiddle);
    final target = tester.getCenter(stripMiddle);

    // 2) Ön koşul: şerit ögesi hâlâ ekranda ve bannerla aynı hizada mı?
    //    (Bu iddia düzeltmeden SONRA da geçerlidir; asıl kanıt 3 ve 4.)
    expect(
      strip.width > 0 && strip.height > 0,
      isTrue,
      reason: 'Şerit ögesi $strip — sıfır alan, ölçüm geçersiz.',
    );

    // 3) 🔴 ASIL ÖLÇÜM: kullanıcı orta ögeye dokunuyor — geçiyor mu?
    expect(
      find.byType(TimersScreen),
      findsNothing,
      reason: 'Ön koşul: Araçlar alarm alt sekmesiyle açılmalı.',
    );
    // 3a) Bannerın ALTINDA kalan noktaya dokunuş. Masaüstünde bannerın sol
    //     kenarı ögenin merkezinin sağında kalıyor: merkez tıklaması geçiyor,
    //     ögenin görünen sağ yarısı ise ölü. Kullanıcı oraya bastığında hiçbir
    //     şey olmaz — ölçüm tam o noktadan alınır.
    if (banner.overlaps(strip)) {
      final dead = banner.intersect(strip);
      await tester.tapAt(dead.center);
      await settle(tester);
      expect(
        find.byType(TimersScreen),
        findsOneWidget,
        reason:
            'Şerit ögesinin ($strip) bannerla ($banner) kesişen parçası '
            '$dead — kullanıcının GÖRDÜĞÜ bu alana yapılan ${dead.center} '
            'dokunuşu banner yuttu, alt sekme değişmedi.',
      );
    }
    // 3b) Ögenin merkezi.
    await tester.tap(stripMiddle, warnIfMissed: false);
    await settle(tester);
    expect(
      find.byType(TimersScreen),
      findsOneWidget,
      reason:
          'Ödül banneri ($banner) şerit ögesinin ($target) dokunuşunu yuttu; '
          'alt sekme hiç değişmedi. Banner kullanıcı kapatana kadar durur, '
          'yani bu öge SÜRESİZ erişilemez.',
    );

    // 4) Geometri: banner gezinme şeridinin ÜSTÜNE hiç düşmemeli. (3) tek
    //    başına "dokunuş geçti" der; bu, kutunun ögeyi görsel olarak da
    //    örtmediğini kilitler.
    expect(
      banner.overlaps(strip),
      isFalse,
      reason:
          'Banner $banner, şerit ögesi $strip — kutular kesişiyor. Banner bir '
          'BILDIRIM şeridi; gezinmenin üstünü kaplamamalı.',
    );

    // 5) İŞLEV KAYBI YOK: banner hâlâ ekranın içinde ve düğmeleri çalışıyor.
    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    expect(
      banner.top >= 0 && banner.bottom <= screen.height + 0.5,
      isTrue,
      reason: 'Banner $banner ekranın ($screen) dışına taşmış — görünmez oldu.',
    );
    // Taç kutlaması (WP-681) araya girerse bannerı 1800 ms boyunca kendi
    // yerinde gölgeler; kalkınca banner geri gelmeli. Bu bekleme aynı zamanda
    // "banner gezinmede kayboldu mu?" sorusunu da yanıtlar.
    await tester.pump(const Duration(milliseconds: 1800));
    await settle(tester);
    expect(
      find.text(rewardText),
      findsOneWidget,
      reason: 'Banner alt sekme değişince kayboldu — işlev kaybı.',
    );
    expect(find.text(tr.profileRewardClaim), findsOneWidget);
    await tester.tap(find.text(tr.profileRewardClaim));
    await settle(tester);
    // "Topla" Profil sekmesine geçirir: Araçlar şeridi ekrandan kalkar. Düğme
    // ölmüşse hiçbir şey olmaz ve şerit yerinde kalır.
    expect(
      stripMiddle,
      findsNothing,
      reason: 'Banner "Topla" düğmesi tıklanamaz oldu; sekme değişmedi.',
    );
  }

  testWidgets('masaüstü 1920: ödül banneri Araçlar şeridini örtmez', (
    tester,
  ) async {
    await onWindows(
      () => measureOverlap(tester, window: const Size(1920, 1080)),
    );
  });

  testWidgets('mobil 393: ödül banneri Araçlar şeridini örtmez', (
    tester,
  ) async {
    await measureOverlap(tester, window: const Size(393, 852));
  });

  testWidgets('masaüstü: banner "Kapat" düğmesi hâlâ çalışır', (tester) async {
    await onWindows(() async {
      await openTools(tester, window: const Size(1920, 1080));
      expect(find.text(rewardText), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await settle(tester);
      expect(
        find.text(rewardText),
        findsNothing,
        reason: 'Banner "Kapat" düğmesi tıklanamaz oldu.',
      );

      // Banner kalkınca şerit zaten çalışmalı (kalıntı engel yok).
      await tester.tap(stripMiddle, warnIfMissed: false);
      await settle(tester);
      expect(find.byType(TimersScreen), findsOneWidget);
    });
  });
}
