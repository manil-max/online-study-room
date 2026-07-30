import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/models/study_group.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/group_providers.dart';
import 'package:online_study_room/data/repositories/group_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_group_repository.dart';
import 'package:online_study_room/features/classroom/widgets/class_detail_screen.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

/// Çağrıları sayan ve isteğe bağlı olarak askıda tutan repository.
class _CountingGroupRepository extends InMemoryGroupRepository {
  int leaveCalls = 0;
  final List<String> commandIds = [];
  Completer<void>? gate;

  @override
  Future<GroupLeaveOutcome> leaveGroup(
    String groupId,
    String userId, {
    required String commandId,
  }) async {
    leaveCalls++;
    commandIds.add(commandId);
    if (gate != null) await gate!.future;
    return super.leaveGroup(groupId, userId, commandId: commandId);
  }
}

void main() {
  late _CountingGroupRepository repo;
  late StudyGroup group;

  final member = Profile(
    id: 'member',
    displayName: 'Üye',
    createdAt: DateTime(2026, 1, 1),
  );

  Future<Widget> harness() async {
    repo = _CountingGroupRepository();
    group = await repo.createGroup(
      name: 'Odak Grubu',
      creator: Profile(
        id: 'owner',
        displayName: 'Sahip',
        createdAt: DateTime(2026, 1, 1),
      ),
    );
    await repo.joinGroup(inviteCode: group.inviteCode, member: member);

    return ProviderScope(
      overrides: [
        groupRepositoryProvider.overrideWithValue(repo),
        authStateProvider.overrideWith((ref) => Stream.value(member)),
      ],
      child: MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ClassDetailScreen(group: group),
      ),
    );
  }

  testWidgets('WP-445: 20 hızlı tap tek çıkış komutu üretir', (tester) async {
    await tester.pumpWidget(await harness());
    await tester.pumpAndSettle();

    final tile = find.byKey(const ValueKey('leave-group-action'));
    await tester.scrollUntilVisible(
      tile,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tile, findsOneWidget);

    // İstek askıda kalsın: meşgul koruması olmasaydı her tap yeni çağrı olurdu.
    repo.gate = Completer<void>();

    await tester.tap(tile);
    await tester.pumpAndSettle();

    // Onay diyaloğu
    await tester.tap(find.text('Çık').last);
    await tester.pump();

    for (var i = 0; i < 20; i++) {
      await tester.tap(tile, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 5));
    }

    expect(repo.leaveCalls, 1);

    repo.gate!.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('WP-445: retry aynı komut anahtarını yeniden kullanır', (
    tester,
  ) async {
    await tester.pumpWidget(await harness());
    await tester.pumpAndSettle();

    final tile = find.byKey(const ValueKey('leave-group-action'));
    await tester.scrollUntilVisible(
      tile,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(tile);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Çık').last);
    await tester.pumpAndSettle();

    // İlk çağrı başarıyla tamamlandı; aynı hareketin komutu tek anahtar üretti.
    expect(repo.leaveCalls, 1);
    expect(repo.commandIds.toSet().length, 1);
  });
}
