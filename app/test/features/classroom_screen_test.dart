import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/study_group.dart';
import 'package:online_study_room/data/providers/group_providers.dart';
import 'package:online_study_room/data/providers/presence_providers.dart';
import 'package:online_study_room/data/providers/study_providers.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/features/classroom/classroom_screen.dart';
import 'package:online_study_room/features/classroom/widgets/campfire_scene.dart';
import 'package:online_study_room/features/home/widgets/group_goal_card.dart';
import 'package:online_study_room/features/home/widgets/group_trend_card.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('ClassroomScreen renders correctly and checks order', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final group = StudyGroup(
      id: 'g1',
      name: 'Test Group',
      inviteCode: 'TEST12',
      createdBy: 'u1',
      createdAt: DateTime.now(),
      dailyGoalMinutes: 120,
    );

    var overrides = [
      sharedPreferencesProvider.overrideWithValue(prefs),
      userGroupProvider.overrideWithValue(AsyncData(group)),
      groupMembersProvider.overrideWith((ref) => Stream.value([])),
      groupPresenceProvider.overrideWith((ref) => Stream.value([])),
      groupDailyStatsProvider.overrideWith((ref) => Stream.value([])),
      authStateProvider.overrideWith(
        (ref) => Stream.value(
          Profile(id: 'u1', displayName: 'Ben', createdAt: DateTime.now()),
        ),
      ),
      userSessionsProvider.overrideWith((ref) => Stream.value([])),
    ];

    // ClassroomScreen gövdesi lazy bir ListView; CampfireScene (360px) + GroupGoalCard
    // + GroupTrendCard sırayla dizili. 640px viewport'ta trend kartı ekran dışında kalıp
    // build edilmez; sıra kontrolü (getTopLeft) için üçünü de kurduracak kadar yüksek tut.
    tester.view.physicalSize = const Size(1080, 6000); // 360x2000 logical
    tester.view.devicePixelRatio = 3.0;

    final details = <FlutterErrorDetails>[];
    final prev = FlutterError.onError;
    FlutterError.onError = details.add;

    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: const MaterialApp(
          locale: Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ClassroomScreen(),
        ),
      ),
    );
    // CampfireScene sonsuz bir alev animasyonu (AnimationController.repeat) barındırır;
    // pumpAndSettle bu yüzden asla oturmaz (10 dk timeout). Ağacı kurup akışları
    // (Stream.value) çözmek ve AnimatedPositioned yerleşimini (560 ms) tamamlamak için
    // sınırlı pump yeterli.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    FlutterError.onError = prev;
    expect(details.map((d) => d.exceptionAsString()), isEmpty);

    // Grup adı hem kompakt başlıkta hem GroupGoalCard içinde görünür (meşru → 1+).
    expect(find.text('Test Group'), findsWidgets);
    expect(find.byTooltip('Sohbet'), findsOneWidget);
    expect(find.byTooltip('Ayarlar'), findsOneWidget);

    // Davet kodu artık kamp ateşinin üstünde değil; alttaki açılır "Grup bilgileri"
    // panelinde. Kapalıyken kod/kopyala görünmez.
    expect(find.text('Grup bilgileri'), findsOneWidget);
    expect(find.text('TEST12'), findsNothing);
    expect(find.byTooltip('Kopyala'), findsNothing);

    // Sıra (§8.3 Gruplar): kamp ateşi EN ÜSTTE → grup hedefi → trend.
    final campfireY = tester.getTopLeft(find.byType(CampfireScene)).dy;
    final goalY = tester.getTopLeft(find.byType(GroupGoalCard)).dy;
    final trendY = tester.getTopLeft(find.byType(GroupTrendCard)).dy;

    expect(
      campfireY < goalY,
      isTrue,
      reason: 'kamp ateşi grup hedefinin ÜSTÜNDE olmalı (kullanıcı isteği)',
    );
    expect(
      goalY < trendY,
      isTrue,
      reason: 'grup hedefi trendin üstünde olmalı',
    );

    // Yönetim paneli en altta (trendin altında).
    final mgmtY = tester.getTopLeft(find.text('Grup bilgileri')).dy;
    expect(trendY < mgmtY, isTrue, reason: 'yönetim paneli en altta olmalı');

    // Açılır panel gerçekten çalışır: dokununca davet kodu + kopyala görünür.
    // (CampfireScene sonsuz alev animasyonu barındırdığı için pumpAndSettle
    // yerine ExpansionTile'ın 200 ms açılışını sınırlı pump ile bekle.)
    await tester.tap(find.text('Grup bilgileri'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('TEST12'), findsOneWidget);
    expect(find.byTooltip('Kopyala'), findsOneWidget);

    // Sonsuz animasyon timer'ını temizle.
    await tester.pumpWidget(const SizedBox());
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
