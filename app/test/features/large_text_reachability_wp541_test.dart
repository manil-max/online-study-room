// WP-541: buyuk yazi olceginde erisilemeyen ekranlar + tema korumasiz aciliyet
// renkleri.
//
// Bu dosya UC ayri sinifi olcer, hepsi ayni kok nedene bakar: "ekranda duruyor"
// ile "kullaniciya ulasiyor" ayni sey degil.
//
// 1. Bos durum ekranlari `Center` + `Column` ile kuruluyordu. Icerik viewport'u
//    astiginda kaydirma YOKTU: `Scrollable` sayisi 0 idi, yani buyuk sistem
//    yazisi secmis kullanici "Koda katil" / "Gruplari kesfet" dugmelerine
//    hicbir sekilde ulasamiyordu. Olcum (360x720, scale=2.0, duzeltme oncesi):
//    Create[324..570] GORUNUR, Join[682..762] EKRAN-DISI, Discover[770..850]
//    EKRAN-DISI, scrollable=0.
// 2. "Bugun ozeti" basligi `Row([Text, Spacer(), Text])` idi; ucu de esnek
//    degildi, bu yuzden VARSAYILAN yazi olcusunde bile dar telefonda tasiyordu.
// 3. Gorev aciliyet renkleri sabit hex'ti (`0xFFB91C1C` vb.). "Gecikti"
//    kirmizisi 11 koyu temanin hepsinde 2.1-2.9 kontrast veriyordu; metin-disi
//    3.0 tabaninin bile altinda.
//
// Testin sozlesmesi: hem TASMA yok, hem ERISIM var. Yalniz `takeException`
// bakmak yetmez — kaydirilamayan ama tasmayan bir duzen de kirik.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// `Override` tipi ana pakette degil (Riverpod 3).
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/core/tasks/task_deadline.dart';
import 'package:online_study_room/core/theme/app_theme.dart';
import 'package:online_study_room/core/theme/warning_tokens.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/models/study_group.dart';
import 'package:online_study_room/data/models/study_session.dart';
import 'package:online_study_room/data/models/subject.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/group_providers.dart';
import 'package:online_study_room/data/providers/study_providers.dart';
import 'package:online_study_room/data/providers/subject_providers.dart';
import 'package:online_study_room/features/classroom/classroom_screen.dart';
import 'package:online_study_room/features/home/widgets/today_summary_card.dart';
import 'package:online_study_room/features/stats/stats_screen.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Olculen telefon matrisi: en dar yaygin cihaz, referans cihaz, genis cihaz.
const List<(double, double)> _screens = [(320, 640), (360, 720), (411, 731)];

/// 1.0 = varsayilan, 2.0 = Android "en buyuk" yazi boyutu.
const List<double> _scales = [1.0, 2.0];

/// Cizim hatalarini toplayarak pump eder; donen liste bos = temiz kare.
Future<List<String>> _pump(
  WidgetTester tester, {
  required Widget home,
  required List<Override> overrides,
  required double width,
  required double height,
  required double scale,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final errors = <FlutterErrorDetails>[];
  final previous = FlutterError.onError;
  FlutterError.onError = errors.add;

  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
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
        home: home,
      ),
    ),
  );
  // Akislar otursun; `pumpAndSettle` yok (kartlar periyodik timer tasir).
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));

  FlutterError.onError = previous;
  return errors.map((detail) => detail.exceptionAsString()).toList();
}

/// Hedefin gercekten kullaniciya ulastigini kanitlar: ya ekranda, ya da bir
/// `Scrollable` ile ekrana getirilebiliyor. Ikisi de yoksa ozellik yok demektir.
Future<void> _expectReachable(
  WidgetTester tester,
  Finder finder,
  double screenHeight,
  String label,
) async {
  expect(finder, findsOneWidget, reason: '$label agacta yok');
  var rect = tester.getRect(finder);
  if (rect.top < 0 || rect.bottom > screenHeight) {
    final scrollables = find.byType(Scrollable);
    expect(
      scrollables,
      findsWidgets,
      reason:
          '$label ekran disinda ([${rect.top.toStringAsFixed(0)}..'
          '${rect.bottom.toStringAsFixed(0)}] / $screenHeight) ve ekranda hic '
          'Scrollable yok — kullanici bu dugmeye asla ulasamaz.',
    );
    await tester.scrollUntilVisible(finder, 80, scrollable: scrollables.first);
    await tester.pump();
    rect = tester.getRect(finder);
  }
  expect(
    rect.top >= -0.5 && rect.bottom <= screenHeight + 0.5,
    isTrue,
    reason:
        '$label kaydirmadan sonra da ekran disinda: '
        '[${rect.top.toStringAsFixed(0)}..${rect.bottom.toStringAsFixed(0)}] '
        '/ $screenHeight',
  );
}

/// Hedefin **dikey** kaydirilabilir bir govde icinde durdugunu sayar.
///
/// `find.byType(Scrollable)` tek basina yetmez: `TabBarView` yatay bir
/// `Scrollable` kurar, yani bos durum hic kayamiyorken bile sayac 0 degildir.
int _verticalScrollAncestors(WidgetTester tester, Finder of) => find
    .ancestor(of: of, matching: find.byType(Scrollable))
    .evaluate()
    .where((element) {
      final axis = (element.widget as Scrollable).axisDirection;
      return axis == AxisDirection.down || axis == AxisDirection.up;
    })
    .length;

List<Override> _classroomOverrides(SharedPreferences prefs) => [
  sharedPreferencesProvider.overrideWithValue(prefs),
  userGroupProvider.overrideWithValue(const AsyncData<StudyGroup?>(null)),
  authStateProvider.overrideWith(
    (ref) => Stream.value(
      Profile(id: 'u1', displayName: 'Ben', createdAt: DateTime(2026, 1, 1)),
    ),
  ),
];

List<Override> _statsOverrides(SharedPreferences prefs) => [
  sharedPreferencesProvider.overrideWithValue(prefs),
  authStateProvider.overrideWith(
    (ref) => Stream.value(
      Profile(id: 'u1', displayName: 'Ben', createdAt: DateTime(2026, 1, 1)),
    ),
  ),
  userSessionsProvider.overrideWith((ref) => Stream.value(<StudySession>[])),
  userSubjectsProvider.overrideWith((ref) => Stream.value(<Subject>[])),
  dailyGoalMinutesProvider.overrideWithValue(120),
];

List<Override> _summaryOverrides() => [
  authStateProvider.overrideWith(
    (ref) => Stream.value(
      Profile(id: 'u1', displayName: 'Ben', createdAt: DateTime(2026, 1, 1)),
    ),
  ),
  userSessionsProvider.overrideWith(
    (ref) => Stream.value(<StudySession>[
      StudySession(
        id: 's1',
        userId: 'u1',
        subjectId: 'sub-1',
        start: DateTime.now().subtract(const Duration(hours: 12)),
        end: DateTime.now(),
        durationSeconds: 12 * 3600 + 34 * 60,
        source: StudySource.live,
      ),
    ]),
  ),
  userSubjectsProvider.overrideWith(
    (ref) => Stream.value(<Subject>[
      const Subject(
        id: 'sub-1',
        userId: 'u1',
        name: 'Matematik',
        color: 'chart-1',
      ),
    ]),
  ),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WP-541/1 — grupsuz bos durum buyuk yazida erisilebilir', () {
    for (final (width, height) in _screens) {
      for (final scale in _scales) {
        testWidgets('${width.toInt()}x${height.toInt()} scale=$scale', (
          tester,
        ) async {
          SharedPreferences.setMockInitialValues({});
          final prefs = await SharedPreferences.getInstance();

          final errors = await _pump(
            tester,
            home: const ClassroomScreen(),
            overrides: _classroomOverrides(prefs),
            width: width,
            height: height,
            scale: scale,
          );
          expect(errors, isEmpty, reason: 'bos durum tasti: $errors');

          // Uc yol da ulasilabilir olmali; davet kodu almis kullanici
          // "Koda katil" olmadan uygulamaya hic giremez.
          await _expectReachable(
            tester,
            find.widgetWithText(FilledButton, 'Grup oluştur'),
            height,
            'Grup olustur',
          );
          await _expectReachable(
            tester,
            find.widgetWithText(OutlinedButton, 'Koda katıl'),
            height,
            'Koda katil',
          );
          await _expectReachable(
            tester,
            find.widgetWithText(TextButton, 'Grupları keşfet'),
            height,
            'Gruplari kesfet',
          );

          // Kok neden sozlesmesi: bos durum **kaydirilabilir** olmali. Tasma
          // olcusu tek basina yetmez — genis bir ekranda tasmayan ama yine de
          // kaydirilamayan duzen bir sonraki cihazda ayni hatayi verir.
          expect(
            _verticalScrollAncestors(
              tester,
              find.widgetWithText(OutlinedButton, 'Koda katıl'),
            ),
            greaterThan(0),
            reason: 'grupsuz bos durumda dikey kaydirici yok',
          );
        });
      }
    }
  });

  group('WP-541/2 — istatistik bos durumu buyuk yazida erisilebilir', () {
    for (final (width, height) in _screens) {
      for (final scale in _scales) {
        testWidgets('${width.toInt()}x${height.toInt()} scale=$scale', (
          tester,
        ) async {
          SharedPreferences.setMockInitialValues({});
          final prefs = await SharedPreferences.getInstance();

          final errors = await _pump(
            tester,
            // Gercek kabuk: sekme cubugu + donem seridi yuksekligin buyuk
            // kismini yer; bos durumu ciplak `Scaffold` icinde olcmek hatayi
            // kacirir (yalancı yesil).
            home: const StatsScreen(),
            overrides: _statsOverrides(prefs),
            width: width,
            height: height,
            scale: scale,
          );
          expect(
            errors,
            isEmpty,
            reason: 'istatistik bos durumu tasti: $errors',
          );

          await _expectReachable(
            tester,
            find.text('Bu dönemde çalışma kaydın yok.'),
            height,
            'Bos durum aciklamasi',
          );

          expect(
            _verticalScrollAncestors(
              tester,
              find.text('Bu dönemde çalışma kaydın yok.'),
            ),
            greaterThan(0),
            reason: 'istatistik bos durumunda dikey kaydirici yok',
          );
        });
      }
    }
  });

  group('WP-541/3 — "Bugun ozeti" basligi tasmiyor', () {
    for (final (width, height) in _screens) {
      for (final scale in _scales) {
        testWidgets('${width.toInt()}x${height.toInt()} scale=$scale', (
          tester,
        ) async {
          final errors = await _pump(
            tester,
            home: Scaffold(
              body: ListView(children: const [TodaySummaryCard()]),
            ),
            overrides: _summaryOverrides(),
            width: width,
            height: height,
            scale: scale,
          );
          expect(errors, isEmpty, reason: 'kart basligi tasti: $errors');
          // Yalancı yeşile karşı: veri kapısı acikken kart govdesi hic
          // cizilmez ve tabii ki tasmaz.
          expect(find.text('Bugün özeti'), findsOneWidget);
        });
      }
    }
  });

  group('WP-541/4 — aciliyet rengi tema zeminine karsi okunur', () {
    // Cizim iki farkli zeminde olur: kart yuzeyi (`surface`) ve liste/scaffold
    // (`surfaceContainerLowest`). Renk ikisinde birden esigi tutmali.
    final now = DateTime.utc(2026, 8, 8, 12);
    final samples = <String, DateTime?>{
      'suresiz': null,
      'gecikti': now.subtract(const Duration(hours: 3)),
      'acil (<6s)': now.add(const Duration(hours: 2)),
      'yakin (6-24s)': now.add(const Duration(hours: 12)),
      'sakin (3g)': now.add(const Duration(days: 3)),
      'uzak (30g)': now.add(const Duration(days: 30)),
    };

    for (final preset in kThemePresets) {
      for (final brightness in Brightness.values) {
        test('${preset.id} / ${brightness.name}', () {
          final theme = AppTheme.fromFamily(preset, brightness);
          final scheme = theme.colorScheme;
          for (final entry in samples.entries) {
            final color = taskUrgencyColor(now, entry.value, scheme);
            for (final background in <(String, Color)>[
              ('surface', scheme.surface),
              ('scaffold', scheme.surfaceContainerLowest),
            ]) {
              final ratio = contrastRatio(color, background.$2);
              expect(
                ratio,
                greaterThanOrEqualTo(kMinTextContrast),
                reason:
                    '${preset.id}/${brightness.name} ${entry.key} rengi '
                    '${background.$1} zemininde ${ratio.toStringAsFixed(2)} — '
                    'WCAG AA metin esigi $kMinTextContrast altinda.',
              );
              // Rozet dolgusu ayni renkten %14 alfa ile uretiliyor; metin o
              // dolgunun ustunde de okunmali.
              final filled = Color.alphaBlend(
                color.withValues(alpha: 0.14),
                background.$2,
              );
              expect(
                contrastRatio(color, filled),
                greaterThanOrEqualTo(3.0),
                reason:
                    '${preset.id}/${brightness.name} ${entry.key} rozet '
                    'dolgusunun ustunde kayboluyor.',
              );
            }
          }
        });
      }
    }
  });
}
