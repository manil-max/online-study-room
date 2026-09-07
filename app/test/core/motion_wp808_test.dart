// WP-808 — hareket dili ve dokunsal geri bildirim.
//
// Bu dosya sabitlerin VARLIĞINI değil, kullanıcının GÖRDÜĞÜNÜ ölçer:
//
//   1. Sayı değişince ara karede eski de yeni de olmayan bir değer çizilir
//      (yani gerçekten geçiş var), `pumpAndSettle` sonrası yeni değer.
//   2. `MediaQuery.disableAnimations` açıkken ara kare DOĞRUDAN yeni değerdir.
//   3. Hedef kutlaması bir kez oynar; hedef tutmuşken gelen yeni kayıt onu
//      tekrar oynatmaz.
//   4. Bütün süre sabitleri ≤ 320 ms ve TEK yerden okunur.
//   5. Sayfa geçişi teması Android ve Windows için tanımlı — ve gerçekten
//      kaydırıyor.
//
// 🔴 Neden ara kare: "widget ağaçta var" iddiası geçişin gerçekten oynadığını
// göstermez. `TweenAnimationBuilder` süresi sıfırlanırsa (ya da hiç
// bağlanmazsa) ağaç aynı kalır, yalnız ara kare kaybolur.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// `Override` tipi ana pakette değil (Riverpod 3).
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:online_study_room/core/l10n/app_locale.dart';
import 'package:online_study_room/core/theme/app_theme.dart';
import 'package:online_study_room/core/theme/motion_tokens.dart';
import 'package:online_study_room/core/utils/duration_format.dart';
import 'package:online_study_room/core/widgets/animated_stat_number.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/models/study_session.dart';
import 'package:online_study_room/data/models/subject.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/study_providers.dart';
import 'package:online_study_room/data/providers/subject_providers.dart';
import 'package:online_study_room/features/home/widgets/goal_card.dart';
import 'package:online_study_room/features/home/widgets/period_summary_card.dart';
import 'package:online_study_room/features/home/widgets/today_summary_card.dart';
import 'package:online_study_room/features/stats/widgets/study_records.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

import '../support/istanbul_fixture.dart';

/// Geçişin gözlendiği ara kare. Süre 260 ms olduğu için 100 ms hem başlangıçtan
/// hem bitişten uzaktır.
const _midFrame = Duration(milliseconds: 100);

StudySession _session(String id, int seconds) => StudySession(
  id: id,
  userId: 'u1',
  subjectId: 'sub-1',
  start: agoWithinIstanbulToday(Duration(seconds: seconds)),
  end: DateTime.now(),
  durationSeconds: seconds,
  source: StudySource.live,
);

const _subjects = <Subject>[
  Subject(id: 'sub-1', userId: 'u1', name: 'Matematik', color: 'chart-1'),
];

Widget _app({
  required Widget child,
  List<Override> overrides = const [],
  bool disableAnimations = false,
}) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(
    locale: const Locale('tr'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: AppTheme.dark(kAppPalettes.first),
    home: Scaffold(
      body: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: disableAnimations),
          child: Center(
            child: SizedBox(width: 360, height: 320, child: child),
          ),
        ),
      ),
    ),
  ),
);

/// [AnimatedStatNumber] içinde o an çizilen metin.
String _statText(WidgetTester tester, {Finder? within}) {
  final numbers = within == null
      ? find.byType(AnimatedStatNumber)
      : find.descendant(of: within, matching: find.byType(AnimatedStatNumber));
  return tester
      .widget<Text>(
        find.descendant(of: numbers, matching: find.byType(Text)),
      )
      .data!;
}

void main() {
  setUp(() {
    // `formatHuman` bağlamsız çalışır ve etkin dile bakar; koşum makinesinin
    // dili testin beklediği dizeyi değiştirmesin.
    setActiveAppLocale(const Locale('tr'));
  });

  group('sayı geçişi', () {
    testWidgets('rekor döşemesinde ara kare eski de yeni de değil', (
      tester,
    ) async {
      final overrides = [
        userSubjectsProvider.overrideWith(
          (ref) => Stream.value(_subjects),
        ),
        dailyGoalMinutesProvider.overrideWithValue(60),
      ];
      Widget records(int lifetime) => _app(
        overrides: overrides,
        child: StudyRecords(
          sessions: const [],
          lifetimeSeconds: lifetime,
        ),
      );

      await tester.pumpWidget(records(60));
      await tester.pump();
      expect(_statText(tester), formatHuman(60));

      await tester.pumpWidget(records(7200));
      await tester.pump(_midFrame);
      final mid = _statText(tester);
      expect(
        mid,
        isNot(formatHuman(60)),
        reason: 'Ara karede hâlâ ESKİ değer var — geçiş hiç oynamıyor.',
      );
      expect(
        mid,
        isNot(formatHuman(7200)),
        reason: 'Ara karede zaten YENİ değer var — sayı yine zıplıyor.',
      );

      await tester.pumpAndSettle();
      expect(_statText(tester), formatHuman(7200));
    });

    testWidgets('disableAnimations açıkken ara kare doğrudan yeni değer', (
      tester,
    ) async {
      final overrides = [
        userSubjectsProvider.overrideWith(
          (ref) => Stream.value(_subjects),
        ),
        dailyGoalMinutesProvider.overrideWithValue(60),
      ];
      Widget records(int lifetime) => _app(
        overrides: overrides,
        disableAnimations: true,
        child: StudyRecords(
          sessions: const [],
          lifetimeSeconds: lifetime,
        ),
      );

      await tester.pumpWidget(records(60));
      await tester.pump();
      await tester.pumpWidget(records(7200));

      expect(
        _statText(tester),
        formatHuman(7200),
        reason:
            '"Animasyonları azalt" açıkken geçiş oynamamalı; süre sıfır '
            'olmalı ve değer doğrudan son hâline geçmeli.',
      );
      // Geçiş yoksa ilerleyen kare de aynı değeri gösterir.
      await tester.pump(_midFrame);
      expect(_statText(tester), formatHuman(7200));
    });

    testWidgets('bugünün özeti kartında toplam süre geçiş yapar', (
      tester,
    ) async {
      final sessions = StreamController<List<StudySession>>();
      addTearDown(sessions.close);
      final overrides = [
        userSessionsProvider.overrideWith((ref) => sessions.stream),
        userSubjectsProvider.overrideWith(
          (ref) => Stream.value(_subjects),
        ),
      ];

      await tester.pumpWidget(
        _app(overrides: overrides, child: const TodaySummaryCard()),
      );
      sessions.add([_session('s1', 60)]);
      await tester.pump();
      await tester.pump();
      expect(_statText(tester), formatHuman(60));

      sessions.add([_session('s1', 60), _session('s2', 7140)]);
      // Akış olayı bir kare, kartın yeniden çizimi ikinci kare.
      await tester.pump();
      await tester.pump();
      await tester.pump(_midFrame);
      final mid = _statText(tester);
      expect(mid, isNot(formatHuman(60)));
      expect(mid, isNot(formatHuman(7200)));

      await tester.pumpAndSettle();
      expect(_statText(tester), formatHuman(7200));
    });

    testWidgets('dönem özeti kartının üç sayısı da geçişten geçer', (
      tester,
    ) async {
      final overrides = [
        userSessionsProvider.overrideWith(
          (ref) => Stream.value(<StudySession>[_session('s1', 1800)]),
        ),
        userSubjectsProvider.overrideWith(
          (ref) => Stream.value(_subjects),
        ),
      ];

      await tester.pumpWidget(
        _app(overrides: overrides, child: const PeriodSummaryCard()),
      );
      await tester.pump();
      await tester.pump();

      // Toplam / günlük ortalama / aktif gün: üçü de sayıdır, üçü de değişir.
      expect(
        find.descendant(
          of: find.byType(PeriodSummaryCard),
          matching: find.byType(AnimatedStatNumber),
        ),
        findsNWidgets(3),
      );
      expect(find.text(formatHuman(1800)), findsWidgets);
    });
  });

  group('hedef kutlaması', () {
    // Kaydedilen süreyi test içinden sürebilmek için araya konan kaynak;
    // `todayRecordedSecondsProvider` bunun son değerini okur.
    final recordedSource = StreamProvider<int>(
      (ref) => const Stream<int>.empty(),
    );

    List<Override> celebrationOverrides(Stream<int> source) => [
      authStateProvider.overrideWith((ref) => Stream<Profile?>.value(null)),
      dailyGoalMinutesProvider.overrideWithValue(60),
      recordedSource.overrideWith((ref) => source),
      todayRecordedSecondsProvider.overrideWith(
        (ref) => ref.watch(recordedSource).value ?? 0,
      ),
    ];

    /// ✓ işaretini saran ölçek dönüşümünün o anki büyüklüğü.
    double checkScale(WidgetTester tester) {
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      final transform = tester.widget<Transform>(
        find
            .ancestor(
              of: find.byIcon(Icons.check_circle),
              matching: find.byType(Transform),
            )
            .first,
      );
      return transform.transform.getMaxScaleOnAxis();
    }

    testWidgets('hedef tutturulunca bir kez oynar, rebuild tekrar oynatmaz', (
      tester,
    ) async {
      final recorded = StreamController<int>();
      addTearDown(recorded.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: celebrationOverrides(recorded.stream),
          child: MaterialApp(
            locale: const Locale('tr'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: AppTheme.dark(kAppPalettes.first),
            home: const Scaffold(
              body: Center(
                child: SizedBox(width: 360, height: 320, child: GoalCard()),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        find.byIcon(Icons.check_circle),
        findsNothing,
        reason: 'Hedef henüz tutmadı; ✓ hiç çizilmemeli.',
      );

      // 0 → 3600: hedef TAM ŞİMDİ tutturuldu.
      recorded.add(3600);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      expect(
        checkScale(tester),
        greaterThan(1.05),
        reason: 'Kutlama hiç oynamadı — ✓ sessizce belirdi.',
      );

      await tester.pumpAndSettle();
      expect(checkScale(tester), closeTo(1.0, 0.001));

      // Hedef zaten tutmuşken gelen yeni kayıt kutlamayı TEKRAR oynatmaz.
      recorded.add(4200);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      expect(
        checkScale(tester),
        closeTo(1.0, 0.001),
        reason:
            'Kutlama ikinci kez oynadı; kart her güncellemede kendini '
            'kutluyor.',
      );
    });

    testWidgets('disableAnimations açıkken kutlama oynamaz', (tester) async {
      final recorded = StreamController<int>();
      addTearDown(recorded.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: celebrationOverrides(recorded.stream),
          child: MaterialApp(
            locale: const Locale('tr'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: AppTheme.dark(kAppPalettes.first),
            home: Scaffold(
              body: Builder(
                builder: (context) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(disableAnimations: true),
                  child: const Center(
                    child: SizedBox(
                      width: 360,
                      height: 320,
                      child: GoalCard(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      recorded.add(3600);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      expect(
        checkScale(tester),
        closeTo(1.0, 0.001),
        reason:
            'Erişilebilirlik ayarı açıkken kutlama oynamamalı '
            '(şart, tercih değil).',
      );
    });
  });

  group('süre sabitleri', () {
    test('hiçbir hareket 320 ms\'yi aşmaz', () {
      expect(MotionTokens.maxDuration, const Duration(milliseconds: 320));
      expect(MotionTokens.all, isNotEmpty);
      for (final duration in MotionTokens.all) {
        expect(
          duration,
          greaterThan(Duration.zero),
          reason: 'Sıfır süre bir hareket değildir.',
        );
        expect(
          duration,
          lessThanOrEqualTo(MotionTokens.maxDuration),
          reason: '$duration üst sınırı aşıyor.',
        );
      }
    });

    test('hareket süreleri widget dosyalarına gömülmez', () {
      const owners = <String>[
        'lib/core/widgets/animated_stat_number.dart',
        'lib/features/home/widgets/goal_card.dart',
      ];
      for (final path in owners) {
        final file = File(path);
        expect(file.existsSync(), isTrue, reason: '$path bulunamadi');
        expect(
          file.readAsStringSync().contains('Duration('),
          isFalse,
          reason:
              '$path kendi süresini yazıyor. Süreler yalnız '
              'core/theme/motion_tokens.dart içinde durur; aksi hâlde üst '
              'sınır tek yerden ölçülemez.',
        );
      }
    });
  });

  group('sayfa geçişi', () {
    test('tema Android ve Windows için tanımlı ve süresi sınırın altında', () {
      for (final theme in [
        AppTheme.dark(kAppPalettes.first),
        AppTheme.light(kAppPalettes.first),
      ]) {
        final builders = theme.pageTransitionsTheme.builders;
        for (final platform in [
          TargetPlatform.android,
          TargetPlatform.windows,
        ]) {
          final builder = builders[platform];
          expect(
            builder,
            isA<AppPageTransitionsBuilder>(),
            reason: '$platform için özel geçiş tanımlı değil.',
          );
          expect(builder!.transitionDuration, MotionTokens.page);
          expect(
            builder.transitionDuration,
            lessThanOrEqualTo(MotionTokens.maxDuration),
          );
        }
      }
    });

    testWidgets('ileri geçişte yeni sayfa sağdan kayar', (tester) async {
      await tester.pumpWidget(_transitionProbe(disableAnimations: false));
      await tester.tap(find.text('Aç'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        tester.getTopLeft(find.byKey(const ValueKey('page2'))).dx,
        greaterThan(1.0),
        reason: 'Yeni sayfa yerinde belirdi — kayma hiç yok.',
      );

      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('page2'))).dx,
        moreOrLessEquals(0, epsilon: 0.01),
      );
    });

    testWidgets('disableAnimations açıkken sayfa kaymaz', (tester) async {
      await tester.pumpWidget(_transitionProbe(disableAnimations: true));
      await tester.tap(find.text('Aç'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        tester.getTopLeft(find.byKey(const ValueKey('page2'))).dx,
        moreOrLessEquals(0, epsilon: 0.01),
        reason:
            'Erişilebilirlik ayarı açıkken sayfa geçişi de oynamamalı; '
            'sayfa doğrudan son yerinde çizilir.',
      );
    });
  });
}

/// İki sayfalık gezinti kabı: ikinci sayfanın sol kenarı ölçülebilsin diye
/// köşede sabit boyutlu bir işaret taşır.
Widget _transitionProbe({required bool disableAnimations}) => MaterialApp(
  theme: AppTheme.dark(kAppPalettes.first),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: disableAnimations),
    child: child!,
  ),
  home: Builder(
    builder: (context) => Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const Scaffold(
                body: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    key: ValueKey('page2'),
                    width: 24,
                    height: 24,
                  ),
                ),
              ),
            ),
          ),
          child: const Text('Aç'),
        ),
      ),
    ),
  ),
);
