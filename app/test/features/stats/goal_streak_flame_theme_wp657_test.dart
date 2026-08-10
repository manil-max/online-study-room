// WP-657 (V64 sahip geri bildirimi, 2026-08-10):
//
//   "hâlâ günlük ve grup serisindeki işaret soluk ama tam belli olmuyor;
//    gri renk daha güzel olur. ... pause modu da var mı bilmiyorum kontrol et,
//    hiç deneyimleme fırsatım olmadı."
//
// 🔴 Bu dosya rengi BEĞENİ ile değil ÖLÇÜM ile sınar. Var olan seri testleri
// (`goal_streak_flame_wp454_test.dart`, `goal_streak_surface_wp481_test.dart`,
// `goal_streak_badge_wp496_test.dart`) rozeti hep `ThemeData(brightness: ...)`
// varsayılan Material şemasında pump ediyor. Uygulamanın gerçekte kullandığı
// 15 hazır tema hiçbirinde kurulmuyor — yani "ekranda okunuyor mu" sorusu
// bugüne kadar HİÇ ölçülmedi.
//
// Depoda bu hata sınıfının kendi kapısı var: `theme_contrast_gate_wp627_test`
// tüm hazır temaları tarar. Seri rozetinin renkleri o kapıya bağlı DEĞİLDİ:
// `goal_streak_flame.dart` sabit `Color(0xFF...)` değerleri yazıyor ve
// `Color.lerp(..., scheme.surface, 0.55)` ile onları zemine doğru
// soluklaştırıyordu. Soluklaştırma zemine YAKLAŞTIRMAK demektir; kontrast
// tanım gereği düşer.
//
// Ölçülen şey kullanıcının GÖRDÜĞÜ satırdır: rozet gerçek `Card` yüzeyinin
// üstünde pump edilir, ikonun ve sayının **çizilen** rengi okunur, rozet
// dolgusu kart yüzeyine alpha-blend edilir ve WCAG oranı bu bileşik zemine
// göre hesaplanır.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/theme/app_theme.dart';
import 'package:online_study_room/core/theme/warning_tokens.dart';
import 'package:online_study_room/data/models/goal_streak.dart';
import 'package:online_study_room/data/providers/goal_streak_providers.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_goal_streak_repository.dart';
import 'package:online_study_room/features/stats/widgets/goal_streak_flame.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

const _states = <GoalStreakState>[
  GoalStreakState.completedToday,
  GoalStreakState.pendingToday,
  GoalStreakState.atRisk,
  GoalStreakState.empty,
];

GoalStreakProjection _projection(GoalStreakState state) => GoalStreakProjection(
  scope: const GoalStreakScope.personal('u1'),
  asOfDay: DateTime.utc(2026, 8, 10),
  currentStreak: state == GoalStreakState.empty ? 0 : 5,
  completionCount: state == GoalStreakState.empty ? 0 : 5,
  state: state,
  sourceVersion: 'test',
);

/// 🔴 ÖLÇÜM AYGITININ KENDİ TUZAĞI (bu turda ölçüldü).
///
/// `MaterialApp` temayı `AnimatedTheme` ile **200 ms boyunca lerp eder**. Aynı
/// ağacı yeni bir `theme:` ile tek `pump()` atarak yeniden çizmek, temayı
/// animasyonun BAŞINDA yakalar: `Theme.of(context)` hâlâ bir önceki temanın
/// şemasını verir. Tema tarayan bir döngüde bu, ilk temanın 15 kez ölçülmesi
/// demektir — kapı yeşil yanar, hiçbir şey ölçülmemiştir.
///
/// İlk taslakta tam bu oldu: koyu `campfire_night` ilk sıradaydı ve AÇIK
/// temaların `pending_today` ölçümü 1.65 yerine 9.67 çıkıyordu.
///
/// İki savunma birden: `themeAnimationDuration: Duration.zero` **ve** her
/// pump'ta benzersiz `key` (ağaç baştan kurulur, eski `Element` yeniden
/// kullanılmaz).
Widget _harness(
  ThemeData theme,
  GoalStreakProjection projection, {
  required String slot,
}) => MaterialApp(
  key: ValueKey(slot),
  locale: const Locale('tr'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: theme,
  themeAnimationDuration: Duration.zero,
  home: Scaffold(
    body: Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: GoalStreakFlame(projection: projection),
        ),
      ),
    ),
  ),
);

/// Rozetin çizilen üç rengi: ikon, sayı ve karta blend edilmiş dolgu.
class _Painted {
  const _Painted({
    required this.icon,
    required this.text,
    required this.effectiveBackground,
    required this.cardSurface,
  });

  final Color icon;
  final Color text;
  final Color effectiveBackground;
  final Color cardSurface;
}

Finder _flameIcon() => find.descendant(
  of: find.byType(GoalStreakFlame),
  matching: find.byType(Icon),
);

Future<_Painted> _paint(
  WidgetTester tester,
  ThemeData theme,
  GoalStreakState state, {
  required String slot,
}) async {
  await tester.pumpWidget(_harness(theme, _projection(state), slot: slot));
  await tester.pumpAndSettle();

  final cardSurface = theme.cardTheme.color ?? theme.colorScheme.surface;
  final container = tester.widget<Container>(
    find
        .descendant(
          of: find.byType(GoalStreakFlame),
          matching: find.byType(Container),
        )
        .first,
  );
  final decoration = container.decoration! as BoxDecoration;
  final icon = tester.widget<Icon>(_flameIcon());
  final textWidget = tester.widget<Text>(
    find.descendant(
      of: find.byType(GoalStreakFlame),
      matching: find.byType(Text),
    ),
  );

  return _Painted(
    icon: icon.color!,
    text: textWidget.style!.color!,
    // Dolgu yarı saydam olabilir: kullanıcının gördüğü zemin, karta blend
    // edilmiş hâlidir.
    effectiveBackground: Color.alphaBlend(decoration.color!, cardSurface),
    cardSurface: cardSurface,
  );
}

void main() {
  group('seri rozeti — hazır temalar × 4 durum kontrast kapısı', () {
    testWidgets('ikon zemininde ≥ 3.0, sayı zemininde ≥ 4.5', (tester) async {
      final failures = <String>[];
      var measured = 0;

      for (final preset in kThemePresets) {
        final theme = AppTheme.fromPreset(preset);
        for (final state in _states) {
          final painted = await _paint(
            tester,
            theme,
            state,
            slot: '${preset.id}-${state.wireValue}-a',
          );

          measured++;
          final iconRatio = contrastRatio(
            painted.icon,
            painted.effectiveBackground,
          );
          if (iconRatio < kMinSurfaceContrast) {
            failures.add(
              '${preset.id}  ${state.wireValue}  ikon/dolgu = '
              '${iconRatio.toStringAsFixed(2)}',
            );
          }

          measured++;
          final textRatio = contrastRatio(
            painted.text,
            painted.effectiveBackground,
          );
          if (textRatio < kMinTextContrast) {
            failures.add(
              '${preset.id}  ${state.wireValue}  sayı/dolgu = '
              '${textRatio.toStringAsFixed(2)}',
            );
          }
        }
      }

      // Kapı boşa dönmesin: tema veya durum listesi kazara boşalırsa kırmızı.
      expect(measured, kThemePresets.length * _states.length * 2);
      expect(failures, isEmpty, reason: '\n${failures.join('\n')}');
    });

    testWidgets('rozet dolgusu kart yüzeyinden ayrışır (≥ 1.15)', (
      tester,
    ) async {
      // Dolgu karttan hiç ayrışmazsa rozet "kutu" olarak da görünmez; geriye
      // yalnız ikon kalır ve sahibin "tam belli olmuyor" şikâyeti buradan da
      // beslenir. Eşik düşük tutuldu: amaç bağıran bir kutu değil, var olan
      // bir kutu.
      final failures = <String>[];
      for (final preset in kThemePresets) {
        final theme = AppTheme.fromPreset(preset);
        for (final state in _states) {
          final painted = await _paint(
            tester,
            theme,
            state,
            slot: '${preset.id}-${state.wireValue}-b',
          );
          final ratio = contrastRatio(
            painted.effectiveBackground,
            painted.cardSurface,
          );
          if (ratio < 1.15) {
            failures.add(
              '${preset.id}  ${state.wireValue}  dolgu/kart = '
              '${ratio.toStringAsFixed(3)}',
            );
          }
        }
      }
      expect(failures, isEmpty, reason: '\n${failures.join('\n')}');
    });
  });

  group('sahip kararı — bekleyen ve sıfırlanmış durum GRİ', () {
    testWidgets('pendingToday ikonu her temada nötr (doygunluk ≤ 0.12)', (
      tester,
    ) async {
      // 🔴 V64 sahip emri: "gri renk daha güzel olur". Eski kod solmuş TURUNCU
      // kullanıyordu (`Color.lerp(0xFFEA580C, surface, 0.55)`), yani doygunluk
      // yüksek kalıyordu ve "soluk turuncu" ile "canlı turuncu" rozet boyutunda
      // ayırt edilemiyordu.
      final failures = <String>[];
      for (final preset in kThemePresets) {
        final theme = AppTheme.fromPreset(preset);
        final painted = await _paint(
          tester,
          theme,
          GoalStreakState.pendingToday,
          slot: '${preset.id}-pending',
        );
        final saturation = HSLColor.fromColor(painted.icon).saturation;
        if (saturation > 0.12) {
          failures.add(
            '${preset.id}  pending doygunluk = ${saturation.toStringAsFixed(2)}',
          );
        }
      }
      expect(failures, isEmpty, reason: '\n${failures.join('\n')}');
    });

    testWidgets('empty/expired ikonu her temada nötr (doygunluk ≤ 0.12)', (
      tester,
    ) async {
      final failures = <String>[];
      for (final preset in kThemePresets) {
        final theme = AppTheme.fromPreset(preset);
        final painted = await _paint(
          tester,
          theme,
          GoalStreakState.empty,
          slot: '${preset.id}-empty',
        );
        final saturation = HSLColor.fromColor(painted.icon).saturation;
        if (saturation > 0.12) {
          failures.add(
            '${preset.id}  empty doygunluk = ${saturation.toStringAsFixed(2)}',
          );
        }
      }
      expect(failures, isEmpty, reason: '\n${failures.join('\n')}');
    });

    testWidgets('canlı alev NÖTR DEĞİL — üç durum tek griye çökmez', (
      tester,
    ) async {
      // Karşı iddia: her şeyi grileştirip kapıyı geçmek. `completedToday`
      // sahibin 3. durumu ve "renkli ateş" olarak yazılı.
      for (final preset in kThemePresets) {
        final theme = AppTheme.fromPreset(preset);
        final painted = await _paint(
          tester,
          theme,
          GoalStreakState.completedToday,
          slot: '${preset.id}-completed',
        );
        expect(
          HSLColor.fromColor(painted.icon).saturation,
          greaterThan(0.35),
          reason: '${preset.id}: canlı alev grileşmiş',
        );
      }
    });
  });

  group('dört durum birbirinden ayrık kalır', () {
    testWidgets('(ikon, renk) çifti her temada dört ayrı değer üretir', (
      tester,
    ) async {
      for (final preset in kThemePresets) {
        final theme = AppTheme.fromPreset(preset);
        final signatures = <String>{};
        for (final state in _states) {
          await tester.pumpWidget(
            _harness(
              theme,
              _projection(state),
              slot: '${preset.id}-${state.wireValue}-c',
            ),
          );
          await tester.pumpAndSettle();
          final icon = tester.widget<Icon>(_flameIcon());
          signatures.add('${icon.icon!.codePoint}:${icon.color!.toARGB32()}');
        }
        expect(
          signatures,
          hasLength(_states.length),
          reason:
              '${preset.id}: iki durum aynı (ikon, renk) çiftine düştü — '
              'kullanıcı ayırt edemez',
        );
      }
    });

    testWidgets('pause durumu pause glifi çizer ve her temada kalır', (
      tester,
    ) async {
      for (final preset in kThemePresets) {
        final theme = AppTheme.fromPreset(preset);
        await tester.pumpWidget(
          _harness(
            theme,
            _projection(GoalStreakState.atRisk),
            slot: '${preset.id}-atrisk',
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester.widget<Icon>(_flameIcon()).icon,
          Icons.pause_circle_outline,
          reason: '${preset.id}: duraklatma glifi kayboldu',
        );
      }
    });
  });

  // ---------------------------------------------------------------------
  // Sahip: "pause modu da var mı bilmiyorum kontrol et, hiç deneyimleme
  // fırsatım olmadı."
  //
  // Yukarıdaki iddialar rozete ELLE bir projeksiyon veriyor; bu grup vermiyor.
  // Burada zincirin tamamı koşuyor: hedef olayları → `projectGoalStreak`
  // (SQL `goal_streak_projection` ile aynı algoritma, `0112`) → repository →
  // `goalStreakProjectionProvider` → `GoalStreakBadge`. Yani "durum kodda var"
  // değil, "kullanıcı o günde uygulamayı açınca ekranda pause görür" ölçülüyor.
  //
  // 🔴 Bu depoda kanıtlanmış hata sınıfı: backend tamam, `lib/` içinde çağrı
  // yeri yok → özellik yok ama testler yeşil. Ölçüm o yüzden ekranın okuduğu
  // yoldan geçiyor.
  group('pause durumu ULAŞILABİLİR — olaydan ekrana', () {
    const personal = GoalStreakScope.personal('u-pause');
    const group = GoalStreakScope.group(
      groupId: 'g-pause',
      timeZone: 'Europe/Istanbul',
    );

    /// Sahibin 2. durumu: **önceki gün** hedef tutturuldu, **dün** kaçırıldı.
    /// Bugün 10 Ağustos → son tamamlama 8 Ağustos (mesafe 2) → `at_risk`.
    List<GoalProgressEvent> pausedHistory(GoalStreakScope scope) => [
      for (final day in const [4, 6, 8])
        GoalProgressEvent(
          eventKey: '${scope.ledgerKey}:$day',
          scope: scope,
          kind: GoalProgressEventKind.goalCompleted,
          goalDay: DateTime.utc(2026, 8, day),
          occurredAt: DateTime.utc(2026, 8, day, 20),
        ),
    ];

    Widget liveBadge(
      GoalStreakScope scope,
      ThemeData theme,
      List<GoalProgressEvent> events,
    ) => ProviderScope(
      overrides: [
        goalStreakRepositoryProvider.overrideWithValue(
          InMemoryGoalStreakRepository(
            initialEvents: events,
            now: () => DateTime.utc(2026, 8, 10, 9),
          ),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: theme,
        themeAnimationDuration: Duration.zero,
        home: Scaffold(
          body: Center(
            child: Card(child: GoalStreakBadge(scope: scope)),
          ),
        ),
      ),
    );

    for (final (name, scope) in <(String, GoalStreakScope)>[
      ('kişisel', personal),
      ('grup', group),
    ]) {
      testWidgets('$name seri: dün kaçırıldıysa ekranda PAUSE belirir', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          liveBadge(
            scope,
            AppTheme.fromPreset(themePresetById('campfire_night')),
            pausedHistory(scope),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          tester.widget<Icon>(_flameIcon()).icon,
          Icons.pause_circle_outline,
          reason: '$name kapsamda duraklatma ekrana hiç ulaşmıyor',
        );
        // Koruma sınırsız: seri sıfırlanmadı, üç tamamlama ayakta duruyor.
        expect(find.text('3'), findsOneWidget);
        expect(
          tester.getSemantics(find.byType(GoalStreakFlame)).label,
          endsWith('Bugün tamamlanmazsa seri bitecek'),
        );
        handle.dispose();
      });
    }

    testWidgets('bugün tamamlanınca pause düşer, canlı ateş gelir', (
      tester,
    ) async {
      await tester.pumpWidget(
        liveBadge(
          personal,
          AppTheme.fromPreset(themePresetById('campfire_night')),
          [
            ...pausedHistory(personal),
            GoalProgressEvent(
              eventKey: '${personal.ledgerKey}:10',
              scope: personal,
              kind: GoalProgressEventKind.goalCompleted,
              goalDay: DateTime.utc(2026, 8, 10),
              occurredAt: DateTime.utc(2026, 8, 10, 8),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester.widget<Icon>(_flameIcon()).icon,
        Icons.local_fire_department,
      );
      // Sahibin tarifi: "yapılırsa normal 3. duruma geçilecek" ve sayı artar.
      expect(find.text('4'), findsOneWidget);
    });
  });

  group('kapı kendini sınar', () {
    testWidgets('harness temayı GERÇEKTEN değiştiriyor (bayat şema kapanı)', (
      tester,
    ) async {
      // 🔴 Bu iddia olmadan yukarıdaki bütün kapı sahteydi. `AnimatedTheme`
      // yüzünden ikinci ve sonraki temalar birincinin şemasını görüyordu;
      // ölçüm 15 tema değil 1 tema × 15 tekrar oluyordu.
      final dark = AppTheme.fromPreset(themePresetById('campfire_night'));
      final light = AppTheme.fromPreset(themePresetById('nordic_snow'));
      expect(dark.colorScheme.brightness, Brightness.dark);
      expect(light.colorScheme.brightness, Brightness.light);

      final darkFirst = await _paint(
        tester,
        dark,
        GoalStreakState.empty,
        slot: 'stale-1',
      );
      final lightSecond = await _paint(
        tester,
        light,
        GoalStreakState.empty,
        slot: 'stale-2',
      );
      // `empty` durumunun zemini şemadan türetilir; tema uygulanmadıysa iki
      // ölçüm BİREBİR aynı çıkar.
      expect(
        lightSecond.effectiveBackground,
        isNot(equals(darkFirst.effectiveBackground)),
        reason: 'tema değişimi widget\'a ulaşmıyor — ölçüm bayat şemayı okuyor',
      );
      expect(
        lightSecond.cardSurface.computeLuminance(),
        greaterThan(darkFirst.cardSurface.computeLuminance()),
      );
    });

    testWidgets('kasten zemine gömülü bir ön plan ihlal olarak yakalanır', (
      tester,
    ) async {
      // Ölçüm aygıtının kendisi: eski `pendingToday` renginin koyu temadaki
      // birebir hesabı. Kapı bunu geçirirse kapı bozuktur.
      const darkSurface = Color(0xFF12161E);
      final oldPendingForeground = Color.lerp(
        const Color(0xFFEA580C),
        darkSurface,
        0.55,
      )!;
      final oldPendingBackground = Color.alphaBlend(
        const Color(0xFFEA580C).withValues(alpha: 0.06),
        darkSurface,
      );
      expect(
        contrastRatio(oldPendingForeground, oldPendingBackground),
        lessThan(kMinSurfaceContrast),
      );
    });
  });
}
