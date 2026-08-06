// WP-496 (V58-N10 / rapor T08): seri rozeti yalın — yalnız alev + sayı.
//
// Sahip kararı (2026-08-06): **rozette hiç yazı olmayacak**; ne durum cümlesi
// ("Henüz seri yok"), ne kapsam etiketi ("Kişisel"). Gerekçe sahibin ifadesi:
// "grup kısmında grup streak yazıyor, oradan anlaşılır zaten".
//
// Bu dosya kararın üç bedelini de ölçüyor, çünkü metin kaldırmak üç şeyi
// sessizce bozabilirdi:
//
//   1. **erişilebilirlik** — `Semantics` cümlesi metinle birlikte silinirse
//      ekran okuyucu kullanıcısı durumu tamamen kaybeder. Etiket eskisiyle
//      BİREBİR aynı kalmalı, o yüzden burada beklenen dizeler harfi harfine
//      yazılı (bir kelime değişse test kırılır).
//   2. **renk körü ayrımı** — metin gidince renk tek ayırt edici olabilirdi.
//      Ayrımı taşıyan şey (ikon, sayı) çifti; dört durumda dört ayrı değer
//      almalı. 🔴 Golden bunu göremez: `flutter test` gerçek MaterialIcons
//      fontunu yüklemez, iki farklı glif golden'da birebir aynı boş kutudur
//      (WP-454 dosyasındaki ölçülmüş uyarı). Bu yüzden `Icon.icon` doğrudan
//      okunuyor.
//   3. **çakışma** — kart şikâyetin kaynağıydı: rozet `Positioned` ile
//      içeriğin üstüne biniyordu ve çakışmayı yalnız sabit 48 px önlüyordu.
//      Aşağıdaki geometri iddiaları 1.0/1.3/1.6 ölçeklerinde **0 piksel
//      örtüşme** ölçüyor; sabit değer büyütülerek de geçilemesin diye üst
//      şeridin ölçekle birlikte BÜYÜDÜĞÜ ayrıca ölçülüyor.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/core/stats/goal_streak_projection.dart';
import 'package:online_study_room/data/models/goal_streak.dart';
import 'package:online_study_room/data/models/study_group.dart';
import 'package:online_study_room/data/models/study_session.dart';
import 'package:online_study_room/data/models/subject.dart';
import 'package:online_study_room/data/providers/group_providers.dart';
import 'package:online_study_room/data/providers/study_providers.dart';
import 'package:online_study_room/data/providers/subject_providers.dart';
import 'package:online_study_room/features/classroom/widgets/study_timer_card.dart';
import 'package:online_study_room/features/stats/widgets/goal_streak_flame.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

const _personal = GoalStreakScope.personal('user-a');
const _group = GoalStreakScope.group(
  groupId: 'group-a',
  timeZone: 'Europe/Istanbul',
);

const _allStates = <GoalStreakState>[
  GoalStreakState.completedToday,
  GoalStreakState.pendingToday,
  GoalStreakState.atRisk,
  GoalStreakState.empty,
];

GoalStreakProjection _projection(
  GoalStreakState state, {
  GoalStreakScope scope = _personal,
  int streak = 4,
}) => GoalStreakProjection(
  scope: scope,
  asOfDay: DateTime.utc(2026, 8, 6),
  currentStreak: streak,
  completionCount: streak,
  state: state,
  sourceVersion: 'goal_completion_v1',
);

Widget _wrap(Widget child, {double textScale = 1.0}) => MaterialApp(
  locale: const Locale('tr'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
    child: Scaffold(body: Center(child: child)),
  ),
);

/// Rozetin içinde çizilen tüm metinler.
List<String> _badgeTexts(WidgetTester tester) => [
  for (final text in tester.widgetList<Text>(
    find.descendant(
      of: find.byType(GoalStreakFlame),
      matching: find.byType(Text),
    ),
  ))
    if (text.data != null) text.data!,
];

/// Gerçek notifier'ın (kanal/dinleyici kuran) `build()`'ini atlayan sahte —
/// `study_timer_card_stop_test.dart` ile aynı desen.
class _IdleTimerNotifier extends StudyTimerNotifier {
  @override
  StudyTimerState build() => const StudyTimerState();
}

/// Sayaç kartını gerçek ağacıyla kurar (rozet burada `null` kapsamla, yani
/// boş projeksiyonla çizilir — geometri iddiaları için kapsam gerekmiyor).
Future<void> _pumpTimerCard(
  WidgetTester tester, {
  required double textScale,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        userSessionsProvider.overrideWith(
          (_) => Stream.value(const <StudySession>[]),
        ),
        userSubjectsProvider.overrideWith(
          (_) => Stream.value(const <Subject>[]),
        ),
        dailyGoalMinutesProvider.overrideWithValue(240),
        userGroupProvider.overrideWithValue(const AsyncData<StudyGroup?>(null)),
        studyTimerProvider.overrideWith(_IdleTimerNotifier.new),
      ],
      child: MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: const Scaffold(
            body: SizedBox(width: 380, height: 900, child: StudyTimerCard()),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('rozette hiç yazı yok (sahip kararı)', () {
    testWidgets('dört durumun dördünde de yalnız sayı çizilir', (tester) async {
      for (final state in _allStates) {
        await tester.pumpWidget(
          _wrap(GoalStreakFlame(projection: _projection(state, streak: 7))),
        );

        expect(
          _badgeTexts(tester),
          <String>['7'],
          reason:
              '$state durumunda rozette sayıdan başka metin var; sahip kararı '
              '"rozette hiç yazı olmayacak"',
        );
      }
    });

    testWidgets('kapsam etiketi de gitti (kişisel ve grup)', (tester) async {
      for (final scope in <GoalStreakScope>[_personal, _group]) {
        await tester.pumpWidget(
          _wrap(
            GoalStreakFlame(
              projection: _projection(
                GoalStreakState.completedToday,
                scope: scope,
                streak: 3,
              ),
            ),
          ),
        );

        expect(find.text('Kişisel'), findsNothing);
        expect(find.text('Grup'), findsNothing);
        expect(_badgeTexts(tester), <String>['3']);
      }
    });

    testWidgets('compact biçimde de yalnız ikon + sayı kalır', (tester) async {
      await tester.pumpWidget(
        _wrap(
          GoalStreakFlame(
            projection: _projection(GoalStreakState.atRisk, streak: 12),
            size: GoalStreakFlameSize.compact,
          ),
        ),
      );

      expect(find.byType(Icon), findsOneWidget);
      expect(_badgeTexts(tester), <String>['12']);
    });

    testWidgets('rozet küçüldü: metinli sürümden dar', (tester) async {
      // Sahip şikâyeti "rozet gereğinden büyük". Ölçüldü (tahmin değil):
      // metinli sürüm bu ağaçta **452.4 px**, yalın sürüm **58.1 px** — 7.8
      // kat dar. Sınır 120 px: yeni içeriğin (ikon + sayı + dolgu) iki katı,
      // eski sürümün dörtte biri. Yani metin geri gelirse test kırılır,
      // yazı tipi/dolgu oynamaları kırmaz.
      await tester.pumpWidget(
        _wrap(
          GoalStreakFlame(
            projection: _projection(GoalStreakState.completedToday, streak: 4),
          ),
        ),
      );

      expect(tester.getSize(find.byType(GoalStreakFlame)).width, lessThan(120));
    });
  });

  group('erişilebilirlik kanalı aynen duruyor', () {
    testWidgets('dört durum × iki kapsam için etiket birebir eski cümle', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      const expected = <(GoalStreakScope, GoalStreakState, String)>[
        (
          _personal,
          GoalStreakState.completedToday,
          'Kişisel · 5 · Bugün hedef tamamlandı',
        ),
        (
          _personal,
          GoalStreakState.pendingToday,
          'Kişisel · 5 · Bugün için hâlâ süre var',
        ),
        (
          _personal,
          GoalStreakState.atRisk,
          'Kişisel · 5 · Bugün tamamlanmazsa seri bitecek',
        ),
        (_personal, GoalStreakState.empty, 'Kişisel · 5 · Henüz seri yok'),
        (
          _group,
          GoalStreakState.completedToday,
          'Grup · 5 · Bugün hedef tamamlandı',
        ),
        (
          _group,
          GoalStreakState.pendingToday,
          'Grup · 5 · Bugün için hâlâ süre var',
        ),
        (
          _group,
          GoalStreakState.atRisk,
          'Grup · 5 · Bugün tamamlanmazsa seri bitecek',
        ),
        (_group, GoalStreakState.empty, 'Grup · 5 · Henüz seri yok'),
      ];

      for (final (scope, state, label) in expected) {
        await tester.pumpWidget(
          _wrap(
            GoalStreakFlame(
              projection: _projection(state, scope: scope, streak: 5),
            ),
          ),
        );

        expect(
          find.bySemanticsLabel(label),
          findsOneWidget,
          reason:
              'ekran okuyucu cümlesi değişti: "$label" bulunamadı. '
              'Metin görsel olarak kaldırıldı, bilgi olarak değil.',
        );
      }
      handle.dispose();
    });
  });

  group('ayrım renge bağlı değil: (ikon, sayı) çifti', () {
    testWidgets('dört durum dört ayrı çift üretir', (tester) async {
      // Gerçekçi sayılar: sıfırlanmış/boş durum modelde her zaman 0 taşır
      // (aşağıdaki model testi bunu sabitliyor), diğerleri en az 1.
      final pairs = <String>{};
      for (final state in _allStates) {
        final streak = state == GoalStreakState.empty ? 0 : 6;
        await tester.pumpWidget(
          _wrap(
            GoalStreakFlame(projection: _projection(state, streak: streak)),
          ),
        );
        final icon = tester.widget<Icon>(find.byType(Icon)).icon!;
        pairs.add('${icon.codePoint}#${_badgeTexts(tester).single}');
      }

      expect(
        pairs,
        hasLength(4),
        reason:
            'iki durum aynı (ikon, sayı) çiftine düşerse ayrım yalnız renge '
            'kalır; renk körü kullanıcı iki durumu ayıramaz',
      );
    });

    test('model garantisi: expired ve empty her zaman 0 taşır', () {
      // Yukarıdaki çift ayrımı bu garantiye dayanıyor. Garanti düşerse
      // "dolu alev + 6" iki farklı anlama gelirdi.
      final start = DateTime.utc(2026, 1, 1);
      final expired = projectGoalStreak(
        scope: _personal,
        events: [
          for (var i = 0; i < 3; i++)
            GoalProgressEvent(
              eventKey: 'e$i',
              scope: _personal,
              kind: GoalProgressEventKind.goalCompleted,
              goalDay: start.add(Duration(days: i)),
              occurredAt: start.add(Duration(days: i, hours: 20)),
            ),
        ],
        // Son tamamlamadan 5 gün sonra: seri bitti.
        asOfDay: start.add(const Duration(days: 7)),
      );
      expect(expired.state, GoalStreakState.expired);
      expect(expired.currentStreak, 0);

      final empty = projectGoalStreak(
        scope: _personal,
        events: const [],
        asOfDay: start,
      );
      expect(empty.state, GoalStreakState.empty);
      expect(empty.currentStreak, 0);
    });
  });

  group('sayaç kartında çakışma yapısal olarak imkânsız', () {
    for (final scale in <double>[1.0, 1.3, 1.6]) {
      testWidgets('rozet "Bugün" ile örtüşmüyor · ölçek $scale', (
        tester,
      ) async {
        await _pumpTimerCard(tester, textScale: scale);

        final badge = tester.getRect(find.byType(GoalStreakFlame));
        final bugun = tester.getRect(find.text('Bugün'));

        expect(
          badge.overlaps(bugun),
          isFalse,
          reason:
              'ölçek $scale: rozet $badge ile "Bugün" $bugun çakışıyor — '
              'şikâyetin ta kendisi (V58-N10)',
        );
        // 🔴 Yukarıdaki `overlaps` TEK BAŞINA yetmez ve bu ölçüldü: eski
        // `Stack` düzeninde rozet solda, "Bugün" ortada olduğu için iki
        // dikdörtgen yatayda kesişmiyor ve `overlaps` **eski kodda da**
        // false dönüyordu. Şikâyeti yakalayan iddia aşağıdaki: ölçek 1.3'te
        // rozetin alt kenarı 59, "Bugün"ün üstü 52 idi.
        expect(
          badge.bottom,
          lessThanOrEqualTo(bugun.top),
          reason: 'rozet başlık satırının üstünde, akışın parçası olmalı',
        );
      });

      testWidgets('rozet üst ikon şeridiyle de örtüşmüyor · ölçek $scale', (
        tester,
      ) async {
        await _pumpTimerCard(tester, textScale: scale);

        final badge = tester.getRect(find.byType(GoalStreakFlame));
        for (final icon in const [
          Icons.history,
          Icons.tune,
          Icons.fullscreen,
        ]) {
          expect(
            badge.overlaps(tester.getRect(find.byIcon(icon))),
            isFalse,
            reason: 'ölçek $scale: rozet ${icon.codePoint} ikonuna biniyor',
          );
        }
      });
    }

    testWidgets('üst boşluk içerikten türüyor, sabit sayı değil', (
      tester,
    ) async {
      // 🔴 Bu iddia olmadan kart sabit 48 px yerine sabit 80 px yazılarak da
      // yeşile alınabilirdi. Ölçülen şey davranış: rozet üst şeridin en uzun
      // öğesi olacak kadar büyüdüğünde başlık aşağı kayıyor mu?
      //
      // Ölçek 1.0–1.6 aralığında şeridin yüksekliğini `IconButton`ın sabit
      // 48 px'i belirliyor, rozet onun altında kalıyor — o aralıkta bu ayrım
      // ölçülemez (ölçüldü: iki ölçekte de 62.0). 3.0 rozeti 48'in üstüne
      // çıkarır; akış ise ancak o zaman sabit sayıdan ayrışır.
      await _pumpTimerCard(tester, textScale: 1.0);
      final baseline = tester.getRect(find.text('Bugün')).top;
      final smallBadge = tester.getSize(find.byType(GoalStreakFlame)).height;

      await _pumpTimerCard(tester, textScale: 3.0);
      final scaled = tester.getRect(find.text('Bugün')).top;
      final bigBadge = tester.getSize(find.byType(GoalStreakFlame)).height;

      expect(
        bigBadge,
        greaterThan(smallBadge),
        reason: 'rozet ölçekle büyümüyorsa bu testin ölçtüğü şey kalmaz',
      );
      expect(
        scaled,
        greaterThan(baseline),
        reason:
            'rozet şeridi taşırdığı hâlde "Bugün" aynı y değerinde kaldıysa '
            'üst boşluk hâlâ sabit bir sayıdır ve çakışma geri gelir',
      );
      expect(
        tester
            .getRect(find.byType(GoalStreakFlame))
            .overlaps(tester.getRect(find.text('Bugün'))),
        isFalse,
        reason: '3.0 ölçekte bile örtüşme yok',
      );
    });

    testWidgets('kart taşma çizmiyor (1.6 ölçek)', (tester) async {
      await _pumpTimerCard(tester, textScale: 1.6);
      expect(tester.takeException(), isNull);
    });
  });
}
