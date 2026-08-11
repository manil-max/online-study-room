// WP-F — yonetici bir gruptan uye ATABILIYOR ama kimlerin uye oldugunu
// GOREMIYORDU.
//
// Kok neden (lider tarafindan bagimsiz dogrulandi, WP-D de ekranda yazdi):
//   * `supabase/migrations/0115_profile_titles.sql:103` — `group_member_directory`
//     cagirani `is_group_member` ile suzer, uye olmayan yoneticiye `42501` doner.
//   * `supabase/migrations/0001_initial_schema.sql:156` — `members_select`
//     politikasi da `is_group_member(group_id)`; yonetici icin SELECT istisnasi
//     YOK.
//   * `supabase/functions/admin-operations/index.ts` — `remove_group_member`
//     VARDI, listeleme eylemi YOKTU.
//
// SECILEN YOL (a): edge fonksiyonuna `list_group_members` eylemi. Fonksiyon
// zaten SERVICE ROLE ile calisir (RLS'i asar) ve yonetici kapisinin arkasindadir;
// migration gerekmez, RLS'e kalici bir yonetici istisnasi acilmaz.
//
// 🔴 Olculen sey KULLANICININ GORDUGU seydir: satir `find.text` ile SAYILIR.
// Bir widget tipinin bulunmasi kanit degildir (hata kabugu da eslesir), o yuzden
// her duzen iddiasinin yaninda govdenin gercek oldugunu gosteren bir metin
// aranir.
//
// OLCEMEDIM: `deno` bu makinede kurulu degil, yerel Docker kalkmıyor — edge
// fonksiyonunun CALISAN 403'u ve RLS'in kendisi kosturulamadi. Sunucu tarafi
// burada KAYNAK SOZLESMESI ile sabitlendi (kapinin switch'ten once geldigi,
// yetkinin cagiranin oturumuyla olculdugu).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/admin_user_dto.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/models/study_group.dart';
import 'package:online_study_room/data/providers/admin_providers.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/group_providers.dart';
import 'package:online_study_room/data/repositories/admin_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_admin_repository.dart';
import 'package:online_study_room/data/repositories/supabase/supabase_admin_repository.dart';
import 'package:online_study_room/features/admin/directory/admin_group_members.dart';
import 'package:online_study_room/features/admin/tabs/admin_groups_tab.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

import '../../support/supabase_wire_harness.dart';

const _alfaId = '11111111-1111-4111-8111-111111111111';
const _ayseId = '33333333-3333-4333-8333-333333333333';
const _mehmetId = '44444444-4444-4444-8444-444444444444';

Profile _profile(String id, String name) =>
    Profile(id: id, displayName: name, createdAt: DateTime(2026));

StudyGroup _group(String id, String name) => StudyGroup(
  id: id,
  name: name,
  inviteCode: id.substring(0, 6),
  createdBy: 'baskasi',
  createdAt: DateTime(2026, 8),
);

String _readRepoFile(String relativePath) =>
    File(relativePath).readAsStringSync();

/// Sunucunun `42501`'i — yonetici grubun uyesi degil.
Stream<List<Profile>> _deniedStream() =>
    Stream<List<Profile>>.error(StateError('42501: not authorized'));

/// Depoya kac kez gidildigini sayan sahte (istemci kapisi olcumu).
class _SpyAdminRepository extends InMemoryAdminRepository {
  _SpyAdminRepository({super.superAdminUserIds});

  int fetchGroupMembersCalls = 0;

  @override
  Future<List<Profile>> fetchGroupMembers(String groupId) {
    fetchGroupMembersCalls++;
    return super.fetchGroupMembers(groupId);
  }
}

/// Yonetici yolu da dusmus (sunucu hatasi) — kayip yazilmali.
class _FailingAdminRepository extends InMemoryAdminRepository {
  _FailingAdminRepository({super.superAdminUserIds});

  @override
  Future<List<Profile>> fetchGroupMembers(String groupId) async {
    throw const AdminException('Üye listesi alınamadı');
  }
}

Future<void> _pump(
  WidgetTester tester,
  Widget body, {
  List<Override> overrides = const [],
}) async {
  tester.view.physicalSize = const Size(1280, 1400);
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

List<Override> _tabOverrides(InMemoryAdminRepository repo) => [
  adminRepositoryProvider.overrideWithValue(repo),
  adminGroupsProvider.overrideWith((ref) async => [_group(_alfaId, 'Alfa Grubu')]),
  adminUsersProvider.overrideWith(
    (ref) async => [
      AdminUserDto(
        id: _ayseId,
        email: 'ayse@example.com',
        createdAt: DateTime(2026),
      ),
      AdminUserDto(
        id: _mehmetId,
        email: 'mehmet@example.com',
        createdAt: DateTime(2026),
      ),
    ],
  ),
];

void main() {
  // ------------------------------------------------------------------
  // KABUL 1 + 2'nin sunucu tarafi — kaynak sozlesmesi.
  // ------------------------------------------------------------------
  group('WP-F/1 sunucu yolu', () {
    final source = _readRepoFile('../supabase/functions/admin-operations/index.ts');

    test('admin-operations uye LISTELEME eylemini tasir', () {
      expect(
        source,
        contains("case 'list_group_members'"),
        reason:
            'Yonetici uye ATABILIYOR (remove_group_member) ama LISTELEYEMIYOR; '
            'grup dosyasi yarim.',
      );
    });

    test('liste eylemi yonetici kapisinin ARKASINDA (fail-closed)', () {
      final gate = source.indexOf("rpc('is_super_admin')");
      final forbidden = source.indexOf("status: 403");
      final switchAt = source.indexOf('switch (action)');
      final listAt = source.indexOf("case 'list_group_members'");

      expect(gate, greaterThan(-1), reason: 'yonetici kapisi yok');
      expect(
        forbidden,
        greaterThan(gate),
        reason: 'kapi basarisiz olunca 403 donmeli',
      );
      expect(
        switchAt,
        greaterThan(forbidden),
        reason: 'eylem dagitimi yetki kapisindan SONRA gelmeli',
      );
      expect(
        listAt,
        greaterThan(switchAt),
        reason:
            'yeni okuma eylemi kapinin arkasinda, switch icinde olmali; '
            'kapiya erisilmeden calisan bir dal fail-open olur',
      );
    });

    test('yetki servis roluyle degil CAGIRANIN oturumuyla olculur', () {
      expect(source, contains("supabaseClient.rpc('is_super_admin')"));
      expect(
        source.contains("supabaseAdmin.rpc('is_super_admin')"),
        isFalse,
        reason:
            'servis rolu her zaman yonetici gibi gorunur; kapi cagiranin '
            'JWT\'siyle olculmeli',
      );
    });

    test('okuma yolu uye kapili RPC uzerinden gecmez', () {
      // Ad yorumda GECEBILIR (neden kullanilmadigi orada anlatiliyor); yasak
      // olan CAGRIDIR.
      expect(
        source.contains("rpc('group_member_directory')"),
        isFalse,
        reason:
            '0115:103 cagirani is_group_member ile suzer — uyesi olmayan '
            'yonetici icin 42501 doner, yani bu RPC bu is icin kullanilamaz',
      );
      expect(
        source,
        contains("from('group_members')"),
        reason: 'okuma servis rolu ile dogrudan tablodan yapilmali',
      );
    });

    test('okuma eylemi gerekce istemez ve denetim kaydi yazmaz', () {
      expect(
        source.contains("if (!targetGroupId || !reason?.trim()) {"),
        isFalse,
        reason:
            'kosulsuz gerekce zorunlulugu salt-okuma eylemini de reddeder',
      );
      expect(
        source,
        contains('READ_ONLY_ACTIONS'),
        reason:
            'salt-okuma eylemleri acikca ayrilmali: gerekce istenmez, '
            'denetim kaydi sismez',
      );
    });
  });

  // ------------------------------------------------------------------
  // KABUL 4 — engellenen uye kurali BOZULMAZ (0115 oldugu gibi durur).
  // ------------------------------------------------------------------
  group('WP-F/2 engellenen uye kurali', () {
    test('0115 satiri silmez, kimligi bosaltir — kural yerinde', () {
      final sql = _readRepoFile('../supabase/migrations/0115_profile_titles.sql');
      expect(
        sql,
        contains("case when v.blocked then '' else p.display_name end"),
        reason: 'kamp atesi kurali: engellenen uye satirda kalir, adi bosalir',
      );
      expect(
        sql,
        contains('case when v.blocked then null else p.avatar_url end'),
      );
      expect(sql, contains('is_blocked_pair(auth.uid(), gm.user_id)'));
    });
  });

  // ------------------------------------------------------------------
  // Kablo — istemci gercekten `admin-operations`'a mi gidiyor?
  // ------------------------------------------------------------------
  group('WP-F/3 kablo', () {
    test('liste admin-operations/list_group_members olarak gider', () async {
      final wire = SupabaseWireHarness();
      wire.respond('admin-operations', {
        'data': [
          {
            'id': _ayseId,
            'display_name': 'Ayşe',
            'created_at': '2026-08-01T10:00:00Z',
            'is_active': true,
          },
        ],
      });
      final repo = SupabaseAdminRepository(wire.client());

      final members = await repo.fetchGroupMembers(_alfaId);

      final call = wire.calls.single;
      expect(call.url.path, contains('functions/v1/admin-operations'));
      expect(call.json['action'], 'list_group_members');
      expect(call.json['targetGroupId'], _alfaId);
      expect(members.single.displayName, 'Ayşe');
      expect(members.single.id, _ayseId);
    });

    test('sunucu reddederse BOS LISTE degil hata doner', () async {
      final wire = SupabaseWireHarness();
      wire.respond('admin-operations', {'error': 'Forbidden'}, status: 403);
      final repo = SupabaseAdminRepository(wire.client());

      await expectLater(
        repo.fetchGroupMembers(_alfaId),
        throwsA(isA<AdminException>()),
        reason:
            'reddedilen okuma sessizce bos listeye donusurse yonetici grubu '
            'BOS sanir',
      );
    });
  });

  // ------------------------------------------------------------------
  // KABUL 2 — istemci kapisi: yonetici olmayan sunucuya bile gitmez.
  // ------------------------------------------------------------------
  group('WP-F/4 istemci kapisi', () {
    test('yonetici olmayanda depo HIC cagrilmaz', () async {
      final repo = _SpyAdminRepository(superAdminUserIds: const {'admin'});
      addTearDown(repo.dispose);
      final container = ProviderContainer(
        overrides: [
          adminRepositoryProvider.overrideWithValue(repo),
          authStateProvider.overrideWith(
            (ref) => Stream.value(_profile('sivil', 'Sivil')),
          ),
        ],
      );
      addTearDown(container.dispose);
      // Riverpod 3: dinleyicisi olmayan saglayici okuma sirasinda atilir.
      final authSub = container.listen(authStateProvider, (_, _) {});
      addTearDown(authSub.close);
      await container.read(authStateProvider.future);
      final sub = container.listen(
        adminGroupMembersProvider(_alfaId),
        (_, _) {},
      );
      addTearDown(sub.close);

      await expectLater(
        container.read(adminGroupMembersProvider(_alfaId).future),
        throwsA(isA<AdminException>()),
      );
      expect(
        repo.fetchGroupMembersCalls,
        0,
        reason: 'yonetici olmayan cagri sunucuya hic ulasmamali (fail-closed)',
      );
    });

    test('yoneticide liste doner', () async {
      final repo = _SpyAdminRepository(superAdminUserIds: const {'admin'});
      addTearDown(repo.dispose);
      repo.seedGroupMembers(_alfaId, [_profile(_ayseId, 'Ayşe')]);
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
      final sub = container.listen(
        adminGroupMembersProvider(_alfaId),
        (_, _) {},
      );
      addTearDown(sub.close);

      final members = await container.read(
        adminGroupMembersProvider(_alfaId).future,
      );
      expect(members.single.displayName, 'Ayşe');
      expect(repo.fetchGroupMembersCalls, 1);
    });
  });

  // ------------------------------------------------------------------
  // Birlestirme kurali (saf) — bos liste ile OKUNAMAYAN liste ayni sey degil.
  // ------------------------------------------------------------------
  group('WP-F/5 birlestirme', () {
    test('uye akisi dusse de yonetici listesi ciziliyor', () {
      final view = adminGroupMemberUnion(
        adminList: AsyncValue.data([_profile(_ayseId, 'Ayşe')]),
        memberStream: AsyncValue.error(
          StateError('42501'),
          StackTrace.empty,
        ),
      );
      expect(view.members.single.displayName, 'Ayşe');
      expect(view.unavailable, isFalse);
      expect(view.isLoading, isFalse);
    });

    test('yonetici yolu dusse de uye akisi ciziliyor', () {
      final view = adminGroupMemberUnion(
        adminList: AsyncValue.error(StateError('500'), StackTrace.empty),
        memberStream: AsyncValue.data([_profile(_ayseId, 'Ayşe')]),
      );
      expect(view.members.single.displayName, 'Ayşe');
      expect(view.unavailable, isFalse);
    });

    test('iki kaynak da duserse kayip acikca isaretlenir', () {
      final view = adminGroupMemberUnion(
        adminList: AsyncValue.error(StateError('500'), StackTrace.empty),
        memberStream: AsyncValue.error(StateError('42501'), StackTrace.empty),
      );
      expect(view.unavailable, isTrue);
      expect(view.members, isEmpty);
    });

    test('iki kaynak da bos ise kayip YOK — grup gercekten bos', () {
      final view = adminGroupMemberUnion(
        adminList: const AsyncValue.data(<Profile>[]),
        memberStream: const AsyncValue.data(<Profile>[]),
      );
      expect(view.unavailable, isFalse);
      expect(view.members, isEmpty);
    });

    test('ayni kisi iki kaynakta da varsa satir tekrarlanmaz', () {
      final view = adminGroupMemberUnion(
        adminList: AsyncValue.data([_profile(_ayseId, 'Ayşe')]),
        memberStream: AsyncValue.data([
          _profile(_ayseId, ''),
          _profile(_mehmetId, 'Mehmet'),
        ]),
      );
      expect(view.members, hasLength(2));
      // Engellenen uyede akis adi BOSALTIR (0115); yonetici gorunumunde
      // kimlik korunur, yoksa kimi attigini bilemez.
      expect(view.members.first.displayName, 'Ayşe');
      expect(view.members.last.displayName, 'Mehmet');
    });
  });

  // ------------------------------------------------------------------
  // KABUL 3 — EKRAN: grup karti listeyi cizer, "liste okunamadi" kalkar.
  // ------------------------------------------------------------------
  group('WP-F/6 ekran', () {
    testWidgets('uye akisi 42501 verse de grup karti uyeleri cizer', (
      tester,
    ) async {
      final repo = InMemoryAdminRepository(superAdminUserIds: const {'admin'});
      addTearDown(repo.dispose);
      repo.seedGroupMembers(_alfaId, [
        _profile(_ayseId, 'Ayşe'),
        _profile(_mehmetId, 'Mehmet'),
      ]);

      await _pump(
        tester,
        const AdminGroupsTab(),
        overrides: [
          ..._tabOverrides(repo),
          groupMembersByIdProvider(_alfaId).overrideWith((ref) => _deniedStream()),
        ],
      );

      // Govde gercek mi?
      expect(find.text('Alfa Grubu'), findsOneWidget);

      expect(
        find.text('Ayşe'),
        findsWidgets,
        reason:
            'WP-F kabul 3: yonetici uyesi olmadigi grubun uye listesini '
            'goremiyor',
      );
      expect(find.text('Mehmet'), findsWidgets);
      expect(
        find.text('Üye listesi okunamadı.'),
        findsNothing,
        reason: 'yonetici yolu calistiginda kayip metni ekranda kalmamali',
      );
    });

    testWidgets('iki kaynak da duserse kayip hala yazilir', (tester) async {
      final repo = _FailingAdminRepository(superAdminUserIds: const {'admin'});
      addTearDown(repo.dispose);

      await _pump(
        tester,
        const AdminGroupsTab(),
        overrides: [
          ..._tabOverrides(repo),
          groupMembersByIdProvider(_alfaId).overrideWith((ref) => _deniedStream()),
        ],
      );

      expect(find.text('Alfa Grubu'), findsOneWidget);
      expect(
        find.text('Üye listesi okunamadı.'),
        findsOneWidget,
        reason:
            'sessiz bos liste YOK: okunamayan liste ile bos grup ayni sey degil',
      );
    });

    testWidgets('gercekten bos grupta kayip degil "uye yok" yazar', (
      tester,
    ) async {
      final repo = InMemoryAdminRepository(superAdminUserIds: const {'admin'});
      addTearDown(repo.dispose);

      await _pump(
        tester,
        const AdminGroupsTab(),
        overrides: [
          ..._tabOverrides(repo),
          groupMembersByIdProvider(
            _alfaId,
          ).overrideWith((ref) => Stream.value(const <Profile>[])),
        ],
      );

      expect(find.text('Bu grupta görünen üye yok.'), findsOneWidget);
      expect(find.text('Üye listesi okunamadı.'), findsNothing);
    });

    testWidgets('engellenen uye yonetici gorunumunde kimliksiz kalmaz', (
      tester,
    ) async {
      final repo = InMemoryAdminRepository(superAdminUserIds: const {'admin'});
      addTearDown(repo.dispose);
      repo.seedGroupMembers(_alfaId, [_profile(_ayseId, 'Ayşe')]);

      await _pump(
        tester,
        const AdminGroupsTab(),
        overrides: [
          ..._tabOverrides(repo),
          // 0115: engellenen uye satirda kalir, adi BOSALIR.
          groupMembersByIdProvider(_alfaId).overrideWith(
            (ref) => Stream.value([_profile(_ayseId, '')]),
          ),
        ],
      );

      expect(
        find.text('Ayşe'),
        findsWidgets,
        reason:
            'yonetici kimi attigini gormeli; kisisel engel listesi moderasyonu '
            'kor etmemeli',
      );
    });

    testWidgets('yalniz anonim kaynak varsa satir bos kalmaz, kimlik yazar', (
      tester,
    ) async {
      final repo = _FailingAdminRepository(superAdminUserIds: const {'admin'});
      addTearDown(repo.dispose);

      await _pump(
        tester,
        const AdminGroupsTab(),
        overrides: [
          ..._tabOverrides(repo),
          groupMembersByIdProvider(_alfaId).overrideWith(
            (ref) => Stream.value([_profile(_ayseId, '')]),
          ),
        ],
      );

      expect(
        find.text(_ayseId),
        findsOneWidget,
        reason: 'adsiz satir tiklanabilir ama okunamaz olurdu',
      );
    });

    testWidgets('uye secici, akis dusse de uyeleri "grup uyesi" isaretler', (
      tester,
    ) async {
      final repo = InMemoryAdminRepository(superAdminUserIds: const {'admin'});
      addTearDown(repo.dispose);
      repo.seedGroupMembers(_alfaId, [_profile(_ayseId, 'Ayşe')]);

      await _pump(
        tester,
        const AdminGroupsTab(),
        overrides: [
          ..._tabOverrides(repo),
          groupMembersByIdProvider(_alfaId).overrideWith((ref) => _deniedStream()),
        ],
      );

      await tester.tap(find.text('Üye At').first);
      await tester.pumpAndSettle();

      // Secici gercek mi?
      expect(find.text('ayse@example.com'), findsOneWidget);
      expect(
        find.textContaining('Grup üyesi'),
        findsWidgets,
        reason:
            'akis dusunce herkes "yabanci" gorunuyordu; yonetici kimin uye '
            'oldugunu ayirt edemiyordu',
      );
    });
  });
}
