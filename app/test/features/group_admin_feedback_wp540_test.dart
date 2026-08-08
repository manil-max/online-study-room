// WP-540: grup yönetim eylemlerinde geri bildirim ve çift gönderim.
//
// WP-530 (grup kurma) / WP-532 (gruba katılma) deseninin yönetim yüzeyine
// taşınması. Düzeltmeden önce ölçülen davranış:
//
//   davet kodu yenile → istek uçarken gösterge=false, düğme etkin=true,
//                       2. basıştan sonra TOPLAM regenerate=2 (RPC idempotent
//                       DEĞİL → iki farklı kod; gösterilen ilk kod anında
//                       geçersiz) ve iki `navigator.pop()`
//   üye yasakla       → gösterge=false, başarı SnackBar=false (tamamen sessiz)
//   dürtme            → 2. basıştan sonra TOPLAM sendNudge=2; sunucu ikinciyi
//                       `nudge_cooldown` ile reddediyor, yani kullanıcı
//                       başarılı dürtmenin ardından "20 dakika bekle" görüyor
//   boş ad/kod        → diyalog hiçbir mesaj vermeden kapanıyor
//   boş sohbet mesajı → SnackBar "Beklenmeyen bir hata oluştu." = true
//   katılma hataları  → beş ayrı sebep tek genel cümleye iniyor
//
// 🔴 Riverpod 3 tuzağı (WP-532 dersi): `authStateProvider` dinleyicisiz
// okunursa her `read`de yeniden kurulur ve `.value` null kalır; akış sessizce
// hiçbir şey yapmaz, test yalancı yeşil olur. Harness'ler provider'ı `watch`
// ile canlı tutuyor ya da ekranı gerçek `ConsumerWidget` içinde kuruyor.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/chat_message.dart';
import 'package:online_study_room/data/models/nudge.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/models/study_group.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/chat_providers.dart';
import 'package:online_study_room/data/providers/group_providers.dart';
import 'package:online_study_room/data/providers/nudge_providers.dart';
import 'package:online_study_room/data/repositories/group_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_chat_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_group_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_nudge_repository.dart';
import 'package:online_study_room/features/classroom/widgets/class_chat_card.dart';
import 'package:online_study_room/features/classroom/widgets/class_detail_screen.dart';
import 'package:online_study_room/features/classroom/widgets/class_switcher.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

final _owner = Profile(
  id: 'owner-1',
  displayName: 'Sahip',
  createdAt: DateTime(2026, 1, 1),
);
final _peer = Profile(
  id: 'peer-1',
  displayName: 'Komsu',
  createdAt: DateTime(2026, 1, 1),
);

/// Sahadaki 5-6 sn'lik sunucu turunu taklit eder ve yönetim çağrılarını sayar.
class _SlowGroupRepository extends InMemoryGroupRepository {
  static const delay = Duration(seconds: 5);

  int regenerateCalls = 0;
  int banCalls = 0;
  int removeCalls = 0;

  @override
  Future<String> regenerateInviteCode(String groupId) async {
    regenerateCalls++;
    await Future<void>.delayed(delay);
    return super.regenerateInviteCode(groupId);
  }

  @override
  Future<void> banMember(String groupId, String userId) async {
    banCalls++;
    await Future<void>.delayed(delay);
    return super.banMember(groupId, userId);
  }

  @override
  Future<void> removeMember(String groupId, String userId) async {
    removeCalls++;
    await Future<void>.delayed(delay);
    return super.removeMember(groupId, userId);
  }
}

/// Katılma/kurma isteğini verilen hatayla düşüren repository.
///
/// `Object` alıyor çünkü sebeplerden biri **`GroupException` bile değil**:
/// Supabase repository yalnız `PostgrestException`ı sarar, bağlantı kopunca
/// `SocketException` sarılmadan yukarı çıkar.
class _FailingGroupRepository extends InMemoryGroupRepository {
  _FailingGroupRepository(this.failure);

  final Object failure;

  @override
  Future<StudyGroup> joinGroup({
    required String inviteCode,
    required Profile member,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 10));
    throw failure;
  }

  @override
  Future<StudyGroup> createGroup({
    required String name,
    required Profile creator,
    GroupVisibility visibility = GroupVisibility.private,
    int memberLimit = kDefaultGroupMemberLimit,
    String timeZone = kDefaultGroupTimeZone,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 10));
    throw failure;
  }
}

/// Gönderimi geciktiren + sayan dürtme repository'si.
class _SlowNudgeRepository extends InMemoryNudgeRepository {
  int sendCount = 0;

  @override
  Future<Nudge> sendNudge({
    required String groupId,
    required Profile sender,
    required Profile recipient,
    String? message,
  }) async {
    sendCount++;
    await Future<void>.delayed(const Duration(seconds: 5));
    return super.sendNudge(
      groupId: groupId,
      sender: sender,
      recipient: recipient,
      message: message,
    );
  }
}

Widget _app(Widget home, List<Override> overrides) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(
    locale: const Locale('tr'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  ),
);

/// Detay ekranı **ikinci** rota olarak açılır.
///
/// 🔴 Bilerek: eski akışta başarı dalında `navigator.pop()` vardı ve iki
/// eşzamanlı istek iki pop çağırıyordu. Ekran `home:` olsaydı pop'un sayısı
/// hiç ölçülemezdi; alttaki kök rota "kaç kez geri gidildi" sorusunun kanıtı.
class _DetailHost extends StatelessWidget {
  const _DetailHost({required this.group});

  final StudyGroup group;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Builder(
          builder: (ctx) => FilledButton(
            onPressed: () => Navigator.of(ctx).push(
              MaterialPageRoute<void>(
                builder: (_) => ClassDetailScreen(group: group),
              ),
            ),
            child: const Text('kok-rota'),
          ),
        ),
      ),
    );
  }
}

/// Grup kurma/katılma akışlarını tetikleyen harness.
class _SwitcherHost extends ConsumerWidget {
  const _SwitcherHost();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(authStateProvider); // Riverpod 3: provider'ı canlı tut.
    return Scaffold(
      body: Center(
        child: Builder(
          builder: (ctx) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton(
                onPressed: () => createGroupFlow(ctx, ref),
                child: const Text('harness-create'),
              ),
              FilledButton(
                onPressed: () => joinGroupFlow(ctx, ref),
                child: const Text('harness-join'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<(StudyGroup, _SlowGroupRepository, _SlowNudgeRepository)>
_adminWorld() async {
  final repo = _SlowGroupRepository();
  final group = await repo.createGroup(name: 'Odak Grubu', creator: _owner);
  await repo.joinGroup(inviteCode: group.inviteCode, member: _peer);
  final nudges = _SlowNudgeRepository()..currentUserId = _owner.id;
  return (group, repo, nudges);
}

Future<void> _pumpDetail(
  WidgetTester tester, {
  required StudyGroup group,
  required GroupRepository repo,
  required InMemoryNudgeRepository nudges,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    _app(_DetailHost(group: group), [
      groupRepositoryProvider.overrideWithValue(repo),
      nudgeRepositoryProvider.overrideWithValue(nudges),
      authStateProvider.overrideWith((ref) => Stream.value(_owner)),
    ]),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('kok-rota'));
  await tester.pumpAndSettle();
}

/// Katılma akışını açar, [code] kodunu yazar ve "Katıl"a hazır bırakır.
Future<void> _pumpJoin(
  WidgetTester tester, {
  required GroupRepository repo,
  bool signedIn = true,
  String code = 'KOD123',
}) async {
  await tester.pumpWidget(
    _app(const _SwitcherHost(), [
      groupRepositoryProvider.overrideWithValue(repo),
      authStateProvider.overrideWith(
        (ref) => Stream.value(signedIn ? _owner : null),
      ),
    ]),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('harness-join'));
  await tester.pumpAndSettle();
  if (code.isNotEmpty) {
    await tester.enterText(find.byType(TextField).first, code);
    await tester.pump();
  }
}

void main() {
  group('davet kodu yenileme', () {
    testWidgets('iki basış tek RPC gönderir, gösterge ekranda kalır', (
      tester,
    ) async {
      final (group, repo, nudges) = await _adminWorld();
      await _pumpDetail(tester, group: group, repo: repo, nudges: nudges);

      await tester.tap(find.byTooltip('Kodu yenile'));
      await tester.pumpAndSettle();

      final submit = find.byKey(const Key('regenerate-code-submit'));
      expect(submit, findsOneWidget);

      await tester.tap(submit);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Kullanıcının "olmadı galiba" anı: aynı düğmeye ikinci basış.
      await tester.tap(submit, warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        repo.regenerateCalls,
        1,
        reason:
            'İkinci basış ikinci RPC gönderdi; kod idempotent değil, '
            'kullanıcıya gösterilen kod anında geçersiz olur.',
      );
      expect(
        find.byType(AlertDialog),
        findsOneWidget,
        reason: 'Diyalog kapanırsa kullanıcı yine göstergesiz ekrana bakar.',
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();

      expect(repo.regenerateCalls, 1);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.textContaining('Yeni kod:'), findsOneWidget);
      // Tek pop: kök rota geri geldi, ondan bir alt seviye yok.
      expect(find.text('kok-rota'), findsOneWidget);
    });
  });

  group('üye yasaklama', () {
    testWidgets('gösterge ve başarı onayı var', (tester) async {
      final (group, repo, nudges) = await _adminWorld();
      await _pumpDetail(tester, group: group, repo: repo, nudges: nudges);

      await tester.scrollUntilVisible(
        find.text(_peer.displayName),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const ValueKey('moderate-peer-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Üyeyi yasakla').last);
      await tester.pumpAndSettle();

      final submit = find.byKey(const Key('ban-member-submit'));
      expect(submit, findsOneWidget);

      await tester.tap(submit);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.byType(CircularProgressIndicator),
        findsOneWidget,
        reason:
            'Geri dönüşü zor bir moderasyon eylemi göstergesiz koşamaz '
            '(ölçüm: gosterge=false).',
      );
      await tester.tap(submit, warnIfMissed: false);
      await tester.pump();
      expect(repo.banCalls, 1);

      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();

      expect(
        find.text('Üye gruba yasaklandı.'),
        findsOneWidget,
        reason: 'Başarı onayı yoktu (ölçüm: basari SnackBar=false).',
      );
    });

    testWidgets('üye çıkarma da onay gösterir', (tester) async {
      final (group, repo, nudges) = await _adminWorld();
      await _pumpDetail(tester, group: group, repo: repo, nudges: nudges);

      await tester.scrollUntilVisible(
        find.text(_peer.displayName),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const ValueKey('moderate-peer-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Üyeyi çıkar').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('remove-member-submit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();

      expect(repo.removeCalls, 1);
      expect(find.text('Üye gruptan çıkarıldı.'), findsOneWidget);
    });
  });

  group('dürtme', () {
    testWidgets('iki basış tek dürtme gönderir', (tester) async {
      final (group, repo, nudges) = await _adminWorld();
      await _pumpDetail(tester, group: group, repo: repo, nudges: nudges);

      await tester.scrollUntilVisible(
        find.text(_peer.displayName),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      final button = find.byKey(const ValueKey('nudge-peer-1'));
      expect(button, findsOneWidget);

      await tester.tap(button);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(button, warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        nudges.sendCount,
        1,
        reason:
            'İkinci gönderim sunucuda `nudge_cooldown` ile reddedilir; '
            'kullanıcı başarılı dürtmenin ardından "20 dakika bekle" görür.',
      );

      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      expect(nudges.sendCount, 1);
      expect(find.textContaining('dürtüldü'), findsOneWidget);
    });
  });

  group('boş girişte sessiz kapanma', () {
    testWidgets('boş grup adı diyaloğu kapatmaz, sebebi yazar', (tester) async {
      final repo = InMemoryGroupRepository();
      await tester.pumpWidget(
        _app(const _SwitcherHost(), [
          groupRepositoryProvider.overrideWithValue(repo),
          authStateProvider.overrideWith((ref) => Stream.value(_owner)),
        ]),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('harness-create'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('create-group-submit')));
      await tester.pumpAndSettle();

      expect(
        find.byType(AlertDialog),
        findsOneWidget,
        reason: 'Sessiz kapanma, başarısız olmuş bir eylemden ayırt edilemez.',
      );
      expect(find.text('Grup adı boş olamaz.'), findsOneWidget);
    });

    testWidgets('boş davet kodu diyaloğu kapatmaz, sebebi yazar', (
      tester,
    ) async {
      await _pumpJoin(tester, repo: InMemoryGroupRepository(), code: '');

      await tester.tap(find.byKey(const Key('join-group-submit')));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Davet kodunu gir.'), findsOneWidget);
    });

    testWidgets('grup kurma alanı istek uçarken kilitli', (tester) async {
      final repo = _FailingGroupRepository(const GroupException('x'));
      await tester.pumpWidget(
        _app(const _SwitcherHost(), [
          groupRepositoryProvider.overrideWithValue(repo),
          authStateProvider.overrideWith((ref) => Stream.value(_owner)),
        ]),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('harness-create'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Yeni Grup');
      await tester.pump();

      await tester.tap(find.byKey(const Key('create-group-submit')));
      await tester.pump();

      // `_promptJoinGroup`da vardı, burada yoktu: istek uçarken ad hâlâ
      // düzenlenebiliyordu.
      final field = tester.widget<TextField>(find.byType(TextField).first);
      expect(field.enabled, isFalse);

      // Askıdaki isteği bitir: yoksa ağaç, timer hâlâ beklerken sökülür.
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();
    });
  });

  group('katılma hatası sebebini söyler', () {
    Future<void> expectMessage(
      WidgetTester tester,
      Object failure,
      String message,
    ) async {
      await _pumpJoin(tester, repo: _FailingGroupRepository(failure));
      await tester.tap(find.byKey(const Key('join-group-submit')));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text(message), findsOneWidget);
    }

    testWidgets('kod yanlış', (tester) async {
      // İki repository de bu cümleyi aynen üretiyor (row == null dalı).
      await expectMessage(
        tester,
        const GroupException('Bu koda ait grup bulunamadı.'),
        'Bu koda ait grup bulunamadı.',
      );
    });

    testWidgets('gruba yasaklısın', (tester) async {
      // Supabase ucu: `0093_group_bans.sql:185` `raise exception 'group_banned'`.
      await expectMessage(
        tester,
        const GroupException('Gruba katılınamadı: group_banned'),
        'Bu gruba katılman engellendi.',
      );
    });

    testWidgets('bellek-içi uç de aynı cümleyi verir', (tester) async {
      // Bellek-içi repository kod yerine cümle taşıyor; eşleme ikisini de
      // tanımazsa demo/test yolu sessizce genel hataya düşer.
      await expectMessage(
        tester,
        const GroupException('Bu gruba katılmanız engellendi.'),
        'Bu gruba katılman engellendi.',
      );
    });

    testWidgets('grup dolu', (tester) async {
      await expectMessage(
        tester,
        const GroupException('Gruba katılınamadı: Grup dolu.'),
        'Grup dolu, yeni üye alamıyor.',
      );
    });

    testWidgets('oturum yok', (tester) async {
      await _pumpJoin(
        tester,
        repo: InMemoryGroupRepository(),
        signedIn: false,
      );
      await tester.tap(find.byKey(const Key('join-group-submit')));
      await tester.pumpAndSettle();

      // 🔴 Eski akış oturumu diyalogdan ÖNCE okuyordu: `.value` null ise
      // "Gruba katıl" hiç açılmıyordu bile.
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Oturum bulunamadı. Yeniden giriş yap.'), findsOneWidget);
    });

    testWidgets('ağ hatası', (tester) async {
      // `GroupException` DEĞİL: Supabase repository yalnız `PostgrestException`ı
      // sarıyor. Eski `on GroupException` bunu hiç yakalamıyordu → gösterge
      // sonsuza dek dönüyor, `PopScope` yüzünden diyalog da kapanmıyordu.
      await expectMessage(
        tester,
        Exception('SocketException: Failed host lookup'),
        'Sunucuya ulaşılamadı. Bağlantını kontrol edip tekrar dene.',
      );
    });
  });

  group('grup kurmada yasaklı ad', () {
    testWidgets('moderasyon mesajı gösterilir', (tester) async {
      // `0094_public_name_filter.sql:47` kodu raise eder; ad DEĞİŞTİRMEDE
      // doğru mesaj zaten vardı, kurmada generic'e düşüyordu.
      final repo = _FailingGroupRepository(
        const GroupException('Grup oluşturulamadı: public_name_not_allowed'),
      );
      await tester.pumpWidget(
        _app(const _SwitcherHost(), [
          groupRepositoryProvider.overrideWithValue(repo),
          authStateProvider.overrideWith((ref) => Stream.value(_owner)),
        ]),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('harness-create'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'yasakli ad');
      await tester.pump();

      await tester.tap(find.byKey(const Key('create-group-submit')));
      await tester.pumpAndSettle();

      expect(
        find.text('Bu ad kullanılamaz. Başka bir ad deneyin.'),
        findsOneWidget,
      );
    });
  });

  group('sohbette boş mesaj', () {
    Widget chatHarness() {
      final group = StudyGroup(
        id: 'group-1',
        name: 'Odak Grubu',
        inviteCode: 'KAMP42',
        createdBy: _owner.id,
        createdAt: DateTime(2026, 1, 1),
      );
      return _app(Scaffold(body: ClassChatCard(group: group)), [
        authStateProvider.overrideWith((ref) => Stream.value(_owner)),
        classMessagesProvider(
          group.id,
        ).overrideWith((ref) => Stream.value(const <ChatMessage>[])),
        chatRepositoryProvider.overrideWithValue(InMemoryChatRepository()),
      ]);
    }

    testWidgets('gönder düğmesi boşken devre dışı, yazınca etkin', (
      tester,
    ) async {
      await tester.pumpWidget(chatHarness());
      await tester.pumpAndSettle();

      // `find.byTooltip` `Tooltip` widget'ını döner; düğmenin kendisi onun
      // atasıdır (`IconButton` iç yapısında tooltip'i sarar).
      final send = find.ancestor(
        of: find.byTooltip('Gönder'),
        matching: find.byType(IconButton),
      );
      expect(
        tester.widget<IconButton>(send).onPressed,
        isNull,
        reason:
            'Etkin düğme `ChatException("Mesaj boş olamaz.")` fırlatıyor ve '
            'ekranda "Beklenmeyen bir hata oluştu." çıkıyordu.',
      );

      // Yalnız boşluk da boştur.
      await tester.enterText(find.byType(TextField), '   ');
      await tester.pump();
      expect(tester.widget<IconButton>(send).onPressed, isNull);

      await tester.enterText(find.byType(TextField), 'merhaba');
      await tester.pump();
      expect(tester.widget<IconButton>(send).onPressed, isNotNull);

      await tester.tap(send);
      await tester.pumpAndSettle();
      expect(find.text('Beklenmeyen bir hata oluştu.'), findsNothing);
      // Gönderim gerçekten oldu: alan temizlendi.
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        isEmpty,
      );
    });
  });
}
