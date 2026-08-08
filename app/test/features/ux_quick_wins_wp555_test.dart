// WP-555: dort kucuk UX borcu. Hepsi DAVRANIS olcer -- kaynak taramasi yok.
//
// Duzeltmeden ONCE olculen davranis:
//
//   1) `session_history_screen.dart:30,55-58,72,90` -- grubu olmayan kullanici
//      kendi calisma gecmisini goremiyor ("once bir gruba katil"), FAB gizli.
//      Yapay kapiydi: `addManualSessionFlow` grup sarti aramaz ve ayni akis
//      sayac kartindan grupsuz da calisiyordu.
//   2) `settings_screen.dart` icinde `goal` kelimesi hic gecmiyordu; gunluk
//      hedef yalnizca sayac kartindan degistirilebiliyordu.
//   3) `group_discovery_screen.dart:139` -- `onChanged: (_) => _load()`,
//      debounce yok: "mate" yazmak 4 RPC uretiyordu.
//
// Sabotaj: ilgili duzeltme geri alinirsa bu dosya kirmizi doner (WP karti).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/models/study_group.dart';
import 'package:online_study_room/data/models/study_session.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/group_providers.dart';
import 'package:online_study_room/data/providers/study_providers.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_auth_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_group_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_study_repository.dart';
import 'package:online_study_room/features/classroom/widgets/group_discovery_screen.dart';
import 'package:online_study_room/features/profile/session_history_screen.dart';
import 'package:online_study_room/features/profile/settings_screen.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/istanbul_fixture.dart';

/// `discoverPublicGroups` cagri sayacini tutan kesif deposu (IS 3).
class _CountingDiscoveryRepository extends InMemoryGroupRepository {
  int discoverCalls = 0;
  final queries = <String>[];

  @override
  Future<List<PublicGroupSummary>> discoverPublicGroups({
    String query = '',
    String? timeZone,
    String userTimeZone = kDefaultGroupTimeZone,
    bool onlyWithCapacity = false,
    int offset = 0,
    int limit = 20,
  }) async {
    discoverCalls++;
    queries.add(query);
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

/// `updateDailyGoal` cagrilarini sayan bellek-ici auth deposu (IS 2).
class _CountingAuthRepository extends InMemoryAuthRepository {
  int goalCalls = 0;
  int? lastGoalMinutes;

  @override
  Future<void> updateDailyGoal(int minutes) async {
    goalCalls++;
    lastGoalMinutes = minutes;
    await super.updateDailyGoal(minutes);
  }
}

void main() {
  Widget app(List<Override> overrides, Widget home) => ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      locale: const Locale('tr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  );

  group('IS 1 - grupsuz kullanici kendi gecmisini gorur', () {
    testWidgets('liste ve manuel ekleme yolu grupsuz da erisilebilir', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final user = Profile(
        id: 'yalniz',
        displayName: 'Yalniz',
        createdAt: DateTime.utc(2026, 1, 1),
      );
      final groups = InMemoryGroupRepository(); // hic grup yok
      final study = InMemoryStudyRepository();
      final now = DateTime.now();
      await study.addSession(
        StudySession(
          id: 'oturum-1',
          userId: user.id,
          // 🔴 WP-565: gece yarisi tuzagi -- bkz. support/istanbul_fixture.dart.
          // Test oturumun BUGUN listesinde gorunmesini bekler; 00:00-01:00
          // arasinda `now - 1 saat` DUNE duser ve oturum `_PastDayTile`a
          // katlanir. Olculdu (2026-08-09): 00:5x kirmizi, 01:04 yesil.
          start: agoWithinIstanbulToday(const Duration(hours: 1), now: now),
          end: now,
          durationSeconds: 3600,
          source: StudySource.manual,
        ),
      );

      await tester.pumpWidget(
        app([
          sharedPreferencesProvider.overrideWithValue(prefs),
          authStateProvider.overrideWith((ref) => Stream.value(user)),
          groupRepositoryProvider.overrideWithValue(groups),
          studyRepositoryProvider.overrideWithValue(study),
        ], const SessionHistoryScreen()),
      );
      await tester.pumpAndSettle();

      // On kosul: kullanicinin gercekten grubu yok.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SessionHistoryScreen)),
      );
      expect(container.read(userGroupProvider).value, isNull);

      // Kayit satiri gorunur (manuel oturum ikonu).
      expect(find.byIcon(Icons.edit_calendar), findsOneWidget);
      expect(find.text('Henüz kaydın yok.'), findsNothing);
      expect(
        find.text('Kayıt eklemek için önce bir gruba katıl veya grup oluştur.'),
        findsNothing,
      );

      // Ekleme yolu da acik: FAB var ve manuel diyalogu aciyor.
      final fab = find.widgetWithText(FloatingActionButton, 'Manuel ekle');
      expect(fab, findsOneWidget);
      await tester.tap(fab);
      await tester.pumpAndSettle();
      expect(find.text('Manuel süre ekle'), findsOneWidget);

      await tester.tap(find.text('Vazgeç'));
      await tester.pumpAndSettle();
    });
  });

  group('IS 2 - gunluk hedef Ayarlar ekranindan degistirilebilir', () {
    Future<_CountingAuthRepository> pumpSettings(WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final auth = _CountingAuthRepository();
      addTearDown(auth.dispose);
      await auth.signUp(
        email: 'ben@example.com',
        password: 'gizli123',
        displayName: 'Ben',
      );
      // 🔴 800dp genislik bilincli secildi. `goal_editor_dialog.dart` 360dp'de
      // 8px RenderFlex tasmasi uretiyor (AlertDialog 280dp minimuma kilitlenip
      // iki `NumberStepper`a 110dp birakiyor) -- WP-555'ten ONCE de vardi ve o
      // dosya bu WP'nin SAHIP yolu degil. `wp85_l10n_test` de ayni diyalogu
      // varsayilan 800dp'de aciyor. Bu test hedef akisini olcer, diyalogun dar
      // ekran yerlesimini degil; tasma ayri kart olarak raporlandi.
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        app([
          sharedPreferencesProvider.overrideWithValue(prefs),
          authRepositoryProvider.overrideWithValue(auth),
        ], const SettingsScreen()),
      );
      await tester.pumpAndSettle();
      return auth;
    }

    Finder dialogIcon(IconData icon) => find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byIcon(icon),
    );

    testWidgets('satir vardir, diyalog acilir ve yeni deger yansir', (
      tester,
    ) async {
      final auth = await pumpSettings(tester);
      final row = find.byKey(const Key('settings-daily-goal'));
      expect(row, findsOneWidget);
      // Varsayilan 360 dk = 6 saat, satirda okunur.
      expect(
        find.descendant(of: row, matching: find.text('6sa')),
        findsOneWidget,
      );

      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);

      // Dakika sutununun "+" tusu: diyalogdaki ikinci artirma dugmesi.
      await tester.tap(dialogIcon(Icons.add).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();

      expect(auth.goalCalls, 1);
      expect(auth.lastGoalMinutes, 361);
      expect(auth.currentUser?.dailyGoalMinutes, 361);
      expect(
        find.descendant(of: row, matching: find.text('6sa 1dk')),
        findsOneWidget,
      );
    });

    testWidgets('gecersiz (15 dk alti) deger reddedilir', (tester) async {
      final auth = await pumpSettings(tester);
      await tester.tap(find.byKey(const Key('settings-daily-goal')));
      await tester.pumpAndSettle();

      // 6 sa 0 dk -> 0 sa 0 dk.
      for (var i = 0; i < 6; i++) {
        await tester.tap(dialogIcon(Icons.remove).first);
        await tester.pumpAndSettle();
      }

      final save = find.widgetWithText(FilledButton, 'Kaydet');
      expect(tester.widget<FilledButton>(save).onPressed, isNull);
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(auth.goalCalls, 0);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(auth.currentUser?.dailyGoalMinutes, 360);

      await tester.tap(find.text('Vazgeç'));
      await tester.pumpAndSettle();
    });
  });

  group('IS 3 - grup aramasi her tusa istek atmaz', () {
    testWidgets('hizli yazilan dort harf tek sunucu istegi uretir', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = _CountingDiscoveryRepository();
      final owner = Profile(
        id: 'kurucu',
        displayName: 'Kurucu',
        createdAt: DateTime.utc(2026, 1, 1),
      );
      await repo.createGroup(
        name: 'Matematik Kampi',
        creator: owner,
        visibility: GroupVisibility.public,
      );
      final viewer = Profile(
        id: 'uye',
        displayName: 'Uye',
        createdAt: DateTime.utc(2026, 1, 1),
      );

      await tester.pumpWidget(
        app([
          sharedPreferencesProvider.overrideWithValue(prefs),
          groupRepositoryProvider.overrideWithValue(repo),
          authStateProvider.overrideWith((ref) => Stream.value(viewer)),
        ], const GroupDiscoveryScreen()),
      );
      await tester.pumpAndSettle();
      expect(repo.discoverCalls, 1, reason: 'ilk acilis tek istek');

      final field = find.byType(TextField);
      for (final text in const ['m', 'ma', 'mat', 'mate']) {
        await tester.enterText(field, text);
        await tester.pump(const Duration(milliseconds: 60));
      }
      // Debounce penceresi henuz dolmadi: hala tek istek.
      expect(repo.discoverCalls, 1);

      await tester.pump(kGroupDiscoverySearchDebounce);
      await tester.pumpAndSettle();

      expect(repo.discoverCalls, 2, reason: 'yazma bitince tek istek gider');
      expect(repo.queries.last, 'mate');
    });

    testWidgets('bekleyen debounce ekran kapaninca hata uretmez', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = _CountingDiscoveryRepository();
      final viewer = Profile(
        id: 'uye',
        displayName: 'Uye',
        createdAt: DateTime.utc(2026, 1, 1),
      );

      final errors = <FlutterErrorDetails>[];
      final previous = FlutterError.onError;
      FlutterError.onError = errors.add;

      await tester.pumpWidget(
        app([
          sharedPreferencesProvider.overrideWithValue(prefs),
          groupRepositoryProvider.overrideWithValue(repo),
          authStateProvider.overrideWith((ref) => Stream.value(viewer)),
        ], const GroupDiscoveryScreen()),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'mat');
      await tester.pump(const Duration(milliseconds: 60));
      // Ekran, zamanlayici atesleneden kapanir.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      FlutterError.onError = previous;
      expect(errors.map((detail) => detail.exceptionAsString()), isEmpty);
      expect(repo.discoverCalls, 1);
    });
  });
}
