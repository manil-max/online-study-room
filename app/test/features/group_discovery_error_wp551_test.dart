// WP-551: açık grup keşfinde hata yüzeyi.
//
// Düzeltmeden önce ölçülen davranış (`group_discovery_screen.dart`):
//
//   katılma → grup dolu / yasaklısın / oturum yok / ağ … HEPSİ tek cümle:
//             "Beklenmeyen bir hata oluştu." (`:113`, `on GroupException`)
//   ağ hatası (katılma) → `on GroupException` yakalamıyor, SnackBar hiç
//             çıkmıyor; hata yakalanmamış async hata olarak düşüyor
//   ağ hatası (liste)   → `_load` da `on GroupException` idi; `_error` null
//             kaldığı için kullanıcı hata yerine "Açık grup bulunamadı" boş
//             listesini görüyordu (`:233`) — yani "sunucu yok" ile "hiç grup
//             yok" ekranda ayırt edilemiyordu
//
// Bu dosya DAVRANIŞ ölçer: gerçek `GroupDiscoveryScreen` çizilir, gerçek
// `groupActionErrorText` (`core/l10n/group_error_text.dart`) koşar. Mesaj
// eşlemesi burada YENİDEN YAZILMAZ; beklenen cümleler kataloğun TR
// değerleridir, yani eşleme kopyalanırsa değil gerçekten kırılırsa kırmızı
// döner.
//
// 🔴 Riverpod 3 tuzağı (WP-532 dersi): `_join`, oturumu
// `ref.read(authStateProvider).value` ile okur. Ekran `build`inde
// `userGroupsProvider` izleniyor ve o da `authStateProvider`ı izlediği için
// provider canlı kalır; harness ayrıca gerçek ekranı kurar.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/models/study_group.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/group_providers.dart';
import 'package:online_study_room/data/repositories/group_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_group_repository.dart';
import 'package:online_study_room/features/classroom/widgets/group_discovery_screen.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Katılma ve keşif isteklerini istenen hatayla düşüren bellek-içi depo.
///
/// Sunucu sözleşmesini taklit eder: hata **kimliği** `GroupException.message`
/// içinde taşınır (`0093_group_bans.sql`), ağ hatası ise `GroupException`
/// DEĞİLDİR — Supabase repository yalnız `PostgrestException`ı sarar.
class _FailingDiscoveryRepository extends InMemoryGroupRepository {
  Object? joinFailure;
  Object? discoverFailure;
  int joinCalls = 0;

  @override
  Future<StudyGroup> joinPublicGroup({
    required String groupId,
    required Profile member,
  }) async {
    joinCalls++;
    final failure = joinFailure;
    if (failure != null) throw failure;
    return super.joinPublicGroup(groupId: groupId, member: member);
  }

  @override
  Future<List<PublicGroupSummary>> discoverPublicGroups({
    String query = '',
    String? timeZone,
    String userTimeZone = kDefaultGroupTimeZone,
    bool onlyWithCapacity = false,
    int offset = 0,
    int limit = 20,
  }) async {
    final failure = discoverFailure;
    if (failure != null) throw failure;
    return super.discoverPublicGroups(
      query: query,
      timeZone: timeZone,
      userTimeZone: userTimeZone,
      onlyWithCapacity: onlyWithCapacity,
      offset: offset,
      limit: limit,
    );
  }
}

const _kGenericMessage = 'Beklenmeyen bir hata oluştu.';

void main() {
  final owner = Profile(
    id: 'kurucu',
    displayName: 'Kurucu',
    createdAt: DateTime.utc(2026, 1, 1),
  );
  final viewer = Profile(
    id: 'uye',
    displayName: 'Uye',
    createdAt: DateTime.utc(2026, 1, 1),
  );

  Widget app(List<Override> overrides) => ProviderScope(
    overrides: overrides,
    child: const MaterialApp(
      locale: Locale('tr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: GroupDiscoveryScreen(),
    ),
  );

  /// Tek açık grup içeren keşif ekranını çizer ve depoyu döner.
  Future<_FailingDiscoveryRepository> pumpDiscovery(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = _FailingDiscoveryRepository();
    await repo.createGroup(
      name: 'Odak Kampi',
      creator: owner,
      visibility: GroupVisibility.public,
    );

    await tester.pumpWidget(
      app([
        sharedPreferencesProvider.overrideWithValue(prefs),
        groupRepositoryProvider.overrideWithValue(repo),
        authStateProvider.overrideWith((ref) => Stream.value(viewer)),
      ]),
    );
    await tester.pumpAndSettle();
    return repo;
  }

  group('gruba katılma hatası sebebini söyler', () {
    /// [failure] ile katılmayı düşürür ve SnackBar'daki cümleyi döner.
    Future<void> expectJoinMessage(
      WidgetTester tester,
      Object failure,
      String expected,
    ) async {
      final repo = await pumpDiscovery(tester);
      expect(
        find.text('Odak Kampi'),
        findsOneWidget,
        reason: 'Liste çizilmezse "Katıl" düğmesi de yoktur, test boşa koşar.',
      );
      repo.joinFailure = failure;

      await tester.tap(find.text('Katıl'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        repo.joinCalls,
        1,
        reason: 'İstek hiç gitmediyse mesaj iddiası anlamsız.',
      );
      expect(find.text(expected), findsOneWidget);
      expect(
        find.text(_kGenericMessage),
        findsNothing,
        reason: 'Eski davranış: her sebep tek genel cümleye iniyordu.',
      );
    }

    testWidgets('grup dolu', (tester) async {
      // `in_memory_group_repository.dart:261` + `0093_group_bans.sql`.
      await expectJoinMessage(
        tester,
        const GroupException('Grup dolu.'),
        'Grup dolu, yeni üye alamıyor.',
      );
    });

    testWidgets('yasaklısın', (tester) async {
      // `0093_group_bans.sql:185` kodu raise eder.
      await expectJoinMessage(
        tester,
        const GroupException('group_banned'),
        'Bu gruba katılman engellendi.',
      );
    });

    testWidgets('oturum yok', (tester) async {
      await expectJoinMessage(
        tester,
        const GroupException('not_authenticated'),
        'Oturum bulunamadı. Yeniden giriş yap.',
      );
    });

    testWidgets('ağ hatası', (tester) async {
      // `GroupException` DEĞİL: eski `on GroupException` bunu hiç yakalamıyordu,
      // kullanıcı hiçbir geri bildirim görmüyordu.
      await expectJoinMessage(
        tester,
        Exception('SocketException: Failed host lookup'),
        'Sunucuya ulaşılamadı. Bağlantını kontrol edip tekrar dene.',
      );
    });

    testWidgets('dört sebep dört ayrı cümle üretir', (tester) async {
      // Tek tek iddialar geçse bile ikisi aynı cümleye düşerse ayırt etme
      // kazanımı yoktur; küme boyu bunu kilitler.
      final messages = <String>{};
      for (final failure in <Object>[
        const GroupException('Grup dolu.'),
        const GroupException('group_banned'),
        const GroupException('not_authenticated'),
        Exception('SocketException: Failed host lookup'),
      ]) {
        // 🔴 Ara temizlik şart: aynı `tester` üzerinde ikinci kez `pumpWidget`
        // çağırmak `ScaffoldMessenger`ı (ve ekran `State`ini) yeniden kullanır,
        // 4 sn'lik ilk SnackBar hâlâ ekranda kalır ve dört ölçüm de BİRİNCİ
        // cümleyi okurdu — yalancı "hepsi aynı" sonucu.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        final repo = await pumpDiscovery(tester);
        repo.joinFailure = failure;
        await tester.tap(find.text('Katıl'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        final snackBar = find.descendant(
          of: find.byType(SnackBar),
          matching: find.byType(Text),
        );
        expect(snackBar, findsOneWidget);
        messages.add(tester.widget<Text>(snackBar).data!);
      }
      expect(messages.length, 4, reason: 'Ayrışan sebepler: $messages');
      expect(messages, isNot(contains(_kGenericMessage)));
    });
  });

  group('liste yüklenemezse', () {
    testWidgets('ağ hatası boş liste değil hata yüzeyi gösterir', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = _FailingDiscoveryRepository();
      await repo.createGroup(
        name: 'Odak Kampi',
        creator: owner,
        visibility: GroupVisibility.public,
      );
      repo.discoverFailure = Exception('SocketException: Failed host lookup');

      await tester.pumpWidget(
        app([
          sharedPreferencesProvider.overrideWithValue(prefs),
          groupRepositoryProvider.overrideWithValue(repo),
          authStateProvider.overrideWith((ref) => Stream.value(viewer)),
        ]),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Sunucuya ulaşılamadı. Bağlantını kontrol edip tekrar dene.'),
        findsOneWidget,
      );
      expect(
        find.text('Açık grup bulunamadı'),
        findsNothing,
        reason:
            'Eski davranış: `_error` null kaldığı için "sunucu yok" ile '
            '"hiç grup yok" aynı ekranı veriyordu.',
      );
      expect(find.text('Tekrar dene'), findsOneWidget);
    });

    testWidgets('sunucu hatası kendi sebebini söyler', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = _FailingDiscoveryRepository();
      repo.discoverFailure = const GroupException('not_authenticated');

      await tester.pumpWidget(
        app([
          sharedPreferencesProvider.overrideWithValue(prefs),
          groupRepositoryProvider.overrideWithValue(repo),
          authStateProvider.overrideWith((ref) => Stream.value(viewer)),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.text('Oturum bulunamadı. Yeniden giriş yap.'), findsOneWidget);
      expect(find.text(_kGenericMessage), findsNothing);
      expect(find.text('Açık grup bulunamadı'), findsNothing);
    });
  });
}
