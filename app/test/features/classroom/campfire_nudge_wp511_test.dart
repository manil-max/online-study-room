// WP-511 (v59 saha geri bildirimi · madde 5 + E1): "kamp ateşinde birine
// tıklayınca açılan yerde dürtme olsun."
//
// İki şey aynı anda düzeltildi:
//
//  * **Madde 5** — kampçı alt sayfası salt okunurdu (isim, durum, süre). Dürtme
//    mantığı `class_detail_screen.dart` içinde `private`di; kopyalansaydı iki
//    uygulama ayrışır ve biri hata metinlerini / "kendine dürtme" kapısını /
//    sunucu odak korumasının (`0116`) istemci karşılığını kaçırırdı. Bu yüzden
//    mantık ortak bir bileşene çıkarıldı (`nudge_action.dart`) ve **iki yer de
//    onu kullanır** — bu dosyanın son grubu tam olarak bunu ölçer.
//  * **E1** — sahnede iki farklı "üyeye tıklayınca ne olsun" tasarımı vardı:
//    dıştaki `GestureDetector` `SocialProfileDialog` açıyordu, ama çocuğu
//    `HitTestBehavior.opaque` ile kendi handler'ını kurduğu için jest arenasında
//    hep içteki kazanıyordu — dıştaki **hiç çalışmıyordu**. Kanonik olan
//    çalışanıdır (kampçı alt sayfası); ölü olan kaldırıldı.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/nudge.dart';
import 'package:online_study_room/data/models/presence.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/models/study_group.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/group_providers.dart';
import 'package:online_study_room/data/providers/nudge_providers.dart';
import 'package:online_study_room/data/providers/presence_providers.dart';
import 'package:online_study_room/data/providers/study_providers.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_group_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_nudge_repository.dart';
import 'package:online_study_room/features/classroom/widgets/campfire_scene.dart';
import 'package:online_study_room/features/classroom/widgets/class_detail_screen.dart';
import 'package:online_study_room/features/classroom/widgets/nudge_action.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

const _studyingNotice =
    'Bu kişi şu an çalışıyor; odağını bölmemek için dürtme kapalı.';

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

/// Gönderim denemesini **sayan** repository — kapının istemcide kaldığını
/// kanıtlamak için (komşu `nudge_studying_feedback_test.dart` ile aynı desen).
class _CountingNudgeRepository extends InMemoryNudgeRepository {
  int sendCount = 0;

  @override
  Future<Nudge> sendNudge({
    required String groupId,
    required Profile sender,
    required Profile recipient,
    String? message,
  }) {
    sendCount += 1;
    return super.sendNudge(
      groupId: groupId,
      sender: sender,
      recipient: recipient,
      message: message,
    );
  }
}

Future<_CountingNudgeRepository> _pumpCampfire(
  WidgetTester tester, {
  bool peerIsStudying = false,
}) async {
  final nudges = _CountingNudgeRepository()..currentUserId = _me.id;
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
              status: peerIsStudying
                  ? PresenceStatus.studying
                  : PresenceStatus.onBreak,
              todaySeconds: 0,
              startedAt: peerIsStudying ? fixedNow : null,
            ),
          ]),
        ),
        groupTodaySecondsProvider.overrideWithValue(const <String, int>{}),
        authStateProvider.overrideWith((ref) => Stream.value(_me)),
        nudgeRepositoryProvider.overrideWithValue(nudges),
      ],
      child: MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: 400,
            child: CampfireScene(clock: () => fixedNow),
          ),
        ),
      ),
    ),
  );
  // 🔴 Sahne sonsuz alev animasyonu barındırır: `pumpAndSettle` asla oturmaz.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  addTearDown(() async => tester.pumpWidget(const SizedBox()));
  return nudges;
}

/// Sahnedeki bir kampçıya dokunur. Çıpa `AnimatedPositioned`ın anahtarıdır.
Future<void> _tapCamper(WidgetTester tester, String userId) async {
  await tester.tap(find.byKey(ValueKey('b-$userId')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// Alt sayfadaki Dürt düğmesine dokunur.
///
/// 🔴 `ensureVisible` şart: çalışan üyede sayfaya bir satır daha (o anki
/// oturum) ekleniyor ve içerik alt sayfanın 9/16 sınırını aşıyor. Düğme
/// kaydırıcının görünmeyen kısmında kalıyor, `tap` ıskalıyor ve test
/// "açıklama çıkmadı" diye **yanlış yere** kırmızı düşüyordu (ölçüldü).
Future<void> _tapNudge(WidgetTester tester) async {
  final button = find.widgetWithText(FilledButton, 'Dürt');
  await tester.ensureVisible(button);
  await tester.pump();
  await tester.tap(button);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  group('E1 — ölü dokunma davranışı kalktı', () {
    testWidgets('kampçıya dokununca kampçı alt sayfası açılıyor', (
      tester,
    ) async {
      await _pumpCampfire(tester);
      await _tapCamper(tester, _peer.id);

      // Kanonik yol: alt sayfa. Ölü olan `SocialProfileDialog` idi.
      expect(find.text('Bugünkü toplam'), findsOneWidget);
      expect(find.text(_peer.displayName), findsWidgets);
    });
  });

  group('madde 5 — alt sayfada dürtme var', () {
    testWidgets('başka bir üyenin sayfasında Dürt düğmesi görünüyor', (
      tester,
    ) async {
      await _pumpCampfire(tester);
      await _tapCamper(tester, _peer.id);

      expect(find.widgetWithText(FilledButton, 'Dürt'), findsOneWidget);
    });

    testWidgets('dürtme gönderiliyor ve alt sayfa kapanıyor', (tester) async {
      final nudges = await _pumpCampfire(tester);
      await _tapCamper(tester, _peer.id);

      await _tapNudge(tester);

      expect(nudges.sendCount, 1);

      // 🔴 Alt sayfa kapanmak **zorunda**: SnackBar'ı çizen `Scaffold` modal
      // rotanın altında kalır, sayfa açıkken mesaj hiç görünmez ve kullanıcı
      // "düğme öldü" sanır.
      expect(find.text('Bugünkü toplam'), findsNothing);
      expect(find.textContaining('dürtüldü'), findsOneWidget);
    });

    testWidgets('kendi kendini dürtme gizli', (tester) async {
      await _pumpCampfire(tester);
      await _tapCamper(tester, _me.id);

      // Sayfa açılıyor ama eylem yok: sunucu da reddediyor
      // (`cannotNudgeSelf`), kullanıcının basıp hata alması bir eylem değil.
      expect(find.text('Bugünkü toplam'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Dürt'), findsNothing);
    });

    testWidgets('çalışan üyeye dürtme sunucuya gitmez, açıklama çıkar', (
      tester,
    ) async {
      final nudges = await _pumpCampfire(tester, peerIsStudying: true);
      await _tapCamper(tester, _peer.id);

      await _tapNudge(tester);

      // `0116_nudge_focus_guard.sql`'in istemci karşılığı: kapı burada durur.
      expect(nudges.sendCount, 0);
      expect(find.text(_studyingNotice), findsOneWidget);
    });
  });

  group('tek bileşen — kopya yok', () {
    testWidgets('grup üye satırı da NudgeAction kullanıyor', (tester) async {
      final groups = InMemoryGroupRepository();
      final group = await groups.createGroup(name: 'Odak', creator: _me);
      await groups.joinGroup(inviteCode: group.inviteCode, member: _peer);
      final nudges = _CountingNudgeRepository()..currentUserId = _me.id;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            groupRepositoryProvider.overrideWithValue(groups),
            nudgeRepositoryProvider.overrideWithValue(nudges),
            authStateProvider.overrideWith((ref) => Stream.value(_me)),
            groupPresenceProvider.overrideWith(
              (ref) => Stream.value(const <Presence>[]),
            ),
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

      // 🔴 Asıl kural bu: iki yüzey **aynı** bileşeni kullanır. Kopyalansaydı
      // bu iddia yeşil kalır ama davranışlar zamanla ayrışırdı — o yüzden
      // yukarıdaki kamp ateşi iddiaları da aynı bileşenin üstünden ölçülüyor.
      expect(
        find.descendant(
          of: find.byKey(memberRowKey(_peer.id)),
          matching: find.byType(NudgeAction),
        ),
        findsOneWidget,
      );
    });
  });
}
