// WP-481 (V57-N04 + V57-N05): seri göstergesi chess.com modeli.
//
// 🔴 Kartın kök nedeni "yanlış hesap" değil, **bağlanmamış kablo**ydu:
// `GoalStreakFlame` ve `goalStreakProjectionProvider` WP-453/454'te yazıldı ama
// `app/lib` içinde tek bir çağrı yeri yoktu. Ekranlar grace'siz eski motoru
// (`currentStreak()`) okuyordu ve sahibin istediği duraklatma o motorda yok.
//
// Bu dosya dört şeyi sabitler:
//   1. rozet seri 0 iken bile **görünür** (eski `if (streak > 0)` kapısı);
//   2. durum → ikon ayrımı (goldenlar gerçek MaterialIcons fontunu yüklemediği
//      için ikon değişimini göremez; `Icon.icon` doğrudan okunur);
//   3. sahibin sayısal örneği: gün atlayarak 100 günde 50 kez tutturan
//      kullanıcı **50** seriye sahiptir (koruma sınırsız);
//   4. üç yüzey artık eski motoru çağırmıyor.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/stats/goal_streak_projection.dart';
import 'package:online_study_room/data/models/goal_streak.dart';
import 'package:online_study_room/data/providers/goal_streak_providers.dart';
import 'package:online_study_room/features/stats/widgets/goal_streak_flame.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

const _personal = GoalStreakScope.personal('u1');
const _group = GoalStreakScope.group(
  groupId: 'g1',
  timeZone: 'Europe/Istanbul',
);

GoalStreakProjection _projection(
  GoalStreakState state, {
  int streak = 3,
  GoalStreakScope scope = _personal,
}) => GoalStreakProjection(
  scope: scope,
  asOfDay: DateTime.utc(2026, 8, 1),
  currentStreak: streak,
  completionCount: streak,
  state: state,
  sourceVersion: 'test',
);

/// Her çağrı **taze** bir `ProviderScope` kurar.
///
/// Aynı ağacı override değiştirerek yeniden pump etmek Riverpod'da eski değeri
/// bir tur daha gösteriyor; iddialar bir durum kayarak yanlış yeşil/kırmızı
/// verirdi. Benzersiz `key` konteyneri tamamen yeniden kurar.
Widget _badge({
  required GoalStreakScope scope,
  GoalStreakProjection? projection,
}) => ProviderScope(
  key: ValueKey('${scope.ledgerKey}-${projection?.state}'),
  overrides: [
    if (projection != null)
      goalStreakProjectionProvider(
        scope,
      ).overrideWith((ref) => Stream.value(projection)),
  ],
  child: MaterialApp(
    locale: const Locale('tr'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: Center(child: GoalStreakBadge(scope: scope))),
  ),
);

IconData _iconOf(WidgetTester tester) =>
    tester.widget<Icon>(find.byType(Icon)).icon!;

void main() {
  group('rozet daima görünür', () {
    testWidgets('seri 0 iken de çizilir ve "0" gösterir', (tester) async {
      await tester.pumpWidget(
        _badge(
          scope: _personal,
          projection: _projection(GoalStreakState.empty, streak: 0),
        ),
      );
      await tester.pumpAndSettle();

      // 🔴 Sahibin maddesi: "rozet her zaman görünür, seri 0 iken bile."
      expect(find.byType(GoalStreakFlame), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
      expect(find.text('Henüz seri yok'), findsOneWidget);
    });

    testWidgets('projeksiyon henüz yokken bile rozet var', (tester) async {
      // Kapsam bilinmiyor (oturum yüklenmedi): rozet gizlenmez, boş durum çizer.
      await tester.pumpWidget(_badge(scope: _personal));
      await tester.pumpAndSettle();

      expect(find.byType(GoalStreakFlame), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
    });
  });

  group('sahibin üç durumu ikonla ayrışır', () {
    testWidgets('sıfırlanmış → soluk alev, duraklatma → pause, tamam → ateş', (
      tester,
    ) async {
      final icons = <GoalStreakState, IconData>{};
      for (final state in [
        GoalStreakState.empty,
        GoalStreakState.atRisk,
        GoalStreakState.completedToday,
        GoalStreakState.pendingToday,
      ]) {
        await tester.pumpWidget(
          _badge(scope: _personal, projection: _projection(state)),
        );
        await tester.pumpAndSettle();
        icons[state] = _iconOf(tester);
      }

      // (a) sıfırlanmış → gri soluk alev (gece ikonu değil).
      expect(icons[GoalStreakState.empty], Icons.local_fire_department);
      // (b) duraklatma → pause işareti (uyarı üçgeni değil).
      expect(icons[GoalStreakState.atRisk], Icons.pause_circle_outline);
      // (c) bugünün hedefi tamam → renkli ateş.
      expect(
        icons[GoalStreakState.completedToday],
        Icons.local_fire_department,
      );
      // Kart kararı: `pendingToday` **canlı** alev; pause yalnız dün kaçınca.
      expect(
        icons[GoalStreakState.pendingToday],
        isNot(Icons.pause_circle_outline),
      );
    });

    testWidgets('canlı alev rengi ile soluk alev rengi ayrı', (tester) async {
      await tester.pumpWidget(
        _badge(
          scope: _personal,
          projection: _projection(GoalStreakState.completedToday),
        ),
      );
      await tester.pumpAndSettle();
      final live = tester.widget<Icon>(find.byType(Icon)).color;

      await tester.pumpWidget(
        _badge(
          scope: _personal,
          projection: _projection(GoalStreakState.empty, streak: 0),
        ),
      );
      await tester.pumpAndSettle();
      final faded = tester.widget<Icon>(find.byType(Icon)).color;

      // Aynı ikon iki durumda kullanılıyor; ayrım renk + sayı + metinle.
      expect(live, isNot(faded));
    });
  });

  group('aynı model grup kapsamında da geçerli', () {
    for (final state in [
      GoalStreakState.empty,
      GoalStreakState.atRisk,
      GoalStreakState.completedToday,
    ]) {
      testWidgets('grup rozeti $state durumunu aynı ikonla gösterir', (
        tester,
      ) async {
        await tester.pumpWidget(
          _badge(
            scope: _personal,
            projection: _projection(state, scope: _personal),
          ),
        );
        await tester.pumpAndSettle();
        final personalIcon = _iconOf(tester);

        await tester.pumpWidget(
          _badge(scope: _group, projection: _projection(state, scope: _group)),
        );
        await tester.pumpAndSettle();

        expect(_iconOf(tester), personalIcon);
        expect(find.text('Grup'), findsOneWidget);
      });
    }
  });

  // 🔴 Sahibin sayısal örneği birebir. "Koruma hakkı sınırsızdır."
  test('gün atlayarak 100 günde 50 kez tutturan kullanıcı 50 seriye sahiptir', () {
    final start = DateTime.utc(2026, 1, 1);
    final events = [
      for (var i = 0; i < 50; i++)
        GoalProgressEvent(
          eventKey: 'e$i',
          scope: _personal,
          kind: GoalProgressEventKind.goalCompleted,
          goalDay: start.add(Duration(days: i * 2)),
          occurredAt: start.add(Duration(days: i * 2, hours: 20)),
        ),
    ];

    final projection = projectGoalStreak(
      scope: _personal,
      events: events,
      // Son tamamlama 98. gün; o gün itibarıyla bakılıyor.
      asOfDay: start.add(const Duration(days: 98)),
    );

    expect(projection.currentStreak, 50);
    expect(projection.completionCount, 50);
    expect(projection.state, GoalStreakState.completedToday);
  });

  test('üç yüzey de artık grace\'siz eski motoru çağırmıyor', () {
    // Ekran kodunda `currentStreak` kalırsa iki motor aynı ekranda yaşar ve
    // kullanıcı aynı geçmişte iki farklı sayı görür (fazın 2. sistemik bulgusu).
    const surfaces = [
      'lib/features/classroom/widgets/study_timer_card.dart',
      'lib/features/home/widgets/goal_card.dart',
      'lib/features/home/widgets/group_goal_card.dart',
    ];
    for (final path in surfaces) {
      final source = File(path).readAsStringSync();
      // Yorum satırları kart gerekçesini anlatıyor; yalnız gerçek kod aranıyor.
      final code = source
          .split('\n')
          .where((line) => !line.trimLeft().startsWith('//'))
          .join('\n');
      expect(
        code,
        isNot(contains('currentStreak')),
        reason: '$path hâlâ eski seri motorunu okuyor',
      );
    }
  });
}
