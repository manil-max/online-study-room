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
  testWidgets('ClassroomScreen renders correctly and checks order', (tester) async {
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
      authStateProvider.overrideWith((ref) => Stream.value(Profile(id: 'u1', displayName: 'Ben', createdAt: DateTime.now()))),
      userSessionsProvider.overrideWith((ref) => Stream.value([])),
    ];

    tester.view.physicalSize = const Size(1080, 1920); // 360x640 logical
    tester.view.devicePixelRatio = 3.0;

    final details = <FlutterErrorDetails>[];
    final prev = FlutterError.onError;
    FlutterError.onError = details.add;

    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: const MaterialApp(
          home: ClassroomScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    FlutterError.onError = prev;
    expect(details.map((d) => d.exceptionAsString()), isEmpty);

    expect(find.text('Test Group'), findsOneWidget);
    expect(find.text('TEST12'), findsOneWidget);
    expect(find.byTooltip('Sohbet'), findsOneWidget);
    expect(find.byTooltip('Ayarlar'), findsOneWidget);
    expect(find.byTooltip('Kopyala'), findsOneWidget);

    // Verify order
    final goalY = tester.getTopLeft(find.byType(GroupGoalCard)).dy;
    final campfireY = tester.getTopLeft(find.byType(CampfireScene)).dy;
    final trendY = tester.getTopLeft(find.byType(GroupTrendCard)).dy;

    expect(goalY < campfireY, isTrue);
    expect(campfireY < trendY, isTrue);

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
