@Tags(['golden'])
library;

// WP-454: üç alev durumu ve kişisel/grup ayrımı.
//
// Kartın kabulü üç şey istiyor ve üçü de burada bağlanıyor:
//   1. durum YALNIZ server projection'dan gelir;
//   2. kişisel/grup renk + çerçeve + label ile ayrılır, yalnız renge dayanmaz;
//   3. küçük kartta işaret okunur.
//
// (2) kozmetik değil erişilebilirlik: renk körü bir kullanıcı için üç durum da
// aynı gri tona düşebilir. Bu yüzden testler rengi değil İKON ve METİN
// farkını ölçüyor — renk tek ayırt edici olsaydı bu iddialar geçmezdi.
//
// ⚠️ WP-496 (sahip kararı, 2026-08-06) rozetteki **görünür** metni kaldırdı.
// Kartın (2) kabulü düşmedi, kanalı değişti: metin farkı artık `Semantics`
// etiketinde ölçülüyor. Aşağıdaki iddialar `find.text` yerine
// `find.bySemanticsLabel` kullanıyor; hiçbiri gevşetilmedi. Rozette yazı
// olmadığının ayrı kanıtı `goal_streak_badge_wp496_test.dart`ta.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/goal_streak.dart';
import 'package:online_study_room/features/stats/widgets/goal_streak_flame.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

GoalStreakProjection _projection(
  GoalStreakState state, {
  GoalStreakScope scope = const GoalStreakScope.personal('user-a'),
  int streak = 4,
}) => GoalStreakProjection(
  scope: scope,
  asOfDay: DateTime.utc(2026, 7, 5),
  currentStreak: streak,
  completionCount: streak,
  state: state,
  sourceVersion: 'goal_completion_v1',
);

const _groupScope = GoalStreakScope.group(
  groupId: 'group-a',
  timeZone: 'Europe/Istanbul',
);

Widget _wrap(
  Widget child, {
  Brightness brightness = Brightness.light,
  double textScale = 1.0,
}) => MaterialApp(
  locale: const Locale('tr'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: ThemeData(brightness: brightness, useMaterial3: true),
  home: MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
    child: Scaffold(body: Center(child: child)),
  ),
);

void main() {
  group('üç durum birbirinden ikon ve metinle ayrılır', () {
    testWidgets('her durum ayrı ikon taşır', (tester) async {
      final icons = <GoalStreakState, IconData>{};
      for (final state in [
        GoalStreakState.completedToday,
        GoalStreakState.pendingToday,
        GoalStreakState.atRisk,
      ]) {
        await tester.pumpWidget(
          _wrap(GoalStreakFlame(projection: _projection(state))),
        );
        icons[state] = tester.widget<Icon>(find.byType(Icon)).icon!;
      }

      expect(
        icons.values.toSet(),
        hasLength(3),
        reason: 'iki durum aynı ikonu kullanırsa ayrım yalnız renge kalır',
      );
    });

    testWidgets('her durum ayrı cümle duyurur', (tester) async {
      final handle = tester.ensureSemantics();
      final labels = <String>{};
      for (final state in [
        GoalStreakState.completedToday,
        GoalStreakState.pendingToday,
        GoalStreakState.atRisk,
      ]) {
        await tester.pumpWidget(
          _wrap(GoalStreakFlame(projection: _projection(state))),
        );
        labels.add(tester.getSemantics(find.byType(GoalStreakFlame)).label);
      }
      expect(labels, hasLength(3));
      handle.dispose();
    });

    testWidgets('grace durumu okunabilir uyarı cümlesi taşır', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(GoalStreakFlame(projection: _projection(GoalStreakState.atRisk))),
      );
      // WP-496: cümle ekranda çizilmiyor ama ekran okuyucuya aynen gidiyor.
      expect(find.text('Bugün tamamlanmazsa seri bitecek'), findsNothing);
      expect(
        find.bySemanticsLabel('Kişisel · 4 · Bugün tamamlanmazsa seri bitecek'),
        findsOneWidget,
      );
      handle.dispose();
    });
  });

  group('durum yalnız server projection alanından gelir', () {
    testWidgets('aynı seri sayısı, farklı state → farklı görsel', (
      tester,
    ) async {
      // Widget'ın elinde yalnız projeksiyon var; tarih/saat okumuyor. İki
      // örnek yalnız `state` alanında ayrışıyor ve çıktı değişiyor.
      await tester.pumpWidget(
        _wrap(
          GoalStreakFlame(
            projection: _projection(GoalStreakState.completedToday, streak: 7),
          ),
        ),
      );
      final completedIcon = tester.widget<Icon>(find.byType(Icon)).icon;
      expect(find.text('7'), findsOneWidget);

      await tester.pumpWidget(
        _wrap(
          GoalStreakFlame(
            projection: _projection(GoalStreakState.pendingToday, streak: 7),
          ),
        ),
      );
      expect(tester.widget<Icon>(find.byType(Icon)).icon, isNot(completedIcon));
      expect(find.text('7'), findsOneWidget);
    });
  });

  group('kişisel ve grup ayrımı renge bağlı değil', () {
    testWidgets('duyurulan cümle kapsamı söyler', (tester) async {
      // WP-496 öncesi bu ayrım görünür bir kapsam rozetiydi; sahip kararıyla
      // kalktı. Bilgi kaybolmadı: kapsam hâlâ cümlenin ilk kelimesi.
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(
          GoalStreakFlame(
            projection: _projection(GoalStreakState.completedToday),
          ),
        ),
      );
      expect(
        tester.getSemantics(find.byType(GoalStreakFlame)).label,
        startsWith('Kişisel · '),
      );

      await tester.pumpWidget(
        _wrap(
          GoalStreakFlame(
            projection: _projection(
              GoalStreakState.completedToday,
              scope: _groupScope,
            ),
          ),
        ),
      );
      expect(
        tester.getSemantics(find.byType(GoalStreakFlame)).label,
        startsWith('Grup · '),
      );
      handle.dispose();
    });

    testWidgets('çerçeve biçimi de ayrışır', (tester) async {
      BorderRadius radiusOf(WidgetTester t) {
        final container = t.widget<Container>(
          find
              .descendant(
                of: find.byType(GoalStreakFlame),
                matching: find.byType(Container),
              )
              .first,
        );
        return ((container.decoration! as BoxDecoration).borderRadius!
            as BorderRadius);
      }

      await tester.pumpWidget(
        _wrap(
          GoalStreakFlame(
            projection: _projection(GoalStreakState.completedToday),
          ),
        ),
      );
      final personal = radiusOf(tester);

      await tester.pumpWidget(
        _wrap(
          GoalStreakFlame(
            projection: _projection(
              GoalStreakState.completedToday,
              scope: _groupScope,
            ),
          ),
        ),
      );
      expect(
        radiusOf(tester),
        isNot(personal),
        reason: 'kapsam ayrımı yalnız renk/etiket değil, biçim de olmalı',
      );
    });

    testWidgets('ekran okuyucu kapsamı, seriyi ve durumu tek cümlede duyar', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(
          GoalStreakFlame(
            projection: _projection(
              GoalStreakState.atRisk,
              scope: _groupScope,
              streak: 5,
            ),
          ),
        ),
      );

      expect(
        find.bySemanticsLabel('Grup · 5 · Bugün tamamlanmazsa seri bitecek'),
        findsOneWidget,
      );
      handle.dispose();
    });
  });

  group('küçük kartta işaret okunur', () {
    testWidgets('compact biçimde ikon, sayı ve kapsam korunur', (tester) async {
      await tester.pumpWidget(
        _wrap(
          GoalStreakFlame(
            projection: _projection(GoalStreakState.atRisk, streak: 12),
            size: GoalStreakFlameSize.compact,
          ),
        ),
      );

      expect(find.byType(Icon), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      // WP-496: kapsam ve durum cümlesi artık hiçbir boyutta çizilmiyor;
      // ölçülen şey işaretin (ikon + sayı) kaybolmaması.
      expect(find.text('Kişisel'), findsNothing);
      expect(find.text('Bugün tamamlanmazsa seri bitecek'), findsNothing);
    });

    testWidgets('2.0 text scale taşma üretmez', (tester) async {
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 360,
            child: GoalStreakFlame(
              projection: _projection(GoalStreakState.atRisk),
            ),
          ),
          textScale: 2.0,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  // 🔴 Golden'ların NE kanıtladığı hakkında bir uyarı — mutasyon turunda
  // ölçüldü, tahmin değil:
  //
  //   * Renk / boşluk / tema değişikliği → üç golden de kırmızıya döner.
  //   * İKON değişikliği → hiçbir golden görmez.
  //
  // Sebep: `flutter test` gerçek MaterialIcons fontunu yüklemez, ikon glifleri
  // boş kutu olarak çizilir. Yani `warning_amber_rounded` ile
  // `local_fire_department` golden'da BİREBİR aynı görünür.
  //
  // Kartın "yalnız renge dayanmaz" kabulünü bu yüzden golden değil, yukarıdaki
  // `her durum ayrı ikon taşır` testi taşıyor; o `Icon.icon` alanını doğrudan
  // okur. İkisini karıştırıp golden'a güvenen biri, ayrımı sessizce kaybeder.
  group('golden', () {
    for (final brightness in Brightness.values) {
      final name = brightness == Brightness.dark ? 'dark' : 'light';
      testWidgets('üç durum · $name', (tester) async {
        await tester.pumpWidget(
          _wrap(
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final state in [
                  GoalStreakState.completedToday,
                  GoalStreakState.pendingToday,
                  GoalStreakState.atRisk,
                  GoalStreakState.empty,
                ])
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: GoalStreakFlame(projection: _projection(state)),
                  ),
                for (final state in [
                  GoalStreakState.completedToday,
                  GoalStreakState.atRisk,
                ])
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: GoalStreakFlame(
                      projection: _projection(state, scope: _groupScope),
                    ),
                  ),
              ],
            ),
            brightness: brightness,
          ),
        );
        await tester.pumpAndSettle();

        await expectLater(
          find.byType(Column).first,
          matchesGoldenFile('goldens/goal_streak_flame_$name.png'),
        );
      });
    }

    testWidgets('compact · 1.6 text scale', (tester) async {
      await tester.pumpWidget(
        _wrap(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final state in [
                GoalStreakState.completedToday,
                GoalStreakState.atRisk,
              ])
                Padding(
                  padding: const EdgeInsets.all(6),
                  child: GoalStreakFlame(
                    projection: _projection(state),
                    size: GoalStreakFlameSize.compact,
                  ),
                ),
            ],
          ),
          textScale: 1.6,
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(Column).first,
        matchesGoldenFile('goldens/goal_streak_flame_compact_scaled.png'),
      );
    });
  });
}
