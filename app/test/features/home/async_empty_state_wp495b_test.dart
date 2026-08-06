// WP-495B: WP-495'in tarama çıktısındaki (docs/qa/V58-ASYNC-EMPTY-AUDIT.md §5)
// "yükleniyor = veri yok" yerlerinin kalanı.
//
// WP-495 yalnız `active_members_card`ı sahiplenmişti; aynı dal grup gerektiren
// **her** kartta duruyordu, yani sahibin gördüğü "Grup Oluştur" flaşı cihazda
// sürecekti. Burada üç kart daha, sınıf istatistikleri sekmesi ve engellenen
// kullanıcı yüzeyleri ölçülür.
//
// Engelli kümesi ayrı bir ağ çağrısıdır (`blockedUserIdsProvider`, FutureProvider).
// Küme gelmeden liste çizilirse engellenen kişi bir kare **gerçek adıyla**
// görünür — kozmetik değil, gizlilik.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/chat_message.dart';
import 'package:online_study_room/data/models/presence.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/models/study_group.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/chat_providers.dart';
import 'package:online_study_room/data/providers/group_providers.dart';
import 'package:online_study_room/data/providers/moderation_providers.dart';
import 'package:online_study_room/data/providers/presence_providers.dart';
import 'package:online_study_room/data/providers/study_providers.dart';
import 'package:online_study_room/features/classroom/widgets/class_chat_card.dart';
import 'package:online_study_room/features/home/widgets/group_card_shell.dart';
import 'package:online_study_room/features/home/widgets/group_goal_card.dart';
import 'package:online_study_room/features/home/widgets/group_trend_card.dart';
import 'package:online_study_room/features/home/widgets/leaderboard_card.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

final _me = Profile(
  id: 'me-1',
  displayName: 'Sahip',
  createdAt: DateTime(2026, 1, 1),
);
final _blocked = Profile(
  id: 'blocked-1',
  displayName: 'Gercek Ad',
  createdAt: DateTime(2026, 1, 1),
);

final _group = StudyGroup(
  id: 'g-1',
  name: 'Odak Grubu',
  inviteCode: 'ABC123',
  createdBy: _me.id,
  createdAt: DateTime(2026, 1, 1),
);

/// Hiç tamamlanmayan gelecek: cihazda ağ turunun beklendiği kare.
Future<T> _pending<T>() => Completer<T>().future;

Future<AppLocalizations> _l10n() =>
    AppLocalizations.delegate.load(const Locale('tr'));

/// `Override` tipi flutter_riverpod barrel'ından dışa verilmiyor; kapsayıcı
/// yalnız MaterialApp'i kurar, `ProviderScope`u her test kendi yazar.
Widget _wrap(Widget home) => MaterialApp(
  locale: const Locale('tr'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: home),
);

/// Grup gerektiren kartların ortak yüzeyi; her biri aynı kapıdan geçer.
final _groupCards = <String, Widget>{
  'sıralama': const LeaderboardCard(),
  'grup hedefi': const GroupGoalCard(),
  'grup trendi': const GroupTrendCard(),
};

Future<void> _pumpGroupCard(
  WidgetTester tester,
  Widget card, {
  required AsyncValue<StudyGroup?> group,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authStateProvider.overrideWith((ref) => Stream.value(_me)),
        userGroupProvider.overrideWithValue(group),
        groupDailyStatsProvider.overrideWith((ref) => Stream.value(const [])),
        groupMembersProvider.overrideWith((ref) => Stream.value([_me])),
        groupPresenceProvider.overrideWith(
          (ref) => Stream.value(const <Presence>[]),
        ),
      ],
      child: _wrap(SizedBox(width: 340, height: 280, child: card)),
    ),
  );
  await tester.pump();
}

void main() {
  group('grup kartları — yükleniyorken davet çizilmez', () {
    for (final entry in _groupCards.entries) {
      testWidgets('${entry.key}: yükleniyorken "Grup Oluştur" yok', (
        tester,
      ) async {
        await _pumpGroupCard(
          tester,
          entry.value,
          group: const AsyncValue.loading(),
        );
        final l10n = await _l10n();

        // Eski kod burada daveti çiziyordu: `.value == null` → GroupCardShell.
        expect(find.text(l10n.homeGrupOlustur), findsNothing);
        expect(find.byKey(kGroupCardSkeletonKey), findsOneWidget);
      });

      testWidgets('${entry.key}: gerçekten grubu yoksa davet görünür', (
        tester,
      ) async {
        await _pumpGroupCard(
          tester,
          entry.value,
          group: const AsyncValue.data(null),
        );
        final l10n = await _l10n();

        expect(find.text(l10n.homeGrupOlustur), findsOneWidget);
        expect(find.byKey(kGroupCardSkeletonKey), findsNothing);
      });
    }

    testWidgets('grup akışı hata verirse boş durum değil hata metni', (
      tester,
    ) async {
      await _pumpGroupCard(
        tester,
        const LeaderboardCard(),
        group: AsyncValue.error('ağ yok', StackTrace.empty),
      );
      final l10n = await _l10n();

      expect(find.text(l10n.homeGrupBilgisiYuklenemedi), findsOneWidget);
      // Tuzak: hatayı "yükleniyor" sayıp sonsuz iskelet göstermek.
      expect(find.byKey(kGroupCardSkeletonKey), findsNothing);
      expect(find.text(l10n.homeGrupOlustur), findsNothing);
    });
  });

  // 🔴 Kamp ateşi ve sınıf sıralaması bilerek burada YOK. Oralarda engelli
  // kümesinin geç gelmesi gizlilik açığı değildir: sunucu `group_member_directory`
  // satırı döndürürken engellenen üyenin adını/avatarını/hayvanını zaten boşaltır
  // (`0095`/`0115`), yani istemciye gerçek ad hiç ulaşmaz. Sahneyi o ek ağ
  // çağrısına bağlamak ana ekranın kritik yoluna spinner ekliyor ve 27 mevcut
  // testi kırıyordu. Sözleşmenin kendisi `block_visibility_wp413_test` ve
  // `supabase/tests/024`te ölçülüyor. Sohbet farklı: `0095` sohbeti kapsamaz,
  // süzgeç yalnız istemcidedir — bu yüzden aşağıdaki iki test var.

  testWidgets('sohbet: engelli kümesi gelmeden mesaj çizilmez', (tester) async {
    final messages = [
      ChatMessage(
        id: 'm-1',
        groupId: _group.id,
        userId: _blocked.id,
        authorDisplayName: _blocked.displayName,
        body: 'engellenen mesaj',
        createdAt: DateTime(2026, 1, 1, 10),
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(_me)),
          blockedUserIdsProvider.overrideWith((ref) => _pending<Set<String>>()),
          classMessagesProvider(
            _group.id,
          ).overrideWith((ref) => Stream.value(messages)),
        ],
        child: _wrap(ClassChatCard(group: _group)),
      ),
    );
    await tester.pump();

    expect(find.text('engellenen mesaj'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('sohbet: küme gelince engellenen mesaj gizli, diğeri görünür', (
    tester,
  ) async {
    final messages = [
      ChatMessage(
        id: 'm-1',
        groupId: _group.id,
        userId: _blocked.id,
        authorDisplayName: _blocked.displayName,
        body: 'engellenen mesaj',
        createdAt: DateTime(2026, 1, 1, 10),
      ),
      ChatMessage(
        id: 'm-2',
        groupId: _group.id,
        userId: _me.id,
        authorDisplayName: _me.displayName,
        body: 'benim mesajim',
        createdAt: DateTime(2026, 1, 1, 11),
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(_me)),
          blockedUserIdsProvider.overrideWith((ref) async => {_blocked.id}),
          classMessagesProvider(
            _group.id,
          ).overrideWith((ref) => Stream.value(messages)),
        ],
        child: _wrap(ClassChatCard(group: _group)),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('engellenen mesaj'), findsNothing);
    expect(find.text('benim mesajim'), findsOneWidget);
  });
}
