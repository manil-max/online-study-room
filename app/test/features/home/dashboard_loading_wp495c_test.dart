// WP-495C: pano kartlarının ilk yüklemede "veri yok" iddia etmesi.
//
// `docs/qa/V58-ASYNC-EMPTY-AUDIT.md` §5'te kalan sınıf buydu: 13 kart oturum /
// grup istatistiği akışını `.value ?? const []` ile okuyordu. Yenilemeye
// dayanıklı ama **ilk yüklemede** boş liste = "hiç kaydın yok" demek. Kaydı olan
// kullanıcı açılışta "Kayıt yok", boş ısı haritası ve "0 dk" görüyordu.
//
// Ölçüt "daha az titriyor" değil: yükleme karesinde kartın **hangi metni
// yazdığı**. Bu yüzden testler boş-durum metinlerini ve "0 dk"yı arıyor.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/daily_stat.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/models/study_group.dart';
import 'package:online_study_room/data/models/study_session.dart';
import 'package:online_study_room/data/models/subject.dart';
import 'package:online_study_room/data/providers/analytics_query_providers.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/group_providers.dart';
import 'package:online_study_room/data/providers/study_providers.dart';
import 'package:online_study_room/data/providers/subject_providers.dart';
import 'package:online_study_room/features/home/dashboard_card.dart';
import 'package:online_study_room/features/home/widgets/card_data_gate.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

final _me = Profile(
  id: 'me-1',
  displayName: 'Sahip',
  createdAt: DateTime(2026, 1, 1),
);

final _group = StudyGroup(
  id: 'g-1',
  name: 'Odak Grubu',
  inviteCode: 'ABC123',
  createdBy: _me.id,
  createdAt: DateTime(2026, 1, 1),
);

/// Gerçek veri: kart "kayıt yok" derse bu **yanlış** olsun diye dolu.
final _sessions = <StudySession>[
  StudySession(
    id: 's-1',
    userId: _me.id,
    start: DateTime.now().subtract(const Duration(hours: 2)),
    end: DateTime.now().subtract(const Duration(hours: 1)),
    durationSeconds: 3600,
    source: StudySource.live,
  ),
];

const _subjects = <Subject>[
  Subject(id: 'sub-1', userId: 'me-1', name: 'Matematik', color: 'chart-1'),
];

final _stats = <DailyStat>[
  DailyStat(userId: _me.id, day: DateTime.now(), seconds: 3600),
];

/// Kişisel kartlar yalnız oturum akışını bekler.
const _personalCards = <DashboardCardType>[
  DashboardCardType.heatmap,
  DashboardCardType.hours,
  DashboardCardType.line,
  DashboardCardType.monthly,
  DashboardCardType.records,
  DashboardCardType.rhythm,
  DashboardCardType.scatter,
  DashboardCardType.today,
  DashboardCardType.weekdayWeekend,
  DashboardCardType.weekly,
];

const _groupCards = <DashboardCardType>[
  DashboardCardType.leaderboard,
  DashboardCardType.groupGoal,
  DashboardCardType.groupTrend,
];

/// Hiç emisyon yapmayan akış: cihazda ağ turunun beklendiği kare.
Stream<T> _pending<T>() => StreamController<T>().stream;

Future<void> _pumpCard(
  WidgetTester tester,
  DashboardCardType type, {
  required bool sessionsReady,
  required bool statsReady,
  bool sessionsFailed = false,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authStateProvider.overrideWith((ref) => Stream.value(_me)),
        userGroupProvider.overrideWithValue(AsyncData<StudyGroup?>(_group)),
        dailyGoalMinutesProvider.overrideWithValue(240),
        userSubjectsProvider.overrideWith((ref) => Stream.value(_subjects)),
        groupMembersProvider.overrideWith((ref) => Stream.value([_me])),
        groupAlphaScoresProvider.overrideWith(
          (ref) async => const <String, int>{},
        ),
        userSessionsProvider.overrideWith((ref) {
          if (sessionsFailed) {
            return Stream<List<StudySession>>.error('ağ yok');
          }
          return sessionsReady
              ? Stream.value(_sessions)
              : _pending<List<StudySession>>();
        }),
        groupDailyStatsProvider.overrideWith(
          (ref) =>
              statsReady ? Stream.value(_stats) : _pending<List<DailyStat>>(),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 340,
              child: dashboardCardFor(
                type,
                DashboardCardSize.medium,
                height: 260,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// Kartların yükleme karesinde **asla** yazmaması gereken iddialar.
List<String> _emptyClaims(AppLocalizations l10n) => [
  l10n.homeKayitYok,
  l10n.homeBugunHenuzCalismaKaydin,
];

void main() {
  for (final type in _personalCards) {
    testWidgets('${type.name}: oturumlar gelmeden boş durum iddia etmiyor', (
      tester,
    ) async {
      await _pumpCard(tester, type, sessionsReady: false, statsReady: true);
      final l10n = await AppLocalizations.delegate.load(const Locale('tr'));

      // Önce kullanıcıya görünen iddia ölçülür: kırık kodda hata mesajı
      // "iskelet yok" değil, ekranda duran yanlış cümleyi göstersin.
      for (final claim in _emptyClaims(l10n)) {
        expect(
          find.text(claim),
          findsNothing,
          reason: 'yanlış boş durum: $claim',
        );
      }
      // "0 dk" / "0 sa" gibi sıfır özetler de bir iddiadır.
      expect(find.textContaining(RegExp(r'^0\s*(dk|sa)')), findsNothing);
      expect(
        find.byKey(kCardSkeletonKey),
        findsOneWidget,
        reason: 'yükleniyorken yer tutucu çizilmeli',
      );
    });

    testWidgets('${type.name}: oturumlar gelince normal çiziliyor', (
      tester,
    ) async {
      await _pumpCard(tester, type, sessionsReady: true, statsReady: true);
      await tester.pump();

      expect(find.byKey(kCardSkeletonKey), findsNothing);
    });
  }

  for (final type in _groupCards) {
    testWidgets('${type.name}: grup istatistiği gelmeden boş çizilmiyor', (
      tester,
    ) async {
      await _pumpCard(tester, type, sessionsReady: true, statsReady: false);

      expect(find.byKey(kCardSkeletonKey), findsOneWidget);
      // Grup kartı davet kartına da düşmemeli: grup hazır, eksik olan veri.
      final l10n = await AppLocalizations.delegate.load(const Locale('tr'));
      expect(find.text(l10n.homeGrupOlustur), findsNothing);
    });

    testWidgets('${type.name}: istatistik gelince normal çiziliyor', (
      tester,
    ) async {
      await _pumpCard(tester, type, sessionsReady: true, statsReady: true);
      await tester.pump();

      expect(find.byKey(kCardSkeletonKey), findsNothing);
    });
  }

  testWidgets('akış hata verirse sonsuz iskelet değil hata metni çizilir', (
    tester,
  ) async {
    await _pumpCard(
      tester,
      DashboardCardType.records,
      sessionsReady: false,
      statsReady: true,
      sessionsFailed: true,
    );
    await tester.pump();

    final l10n = await AppLocalizations.delegate.load(const Locale('tr'));
    expect(find.text(l10n.homeVerilerYuklenemedi), findsOneWidget);
    // Kart tuzağı: hatayı "yükleniyor" sayıp sonsuza kadar iskelet döndürmek.
    expect(find.byKey(kCardSkeletonKey), findsNothing);
  });
}
