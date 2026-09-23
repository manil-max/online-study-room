// WP-929 — telefonda DERS ve MOD seçimi sayaç kartında görünür.
//
// 🔴 Kusur: ders seçici ve mod seçici (Kronometre / Geri sayım / Pomodoro)
// yalnız kart [kTimerFullMinHeight] (400 px) boyundan uzunsa çiziliyordu.
// Varsayılan panoda telefonda sayaç kartı ~286–316 px; yani HİÇBİR telefonda
// görünmüyordu. Yeni kullanıcının bütün süresi "Genel"e yazılıyor, Pomodoro'yu
// hiç bulamıyordu.
//
// Bu dosya kartı telefon panosundaki GERÇEK ölçüsünde (360 dp telefonda
// 328×286) çizer ve kısa kartta tek satırlık ders + mod çipini ister.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/core/theme/app_theme.dart';
import 'package:online_study_room/core/theme/theme_settings.dart';
import 'package:online_study_room/data/models/study_group.dart';
import 'package:online_study_room/data/models/study_session.dart';
import 'package:online_study_room/data/models/subject.dart';
import 'package:online_study_room/data/providers/group_providers.dart';
import 'package:online_study_room/data/providers/study_providers.dart';
import 'package:online_study_room/data/providers/subject_providers.dart';
import 'package:online_study_room/features/classroom/widgets/study_timer_card.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

/// 360 dp telefonda varsayılan panodaki sayaç hücresi (ölçüldü).
const Size _phoneCell = Size(328, 286);

/// 320 dp telefonda aynı hücre: 288 dp içerik, 28 satır (ızgara 32 sütun,
/// 8 px aralık) → 288×251.
const Size _narrowCell = Size(288, 251);

const _subjects = <Subject>[
  Subject(id: 'm', userId: 'u1', name: 'Matematik', color: 'chart-1'),
  Subject(id: 'f', userId: 'u1', name: 'Fizik', color: 'chart-2'),
];

const _subjectChip = Key('timer-quick-subject');
const _modeChip = Key('timer-quick-mode');

class _RunningTimer extends StudyTimerNotifier {
  _RunningTimer([this.mode = TimerMode.stopwatch]);

  final TimerMode mode;

  @override
  StudyTimerState build() => StudyTimerState(
    isRunning: true,
    mode: mode,
    subjectId: 'm',
    startedAt: DateTime.now().subtract(const Duration(minutes: 3)),
  );
}

/// Yükseklik iddiaları test yazı tipinde (her harf kare) anlamsızdır: gerçek
/// Roboto yüklenir, cihazdaki satır boyları ölçülür.
Future<void> _loadRoboto() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  final file = File(
    '$root/bin/cache/artifacts/material_fonts/roboto-regular.ttf',
  );
  if (root == null || !file.existsSync()) {
    fail('Roboto bulunamadi (FLUTTER_ROOT=$root); olcum yapilamaz.');
  }
  final loader = FontLoader('Roboto')
    ..addFont(file.readAsBytes().then((b) => ByteData.view(b.buffer)));
  await loader.load();
}

ThemeData _firstRunTheme() {
  final theme = AppTheme.fromFamily(
    themePresetById(kFirstRunFamilyId),
    Brightness.light,
  );
  return theme.copyWith(textTheme: theme.textTheme.apply(fontFamily: 'Roboto'));
}

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  Size cell = _phoneCell,
  Locale locale = const Locale('tr'),
  double textScale = 1.0,
  bool running = false,
  TimerMode runningMode = TimerMode.stopwatch,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        userSessionsProvider.overrideWith(
          (ref) => Stream.value(const <StudySession>[]),
        ),
        userSubjectsProvider.overrideWith((ref) => Stream.value(_subjects)),
        dailyGoalMinutesProvider.overrideWithValue(120),
        userGroupProvider.overrideWithValue(const AsyncData<StudyGroup?>(null)),
        if (running)
          studyTimerProvider.overrideWith(() => _RunningTimer(runningMode)),
      ],
      child: MaterialApp(
        // Uygulamanin ilk acilis temasi: kart kenar boslugu ve yazi boylari
        // cihazdakiyle ayni olsun.
        theme: _firstRunTheme(),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox.fromSize(size: cell, child: const StudyTimerCard()),
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 50));
  return ProviderScope.containerOf(tester.element(find.byType(StudyTimerCard)));
}

void main() {
  late AppLocalizations tr;

  setUpAll(() async {
    tr = await AppLocalizations.delegate.load(const Locale('tr'));
    await _loadRoboto();
  });

  testWidgets('kisa kartta ders ve mod cipi GORUNUR', (tester) async {
    await _pump(tester);
    expect(
      find.byKey(_subjectChip),
      findsOneWidget,
      reason:
          'Telefonun varsayilan sayac kartinda ders secimi yok: yeni kullanici '
          'butun suresini "Genel"e yaziyor.',
    );
    expect(
      find.byKey(_modeChip),
      findsOneWidget,
      reason: 'Telefonda Pomodoro/geri sayim secimi hic gorunmuyor.',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('ders cipi mevcut ders menusunu acar ve secim sayaca yazilir', (
    tester,
  ) async {
    final c = await _pump(tester);
    await tester.tap(find.byKey(_subjectChip));
    await tester.pumpAndSettle();
    expect(find.text(tr.classroomDersleriDuzenle), findsOneWidget);
    await tester.tap(find.text('Fizik').last);
    await tester.pumpAndSettle();
    expect(c.read(studyTimerProvider).subjectId, 'f');
    expect(
      find.descendant(
        of: find.byKey(_subjectChip),
        matching: find.text('Fizik'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('mod cipi Pomodoro secer (mevcut setMode API)', (tester) async {
    final c = await _pump(tester);
    expect(c.read(studyTimerProvider).mode, TimerMode.stopwatch);
    await tester.tap(find.byKey(_modeChip));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr.classroomPomodoro).last);
    await tester.pumpAndSettle();
    expect(c.read(studyTimerProvider).mode, TimerMode.pomodoro);
    expect(
      find.descendant(
        of: find.byKey(_modeChip),
        matching: find.text(tr.classroomPomodoro),
      ),
      findsOneWidget,
    );
  });

  testWidgets('calisirken: ders KILITLI etiket olarak gorunur, mod cipi yok', (
    tester,
  ) async {
    await _pump(tester, running: true);
    expect(
      find.descendant(
        of: find.byKey(_subjectChip),
        matching: find.text('Matematik'),
      ),
      findsOneWidget,
      reason: 'Calisirken hangi dersin sayildigi kartta yazmali.',
    );
    expect(find.byKey(_modeChip), findsNothing);
    await tester.tap(find.byKey(_subjectChip), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(
      find.text(tr.classroomDersleriDuzenle),
      findsNothing,
      reason: 'Uzun kartta oldugu gibi calisirken ders degistirilemez.',
    );
  });

  testWidgets('uzun kartta satir tekrar edilmez (tam seciciler zaten var)', (
    tester,
  ) async {
    await _pump(tester, cell: const Size(360, kTimerFullMinHeight + 240));
    expect(find.byKey(_modeChip), findsNothing);
  });

  for (final locale in const [Locale('tr'), Locale('en')]) {
    for (final cell in const [_phoneCell, _narrowCell]) {
      for (final scale in const [1.0, 1.3]) {
        testWidgets(
          'tasma yok: ${locale.languageCode} ${cell.width.toInt()} dp '
          'olcek $scale',
          (tester) async {
            await _pump(tester, cell: cell, locale: locale, textScale: scale);
            expect(find.byKey(_modeChip), findsOneWidget);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  double cardScroll(WidgetTester tester) => tester
      .state<ScrollableState>(
        find
            .descendant(
              of: find.byType(StudyTimerCard),
              matching: find.byType(Scrollable),
            )
            .first,
      )
      .position
      .maxScrollExtent;

  for (final cell in const [_phoneCell, _narrowCell]) {
    testWidgets(
      'olcek 1.0 ${cell.width.toInt()} dp telefonda kart ICI kaydirma cikmaz',
      (tester) async {
        await _pump(tester, cell: cell);
        expect(
          cardScroll(tester),
          0,
          reason:
              'Satir eklendi diye kart icinde kaydirma cikarsa parmak ana ekrani '
              'kaydiramaz (WP-646).',
        );
      },
    );
  }

  // Kronometre varsayilan moddur. Geri sayim/Pomodoro calisirken faz
  // gostergesi ek bir satir cizer; o kaydirma bu isten ONCE de vardi (~42 px)
  // ve burada azaldi, sifirlanmadi — ayri is olarak raporlandi.
  testWidgets('calisirken (kronometre) de kart ici kaydirma cikmaz', (
    tester,
  ) async {
    await _pump(tester, running: true);
    expect(cardScroll(tester), 0);
  });
}
