// WP-479 (V57-N02 ikinci yarısı): "Uzun bir ünvan seçilince 'Choose title'
// butonu alt satıra kayıyor ve gereksiz yer kaplıyor."
//
// İki ayrı iş var ve ikisi de burada bağlanıyor:
//   1. 🔴 Sahip kararı (bağlayıcı): seçici **alttan açılan kart OLMAYACAK**;
//      ders seçimindeki gibi butona çapalanan menü olacak. Bu kararın bekçisi
//      "menü açıldı" demek değil, `ModalBottomSheetRoute`un **hiç
//      açılmadığını** doğrulamaktır — ikisi aynı anda doğru olabilirdi.
//   2. Kayma `Wrap`tan geliyordu: chip genişleyince buton bir sonraki `run`'a
//      düşüyor ve kart yükseliyordu.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/achievement.dart';
import 'package:online_study_room/data/models/gamification_profile.dart';
import 'package:online_study_room/features/profile/widgets/achievement_showcase.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

final _now = DateTime.utc(2026, 8, 1);

/// Açılan rotaları kaydeder: alt sayfa açıldı mı sorusunu **doğrudan** yanıtlar.
class _RouteSpy extends NavigatorObserver {
  final List<Route<dynamic>> pushed = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushed.add(route);
    super.didPush(route, previousRoute);
  }
}

GamificationProfile _profile() => GamificationProfile(
  userId: 'u1',
  xp: 500,
  crownRank: 'wood_novice',
  selectedBadges: const [],
  streakFreezes: 0,
  createdAt: _now,
  updatedAt: _now,
);

UserAchievement _earned(String id) => UserAchievement(
  id: 'earned-$id',
  userId: 'u1',
  achievementId: id,
  tier: 1,
  unlockedAt: _now,
  createdAt: _now,
  updatedAt: _now,
);

Widget _harness({
  required List<String> earned,
  String? titleId,
  _RouteSpy? spy,
  double width = 360,
}) => MaterialApp(
  locale: const Locale('tr'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  navigatorObservers: [?spy],
  home: Scaffold(
    body: Center(
      child: SizedBox(
        width: width,
        child: SingleChildScrollView(
          child: AchievementShowcase(
            gamification: _profile(),
            userAchievements: [for (final id in earned) _earned(id)],
            titleAchievementId: titleId,
            isSelf: true,
            showCatalog: false,
            onSelectTitle: (_) async {},
          ),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('seçici alt sayfa DEĞİL, butona çapalanan menüdür', (
    tester,
  ) async {
    final spy = _RouteSpy();
    await tester.pumpWidget(
      _harness(
        earned: const ['marathon_total', 'secret_last_second'],
        titleId: 'marathon_total',
        spy: spy,
      ),
    );
    await tester.pumpAndSettle();
    spy.pushed.clear();

    await tester.tap(find.byKey(const ValueKey('choose-profile-title')));
    await tester.pumpAndSettle();

    // 🔴 Sahip kararının otomatik bekçisi.
    expect(
      spy.pushed.whereType<ModalBottomSheetRoute<dynamic>>(),
      isEmpty,
      reason: 'ünvan seçici alt sayfa olmayacak (sahip kararı, WP-479)',
    );
    expect(find.byType(BottomSheet), findsNothing);

    // Menü gerçekten açıldı ve seçenekleri taşıyor.
    expect(find.byType(PopupMenuItem<String>), findsWidgets);
    expect(
      find.byKey(const ValueKey('profile-title-marathon_total')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('remove-profile-title')),
      findsOneWidget,
    );
  });

  testWidgets('menü basılan butona çapalanır, ekranın köşesine değil', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(earned: const ['marathon_total'], titleId: 'marathon_total'),
    );
    await tester.pumpAndSettle();

    final button = tester.getRect(
      find.byKey(const ValueKey('choose-profile-title')),
    );
    await tester.tap(find.byKey(const ValueKey('choose-profile-title')));
    await tester.pumpAndSettle();

    final menu = tester.getRect(
      find.byKey(const ValueKey('profile-title-marathon_total')),
    );
    // `showAnchoredMenu` menüyü çapanın kutusuna göre konumlandırır; çapa
    // düşerse menü ekranın köşesine kaçar. Ölçüt: menü merkezinin butona olan
    // uzaklığı, ekran köşesine olan uzaklığından belirgin biçimde küçük.
    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    final toButton = (menu.center - button.center).distance;
    final toCorner = (menu.center - Offset.zero).distance;
    expect(
      toButton,
      lessThan(toCorner),
      reason:
          'menü butona değil köşeye çapalanmış görünüyor '
          '(butona $toButton, köşeye $toCorner, ekran $screen)',
    );
    expect(toButton, lessThan(250));
  });

  testWidgets('ünvan uzasa da buton yer değiştirmez', (tester) async {
    await tester.pumpWidget(
      _harness(earned: const ['marathon_total'], titleId: null),
    );
    await tester.pumpAndSettle();
    final withoutTitle = tester.getRect(
      find.byKey(const ValueKey('choose-profile-title')),
    );

    // Sözlükteki en uzun TR ünvan adı ("Son Saniye Kurtarıcısı").
    await tester.pumpWidget(
      _harness(
        earned: const ['secret_last_second'],
        titleId: 'secret_last_second',
      ),
    );
    await tester.pumpAndSettle();
    final withLongTitle = tester.getRect(
      find.byKey(const ValueKey('choose-profile-title')),
    );

    expect(
      withLongTitle,
      withoutTitle,
      reason: 'buton ünvan uzunluğuna göre kaymamalı (Wrap regresyonu)',
    );
  });

  testWidgets('dar ekranda tek satır kalır, taşma yok', (tester) async {
    await tester.pumpWidget(
      _harness(
        earned: const ['secret_last_second'],
        titleId: 'secret_last_second',
        width: 300,
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final chip = tester.getRect(
      find.byKey(const ValueKey('profile-title-chip')),
    );
    final button = tester.getRect(
      find.byKey(const ValueKey('choose-profile-title')),
    );
    // Aynı satırdalar: dikey aralıkları kesişiyor.
    expect(chip.top, lessThan(button.bottom));
    expect(button.top, lessThan(chip.bottom));
  });
}
