// WP-692 — REDDEDILEN OKUMA YARIM DAKIKA "DONEN CARK" GORUNUYOR.
//
// Olculen kusur (kaynak: `riverpod-3.3.2/lib/src/core/provider_container.dart:940`
// `ProviderContainer.defaultRetry` ve `.../core/element.dart:758` `triggerRetry`):
//   * `defaultRetry` yalniz `Error` ve `ProviderException` icin durur. Uygulamanin
//     kendi `AdminException`'i `Exception` implement eder → **10 kez** yeniden
//     denenir (200+400+800+1600+3200+6400*5 = **38.4 sn**).
//   * Bu sure boyunca element `AsyncLoading(retrying: true)` doner
//     (`element.dart:781-787`), yani ekranda **donen cark** vardir; kayip
//     yazilmaz.
//   * `element.dart:80` — `onLoading` `_futureCompleter`'i **tamamlamaz**. Yani
//     `.future` bekleyen her cagri (ve `.future`'i bekleyen her BAGLI saglayici)
//     38 saniye askida kalir.
//
// 🔴 Bu dosya SURE olcmez, **durum gecisi + cagri sayisi** olcer. Gercek bekleme
// yok: `testWidgets` FakeAsync altinda kosar, `tester.pump(Duration)` sahte saati
// ilerletir.
//
// 🔴 Kapatma TOPTAN DEGIL: gecici (ag) hatasinda yeniden deneme YARARLIDIR ve
// acik birakilmistir — WP-692/4 bunu ayri olcer.

import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/admin_audit_log.dart';
import 'package:online_study_room/data/models/admin_user_dto.dart';
import 'package:online_study_room/data/models/announcement.dart';
import 'package:online_study_room/data/models/feedback_ticket.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/models/study_group.dart';
import 'package:online_study_room/data/providers/admin_providers.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/repositories/admin_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_admin_repository.dart';

/// Sunucunun **kalici** reddi: `admin-operations` 403 doner ve depo bunu
/// `AdminException`'a sarar (`supabase_admin_repository.dart:285`).
const _denied = AdminException('Kullanıcılar alınamadı: {error: Forbidden}');

/// Ayni kalici sinif, PostgREST tarafi: RLS reddi
/// (`supabase_admin_repository.dart:388` `Gruplar alınamadı: $e`).
const _rlsDenied = AdminException(
  'Gruplar alınamadı: PostgrestException(message: permission denied for '
  'table study_groups, code: 42501)',
);

/// **Gecici** hata: ag dusmesi. `fetchUsers`'in son `catch (e)` dali
/// (`supabase_admin_repository.dart:294`) SocketException'i da ayni tipe sarar.
const _transient = AdminException(
  'Beklenmeyen hata: SocketException: Failed host lookup: '
  "'abc.supabase.co' (OS Error: No address associated with hostname)",
);

Profile _profile(String id) =>
    Profile(id: id, displayName: id, createdAt: DateTime(2026));

/// Her okuma metodunu sayan ve istenen hatayi atan depo.
class _FailingAdminRepository extends InMemoryAdminRepository {
  _FailingAdminRepository(this.error, {super.superAdminUserIds});

  final Object error;

  final Map<String, int> calls = <String, int>{};

  int callsTo(String method) => calls[method] ?? 0;

  Never _fail(String method) {
    calls[method] = callsTo(method) + 1;
    throw error;
  }

  @override
  Future<List<AdminUserDto>> fetchUsers() async => _fail('fetchUsers');

  @override
  Future<List<StudyGroup>> fetchGroups() async => _fail('fetchGroups');

  @override
  Future<List<Announcement>> fetchAnnouncements() async =>
      _fail('fetchAnnouncements');

  @override
  Future<List<AdminAuditLog>> fetchAuditLogs() async => _fail('fetchAuditLogs');

  @override
  Future<AdminDashboardSummary> fetchDashboardSummary(String userId) async =>
      _fail('fetchDashboardSummary');

  @override
  Future<List<FeedbackTicket>> fetchFeedbackTickets(
    String userId, {
    FeedbackTicketStatus? status,
    FeedbackTicketType? type,
    bool includeArchived = false,
  }) async => _fail('fetchFeedbackTickets');

  @override
  Future<List<FeedbackTicket>> fetchMyFeedbackTickets(String userId) async =>
      _fail('fetchMyFeedbackTickets');

  @override
  Future<int> fetchUnreadTicketReplyCount(String userId) async =>
      _fail('fetchUnreadTicketReplyCount');

  @override
  Future<bool> isSuperAdmin(String userId) async {
    calls['isSuperAdmin'] = callsTo('isSuperAdmin') + 1;
    return super.isSuperAdmin(userId);
  }
}

/// Yonetici kapisinin KENDISI duser (`isSuperAdmin` → `42501`).
class _FailingGateRepository extends InMemoryAdminRepository {
  _FailingGateRepository(this.error);

  final Object error;
  int isSuperAdminCalls = 0;

  @override
  Future<bool> isSuperAdmin(String userId) async {
    isSuperAdminCalls++;
    throw error;
  }
}

/// Sahte saati **10 yeniden denemenin tamamindan** (38.4 sn) fazla ilerletir.
/// Gercek bekleme yok.
Future<void> _elapseBeyondEveryRetry(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 120));
  await tester.pump();
}

Future<ProviderContainer> _container(
  WidgetTester tester,
  InMemoryAdminRepository repo, {
  String userId = 'admin',
}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  final container = ProviderContainer(
    overrides: [
      adminRepositoryProvider.overrideWithValue(repo),
      authStateProvider.overrideWith((ref) => Stream.value(_profile(userId))),
    ],
  );
  addTearDown(container.dispose);
  // Riverpod 3 tuzagi: dinleyicisi olmayan saglayici her `read`de yeniden
  // kurulur; sayaclar yaniltici olur. Abonelik ACIK tutulur.
  final authSub = container.listen(authStateProvider, (_, _) {});
  addTearDown(authSub.close);
  await container.read(authStateProvider.future);
  return container;
}

/// Saglayicinin gordugu TUM durumlari kaydeder.
List<AsyncValue<Object?>> _record<T>(
  ProviderContainer container,
  ProviderListenable<AsyncValue<T>> provider,
) {
  final states = <AsyncValue<Object?>>[];
  final sub = container.listen<AsyncValue<T>>(
    provider,
    (_, next) => states.add(next),
    fireImmediately: true,
  );
  addTearDown(sub.close);
  return states;
}

typedef _Case = ({
  String name,
  String method,
  ProviderListenable<AsyncValue<Object?>> provider,
});

final List<_Case> _adminReadCases = <_Case>[
  (name: 'adminUsersProvider', method: 'fetchUsers', provider: adminUsersProvider),
  (
    name: 'adminGroupsProvider',
    method: 'fetchGroups',
    provider: adminGroupsProvider,
  ),
  (
    name: 'adminAnnouncementsProvider',
    method: 'fetchAnnouncements',
    provider: adminAnnouncementsProvider,
  ),
  (
    name: 'adminAuditLogsProvider',
    method: 'fetchAuditLogs',
    provider: adminAuditLogsProvider,
  ),
  (
    name: 'adminDashboardSummaryProvider',
    method: 'fetchDashboardSummary',
    provider: adminDashboardSummaryProvider,
  ),
  (
    name: 'adminFeedbackTicketsProvider',
    method: 'fetchFeedbackTickets',
    provider: adminFeedbackTicketsProvider(null),
  ),
  (
    name: 'adminArchivedFeedbackTicketsProvider',
    method: 'fetchFeedbackTickets',
    provider: adminArchivedFeedbackTicketsProvider(null),
  ),
  (
    name: 'myFeedbackTicketsProvider',
    method: 'fetchMyFeedbackTickets',
    provider: myFeedbackTicketsProvider,
  ),
  (
    name: 'unreadFeedbackReplyCountProvider',
    method: 'fetchUnreadTicketReplyCount',
    provider: unreadFeedbackReplyCountProvider,
  ),
];

void main() {
  // ------------------------------------------------------------------
  // KABUL 1 + 2 — kalici hata: ILK hatada AsyncError, depo BIR kez.
  // ------------------------------------------------------------------
  group('WP-692/1 kalici hata yeniden DENENMEZ', () {
    for (final c in _adminReadCases) {
      testWidgets('${c.name}: depo 1 kez cagrilir, durum AsyncError', (
        tester,
      ) async {
        final repo = _FailingAdminRepository(
          _denied,
          superAdminUserIds: const {'admin'},
        );
        addTearDown(repo.dispose);
        final container = await _container(tester, repo);
        final states = _record(container, c.provider);

        await _elapseBeyondEveryRetry(tester);

        expect(
          repo.callsTo(c.method),
          1,
          reason:
              '${c.name}: yetki reddi tekrar denemekle DUZELMEZ; her deneme '
              'ekrandaki carki 38 saniyeye kadar uzatir',
        );
        expect(
          states.any((s) => s.isLoading && s.retrying),
          isFalse,
          reason:
              '${c.name}: `AsyncLoading(retrying: true)` = kullanicinin gordugu '
              'DONEN CARK; kalici hatada bu durum hic olusmamali',
        );
        expect(
          container.read(c.provider),
          isA<AsyncError<Object?>>(),
          reason: '${c.name}: kayip DERHAL yuzeye cikmali',
        );
      });
    }
  });

  // ------------------------------------------------------------------
  // KABUL 3 — `.future` bekleyen kod KILITLENMEZ.
  // ------------------------------------------------------------------
  group('WP-692/2 `.future` askida kalmaz', () {
    testWidgets('kalici hatada `.future` derhal firlatir', (tester) async {
      final repo = _FailingAdminRepository(
        _denied,
        superAdminUserIds: const {'admin'},
      );
      addTearDown(repo.dispose);
      final container = await _container(tester, repo);
      _record(container, adminUsersProvider);

      var settled = false;
      Object? thrown;
      unawaited(
        container
            .read(adminUsersProvider.future)
            .then(
              (_) => settled = true,
              onError: (Object e) {
                thrown = e;
                settled = true;
              },
            ),
      );

      // SADECE mikro gorevler + bir kare. Sahte saat ilk yeniden deneme
      // gecikmesinin (200 ms) COK altinda ilerletilir: retry zamanlayicisi
      // kasten atesenmez, yalniz Riverpod'un 0 sureli dispose gorevi akar.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));

      expect(
        settled,
        isTrue,
        reason:
            '`element.dart:80` — `onLoading` completer\'i tamamlamaz; retry '
            'doneminde `.future` askida kalir ve onu bekleyen her cagri '
            '(ve bagli saglayici) 38 saniye kilitlenir',
      );
      expect(thrown, isNotNull);
    });

    testWidgets('yonetici KAPISI duserse bagli saglayici da kilitlenmez', (
      tester,
    ) async {
      final repo = _FailingGateRepository(
        const AdminException(
          'Admin yetkisi kontrol edilemedi: permission denied for function '
          'is_super_admin',
        ),
      );
      addTearDown(repo.dispose);
      final container = await _container(tester, repo);
      final gateStates = _record(container, adminIsSuperAdminProvider);
      _record(container, adminGroupsProvider);

      await _elapseBeyondEveryRetry(tester);

      expect(
        repo.isSuperAdminCalls,
        1,
        reason:
            'kapi saglayicisi TUM yonetici yuzeyinin onunde durur; 10 kez '
            'denenmesi butun ekrani 38 saniye bos tutar',
      );
      expect(
        gateStates.any((s) => s.isLoading && s.retrying),
        isFalse,
      );
      expect(container.read(adminIsSuperAdminProvider), isA<AsyncError<bool>>());
      expect(
        container.read(adminGroupsProvider),
        isA<AsyncError<List<StudyGroup>>>(),
        reason: 'kapi dususe bagli liste de kayip yazmali, cark cevirmemeli',
      );
    });
  });

  // ------------------------------------------------------------------
  // KABUL 4 — kapatma SECILI: gecici hatada yeniden deneme DURUYOR.
  // ------------------------------------------------------------------
  group('WP-692/3 gecici hata hala yeniden denenir', () {
    testWidgets('ag hatasinda depo tekrar cagrilir ve durum `retrying`', (
      tester,
    ) async {
      final repo = _FailingAdminRepository(
        _transient,
        superAdminUserIds: const {'admin'},
      );
      addTearDown(repo.dispose);
      final container = await _container(tester, repo);
      final states = _record(container, adminUsersProvider);

      await _elapseBeyondEveryRetry(tester);

      expect(
        repo.callsTo('fetchUsers'),
        greaterThan(1),
        reason:
            'gecici ag hatasi tekrar denemekle DUZELIR; toptan kapatma bu '
            'kazanci da silerdi',
      );
      expect(
        states.any((s) => s.isLoading && s.retrying),
        isTrue,
        reason: 'gecici hatada `retrying` durumu beklenen davranistir',
      );
    });
  });

  // ------------------------------------------------------------------
  // Politikanin kendisi — saf birim.
  // ------------------------------------------------------------------
  group('WP-692/4 politika', () {
    test('kalici hatalar: null (yeniden deneme YOK)', () {
      expect(adminRetryPolicy(0, _denied), isNull);
      expect(adminRetryPolicy(0, _rlsDenied), isNull);
      expect(
        adminRetryPolicy(
          0,
          const AdminException('admin_required', code: 'admin_required'),
        ),
        isNull,
        reason: 'istemci kapisi reddi sunucuya hic gitmez, tekrar anlamsiz',
      );
      expect(
        adminRetryPolicy(
          0,
          const AdminException('Oturumun sona ermiş.', code: 'session_required'),
        ),
        isNull,
      );
      expect(
        adminRetryPolicy(0, const AdminException('Konu boş olamaz.')),
        isNull,
        reason: 'dogrulama hatasi tekrar denemekle duzelmez',
      );
    });

    test('gecici hatalar: yeniden denenir', () {
      expect(adminRetryPolicy(0, _transient), isNotNull);
      expect(
        adminRetryPolicy(
          0,
          const AdminException('Beklenmeyen hata: TimeoutException after 0:00:10'),
        ),
        isNotNull,
      );
      expect(
        adminRetryPolicy(
          0,
          const AdminException(
            'Kullanıcılar alınamadı: ClientException with SocketException: '
            'Connection reset by peer',
          ),
        ),
        isNotNull,
      );
    });

    test('Riverpod\'un kendi sinirlari korunur', () {
      // `defaultRetry` 10'dan sonra durur; politika bunu EZMEZ.
      expect(adminRetryPolicy(10, _transient), isNull);
      // `Error` zaten hic denenmez (`provider_container.dart:948`).
      expect(adminRetryPolicy(0, StateError('bug')), isNull);
    });
  });

  // ------------------------------------------------------------------
  // Envanter kapisi — yeni bir okuma saglayicisi politikasiz eklenemesin.
  // ------------------------------------------------------------------
  group('WP-692/5 envanter', () {
    test('dosyadaki her FutureProvider politikayi tasir', () {
      final source = File(
        'lib/data/providers/admin_providers.dart',
      ).readAsStringSync();
      // 🔴 Yalniz KOSAN satirlar olculur: aciklama satirlari (bu duzeltmeyi
      // anlatan yorumlar dahil) sayimi sahte yesile cekerdi.
      final code = source
          .split('\n')
          .where((l) => !l.trimLeft().startsWith('//'))
          .join('\n');

      final declared = RegExp(r'FutureProvider[<.]').allMatches(code).length;
      final guarded = RegExp(
        r'retry:\s*adminRetryPolicy',
      ).allMatches(code).length;

      expect(
        guarded,
        declared,
        reason:
            'her okuma saglayicisi retry politikasini tasimali; politikasiz '
            'kalan biri kalici hatada yine 38 saniye cark cevirir '
            '(bildirilen: $declared saglayici, korunan: $guarded)',
      );
      expect(declared, greaterThanOrEqualTo(11));
    });
  });
}
