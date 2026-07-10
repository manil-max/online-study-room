import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:online_study_room/data/models/presence.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/providers/group_providers.dart';
import 'package:online_study_room/data/providers/presence_providers.dart';
import 'package:online_study_room/data/providers/study_providers.dart';
import 'package:online_study_room/features/classroom/widgets/campfire_scene.dart';

Profile _profile(String id, String name) => Profile(
      id: id,
      displayName: name,
      createdAt: DateTime(2026, 1, 1),
    );

Widget _harness({
  required List<Profile> members,
  required List<Presence> presence,
  required Map<String, int> today,
}) {
  return ProviderScope(
    overrides: [
      groupMembersProvider.overrideWith((ref) => Stream.value(members)),
      groupPresenceProvider.overrideWith((ref) => Stream.value(presence)),
      groupTodaySecondsProvider.overrideWithValue(today),
    ],
    child: const MaterialApp(
      home: Scaffold(
        body: SizedBox(width: 400, child: CampfireScene()),
      ),
    ),
  );
}

void main() {
  testWidgets('CampfireScene çalışan + dinlenen üyelerle taşmadan render olur',
      (tester) async {
    final started = DateTime.now().subtract(const Duration(minutes: 5));
    await tester.pumpWidget(_harness(
      members: [
        _profile('u1', 'Ada'),
        _profile('u2', 'Bora'),
        _profile('u3', 'Cem'),
      ],
      presence: [
        Presence(
            userId: 'u1',
            status: PresenceStatus.studying,
            todaySeconds: 3600,
            startedAt: started),
        Presence(
            userId: 'u2',
            status: PresenceStatus.onBreak,
            todaySeconds: 1200),
        Presence(
            userId: 'u3',
            status: PresenceStatus.offline,
            todaySeconds: 0),
      ],
      today: {'u1': 3600, 'u2': 1200, 'u3': 0},
    ));
    // Stream değerinin dağıtılması + ilk animasyon karesi.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(CampfireScene), findsOneWidget);
    // 1 kişi çalışıyor rozeti.
    expect(find.text('1 çalışıyor'), findsOneWidget);
    // Üye adları sahnede.
    expect(find.text('Ada'), findsOneWidget);
    expect(find.text('Bora'), findsOneWidget);
    expect(find.text('Cem'), findsOneWidget);

    // Çalışan üyenin SecondTicker timer'ını temizlemek için ağacı kaldır.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('CampfireScene kimse çalışmıyorken sönük ateş ipucunu gösterir',
      (tester) async {
    await tester.pumpWidget(_harness(
      members: [_profile('u1', 'Ada')],
      presence: [
        Presence(
            userId: 'u1', status: PresenceStatus.offline, todaySeconds: 0),
      ],
      today: {'u1': 0},
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('kimse yok'), findsOneWidget);
    expect(
      find.textContaining('Ateş sönük'),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox());
  });
}
