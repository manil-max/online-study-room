// WP-494 (V58-N01 / rapor T03): "gruplar kısmında sürekli ekran yenilenip
// geliyordu."
//
// Kök neden: `_MembersCard` üye akışını `StreamBuilder`a **`build()` içinde**
// veriyordu (`stream: repo.watchMembers(group.id)`). Aynı `build()` presence'ı
// da izlediği için her presence emisyonu yeni bir akış nesnesi üretiyor,
// `StreamBuilder` eski aboneliği kapatıp yenisini açıyor, taze akış henüz veri
// vermediği için liste bir kare spinner'a düşüyordu. Supabase tarafında bu
// yeni bir realtime aboneliği + her emisyonda bir RPC demektir.
//
// Ölçüt "daha az yenileniyor" değil: **abonelik sayısı**. Depo çağrısı sayılır
// ve ekran presence akışıyla tekrar tekrar çizdirilir.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/presence.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/models/study_group.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/group_providers.dart';
import 'package:online_study_room/data/providers/presence_providers.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_group_repository.dart';
import 'package:online_study_room/features/classroom/widgets/class_detail_screen.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

/// `watchMembers` çağrılarını sayar: her çağrı gerçek uygulamada bir Supabase
/// realtime aboneliğine karşılık gelir.
///
/// Emisyonlar bilerek geciktirilir. Bellek-içi depo veriyi anında verdiği için
/// taze bir abonelik testte hiç "veri yok" karesi göstermez ve spinner iddiası
/// sessizce her iki kodda da yeşil kalırdı; gerçek Supabase akışında ise yeni
/// abonelik ilk veriyi ağ turundan sonra verir. Gecikme o turu temsil eder.
class _CountingGroupRepository extends InMemoryGroupRepository {
  int watchMembersCalls = 0;

  @override
  Stream<List<Profile>> watchMembers(String groupId) {
    watchMembersCalls++;
    return super.watchMembers(groupId).asyncMap((members) async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return members;
    });
  }
}

Profile _profile(String id, String name) =>
    Profile(id: id, displayName: name, createdAt: DateTime(2026, 1, 1));

final _owner = _profile('owner-1', 'Sahip');
final _peer = _profile('peer-1', 'Ada');

class _Harness {
  _Harness(this.repo, this.group, this.presence);

  final _CountingGroupRepository repo;
  final StudyGroup group;
  final StreamController<List<Presence>> presence;
}

Future<_Harness> _pumpDetail(WidgetTester tester, {int screens = 1}) async {
  final repo = _CountingGroupRepository();
  final group = await repo.createGroup(name: 'Odak Grubu', creator: _owner);
  await repo.joinGroup(inviteCode: group.inviteCode, member: _peer);

  final presence = StreamController<List<Presence>>.broadcast();
  addTearDown(presence.close);

  // Üye kartı `ListView`in aşağısında; kısa yüzeyde hiç kurulmaz ve ölçüm
  // sessizce boşa çıkar. Yüzey iki ekranı da tamamen gösterecek kadar uzun.
  tester.view.physicalSize = const Size(1000, 5000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        groupRepositoryProvider.overrideWithValue(repo),
        authStateProvider.overrideWith((ref) => Stream.value(_owner)),
        groupPresenceProvider.overrideWith((ref) => presence.stream),
        // Ölçüm yalnız detay ekranının akışını saysın: aktif grup provider'ı
        // da aynı depoyu çağırır, o bu kartın konusu değil.
        groupMembersProvider.overrideWith(
          (ref) => Stream.value([_owner, _peer]),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: screens == 1
            ? ClassDetailScreen(group: group)
            : Column(
                children: [
                  for (var i = 0; i < screens; i++)
                    Expanded(child: ClassDetailScreen(group: group)),
                ],
              ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return _Harness(repo, group, presence);
}

/// Cihazdaki tetikleyicinin aynısı: presence emisyonu → `_MembersCard` yeniden
/// çizilir.
Future<void> _emitPresence(WidgetTester tester, _Harness h, int times) async {
  for (var i = 0; i < times; i++) {
    h.presence.add([
      Presence(
        userId: _peer.id,
        groupId: h.group.id,
        status: i.isEven ? PresenceStatus.studying : PresenceStatus.offline,
        todaySeconds: i * 60,
      ),
    ]);
    await tester.pump();
  }
}

void main() {
  testWidgets('ekran 10 kez yeniden çizilse de abonelik 1 kalır', (
    tester,
  ) async {
    final h = await _pumpDetail(tester);
    expect(h.repo.watchMembersCalls, 1, reason: 'ilk yükleme tek akış açmalı');

    await _emitPresence(tester, h, 10);

    // Eski kodda bu sayı 11 olurdu: her yeniden çizim yeni bir abonelik.
    expect(
      h.repo.watchMembersCalls,
      1,
      reason: 'yeniden çizim başına yeni abonelik açılıyor',
    );
  });

  testWidgets('presence değişiminde liste spinner göstermeden güncellenir', (
    tester,
  ) async {
    final h = await _pumpDetail(tester);
    expect(find.text(_peer.displayName), findsOneWidget);

    await _emitPresence(tester, h, 5);

    // Sahibin gördüğü belirti: liste her yenilemede kaybolup spinner'a düşüyor.
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text(_peer.displayName), findsOneWidget);
    expect(find.text(_owner.displayName), findsOneWidget);
  });

  testWidgets('aynı grubu iki ekran izlerse abonelik yine tek kalır', (
    tester,
  ) async {
    // Provider ailesi `groupId` ile anahtarlanır: ikinci ekran var olan akışa
    // bağlanır, ikinci kanal açmaz (kart edge-case'i).
    final h = await _pumpDetail(tester, screens: 2);

    expect(h.repo.watchMembersCalls, 1);
  });
}
