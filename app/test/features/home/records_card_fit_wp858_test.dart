// WP-858 — "Rekorlar" kartı kendi boyunda taşmaz.
//
// Ölçüm (WP-836 envanteri): varsayılan 32×26 hücrede, dar telefonda
// (328 px içerik) kart 211 px KART İÇİ kaydırma üretiyordu — diğer her kart
// varsayılan boyunda 0'a inmişti. Sahip: "kartlar hep bozuk geliyor".
//
// Düzeltme hücreyi büyütmedi; kart yoğun döşemeye geçti ve gövdeye sığan
// kadarını ÖNEM sırasıyla gösteriyor (Toplam → Rekor seri → Aktif gün →
// En verimli gün → En çok ders). Bu dosya üç şeyi kilitler:
//   1. varsayılan hücrede kaydırma YOK ve en önemli dört rekor ekranda;
//   2. büyütülmüş hücrede beşi birden görünür (hiçbir şey kalıcı gizlenmez);
//   3. büyük yazıda döşeme DÜŞÜRÜLMEZ, kart kayar (WP-497 / WP-541).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/stats/study_stats.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/models/study_session.dart';
import 'package:online_study_room/data/models/subject.dart';
import 'package:online_study_room/data/models/user_study_summary.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/study_providers.dart';
import 'package:online_study_room/data/providers/subject_providers.dart';
import 'package:online_study_room/features/home/dashboard_card.dart';
import 'package:online_study_room/features/home/widgets/records_card.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

// Ana Sayfa ızgarasının gerçek geometrisi (envanter testiyle aynı formül).
const double _kGap = 8.0;
const int _kColumns = 32;
const double _kNarrowPhone = 328;

double _span(double content, int units) =>
    units * ((content - (_kColumns - 1) * _kGap) / _kColumns) +
    (units - 1) * _kGap;

const _subjects = <Subject>[
  Subject(id: 's1', userId: 'u1', name: 'Matematik', color: 'chart-1'),
  Subject(id: 's2', userId: 'u1', name: 'Fizik', color: 'chart-2'),
];

/// 90 gün × günde 2 oturum: her döşeme dolu, kapsam etiketi (" · 90 gün")
/// açık — yani etiketler en uzun hâlinde.
List<StudySession> _sessions() {
  final now = DateTime.now();
  return [
    for (var d = 0; d < 90; d++)
      for (var k = 0; k < 2; k++)
        () {
          final start = dayOf(
            now,
          ).subtract(Duration(days: d)).add(Duration(hours: 9 + k * 3));
          return StudySession(
            id: 's-$d-$k',
            userId: 'u1',
            subjectId: _subjects[(d + k) % _subjects.length].id,
            start: start,
            end: start.add(const Duration(minutes: 55)),
            durationSeconds: 55 * 60,
            source: StudySource.live,
          );
        }(),
  ];
}

Future<void> _pump(
  WidgetTester tester, {
  required int h,
  double scale = 1.0,
}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final width = _span(_kNarrowPhone, 32);
  final height = _span(_kNarrowPhone, h);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authStateProvider.overrideWith(
          (ref) => Stream.value(
            Profile(id: 'u1', displayName: 'Ben', createdAt: DateTime(2026)),
          ),
        ),
        userSessionsProvider.overrideWith((ref) => Stream.value(_sessions())),
        userSubjectsProvider.overrideWith((ref) => Stream.value(_subjects)),
        // Ömür boyu > sıcak pencere → kapsam etiketleri açık (en uzun hâl).
        userStudySummaryProvider.overrideWith(
          (ref) async => const UserStudySummary(
            lifetimeSeconds: 900000,
            yearSeconds: 800000,
            hotWindowSeconds: 594000,
          ),
        ),
        dailyGoalMinutesProvider.overrideWithValue(60),
      ],
      child: MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                SizedBox(
                  width: width,
                  height: height,
                  child: dashboardCardFor(
                    DashboardCardType.records,
                    DashboardCardConfig(
                      DashboardCardType.records,
                      w: 32,
                      h: h,
                    ).sizeForColumns(_kColumns),
                    height: height,
                  ),
                ),
                const SizedBox(height: 1600),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

/// Kartın içindeki dikey kaydırma payı (0 = sığıyor, jest dış sayfaya gider).
double _innerOverflow(WidgetTester tester) {
  var worst = 0.0;
  for (final e in find
      .descendant(
        of: find.byType(RecordsCard),
        matching: find.byType(Scrollable),
      )
      .evaluate()) {
    final state = (e as StatefulElement).state as ScrollableState;
    if (state.position.hasContentDimensions &&
        state.position.maxScrollExtent > worst) {
      worst = state.position.maxScrollExtent;
    }
  }
  return worst;
}

/// Etiket kartın görünür kutusunun İÇİNDE mi (kaydırmadan okunabiliyor mu)?
void _expectVisible(WidgetTester tester, String label) {
  final finder = find.descendant(
    of: find.byType(RecordsCard),
    matching: find.textContaining(label),
  );
  expect(finder, findsOneWidget, reason: '"$label" döşemesi yok');
  final card = tester.getRect(find.byType(RecordsCard));
  final rect = tester.getRect(finder);
  expect(
    rect.bottom <= card.bottom + 0.5,
    isTrue,
    reason: '"$label" kartın altında kalıyor ($rect / $card)',
  );
}

void main() {
  late AppLocalizations l10n;
  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('tr'));
  });

  testWidgets('varsayılan hücre dar telefonda KAYDIRMASIZ, en önemli dört '
      'rekor görünür', (tester) async {
    final def = DashboardCardType.records.defaultCells(_kColumns);
    expect(def.w, 32, reason: 'kurulum: varsayılan tam genişlik varsayıldı');
    await _pump(tester, h: def.h);
    expect(tester.takeException(), isNull);

    expect(
      _innerOverflow(tester),
      0,
      reason:
          'rekor kartı varsayılan hücresinde kendi içinde kayıyor; '
          'parmak kartın üstündeyken ana ekran takılır (WP-858 öncesi 211 px)',
    );
    // Önem sırası: kırpılan en az kritik olandır.
    _expectVisible(tester, l10n.statsToplam);
    _expectVisible(tester, l10n.statsRekorSeri);
    _expectVisible(tester, l10n.statsAktifGun);
    _expectVisible(tester, l10n.statsEnVerimliGun);
    expect(
      find.textContaining(l10n.statsEnCokDers),
      findsNothing,
      reason:
          'bu hücrede beşinci döşeme yer bulamaz; kaydırıcı kurmak yerine '
          'en az kritik rekor düşer',
    );
  });

  testWidgets('büyütülmüş hücrede beş rekorun hepsi, kaydırmasız', (
    tester,
  ) async {
    await _pump(tester, h: 32);
    expect(tester.takeException(), isNull);
    expect(_innerOverflow(tester), 0);
    for (final label in [
      l10n.statsToplam,
      l10n.statsRekorSeri,
      l10n.statsAktifGun,
      l10n.statsEnVerimliGun,
      l10n.statsEnCokDers,
    ]) {
      _expectVisible(tester, label);
    }
  });

  testWidgets('büyük yazıda rekor GİZLENMEZ; kart kayar (WP-497/541)', (
    tester,
  ) async {
    final def = DashboardCardType.records.defaultCells(_kColumns);
    await _pump(tester, h: def.h, scale: 2.0);
    expect(tester.takeException(), isNull);
    // Beşi de ağaçta: büyük yazı seçen kullanıcıdan içerik saklanmaz.
    expect(find.textContaining(l10n.statsEnCokDers), findsOneWidget);
    expect(
      _innerOverflow(tester),
      greaterThan(0),
      reason: 'sığmayan döşemeye ulaşmanın yolu kart içi kaydırmadır',
    );
  });
}
