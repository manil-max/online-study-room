// WP-799 — YENİ KULLANICININ İLK GÖRDÜĞÜ ÖLÜ UÇLAR.
//
// 🔴 Bu dosyanın varlık sebebi: uygulamayı ilk açan kullanıcının okuduğu
// cümleler ve bastığı düğmeler hiçbir kapı tarafından ölçülmüyordu. Denetimin
// bulduğu ölü uçların ortak deseni "kod doğru duruyor ama kullanıcının GÖRDÜĞÜ
// satır yanlış" idi:
//
//   1. `today_summary_card` kompakt dalı "Kayıt yok" yazıyordu; aynı kartın tam
//      boy dalı aynı durumda "Bugün henüz çalışma kaydın yok. Sayaçtan başla!"
//      diyordu. Varsayılan panoda kart 393 dp telefonda kompakt dala düşüyor,
//      yani ölü ucu HER yeni kullanıcı görüyordu.
//   2. `scatter_card` aynı l10n anahtarını başlık ve alt satır olarak İKİ KEZ
//      yazıyordu.
//   3. `tasks_card` boş dalı `_EmptyTasks`in eylem parametresini geçmiyordu.
//   4. `personal_stats_view` boş durumu aynı şeyi iki kez söylüyor, hiçbir çıkış
//      sunmuyordu.
//   5. Onboarding'in son düğmesi "Kamp ateşine git" diyor ama Ana Sayfa'ya
//      götürüyordu — aynı sayfanın gövdesiyle çelişerek.
//   6. `timers_screen` boş durumu çıplak bir cümleydi: ne yapılacağı yazmıyordu.
//   7. `subjects_screen` boş durumuna bir FORM ALANI etiketi yapıştırılmıştı.
//   8. `class_switcher` grubu olmayana `enabled: false` bir satır gösteriyordu;
//      `switchOnly` kolunda menünün tamamı tıklanamaz oluyordu.
//
// Ölçüt her yerde aynı: EKRANDA hangi metin var, düğmeye basınca ne oluyor.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/l10n/app_locale.dart';
import 'package:online_study_room/core/navigation/nav_index.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/models/study_session.dart';
import 'package:online_study_room/data/models/subject.dart';
import 'package:online_study_room/data/models/user_study_summary.dart';
import 'package:online_study_room/data/providers/alarm_providers.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/group_providers.dart';
import 'package:online_study_room/data/providers/study_providers.dart';
import 'package:online_study_room/data/providers/subject_providers.dart';
import 'package:online_study_room/data/providers/user_task_providers.dart';
import 'package:online_study_room/data/models/study_group.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_alarm_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_auth_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_user_task_repository.dart';
import 'package:online_study_room/features/home/dashboard_card.dart';
import 'package:online_study_room/features/home/dashboard_providers.dart';
import 'package:online_study_room/features/home/widgets/scatter_card.dart';
import 'package:online_study_room/features/home/widgets/tasks_card.dart';
import 'package:online_study_room/features/home/widgets/today_summary_card.dart';
import 'package:online_study_room/features/classroom/widgets/class_switcher.dart';
import 'package:online_study_room/features/clock/timers_screen.dart';
import 'package:online_study_room/features/onboarding/onboarding_screen.dart';
import 'package:online_study_room/features/profile/subjects_screen.dart';
import 'package:online_study_room/features/stats/widgets/personal_stats_view.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../support/istanbul_fixture.dart';

final _me = Profile(
  id: 'me-1',
  displayName: 'Sahip',
  createdAt: DateTime(2026, 1, 1),
);

const _subjects = <Subject>[
  Subject(id: 'sub-1', userId: 'me-1', name: 'Matematik', color: 'chart-1'),
];

/// 🔴 Hücre ölçüsü ELLE YAZILMAZ, ürünün kendi düzeninden türetilir.
///
/// Sabit bir `SizedBox(width: 176)` yazsaydık pano matematiği değiştiğinde test
/// yeşil kalmaya devam eder, kullanıcı yine ölü ucu görürdü. Kaynaklar:
/// `defaultDashboardLayout` (kart kaç hücre), `dashboardGridColumnsProvider`
/// (32 sütun), `home_screen.dart` (yatay kenar boşluğu 16, hücre arası 8).
({double width, double height}) _defaultTodayCell({double screenWidth = 393}) {
  const columns = 32;
  const gap = 8.0;
  const horizontalPadding = 16.0;
  final gridWidth = screenWidth - 2 * horizontalPadding;
  final cell = (gridWidth - (columns - 1) * gap) / columns;
  final config = defaultDashboardLayout(
    columns,
  ).firstWhere((c) => c.type == DashboardCardType.today);
  return (
    width: config.w * cell + (config.w - 1) * gap,
    height: config.h * cell + (config.h - 1) * gap,
  );
}

Future<void> _pumpCard(
  WidgetTester tester,
  Widget card, {
  required double width,
  required double height,
  List<StudySession> sessions = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authStateProvider.overrideWith((ref) => Stream.value(_me)),
        userSessionsProvider.overrideWith((ref) => Stream.value(sessions)),
        userSubjectsProvider.overrideWith((ref) => Stream.value(_subjects)),
      ],
      child: MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: SizedBox(width: width, height: height, child: card),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets(
    '(1) varsayilan pano hucresinde "Kayit yok" YOK, dogru cumle VAR',
    (tester) async {
      final cell = _defaultTodayCell();

      // Kompakt dala neden düşüldüğü ölçümle yazılı dursun: eşik
      // `today_summary_card.dart` içinde 180 px.
      expect(
        cell.width,
        lessThan(180),
        reason:
            'Varsayilan panoda "Bugun ozeti" karti 393 dp telefonda '
            '${cell.width.toStringAsFixed(1)} px; 180 esiginin altinda oldugu '
            'icin KOMPAKT dal cizilir. Bu iddia duserse test artik denetimin '
            'buldugu dali olcmuyordur.',
      );

      await _pumpCard(
        tester,
        const TodaySummaryCard(),
        width: cell.width,
        height: cell.height,
      );
      final l10n = await AppLocalizations.delegate.load(const Locale('tr'));

      expect(
        find.text(l10n.homeKayitYok),
        findsNothing,
        reason:
            'Yeni kullanici ana ekranda "Kayit yok" gormemeli: bu cumle ne '
            'olduguna dair bir sey soylemiyor ve hicbir yere goturmuyor.',
      );
      expect(
        find.text(l10n.homeBugunHenuzCalismaKaydin),
        findsOneWidget,
        reason:
            'Kompakt dal, tam boy dalin kurdugu cumleyi kurmali (ne oldugu + '
            'ne yapilacagi).',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('(1b) kayit varken kompakt dal bos durum cumlesi YAZMAZ', (
    tester,
  ) async {
    final cell = _defaultTodayCell();
    await _pumpCard(
      tester,
      const TodaySummaryCard(),
      width: cell.width,
      height: cell.height,
      sessions: [
        StudySession(
          id: 's-1',
          userId: _me.id,
          subjectId: 'sub-1',
          // 🔴 WP-821: `now - 2sa` gece 00:00–02:00 kosumunda oturumu DUNE
          // dusuruyordu; bugunun toplami 0 cikip test kirmizi doner.
          // `agoWithinIstanbulToday` (WP-565) tam bunun icin var.
          start: agoWithinIstanbulToday(const Duration(hours: 2)),
          end: agoWithinIstanbulToday(const Duration(hours: 1)),
          durationSeconds: 3600,
          source: StudySource.live,
        ),
      ],
    );
    final l10n = await AppLocalizations.delegate.load(const Locale('tr'));

    expect(find.text(l10n.homeBugunHenuzCalismaKaydin), findsNothing);
    expect(find.text(l10n.homeDersSayisi(1)), findsOneWidget);
  });

  testWidgets('(2) "Oturum dagilimi" basligi ekranda BIR kez gorunuyor', (
    tester,
  ) async {
    await _pumpCard(
      tester,
      const ScatterCard(),
      width: 340,
      height: 260,
      sessions: [
        StudySession(
          id: 's-1',
          userId: _me.id,
          // 🔴 WP-821: `now - 2sa` gece 00:00–02:00 kosumunda oturumu DUNE
          // dusuruyordu; bugunun toplami 0 cikip test kirmizi doner.
          // `agoWithinIstanbulToday` (WP-565) tam bunun icin var.
          start: agoWithinIstanbulToday(const Duration(hours: 2)),
          end: agoWithinIstanbulToday(const Duration(hours: 1)),
          durationSeconds: 3600,
          source: StudySource.live,
        ),
      ],
    );
    final l10n = await AppLocalizations.delegate.load(const Locale('tr'));

    expect(
      find.text(l10n.homeOturumDagilimi),
      findsOneWidget,
      reason:
          'Ayni l10n anahtari basligin altina ikinci kez yazilmisti; ekranda '
          'ayni cumle alt alta iki kez gorunuyordu.',
    );
  });

  testWidgets(
    '(3) gorev karti bos dalinda cikis var ve Araclar sekmesine goturuyor',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = InMemoryUserTaskRepository();
      late ProviderContainer container;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            authStateProvider.overrideWith((ref) => Stream.value(_me)),
            userTaskRepositoryProvider.overrideWithValue(repo),
          ],
          child: MaterialApp(
            locale: const Locale('tr'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: Center(
                child: SizedBox(width: 360, height: 420, child: TasksCard()),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      container = ProviderScope.containerOf(
        tester.element(find.byType(TasksCard)),
      );

      final l10n = await AppLocalizations.delegate.load(const Locale('tr'));
      expect(find.text(l10n.taskListEmpty), findsOneWidget);

      final action = find.byKey(const Key('tasks-card-empty-action'));
      expect(
        action,
        findsOneWidget,
        reason:
            '`_EmptyTasks` eylem parametresini destekliyor ama bos dal onu hic '
            'gecmiyordu: kullanici "Henuz gorev yok" cumlesiyle basbasa kaliyordu.',
      );
      expect(container.read(navIndexProvider), AppTab.home.index);

      await tester.tap(action);
      await tester.pumpAndSettle();

      expect(
        container.read(navIndexProvider),
        AppTab.tools.index,
        reason:
            'Eylem gorevlerin gercek ekranina goturmeli (Araclar sekmesi); '
            'kart bilerek bir ekleme yuzeyi degil.',
      );
      // Home kartinda hala ekleme YOK (WP-199 sozlesmesi bozulmadi).
      expect(find.byIcon(Icons.add), findsNothing);
    },
  );

  testWidgets('(4) kisisel istatistik bos durumu Ana Sayfa sekmesine goturuyor', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    late ProviderContainer container;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authStateProvider.overrideWith((ref) => Stream.value(_me)),
          userSessionsProvider.overrideWith(
            (ref) => Stream.value(const <StudySession>[]),
          ),
          userSubjectsProvider.overrideWith((ref) => Stream.value(_subjects)),
          userStudySummaryProvider.overrideWith(
            (ref) async => UserStudySummary.empty,
          ),
        ],
        child: MaterialApp(
          locale: const Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: PersonalStatsView(sessions: <StudySession>[]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    container = ProviderScope.containerOf(
      tester.element(find.byType(PersonalStatsView)),
    );

    final l10n = await AppLocalizations.delegate.load(const Locale('tr'));
    expect(find.text(l10n.statsHenuzCalismaKaydinYok), findsOneWidget);
    expect(
      find.text(l10n.statsBuDonemdeCalismaKaydin),
      findsNothing,
      reason: 'Bos durum ayni seyi iki kez soylemesin.',
    );

    final start = find.byKey(const Key('stats-personal-empty-start'));
    expect(
      start,
      findsOneWidget,
      reason:
          'Ayni ekranin grup dali (`stats-group-empty-join`) bos durumda cikis '
          'sunuyor; kisisel dal unutulmustu.',
    );
    expect(find.text(l10n.statsKisiselBosEylem), findsOneWidget);

    // Sekmeyi baska bir yere alip dugmenin GERCEKTEN Ana Sayfa'ya
    // goturdugunu olc; baslangic degeri zaten home oldugu icin dugme hic
    // calismasa da yesil gorunurdu.
    container.read(navIndexProvider.notifier).setTab(AppTab.stats);
    await tester.pump();
    expect(container.read(navIndexProvider), AppTab.stats.index);

    await tester.tap(start);
    await tester.pumpAndSettle();
    expect(container.read(navIndexProvider), AppTab.home.index);
  });

  testWidgets('(5) onboarding son dugmesi gittigi yeri soyluyor', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(393, 850);
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({
      'app_language_preference': AppLanguage.turkish.name,
    });
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authRepositoryProvider.overrideWithValue(InMemoryAuthRepository()),
        ],
        child: MaterialApp(
          locale: const Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const OnboardingScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final l10n = await AppLocalizations.delegate.load(const Locale('tr'));
    await tester.tap(find.text(l10n.onboardingContinue));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.onboardingNotNow));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.onboardingSkipGroup));
    await tester.pumpAndSettle();

    expect(find.text(l10n.onboardingReadyTitle), findsOneWidget);
    expect(find.text(l10n.onboardingReadyBody), findsOneWidget);
    expect(
      find.text(l10n.onboardingStart),
      findsNothing,
      reason:
          '"Kamp atesine git" bir yalandi: `_finish` yalniz onboarding '
          'bayragini yazar, `HomeShell` varsayilan sekmesi `home`dur ve kamp '
          'atesi `groups` sekmesindedir.',
    );
    expect(
      find.text(l10n.classroomCalismayaBasla),
      findsOneWidget,
      reason: 'Dugme adi ayni sayfanin govdesiyle ayni seyi soylemeli.',
    );
  });

  testWidgets('(6) bos zamanlayici listesi NE YAPILACAGINI soyluyor', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          alarmRepositoryProvider.overrideWithValue(InMemoryAlarmRepository()),
        ],
        child: const MaterialApp(
          locale: Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: TimersScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('tr'));
    expect(find.text(l10n.clockHenuzCalisanBirTimer), findsOneWidget);
    expect(
      find.text(l10n.clockTimerBosIpucu),
      findsOneWidget,
      reason:
          'Bos durum ciplak bir cumleydi: kullanici zamanlayiciyi NASIL '
          'baslatacagini ekrandan okuyamiyordu.',
    );
  });

  testWidgets('(7) bos ders listesi form etiketi yapistirmiyor', (
    tester,
  ) async {
    // "Genel" sanal dersi gizli: bos durum dali yalniz o zaman cizilir
    // (`subjects.isEmpty && !generalVisible`).
    SharedPreferences.setMockInitialValues({
      generalSubjectHiddenKey(_me.id): true,
    });
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authStateProvider.overrideWith((ref) => Stream.value(_me)),
          userSubjectsProvider.overrideWith(
            (ref) => Stream.value(const <Subject>[]),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SubjectsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('tr'));
    expect(find.text(l10n.profileHenuzDersinYok), findsOneWidget);
    expect(
      find.textContaining(l10n.profileDersOpsiyonel),
      findsNothing,
      reason:
          '"Ders (opsiyonel)" bir FORM ALANI etiketidir; govde metnine '
          'yapistirilinca hicbir sey anlatmaz.',
    );
    // Cikis yolu ekranin kendi FAB'idir; bos durum cikissiz degil.
    expect(find.text(l10n.profileDersEkle), findsOneWidget);
  });

  testWidgets('(8) grup yokken gecis menusu tiklanabilir bir cikis veriyor', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(_me)),
          userGroupsProvider.overrideWith(
            (ref) => Stream.value(const <StudyGroup>[]),
          ),
          userGroupProvider.overrideWithValue(
            const AsyncData<StudyGroup?>(null),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => Center(
                child: TextButton(
                  onPressed: () =>
                      showClassSwitcher(context, ref, switchOnly: true),
                  child: const Text('ac'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('ac'));
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('tr'));
    expect(
      find.text(l10n.classroomHenuzGrupYok),
      findsNothing,
      reason:
          '`switchOnly` kolunda olustur/katil maddeleri hic cizilmez, yani '
          '`enabled: false` bir satir menunun TAMAMINI tiklanamaz yapiyordu.',
    );
    expect(find.text(l10n.classroomGrupOlustur), findsOneWidget);

    // Olu ucun kaniti tiklamadir: satir gercekten bir sey aciyor mu?
    await tester.tap(find.text(l10n.classroomGrupOlustur));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('create-group-submit')), findsOneWidget);
  });
}
