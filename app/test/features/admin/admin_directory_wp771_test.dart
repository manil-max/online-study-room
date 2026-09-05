// WP-771 — kisi/grup dizini kullanilir hale gelir + YUTULAN hatalar yuzeye
// cikar.
//
// ONCE KIRMIZI. Yedi kabul olcutunun her biri gorev kartindan birebir alindi ve
// her biri **kullanicinin gordugu** seyi olcer:
//   * arama `tester.enterText` ile YAZILIR, sonuc `find` ile SAYILIR;
//   * hata mesaji ekranda ARANIR (kaynakta `e.message` gecmesi kanit degildir);
//   * tazeleme, sahte deponun cagri SAYACI ile olculur (saglayici gercekten
//     yeniden okundu mu?);
//   * sert teyitte beklenen metnin e-posta oldugu, e-postayi YAZIP eylemin
//     indigini gorerek kanitlanir — diyalogda bir dize aramak yetmez.
//
// 🔴 Kabuk tuzagi: `find.byType(X)` bos/hatali bir govdeyle de eslesir. Her
// duzen iddiasinin yaninda govdenin GERCEK oldugunu gosteren bir metin aranir.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:online_study_room/data/models/admin_user_dto.dart';
import 'package:online_study_room/data/models/announcement.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/models/study_group.dart';
import 'package:online_study_room/data/providers/admin_moderation_providers.dart';
import 'package:online_study_room/data/providers/admin_providers.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/group_providers.dart';
import 'package:online_study_room/data/repositories/admin_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_admin_moderation_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_admin_repository.dart';
import 'package:online_study_room/features/admin/directory/admin_member_picker.dart';
import 'package:online_study_room/features/admin/health/account_purge_health_providers.dart';
import 'package:online_study_room/features/admin/sanctions/admin_person_dossier.dart';
import 'package:online_study_room/features/admin/tabs/admin_announcements_tab.dart';
import 'package:online_study_room/features/admin/tabs/admin_groups_tab.dart';
import 'package:online_study_room/features/admin/tabs/admin_users_tab.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

const _alfaId = '11111111-1111-4111-8111-111111111111';
const _ayseId = '33333333-3333-4333-8333-333333333333';
const _mehmetId = '44444444-4444-4444-8444-444444444444';
const _ayseEmail = 'ayse@example.com';
const _mehmetEmail = 'mehmet@example.com';

/// Sunucunun ham cevabi — jenerik metnin yerine EKRANDA bu aranir.
const _serverMessage = 'Forbidden';

Profile _profile(String id, String name, {bool isActive = true}) =>
    Profile(
      id: id,
      displayName: name,
      createdAt: DateTime(2026),
      isActive: isActive,
    );

StudyGroup _group(String id, String name) => StudyGroup(
  id: id,
  name: name,
  inviteCode: id.substring(0, 6),
  createdBy: 'baskasi',
  createdAt: DateTime(2026, 8),
);

List<AdminUserDto> _users() => [
  AdminUserDto(id: _ayseId, email: _ayseEmail, createdAt: DateTime(2026)),
  AdminUserDto(id: _mehmetId, email: _mehmetEmail, createdAt: DateTime(2026)),
];

/// Uye listesi saglayicisi GERCEKTEN yeniden okundu mu?
class _SpyRepository extends InMemoryAdminRepository {
  _SpyRepository({super.superAdminUserIds, this.failWith});

  /// Verilirse her eylem bu istisnayla duser (sunucu "hayir" dedi).
  final AdminException? failWith;

  int fetchGroupMembersCalls = 0;
  final List<String> groupActions = [];
  final List<String> userActions = [];

  @override
  Future<List<Profile>> fetchGroupMembers(String groupId) {
    fetchGroupMembersCalls++;
    return super.fetchGroupMembers(groupId);
  }

  @override
  Future<void> performGroupAction({
    required String action,
    required String targetGroupId,
    String? targetUserId,
    required String reason,
  }) async {
    final error = failWith;
    if (error != null) throw error;
    groupActions.add('$action:${targetUserId ?? targetGroupId}');
  }

  @override
  Future<void> performUserAction({
    required String action,
    required String targetUserId,
    required String reason,
  }) async {
    final error = failWith;
    if (error != null) throw error;
    userActions.add('$action:$targetUserId');
  }

  @override
  Future<void> deleteAnnouncement(String announcementId) async {
    final error = failWith;
    if (error != null) throw error;
    await super.deleteAnnouncement(announcementId);
  }
}

/// Saglik okumasi kac kez denendi?
class _PurgeSpyRepository extends InMemoryAdminRepository {
  _PurgeSpyRepository({
    super.superAdminUserIds,
    super.accountPurgeHealthError,
  });

  int purgeHealthCalls = 0;

  @override
  Future<AccountPurgeHealth> fetchAccountPurgeHealth() {
    purgeHealthCalls++;
    return super.fetchAccountPurgeHealth();
  }
}

Future<void> _pump(
  WidgetTester tester,
  Widget body, {
  List<Override> overrides = const [],
}) async {
  tester.view.physicalSize = const Size(1280, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authStateProvider.overrideWith(
          (ref) => Stream.value(_profile('admin', 'Admin')),
        ),
        ...overrides,
      ],
      child: MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: body),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void _expectRealBody(WidgetTester tester) {
  expect(tester.takeException(), isNull, reason: 'agac hata kabugunda');
  expect(find.byType(ErrorWidget), findsNothing, reason: 'agac hata kabugunda');
}

List<Override> _userTabOverrides(InMemoryAdminRepository repo) => [
  adminRepositoryProvider.overrideWithValue(repo),
  adminUsersProvider.overrideWith((ref) async => _users()),
];

List<Override> _groupTabOverrides(
  InMemoryAdminRepository repo, {
  required List<Profile> members,
}) => [
  adminRepositoryProvider.overrideWithValue(repo),
  adminGroupsProvider.overrideWith((ref) async => [_group(_alfaId, 'Alfa Grubu')]),
  adminUsersProvider.overrideWith((ref) async => _users()),
  groupMembersByIdProvider(_alfaId).overrideWith((ref) => Stream.value(members)),
];

/// Grup sekmesinin kendi gerekce diyalogu (`askAdminReason` degil).
Future<void> _confirmGroupReason(WidgetTester tester, String reason) async {
  await tester.enterText(
    find.widgetWithText(TextField, 'Gerekçe (Zorunlu)'),
    reason,
  );
  await tester.tap(find.widgetWithText(FilledButton, 'Onayla'));
  await tester.pumpAndSettle();
}

/// Kullanici/dosya yolundaki ortak gerekce diyalogu.
Future<void> _confirmAdminReason(WidgetTester tester, String reason) async {
  await tester.enterText(
    find.byKey(const Key('admin-user-reason-field')),
    reason,
  );
  await tester.tap(find.byKey(const Key('admin-user-reason-confirm')));
  await tester.pumpAndSettle();
}

/// SnackBar'in 4 sn'lik zamanlayicisini bosaltir (bekleyen timer uyarisi).
Future<void> _drainSnackBar(WidgetTester tester) =>
    tester.pumpAndSettle(const Duration(seconds: 5));

void main() {
  // ------------------------------------------------------------------
  // KABUL 1 — kisi dizininde arama.
  // ------------------------------------------------------------------
  group('WP-771/1 kullanici aramasi', () {
    testWidgets('e-posta parcasi listeyi suzer', (tester) async {
      final repo = _SpyRepository(superAdminUserIds: const {'admin'});
      addTearDown(repo.dispose);
      await _pump(
        tester,
        const AdminUsersTab(),
        overrides: _userTabOverrides(repo),
      );
      _expectRealBody(tester);

      // Govde gercek mi? Iki kullanici da e-postasiyla cizilmis olmali.
      expect(find.text(_ayseEmail), findsOneWidget);
      expect(find.text(_mehmetEmail), findsOneWidget);

      final search = find.widgetWithText(TextField, 'E-posta veya kimlik ara');
      expect(
        search,
        findsOneWidget,
        reason:
            'WP-771 kabul 1: kullanicilar sekmesi duz bir ListView; arama '
            'kutusu yok (admin_users_tab.dart:38-62).',
      );

      await tester.enterText(search, 'mehmet');
      await tester.pumpAndSettle();

      expect(find.text(_mehmetEmail), findsOneWidget);
      expect(
        find.text(_ayseEmail),
        findsNothing,
        reason: 'arama yazildi ama liste filtrelenmedi',
      );
    });

    testWidgets('kimlik parcasi da eslesir', (tester) async {
      final repo = _SpyRepository(superAdminUserIds: const {'admin'});
      addTearDown(repo.dispose);
      await _pump(
        tester,
        const AdminUsersTab(),
        overrides: _userTabOverrides(repo),
      );

      await tester.enterText(
        find.widgetWithText(TextField, 'E-posta veya kimlik ara'),
        _ayseId.substring(0, 8),
      );
      await tester.pumpAndSettle();

      expect(find.text(_ayseEmail), findsOneWidget);
      expect(find.text(_mehmetEmail), findsNothing);
    });

    testWidgets('bos sonucta filtre temizlenebilir', (tester) async {
      final repo = _SpyRepository(superAdminUserIds: const {'admin'});
      addTearDown(repo.dispose);
      await _pump(
        tester,
        const AdminUsersTab(),
        overrides: _userTabOverrides(repo),
      );

      await tester.enterText(
        find.widgetWithText(TextField, 'E-posta veya kimlik ara'),
        'zzz',
      );
      await tester.pumpAndSettle();
      expect(find.text(_ayseEmail), findsNothing);

      final clear = find.text('Filtreyi temizle');
      expect(
        clear,
        findsOneWidget,
        reason:
            'WP-771 kabul 1: bos sonucta filtreyi kaldiracak kontrol ekranda '
            'yok (filtre cikmazi).',
      );

      await tester.tap(clear);
      await tester.pumpAndSettle();

      expect(find.text(_ayseEmail), findsOneWidget);
      expect(find.text(_mehmetEmail), findsOneWidget);
    });
  });

  // ------------------------------------------------------------------
  // KABUL 2 — uye atildiktan sonra uye listesi TAZELENIR.
  // ------------------------------------------------------------------
  group('WP-771/2 uye atma sonrasi tazeleme', () {
    testWidgets('atma sonrasi uye saglayicisi yeniden okunur', (tester) async {
      final repo = _SpyRepository(superAdminUserIds: const {'admin'});
      addTearDown(repo.dispose);
      repo.seedGroupMembers(_alfaId, [
        _profile(_ayseId, 'Ayşe'),
        _profile(_mehmetId, 'Mehmet'),
      ]);

      await _pump(
        tester,
        const AdminGroupsTab(),
        overrides: _groupTabOverrides(
          repo,
          members: [_profile(_ayseId, 'Ayşe'), _profile(_mehmetId, 'Mehmet')],
        ),
      );
      _expectRealBody(tester);

      // Govde gercek mi?
      expect(find.text('Alfa Grubu'), findsOneWidget);
      expect(find.text('Ayşe'), findsWidgets);
      final before = repo.fetchGroupMembersCalls;
      expect(before, greaterThan(0), reason: 'uye listesi hic okunmamis');

      await tester.tap(find.byTooltip('Üyeyi At').first);
      await tester.pumpAndSettle();
      await _confirmGroupReason(tester, 'kural ihlali');

      // Eylem gercekten indi mi? (Kaynakta gecmesi kanit degil.)
      expect(repo.groupActions, ['remove_group_member:$_ayseId']);
      expect(
        repo.fetchGroupMembersCalls,
        greaterThan(before),
        reason:
            'WP-771 kabul 2: `_perform` yalniz adminGroupsProvider\'i '
            'invalidate ediyor; uye listesi (autoDispose DEGIL) bayat kaliyor '
            've atilan kisi satirda durmaya devam ediyor.',
      );
      await _drainSnackBar(tester);
    });
  });

  // ------------------------------------------------------------------
  // KABUL 3 — gruptan AYRILMIS kisi aktif uye gibi gorunmez.
  // ------------------------------------------------------------------
  group('WP-771/3 ayrilmis uye', () {
    List<Profile> members() => [
      _profile(_ayseId, 'Ayşe'),
      _profile(_mehmetId, 'Mehmet', isActive: false),
    ];

    testWidgets('pasif satir etiketlenir ve "Uyeyi at" dugmesi cizilmez', (
      tester,
    ) async {
      final repo = _SpyRepository(superAdminUserIds: const {'admin'});
      addTearDown(repo.dispose);
      repo.seedGroupMembers(_alfaId, members());

      await _pump(
        tester,
        const AdminGroupsTab(),
        overrides: _groupTabOverrides(repo, members: members()),
      );
      _expectRealBody(tester);

      // Govde gercek mi? Iki satir da cizilmis olmali.
      expect(find.text('Ayşe'), findsWidgets);
      expect(find.text('Mehmet'), findsWidgets);

      expect(
        find.text('Gruptan ayrıldı'),
        findsOneWidget,
        reason:
            'WP-771 kabul 3: `is_active` sunucudan geliyor ama satirda hicbir '
            'ayrim yok (admin_member_picker.dart:170-198).',
      );
      expect(
        find.byTooltip('Üyeyi At'),
        findsOneWidget,
        reason:
            'WP-771 kabul 3: ayrilmis uyenin yaninda da "Uyeyi at" duruyor; '
            'olmayan bir uyeligi bitiren dugme yalan soyler.',
      );
    });

    test('birlestirme: ayrilmis kisi "grup uyesi" olarak isaretlenmez', () {
      final entries = adminMergeDirectory(
        members: members(),
        users: const [],
      );

      expect(entries.firstWhere((e) => e.id == _ayseId).isMember, isTrue);
      expect(
        entries.firstWhere((e) => e.id == _mehmetId).isMember,
        isFalse,
        reason:
            'WP-771 kabul 3: uye secici ayrilmis kisiyi "Grup uyesi" olarak '
            'gosteriyordu.',
      );
    });

    testWidgets('uye secicide pasif satir "Grup uyesi" yazmaz', (tester) async {
      final repo = _SpyRepository(superAdminUserIds: const {'admin'});
      addTearDown(repo.dispose);
      repo.seedGroupMembers(_alfaId, members());

      await _pump(
        tester,
        const AdminGroupsTab(),
        overrides: _groupTabOverrides(repo, members: members()),
      );

      await tester.tap(find.text('Üye At').first);
      await tester.pumpAndSettle();
      _expectRealBody(tester);

      // Secici gercek mi?
      expect(find.text(_ayseEmail), findsOneWidget);
      expect(find.text(_mehmetEmail), findsOneWidget);
      expect(
        find.textContaining('Grup üyesi'),
        findsOneWidget,
        reason:
            'WP-771 kabul 3: ayrilmis kisi de "Grup uyesi" olarak '
            'isaretleniyordu.',
      );
    });
  });

  // ------------------------------------------------------------------
  // KABUL 4 — sunucunun GERCEK mesaji ekranda.
  // ------------------------------------------------------------------
  group('WP-771/4 yutulan sunucu mesaji', () {
    testWidgets('kullanici eylemi: "Forbidden" yazar, jenerik metin degil', (
      tester,
    ) async {
      final repo = _SpyRepository(
        superAdminUserIds: const {'admin'},
        failWith: const AdminException(_serverMessage),
      );
      addTearDown(repo.dispose);

      await _pump(
        tester,
        const AdminUsersTab(),
        overrides: _userTabOverrides(repo),
      );

      await tester.tap(find.text('Şifre Sıfırla').first);
      await tester.pumpAndSettle();
      await _confirmAdminReason(tester, 'sahip talebi');

      expect(
        find.text(_serverMessage),
        findsOneWidget,
        reason:
            'WP-771 kabul 4: admin_users_tab.dart:98-101 `e.message`i atip '
            'jenerik metin yaziyor.',
      );
      expect(find.text('Beklenmeyen bir hata oluştu.'), findsNothing);
      await _drainSnackBar(tester);
    });

    testWidgets('grup eylemi: "Forbidden" yazar', (tester) async {
      final repo = _SpyRepository(
        superAdminUserIds: const {'admin'},
        failWith: const AdminException(_serverMessage),
      );
      addTearDown(repo.dispose);
      repo.seedGroupMembers(_alfaId, [_profile(_ayseId, 'Ayşe')]);

      await _pump(
        tester,
        const AdminGroupsTab(),
        overrides: _groupTabOverrides(
          repo,
          members: [_profile(_ayseId, 'Ayşe')],
        ),
      );

      await tester.tap(find.byTooltip('Üyeyi At').first);
      await tester.pumpAndSettle();
      await _confirmGroupReason(tester, 'kural ihlali');

      expect(
        find.text(_serverMessage),
        findsOneWidget,
        reason:
            'WP-771 kabul 4: admin_groups_tab.dart:228-233 sunucunun mesajini '
            'yutuyor.',
      );
      expect(find.text('Beklenmeyen bir hata oluştu.'), findsNothing);
      await _drainSnackBar(tester);
    });

    testWidgets('kisi dosyasi: "Forbidden" yazar', (tester) async {
      final repo = _SpyRepository(
        superAdminUserIds: const {'admin'},
        failWith: const AdminException(_serverMessage),
      );
      addTearDown(repo.dispose);

      await _pump(
        tester,
        const AdminPersonDossier(
          targetUserId: _mehmetId,
          targetEmail: _mehmetEmail,
        ),
        overrides: [
          adminRepositoryProvider.overrideWithValue(repo),
          adminModerationRepositoryProvider.overrideWithValue(
            InMemoryAdminModerationRepository(),
          ),
          adminUsersProvider.overrideWith((ref) async => _users()),
        ],
      );
      _expectRealBody(tester);

      // Govde gercek mi?
      expect(find.byKey(const Key('admin-person-dossier')), findsOneWidget);

      await tester.tap(find.text('Şifre Sıfırla').first);
      await tester.pumpAndSettle();
      await _confirmAdminReason(tester, 'sahip talebi');

      expect(
        find.text(_serverMessage),
        findsOneWidget,
        reason:
            'WP-771 kabul 4: admin_person_dossier.dart:224-228 sunucunun '
            'mesajini yutuyor.',
      );
      await _drainSnackBar(tester);
    });
  });

  // ------------------------------------------------------------------
  // KABUL 5 — duyuru silme hatasi ekranda.
  // ------------------------------------------------------------------
  group('WP-771/5 duyuru hatasi', () {
    testWidgets('silme reddi sunucunun mesajiyla gorunur', (tester) async {
      final repo = _SpyRepository(
        superAdminUserIds: const {'admin'},
        failWith: const AdminException(_serverMessage),
      );
      addTearDown(repo.dispose);

      await _pump(
        tester,
        const AdminAnnouncementsTab(),
        overrides: [
          adminRepositoryProvider.overrideWithValue(repo),
          adminAnnouncementsProvider.overrideWith(
            (ref) async => [
              Announcement(
                id: 'a1',
                title: 'Bakım duyurusu',
                message: 'Cumartesi bakım var.',
                targetType: 'all',
                createdAt: DateTime(2026, 8, 10),
              ),
            ],
          ),
        ],
      );
      _expectRealBody(tester);

      // Govde gercek mi?
      expect(find.text('Bakım duyurusu'), findsOneWidget);

      await tester.tap(find.byTooltip('Sil'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Sil'));
      await tester.pumpAndSettle();

      expect(
        find.text(_serverMessage),
        findsOneWidget,
        reason:
            'WP-771 kabul 5: admin_announcements_tab.dart:101 `catch (_)` ile '
            'RLS reddini tanisiz yutuyor.',
      );
      expect(find.text('Beklenmeyen bir hata oluştu.'), findsNothing);
      await _drainSnackBar(tester);
    });
  });

  // ------------------------------------------------------------------
  // KABUL 6 — saglik saglayicisi depo politikasini tasir.
  // ------------------------------------------------------------------
  group('WP-771/6 saglik saglayicisi', () {
    test('kalici hatada 38 sn cark cevirmez, hemen duser', () async {
      final repo = _PurgeSpyRepository(
        superAdminUserIds: const {'admin'},
        accountPurgeHealthError: const AdminException(
          'not_super_admin',
          code: 'not_super_admin',
        ),
      );
      addTearDown(repo.dispose);

      final container = ProviderContainer(
        overrides: [
          adminRepositoryProvider.overrideWithValue(repo),
          authStateProvider.overrideWith(
            (ref) => Stream.value(_profile('admin', 'Admin')),
          ),
        ],
      );
      addTearDown(container.dispose);
      // Riverpod 3: dinleyicisi olmayan saglayici okuma sirasinda atilir.
      final authSub = container.listen(authStateProvider, (_, _) {});
      addTearDown(authSub.close);
      await container.read(authStateProvider.future);
      final sub = container.listen(accountPurgeHealthProvider, (_, _) {});
      addTearDown(sub.close);

      await expectLater(
        container
            .read(accountPurgeHealthProvider.future)
            .timeout(const Duration(seconds: 2)),
        throwsA(isA<AdminException>()),
        reason:
            'WP-771 kabul 6: `retry:` gecilmezse Riverpod 3 varsayilani kalici '
            'reddi 10 kez / ~38 sn dener; `.future` o sure boyunca askida '
            'kalir (core/net/read_retry_policy.dart:14-21).',
      );
      expect(
        repo.purgeHealthCalls,
        1,
        reason: 'kalici hata yeniden denenmis',
      );
    });
  });

  // ------------------------------------------------------------------
  // KABUL 7 — sert teyit UUID degil E-POSTA ister.
  // ------------------------------------------------------------------
  group('WP-771/7 sert teyit metni', () {
    testWidgets('vakadan acilan dosyada e-posta yazilinca hesap silinir', (
      tester,
    ) async {
      final repo = _SpyRepository(superAdminUserIds: const {'admin'});
      addTearDown(repo.dispose);

      await _pump(
        tester,
        // Vakadan gelen kopru e-postayi TASIMAZ
        // (`widgets/moderation_queue_card.dart:90`).
        const AdminPersonDossier(targetUserId: _mehmetId),
        overrides: [
          adminRepositoryProvider.overrideWithValue(repo),
          adminModerationRepositoryProvider.overrideWithValue(
            InMemoryAdminModerationRepository(),
          ),
          adminUsersProvider.overrideWith((ref) async => _users()),
        ],
      );
      _expectRealBody(tester);

      expect(
        find.text(_mehmetEmail),
        findsWidgets,
        reason:
            'WP-771 kabul 7: `ref.read` autoDispose saglayicida AsyncLoading '
            'doner; dosya basligi 36 karakterlik UUID yaziyordu.',
      );

      await tester.tap(find.byKey(const Key('admin-person-delete')));
      await tester.pumpAndSettle();
      await _confirmAdminReason(tester, 'kullanici talebi');

      expect(find.byKey(const Key('admin-sanction-hard-confirm')), findsOneWidget);

      // Sozlesme korunur: bos metinle hicbir sey inmez.
      await tester.tap(find.byKey(const Key('admin-sanction-hard-submit')));
      await tester.pumpAndSettle();
      expect(repo.userActions, isEmpty);

      // Beklenen metin E-POSTA: yazilinca eylem iner.
      await tester.enterText(
        find.byKey(const Key('admin-sanction-hard-email')),
        _mehmetEmail,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('admin-sanction-hard-submit')));
      await tester.pumpAndSettle();

      expect(
        repo.userActions,
        ['soft_delete_user:$_mehmetId'],
        reason:
            'WP-771 kabul 7: teyit hala UUID bekliyor — dizinde e-posta VAR '
            'ama cozulmuyor.',
      );
      await _drainSnackBar(tester);
    });
  });
}
