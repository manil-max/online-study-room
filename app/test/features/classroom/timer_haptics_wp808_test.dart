import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/data/models/study_group.dart';
import 'package:online_study_room/data/models/study_session.dart';
import 'package:online_study_room/data/models/subject.dart';
import 'package:online_study_room/data/providers/group_providers.dart';
import 'package:online_study_room/data/providers/study_providers.dart';
import 'package:online_study_room/data/providers/subject_providers.dart';
import 'package:online_study_room/features/classroom/widgets/focus_timer_screen.dart';
import 'package:online_study_room/features/classroom/widgets/study_timer_card.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

/// WP-808/2 — sayaç dokunsal geri bildirimi **ölçülür**.
///
/// 🔴 WP-808 titreşimleri ekledi ama testini yazamadı ("haptic çağrıları için
/// birim testi yazmadım"). Oysa ölçülebilir: `HapticFeedback.mediumImpact()`
/// `SystemChannels.platform` üzerinden `HapticFeedback.vibrate` çağırır ve
/// argümanı taşır. Ölçmeyen bir titreşim, sessizce kaybolur — üstelik
/// kullanıcı bunu yalnız cihazda fark eder.
///
/// Bu dosyanın ASIL iddiası tek bir titreşim değil: **kuralın tek yerde
/// yaşadığı**. WP-808 darbeyi kartın `onPressed`ine koymuştu; tam ekran odak
/// ekranı aynı yardımcıyı çağırdığı hâlde titreşimsiz kalıyordu — yani
/// `stopTimerFromSurface`ın kendi yorumundaki WP-560 dersi ("aynı kuralın iki
/// yüzeyde ayrık yaşaması") darbe için aynen tekrarlanmıştı.
class _FakeTimerNotifier extends StudyTimerNotifier {
  _FakeTimerNotifier(this._initial);

  final StudyTimerState _initial;
  var stopCalls = 0;
  var startCalls = 0;

  @override
  StudyTimerState build() => _initial;

  @override
  Future<void> stop({DateTime? at, String? trigger}) async {
    stopCalls++;
    state = const StudyTimerState();
  }

  @override
  void start({bool guardAccidentalRestart = true, String trigger = ''}) {
    startCalls++;
    state = StudyTimerState(isRunning: true, startedAt: DateTime.now());
  }
}

/// Platform kanalına düşen darbeleri sırayla toplar.
List<String> _recordHaptics(WidgetTester tester) {
  final seen = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        seen.add((call.arguments as String?) ?? 'default');
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  return seen;
}

Future<void> _pumpCard(WidgetTester tester, _FakeTimerNotifier notifier) async {
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
        studyTimerProvider.overrideWith(() => notifier),
      ],
      child: MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: SizedBox(width: 380, height: 900, child: StudyTimerCard()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('baslat HAFIF darbe verir', (tester) async {
    final haptics = _recordHaptics(tester);
    final idle = _FakeTimerNotifier(const StudyTimerState());
    await _pumpCard(tester, idle);

    await tester.tap(find.text('Çalışmaya başla'));
    await tester.pumpAndSettle();

    expect(idle.startCalls, 1);
    expect(
      haptics,
      ['HapticFeedbackType.lightImpact'],
      reason: 'Baslat hafif olmali: sik yapilan, geri donusu kolay eylem.',
    );
  });

  testWidgets('durdur ORTA darbe verir', (tester) async {
    final haptics = _recordHaptics(tester);
    final running = _FakeTimerNotifier(
      StudyTimerState(
        isRunning: true,
        startedAt: DateTime.now().subtract(const Duration(minutes: 3)),
      ),
    );
    await _pumpCard(tester, running);

    await tester.tap(find.text('Durdur'));
    await tester.pumpAndSettle();

    expect(running.stopCalls, 1);
    expect(
      haptics,
      ['HapticFeedbackType.mediumImpact'],
      reason:
          'Durdur daha agir bir olaydir; ekrana bakmadan hangisine bastigin '
          'anlasilsin.',
    );
  });

  /// 🔴 ASIL DIKIS. Kart ile tam ekran odak ekrani AYNI yardimciyi cagirir;
  /// darbe o yardimicinin ICINDE oldugu icin ikisi de ayni sekilde davranir.
  /// Darbe cagri yerine konsaydi bu test kirmizi olurdu -- WP-808'de tam
  /// olarak oyleydi.
  testWidgets('durdurma darbesi ORTAK yardimcida yasar, cagri yerinde degil', (
    tester,
  ) async {
    final haptics = _recordHaptics(tester);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final notifier = _FakeTimerNotifier(
      StudyTimerState(
        isRunning: true,
        startedAt: DateTime.now().subtract(const Duration(minutes: 3)),
      ),
    );

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
          userGroupProvider.overrideWithValue(
            const AsyncData<StudyGroup?>(null),
          ),
          studyTimerProvider.overrideWith(() => notifier),
        ],
        child: MaterialApp(
          locale: const Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => stopTimerFromSurface(context, ref),
                  child: const Text('tam ekran durdur'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('tam ekran durdur'));
    await tester.pumpAndSettle();

    expect(notifier.stopCalls, 1);
    expect(
      haptics,
      ['HapticFeedbackType.mediumImpact'],
      reason:
          'Tam ekran odak ekrani karti degil ORTAK yardimciyi cagirir; darbe '
          'yardimicinin icinde degilse bu yuzey sessiz kalir.',
    );
  });

  testWidgets('durdurma darbesi CIFT verilmez', (tester) async {
    final haptics = _recordHaptics(tester);
    final running = _FakeTimerNotifier(
      StudyTimerState(
        isRunning: true,
        startedAt: DateTime.now().subtract(const Duration(minutes: 3)),
      ),
    );
    await _pumpCard(tester, running);
    await tester.tap(find.text('Durdur'));
    await tester.pumpAndSettle();
    expect(
      haptics.length,
      1,
      reason:
          'Darbe hem cagri yerinde hem yardimicida olursa kullanici cift '
          'titresim hisseder.',
    );
  });
}
