// WP-617 — DENETIM-gruplar / KANAMA-2: "eylem ag hatasinda TAMAMEN SESSIZ".
//
// Uc yol da ayni sekilde kirilmisti: ekran YALNIZ kendi alan hatasini
// yakaliyordu (`ChatException` / `NudgeException`), depo ise yalniz
// `PostgrestException`i o ture sariyordu. Yani ag kopunca hata **sarilmadan**
// yukari cikiyor, hicbir `catch` onu tutmuyordu:
//
//   sohbet   `class_chat_card.dart`      → mesaj gitmiyor, uyari da yok
//   durtme   `nudge_action.dart`         → gosterge kapaniyor, hicbir sey yok
//   susturma `class_detail_screen.dart`  → simge eskisi gibi, hicbir sey yok
//
// 🔴 Bu testin can alici noktasi sahte deponun HANGI hatayi firlattigi.
// `ChatException`/`NudgeException` firlatan bir test bu kusuru **olcemez** —
// tam da bu yuzden uc surumdur gozden kacti. Buradaki depolar bilerek alan
// disi, sarilmamis bir ag hatasi (`SocketException`) firlatir.
//
// Iddia her yerde iki yonlu: hata varken uyari CIKMALI, basarida CIKMAMALI.
// Tek yonlu birakilsaydi "kosulsuz SnackBar goster" sabotaji testi gecerdi.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/nudge.dart';
import 'package:online_study_room/data/models/presence.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/models/study_group.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/chat_providers.dart';
import 'package:online_study_room/data/providers/group_providers.dart';
import 'package:online_study_room/data/providers/moderation_providers.dart';
import 'package:online_study_room/data/providers/nudge_providers.dart';
import 'package:online_study_room/data/providers/presence_providers.dart';
import 'package:online_study_room/data/providers/study_providers.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_chat_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_group_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_moderation_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_nudge_repository.dart';
import 'package:online_study_room/features/classroom/widgets/campfire_scene.dart';
import 'package:online_study_room/features/classroom/widgets/class_chat_card.dart';
import 'package:online_study_room/features/classroom/widgets/class_detail_screen.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

/// `core/l10n/group_error_text.dart:36-37` alan disi hatayi bu cumleye cevirir.
/// Ayni sebep her ekranda ayni cumleyi uretmek zorunda.
const _kNetworkText = 'Sunucuya ulaşılamadı. Bağlantını kontrol edip tekrar dene.';

/// Sarilmamis ag hatasi: Supabase deposu bunu `PostgrestException` sanmaz,
/// yani `on ChatException` / `on NudgeException` bloklari GORMEZ.
const _kNetworkFailure = SocketException('baglanti koptu');

final _me = Profile(
  id: 'me-1',
  displayName: 'Ben',
  createdAt: DateTime(2026, 1, 1),
);
final _peer = Profile(
  id: 'peer-1',
  displayName: 'Komsu',
  createdAt: DateTime(2026, 1, 1),
);

final _group = StudyGroup(
  id: 'g1',
  name: 'Odak Grubu',
  inviteCode: 'KAMP42',
  createdBy: _me.id,
  createdAt: DateTime(2026, 1, 1),
);

class _OfflineChatRepository extends InMemoryChatRepository {
  int sendAttempts = 0;

  @override
  Future<void> sendMessage({
    required String groupId,
    required Profile sender,
    required String text,
  }) async {
    sendAttempts += 1;
    await Future<void>.delayed(const Duration(milliseconds: 10));
    throw _kNetworkFailure;
  }
}

class _OfflineNudgeRepository extends InMemoryNudgeRepository {
  @override
  Future<Nudge> sendNudge({
    required String groupId,
    required Profile sender,
    required Profile recipient,
    String? message,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 10));
    throw _kNetworkFailure;
  }

  @override
  Future<void> muteNudgesFrom(String userId) async {
    await Future<void>.delayed(const Duration(milliseconds: 10));
    throw _kNetworkFailure;
  }
}

Widget _wrap(Widget child, List<Override> overrides) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(
    locale: const Locale('tr'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  ),
);

// --------------------------------------------------------------------- sohbet

Future<void> _pumpChat(WidgetTester tester, InMemoryChatRepository repo) async {
  await tester.pumpWidget(
    _wrap(ClassChatCard(group: _group), [
      authStateProvider.overrideWith((ref) => Stream.value(_me)),
      classMessagesProvider(_group.id).overrideWith((ref) => Stream.value([])),
      chatRepositoryProvider.overrideWithValue(repo),
      // WP-538: engelli kume bilinmeden sohbet cizilmez (fail-closed).
      moderationRepositoryProvider.overrideWithValue(
        InMemoryModerationRepository(),
      ),
    ]),
  );
  await tester.pumpAndSettle();
}

Future<void> _typeAndSend(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField), 'merhaba');
  await tester.pump();
  await tester.tap(find.byTooltip('Gönder'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

// -------------------------------------------------------------- detay ekrani

Future<StudyGroup> _seedGroup(InMemoryGroupRepository repo) async {
  final group = await repo.createGroup(name: 'Odak Grubu', creator: _me);
  await repo.joinGroup(inviteCode: group.inviteCode, member: _peer);
  return group;
}

Future<void> _pumpDetail(
  WidgetTester tester, {
  required InMemoryNudgeRepository nudges,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final groups = InMemoryGroupRepository();
  final group = await _seedGroup(groups);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        groupRepositoryProvider.overrideWithValue(groups),
        nudgeRepositoryProvider.overrideWithValue(nudges),
        moderationRepositoryProvider.overrideWithValue(
          InMemoryModerationRepository(),
        ),
        authStateProvider.overrideWith((ref) => Stream.value(_me)),
      ],
      child: MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ClassDetailScreen(group: group),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    find.byKey(memberRowKey(_peer.id)),
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(find.byKey(memberRowKey(_peer.id)));
  await tester.pumpAndSettle();
}

Future<void> _tapAndSettleAction(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

// ------------------------------------------------------------- kamp atesi

Future<void> _pumpCampfire(WidgetTester tester) async {
  final fixedNow = DateTime(2026, 7, 26, 12);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        userGroupProvider.overrideWithValue(AsyncData(_group)),
        groupMembersProvider.overrideWith((ref) => Stream.value([_me, _peer])),
        groupPresenceProvider.overrideWith(
          (ref) => Stream.value([
            Presence(
              userId: _peer.id,
              groupId: _group.id,
              status: PresenceStatus.onBreak,
              todaySeconds: 0,
            ),
          ]),
        ),
        groupTodaySecondsProvider.overrideWithValue(const <String, int>{}),
        authStateProvider.overrideWith((ref) => Stream.value(_me)),
        nudgeRepositoryProvider.overrideWithValue(InMemoryNudgeRepository()),
        moderationRepositoryProvider.overrideWithValue(
          InMemoryModerationRepository(),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(width: 400, child: CampfireScene(clock: () => fixedNow)),
        ),
      ),
    ),
  );
  // Sahne sonsuz alev animasyonu barindirir: `pumpAndSettle` asla oturmaz.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  addTearDown(() async => tester.pumpWidget(const SizedBox()));
}

void main() {
  group('KANAMA-2 · sohbet gönderimi', () {
    testWidgets('ağ hatasında uyarı ÇIKAR', (tester) async {
      final repo = _OfflineChatRepository();
      await _pumpChat(tester, repo);

      await _typeAndSend(tester);

      expect(
        repo.sendAttempts,
        1,
        reason: 'gönderim hiç denenmediyse test yanlış şeyi ölçüyor',
      );
      expect(
        find.text(_kNetworkText),
        findsOneWidget,
        reason:
            'ağ kopunca kullanıcı mesajı yazıp Gönder\'e basıyor ve HİÇBİR ŞEY '
            'olmuyordu: ne mesaj gidiyor ne uyarı çıkıyor.',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('başarıda uyarı ÇIKMAZ (tek yönlü iddia kapanı)', (
      tester,
    ) async {
      await _pumpChat(tester, InMemoryChatRepository());

      await _typeAndSend(tester);

      expect(find.byType(SnackBar), findsNothing);
      expect(find.text(_kNetworkText), findsNothing);
    });
  });

  group('KANAMA-2 · dürtme', () {
    testWidgets('ağ hatasında uyarı ÇIKAR', (tester) async {
      await _pumpDetail(
        tester,
        nudges: _OfflineNudgeRepository()..currentUserId = _me.id,
      );

      await _tapAndSettleAction(
        tester,
        find.byKey(ValueKey('nudge-${_peer.id}')),
      );

      expect(find.text(_kNetworkText), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('başarıda hata değil onay çıkar', (tester) async {
      await _pumpDetail(
        tester,
        nudges: InMemoryNudgeRepository()..currentUserId = _me.id,
      );

      await _tapAndSettleAction(
        tester,
        find.byKey(ValueKey('nudge-${_peer.id}')),
      );

      expect(find.text('${_peer.displayName} dürtüldü'), findsOneWidget);
      expect(find.text(_kNetworkText), findsNothing);
    });
  });

  group('KANAMA-2 · dürtme susturma', () {
    testWidgets('ağ hatasında uyarı ÇIKAR', (tester) async {
      await _pumpDetail(
        tester,
        nudges: _OfflineNudgeRepository()..currentUserId = _me.id,
      );

      await _tapAndSettleAction(
        tester,
        find.byKey(ValueKey('mute-${_peer.id}')),
      );

      expect(find.text(_kNetworkText), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('başarıda hata değil onay çıkar', (tester) async {
      await _pumpDetail(
        tester,
        nudges: InMemoryNudgeRepository()..currentUserId = _me.id,
      );

      await _tapAndSettleAction(
        tester,
        find.byKey(ValueKey('mute-${_peer.id}')),
      );

      expect(find.text('Dürtmesi susturuldu.'), findsOneWidget);
      expect(find.text(_kNetworkText), findsNothing);
    });
  });

  // TEMIZLIK-3: sikayet/engelleme yolu yalniz sohbet mesajindaydi.
  group('bildir/engelle yolu sohbetin disinda da var', () {
    testWidgets('kamp ateşi kampçı sayfasında görünür iki eylem', (
      tester,
    ) async {
      await _pumpCampfire(tester);

      await tester.tap(find.byKey(ValueKey('b-${_peer.id}')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final report = find.byKey(const ValueKey('peer-safety-report'));
      await tester.ensureVisible(report);
      await tester.pump();

      expect(report, findsOneWidget);
      expect(find.byKey(const ValueKey('peer-safety-block')), findsOneWidget);
      // WP-446 kazanımı taşındı: iki eylemin kapsamı ekranda yazılı.
      expect(find.textContaining('yöneticilere gider'), findsOneWidget);
      expect(find.textContaining('Yalnız sizin için'), findsOneWidget);
    });

    testWidgets('kendi kampçı sayfasında GÖSTERİLMEZ', (tester) async {
      await _pumpCampfire(tester);

      await tester.tap(find.byKey(ValueKey('b-${_me.id}')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byKey(const ValueKey('peer-safety-report')), findsNothing);
      expect(find.byKey(const ValueKey('peer-safety-block')), findsNothing);
    });

    testWidgets('grup üye satırından da açılır', (tester) async {
      await _pumpDetail(
        tester,
        nudges: InMemoryNudgeRepository()..currentUserId = _me.id,
      );

      await tester.longPress(find.byKey(memberRowKey(_peer.id)));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('peer-safety-report')), findsOneWidget);
      expect(find.byKey(const ValueKey('peer-safety-block')), findsOneWidget);
    });
  });
}
