import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/daily_stat.dart';
import 'package:online_study_room/data/models/presence.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/group_providers.dart';
import 'package:online_study_room/data/providers/presence_providers.dart';
import 'package:online_study_room/data/providers/study_providers.dart';
import 'package:online_study_room/features/classroom/widgets/campfire_scene.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

final _now = DateTime(2026, 8, 13, 16);
final _viewer = Profile(
  id: 'viewer',
  displayName: 'Ben',
  createdAt: DateTime(2026),
);

Profile _member(int index) => Profile(
  id: 'member-$index',
  displayName: 'Uzun Kampçı Adı $index',
  createdAt: DateTime(2026),
  dailyGoalMinutes: 60,
);

Future<void> _pumpScene(
  WidgetTester tester, {
  required double width,
  required List<Profile> members,
  required List<Presence> presences,
}) async {
  tester.view.physicalSize = Size(width, 720);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authStateProvider.overrideWith((ref) => Stream.value(_viewer)),
        userGroupProvider.overrideWithValue(const AsyncData(null)),
        groupMembersProvider.overrideWith((ref) => Stream.value(members)),
        groupPresenceProvider.overrideWith((ref) => Stream.value(presences)),
        groupTodaySecondsProvider.overrideWithValue({
          for (final member in members) member.id: 25 * 60,
        }),
        groupDailyStatsProvider.overrideWith(
          (ref) => Stream.value([
            for (final member in members)
              DailyStat(
                userId: member.id,
                day: DateTime(2026, 8, 13),
                seconds: 25 * 60,
              ),
          ]),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: CampfireScene(clock: () => _now)),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  addTearDown(() async => tester.pumpWidget(const SizedBox()));
}

void main() {
  for (final width in [320.0, 360.0, 412.0]) {
    testWidgets('isimler $width dp ekranda kendi hayvanıyla merkezlenir', (
      tester,
    ) async {
      final members = [for (var index = 0; index < 4; index++) _member(index)];
      await _pumpScene(
        tester,
        width: width,
        members: members,
        presences: [
          for (final member in members)
            Presence(
              userId: member.id,
              status: PresenceStatus.offline,
              todaySeconds: 0,
            ),
        ],
      );

      final scene = tester.getRect(find.byType(CampfireScene));
      final labels = <Rect>[];
      for (final member in members) {
        final body = tester.getRect(find.byKey(ValueKey('b-${member.id}')));
        final label = tester.getRect(find.byKey(ValueKey('l-${member.id}')));
        expect(label.center.dx, closeTo(body.center.dx, 0.01));
        expect(scene.contains(label.topLeft), isTrue);
        expect(scene.contains(label.bottomRight), isTrue);
        labels.add(label);
      }
      for (var first = 0; first < labels.length; first++) {
        for (var second = first + 1; second < labels.length; second++) {
          expect(labels[first].overlaps(labels[second]), isFalse);
        }
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('offline durumu üstte değil kimlik bloğunun altındadır', (
    tester,
  ) async {
    final peer = _member(1);
    await _pumpScene(
      tester,
      width: 360,
      members: [peer],
      presences: [
        Presence(
          userId: peer.id,
          status: PresenceStatus.offline,
          todaySeconds: 0,
        ),
      ],
    );
    await tester.tap(find.byKey(ValueKey('b-${peer.id}')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final identityHeader = tester.getRect(
      find.byKey(const Key('camper-sheet-identity-header')),
    );
    final status = tester.getRect(find.byKey(const Key('camper-sheet-status')));
    expect(status.top, greaterThanOrEqualTo(identityHeader.bottom));
    expect(find.byKey(const Key('camper-sheet-live-elapsed')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('çalışan üyede kimlik altında canlı oturum süresi vardır', (
    tester,
  ) async {
    final peer = _member(2);
    await _pumpScene(
      tester,
      width: 360,
      members: [peer],
      presences: [
        Presence(
          userId: peer.id,
          status: PresenceStatus.studying,
          todaySeconds: 0,
          startedAt: _now.subtract(const Duration(minutes: 5)),
        ),
      ],
    );
    await tester.tap(find.byKey(ValueKey('b-${peer.id}')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final identityHeader = tester.getRect(
      find.byKey(const Key('camper-sheet-identity-header')),
    );
    final elapsed = tester.getRect(
      find.byKey(const Key('camper-sheet-live-elapsed')),
    );
    expect(elapsed.top, greaterThanOrEqualTo(identityHeader.bottom));
    expect(find.text('00:05:00'), findsWidgets);
    expect(find.byKey(const Key('camper-sheet-status')), findsNothing);
    expect(find.byKey(const Key('camper-stat-session')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
