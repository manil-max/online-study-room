// WP-508 (v59 saha maddesi 1): Ana Sayfa kartlarının içindeki "kaydırıyorum ama
// kaymıyor" tuzağı.
//
// 🔴 Kök neden bir çizim hatası değil, bir **jest** hatasıydı: pano hücresi her
// karta sabit piksel yükseklik verir (`dashboard_card.dart` → `SizedBox`), kart
// da o sınırlı kutuda **koşulsuz** bir kaydırıcı kurardı. Flutter'da en içteki
// `Scrollable` dikey sürüklemeyi gesture arena'da kazanır; içerik zaten sığdığı
// için hiçbir şey oynamaz ve **dış sayfa da kaymaz**. Android'in stretch
// overscroll'u bu sırada tetiklendiği için sahibin gördüğü "kaydırma animasyonu
// var ama sayfa kaymıyor" görüntüsü çıkardı.
//
// `ListView`ler ayrıca ikinci kez ısırıyordu: `physics`/`primary`/`controller`
// verilmemiş dikey bir `ScrollView` **`AlwaysScrollableScrollPhysics`**a düşer
// (`scroll_view.dart`), yani "içerik dışarı taşmıyorsa jesti bırak" varsayılan
// kuralı bile devre dışı kalır.
//
// ⚠️ Bu dosya "kart hiç kaydırmasın" demiyor — o çözüm WP-497'de bilerek
// düzeltilen "sığmayan üye tamamen kayboluyor" hatasını geri getirirdi. Ölçülen
// şey sahibin bağlayıcı kuralı: **sığıyorsa dış sayfa akar, taşıyorsa kart içi
// kayar.** İki yarım da burada kanıtlanır; yalnız birincisi test edilirse
// düzeltme ikinci yarımı sessizce kırabilir.
//
// Mevcut `test/features/classroom/group_scroll_nesting_test.dart` yalnız
// **sınırsız** yükseklik yolunu (Gruplar listesi) koruyordu; hata tam bu
// boşluktan, sınırlı hücreden girdi.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// `Override` tipi ana pakette değil (Riverpod 3): yardımcıların imzası için.
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/core/stats/istanbul_calendar.dart';
import 'package:online_study_room/data/models/presence.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/models/study_group.dart';
import 'package:online_study_room/data/models/study_session.dart';
import 'package:online_study_room/data/models/subject.dart';
import 'package:online_study_room/data/models/user_task.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/group_providers.dart';
import 'package:online_study_room/data/providers/presence_providers.dart';
import 'package:online_study_room/data/providers/study_providers.dart';
import 'package:online_study_room/data/providers/subject_providers.dart';
import 'package:online_study_room/data/providers/user_task_providers.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_user_task_repository.dart';
import 'package:online_study_room/features/home/widgets/active_members_card.dart';
import 'package:online_study_room/features/home/widgets/card_scaffold.dart';
import 'package:online_study_room/features/home/widgets/goal_card.dart';
import 'package:online_study_room/features/home/widgets/period_summary_card.dart';
import 'package:online_study_room/features/home/widgets/records_card.dart';
import 'package:online_study_room/features/home/widgets/tasks_card.dart';
import 'package:online_study_room/features/home/widgets/today_summary_card.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/istanbul_fixture.dart';

final _group = StudyGroup(
  id: 'g-1',
  name: 'Odak Grubu',
  inviteCode: 'ABC123',
  createdBy: 'u1',
  createdAt: DateTime(2026, 1, 1),
);

Profile _member(int i) =>
    Profile(id: 'u$i', displayName: 'Uye $i', createdAt: DateTime(2026, 1, 1));

Presence _studying(int i) => Presence(
  userId: 'u$i',
  groupId: _group.id,
  status: PresenceStatus.studying,
  todaySeconds: 600,
  startedAt: DateTime(2026, 1, 1, 9).add(Duration(minutes: i)),
);

/// Ana Sayfa'nın gerçek kabuğu: dış sayfa kaydırıcısı + karta **sabit piksel
/// yükseklik** veren hücre. Kabuğu taklit etmeyen kurulum bu hatayı göremez —
/// kart sınırsız yükseklikte zaten doğru davranıyordu.
Future<ScrollController> _pumpHomeCell(
  WidgetTester tester, {
  required Widget card,
  List<Override> overrides = const [],
  double cellHeight = 260,
  double cellWidth = 360,
}) async {
  final outer = ScrollController();
  addTearDown(outer.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            controller: outer,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                SizedBox(width: cellWidth, height: cellHeight, child: card),
                // Dış sayfanın gerçekten kayacak yeri olsun.
                const SizedBox(height: 1200),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  // Akışların (presence/üye/rütbe) yerine oturması için iki kare.
  // `pumpAndSettle` kullanılmıyor: `SecondTicker` saniyelik periyodik timer
  // kurar, sahne hiç durulmaz.
  await tester.pump();
  await tester.pump();
  return outer;
}

/// Kartın **kendi** kaydırma pozisyonu (varsa).
ScrollPosition? _innerPosition(WidgetTester tester, Finder card) {
  final inner = find.descendant(of: card, matching: find.byType(Scrollable));
  if (inner.evaluate().isEmpty) return null;
  return tester.state<ScrollableState>(inner.first).position;
}

/// Kartın üstünden yukarı sürükler ve dış sayfanın gerçekten kaydığını ölçer.
///
/// Önce kurulumun gerçekten **sığan** tarafta olduğunu doğrular: kart taşıyorsa
/// içeride kayması zaten doğru davranıştır ve bu iddia yanlış yerde ölçüm yapar.
Future<void> _expectOuterScrolls(
  WidgetTester tester,
  ScrollController outer,
  Finder card, {
  required String label,
}) async {
  expect(outer.offset, 0, reason: '$label: kurulum bozuk, sayfa baştan kaymış');
  final inner = _innerPosition(tester, card);
  if (inner != null) {
    expect(
      inner.maxScrollExtent,
      0,
      reason:
          '$label: kurulum bozuk — içerik hücreye sığmıyor, test "sığan içerik" '
          'kuralını ölçmüyor. Hücreyi büyüt.',
    );
  }
  await tester.drag(card, const Offset(0, -200));
  await tester.pump();

  expect(
    outer.offset,
    greaterThan(0),
    reason:
        '$label: parmak kartın üstündeyken dış sayfa kaymadı. Kart, içerik '
        'kutusuna sığdığı hâlde dikey sürükleme jestini yutuyor (v59 madde 1).',
  );
}

void main() {
  group('sığan içerik: kart jesti yutmaz, dış sayfa akar', () {
    testWidgets('ortak iskelet (CardScaffold)', (tester) async {
      final outer = await _pumpHomeCell(
        tester,
        cellHeight: 120,
        card: CardScaffold(
          header: const Text('Baslik'),
          // Hücreden kısa gövde: `CardScaffold` doldurma eşiğinin altında
          // kaydırma dalına düşer, ama taşacak içerik yoktur.
          bodyBuilder: (context, h) => const SizedBox(height: 24),
        ),
      );
      await _expectOuterScrolls(
        tester,
        outer,
        find.byType(CardScaffold),
        label: 'CardScaffold',
      );
    });

    testWidgets('Şu an çalışanlar (sahibin bildirdiği kart)', (tester) async {
      final outer = await _pumpHomeCell(
        tester,
        card: const ActiveMembersCard(),
        overrides: _activeMembersOverrides(2),
      );
      await _expectOuterScrolls(
        tester,
        outer,
        find.byType(ActiveMembersCard),
        label: 'ActiveMembersCard',
      );
    });

    testWidgets('Bugünün özeti (ders kırılımı listesi)', (tester) async {
      final outer = await _pumpHomeCell(
        tester,
        card: const TodaySummaryCard(),
        overrides: _statsOverrides(),
      );
      // WP-566: kart ders kirilimi listesini gercekten kurmus olmali; bos
      // kart hic `Scrollable` kurmaz ve jest iddiasi bosa doner.
      expect(
        find.text('Matematik'),
        findsOneWidget,
        reason: 'kurulum bozuk: bugunun ders kirilimi cizilmedi',
      );
      await _expectOuterScrolls(
        tester,
        outer,
        find.byType(TodaySummaryCard),
        label: 'TodaySummaryCard',
      );
    });

    testWidgets('Görevler', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = InMemoryUserTaskRepository();
      // Boş listede kart hiç `ListView` kurmaz — kurulum hatayı göremezdi.
      await repo.saveAll(
        userKey: 'local',
        tasks: [
          for (var i = 1; i <= 2; i++)
            UserTask(
              id: 't$i',
              title: 'Gorev $i',
              completed: false,
              createdAt: DateTime(2026, 1, 1),
              sortOrder: i,
            ),
        ],
      );
      final outer = await _pumpHomeCell(
        tester,
        card: const TasksCard(),
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authStateProvider.overrideWith((ref) => Stream.value(null)),
          userTaskRepositoryProvider.overrideWithValue(repo),
        ],
      );
      expect(
        find.text('Gorev 1'),
        findsOneWidget,
        reason: 'kurulum bozuk: görev listesi çizilmedi',
      );
      await _expectOuterScrolls(
        tester,
        outer,
        find.byType(TasksCard),
        label: 'TasksCard',
      );
    });

    testWidgets('Günlük hedef (koşulsuz kaydırıcı kuruyordu)', (tester) async {
      final outer = await _pumpHomeCell(
        tester,
        card: const GoalCard(),
        overrides: _goalOverrides(),
      );
      await _expectOuterScrolls(
        tester,
        outer,
        find.byType(GoalCard),
        label: 'GoalCard',
      );
    });

    testWidgets('Dönem özeti (koşulsuz kaydırıcı kuruyordu)', (tester) async {
      final outer = await _pumpHomeCell(
        tester,
        card: const PeriodSummaryCard(),
        overrides: _statsOverrides(),
      );
      await _expectOuterScrolls(
        tester,
        outer,
        find.byType(PeriodSummaryCard),
        label: 'PeriodSummaryCard',
      );
    });

    testWidgets('Rekorlar', (tester) async {
      final outer = await _pumpHomeCell(
        tester,
        cellHeight: 460,
        card: const RecordsCard(),
        overrides: _statsOverrides(),
      );
      await _expectOuterScrolls(
        tester,
        outer,
        find.byType(RecordsCard),
        label: 'RecordsCard',
      );
    });
  });

  group('taşan içerik: kart içinde kayar (WP-497 geri gelmez)', () {
    testWidgets('12 aktif üye · kart kayar, dış sayfa durur', (tester) async {
      final outer = await _pumpHomeCell(
        tester,
        card: const ActiveMembersCard(),
        overrides: _activeMembersOverrides(12),
      );

      final card = find.byType(ActiveMembersCard);
      final position = _innerPosition(tester, card);
      expect(
        position,
        isNotNull,
        reason: '12 üye bu hücreye sığmaz; kartın kendi kaydırıcısı olmalı '
            '(yoksa sığmayan üyeye ulaşılamaz — WP-497)',
      );
      expect(
        position!.maxScrollExtent,
        greaterThan(0),
        reason: 'kurulum bozuk: 12 üye taşmıyor',
      );

      await tester.drag(card, const Offset(0, -120));
      await tester.pump();

      expect(
        position.pixels,
        greaterThan(0),
        reason: 'taşan kart kendi içinde kaymadı — sığmayan üyeye ulaşılamaz',
      );
      expect(
        outer.offset,
        0,
        reason: 'taşan kart üzerindeki sürükleme dış sayfaya sızmamalı',
      );
    });
  });

  group('sınırsız yükseklik: kart hiç kaydırıcı kurmaz (WP-172)', () {
    // Sınırsız kısıtta kaydırıcı kurmak yalnız jesti değil, düzeni de bozar
    // (viewport sınırsız yükseklik alamaz). `goal_card`, `period_summary_card`
    // ve `today_summary_card`'ın kompakt dalı bu kontrolü hiç yapmıyordu.
    final cases = <String, ({Widget card, List<Override> overrides, double w})>{
      'GoalCard': (card: const GoalCard(), overrides: _goalOverrides(), w: 320),
      'PeriodSummaryCard': (
        card: const PeriodSummaryCard(),
        overrides: _statsOverrides(),
        w: 320,
      ),
      // Kompakt dal yalnız dar hücrede çizilir; geniş kurulum onu hiç görmez.
      'TodaySummaryCard (kompakt)': (
        card: const TodaySummaryCard(),
        overrides: _statsOverrides(),
        w: 150,
      ),
    };

    for (final entry in cases.entries) {
      testWidgets('${entry.key} sınırsız listede taşmıyor', (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: entry.value.overrides,
            child: MaterialApp(
              locale: const Locale('tr'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: ListView(
                  children: [
                    // `ListView` çocuğa TAM genişlik dayatır; dar hücreyi
                    // görmek için araya gevşek kısıt veren `Align` gerekiyor.
                    Align(
                      alignment: Alignment.topLeft,
                      child: SizedBox(
                        width: entry.value.w,
                        child: entry.value.card,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        // Sahnedeki tek `Scrollable` dış liste olmalı.
        expect(find.byType(Scrollable), findsOneWidget);
      });
    }
  });

  // 🔴 WP-566 kaniti: tuzak gece yarisi PENCERESINI beklemeden
  // olculur. Enjekte edilen `now` gunun 24 saatini tarar, yani sonuc kosum
  // saatinden bagimsizdir. Fixture ham `DateTime.now().subtract`a donerse (ya
  // da yardimcidaki kirpma kalkarsa) 01:00 oncesi ornekler kirmizi doner.
  test('WP-566: kart oturumu gunun HER saatinde bugune duser', () {
    // 21:00Z = ertesi gun 00:00 Istanbul (UTC+3).
    final istanbulMidnight = DateTime.utc(2026, 8, 9, 21);
    for (var minute = 0; minute < 24 * 60; minute += 15) {
      final now = istanbulMidnight.add(Duration(minutes: minute));
      expect(
        _todaySessions(now: now).single.day,
        istanbulDay(now),
        reason:
            'Istanbul ${minute ~/ 60}:${(minute % 60).toString().padLeft(2, '0')} '
            '- fixture oturumu bugune dusmedi, ders kirilimi hic cizilmez.',
      );
    }
  });
}

List<Override> _activeMembersOverrides(int count) => [
  authStateProvider.overrideWith((ref) => Stream.value(_member(1))),
  userGroupProvider.overrideWithValue(AsyncValue.data(_group)),
  groupPresenceProvider.overrideWith(
    (ref) => Stream.value([for (var i = 1; i <= count; i++) _studying(i)]),
  ),
  groupMembersProvider.overrideWith(
    (ref) => Stream.value([for (var i = 1; i <= count; i++) _member(i)]),
  ),
];

/// `TodaySummaryCard` yalniz **bugune** dusen oturumlari toplar
/// (`today_summary_card.dart` -> `sessionsOnDay(sessions, now)`).
///
/// 🔴 WP-566 gece yarisi tuzagi: burada eskiden ham
/// `DateTime.now() - 1 saat` vardi. Urunun gun siniri `Europe/Istanbul`;
/// kosum 00:00-01:00 arasina denk gelirse oturum DUNE duser ve kart ders
/// kirilimi `ListView`ini **hic kurmaz** -- yani WP-508'in olctugu jest tuzagi
/// (sigan icerikte kaydirici kuran kart) sahnede hic bulunmaz ve iki test
/// sessizce olcmeyi birakir. Ayni pencere `today_summary_unbounded_wp515`i
/// kirmisti (2026-08-09 00:5x kirmizi, 01:04 hicbir kod degismeden yesil).
List<StudySession> _todaySessions({DateTime? now}) => [
  StudySession(
    id: 's1',
    userId: 'u1',
    subjectId: 'sub-1',
    start: agoWithinIstanbulToday(const Duration(hours: 1), now: now),
    end: now ?? DateTime.now(),
    durationSeconds: 3600,
    source: StudySource.live,
  ),
];

List<Override> _statsOverrides() => [
  authStateProvider.overrideWith((ref) => Stream.value(_member(1))),
  userSessionsProvider.overrideWith((ref) => Stream.value(_todaySessions())),
  userSubjectsProvider.overrideWith(
    (ref) => Stream.value(<Subject>[
      const Subject(id: 'sub-1', userId: 'u1', name: 'Matematik', color: 'chart-1'),
    ]),
  ),
];

List<Override> _goalOverrides() => [
  authStateProvider.overrideWith((ref) => Stream.value(null)),
  todayRecordedSecondsProvider.overrideWithValue(1800),
  dailyGoalMinutesProvider.overrideWithValue(60),
];
